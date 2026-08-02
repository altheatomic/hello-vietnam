export const recognitionKinds = [
  "food",
  "landmark",
  "cultural_object",
  "sign_text",
  "unclear",
  "unsupported",
] as const;

export type RecognitionKind = typeof recognitionKinds[number];
export type ConfidenceBand = "confident" | "tentative" | "low";

export const recognitionReasonCodes = [
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
] as const;

export type RecognitionReasonCode = typeof recognitionReasonCodes[number];
export type RecognitionSignType =
  | "street"
  | "business"
  | "traffic"
  | "informational"
  | "other";

export type RecognitionTextAnalysis = {
  original_text: string;
  detected_language_code: string;
  detected_language_name: string;
  translated_text: string;
  target_language_code: string;
  sign_type: RecognitionSignType;
  travel_context: string;
  map_query: string;
  can_open_map: boolean;
};

export type NormalizedRecognition = {
  schema_version: 2;
  result_kind: RecognitionKind;
  result_type: "food" | "object";
  confidence: number;
  confidence_band: ConfidenceBand;
  detected_name: string;
  subtitle: string;
  summary: string;
  location_hint: string;
  category_text: string;
  reason_code: RecognitionReasonCode;
  primary_tags: string[];
  secondary_tags: string[];
  best_time: string;
  note: string;
  cultural_significance: string;
  usage_bullets: string[];
  production_method: string;
  alternative_names: string;
  price_range: string;
  suggested_places: string[];
  map_query: string;
  can_open_map: boolean;
  text_analysis: RecognitionTextAnalysis | null;
};

const signTypes: readonly RecognitionSignType[] = [
  "street",
  "business",
  "traffic",
  "informational",
  "other",
];

export function normalizeRecognition(
  raw: Record<string, unknown>,
): NormalizedRecognition {
  const requestedKind = readString(raw.result_kind);
  if (!recognitionKinds.includes(requestedKind as RecognitionKind)) {
    return unsupportedRecognition("invalid_result_kind");
  }

  const kind = requestedKind as RecognitionKind;
  const confidence = clampConfidence(raw.confidence);

  if (kind !== "unclear" && kind !== "unsupported" && confidence < 0.55) {
    return unclearRecognition(confidence, "insufficient_evidence");
  }

  if (kind === "unsupported") {
    const reason = readReason(raw.reason_code);
    return unsupportedRecognition(reason === "none" ? "out_of_scope" : reason);
  }

  if (kind === "unclear") {
    const reason = readReason(raw.reason_code);
    return unclearRecognition(
      confidence,
      reason === "none" ? "insufficient_evidence" : reason,
    );
  }

  const textAnalysis = kind === "sign_text"
    ? normalizeTextAnalysis(raw.text_analysis)
    : null;
  const detectedName = readString(raw.detected_name);

  if (
    (kind === "sign_text" && textAnalysis == null) ||
    (kind !== "sign_text" && detectedName.length === 0)
  ) {
    return unclearRecognition(confidence, "insufficient_evidence");
  }

  return buildSupportedRecognition({
    raw,
    kind,
    confidence,
    detectedName,
    textAnalysis,
  });
}

export function unsupportedRecognition(
  reasonCode: RecognitionReasonCode,
): NormalizedRecognition {
  return emptyRecognition({
    result_kind: "unsupported",
    confidence: 0,
    reason_code: reasonCode,
  });
}

function unclearRecognition(
  confidence: number,
  reasonCode: RecognitionReasonCode,
): NormalizedRecognition {
  return emptyRecognition({
    result_kind: "unclear",
    confidence,
    reason_code: reasonCode,
  });
}

