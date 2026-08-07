export type JsonObject = Record<string, unknown>;
export type PagedRows = { rows: JsonObject[]; totalCount: number };

export interface FreshnessApiGateway {
  submitReport(payload: JsonObject): Promise<JsonObject>;
  listMyReports(userId: string, page: number, pageSize: number): Promise<PagedRows>;
  getOverview(): Promise<JsonObject>;
  listQueue(page: number, pageSize: number): Promise<PagedRows>;
  listStale(page: number, pageSize: number): Promise<PagedRows>;
  listReports(page: number, pageSize: number): Promise<PagedRows>;
  listRuns(page: number, pageSize: number): Promise<PagedRows>;
  reviewProposal(
    proposalId: string,
    decision: "approved" | "rejected",
    appliedData: JsonObject,
  ): Promise<JsonObject>;
  requestCheck(contentType: string, contentId: string): Promise<void>;
  updateReportStatus(
    reportId: string,
    status: "pending" | "in_progress" | "resolved" | "dismissed",
  ): Promise<JsonObject>;
}

export type FreshnessApiHandlerInput = {
  request: Request;
  userId: string;
  isAdmin: boolean;
  gateway: FreshnessApiGateway;
};

const CONTENT_TYPES = new Set([
  "place",
  "activity",
  "culture",
  "food",
  "local_product",
]);
const REPORT_REASONS = new Set([
  "closed",
  "wrong_hours",
  "wrong_location",
  "event_ended",
  "other",
]);

export async function handleFreshnessApiRequest(
  input: FreshnessApiHandlerInput,
): Promise<Response> {
  if (input.request.method !== "POST") {
    return response({ error: "Method not allowed." }, 405);
  }

  const body = await input.request.json().catch(() => null);
  if (!isRecord(body)) return response({ error: "Invalid JSON payload." }, 400);
  const action = text(body.action);
  if (!action) return response({ error: "Action is required." }, 400);

  try {
    switch (action) {
      case "submitReport": {
        const contentType = requiredContentType(body.contentType);
        const contentId = requiredId(body.contentId, "contentId");
        const reason = text(body.reason);
        if (!REPORT_REASONS.has(reason)) throw badRequest("Unsupported report reason.");
        const note = body.note === undefined || body.note === null ? null : text(body.note);
        if (note !== null && note.length > 1000) throw badRequest("Report note is too long.");
        const report = await input.gateway.submitReport({
          contentType,
          contentId,
          reason,
          note,
        });
        return response({ report }, 200);
      }
      case "listMyReports": {
        const page = parsePage(body.page);
        const pageSize = parsePageSize(body.pageSize);
        const result = await input.gateway.listMyReports(input.userId, page, pageSize);
        return response({ reports: result.rows, totalCount: result.totalCount }, 200);
      }
      case "adminGetOverview":
        requireAdmin(input.isAdmin);
        return response({ overview: await input.gateway.getOverview() }, 200);
      case "adminListQueue":
        requireAdmin(input.isAdmin);
        return pagedResponse(await input.gateway.listQueue(parsePage(body.page), parsePageSize(body.pageSize)), "proposals");
      case "adminListStale":
        requireAdmin(input.isAdmin);
        return pagedResponse(await input.gateway.listStale(parsePage(body.page), parsePageSize(body.pageSize)), "freshness");
      case "adminListReports":
        requireAdmin(input.isAdmin);
        return pagedResponse(await input.gateway.listReports(parsePage(body.page), parsePageSize(body.pageSize)), "reports");
      case "adminListRuns":
        requireAdmin(input.isAdmin);
        return pagedResponse(await input.gateway.listRuns(parsePage(body.page), parsePageSize(body.pageSize)), "runs");
      case "adminReviewProposal": {
        requireAdmin(input.isAdmin);
        const proposalId = requiredId(body.proposalId, "proposalId");
        const decision = text(body.decision);
        if (decision !== "approved" && decision !== "rejected") {
          throw badRequest("Unsupported proposal decision.");
        }
        const appliedData = body.appliedData === undefined
          ? {}
          : requireObject(body.appliedData, "appliedData");
        const proposal = await input.gateway.reviewProposal(
          proposalId,
          decision,
          appliedData,
        );
        return response({ proposal }, 200);
      }
      case "adminRequestCheck": {
        requireAdmin(input.isAdmin);
        const contentType = requiredContentType(body.contentType);
        const contentId = requiredId(body.contentId, "contentId");
        await input.gateway.requestCheck(contentType, contentId);
        return response({ ok: true }, 200);
      }
      case "adminUpdateReportStatus": {
        requireAdmin(input.isAdmin);
        const reportId = requiredId(body.reportId, "reportId");
        const status = text(body.status);
        if (!new Set(["pending", "in_progress", "resolved", "dismissed"]).has(status)) {
          throw badRequest("Unsupported report status.");
        }
        const report = await input.gateway.updateReportStatus(reportId, status as "pending" | "in_progress" | "resolved" | "dismissed");
        return response({ report }, 200);
      }
      default:
        return response({ error: "Unsupported action." }, 400);
    }
  } catch (error) {
    if (error instanceof ApiError) {
      return response({ error: error.message, code: error.code, error_code: error.code }, error.status);
    }
    const message = error instanceof Error ? error.message : "Unexpected error.";
    if (/duplicate open report|duplicate_report|unique/i.test(message)) {
      return response({ error: "Duplicate open report.", code: "duplicate_report", error_code: "duplicate_report" }, 409);
    }
    if (/daily content report limit|report_rate_limited/i.test(message)) {
      return response({ error: "Daily report limit reached.", code: "report_rate_limited", error_code: "report_rate_limited" }, 429);
    }
    return response({ error: message }, 500);
  }
}

class ApiError extends Error {
  constructor(
    message: string,
    public readonly status: number,
    public readonly code = "invalid_request",
  ) {
    super(message);
  }
}

function badRequest(message: string): ApiError {
  return new ApiError(message, 400);
}

function requireAdmin(isAdmin: boolean): void {
  if (!isAdmin) throw new ApiError("Admin role required.", 403, "admin_required");
}

function requiredContentType(value: unknown): string {
  const contentType = text(value);
  if (!CONTENT_TYPES.has(contentType)) throw badRequest("Unsupported content type.");
  return contentType;
}

function requiredId(value: unknown, field: string): string {
  const id = text(value);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)) {
    throw badRequest(`${field} must be a UUID.`);
  }
  return id;
}

function parsePage(value: unknown): number {
  const page = Number(value ?? 1);
  if (!Number.isInteger(page) || page < 1) throw badRequest("Page must be a positive integer.");
  return Math.min(page, 10000);
}

function parsePageSize(value: unknown): number {
  const pageSize = Number(value ?? 20);
  if (!Number.isInteger(pageSize) || pageSize < 1) throw badRequest("Page size must be a positive integer.");
  return Math.min(pageSize, 50);
}

function requireObject(value: unknown, field: string): JsonObject {
  if (!isRecord(value)) throw badRequest(`${field} must be an object.`);
  return value;
}

function pagedResponse(result: PagedRows, key: string): Response {
  return response({ [key]: result.rows, totalCount: result.totalCount }, 200);
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function isRecord(value: unknown): value is JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function response(body: JsonObject, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export { ApiError, CONTENT_TYPES, REPORT_REASONS };
