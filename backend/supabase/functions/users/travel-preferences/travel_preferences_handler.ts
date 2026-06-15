/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { createClient } from "@supabase/supabase-js";

import { corsHeaders } from "../../_shared/cors.ts";
import {
  AuthorizationError,
  requireAuthenticatedUserId,
  requireAuthorizationHeader,
} from "../../auth/auth_guard.ts";

type JsonObject = Record<string, unknown>;

type TravelPreferencesPayload = {
  travelStyles: string[];
  companions: string[];
  budgetLevel: string | null;
  pace: string | null;
  topics: string[];
  completedAt: string | null;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const ONBOARDING_TABLE = "user_onboarding_choice";
const PROFILE_TABLE = "user_travel_profile";

const TRIP_STYLE_SCREEN = "trip_style";
const INTEREST_SCREEN = "specific_interest";

const TRAVEL_STYLE_TO_DB: Record<string, string> = {
  food: "food",
  culture: "culture",
  nature: "nature",
  relaxation: "relaxation",
  adventure: "adventure",
  shopping: "shopping",
  photography: "photography",
  localDiscovery: "local_discovery",
};

const TRAVEL_STYLE_FROM_DB = invertMap(TRAVEL_STYLE_TO_DB);

const COMPANION_TO_DB: Record<string, string> = {
  solo: "solo",
  couple: "couple",
  friends: "friends",
  familyKids: "family",
  seniors: "seniors",
  business: "business",
};

const COMPANION_FROM_DB = invertMap(COMPANION_TO_DB);

const BUDGET_TO_DB: Record<string, string> = {
  budget: "budget",
  moderate: "mid_range",
  comfort: "comfort",
  premium: "premium",
};

const BUDGET_FROM_DB = invertMap(BUDGET_TO_DB);

const PACE_TO_DB: Record<string, string> = {
  easy: "easy",
  balanced: "balanced",
  active: "active",
  packed: "packed",
};

const PACE_FROM_DB = invertMap(PACE_TO_DB);

const INTEREST_TO_DB: Record<string, string> = {
  streetFood: "street_food",
  coffee: "coffee",
  museums: "museums",
  temples: "temples",
  festivals: "festivals",
  beaches: "beaches",
  mountains: "mountains",
  nightMarkets: "night_markets",
  workshops: "workshops",
  handmadeProducts: "handmade_products",
  scenicSpots: "scenic_spots",
  wellness: "wellness",
};

const INTEREST_FROM_DB = invertMap(INTEREST_TO_DB);

if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error(
    "Missing required Supabase environment variables for travel-preferences function.",
  );
}

export async function handleTravelPreferencesRequest(
  req: Request,
): Promise<Response> {
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
    const service = new TravelPreferencesService(adminClient);

    switch (action) {
      case "saveTravelPreferences": {
        const preferences = parseTravelPreferencesPayload(payload.preferences);
        const saved = await service.savePreferences(userId, preferences);
        return jsonResponse({ success: true, preferences: saved });
      }
      case "getTravelPreferences": {
        const preferences = await service.getPreferences(userId);
        return jsonResponse({ preferences });
      }
      case "clearTravelPreferences": {
        await service.clearPreferences(userId);
        return jsonResponse({ success: true });
      }
      default:
        return jsonResponse({ error: `Unsupported action: ${action}` }, 400);
    }
  } catch (error) {
    if (error instanceof AuthorizationError) {
      return jsonResponse({ error: error.message }, error.statusCode);
    }
    const message = error instanceof Error ? error.message : "Unexpected error.";
    return jsonResponse({ error: message }, 500);
  }
}

class TravelPreferencesService {
  constructor(private readonly client: ReturnType<typeof createClient>) {}

