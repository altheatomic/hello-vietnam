const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type TranslatePayload = {
  text?: string;
  sourceLanguageCode?: string;
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

  const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
  const geminiModel = Deno.env.get("GEMINI_TRANSLATE_MODEL") ?? "gemini-2.5-flash";

  if (!geminiApiKey) {
    return jsonResponse(
      { error: "Server is missing GEMINI_API_KEY secret." },
      500,
    );
  }

  let payload: TranslatePayload;
  try {
    payload = await request.json();
  } catch (_) {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
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
                `You are a translation engine for a travel app. ${sourceInstruction} Translate the user text into ${targetLanguageName} (${targetLanguageCode}). Preserve meaning, tone, formatting, numbers, proper nouns, and line breaks. Return JSON only with keys: translation and detected_source_language_code.`,
            },
          ],
        },
        generationConfig: {
          temperature: 0.2,
          responseMimeType: "application/json",
          responseSchema: {
            type: "OBJECT",
            properties: {
              translation: {
                type: "STRING",
              },
              detected_source_language_code: {
                type: "STRING",
              },
            },
            required: ["translation", "detected_source_language_code"],
          },
        },
        contents: [
          {
            parts: [
              {
                text: JSON.stringify({
                  text,
                  source_language_code: sourceLanguageCode,
                  target_language_code: targetLanguageCode,
                  target_language_name: targetLanguageName,
                }),
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
      { error: "Gemini response did not contain translation text." },
      502,
    );
  }

  let parsed: { translation?: string; detected_source_language_code?: string | null };
  try {
    parsed = parseGeminiJson(rawText);
  } catch (_) {
    return jsonResponse(
      { error: "Gemini returned invalid JSON." },
      502,
    );
  }

  if (!parsed.translation || parsed.translation.trim().length === 0) {
    return jsonResponse(
      { error: "Gemini response did not contain translation text." },
      502,
    );
  }

  return jsonResponse(
    {
      translation: parsed.translation.trim(),
      detected_source_language_code: parsed.detected_source_language_code ?? null,
      provider: "gemini",
      requested_target_language_name: targetLanguageName,
    },
    200,
  );
});

function parseGeminiJson(rawText: string) {
  try {
    return JSON.parse(rawText) as {
      translation?: string;
      detected_source_language_code?: string | null;
    };
  } catch (_) {
    const fencedMatch = rawText.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
    if (fencedMatch != null) {
      return JSON.parse(fencedMatch[1]) as {
        translation?: string;
        detected_source_language_code?: string | null;
      };
    }

    const firstBrace = rawText.indexOf("{");
    const lastBrace = rawText.lastIndexOf("}");
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      return JSON.parse(rawText.slice(firstBrace, lastBrace + 1)) as {
        translation?: string;
        detected_source_language_code?: string | null;
      };
    }

    rethrow;
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
