/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { createClient } from "@supabase/supabase-js";

import { corsHeaders } from "../../_shared/cors.ts";

type JsonObject = Record<string, unknown>;

type LocationSource = "gps" | "manual" | "map_pin";

type UpsertLocationPreferencePayload = {
  latitude: number | null;
  longitude: number | null;
  approxAddress: string | null;
  provinceCity: string | null;
  locationSource: LocationSource;
  updatedAt: string | null;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const TABLE_NAME = "user_location_preference";

if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error(
    "Missing required Supabase environment variables for location-preference function.",
  );
}

export async function handleLocationPreferenceRequest(
  req: Request,
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const authHeader = requiredAuthHeader(req.headers.get("Authorization"));
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const userId = await requireAuthenticatedUserId(userClient);

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return jsonResponse({ error: "Invalid JSON body." }, 400);
    }

    const payload = body as JsonObject;
    const action = stringValue(payload.action);
    if (!action) {
      return jsonResponse({ error: "Missing action." }, 400);
    }

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const service = new UserLocationPreferenceService(adminClient);

    switch (action) {
      case "upsertLocationPreference": {
        const preference = parseUpsertPayload(payload.preference);
        const saved = await service.upsertPreference(userId, preference);
        return jsonResponse({ success: true, preference: saved });
      }
      case "getLatestLocationPreference": {
        const preference = await service.getLatestPreference(userId);
        return jsonResponse({ preference });
      }
      default:
        return jsonResponse({ error: `Unsupported action: ${action}` }, 400);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error.";
    const status = message.toLowerCase().includes("unauthorized") ? 401 : 500;
    return jsonResponse({ error: message }, status);
  }
}

class UserLocationPreferenceService {
  constructor(private readonly client: ReturnType<typeof createClient>) {}

  async upsertPreference(
    userId: string,
    payload: UpsertLocationPreferencePayload,
  ): Promise<JsonObject> {
    const { data, error } = await this.client
      .from(TABLE_NAME)
      .upsert(
        {
          id_user: userId,
          latitude: payload.latitude,
          longitude: payload.longitude,
          approx_address: payload.approxAddress,
          province_city: payload.provinceCity,
          location_source: payload.locationSource,
          updated_at: payload.updatedAt ?? new Date().toISOString(),
        },
        { onConflict: "id_user" },
      )
      .select("*")
      .single();

    if (error) {
      throw new Error(`${TABLE_NAME}: ${error.message}`);
    }
    return (data ?? {}) as JsonObject;
  }

  async getLatestPreference(userId: string): Promise<JsonObject | null> {
    const { data, error } = await this.client
      .from(TABLE_NAME)
      .select("*")
      .eq("id_user", userId)
      .limit(1)
      .maybeSingle();

    if (error) {
      throw new Error(`${TABLE_NAME}: ${error.message}`);
    }
    if (!data) return null;
    return data as JsonObject;
  }
}

function parseUpsertPayload(value: unknown): UpsertLocationPreferencePayload {
  if (!value || typeof value !== "object") {
    throw new Error("Missing preference payload.");
  }

  const row = value as JsonObject;
  const source = requiredLocationSource(row.locationSource);

  return {
    latitude: numberOrNull(row.latitude),
    longitude: numberOrNull(row.longitude),
    approxAddress: stringOrNull(row.approxAddress),
    provinceCity: stringOrNull(row.provinceCity),
    locationSource: source,
    updatedAt: stringOrNull(row.updatedAt),
  };
}

function requiredAuthHeader(value: string | null): string {
  const token = value?.trim();
  if (!token) {
    throw new Error("Unauthorized: missing Authorization header.");
  }
  return token;
}

async function requireAuthenticatedUserId(
  client: ReturnType<typeof createClient>,
): Promise<string> {
  const {
    data: { user },
    error,
  } = await client.auth.getUser();
  if (error || !user?.id) {
    throw new Error("Unauthorized.");
  }
  return user.id;
}

function requiredLocationSource(value: unknown): LocationSource {
  const parsed = stringValue(value)?.toLowerCase();
  if (parsed === "gps" || parsed === "manual" || parsed === "map_pin") {
    return parsed;
  }
  throw new Error(
    'locationSource must be one of "gps", "manual", "map_pin".',
  );
}

function numberOrNull(value: unknown): number | null {
  if (value == null) return null;
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  const parsed = Number(String(value));
  return Number.isFinite(parsed) ? parsed : null;
}

function stringOrNull(value: unknown): string | null {
  const parsed = stringValue(value);
  return parsed ?? null;
}

function stringValue(value: unknown): string | null {
  if (value == null) return null;
  const text = String(value).trim();
  return text.length === 0 ? null : text;
}

function jsonResponse(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
