# Travel-Aware AI Image Recognition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route uploaded travel images into safe, typed Food, Landmark, Cultural Object, Sign Text, Unclear, or Unsupported results while preserving the existing AI Recognition UI and requesting GPS only after a map action.

**Architecture:** Keep one Gemini request in the Supabase `ai-search` Edge Function, but move prompt construction and result normalization into pure TypeScript modules. Flutter receives schema v2 through a typed domain model, renders category-specific sections inside the existing result shell, persists only useful results, and delegates on-demand map/TTS/copy behavior to injected, testable collaborators.

**Tech Stack:** Supabase Edge Functions, Deno TypeScript, Gemini structured JSON, Flutter 3.41/Dart 3.11, `image_picker`, `shared_preferences`, `geolocator`, `url_launcher`, `audioplayers`, and Flutter widget tests.

## Global Constraints

- Make exactly one Gemini image-analysis request per recognition attempt.
- `result_kind` is limited to `food`, `landmark`, `cultural_object`, `sign_text`, `unclear`, and `unsupported`.
- Confidence `>= 0.80` is confident, `0.55-0.79` is tentative, and `< 0.55` becomes `unclear`.
- Never request or send GPS during image analysis; request it only after a map or directions tap.
- Preserve the existing AI Recognition colors, typography, hero, cards, spacing, and navigation.
- Do not identify people or extract/store OCR from identity documents, payment cards, unsafe content, or other sensitive documents.
- Keep existing Food database matching and its independent thresholds unchanged.
- Keep old local `food`/`object` history readable and retain the current history storage key.
- Do not add a Supabase migration or a new Flutter dependency.
- Backend tests must not make live Gemini requests.
- Do not add `.superpowers/` visual-companion files to product commits.
- Deno is not currently installed on this workstation; install or expose a Deno runtime before executing backend test commands. Do not skip the backend tests.

## File Structure

### Backend

- Create `backend/supabase/functions/ai-search/recognition_contract.ts` for result types, reason codes, confidence gates, category completeness rules, and safe normalization.
- Create `backend/supabase/functions/ai-search/recognition_contract_test.ts` for pure normalization tests.
- Create `backend/supabase/functions/ai-search/recognition_prompt.ts` for the Gemini system instruction, structured response schema, and request body builder.
- Create `backend/supabase/functions/ai-search/recognition_prompt_test.ts` for prompt/schema contract tests.
- Modify `backend/supabase/functions/ai-search/index.ts:10-327` so it parses language inputs, performs one Gemini call through the builder, handles safety blocks, normalizes the response, and attaches Food matches only to normalized Food results.

### Flutter domain and data

- Create `frontend/lib/features/ai_search/domain/ai_recognition_result.dart` for `AiRecognitionKind`, `AiRecognitionTextAnalysis`, `AiSearchResult`, and `AiSearchDatabaseMatch`.
- Modify `frontend/lib/features/ai_search/data/ai_search_service.dart:1-237` so it contains only transport/error mapping and sends the target language.
- Modify `frontend/lib/features/ai_search/data/ai_recognition_history_repository.dart:9-149` to import the domain model and refuse ineligible history results.
- Modify AI Search data/history tests to cover schema v2 and legacy history.

### Flutter actions and presentation

- Modify `frontend/lib/core/utils/maps_launcher.dart:1-29` to expose pure query URI builders and boolean launch results while preserving coordinate APIs.
- Create `frontend/lib/features/ai_search/application/ai_recognition_map_coordinator.dart` for permission preparation and query launch behavior.
- Create `frontend/test/features/ai_search/application/ai_recognition_map_coordinator_test.dart` and `frontend/test/core/utils/maps_launcher_test.dart`.
- Create `frontend/lib/features/ai_search/presentation/widgets/ai_recognition_result_sections.dart` for category-specific detail cards and fallback states.
- Create `frontend/test/features/ai_search/presentation/ai_recognition_result_sections_test.dart`.
- Modify `frontend/lib/features/ai_search/presentation/ai_search_page.dart:14-1282` to use one result state, pass the target language, route result sections, coordinate map/copy/TTS actions, and preserve the current shell.
- Modify `frontend/lib/features/ai_search/presentation/ai_recognition_history_page.dart:191-311` to display the new category labels safely.
- Modify `frontend/lib/core/language/app_language.dart:1150-1205` with the new user-visible AI Recognition strings.
- Create `frontend/test/features/ai_search/presentation/ai_search_result_routing_test.dart` for page-level routing, history, and deferred-location assertions.

---

### Task 1: Normalize the Backend Recognition Contract

**Files:**
- Create: `backend/supabase/functions/ai-search/recognition_contract.ts`
- Create: `backend/supabase/functions/ai-search/recognition_contract_test.ts`

**Interfaces:**
- Consumes: raw parsed Gemini JSON as `Record<string, unknown>`.
- Produces: `normalizeRecognition(raw: Record<string, unknown>): NormalizedRecognition`.
- Produces: `unsupportedRecognition(reasonCode: RecognitionReasonCode): NormalizedRecognition`.
- Produces: `RecognitionKind`, `RecognitionReasonCode`, `RecognitionTextAnalysis`, and `NormalizedRecognition` exported types.

- [ ] **Step 1: Write failing contract tests for supported, tentative, unclear, and unsupported results**

```ts
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
});

Deno.test("normalizeRecognition rejects unknown result kinds", () => {
  const result = normalizeRecognition(rawResult({ result_kind: "vehicle" }));
  assertEquals(result.result_kind, "unsupported");
  assertEquals(result.reason_code, "invalid_result_kind");
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
});
```

- [ ] **Step 2: Run the contract tests and verify RED**

```powershell
deno test backend/supabase/functions/ai-search/recognition_contract_test.ts
```

Expected: FAIL because `recognition_contract.ts` and `normalizeRecognition` do not exist.

- [ ] **Step 3: Implement the typed normalizer and safe fallback constructors**

