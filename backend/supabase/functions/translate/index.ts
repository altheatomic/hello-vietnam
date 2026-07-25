import { createClient } from "npm:@supabase/supabase-js@2";
import {
  synthesizeVbeeSpeech,
  VbeeTtsError,
} from "../_shared/vbee_tts.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type TranslatePayload = {
  action?: "translate" | "tts";
  text?: string;
  sourceLanguageCode?: string;
  targetLanguageCode?: string;
  targetLanguageName?: string;
  languageCode?: string;
  languageName?: string;
};

type JsonObject = Record<string, unknown>;

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let payload: TranslatePayload;
  try {
    payload = await request.json();
  } catch (_) {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  const authResult = await authenticate(request);
  if (authResult instanceof Response) return authResult;

  const limitResult = await applyRateLimit(authResult.supabase, authResult.userId);
  if (limitResult instanceof Response) return limitResult;

  if (payload.action === "tts") {
    return handleTextToSpeech(payload);
  }

  return handleTranslation(payload);
});

async function authenticate(request: Request) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Missing Authorization header." }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !supabaseServiceKey) {
    return jsonResponse({ error: "Missing Supabase configuration." }, 500);
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);
  const token = authHeader.replace(/^Bearer\s+/i, "");
  const { data: userData, error: userError } = await supabase.auth.getUser(token);
  if (userError || !userData?.user) {
    return jsonResponse({ error: "Invalid token or user not found." }, 401);
  }

  return { supabase, userId: userData.user.id };
}

async function applyRateLimit(
  supabase: ReturnType<typeof createClient<any>>,
  userId: string,
) {
  const { data: limitData, error: limitError } = await supabase
    .from("user_translation_limits")
    .select("*")
    .eq("user_id", userId)
    .single();

  const now = new Date();
  const today = now.toISOString().split("T")[0];
  let requestsThisMinute = 1;
  let requestsToday = 1;

  if (limitData && !limitError) {
    const lastRequest = new Date(String(limitData.last_request_time));
    const lastResetDate = String(limitData.last_reset_date);
    const diffMs = now.getTime() - lastRequest.getTime();
    const diffMinutes = Math.floor(diffMs / 1000 / 60);

    requestsToday = lastResetDate !== today
      ? 1
      : Number(limitData.requests_today ?? 0) + 1;
    requestsThisMinute = diffMinutes >= 1
      ? 1
      : Number(limitData.requests_this_minute ?? 0) + 1;

    if (requestsToday > 200) {
      return jsonResponse({ error: "Daily limit exceeded (200 requests/day)." }, 429);
    }

    if (requestsThisMinute > 30) {
      return jsonResponse({ error: "Rate limit exceeded (30 requests/min)." }, 429);
    }

    await supabase.from("user_translation_limits").update({
      last_request_time: now.toISOString(),
      requests_this_minute: requestsThisMinute,
      requests_today: requestsToday,
      last_reset_date: today,
    }).eq("user_id", userId);
  } else {
    await supabase.from("user_translation_limits").insert({
      user_id: userId,
      last_request_time: now.toISOString(),
      requests_this_minute: 1,
      requests_today: 1,
      last_reset_date: today,
    });
  }

  return null;
}

async function handleTranslation(payload: TranslatePayload) {
  const deepseekApiKey = Deno.env.get("DEEPSEEK_API_KEY");
  const deepseekModel = Deno.env.get("DEEPSEEK_TRANSLATE_MODEL") ??
    "deepseek-chat";

  if (!deepseekApiKey) {
    return jsonResponse(
      { error: "Server is missing DEEPSEEK_API_KEY secret." },
      500,
    );
  }

  const text = payload.text?.trim() ?? "";
  const sourceLanguageCode = payload.sourceLanguageCode?.trim() ?? "auto";
  const targetLanguageCode = payload.targetLanguageCode?.trim() ?? "";
  const targetLanguageName = payload.targetLanguageName?.trim() ?? "Vietnamese";

  if (!text) {
    return jsonResponse({ error: "Text is required." }, 400);
  }

  if (!targetLanguageCode) {
    return jsonResponse({ error: "Target language is required." }, 400);
  }

  const sourceInstruction = sourceLanguageCode === "auto"
    ? "Detect the source language automatically."
    : `The source language is ${sourceLanguageCode}.`;

  const systemMessage =
    `You are a translation engine for a travel app. ${sourceInstruction} Translate the user text into ${targetLanguageName} (${targetLanguageCode}). Preserve meaning, tone, formatting, numbers, proper nouns, and line breaks. Return JSON only with keys: 'translation' and 'detected_source_language_code'. Do not use markdown blocks.`;

  const deepseekResponse = await fetch(
    "https://api.deepseek.com/v1/chat/completions",
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${deepseekApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: deepseekModel,
        messages: [
          { role: "system", content: systemMessage },
          { role: "user", content: `Translate this:\n\n${text}` },
        ],
        temperature: 0.2,
        response_format: { type: "json_object" },
      }),
    },
  );

  const data = await deepseekResponse.json();
  if (!deepseekResponse.ok) {
    return jsonResponse(
      {
        error: readErrorMessage(data) ??
          `DeepSeek request failed (${deepseekResponse.status}).`,
      },
      deepseekResponse.status,
    );
  }

  const rawText = data?.choices?.[0]?.message?.content;
  if (typeof rawText !== "string" || rawText.trim().length === 0) {
    return jsonResponse(
      { error: "DeepSeek response did not contain translation text." },
      502,
    );
  }

  let parsed: { translation?: string; detected_source_language_code?: string | null };
  try {
    parsed = JSON.parse(rawText);
  } catch (_) {
    return jsonResponse({ error: "DeepSeek returned invalid JSON." }, 502);
  }

  if (!parsed.translation || parsed.translation.trim().length === 0) {
    return jsonResponse(
      { error: "DeepSeek response did not contain translation text." },
      502,
    );
  }

  return jsonResponse(
    {
      translation: parsed.translation.trim(),
      detected_source_language_code:
        parsed.detected_source_language_code ?? null,
      provider: "deepseek",
      requested_target_language_name: targetLanguageName,
    },
    200,
  );
}

