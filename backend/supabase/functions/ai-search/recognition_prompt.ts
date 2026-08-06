import { recognitionKinds } from "./recognition_contract.ts";

export type GeminiRecognitionRequestInput = {
  imageBase64: string;
  mimeType: string;
  targetLanguageCode: string;
  targetLanguageName: string;
};

const commonProperties = {
  schema_version: { type: "INTEGER" },
  result_kind: {
    type: "STRING",
    enum: [...recognitionKinds],
  },
  confidence: { type: "NUMBER" },
  detected_name: { type: "STRING" },
  subtitle: { type: "STRING" },
  summary: { type: "STRING" },
  location_hint: { type: "STRING" },
  category_text: { type: "STRING" },
  reason_code: {
    type: "STRING",
    enum: [
      "none",
      "low_quality",
      "no_clear_subject",
      "insufficient_evidence",
      "out_of_scope",
      "person_or_selfie",
      "sensitive_document",
      "unsafe_content",
      "invalid_result_kind",
      "invalid_model_response",
    ],
  },
  primary_tags: {
    type: "ARRAY",
    items: { type: "STRING" },
  },
  secondary_tags: {
    type: "ARRAY",
    items: { type: "STRING" },
  },
  best_time: { type: "STRING" },
  note: { type: "STRING" },
  cultural_significance: { type: "STRING" },
  usage_bullets: {
    type: "ARRAY",
    items: { type: "STRING" },
  },
  production_method: { type: "STRING" },
  alternative_names: { type: "STRING" },
  price_range: { type: "STRING" },
  suggested_places: {
    type: "ARRAY",
    items: { type: "STRING" },
  },
  map_query: { type: "STRING" },
  can_open_map: { type: "BOOLEAN" },
  text_analysis: {
    type: "OBJECT",
    properties: {
      original_text: { type: "STRING" },
      detected_language_code: { type: "STRING" },
      detected_language_name: { type: "STRING" },
      translated_text: { type: "STRING" },
      target_language_code: { type: "STRING" },
      sign_type: {
        type: "STRING",
        enum: ["street", "business", "traffic", "informational", "other"],
      },
      travel_context: { type: "STRING" },
      map_query: { type: "STRING" },
      can_open_map: { type: "BOOLEAN" },
    },
    required: [
      "original_text",
      "detected_language_code",
      "detected_language_name",
      "translated_text",
      "target_language_code",
      "sign_type",
      "travel_context",
      "map_query",
      "can_open_map",
    ],
  },
};

export const recognitionResponseSchema = {
  type: "OBJECT",
  properties: commonProperties,
  required: [
    "schema_version",
    "result_kind",
    "confidence",
    "detected_name",
    "subtitle",
    "summary",
    "location_hint",
    "category_text",
    "reason_code",
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
    "map_query",
    "can_open_map",
    "text_analysis",
  ],
};

export function buildGeminiRecognitionRequest(
  input: GeminiRecognitionRequestInput,
): Record<string, unknown> {
  return {
    system_instruction: {
      parts: [{
        text: [
          "You are the image recognition router for a Vietnam travel app.",
          "Return only the required JSON schema.",
          "Choose exactly one supported result_kind.",
          "Supported results are Vietnamese or travel-relevant food, landmarks, cultural objects, and readable signs or street names.",
          "If the image contains readable text naming a street, road, avenue, or intersection, choose result_kind sign_text (not cultural_object), set text_analysis.sign_type to street, and provide a concise map_query with can_open_map true when the name is sufficiently readable.",
          "Keep location_hint to a short region or city label; put full explanations in summary or travel_context.",
          "Ordinary unrelated objects, people, selfies, identity documents, payment cards, and unsafe content are unsupported.",
          "Never identify a person and never transcribe sensitive documents.",
          "Use honest confidence. Do not fill irrelevant category fields or invent facts.",
          `Translate readable sign text into ${input.targetLanguageName} (${input.targetLanguageCode}).`,
          "A sign map_query is only a search query for the named place or text; never infer or claim the user's current location.",
          "If the image is blurry, has no clear subject, has unreadable text, or lacks evidence, return unclear with the appropriate reason_code.",
        ].join(" "),
      }],
    },
    generationConfig: {
      temperature: 0.2,
      responseMimeType: "application/json",
      responseSchema: recognitionResponseSchema,
    },
    contents: [{
      parts: [
        { inline_data: { mime_type: input.mimeType, data: input.imageBase64 } },
        { text: "Classify and analyze this image for the travel app." },
      ],
    }],
  };
}

export function isGeminiSafetyBlocked(data: unknown): boolean {
  if (data == null || typeof data !== "object" || Array.isArray(data)) {
    return false;
  }

  const record = data as Record<string, unknown>;
  const promptFeedback = record.promptFeedback;
  if (
    isRecord(promptFeedback) &&
    normalizeReason(promptFeedback.blockReason) === "SAFETY"
  ) {
    return true;
  }

  const candidates = record.candidates;
  if (!Array.isArray(candidates)) return false;
  return candidates.some((candidate) =>
    isRecord(candidate) &&
    normalizeReason(candidate.finishReason) === "SAFETY"
  );
}

export function parseGeminiJson(rawText: string): Record<string, unknown> {
  const trimmed = rawText.trim();
  if (!trimmed) throw new Error("Invalid JSON");

  try {
    return parseObject(JSON.parse(trimmed));
  } catch (_) {
    const fencedMatch = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
    if (fencedMatch != null) {
      try {
        return parseObject(JSON.parse(fencedMatch[1]));
      } catch (_) {
        throw new Error("Invalid JSON");
      }
    }

    const firstBrace = trimmed.indexOf("{");
    const lastBrace = trimmed.lastIndexOf("}");
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      try {
        return parseObject(
          JSON.parse(trimmed.slice(firstBrace, lastBrace + 1)),
        );
      } catch (_) {
        throw new Error("Invalid JSON");
      }
    }

    throw new Error("Invalid JSON");
  }
}

function parseObject(value: unknown): Record<string, unknown> {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Invalid JSON");
  }
  return value as Record<string, unknown>;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function normalizeReason(value: unknown): string {
  return typeof value === "string" ? value.trim().toUpperCase() : "";
}
