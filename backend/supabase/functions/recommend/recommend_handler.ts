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
const CF_SERVICE_URL =
  Deno.env.get("CF_SERVICE_URL") ?? "http://localhost:8000";

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  throw new Error("Missing required Supabase environment variables.");
}

export async function handleRecommendRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const authHeader = requireAuthorizationHeader(
      req.headers.get("Authorization"),
    );
    const userClient = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
      global: { headers: { Authorization: authHeader } },
    });
    const userId = await requireAuthenticatedUserId(userClient);

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return jsonResponse({ error: "Invalid JSON body." }, 400);
    }

    const payload = body as JsonObject;
    const action = stringValue(payload.action);
    switch (action) {
      case "getPersonalizedProvinces": {
        const limit = positiveInt(payload.limit, 100);
        return proxyGet(
          `/api/recommend/provinces?id_user=${encodeURIComponent(userId)}` +
            `&limit=${limit}`,
        );
      }
      case "getTopPlacesForProvince": {
        const idProvince = requiredString(payload.idProvince, "idProvince");
        const limit = positiveInt(payload.limit, 20);
        return proxyGet(
          `/api/recommend/province/${encodeURIComponent(idProvince)}` +
            `?id_user=${encodeURIComponent(userId)}&limit=${limit}`,
        );
      }
      default:
        return jsonResponse({ error: `Unsupported action: ${action}` }, 400);
    }
  } catch (error) {
    console.error("[recommend] unhandled error", error);
    if (error instanceof AuthorizationError) {
      return jsonResponse({ error: error.message }, error.statusCode);
    }
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unexpected error." },
      500,
    );
  }
}

async function proxyGet(path: string): Promise<Response> {
  console.log(`[recommend] cf_service_host=${new URL(CF_SERVICE_URL).host}`);
  const response = await fetch(`${CF_SERVICE_URL}${path}`);
  const { data, error } = await parseUpstreamJson(response);
  if (error != null) return error;

  const object = data as JsonObject;
  console.log(`[recommend] cf_service_status=${response.status}`);
  if (!response.ok) {
    return jsonResponse(
      { error: stringValue(object.detail) ?? "Request failed." },
      response.status,
    );
  }
  return jsonResponse(object);
}

async function parseUpstreamJson(
  response: Response,
): Promise<{ data: unknown; error: Response | null }> {
  const raw = await response.text();
  try {
    return { data: raw.length > 0 ? JSON.parse(raw) : {}, error: null };
  } catch {
    console.error(
      `[recommend] cf_service returned non-JSON body ` +
        `(status=${response.status}): ${raw.slice(0, 500)}`,
    );
    return {
      data: null,
      error: jsonResponse(
        {
          error:
            `cf_service returned an unexpected response ` +
            `(status ${response.status}).`,
        },
        502,
      ),
    };
  }
}

function stringValue(value: unknown): string | null {
  if (value == null) return null;
  const normalized = String(value).trim();
  return normalized.length > 0 ? normalized : null;
}

function requiredString(value: unknown, field: string): string {
  const normalized = stringValue(value);
  if (!normalized) throw new Error(`Missing required field: ${field}`);
  return normalized;
}

function positiveInt(value: unknown, fallback: number): number {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function jsonResponse(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
