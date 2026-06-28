/// <reference lib="dom" />

import { createClient } from "@supabase/supabase-js";
import { corsHeaders } from "../_shared/cors.ts";

type JsonObject = Record<string, unknown>;
type AiFeature =
  | "translate"
  | "phrase_practice"
  | "report_classify"
  | "forum_moderation"
  | "admin_content"
  | "recommendation"
  | "generic";

type AiGatewayPayload = {
  feature?: AiFeature;
  input?: JsonObject;
  language?: string;
  modelMode?: "fast" | "pro";
  useCache?: boolean;
};

type FeatureConfig = {
  modelMode: "fast" | "pro";
  temperature: number;
  maxTokens: number;
  cacheTtlSeconds: number;
  systemPrompt: string;
  responseContract: string;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const DEEPSEEK_API_KEY = Deno.env.get("DEEPSEEK_API_KEY") ?? "";
const DEEPSEEK_BASE_URL = Deno.env.get("DEEPSEEK_BASE_URL") ??
  "https://api.deepseek.com";
const DEEPSEEK_FAST_MODEL = Deno.env.get("DEEPSEEK_FAST_MODEL") ??
  "deepseek-chat";
const DEEPSEEK_PRO_MODEL = Deno.env.get("DEEPSEEK_PRO_MODEL") ??
  DEEPSEEK_FAST_MODEL;
const ALLOW_ANON = (Deno.env.get("AI_GATEWAY_ALLOW_ANON") ?? "false")
  .toLowerCase() === "true";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  if (!DEEPSEEK_API_KEY) {
    return jsonResponse({ error: "Server is missing DEEPSEEK_API_KEY." }, 500);
  }

  const authHeader = request.headers.get("Authorization")?.trim() ?? "";
  const serviceClient = createServiceClient();
  const userId = await resolveUserId(authHeader);
  if (!ALLOW_ANON && !userId) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  let payload: AiGatewayPayload;
  try {
    payload = await request.json();
  } catch (_) {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  const feature = payload.feature ?? "generic";
  const input = payload.input ?? {};
  if (!isKnownFeature(feature)) {
    return jsonResponse({ error: `Unsupported AI feature: ${feature}` }, 400);
  }

  const config = configForFeature(feature, payload.modelMode);
  const model = config.modelMode === "pro" ? DEEPSEEK_PRO_MODEL : DEEPSEEK_FAST_MODEL;
  const language = cleanText(payload.language) ?? "en";
  const cacheEnabled = payload.useCache !== false && config.cacheTtlSeconds > 0;
  const cacheHash = await hashInput({ feature, input, language, model });

  if (serviceClient && cacheEnabled) {
    const cached = await readCache(serviceClient, feature, cacheHash);
    if (cached) {
      await writeUsageLog(serviceClient, {
        userId,
        feature,
        model,
        status: "cache_hit",
        inputTokens: 0,
        outputTokens: 0,
        estimatedCost: 0,
      });
      return jsonResponse({
        feature,
        provider: "deepseek",
        model,
        cached: true,
        result: cached,
      });
    }
  }

  if (serviceClient && userId) {
    const allowed = await withinDailyQuota(serviceClient, userId, feature);
    if (!allowed) {
      await writeUsageLog(serviceClient, {
        userId,
        feature,
        model,
        status: "quota_exceeded",
      });
      return jsonResponse({ error: "Daily AI quota exceeded." }, 429);
    }
  }

  try {
    const deepseek = await callDeepSeek({
      feature,
      input,
      language,
      config,
      model,
    });

    if (serviceClient && cacheEnabled) {
      await writeCache(
        serviceClient,
        feature,
        cacheHash,
        deepseek.result,
        config.cacheTtlSeconds,
      );
    }

    if (serviceClient) {
      await writeUsageLog(serviceClient, {
        userId,
        feature,
        model,
        status: "success",
        inputTokens: deepseek.inputTokens,
        outputTokens: deepseek.outputTokens,
        estimatedCost: estimateCost(model, deepseek.inputTokens, deepseek.outputTokens),
      });
    }

    return jsonResponse({
      feature,
      provider: "deepseek",
      model,
      cached: false,
      usage: {
        input_tokens: deepseek.inputTokens,
        output_tokens: deepseek.outputTokens,
      },
      result: deepseek.result,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "AI request failed.";
    if (serviceClient) {
      await writeUsageLog(serviceClient, {
        userId,
        feature,
        model,
        status: "error",
        errorMessage: message,
      });
    }
    return jsonResponse({ error: message }, 502);
  }
});

async function callDeepSeek(args: {
  feature: AiFeature;
  input: JsonObject;
  language: string;
  config: FeatureConfig;
  model: string;
}): Promise<{ result: JsonObject; inputTokens: number; outputTokens: number }> {
  const endpoint = `${DEEPSEEK_BASE_URL.replace(/\/+$/, "")}/chat/completions`;
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${DEEPSEEK_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: args.model,
      temperature: args.config.temperature,
      max_tokens: args.config.maxTokens,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content:
            `${args.config.systemPrompt}\n\n${args.config.responseContract}\nReturn JSON only. Never return markdown.`,
        },
        {
          role: "user",
          content: JSON.stringify({
            feature: args.feature,
            output_language: args.language,
            input: args.input,
          }),
        },
      ],
    }),
  });

  const raw = await response.json().catch(() => null) as JsonObject | null;
  if (!response.ok) {
    const error = readNestedString(raw, ["error", "message"]) ??
      `DeepSeek request failed (${response.status}).`;
    throw new Error(error);
  }

  const content = readNestedString(raw, ["choices", 0, "message", "content"]);
  if (!content) {
    throw new Error("DeepSeek response did not contain message content.");
  }

  let result: JsonObject;
  try {
    result = JSON.parse(content) as JsonObject;
  } catch (_) {
    result = parseJsonFromText(content);
  }

  return {
    result,
    inputTokens: numberValue(readNestedValue(raw, ["usage", "prompt_tokens"])),
    outputTokens: numberValue(readNestedValue(raw, ["usage", "completion_tokens"])),
  };
}

