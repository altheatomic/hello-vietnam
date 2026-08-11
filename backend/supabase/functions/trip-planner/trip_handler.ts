/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { createClient } from "@supabase/supabase-js";
import { corsHeaders } from "../_shared/cors.ts";
import {
  AuthorizationError,
  requireAuthenticatedUserId,
  requireAuthorizationHeader,
  requireRole,
} from "../auth/auth_guard.ts";
import { isRawCloneAllowed } from "./trip_clone_authorization.ts";

type JsonObject = Record<string, unknown>;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
// Set via: supabase secrets set CF_SERVICE_URL=https://your-cf-service.run.app
const CF_SERVICE_URL =
  Deno.env.get("CF_SERVICE_URL") ?? "http://localhost:8000";
const HANDLER_VERSION = "trip-planner-2026-06-06-v1";

if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing required Supabase environment variables.");
}

export async function handleTripPlannerRequest(
  req: Request,
): Promise<Response> {
  console.log(`[trip-planner] version=${HANDLER_VERSION} method=${req.method}`);

  if (req.method === "OPTIONS")
    return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST")
    return jsonResponse({ error: "Method not allowed." }, 405);

  try {
    const authHeader = requireAuthorizationHeader(
      req.headers.get("Authorization"),
    );
    const userClient = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
      global: { headers: { Authorization: authHeader } },
    });
    const userId = await requireAuthenticatedUserId(userClient);

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object")
      return jsonResponse({ error: "Invalid JSON body." }, 400);

    const payload = body as JsonObject;
    const action = strVal(payload.action);
    if (!action) return jsonResponse({ error: "Missing action." }, 400);
    console.log(`[trip-planner] action=${action} userId=${userId}`);

    switch (action) {
      case "planTrip":
        return planTrip(userId, payload);
      case "getPlan":
        return getPlan(userId, payload);
      case "listPlans":
        return listPlans(userId);
      case "listSavedPlans":
        return listSavedPlans(userId);
      case "getNearbyPlaces":
        return getNearbyPlaces(payload);
      case "clonePlan":
        return clonePlan(userId, payload);
      case "savePlan":
        return savePlan(userId, payload);
      case "renamePlan":
        return renamePlan(userId, payload);
      case "rescheduleTrip":
        return rescheduleTrip(userId, payload);
      case "completeTrip":
        return completeTrip(userId, payload);
      case "overdueTripCheck":
        return overdueTripCheck(userId);
      case "triggerCfRetrain":
        return triggerCfRetrain(userId);
      case "getCfRetrainLogs":
        return getCfRetrainLogs(userId);
      default:
        return jsonResponse({ error: `Unsupported action: ${action}` }, 400);
    }
  } catch (err) {
    console.error("[trip-planner] unhandled error", err);
    if (err instanceof AuthorizationError)
      return jsonResponse({ error: err.message }, err.statusCode);
    return jsonResponse(
      { error: err instanceof Error ? err.message : "Unexpected error." },
      500,
    );
  }
}

async function planTrip(userId: string, p: JsonObject): Promise<Response> {
  const body: JsonObject = {
    id_user: userId,
    n_days: reqInt(p.nDays, "nDays"),
    start_date: strVal(p.startDate),
    top_n: intOrDefault(p.topN, 40),
    sa_runs: intOrDefault(p.saRuns, 5),
    save_plan: boolOrDefault(p.savePlan, true),
  };
  const idProvince = strVal(p.idProvince);
  if (idProvince) body.id_province = idProvince;
  const targetLat = numVal(p.targetLat);
  const targetLng = numVal(p.targetLng);
  if (targetLat != null) body.target_lat = targetLat;
  if (targetLng != null) body.target_lng = targetLng;
  if (Array.isArray(p.interestOptionIds)) {
    body.interest_option_ids = p.interestOptionIds;
  }
  body.include_lunch_break = boolOrDefault(p.includeLunchBreak, true);
  return proxyPost("/api/trips/plan", body);
}

async function getPlan(userId: string, p: JsonObject): Promise<Response> {
  const id = reqStr(p.idPlan, "idPlan");
  return proxyGet(`/api/trips/plan/${id}?id_user=${userId}`);
}

async function listPlans(userId: string): Promise<Response> {
  return proxyGet(`/api/trips/plans?id_user=${userId}`);
}

async function listSavedPlans(userId: string): Promise<Response> {
  return proxyGet(`/api/trips/saved?id_user=${userId}`);
}