async function handleTextToSpeech(payload: TranslatePayload) {
  const vbeeApiKey = Deno.env.get("VBEE_API_KEY");
  if (!vbeeApiKey) {
    return jsonResponse({ error: "Server is missing VBEE_API_KEY secret." }, 500);
  }

  const text = payload.text?.trim() ?? "";
  const languageCode = payload.languageCode?.trim() ?? "vi";
  if (!text) {
    return jsonResponse({ error: "Text is required." }, 400);
  }

  const voiceCode = voiceCodeForLanguage(languageCode);
  if (!voiceCode) {
    const languageName = payload.languageName?.trim() ?? languageCode;
    return jsonResponse(
      { error: `Server is missing VBEE_VOICE_CODE for ${languageName}.` },
      500,
    );
  }

  const baseUrl = (Deno.env.get("VBEE_BASE_URL") ?? "https://vbee.vn")
    .replace(/\/+$/, "");
  const appId = Deno.env.get("VBEE_APP_ID") ?? vbeeApiKey;
  const callbackUrl = Deno.env.get("VBEE_CALLBACK_URL") ??
    "https://example.com/vbee-callback";
  const speedRate = Deno.env.get("VBEE_SPEED_RATE") ?? "1.0";
  const bitrate = Deno.env.get("VBEE_BITRATE") ?? "128";
  const normalizedLanguageCode = localeFor(languageCode);

  try {
    const result = await synthesizeVbeeSpeech(
      { text, languageCode: normalizedLanguageCode },
      {
        apiKey: vbeeApiKey,
        appId,
        baseUrl,
        pollIntervalMs: 750,
        maxPollAttempts: 8,
        vietnameseVoiceCode: normalizedLanguageCode.startsWith("vi-")
          ? voiceCode
          : undefined,
        englishVoiceCode: normalizedLanguageCode.startsWith("en-")
          ? voiceCode
          : undefined,
        defaultVoiceCode: voiceCode,
        voiceCodes: { [normalizedLanguageCode]: voiceCode },
        callbackUrl,
        speedRate,
        bitrate,
      },
    );

    return jsonResponse({
      audio_url: result.audioUrl,
      provider: "vbee",
      request_id: result.requestId || null,
    }, 200);
  } catch (error) {
    if (error instanceof VbeeTtsError) {
      return jsonResponse({ error: error.message }, error.statusCode);
    }
    return jsonResponse({ error: "Vbee TTS request failed." }, 502);
  }
}

function voiceCodeForLanguage(languageCode: string) {
  const normalized = localeFor(languageCode);
  const langKey = normalized.split("-")[0].toUpperCase();
  const exactKey = normalized.replace(/-/g, "_").toUpperCase();

  return Deno.env.get(`VBEE_${exactKey}_VOICE_CODE`) ??
    Deno.env.get(`VBEE_${langKey}_VOICE_CODE`) ??
    (normalized.startsWith("vi-")
      ? Deno.env.get("VBEE_VOICE_CODE") ??
        "hn_female_ngochuyen_full_48k-fhg"
      : Deno.env.get("VBEE_VOICE_CODE"));
}

function localeFor(languageCode: string) {
  const code = languageCode.replaceAll("_", "-").trim();
  if (code.includes("-")) return code.toLowerCase();

  switch (code.toLowerCase()) {
    case "vi":
      return "vi-vn";
    case "en":
      return "en-us";
    case "zh":
      return "zh-cn";
    case "ja":
      return "ja-jp";
    case "ko":
      return "ko-kr";
    default:
      return code.toLowerCase();
  }
}

function readErrorMessage(data: unknown): string | null {
  const object = readObject(data);
  const nestedError = readObject(object?.error);
  const message = object?.message ?? object?.error_message ??
    object?.errorMessage ?? nestedError?.message;
  return typeof message === "string" && message.trim().length > 0
    ? message.trim()
    : null;
}

function readObject(value: unknown): JsonObject | null {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonObject
    : null;
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
