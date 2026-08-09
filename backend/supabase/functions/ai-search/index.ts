import { createClient } from "@supabase/supabase-js";
import { loadFoodCatalog } from "./food_catalog.ts";
import { findBestFoodMatch } from "./food_matcher.ts";
import {
  configuredGeminiKeys,
  configuredGeminiModels,
  requestGeminiWithFallback,
} from "./gemini_fallback.ts";
import {
  normalizeRecognition,
  unsupportedRecognition,
} from "./recognition_contract.ts";
import {
  buildGeminiRecognitionRequest,
  isGeminiSafetyBlocked,
  parseGeminiJson,
} from "./recognition_prompt.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type AiSearchPayload = {
  imageBase64?: string;
  mimeType?: string;
  fileName?: string;
  targetLanguageCode?: string;
  targetLanguageName?: string;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const geminiApiKeys = configuredGeminiKeys(Deno.env.get);
  const geminiModels = configuredGeminiModels(Deno.env.get);

  if (geminiApiKeys.length === 0) {
    return jsonResponse(
      { error: "Server is missing a GEMINI_API_KEY secret." },
      500,
    );
  }

  let payload: AiSearchPayload;
  try {
    payload = await request.json();
  } catch (_) {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  const imageBase64 = payload.imageBase64?.trim() ?? "";
  const mimeType = payload.mimeType?.trim() || "image/jpeg";
  const targetLanguageCode = payload.targetLanguageCode?.trim() || "en";
  const targetLanguageName = payload.targetLanguageName?.trim() || "English";

  if (!imageBase64) {
    return jsonResponse({ error: "imageBase64 is required." }, 400);
  }

  const geminiRequest = buildGeminiRecognitionRequest({
    imageBase64,
    mimeType,
    targetLanguageCode,
    targetLanguageName,
  });

  let geminiResult;
  try {
    geminiResult = await requestGeminiWithFallback({
      apiKeys: geminiApiKeys,
      models: geminiModels,
      body: geminiRequest,
    });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error
          ? error.message
          : "Gemini request failed.",
      },
      502,
    );
  }
  const geminiResponse = geminiResult.response;
  const geminiData = geminiResult.data as Record<string, any> | null;

  if (!geminiResponse.ok) {
    return jsonResponse(
      {
        error: geminiData?.error?.message ??
          `Gemini request failed (${geminiResponse.status}).`,
      },
      geminiResponse.status,
    );
  }

  if (isGeminiSafetyBlocked(geminiData)) {
    return jsonResponse(
      {
        ...unsupportedRecognition("unsafe_content"),
        db_match: null,
        provider: "gemini",
        model: geminiResult.model,
      },
      200,
    );
  }

  const rawText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof rawText !== "string" || rawText.trim().length === 0) {
    return jsonResponse(
      { error: "Gemini response did not contain analysis text." },
      502,
    );
  }

  let parsed: Record<string, unknown>;
  try {
    parsed = parseGeminiJson(rawText);
  } catch (_) {
    return jsonResponse(
      { error: "Gemini returned invalid JSON." },
      502,
    );
  }

  const normalized = normalizeRecognition(parsed);
  const databaseMatch = normalized.result_kind === "food"
    ? await resolveFoodDatabaseMatch({
      detectedName: normalized.detected_name,
      alternativeNames: normalized.alternative_names,
      confidence: normalized.confidence,
    })
    : null;

  return jsonResponse(
    {
      ...normalized,
      db_match: databaseMatch,
      provider: "gemini",
      model: geminiResult.model,
    },
    200,
  );
});

async function resolveFoodDatabaseMatch(input: {
  detectedName: string;
  alternativeNames: string;
  confidence: number;
}) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.warn(
      "AI Search database matching skipped: Supabase secrets missing.",
    );
    return null;
  }

  try {
    const client = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });
    const catalog = await loadFoodCatalog(client);
    return findBestFoodMatch({
      detectedName: input.detectedName,
      alternativeNames: input.alternativeNames,
      recognitionConfidence: input.confidence,
      catalog,
    });
  } catch (error) {
    console.warn(
      `AI Search database matching skipped: ${
        error instanceof Error ? error.message : String(error)
      }`,
    );
    return null;
  }
}

function jsonResponse(data: unknown, status: number) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