```ts
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
export type RecognitionReasonCode =
  | "none"
  | "low_quality"
  | "no_clear_subject"
  | "insufficient_evidence"
  | "out_of_scope"
  | "person_or_selfie"
  | "sensitive_document"
  | "unsafe_content"
  | "invalid_result_kind"
  | "invalid_model_response";

export type RecognitionTextAnalysis = {
  original_text: string;
  detected_language_code: string;
  detected_language_name: string;
  translated_text: string;
  target_language_code: string;
  sign_type: "street" | "business" | "traffic" | "informational" | "other";
  travel_context: string;
  map_query: string;
  can_open_map: boolean;
};

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
    return unsupportedRecognition(readReason(raw.reason_code));
  }
  if (kind === "unclear") {
    return unclearRecognition(confidence, readReason(raw.reason_code));
  }
  const textAnalysis = kind === "sign_text"
    ? normalizeTextAnalysis(raw.text_analysis)
    : null;
  const detectedName = readString(raw.detected_name);
  if ((kind === "sign_text" && textAnalysis == null) ||
      (kind !== "sign_text" && detectedName.length === 0)) {
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
```

Define `NormalizedRecognition` with every schema field listed in the design.
It also includes common `map_query: string` and `can_open_map: boolean` fields
so Landmark and Cultural Object results can expose verified map actions. For a
Sign Text result, copy these values from normalized `text_analysis`; Food,
Unclear, and Unsupported always use an empty query and `false`.
Implement `readString`, `readStringArray`, `readReason`, `clampConfidence`,
`normalizeTextAnalysis`, `buildSupportedRecognition`, `unclearRecognition`, and
`unsupportedRecognition` in the same module. Both fallback constructors clear
category details and `text_analysis`; `unsupportedRecognition` uses confidence
`0` and legacy `result_type: "object"`.

- [ ] **Step 4: Run contract tests and existing Food matcher tests**

```powershell
deno test backend/supabase/functions/ai-search/recognition_contract_test.ts backend/supabase/functions/ai-search/food_matcher_test.ts backend/supabase/functions/ai-search/food_catalog_test.ts
```

Expected: all tests PASS.

- [ ] **Step 5: Commit the backend contract**

```powershell
git add backend/supabase/functions/ai-search/recognition_contract.ts backend/supabase/functions/ai-search/recognition_contract_test.ts
git commit -m "feat: normalize AI recognition result kinds"
```

### Task 2: Build the Gemini Schema and Integrate the Edge Function

**Files:**
- Create: `backend/supabase/functions/ai-search/recognition_prompt.ts`
- Create: `backend/supabase/functions/ai-search/recognition_prompt_test.ts`
- Modify: `backend/supabase/functions/ai-search/index.ts:10-327`

**Interfaces:**
- Consumes: `GeminiRecognitionRequestInput` with image data, MIME type, and target language.
- Produces: `buildGeminiRecognitionRequest(input): Record<string, unknown>`.
- Produces: `isGeminiSafetyBlocked(data: unknown): boolean` and
  `parseGeminiJson(rawText: string): Record<string, unknown>`.
- Consumes from Task 1: `normalizeRecognition`, `unsupportedRecognition`, and `NormalizedRecognition`.
- Produces network JSON containing schema v2 fields plus `db_match`, `provider`, and `model`.

- [ ] **Step 1: Write failing prompt/schema tests**

```ts
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
  for (const kind of [
    "food",
    "landmark",
    "cultural_object",
    "sign_text",
    "unclear",
    "unsupported",
  ]) {
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
  assertEquals(isGeminiSafetyBlocked({
    promptFeedback: { blockReason: "SAFETY" },
  }), true);
  assertEquals(isGeminiSafetyBlocked({
    candidates: [{ finishReason: "SAFETY" }],
  }), true);
});

Deno.test("malformed Gemini JSON is rejected", () => {
  assertThrows(() => parseGeminiJson("not-json"), Error, "Invalid JSON");
});
```

- [ ] **Step 2: Run prompt tests and verify RED**

```powershell
deno test backend/supabase/functions/ai-search/recognition_prompt_test.ts
```

Expected: FAIL because the prompt builder does not exist.

- [ ] **Step 3: Implement the prompt builder with a strict response schema**

```ts
export type GeminiRecognitionRequestInput = {
  imageBase64: string;
  mimeType: string;
  targetLanguageCode: string;
  targetLanguageName: string;
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
          "Ordinary unrelated objects, people, selfies, identity documents, payment cards, and unsafe content are unsupported.",
          "Never identify a person and never transcribe sensitive documents.",
          "Use honest confidence. Do not fill irrelevant category fields.",
          `Translate readable sign text into ${input.targetLanguageName} (${input.targetLanguageCode}).`,
          "Do not infer the user's current location from a sign.",
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
```

Define `recognitionResponseSchema` in the same file. It requires every common
field, including common `map_query` and `can_open_map`, plus a required
`text_analysis` object with all sign keys. Non-sign
categories return empty nested sign strings and nested `can_open_map: false`;
their common map fields may still describe a reliable Landmark or Cultural
Object query. Configure
`result_kind` and `sign_type` with the exact enum values from the design.
Move the current fenced/plain JSON parser from `index.ts` into
`parseGeminiJson`. Implement `isGeminiSafetyBlocked` against both
`promptFeedback.blockReason` and candidate `finishReason`, comparing normalized
values to `SAFETY`.

- [ ] **Step 4: Refactor `index.ts` to use the builder and normalizer**

```ts
type AiSearchPayload = {
  imageBase64?: string;
  mimeType?: string;
  fileName?: string;
  targetLanguageCode?: string;
  targetLanguageName?: string;
};

const targetLanguageCode = payload.targetLanguageCode?.trim() || "en";
const targetLanguageName = payload.targetLanguageName?.trim() || "English";
const geminiRequest = buildGeminiRecognitionRequest({
  imageBase64,
  mimeType,
  targetLanguageCode,
  targetLanguageName,
});
```