function buildSupportedRecognition(input: {
  raw: Record<string, unknown>;
  kind: Exclude<RecognitionKind, "unclear" | "unsupported">;
  confidence: number;
  detectedName: string;
  textAnalysis: RecognitionTextAnalysis | null;
}): NormalizedRecognition {
  const { raw, kind, confidence, detectedName, textAnalysis } = input;
  const reason = readReason(raw.reason_code);
  const canUseMap = kind === "sign_text"
    ? textAnalysis?.can_open_map === true &&
      textAnalysis.map_query.length > 0
    : (kind === "landmark" || kind === "cultural_object") &&
      readBoolean(raw.can_open_map) && readString(raw.map_query).length > 0;
  const mapQuery = kind === "sign_text"
    ? (textAnalysis?.map_query ?? "")
    : canUseMap
    ? readString(raw.map_query)
    : "";

  return {
    schema_version: 2,
    result_kind: kind,
    result_type: kind === "food" ? "food" : "object",
    confidence,
    confidence_band: confidence >= 0.8 ? "confident" : "tentative",
    detected_name: detectedName,
    subtitle: readString(raw.subtitle),
    summary: readString(raw.summary),
    location_hint: readString(raw.location_hint),
    category_text: readString(raw.category_text),
    reason_code: reason,
    primary_tags: readStringArray(raw.primary_tags),
    secondary_tags: readStringArray(raw.secondary_tags),
    best_time: readString(raw.best_time),
    note: readString(raw.note),
    cultural_significance: readString(raw.cultural_significance),
    usage_bullets: readStringArray(raw.usage_bullets),
    production_method: readString(raw.production_method),
    alternative_names: readString(raw.alternative_names),
    price_range: readString(raw.price_range),
    suggested_places: readStringArray(raw.suggested_places),
    map_query: canUseMap ? mapQuery : "",
    can_open_map: canUseMap,
    text_analysis: kind === "sign_text" ? textAnalysis : null,
  };
}

function emptyRecognition(input: {
  result_kind: "unclear" | "unsupported";
  confidence: number;
  reason_code: RecognitionReasonCode;
}): NormalizedRecognition {
  return {
    schema_version: 2,
    result_kind: input.result_kind,
    result_type: "object",
    confidence: input.confidence,
    confidence_band: "low",
    detected_name: "",
    subtitle: "",
    summary: "",
    location_hint: "",
    category_text: "",
    reason_code: input.reason_code,
    primary_tags: [],
    secondary_tags: [],
    best_time: "",
    note: "",
    cultural_significance: "",
    usage_bullets: [],
    production_method: "",
    alternative_names: "",
    price_range: "",
    suggested_places: [],
    map_query: "",
    can_open_map: false,
    text_analysis: null,
  };
}

function normalizeTextAnalysis(value: unknown): RecognitionTextAnalysis | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const raw = value as Record<string, unknown>;
  const originalText = readString(raw.original_text);
  if (!originalText) return null;

  const requestedSignType = readString(raw.sign_type) as RecognitionSignType;
  const signType = signTypes.includes(requestedSignType)
    ? requestedSignType
    : "other";
  const requestedMapQuery = readString(raw.map_query);
  const canOpenMap = readBoolean(raw.can_open_map) &&
    requestedMapQuery.length > 0;

  return {
    original_text: originalText,
    detected_language_code: readString(raw.detected_language_code),
    detected_language_name: readString(raw.detected_language_name),
    translated_text: readString(raw.translated_text),
    target_language_code: readString(raw.target_language_code),
    sign_type: signType,
    travel_context: readString(raw.travel_context),
    map_query: canOpenMap ? requestedMapQuery : "",
    can_open_map: canOpenMap,
  };
}

export function readString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

export function readStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => typeof item === "string" ? item.trim() : "")
    .filter((item) => item.length > 0);
}

export function readReason(value: unknown): RecognitionReasonCode {
  const reason = readString(value) as RecognitionReasonCode;
  return recognitionReasonCodes.includes(reason)
    ? reason
    : reason.length === 0
    ? "none"
    : "invalid_model_response";
}

export function clampConfidence(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed)) return 0.5;
  return Math.max(0, Math.min(1, parsed));
}

function readBoolean(value: unknown): boolean {
  return value === true;
}
