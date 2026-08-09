import type { SupabaseClient } from "@supabase/supabase-js";

import type {
  FreshnessApiGateway,
  JsonObject,
  PagedRows,
} from "./freshness_api_handler.ts";

export class SupabaseFreshnessApiGateway implements FreshnessApiGateway {
  constructor(
    private readonly serviceClient: SupabaseClient,
    private readonly authenticatedClient: SupabaseClient = serviceClient,
  ) {}

  async submitReport(payload: JsonObject): Promise<JsonObject> {
    const { data, error } = await this.authenticatedClient.rpc(
      "submit_content_report",
      {
        p_content_type: payload.contentType,
        p_content_id: payload.contentId,
        p_reason: payload.reason,
        p_note: payload.note,
      },
    );
    if (error) throw new Error(error.message);
    return { id: data };
  }

  async listMyReports(userId: string, page: number, pageSize: number): Promise<PagedRows> {
    const { data, count, error } = await this.serviceClient
      .from("content_report")
      .select(
        "id,content_type,content_id,reason,note,status,created_at,resolved_at",
        { count: "exact" },
      )
      .eq("reporter_user_id", userId)
      .order("created_at", { ascending: false })
      .range(...rangeFor(page, pageSize));
    if (error) throw new Error(error.message);
    return { rows: asRows(data), totalCount: count ?? 0 };
  }

  async getOverview(): Promise<JsonObject> {
    const [due, pending, autoExpiredToday, failedRuns] = await Promise.all([
      countRows(this.serviceClient, "content_freshness", (query) =>
        query.in("freshness_status", ["due", "stale"])),
      countRows(this.serviceClient, "content_change_proposal", (query) =>
        query.eq("decision", "pending")),
      countRows(this.serviceClient, "content_change_proposal", (query) =>
        query.eq("decision", "auto_applied").gte("detected_at", utcDayStart())),
      countRows(this.serviceClient, "content_update_run", (query) =>
        query.in("status", ["failed", "partial_failure"])),
    ]);
    return { due, pending, autoExpiredToday, failedRuns };
  }

  async listQueue(page: number, pageSize: number): Promise<PagedRows> {
    const { data, count, error } = await this.serviceClient
      .from("content_change_proposal")
      .select(
        "id,freshness_id,change_type,before_data,proposed_data,changed_fields,reason,confidence,decision,detected_at,content_freshness!inner(content_type,content_id,source_type,source_url,freshness_status,last_verified_at)",
        { count: "exact" },
      )
      .eq("decision", "pending")
      .order("detected_at", { ascending: false })
      .range(...rangeFor(page, pageSize));
    if (error) throw new Error(error.message);
    return { rows: asRows(data), totalCount: count ?? 0 };
  }

  async listStale(page: number, pageSize: number): Promise<PagedRows> {
    const { data, count, error } = await this.serviceClient
      .from("content_freshness")
      .select(
        "id,content_type,content_id,source_type,source_url,freshness_status,last_verified_at,next_check_at,last_error,consecutive_missing_count",
        { count: "exact" },
      )
      .in("freshness_status", ["due", "stale"])
      .order("next_check_at", { ascending: true })
      .range(...rangeFor(page, pageSize));
    if (error) throw new Error(error.message);
    return { rows: asRows(data), totalCount: count ?? 0 };
  }

  async listReports(page: number, pageSize: number): Promise<PagedRows> {
    const { data, count, error } = await this.serviceClient
      .from("content_report")
      .select(
        "id,reporter_user_id,content_type,content_id,reason,note,status,created_at,resolved_at,reporter:user_account!content_report_reporter_user_id_fkey(full_name,username)",
        { count: "exact" },
      )
      .in("status", ["pending", "in_progress"])
      .order("created_at", { ascending: false })
      .range(...rangeFor(page, pageSize));
    if (error) throw new Error(error.message);
    const rows = asRows(data).map((row) => {
      const profile = row.reporter && typeof row.reporter === "object"
        ? row.reporter as Record<string, unknown>
        : {};
      const fullName = String(profile.full_name ?? "").trim();
      const username = String(profile.username ?? "").trim();
      return {
        ...row,
        reporter_name: fullName || username.split("@")[0] || null,
        reporter_email: username || null,
      };
    });
    return { rows, totalCount: count ?? 0 };
  }

  async listRuns(page: number, pageSize: number): Promise<PagedRows> {
    const { data, count, error } = await this.serviceClient
      .from("content_update_run")
      .select(
        "id,trigger_type,started_at,finished_at,status,selected_count,checked_count,unchanged_count,proposal_count,auto_applied_count,failed_count,error_summary",
        { count: "exact" },
      )
      .order("started_at", { ascending: false })
      .range(...rangeFor(page, pageSize));
    if (error) throw new Error(error.message);
    return { rows: asRows(data), totalCount: count ?? 0 };
  }

  async reviewProposal(
    proposalId: string,
    decision: "approved" | "rejected",
    appliedData: JsonObject,
  ): Promise<JsonObject> {
    const { data, error } = await this.authenticatedClient.rpc(
      "review_content_change_proposal",
      {
        p_proposal_id: proposalId,
        p_decision: decision,
        p_applied_data: appliedData,
      },
    );
    if (error) throw new Error(error.message);
    if (!data || typeof data !== "object") throw new Error("Review returned an invalid proposal.");
    return data as JsonObject;
  }

  async requestCheck(contentType: string, contentId: string): Promise<void> {
    const { error } = await this.authenticatedClient.rpc("request_content_freshness_check", {
      p_content_type: contentType,
      p_content_id: contentId,
    });
    if (error) throw new Error(error.message);
  }

  async updateReportStatus(
    reportId: string,
    status: "pending" | "in_progress" | "resolved" | "dismissed",
  ): Promise<JsonObject> {
    const { data, error } = await this.serviceClient
      .from("content_report")
      .update({
        status,
        resolved_at: status === "resolved" || status === "dismissed"
          ? new Date().toISOString()
          : null,
      })
      .eq("id", reportId)
      .select("id,reporter_user_id,content_type,content_id,reason,note,status,created_at,resolved_at")
      .single();
    if (error) throw new Error(error.message);
    return (data ?? {}) as JsonObject;
  }
}

async function countRows(
  client: SupabaseClient,
  table: string,
  refine: (query: any) => any,
): Promise<number> {
  let query = client.from(table).select("id", { count: "exact", head: true });
  query = refine(query);
  const { count, error } = await query;
  if (error) throw new Error(error.message);
  return count ?? 0;
}

function rangeFor(page: number, pageSize: number): [number, number] {
  const from = (page - 1) * pageSize;
  return [from, from + pageSize - 1];
}

function utcDayStart(): string {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())).toISOString();
}

function asRows(data: unknown): JsonObject[] {
  return Array.isArray(data)
    ? data.filter((row): row is JsonObject => row !== null && typeof row === "object" && !Array.isArray(row))
    : [];
}