  async savePreferences(
    userId: string,
    payload: TravelPreferencesPayload,
  ): Promise<JsonObject> {
    const completedAt = payload.completedAt ?? new Date().toISOString();

    const { error: profileError } = await this.client.from(PROFILE_TABLE).upsert(
      {
        id_user: userId,
        companion_style: firstMappedValue(payload.companions, COMPANION_TO_DB),
        budget_level: mappedValueOrNull(payload.budgetLevel, BUDGET_TO_DB),
        pace_level: mappedValueOrNull(payload.pace, PACE_TO_DB),
        onboarding_completed: true,
        onboarding_completed_at: completedAt,
      },
      { onConflict: "id_user" },
    );

    if (profileError) {
      throw new Error(`${PROFILE_TABLE}: ${profileError.message}`);
    }

    const { error: deleteError } = await this.client
      .from(ONBOARDING_TABLE)
      .delete()
      .eq("id_user", userId)
      .in("screen_code", [TRIP_STYLE_SCREEN, INTEREST_SCREEN]);

    if (deleteError) {
      throw new Error(`${ONBOARDING_TABLE}: ${deleteError.message}`);
    }

    const choiceRows = buildChoiceRows(userId, payload, completedAt);
    if (choiceRows.length > 0) {
      const { error: insertError } = await this.client
        .from(ONBOARDING_TABLE)
        .insert(choiceRows);
      if (insertError) {
        throw new Error(`${ONBOARDING_TABLE}: ${insertError.message}`);
      }
    }

    return (await this.getPreferences(userId)) ?? {};
  }

  async getPreferences(userId: string): Promise<JsonObject | null> {
    const { data: profile, error: profileError } = await this.client
      .from(PROFILE_TABLE)
      .select("*")
      .eq("id_user", userId)
      .maybeSingle();

    if (profileError) {
      throw new Error(`${PROFILE_TABLE}: ${profileError.message}`);
    }

    if (profile == null || profile["onboarding_completed"] != true) {
      return null;
    }

    const { data: choices, error: choicesError } = await this.client
      .from(ONBOARDING_TABLE)
      .select("screen_code, option_code")
      .eq("id_user", userId);

    if (choicesError) {
      throw new Error(`${ONBOARDING_TABLE}: ${choicesError.message}`);
    }

    const choiceRows = asRows(choices);
    const travelStyles = collectMappedOptions(
      choiceRows,
      TRIP_STYLE_SCREEN,
      TRAVEL_STYLE_FROM_DB,
    );
    const topics = collectMappedOptions(
      choiceRows,
      INTEREST_SCREEN,
      INTEREST_FROM_DB,
    );

    const companion = mappedValueFromDb(
      stringValue(profile["companion_style"]),
      COMPANION_FROM_DB,
    );
    const budget = mappedValueFromDb(
      stringValue(profile["budget_level"]),
      BUDGET_FROM_DB,
    );
    const pace = mappedValueFromDb(
      stringValue(profile["pace_level"]),
      PACE_FROM_DB,
    );
    const completedAt =
        stringValue(profile["onboarding_completed_at"]) ??
        stringValue(profile["updated_at"]) ??
        new Date().toISOString();

    return {
      "travelStyles": travelStyles,
      "companions": companion == null ? [] : [companion],
      "budgetLevel": budget ?? "moderate",
      "pace": pace ?? "balanced",
      "topics": topics,
      "completedAt": completedAt,
    };
  }

  async clearPreferences(userId: string): Promise<void> {
    const { error: deleteChoicesError } = await this.client
      .from(ONBOARDING_TABLE)
      .delete()
      .eq("id_user", userId);
    if (deleteChoicesError) {
      throw new Error(`${ONBOARDING_TABLE}: ${deleteChoicesError.message}`);
    }

    const { error: updateProfileError } = await this.client
      .from(PROFILE_TABLE)
      .upsert(
        {
          id_user: userId,
          companion_style: null,
          budget_level: null,
          pace_level: null,
          onboarding_completed: false,
          onboarding_completed_at: null,
        },
        { onConflict: "id_user" },
      );
    if (updateProfileError) {
      throw new Error(`${PROFILE_TABLE}: ${updateProfileError.message}`);
    }
  }
}