Use `geminiRequest` as the single fetch body. Normalize parsed output, convert a
provider safety block to `unsupportedRecognition("unsafe_content")`, and call
`resolveFoodDatabaseMatch` only for normalized Food. Preserve CORS, auth, error
mapping, provider/model metadata, and current Food matching behavior.

- [ ] **Step 5: Run backend tests and type-check the Edge Function**

```powershell
deno test backend/supabase/functions/ai-search/recognition_contract_test.ts backend/supabase/functions/ai-search/recognition_prompt_test.ts backend/supabase/functions/ai-search/food_matcher_test.ts backend/supabase/functions/ai-search/food_catalog_test.ts
deno check backend/supabase/functions/ai-search/index.ts
```

Expected: all tests PASS and `deno check` exits 0.

- [ ] **Step 6: Commit the Gemini contract integration**

```powershell
git add backend/supabase/functions/ai-search/recognition_prompt.ts backend/supabase/functions/ai-search/recognition_prompt_test.ts backend/supabase/functions/ai-search/index.ts
git commit -m "feat: route travel images with Gemini schema"
```

### Task 3: Introduce the Flutter Schema v2 Domain Model

**Files:**
- Create: `frontend/lib/features/ai_search/domain/ai_recognition_result.dart`
- Modify: `frontend/lib/features/ai_search/data/ai_search_service.dart:1-169`
- Modify: `frontend/test/features/ai_search/data/ai_search_service_test.dart:1-105`
- Modify constructor imports/usages in:
  - `frontend/test/features/ai_search/data/ai_recognition_history_repository_test.dart`
  - `frontend/test/features/ai_search/presentation/ai_recognition_history_page_test.dart`
  - `frontend/test/features/ai_search/presentation/ai_search_history_navigation_test.dart`
  - `frontend/lib/features/ai_search/presentation/ai_search_page.dart`

**Interfaces:**
- Produces: `AiRecognitionKind.parse(String?, {String? legacyResultType})` and `.wireValue`.
- Produces: `AiRecognitionTextAnalysis.fromJson/toJson`.
- Produces: `AiSearchResult.fromJson/toJson`, `.isFood`, `.isHistoryEligible`, and `.legacyResultType`.
- Preserves: `AiSearchDatabaseMatch.tryParse/toJson`.

- [ ] **Step 1: Expand model tests for schema v2 and legacy parsing**

```dart
test('schema v2 sign result round-trip preserves OCR and map query', () {
  final AiSearchResult result = AiSearchResult.fromJson(<String, dynamic>{
    'schema_version': 2,
    'result_kind': 'sign_text',
    'result_type': 'object',
    'confidence': 0.91,
    'detected_name': 'ĐƯỜNG NGUYỄN HUỆ',
    'summary': 'A Vietnamese street sign.',
    'reason_code': 'none',
    'text_analysis': <String, dynamic>{
      'original_text': 'ĐƯỜNG NGUYỄN HUỆ',
      'detected_language_code': 'vi',
      'detected_language_name': 'Vietnamese',
      'translated_text': 'Nguyen Hue Street',
      'target_language_code': 'en',
      'sign_type': 'street',
      'travel_context': 'A street name.',
      'map_query': 'Nguyen Hue Street, Vietnam',
      'can_open_map': true,
    },
  });
  expect(result.kind, AiRecognitionKind.signText);
  expect(result.textAnalysis?.originalText, 'ĐƯỜNG NGUYỄN HUỆ');
  expect(
    AiSearchResult.fromJson(result.toJson()).textAnalysis?.mapQuery,
    'Nguyen Hue Street, Vietnam',
  );
});

test('legacy object history maps to cultural object', () {
  final AiSearchResult result = AiSearchResult.fromJson(<String, dynamic>{
    'result_type': 'object',
    'confidence': 0.88,
    'detected_name': 'Nón lá',
  });
  expect(result.kind, AiRecognitionKind.culturalObject);
});

test('unknown schema v2 kind is unsupported', () {
  final AiSearchResult result = AiSearchResult.fromJson(<String, dynamic>{
    'result_kind': 'vehicle',
    'result_type': 'object',
    'confidence': 0.9,
  });
  expect(result.kind, AiRecognitionKind.unsupported);
  expect(result.isHistoryEligible, isFalse);
});
```

- [ ] **Step 2: Run the model tests and verify RED**

```powershell
Set-Location frontend
flutter test test/features/ai_search/data/ai_search_service_test.dart
```

Expected: FAIL because schema v2 domain types do not exist.

- [ ] **Step 3: Move models into a focused domain file**

```dart
enum AiRecognitionKind {
  food('food'),
  landmark('landmark'),
  culturalObject('cultural_object'),
  signText('sign_text'),
  unclear('unclear'),
  unsupported('unsupported');

  const AiRecognitionKind(this.wireValue);
  final String wireValue;

  static AiRecognitionKind parse(
    String? value, {
    String? legacyResultType,
  }) {
    final String normalized = value?.trim().toLowerCase() ?? '';
    for (final AiRecognitionKind kind in values) {
      if (kind.wireValue == normalized) return kind;
    }
    if (normalized.isNotEmpty) return AiRecognitionKind.unsupported;
    return legacyResultType?.trim().toLowerCase() == 'food'
        ? AiRecognitionKind.food
        : AiRecognitionKind.culturalObject;
  }
}

class AiRecognitionTextAnalysis {
  const AiRecognitionTextAnalysis({
    required this.originalText,
    required this.detectedLanguageCode,
    required this.detectedLanguageName,
    required this.translatedText,
    required this.targetLanguageCode,
    required this.signType,
    required this.travelContext,
    required this.mapQuery,
    required this.canOpenMap,
  });

  final String originalText;
  final String detectedLanguageCode;
  final String detectedLanguageName;
  final String translatedText;
  final String targetLanguageCode;
  final String signType;
  final String travelContext;
  final String mapQuery;
  final bool canOpenMap;
}
```