function configForFeature(
  feature: AiFeature,
  requestedMode?: "fast" | "pro",
): FeatureConfig {
  const configs: Record<AiFeature, FeatureConfig> = {
    translate: {
      modelMode: "fast",
      temperature: 0.2,
      maxTokens: 700,
      cacheTtlSeconds: 60 * 60 * 24 * 14,
      systemPrompt:
        "You are a precise translation assistant for a Vietnam travel app. Preserve meaning, names, numbers, formatting, and tone. Prefer natural travel-friendly wording.",
      responseContract:
        'JSON schema: {"translation": string, "detected_source_language_code": string|null, "tone": string, "notes": string[]}.',
    },
    phrase_practice: {
      modelMode: "fast",
      temperature: 0.35,
      maxTokens: 900,
      cacheTtlSeconds: 60 * 60 * 24 * 7,
      systemPrompt:
        "You coach travelers learning Vietnamese phrases. Correct grammar, explain usage simply, and provide natural alternatives.",
      responseContract:
        'JSON schema: {"corrected": string, "explanation": string, "natural_alternatives": string[], "pronunciation_hint": string|null, "formality": string}.',
    },
    report_classify: {
      modelMode: "fast",
      temperature: 0.1,
      maxTokens: 500,
      cacheTtlSeconds: 0,
      systemPrompt:
        "You classify app reports for an admin dashboard. Use only allowed categories and be conservative.",
      responseContract:
        'JSON schema: {"report_category": "content_report"|"bug_report"|"suggestion"|"account_issue"|"payment_issue", "priority": "low"|"medium"|"high"|"urgent", "summary": string, "recommended_action": string, "target_type": string|null}.',
    },
    forum_moderation: {
      modelMode: "fast",
      temperature: 0.1,
      maxTokens: 450,
      cacheTtlSeconds: 0,
      systemPrompt:
        "You moderate forum content for a travel community. Flag spam, harassment, scams, unsafe advice, and explicit content without overblocking normal travel discussion.",
      responseContract:
        'JSON schema: {"safe": boolean, "risk_level": "low"|"medium"|"high", "categories": string[], "reason": string, "suggested_action": "allow"|"review"|"hide"}.',
    },
    admin_content: {
      modelMode: "pro",
      temperature: 0.45,
      maxTokens: 1400,
      cacheTtlSeconds: 60 * 60 * 24,
      systemPrompt:
        "You help admins write polished Vietnam travel content. Use grounded, concise, non-marketing language. Do not invent exact facts if the input does not contain them.",
      responseContract:
        'JSON schema: {"title": string|null, "short_description": string, "detailed_description": string, "tags": string[], "warnings": string[]}.',
    },
    recommendation: {
      modelMode: "pro",
      temperature: 0.4,
      maxTokens: 1200,
      cacheTtlSeconds: 60 * 60,
      systemPrompt:
        "You explain travel recommendations using only the candidate items and user preferences provided. Do not invent places, prices, ratings, or schedules.",
      responseContract:
        'JSON schema: {"summary": string, "recommendations": [{"id": string|null, "name": string, "reason": string, "best_for": string[]}], "next_step": string}.',
    },
    generic: {
      modelMode: "fast",
      temperature: 0.3,
      maxTokens: 900,
      cacheTtlSeconds: 0,
      systemPrompt:
        "You are an assistant inside a Vietnam travel app. Be concise, helpful, and return structured JSON.",
      responseContract:
        'JSON schema: {"answer": string, "items": array, "metadata": object}.',
    },
  };

  const base = configs[feature];
  return requestedMode ? { ...base, modelMode: requestedMode } : base;
}

function createServiceClient() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return null;
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
}

async function resolveUserId(authHeader: string): Promise<string | null> {
  if (!authHeader || !SUPABASE_URL || !SUPABASE_ANON_KEY) return null;
  const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data, error } = await client.auth.getUser();
  if (error || !data.user?.id) return null;
  return data.user.id;
}