async function getNearbyPlaces(p: JsonObject): Promise<Response> {
  const lat = reqNum(p.lat, "lat");
  const lng = reqNum(p.lng, "lng");
  const limit = intOrDefault(p.limit, 3);
  return proxyGet(`/api/places/nearby?lat=${lat}&lng=${lng}&limit=${limit}`);
}

async function clonePlan(userId: string, p: JsonObject): Promise<Response> {
  const id = reqStr(p.idPlan, "idPlan");
  const adminClient = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!);
  const { data: plan, error: planError } = await adminClient
    .from("plan")
    .select("id_user")
    .eq("id_plan", id)
    .maybeSingle();
  if (planError) {
    return jsonResponse({ error: `Could not authorize clone: ${planError.message}` }, 503);
  }
  if (!plan) return jsonResponse({ error: "Plan not found." }, 404);

  let hasActiveForumShare = false;
  if (String(plan.id_user ?? "") !== userId) {
    const { data: post, error: postError } = await adminClient
      .from("forum_post")
      .select("id_post")
      .eq("status", "active")
      .contains("shared_item", { type: "trip_plan", plan_id: id })
      .limit(1)
      .maybeSingle();
    if (postError) {
      return jsonResponse(
        { error: `Could not authorize forum share: ${postError.message}` },
        503,
      );
    }
    hasActiveForumShare = post != null;
  }

  if (!isRawCloneAllowed({
    requestingUserId: userId,
    ownerUserId: strVal(plan.id_user),
    hasActiveForumShare,
  })) {
    return jsonResponse({ error: "This trip is not available to copy." }, 403);
  }
  return proxyPost(`/api/trips/${id}/clone`, { id_user: userId });
}

async function savePlan(userId: string, p: JsonObject): Promise<Response> {
  const id = reqStr(p.idPlan, "idPlan");
  return proxyPost(`/api/trips/${id}/save`, {
    id_user: userId,
    custom_title: strVal(p.customTitle),
  });
}

async function renamePlan(userId: string, p: JsonObject): Promise<Response> {
  const id = reqStr(p.idPlan, "idPlan");
  const customTitle = reqStr(p.customTitle, "customTitle");
  return proxyRequest("PATCH", `/api/trips/${id}/title`, {
    id_user: userId,
    custom_title: customTitle,
  });
}

async function rescheduleTrip(userId: string, p: JsonObject): Promise<Response> {
  const id = reqStr(p.idPlan, "idPlan");
  const newStartAt = reqStr(p.newStartAt, "newStartAt");
  return proxyPost(`/api/trips/${id}/reschedule`, {
    id_user: userId,
    new_start_at: newStartAt,
  });
}

async function completeTrip(userId: string, p: JsonObject): Promise<Response> {
  const id = reqStr(p.idPlan, "idPlan");
  return proxyPost(`/api/trips/${id}/complete`, { id_user: userId });
}

async function overdueTripCheck(userId: string): Promise<Response> {
  return proxyGet(`/api/trips/overdue-check?id_user=${userId}`);
}

async function triggerCfRetrain(userId: string): Promise<Response> {
  const adminClient = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!);
  await requireRole(adminClient, userId, "admin");
  return proxyPost("/admin/cf/retrain", {});
}

async function getCfRetrainLogs(userId: string): Promise<Response> {
  const adminClient = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!);
  await requireRole(adminClient, userId, "admin");

  const { data, error } = await adminClient
    .from("cf_retrain_log")
    .select(
      "id_log, triggered_by, started_at, finished_at, status, rows_written, error_msg",
    )
    .order("started_at", { ascending: false })
    .limit(50);

  if (error) {
    return jsonResponse(
      { error: `Could not load CF retrain logs: ${error.message}` },
      503,
    );
  }
  return jsonResponse({ logs: data ?? [] });
}

async function proxyPost(path: string, body: unknown): Promise<Response> {
  return proxyRequest("POST", path, body);
}