Move `AiSearchResult` and `AiSearchDatabaseMatch` from the service into the same
domain file. Add `schemaVersion`, `kind`, `reasonCode`, `mapQuery`, `canOpenMap`,
and `textAnalysis`. For Sign Text, parsing falls back to the nested text-analysis
map values when the common values are absent.
`toJson()` writes both `result_kind` and legacy `result_type`. Define eligibility:

```dart
bool get isHistoryEligible => switch (kind) {
  AiRecognitionKind.food ||
  AiRecognitionKind.landmark ||
  AiRecognitionKind.culturalObject => detectedName.trim().isNotEmpty,
  AiRecognitionKind.signText =>
    textAnalysis?.originalText.trim().isNotEmpty ?? false,
  AiRecognitionKind.unclear || AiRecognitionKind.unsupported => false,
};
```

- [ ] **Step 4: Update imports and existing constructors without changing UI behavior**

Use `kind: AiRecognitionKind.food` for Food fixtures and
`kind: AiRecognitionKind.culturalObject` for legacy Object fixtures. Import the
domain file from the service, history repository, page, and tests. Do not change
page routing in this task.

- [ ] **Step 5: Format and run focused model/history compile tests**

```powershell
Set-Location frontend
dart format lib/features/ai_search/domain/ai_recognition_result.dart lib/features/ai_search/data/ai_search_service.dart test/features/ai_search/data/ai_search_service_test.dart test/features/ai_search/data/ai_recognition_history_repository_test.dart test/features/ai_search/presentation/ai_recognition_history_page_test.dart test/features/ai_search/presentation/ai_search_history_navigation_test.dart
flutter test test/features/ai_search/data/ai_search_service_test.dart test/features/ai_search/data/ai_recognition_history_repository_test.dart test/features/ai_search/presentation/ai_recognition_history_page_test.dart test/features/ai_search/presentation/ai_search_history_navigation_test.dart
```

Expected: all selected tests PASS.

- [ ] **Step 6: Commit the Flutter recognition domain model**

```powershell
git add frontend/lib/features/ai_search/domain/ai_recognition_result.dart frontend/lib/features/ai_search/data/ai_search_service.dart frontend/lib/features/ai_search/data/ai_recognition_history_repository.dart frontend/lib/features/ai_search/presentation/ai_search_page.dart frontend/test/features/ai_search/data/ai_search_service_test.dart frontend/test/features/ai_search/data/ai_recognition_history_repository_test.dart frontend/test/features/ai_search/presentation/ai_recognition_history_page_test.dart frontend/test/features/ai_search/presentation/ai_search_history_navigation_test.dart
git commit -m "refactor: add typed AI recognition result model"
```

### Task 4: Send Target Language and Enforce History Eligibility

**Files:**
- Modify: `frontend/lib/features/ai_search/data/ai_search_service.dart:170-237`
- Modify: `frontend/lib/features/ai_search/data/ai_recognition_history_repository.dart:11-149`
- Modify: `frontend/test/features/ai_search/data/ai_search_service_test.dart`
- Modify: `frontend/test/features/ai_search/data/ai_recognition_history_repository_test.dart`

**Interfaces:**
- Produces: `AiSearchService.analyzeImage(XFile file, {required String targetLanguageCode, required String targetLanguageName})`.
- Changes: `AiRecognitionHistoryStore.save` returns `Future<AiRecognitionHistoryEntry?>` and returns `null` without writing for ineligible results.

- [ ] **Step 1: Write failing request-language and history-filter tests**

```dart
final AiSearchResult result = await service.analyzeImage(
  XFile.fromData(Uint8List.fromList(<int>[1, 2, 3]), name: 'photo.png'),
  targetLanguageCode: 'vi',
  targetLanguageName: 'Vietnamese',
);
expect(body['targetLanguageCode'], 'vi');
expect(body['targetLanguageName'], 'Vietnamese');
expect(result.kind, AiRecognitionKind.food);
```

```dart
test('does not save unclear or unsupported results', () async {
  final AiRecognitionHistoryRepository repository =
      AiRecognitionHistoryRepository(userId: 'user-1');
  final AiRecognitionHistoryEntry? saved = await repository.save(
    result: _result('Unknown', kind: AiRecognitionKind.unclear),
    imageBytes: imageBytes,
  );
  expect(saved, isNull);
  expect(await repository.load(), isEmpty);
});
```

Add a history test proving a `signText` result with non-empty `originalText` is
saved, while a sign with empty OCR is not saved.

- [ ] **Step 2: Run both test files and verify RED**

```powershell
Set-Location frontend
flutter test test/features/ai_search/data/ai_search_service_test.dart test/features/ai_search/data/ai_recognition_history_repository_test.dart
```

Expected: FAIL on the missing language parameters and nullable history save.

- [ ] **Step 3: Implement request language and repository guard**

```dart
Future<AiSearchResult> analyzeImage(
  XFile file, {
  required String targetLanguageCode,
  required String targetLanguageName,
}) async {
  final Uint8List bytes = await file.readAsBytes();
  if (bytes.isEmpty) {
    throw AiSearchException('Anh tai len dang rong.');
  }
  final Map<String, dynamic> data = await _edgeFunctionClient.postJson(
    'ai-search',
    requireAuth: true,
    body: <String, Object?>{
      'imageBase64': base64Encode(bytes),
      'mimeType': _inferMimeType(file),
      'fileName': file.name,
      'targetLanguageCode': targetLanguageCode.trim().isEmpty
          ? 'en'
          : targetLanguageCode.trim(),
      'targetLanguageName': targetLanguageName.trim().isEmpty
          ? 'English'
          : targetLanguageName.trim(),
    },
  );
  return AiSearchResult.fromJson(data);
}
```

At the top of `save`, return `null` before thumbnail creation when
`!result.isHistoryEligible`. Change the interface and fake stores to nullable
return types. Keep empty-image validation for eligible results.

- [ ] **Step 4: Run service and repository tests**

