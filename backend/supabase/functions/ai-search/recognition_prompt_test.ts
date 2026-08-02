import {
  assert,
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildGeminiRecognitionRequest,
  isGeminiSafetyBlocked,
  parseGeminiJson,
} from "./recognition_prompt.ts";

Deno.test("Gemini request contains the closed result kind enum", () => {
  const body = buildGeminiRecognitionRequest({
    imageBase64: "AQID",
    mimeType: "image/jpeg",
    targetLanguageCode: "en",
    targetLanguageName: "English",
  });
  const serialized = JSON.stringify(body);
  for (
    const kind of [
      "food",
      "landmark",
      "cultural_object",
      "sign_text",
      "unclear",
      "unsupported",
    ]
  ) {
    assert(serialized.includes(kind));
  }
  assert(serialized.includes("English"));
  assertEquals(serialized.includes("latitude"), false);
  assertEquals(serialized.includes("longitude"), false);
});

Deno.test("Gemini request carries exactly one inline image", () => {
  const body = buildGeminiRecognitionRequest({
    imageBase64: "AQID",
    mimeType: "image/png",
    targetLanguageCode: "vi",
    targetLanguageName: "Vietnamese",
  });
  const contents = body.contents as Array<Record<string, unknown>>;
  const parts = contents[0].parts as Array<Record<string, unknown>>;
  assertEquals(parts.filter((part) => "inline_data" in part).length, 1);
});

Deno.test("Gemini safety metadata is detected without response text", () => {
  assertEquals(
    isGeminiSafetyBlocked({
      promptFeedback: { blockReason: "SAFETY" },
    }),
    true,
  );
  assertEquals(
    isGeminiSafetyBlocked({
      candidates: [{ finishReason: "SAFETY" }],
    }),
    true,
  );
});

Deno.test("malformed Gemini JSON is rejected", () => {
  assertThrows(() => parseGeminiJson("not-json"), Error, "Invalid JSON");
});