async function proxyRequest(
  method: "POST" | "PATCH",
  path: string,
  body: unknown,
): Promise<Response> {
  console.log(`[trip-planner] cf_service_host=${new URL(CF_SERVICE_URL).host}`);
  const r = await fetch(`${CF_SERVICE_URL}${path}`, {
    method,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const { data, error } = await parseUpstreamJson(r);
  if (error != null) return error;

  const obj = data as JsonObject;
  console.log(`[trip-planner] cf_service_status=${r.status} days=${Array.isArray(obj.days) ? obj.days.length : "N/A"}`);
  if (!r.ok) return upstreamErrorResponse(obj, r.status);
  return jsonResponse(obj);
}

async function proxyGet(path: string): Promise<Response> {
  console.log(`[trip-planner] cf_service_host=${new URL(CF_SERVICE_URL).host}`);
  const r = await fetch(`${CF_SERVICE_URL}${path}`);
  const { data, error } = await parseUpstreamJson(r);
  if (error != null) return error;

  const obj = data as JsonObject;
  console.log(`[trip-planner] cf_service_status=${r.status} days=${Array.isArray(obj.days) ? obj.days.length : "N/A"}`);
  if (path.startsWith("/api/trips/plan/")) {
    const firstDay = Array.isArray(obj.days) ? obj.days[0] : null;
    const firstPlace = firstDay && typeof firstDay === "object" &&
        Array.isArray((firstDay as JsonObject).places)
      ? ((firstDay as JsonObject).places as unknown[])[0] ?? null
      : null;
    console.log(
      `[trip-planner] getPlan_first_place=${JSON.stringify(firstPlace)}`,
    );
  }
  if (!r.ok) return upstreamErrorResponse(obj, r.status);
  return jsonResponse(obj);
}

/// Builds the edge-function error response from an upstream cf_service
/// error body. `detail` is usually a plain string (FastAPI's default
/// HTTPException shape), but some cf_service routes (e.g. planTrip's
/// no-candidates case) raise a structured `{error_code, message}` detail
/// so the client can distinguish failure reasons without string-matching
/// the message. Both shapes are supported; string stays backward compatible.
function upstreamErrorResponse(obj: JsonObject, status: number): Response {
  const detail = obj.detail;
  if (detail && typeof detail === "object" && !Array.isArray(detail)) {
    const d = detail as JsonObject;
    return jsonResponse(
      {
        error: strVal(d.message) ?? "Request failed.",
        error_code: strVal(d.error_code) ?? undefined,
      },
      status,
    );
  }
  return jsonResponse({ error: strVal(detail) ?? "Request failed." }, status);
}

/// Safely parses an upstream cf_service response body as JSON.
///
/// cf_service can fail before reaching a route handler (e.g. a dependency
/// raising before the JSON exception handler applies) and Starlette's default
/// error path returns a plain-text "Internal Server Error" body in that case.
/// Calling `.json()` on that unconditionally throws a SyntaxError that, left
/// uncaught, aborts the edge function invocation — which the browser then
/// misreports as a CORS failure rather than the real upstream 500. Reading
/// the body as text first and parsing it ourselves keeps every failure mode
/// inside a normal, CORS-headers-included JSON error response.
async function parseUpstreamJson(
  r: Response,
): Promise<{ data: unknown; error: Response | null }> {
  const raw = await r.text();
  try {
    return { data: raw.length > 0 ? JSON.parse(raw) : {}, error: null };
  } catch {
    console.error(
      `[trip-planner] cf_service returned non-JSON body (status=${r.status}): ${raw.slice(0, 500)}`,
    );
    return {
      data: null,
      error: jsonResponse(
        { error: `cf_service returned an unexpected response (status ${r.status}).` },
        502,
      ),
    };
  }
}

function strVal(v: unknown): string | null {
  if (v == null) return null;
  const s = String(v).trim();
  return s.length > 0 ? s : null;
}

function reqStr(v: unknown, name: string): string {
  const s = strVal(v);
  if (!s) throw new Error(`Missing required field: ${name}`);
  return s;
}

function reqInt(v: unknown, name: string): number {
  const n = typeof v === "number" ? v : Number(v);
  if (!Number.isInteger(n) || n < 1)
    throw new Error(`${name} must be a positive integer`);
  return n;
}

function numVal(v: unknown): number | null {
  if (v == null) return null;
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : null;
}

function reqNum(v: unknown, name: string): number {
  const n = numVal(v);
  if (n == null) throw new Error(`${name} must be a number`);
  return n;
}

function intOrDefault(v: unknown, fallback: number): number {
  if (v == null) return fallback;
  const n = typeof v === "number" ? v : Number(v);
  return Number.isInteger(n) && n > 0 ? n : fallback;
}

function boolOrDefault(v: unknown, fallback: boolean): boolean {
  if (v == null) return fallback;
  if (typeof v === "boolean") return v;
  if (v === "true") return true;
  if (v === "false") return false;
  return fallback;
}

function jsonResponse(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