```powershell
Set-Location frontend
dart format lib/features/ai_search/data/ai_search_service.dart lib/features/ai_search/data/ai_recognition_history_repository.dart test/features/ai_search/data/ai_search_service_test.dart test/features/ai_search/data/ai_recognition_history_repository_test.dart
flutter test test/features/ai_search/data/ai_search_service_test.dart test/features/ai_search/data/ai_recognition_history_repository_test.dart
```

Expected: both test files PASS.

- [ ] **Step 5: Commit language and history behavior**

```powershell
git add frontend/lib/features/ai_search/data/ai_search_service.dart frontend/lib/features/ai_search/data/ai_recognition_history_repository.dart frontend/test/features/ai_search/data/ai_search_service_test.dart frontend/test/features/ai_search/data/ai_recognition_history_repository_test.dart
git commit -m "feat: localize and filter AI recognition results"
```

### Task 5: Add Query-Based Google Maps and Deferred Location Preparation

**Files:**
- Modify: `frontend/lib/core/utils/maps_launcher.dart:1-29`
- Create: `frontend/lib/features/ai_search/application/ai_recognition_map_coordinator.dart`
- Create: `frontend/test/core/utils/maps_launcher_test.dart`
- Create: `frontend/test/features/ai_search/application/ai_recognition_map_coordinator_test.dart`

**Interfaces:**
- Produces: `buildGoogleMapsSearchQueryUri(String query): Uri`.
- Produces: `buildGoogleMapsDirectionsToQueryUri({required String query, double? originLat, double? originLng}): Uri`.
- Produces: `openGoogleMapsSearchQuery(String query): Future<bool>` and `openGoogleMapsDirectionsToQuery(...): Future<bool>`.
- Produces: the `AiRecognitionMapCoordinator` interface with `.prepare()`,
  `.launch(query, {origin})`, and `.openSettings(target)`.

- [ ] **Step 1: Write failing URI builder tests**

```dart
test('search query URI preserves Vietnamese text', () {
  final Uri uri = buildGoogleMapsSearchQueryUri(
    'Đường Nguyễn Huệ, Việt Nam',
  );
  expect(uri.host, 'www.google.com');
  expect(uri.path, '/maps/search/');
  expect(uri.queryParameters['api'], '1');
  expect(uri.queryParameters['query'], 'Đường Nguyễn Huệ, Việt Nam');
});

test('directions query omits origin when GPS is unavailable', () {
  final Uri uri = buildGoogleMapsDirectionsToQueryUri(
    query: 'Nguyen Hue Street, Vietnam',
  );
  expect(uri.queryParameters['destination'], 'Nguyen Hue Street, Vietnam');
  expect(uri.queryParameters.containsKey('origin'), isFalse);
});
```

- [ ] **Step 2: Write failing coordinator tests**

Use fakes implementing these exact interfaces:

```dart
abstract interface class AiRecognitionLocationGateway {
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<bool> isServiceEnabled();
  Future<AiRecognitionMapOrigin> currentOrigin();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

abstract interface class AiRecognitionMapGateway {
  Future<bool> openSearch(String query);
  Future<bool> openDirections(
    String query, {
    required AiRecognitionMapOrigin origin,
  });
}

abstract interface class AiRecognitionMapCoordinator {
  Future<AiRecognitionMapPreparation> prepare();
  Future<bool> launch(
    String query, {
    AiRecognitionMapOrigin? origin,
  });
  Future<bool> openSettings(AiRecognitionMapSettingsTarget target);
}
```

Cover granted permission, denied-then-denied fallback, permanently denied app
settings, disabled-service location settings, GPS failure fallback, successful
directions launch, and unsuccessful text-search launch.

```dart
test('denied permission requests once then prepares no-origin search', () async {
  location.permission = LocationPermission.denied;
  location.requestResult = LocationPermission.denied;
  final AiRecognitionMapPreparation result = await coordinator.prepare();
  expect(result, isA<AiRecognitionMapWithoutOrigin>());
  expect(location.requestPermissionCalls, 1);
});

test('disabled location service requires location settings choice', () async {
  location.permission = LocationPermission.whileInUse;
  location.serviceEnabled = false;
  final AiRecognitionMapPreparation result = await coordinator.prepare();
  expect(result, isA<AiRecognitionMapNeedsSettings>());
  expect(
    (result as AiRecognitionMapNeedsSettings).target,
    AiRecognitionMapSettingsTarget.location,
  );
});

test('granted permission returns the current map origin', () async {
  location.permission = LocationPermission.whileInUse;
  location.origin = (latitude: 10.7769, longitude: 106.7009);
  final AiRecognitionMapPreparation result = await coordinator.prepare();
  expect(result, isA<AiRecognitionMapReady>());
  expect((result as AiRecognitionMapReady).origin, location.origin);
});
```

- [ ] **Step 3: Run the map tests and verify RED**

```powershell
Set-Location frontend
flutter test test/core/utils/maps_launcher_test.dart test/features/ai_search/application/ai_recognition_map_coordinator_test.dart
```

Expected: FAIL because the URI builders and coordinator do not exist.

- [ ] **Step 4: Implement pure URI builders and boolean launch functions**

```dart
Uri buildGoogleMapsSearchQueryUri(String query) => Uri.https(
  'www.google.com',
  '/maps/search/',
  <String, String>{'api': '1', 'query': query.trim()},
);

Uri buildGoogleMapsDirectionsToQueryUri({
  required String query,
  double? originLat,
  double? originLng,
}) {
  return Uri.https('www.google.com', '/maps/dir/', <String, String>{
    'api': '1',
    if (originLat != null && originLng != null)
      'origin': '$originLat,$originLng',
    'destination': query.trim(),
    'travelmode': 'driving',
  });
}
```

Keep existing coordinate functions but return `Future<bool>` from `launchUrl`.
Reject blank query values with `ArgumentError.value` before launching.

- [ ] **Step 5: Implement the coordinator as a pure decision boundary**

