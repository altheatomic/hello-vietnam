import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { normalizeRecognition } from "./recognition_contract.ts";

function rawResult(overrides: Record<string, unknown> = {}) {
  return {
    result_kind: "food",
    confidence: 0.91,
    detected_name: "Bun bo Hue",
    subtitle: "Hue beef noodle soup",
    summary: "A central Vietnamese noodle soup.",
    location_hint: "Hue",
    category_text: "Noodle soup",
    reason_code: "none",
    primary_tags: ["Beef", "Noodles"],
    secondary_tags: ["Spicy"],
    best_time: "Breakfast",
    note: "Contains shrimp paste.",
    cultural_significance: "A Hue specialty.",
    usage_bullets: [],
    production_method: "Simmered broth",
    alternative_names: "Bun bo",
    price_range: "40000-70000 VND",
    suggested_places: ["Hue"],
    map_query: "",
    can_open_map: false,
    text_analysis: {
      original_text: "",
      detected_language_code: "",
      detected_language_name: "",
      translated_text: "",
      target_language_code: "en",
      sign_type: "other",
      travel_context: "",
      map_query: "",
      can_open_map: false,
    },
    ...overrides,
  };
}

Deno.test("normalizeRecognition preserves a complete food result", () => {
  const result = normalizeRecognition(rawResult());
  assertEquals(result.result_kind, "food");
  assertEquals(result.confidence, 0.91);
  assertEquals(result.confidence_band, "confident");
  assertEquals(result.map_query, "");
  assertEquals(result.can_open_map, false);
});

Deno.test("normalizeRecognition keeps medium confidence tentative", () => {
  const result = normalizeRecognition(rawResult({ confidence: 0.64 }));
  assertEquals(result.result_kind, "food");
  assertEquals(result.confidence_band, "tentative");
});

Deno.test("normalizeRecognition converts low confidence to unclear", () => {
  const result = normalizeRecognition(rawResult({ confidence: 0.54 }));
  assertEquals(result.result_kind, "unclear");
  assertEquals(result.reason_code, "insufficient_evidence");
  assertEquals(result.suggested_places, []);
  assertEquals(result.text_analysis, null);
});

Deno.test("normalizeRecognition rejects a sign without OCR text", () => {
  const result = normalizeRecognition(rawResult({
    result_kind: "sign_text",
    detected_name: "Street sign",
    text_analysis: {
      original_text: "",
      translated_text: "Nguyen Hue Street",
      target_language_code: "en",
      sign_type: "street",
      map_query: "Nguyen Hue Street",
      can_open_map: true,
    },
  }));
  assertEquals(result.result_kind, "unclear");
  assertEquals(result.text_analysis, null);
  assertEquals(result.can_open_map, false);
});

Deno.test("normalizeRecognition accepts readable sign text", () => {
  const result = normalizeRecognition(rawResult({
    result_kind: "sign_text",
    detected_name: "DUONG NGUYEN HUE",
    text_analysis: {
      original_text: "ĐƯỜNG NGUYỄN HUỆ",
      detected_language_code: "vi",
      detected_language_name: "Vietnamese",
      translated_text: "Nguyen Hue Street",
      target_language_code: "en",
      sign_type: "street",
      travel_context: "A Vietnamese street name.",
      map_query: "Nguyen Hue Street, Vietnam",
      can_open_map: true,
    },
    map_query: "Nguyen Hue Street, Vietnam",
    can_open_map: true,
  }));
  assertEquals(result.result_kind, "sign_text");
  assertEquals(result.text_analysis?.original_text, "ĐƯỜNG NGUYỄN HUỆ");
  assertEquals(result.map_query, "Nguyen Hue Street, Vietnam");
  assertEquals(result.can_open_map, true);
});

Deno.test("promotes a misclassified street sign to the map-enabled sign flow", () => {
  const result = normalizeRecognition(rawResult({
    result_kind: "cultural_object",
    detected_name: "Vietnamese Street Sign",
    text_analysis: {
      original_text: "ĐƯỜNG NGUYỄN DU",
      detected_language_code: "vi",
      detected_language_name: "Vietnamese",
      translated_text: "Nguyen Du Street",
      target_language_code: "en",
      sign_type: "street",
      travel_context: "A Vietnamese street name.",
      map_query: "Nguyen Du Street, Vietnam",
      can_open_map: true,
    },
  }));

  assertEquals(result.result_kind, "sign_text");
  assertEquals(result.can_open_map, true);
  assertEquals(result.map_query, "Nguyen Du Street, Vietnam");
  assertEquals(result.text_analysis?.sign_type, "street");
});

Deno.test("normalizeRecognition rejects unknown result kinds", () => {
  const result = normalizeRecognition(rawResult({ result_kind: "vehicle" }));
  assertEquals(result.result_kind, "unsupported");
  assertEquals(result.reason_code, "invalid_result_kind");
  assertEquals(result.detected_name, "");
});

Deno.test("normalizeRecognition strips sensitive OCR", () => {
  const result = normalizeRecognition(rawResult({
    result_kind: "unsupported",
    reason_code: "sensitive_document",
    text_analysis: {
      original_text: "123456789",
      translated_text: "123456789",
      map_query: "",
      can_open_map: false,
    },
  }));
  assertEquals(result.text_analysis, null);
  assertEquals(result.detected_name, "");
  assertEquals(result.suggested_places, []);
});
