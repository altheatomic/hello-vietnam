/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { createClient } from "@supabase/supabase-js";

import { corsHeaders } from "../_shared/cors.ts";
import {
  AuthorizationError,
  requireAuthenticatedUserId,
  requireAuthorizationHeader,
} from "../auth/auth_guard.ts";
import { ReviewModerationError, ReviewService } from "./review_service.ts";
import {
  CONTENT_REGISTRY,
  type ContentRef,
  type ReviewContentType,
  type ReviewListPayload,
  type UpsertReviewPayload,
} from "./review_types.ts";

export {
  evaluateModeration,
  normalizeReviewText,
  summarizePublishedReviews,
} from "./review_types.ts";

type JsonObject = Record<string, unknown>;

class RequestValidationError extends Error {
  constructor(message: string, readonly statusCode = 400) {
    super(message);
    this.name = "RequestValidationError";
  }
}

export async function handleReviewsRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const rawPayload = await req.json().catch(() => null);
    if (!isJsonObject(rawPayload)) {
      throw new RequestValidationError("Invalid JSON body.");
    }
    const payload: JsonObject = rawPayload;

    const action = requiredString(payload.action, "action");
    const { url, anonKey, serviceRoleKey } = requiredEnvironment();
    const service = new ReviewService(createClient(url, serviceRoleKey));

    switch (action) {
      case "getReviewSummary":
        return jsonResponse(await service.getReviewSummary(parseContentRef(payload)));
      case "getReviews":
        return jsonResponse(await service.getReviews(parseReviewListPayload(payload)));
      case "getMyReview": {
        const userId = await requireAuthenticatedUserIdFromRequest(req, url, anonKey);
        return jsonResponse(await service.getMyReview(userId, parseContentRef(payload)));
      }
      case "upsertReview": {
        const userId = await requireAuthenticatedUserIdFromRequest(req, url, anonKey);
        return jsonResponse(await service.upsertReview(userId, parseUpsertPayload(payload)));
      }
      default:
        return jsonResponse({ error: `Unsupported action: ${action}` }, 400);
    }
  } catch (error) {
    if (
      error instanceof AuthorizationError ||
      error instanceof RequestValidationError ||
      error instanceof ReviewModerationError
    ) {
      return jsonResponse({ error: error.message }, error.statusCode);
    }
    const message = error instanceof Error ? error.message : "Unexpected error.";
    return jsonResponse({ error: message }, 500);
  }
}

export function parseContentRef(value: JsonObject): ContentRef {
  const contentType = requiredString(value.contentType, "contentType");
  if (!Object.hasOwn(CONTENT_REGISTRY, contentType)) {
    throw new RequestValidationError("Invalid contentType.");
  }
  const contentId = requiredString(value.contentId, "contentId");
  if (!isUuid(contentId)) {
    throw new RequestValidationError("contentId must be a UUID.");
  }
  return { contentType: contentType as ReviewContentType, contentId };
}

export function parseUpsertPayload(value: JsonObject): UpsertReviewPayload {
  const content = parseContentRef(value);
  const rating = Number(value.rating);
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    throw new RequestValidationError("rating must be an integer between 1 and 5.");
  }
  const comment = requiredString(value.comment, "comment");
  if (comment.length > 2000) {
    throw new RequestValidationError("comment must not exceed 2000 characters.");
  }
  return { ...content, rating, comment };
}

export function parseReviewListPayload(value: JsonObject): ReviewListPayload {
  const content = parseContentRef(value);
  return {
    ...content,
    page: boundedPositiveInt(value.page, 1, 100000),
    pageSize: boundedPositiveInt(value.pageSize, 20, 100),
  };
}

function requiredEnvironment(): { url: string; anonKey: string; serviceRoleKey: string } {
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceRoleKey) {
    throw new Error("Missing required Supabase environment variables for reviews function.");
  }
  return { url, anonKey, serviceRoleKey };
}

async function requireAuthenticatedUserIdFromRequest(
  req: Request,
  url: string,
  anonKey: string,
): Promise<string> {
  const authHeader = requireAuthorizationHeader(req.headers.get("Authorization"));
  const client = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  return requireAuthenticatedUserId(client);
}

function requiredString(value: unknown, fieldName: string): string {
  if (typeof value !== "string" || !value.trim()) {
    throw new RequestValidationError(`Missing ${fieldName}.`);
  }
  return value.trim();
}

function boundedPositiveInt(value: unknown, fallback: number, max: number): number {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? Math.min(parsed, max) : fallback;
}

function isJsonObject(value: unknown): value is JsonObject {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