```dart
typedef AiRecognitionMapOrigin = ({double latitude, double longitude});

sealed class AiRecognitionMapPreparation {
  const AiRecognitionMapPreparation();
}

final class AiRecognitionMapReady extends AiRecognitionMapPreparation {
  const AiRecognitionMapReady(this.origin);
  final AiRecognitionMapOrigin origin;
}

final class AiRecognitionMapWithoutOrigin
    extends AiRecognitionMapPreparation {
  const AiRecognitionMapWithoutOrigin(this.reason);
  final String reason;
}

final class AiRecognitionMapNeedsSettings
    extends AiRecognitionMapPreparation {
  const AiRecognitionMapNeedsSettings(this.target);
  final AiRecognitionMapSettingsTarget target;
}

enum AiRecognitionMapSettingsTarget { app, location }
```

`prepare()` checks permission, requests only when currently denied, returns app
settings for `deniedForever`, returns location settings when the service is off,
and catches GPS errors as `AiRecognitionMapWithoutOrigin('gps_unavailable')`.
`launch` calls directions when an origin exists and text search otherwise.
`openSettings` delegates to app or location settings according to the enum.
Implement `DefaultAiRecognitionMapCoordinator` plus production adapters around
`DeviceLocationService` and map launchers; page tests implement the interface
with a fake.

- [ ] **Step 6: Format and run map tests**

```powershell
Set-Location frontend
dart format lib/core/utils/maps_launcher.dart lib/features/ai_search/application/ai_recognition_map_coordinator.dart test/core/utils/maps_launcher_test.dart test/features/ai_search/application/ai_recognition_map_coordinator_test.dart
flutter test test/core/utils/maps_launcher_test.dart test/features/ai_search/application/ai_recognition_map_coordinator_test.dart
```

Expected: all map tests PASS.

- [ ] **Step 7: Commit deferred map behavior**

```powershell
git add frontend/lib/core/utils/maps_launcher.dart frontend/lib/features/ai_search/application/ai_recognition_map_coordinator.dart frontend/test/core/utils/maps_launcher_test.dart frontend/test/features/ai_search/application/ai_recognition_map_coordinator_test.dart
git commit -m "feat: defer AI recognition location to map actions"
```

### Task 6: Render Category-Specific Result Sections

**Files:**
- Create: `frontend/lib/features/ai_search/presentation/widgets/ai_recognition_result_sections.dart`
- Create: `frontend/test/features/ai_search/presentation/ai_recognition_result_sections_test.dart`

**Interfaces:**
- Consumes: `AiSearchResult result`.
- Consumes callbacks: `onOpenMap`, `onCopyOriginal`, `onCopyTranslation`,
  `onListen`, `onTakePhoto`, and `onChooseImage`.
- Produces keyed sections for each result kind without owning image picking, history, networking, location, or TTS.

- [ ] **Step 1: Write failing widget tests for all result kinds**

```dart
await tester.pumpWidget(MaterialApp(
  home: Scaffold(
    body: AiRecognitionResultSections(
      result: signResult,
      onOpenMap: () {},
      onCopyOriginal: () {},
      onCopyTranslation: () {},
      onListen: () {},
      onTakePhoto: () {},
      onChooseImage: () {},
    ),
  ),
));

expect(find.byKey(const Key('ai-result-sign-text')), findsOneWidget);
expect(find.text('ĐƯỜNG NGUYỄN HUỆ'), findsOneWidget);
expect(find.text('Nguyen Hue Street'), findsOneWidget);
expect(find.byKey(const Key('ai-sign-map-button')), findsOneWidget);
expect(find.byKey(const Key('ai-sign-listen-button')), findsOneWidget);
```

Add separate tests asserting Food retains its existing cards; Landmark exposes
visitor context and a conditional map button; Cultural Object exposes materials,
use, production, and cultural significance; Unclear has capture guidance and no
detail cards; Unsupported has the supported-scope message and no claims; and a
traffic sign includes the informational safety note.

```dart
testWidgets('unclear result exposes retry actions without detail claims', (
  WidgetTester tester,
) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AiRecognitionResultSections(
        result: unclearResult,
        onOpenMap: () {},
        onCopyOriginal: () {},
        onCopyTranslation: () {},
        onListen: () {},
        onTakePhoto: () {},
        onChooseImage: () {},
      ),
    ),
  ));
  expect(find.byKey(const Key('ai-result-unclear')), findsOneWidget);
  expect(find.byKey(const Key('ai-result-price-card')), findsNothing);
  expect(find.byKey(const Key('ai-result-materials-card')), findsNothing);
  expect(find.byKey(const Key('ai-result-map-button')), findsNothing);
  expect(find.byKey(const Key('ai-retake-photo-button')), findsOneWidget);
  expect(find.byKey(const Key('ai-choose-image-button')), findsOneWidget);
});
```

- [ ] **Step 2: Run result-section tests and verify RED**

```powershell
Set-Location frontend
flutter test test/features/ai_search/presentation/ai_recognition_result_sections_test.dart
```

Expected: FAIL because `AiRecognitionResultSections` does not exist.

- [ ] **Step 3: Implement the focused result widget**

```dart
class AiRecognitionResultSections extends StatelessWidget {
  const AiRecognitionResultSections({
    super.key,
    required this.result,
    required this.onOpenMap,
    required this.onCopyOriginal,
    required this.onCopyTranslation,
    required this.onListen,
    required this.onTakePhoto,
    required this.onChooseImage,
  });

  final AiSearchResult result;
  final VoidCallback onOpenMap;
  final VoidCallback onCopyOriginal;
  final VoidCallback onCopyTranslation;
  final VoidCallback onListen;
  final VoidCallback onTakePhoto;
  final VoidCallback onChooseImage;

  @override
  Widget build(BuildContext context) {
    return switch (result.kind) {
      AiRecognitionKind.food => _FoodSection(result: result),
      AiRecognitionKind.landmark => _LandmarkSection(
          result: result,
          onOpenMap: onOpenMap,
        ),
      AiRecognitionKind.culturalObject => _CulturalObjectSection(
          result: result,
          onOpenMap: onOpenMap,
        ),
      AiRecognitionKind.signText => _SignTextSection(
          result: result,
          onOpenMap: onOpenMap,
          onCopyOriginal: onCopyOriginal,
          onCopyTranslation: onCopyTranslation,
          onListen: onListen,
        ),
      AiRecognitionKind.unclear => _UnclearSection(
          onTakePhoto: onTakePhoto,
          onChooseImage: onChooseImage,
        ),
      AiRecognitionKind.unsupported => _UnsupportedSection(
          onTakePhoto: onTakePhoto,
          onChooseImage: onChooseImage,
        ),
    };
  }
}
```

