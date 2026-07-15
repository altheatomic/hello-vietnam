/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { createClient } from "@supabase/supabase-js";
import { corsHeaders } from "../_shared/cors.ts";
import {
  AuthorizationError,
  requireAuthenticatedUserId,
  requireAuthorizationHeader,
} from "../auth/auth_guard.ts";

type JsonObject = Record<string, unknown>;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
// Set via: supabase secrets set CF_SERVICE_URL=https://your-cf-service.run.app
const CF_SERVICE_URL =
  Deno.env.get("CF_SERVICE_URL") ?? "http://localhost:8000";
const HANDLER_VERSION = "trip-planner-2026-06-06-v1";

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
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
  return proxyPost(`/api/trips/${id}/clone`, { id_user: userId });
}

async function savePlan(userId: string, p: JsonObject): Promise<Response> {
  const id = reqStr(p.idPlan, "idPlan");
  return proxyPost(`/api/trips/${id}/save`, {
    id_user: userId,
    custom_title: strVal(p.customTitle),
  });
}

async function proxyPost(path: string, body: unknown): Promise<Response> {
  console.log(`[trip-planner] cf_service_host=${new URL(CF_SERVICE_URL).host}`);
  const r = await fetch(`${CF_SERVICE_URL}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = (await r.json()) as JsonObject;
  console.log(`[trip-planner] cf_service_status=${r.status} days=${Array.isArray(data.days) ? data.days.length : "N/A"}`);
  if (!r.ok)
    return jsonResponse(
      { error: strVal(data.detail) ?? "Request failed." },
      r.status,
    );
  return jsonResponse(data);
}

async function proxyGet(path: string): Promise<Response> {
  console.log(`[trip-planner] cf_service_host=${new URL(CF_SERVICE_URL).host}`);
  const r = await fetch(`${CF_SERVICE_URL}${path}`);
  const data = (await r.json()) as JsonObject;
  console.log(`[trip-planner] cf_service_status=${r.status} days=${Array.isArray(data.days) ? data.days.length : "N/A"}`);
  if (!r.ok)
    return jsonResponse(
      { error: strVal(data.detail) ?? "Request failed." },
      r.status,
    );
  return jsonResponse(data);
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