async function withinDailyQuota(
  client: ReturnType<typeof createClient>,
  userId: string,
  feature: AiFeature,
): Promise<boolean> {
  const limit = Number.parseInt(
    Deno.env.get(`AI_GATEWAY_${feature.toUpperCase()}_DAILY_LIMIT`) ??
      Deno.env.get("AI_GATEWAY_DEFAULT_DAILY_LIMIT") ??
      "100",
    10,
  );
  if (!Number.isFinite(limit) || limit <= 0) return true;

  const since = new Date();
  since.setUTCHours(0, 0, 0, 0);

  try {
    const { count, error } = await client
      .from("ai_usage_log")
      .select("id", { count: "exact", head: true })
      .eq("id_user", userId)
      .eq("feature", feature)
      .gte("created_at", since.toISOString());
    if (error) return true;
    return (count ?? 0) < limit;
  } catch (_) {
    return true;
  }
}

async function readCache(
  client: ReturnType<typeof createClient>,
  feature: AiFeature,
  inputHash: string,
): Promise<JsonObject | null> {
  try {
    const { data, error } = await client
      .from("ai_cache")
      .select("response_json")
      .eq("feature", feature)
      .eq("input_hash", inputHash)
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error || !data?.response_json) return null;
    return data.response_json as JsonObject;
  } catch (_) {
    return null;
  }
}

async function writeCache(
  client: ReturnType<typeof createClient>,
  feature: AiFeature,
  inputHash: string,
  responseJson: JsonObject,
  ttlSeconds: number,
): Promise<void> {
  const expiresAt = new Date(Date.now() + ttlSeconds * 1000).toISOString();
  try {
    await client.from("ai_cache").upsert({
      feature,
      input_hash: inputHash,
      response_json: responseJson,
      expires_at: expiresAt,
    }, { onConflict: "feature,input_hash" });
  } catch (_) {
    // Cache is optional; failing to write it must not break the AI response.
  }
}

async function writeUsageLog(
  client: ReturnType<typeof createClient>,
  log: {
    userId: string | null;
    feature: AiFeature;
    model: string;
    status: string;
    inputTokens?: number;
    outputTokens?: number;
    estimatedCost?: number;
    errorMessage?: string;
  },
): Promise<void> {
  try {
    await client.from("ai_usage_log").insert({
      id_user: log.userId,
      provider: "deepseek",
      feature: log.feature,
      model: log.model,
      input_tokens: log.inputTokens ?? null,
      output_tokens: log.outputTokens ?? null,
      estimated_cost: log.estimatedCost ?? null,
      status: log.status,
      error_message: log.errorMessage ?? null,
    });
  } catch (_) {
    // Usage logging is best-effort so app features remain available.
  }
}

async function hashInput(value: unknown): Promise<string> {
  const encoded = new TextEncoder().encode(stableStringify(value));
  const digest = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function stableStringify(value: unknown): string {
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`;
  }
  if (value && typeof value === "object") {
    const object = value as JsonObject;
    return `{${Object.keys(object).sort().map((key) =>
      `${JSON.stringify(key)}:${stableStringify(object[key])}`
    ).join(",")}}`;
  }
  return JSON.stringify(value);
}

function estimateCost(model: string, inputTokens: number, outputTokens: number) {
  const normalizedModel = model.toUpperCase().replaceAll("-", "_");
  const inputPerMillion = Number.parseFloat(
    Deno.env.get(`AI_COST_${normalizedModel}_INPUT_PER_1M`) ?? "0",
  );
  const outputPerMillion = Number.parseFloat(
    Deno.env.get(`AI_COST_${normalizedModel}_OUTPUT_PER_1M`) ?? "0",
  );
  return (inputTokens / 1_000_000) * inputPerMillion +
    (outputTokens / 1_000_000) * outputPerMillion;
}

function parseJsonFromText(text: string): JsonObject {
  const fencedMatch = text.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  if (fencedMatch) return JSON.parse(fencedMatch[1]) as JsonObject;
  const firstBrace = text.indexOf("{");
  const lastBrace = text.lastIndexOf("}");
  if (firstBrace >= 0 && lastBrace > firstBrace) {
    return JSON.parse(text.slice(firstBrace, lastBrace + 1)) as JsonObject;
  }
  throw new Error("DeepSeek returned invalid JSON.");
}

function readNestedValue(value: unknown, path: Array<string | number>): unknown {
  let current = value;
  for (const key of path) {
    if (Array.isArray(current) && typeof key === "number") {
      current = current[key];
    } else if (current && typeof current === "object" && typeof key === "string") {
      current = (current as JsonObject)[key];
    } else {
      return null;
    }
  }
  return current;
}

function readNestedString(value: unknown, path: Array<string | number>) {
  const nested = readNestedValue(value, path);
  return cleanText(nested);
}

function cleanText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text.length > 0 ? text : null;
}

function numberValue(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? Math.max(0, Math.trunc(parsed)) : 0;
}

function isKnownFeature(value: unknown): value is AiFeature {
  return value === "translate" ||
    value === "phrase_practice" ||
    value === "report_classify" ||
    value === "forum_moderation" ||
    value === "admin_content" ||
    value === "recommendation" ||
    value === "generic";
}

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
