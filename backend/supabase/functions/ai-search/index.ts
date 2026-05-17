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
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
  const geminiModel = Deno.env.get("GEMINI_AI_SEARCH_MODEL") ??
    "gemini-2.5-flash";

  if (!geminiApiKey) {
    return jsonResponse(
      { error: "Server is missing GEMINI_API_KEY secret." },
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

  if (!imageBase64) {
    return jsonResponse({ error: "imageBase64 is required." }, 400);
  }

  const geminiResponse = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${geminiModel}:generateContent`,
    {
      method: "POST",
      headers: {
        "x-goog-api-key": geminiApiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        system_instruction: {
          parts: [
            {
              text:
                "You are an AI recognition engine for a Vietnam travel app. Analyze the uploaded image and return concise, useful JSON only. Classify the image as either food or object. If it is Vietnamese or likely found in Vietnam, infer likely origin, cultural context, ingredients/materials, and suggested places to try, buy, or see it in Vietnam. Never return markdown. If unsure, still return your best guess with lower confidence.",
            },
          ],
        },
        generationConfig: {
          temperature: 0.3,
          responseMimeType: "application/json",
          responseSchema: {
            type: "OBJECT",
            properties: {
              result_type: {
                type: "STRING",
              },
              confidence: {
                type: "NUMBER",
              },
              detected_name: {
                type: "STRING",
              },
              subtitle: {
                type: "STRING",
              },
              summary: {
                type: "STRING",
              },
              location_hint: {
                type: "STRING",
              },
              category_text: {
                type: "STRING",
              },
              primary_tags: {
                type: "ARRAY",
                items: { type: "STRING" },
              },
              secondary_tags: {
                type: "ARRAY",
                items: { type: "STRING" },
              },
              best_time: {
                type: "STRING",
              },
              note: {
                type: "STRING",
              },
              cultural_significance: {
                type: "STRING",
              },
              usage_bullets: {
                type: "ARRAY",
                items: { type: "STRING" },
              },
              production_method: {
                type: "STRING",
              },
              alternative_names: {
                type: "STRING",
              },
              price_range: {
                type: "STRING",
              },
              suggested_places: {
                type: "ARRAY",
                items: { type: "STRING" },
              },
            },
            required: [
              "result_type",
              "confidence",
              "detected_name",
              "subtitle",
              "summary",
              "location_hint",
              "category_text",
              "primary_tags",
              "secondary_tags",
              "best_time",
              "note",
              "cultural_significance",
              "usage_bullets",
              "production_method",
              "alternative_names",
              "price_range",
              "suggested_places",
            ],
          },
        },
        contents: [
          {
            parts: [
              {
                inline_data: {
                  mime_type: mimeType,
                  data: imageBase64,
                },
              },
              {
                text:
                  "Identify the image and respond with fields suitable for a travel discovery app UI. Use result_type food for dishes/drinks/ingredients and object for crafts, clothing, tools, souvenirs, cultural objects, or landmarks.",
              },
            ],
          },
        ],
      }),
    },
  );

  const geminiData = await geminiResponse.json();

  if (!geminiResponse.ok) {
    return jsonResponse(
      {
        error:
          geminiData?.error?.message ??
          `Gemini request failed (${geminiResponse.status}).`,
      },
      geminiResponse.status,
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

  return jsonResponse(
    {
      result_type: normalizeResultType(parsed.result_type),
      confidence: clampConfidence(parsed.confidence),
      detected_name: readString(parsed.detected_name),
      subtitle: readString(parsed.subtitle),
      summary: readString(parsed.summary),
      location_hint: readString(parsed.location_hint),
      category_text: readString(parsed.category_text),
      primary_tags: readStringArray(parsed.primary_tags),
      secondary_tags: readStringArray(parsed.secondary_tags),
      best_time: readString(parsed.best_time),
      note: readString(parsed.note),
      cultural_significance: readString(parsed.cultural_significance),
      usage_bullets: readStringArray(parsed.usage_bullets),
      production_method: readString(parsed.production_method),
      alternative_names: readString(parsed.alternative_names),
      price_range: readString(parsed.price_range),
      suggested_places: readStringArray(parsed.suggested_places),
      provider: "gemini",
      model: geminiModel,
    },
    200,
  );
});

function normalizeResultType(value: unknown) {
  const raw = readString(value).toLowerCase();
  return raw === "food" ? "food" : "object";
}

function clampConfidence(value: unknown) {
  const parsed = typeof value === "number" ? value : Number(value);
  if (Number.isNaN(parsed)) return 0.5;
  return Math.max(0, Math.min(1, parsed));
}

function readString(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function readStringArray(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => typeof item === "string" ? item.trim() : "")
    .filter((item) => item.length > 0);
}

function parseGeminiJson(rawText: string) {
  try {
    return JSON.parse(rawText) as Record<string, unknown>;
  } catch (_) {
    const fencedMatch = rawText.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
    if (fencedMatch != null) {
      return JSON.parse(fencedMatch[1]) as Record<string, unknown>;
    }

    const firstBrace = rawText.indexOf("{");
    const lastBrace = rawText.lastIndexOf("}");
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      return JSON.parse(
        rawText.slice(firstBrace, lastBrace + 1),
      ) as Record<string, unknown>;
    }

    throw new Error("Invalid JSON");
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