function parseTravelPreferencesPayload(
  value: unknown,
): TravelPreferencesPayload {
  if (!value || typeof value !== "object") {
    throw new Error("Missing preferences payload.");
  }

  const row = value as JsonObject;
  const travelStyles = uniqueMappedValues(
    stringList(row.travelStyles),
    TRAVEL_STYLE_TO_DB,
    "travelStyles",
  );
  const companions = uniqueMappedValues(
    stringList(row.companions),
    COMPANION_TO_DB,
    "companions",
  );
  const topics = uniqueMappedValues(
    stringList(row.topics),
    INTEREST_TO_DB,
    "topics",
  );

  const budgetLevel = stringValue(row.budgetLevel);
  if (budgetLevel != null && !hasOwn(BUDGET_TO_DB, budgetLevel)) {
    throw new Error(`Unsupported budgetLevel: ${budgetLevel}`);
  }

  const pace = stringValue(row.pace);
  if (pace != null && !hasOwn(PACE_TO_DB, pace)) {
    throw new Error(`Unsupported pace: ${pace}`);
  }

  return {
    travelStyles,
    companions,
    budgetLevel,
    pace,
    topics,
    completedAt: stringValue(row.completedAt),
  };
}

function buildChoiceRows(
  userId: string,
  payload: TravelPreferencesPayload,
  timestamp: string,
): JsonObject[] {
  const rows: JsonObject[] = [];

  for (const style of payload.travelStyles) {
    rows.push({
      id_user: userId,
      screen_code: TRIP_STYLE_SCREEN,
      option_code: TRAVEL_STYLE_TO_DB[style],
      created_at: timestamp,
      updated_at: timestamp,
    });
  }

  for (const topic of payload.topics) {
    rows.push({
      id_user: userId,
      screen_code: INTEREST_SCREEN,
      option_code: INTEREST_TO_DB[topic],
      created_at: timestamp,
      updated_at: timestamp,
    });
  }

  return rows;
}

function uniqueMappedValues(
  values: string[],
  allowed: Record<string, string>,
  fieldName: string,
): string[] {
  const output: string[] = [];
  for (const value of values) {
    if (!hasOwn(allowed, value)) {
      throw new Error(`Unsupported ${fieldName} value: ${value}`);
    }
    if (!output.includes(value)) {
      output.push(value);
    }
  }
  return output;
}

function stringList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  const output: string[] = [];
  for (const item of value) {
    const parsed = stringValue(item);
    if (parsed != null) {
      output.push(parsed);
    }
  }
  return output;
}

function collectMappedOptions(
  rows: JsonObject[],
  screenCode: string,
  mapping: Record<string, string>,
): string[] {
  const output: string[] = [];
  for (const row of rows) {
    if (stringValue(row["screen_code"]) != screenCode) {
      continue;
    }
    const optionCode = stringValue(row["option_code"]);
    const mapped = mappedValueFromDb(optionCode, mapping);
    if (mapped != null && !output.includes(mapped)) {
      output.push(mapped);
    }
  }
  return output;
}

function mappedValueOrNull(
  value: string | null,
  mapping: Record<string, string>,
): string | null {
  if (value == null) {
    return null;
  }
  return mapping[value] ?? null;
}

function mappedValueFromDb(
  value: string | null,
  mapping: Record<string, string>,
): string | null {
  if (value == null) {
    return null;
  }
  return mapping[value] ?? null;
}

function firstMappedValue(
  values: string[],
  mapping: Record<string, string>,
): string | null {
  for (const value of values) {
    const mapped = mapping[value];
    if (mapped != null) {
      return mapped;
    }
  }
  return null;
}

function hasOwn(source: Record<string, string>, key: string): boolean {
  return Object.prototype.hasOwnProperty.call(source, key);
}

function invertMap(source: Record<string, string>): Record<string, string> {
  const output: Record<string, string> = {};
  for (const [key, value] of Object.entries(source)) {
    output[value] = key;
  }
  return output;
}

function stringValue(value: unknown): string | null {
  if (value == null) return null;
  const text = String(value).trim();
  return text.length === 0 ? null : text;
}

function asRows(data: unknown): JsonObject[] {
  if (!Array.isArray(data)) {
    return [];
  }
  return data.filter((value) => !!value && typeof value === "object") as JsonObject[];
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