Use the current `ai_search_page.dart` card colors, borders, radii, spacing, icon
sizes, and text hierarchy. Hide empty optional cards. The sign map callback is
visible only when `textAnalysis.canOpenMap` and `mapQuery.trim().isNotEmpty`.
Do not introduce a new visual theme.

- [ ] **Step 4: Format and run section tests**

```powershell
Set-Location frontend
dart format lib/features/ai_search/presentation/widgets/ai_recognition_result_sections.dart test/features/ai_search/presentation/ai_recognition_result_sections_test.dart
flutter test test/features/ai_search/presentation/ai_recognition_result_sections_test.dart
```

Expected: all section tests PASS.

- [ ] **Step 5: Commit category-specific sections**

```powershell
git add frontend/lib/features/ai_search/presentation/widgets/ai_recognition_result_sections.dart frontend/test/features/ai_search/presentation/ai_recognition_result_sections_test.dart
git commit -m "feat: render travel-aware recognition sections"
```

### Task 7: Wire Result Routing, Copy, TTS, Map Choices, and History into the Page

**Files:**
- Modify: `frontend/lib/features/ai_search/presentation/ai_search_page.dart:14-1282`
- Modify: `frontend/lib/features/ai_search/presentation/ai_recognition_history_page.dart:191-311`
- Modify: `frontend/lib/core/language/app_language.dart:1150-1205`
- Create: `frontend/test/features/ai_search/presentation/ai_search_result_routing_test.dart`
- Modify: existing AI Search presentation tests where constructors/imports change.

**Interfaces:**
- Consumes from Task 4: language-aware `analyzeImage` and nullable history save.
- Consumes from Task 5: `AiRecognitionMapCoordinator`.
- Consumes from Task 6: `AiRecognitionResultSections` callbacks.
- Uses existing `OpenAITranslationService.synthesizeSpeech` and `AudioPlayer.play` only after Listen is tapped.

- [ ] **Step 1: Write failing page-routing and deferred-action tests**

Build page fixtures through `initialHistoryEntry` so tests never call the network.
Inject a fake map coordinator and callback spies. Start with:

```dart
testWidgets('restoring a sign result does not request location', (tester) async {
  final FakeMapCoordinator maps = FakeMapCoordinator();
  await tester.pumpWidget(MaterialApp(
    home: AiSearchPage(
      initialHistoryEntry: signHistoryEntry,
      mapCoordinator: maps,
    ),
  ));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('ai-result-sign-text')), findsOneWidget);
  expect(maps.prepareCalls, 0);
});

testWidgets('map tap prepares location exactly once', (tester) async {
  final FakeMapCoordinator maps = FakeMapCoordinator.ready();
  await tester.pumpWidget(MaterialApp(
    home: AiSearchPage(
      initialHistoryEntry: signHistoryEntry,
      mapCoordinator: maps,
    ),
  ));
  await tester.tap(find.byKey(const Key('ai-sign-map-button')));
  await tester.pumpAndSettle();
  expect(maps.prepareCalls, 1);
  expect(maps.launchCalls, 1);
});

testWidgets('copy and listen actions run only after taps', (tester) async {
  final List<String> copied = <String>[];
  final List<String> spoken = <String>[];
  await tester.pumpWidget(MaterialApp(
    home: AiSearchPage(
      initialHistoryEntry: signHistoryEntry,
      onCopyText: (String text) async => copied.add(text),
      onSpeakText: (String text) async => spoken.add(text),
    ),
  ));
  expect(copied, isEmpty);
  expect(spoken, isEmpty);
  await tester.tap(find.byKey(const Key('ai-sign-copy-original-button')));
  await tester.tap(find.byKey(const Key('ai-sign-listen-button')));
  expect(copied.single, 'ĐƯỜNG NGUYỄN HUỆ');
  expect(spoken.single, 'ĐƯỜNG NGUYỄN HUỆ');
});
```

Add tests for settings fallback: the dialog exposes Open Settings, Continue
Without Location, and Cancel; choosing Continue launches text search. Add tests
that unclear/unsupported results do not call history save and Food restoration
continues to show verified detail navigation.

- [ ] **Step 2: Run page tests and verify RED**

```powershell
Set-Location frontend
flutter test test/features/ai_search/presentation/ai_search_result_routing_test.dart
```

Expected: FAIL because the page does not support typed routing/actions.

- [ ] **Step 3: Replace the food/object view split with one typed result state**

```dart
enum _AiSearchView { initial, analyzing, result }

AiSearchResult? _activeResult;

void _showResult(AiSearchResult result) {
  setState(() {
    _activeResult = result;
    _activeRecognitionData = _RecognitionData.fromAiSearchResult(result);
    _view = _AiSearchView.result;
  });
}
```

Read the app language before awaiting analysis:

```dart
final AppLanguage language = AppLanguageScope.languageOf(context);
final AiSearchResult result = await _aiSearchService.analyzeImage(
  file,
  targetLanguageCode: language.code,
  targetLanguageName: language.englishName,
);
```

Call history save only when `result.isHistoryEligible`; retain the repository
guard as defense in depth. Restore all supported result kinds through the same
typed result view.

- [ ] **Step 4: Integrate category sections inside the existing result shell**

```dart
AiRecognitionResultSections(
  result: result,
  onOpenMap: () => _openMap(result),
  onCopyOriginal: () => _copyText(
    result.textAnalysis?.originalText ?? '',
  ),
  onCopyTranslation: () => _copyText(
    result.textAnalysis?.translatedText ?? '',
  ),
  onListen: () => _speakSignText(result),
  onTakePhoto: () => _pickAndAnalyze(ImageSource.camera),
  onChooseImage: () => _pickAndAnalyze(ImageSource.gallery),
),
```

Keep the selected-image hero, close button, confidence badge, current scrolling,
Food favorite behavior, and verified Food panel. Hide favorite for signs,
unclear, and unsupported results.

- [ ] **Step 5: Implement map preparation and fallback choices**

`_openMap` returns for a blank/untrusted query, prevents duplicate taps with
`_openingMap`, and calls `prepare()` only after the tap. Launch directions for
`AiRecognitionMapReady`; launch search for `AiRecognitionMapWithoutOrigin`; and
show a settings/continue/cancel dialog for `AiRecognitionMapNeedsSettings`.
When launching fails, show a snackbar action that copies the search query.
Never add prepared coordinates to the result or history.

- [ ] **Step 6: Implement default copy and on-demand TTS collaborators**

Add optional constructor hooks:

```dart
final Future<void> Function(String text)? onCopyText;
final Future<void> Function(String text)? onSpeakText;
final AiRecognitionMapCoordinator? mapCoordinator;
```

The default copy path uses `Clipboard.setData`. The default speech path calls
`OpenAITranslationService.synthesizeSpeech` with the detected sign language,
then plays `UrlSource(speech.audioUrl)` through a lazily owned `AudioPlayer`.
Dispose the player, block repeated Listen taps, and surface failures through the
existing snackbar style.

- [ ] **Step 7: Update history labels and localized copy**

Map history labels from `AiRecognitionKind` instead of defaulting to Object.
Add Vietnamese `context.l10n.ui` entries for Possible Match, Landmark, Cultural
Object, Street Sign, Original Text, Translation, Copy, Listen, Find on Map,
Continue Without Location, Open Settings, Take Another Photo, Choose Another
Image, Could Not Recognize Clearly, and Image Type Not Supported.

- [ ] **Step 8: Format and run all AI Search presentation tests**

```powershell
Set-Location frontend
dart format lib/features/ai_search/presentation/ai_search_page.dart lib/features/ai_search/presentation/ai_recognition_history_page.dart lib/core/language/app_language.dart test/features/ai_search/presentation
flutter test test/features/ai_search/presentation
```

Expected: all presentation tests PASS, including dark mode and history navigation.

- [ ] **Step 9: Commit page integration**

```powershell
git add frontend/lib/features/ai_search/presentation/ai_search_page.dart frontend/lib/features/ai_search/presentation/ai_recognition_history_page.dart frontend/lib/core/language/app_language.dart frontend/test/features/ai_search/presentation/ai_search_result_routing_test.dart frontend/test/features/ai_search/presentation/ai_search_history_navigation_test.dart frontend/test/features/ai_search/presentation/ai_recognition_history_page_test.dart frontend/test/features/ai_search/presentation/ai_search_dark_mode_test.dart
git commit -m "feat: complete travel-aware AI recognition flow"
```

### Task 8: Run Cross-Layer Regression Verification

**Files:**
- Modify only files from Tasks 1-7 if a verification command exposes a defect.

**Interfaces:**
- Verifies schema v2, legacy history, Food matching, category routing, map permission boundaries, TTS/copy actions, and current UI regressions.

- [ ] **Step 1: Run the complete backend AI Search suite**

```powershell
deno test backend/supabase/functions/ai-search/recognition_contract_test.ts backend/supabase/functions/ai-search/recognition_prompt_test.ts backend/supabase/functions/ai-search/food_matcher_test.ts backend/supabase/functions/ai-search/food_catalog_test.ts
deno check backend/supabase/functions/ai-search/index.ts
```

Expected: every backend test PASS and type-check exits 0.

- [ ] **Step 2: Run the complete Flutter AI Search suite**

```powershell
Set-Location frontend
flutter test test/features/ai_search test/core/utils/maps_launcher_test.dart
```

Expected: all AI Search and map tests PASS.

- [ ] **Step 3: Run formatting and static analysis**

```powershell
Set-Location frontend
dart format --output=none --set-exit-if-changed lib/features/ai_search lib/core/utils/maps_launcher.dart lib/core/language/app_language.dart test/features/ai_search test/core/utils/maps_launcher_test.dart
flutter analyze
```

Expected: formatter exits 0 and analyzer reports no feature-introduced issues.

- [ ] **Step 4: Run the full Flutter regression suite**

```powershell
Set-Location frontend
flutter test
```

Expected: all Flutter tests PASS. If an unrelated pre-existing failure exists,
record its exact test name/output separately; do not weaken or delete the test.

- [ ] **Step 5: Review the final diff against privacy and UX constraints**

```powershell
Set-Location ..
git diff --check
git status --short
git diff -- backend/supabase/functions/ai-search frontend/lib/features/ai_search frontend/lib/core/utils/maps_launcher.dart frontend/lib/core/language/app_language.dart frontend/test/features/ai_search frontend/test/core/utils/maps_launcher_test.dart
```

Confirm no analysis request contains coordinates, unsupported results clear
sensitive OCR, Food thresholds are unchanged, UI theme tokens remain consistent,
no migration exists, and `.superpowers/` is not staged.

- [ ] **Step 6: Route verification defects back to their owning task**

If Steps 1-5 expose a defect, return to the task that owns the affected
interface, add a focused regression test there, make the minimum correction,
rerun that task's commands, and use that task's exact-path commit command. Do not
create a catch-all commit or stage a directory containing unrelated user work.

## Completion Evidence

Implementation is complete only when:

- Backend contract, prompt, Food matcher, and type-check commands pass.
- Flutter AI Search data, history, map, result-section, and page-routing tests pass.
- Full `flutter test` passes or unrelated pre-existing failures are documented with exact output.
- `flutter analyze` reports no feature-introduced issues.
- `git diff --check` is clean.
- Final status confirms `.superpowers/` and unrelated user changes are not staged.
