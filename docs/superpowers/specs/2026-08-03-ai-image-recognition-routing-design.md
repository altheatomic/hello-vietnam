# AI Image Recognition Routing Design

**Date:** 2026-08-03
**Status:** Approved for implementation planning

## Summary

Extend AI Recognition from the current forced `food`/`object` split into a
travel-aware image router that can handle food, landmarks, cultural objects,
signs and street names, unclear images, and unsupported images. The feature
continues to use one Gemini image-analysis request. Backend validation decides
whether the response is safe and complete enough to render.

The Flutter implementation must preserve the current AI Recognition visual
language. The mockups created during brainstorming describe information
hierarchy only; they are not a redesign.

## Current Problem

The current Gemini prompt requires every image to be either `food` or `object`
and tells the model to guess with lower confidence when unsure. Backend
normalization converts every value other than `food` to `object`. Flutter labels
low-confidence results but still renders the full food or object template and
saves the result to history.

This behavior can turn a street sign, selfie, ordinary object, blurred image,
or unrelated photo into a plausible-looking but irrelevant travel result. A
street sign can incorrectly receive material, production, price, and cultural
history fields simply because the object template requires them.

## Goals

- Recognize food without regressing verified food database linking.
- Recognize landmarks and travel-relevant cultural objects.
- Read signs and street names, translate their text, and expose useful actions.
- Refuse to invent detailed results when an image is unclear or unsupported.
- Request device location only after the user taps a map or directions action.
- Preserve the current AI Recognition screen style and existing history data.
- Use one Gemini image-analysis request per recognition attempt.
- Keep category routing and validation deterministic and independently testable.

## Non-Goals

- General-purpose object recognition for ordinary household or consumer items.
- Face recognition, person identification, or analysis of selfies.
- OCR or storage of identity documents, payment cards, or sensitive documents.
- Guaranteed legal or safety interpretation of traffic signs.
- On-device OCR in this phase.
- A redesign of AI Recognition or a new database-backed landmark catalog.
- Automatic background location access or location collection during analysis.

## Chosen Architecture

### Request flow

1. Flutter uses the existing image picker and compression settings.
2. Flutter sends the image, MIME type, file name, target language code, and
   target language name to the `ai-search` Edge Function.
3. Flutter does not request or send device location.
4. The Edge Function makes one Gemini request using a strict structured schema.
5. A pure backend normalizer validates the result kind, confidence, required
   fields, and category-specific payload.
6. Food results may use the existing Supabase food matcher.
7. The Edge Function returns schema version 2 while retaining legacy response
   fields needed by existing clients and local history.
8. Flutter parses the typed result and selects the corresponding existing-style
   result section.

### Component boundaries

- **Gemini prompt/schema:** classifies the image and produces structured travel
  content and OCR data.
- **Recognition contract normalizer:** applies deterministic confidence,
  completeness, and safety rules. It must not call Gemini or Supabase.
- **Food matcher:** remains responsible only for verified food catalog links.
- **Flutter result model:** parses schema v2 and maps legacy history records.
- **Flutter result presentation:** renders one category-specific set of cards
  inside the current result-page shell.
- **Map action coordinator:** requests location only after a user action and
  opens Google Maps with a query or directions URL.
- **History repository:** stores only useful, non-sensitive successful results.

## Recognition Contract

### Result kinds

`result_kind` is a closed enum:

- `food`
- `landmark`
- `cultural_object`
- `sign_text`
- `unclear`
- `unsupported`

The backend must never normalize an unknown value to a supported kind. Unknown
values become `unsupported` with reason `invalid_result_kind`.

### Common fields

The schema v2 response contains:

- `schema_version`: integer `2`
- `result_kind`: one of the six values above
- `confidence`: number clamped to `0.0` through `1.0`
- `detected_name`
- `subtitle`
- `summary`
- `location_hint`
- `category_text`
- `reason_code`
- Existing travel fields such as tags, cultural significance, usage,
  production method, alternative names, price range, and suggested places
- Optional `db_match` for verified food only
- Optional `text_analysis` for `sign_text`

The legacy `result_type` field remains in the network and serialized-history
shape during migration. `food` maps to legacy `food`; all other kinds map to
legacy `object`. New Flutter code always prefers `result_kind`.

### Sign text fields

`text_analysis` contains:

- `original_text`
- `detected_language_code`
- `detected_language_name`
- `translated_text`
- `target_language_code`
- `sign_type`: `street`, `business`, `traffic`, `informational`, or `other`
- `travel_context`
- `map_query`
- `can_open_map`

`map_query` must describe text suitable for a Google Maps search. Gemini must
not claim that the photographed sign is the user's current location. The map
action is hidden when `can_open_map` is false or `map_query` is blank.

### Unsupported and unclear reasons

Reason codes include:

- `low_quality`
- `no_clear_subject`
- `insufficient_evidence`
- `out_of_scope`
- `person_or_selfie`
- `sensitive_document`
- `unsafe_content`
- `invalid_result_kind`
- `invalid_model_response`

Sensitive and unsafe results must not include OCR text or detailed analysis.

## Validation and Confidence Rules

- Confidence at or above `0.80` may render a confident result.
- Confidence from `0.55` through `0.79` renders a possible result and uses
  language such as "Possible match" or "This may be...".
- Confidence below `0.55` becomes `unclear`, even if Gemini selected a supported
  result kind.
- A supported result missing its minimum required content becomes `unclear`
  with reason `insufficient_evidence`.
- `sign_text` requires non-empty `original_text`. Translation may equal the
  original text when source and target languages match.
- `food` retains the existing independent database-match thresholds. A failed
  database match does not invalidate the AI recognition result.
- `db_match` is discarded for every non-food result.
- Unsupported and unclear results must not contain suggested places, price,
  production, database links, or map actions.
- The normalizer never fills absent model fields with invented content.

## Gemini Prompt Behavior

The prompt describes the app as a Vietnam travel assistant rather than a
general object recognizer. It explicitly defines supported and unsupported
categories, requires honest uncertainty, forbids person identification, and
forbids extraction of sensitive-document text.

Gemini returns the translation in the user's current app language as part of
the same response. The existing translation service is not called during image
analysis. Text-to-speech may use the existing TTS flow later, but only after the
user taps Listen.

## Flutter Presentation

### Shared shell

The current initial page, image picker, analyzing screen, hero image, color
palette, typography, match card, card shapes, spacing, and history navigation
remain in place. The result page continues to show the selected image.

The existing page is split into focused result widgets or builders so that the
main page does not continue accumulating category-specific responsibilities.

### Food

Food keeps the current ingredient, taste, best-time, dietary note, cultural
significance, suggested-place, favorite, and verified database panels. Existing
detail navigation remains available only for verified food matches.

### Landmark

Landmark displays the likely name, confidence wording, location hint, concise
historical or cultural context, visitor etiquette, suggested visiting time, and
map action when a reliable query is present. Medium confidence must remain
visibly tentative.

### Cultural object

Cultural object displays category, materials, common use, production method,
alternative names, cultural significance, and relevant places. A map action is
shown only when a reliable place query exists. Ordinary, non-travel objects are
unsupported rather than cultural objects.

### Sign and street text

Sign results display original OCR text first, then translation, detected
language, sign type, and concise travel context. Available actions are:

- Copy original text
- Copy translated text
- Listen, using the existing on-demand TTS flow
- Find on map or get directions when a map query is available
- Recognize another image

Traffic-sign explanations include a short statement that the interpretation is
informational and official signs and local rules take precedence.

### Unclear

Unclear results stay in the current visual style but do not render category
detail cards. They explain the reason and suggest concrete capture improvements:
move closer, improve lighting, keep the camera straight, and center the subject.
Primary actions are Retake Photo and Choose Image.

### Unsupported

Unsupported results briefly explain that AI Recognition currently supports
Vietnamese food, landmarks, cultural objects, signs, and street names. They do
not display fabricated descriptive fields. Primary actions are Choose Another
Image and Take Photo.

## Location and Map Behavior

- Analysis never requests location permission.
- The map coordinator requests permission only after a map or directions tap.
- If permission is granted, current coordinates are used as the directions
  origin or as search context.
- If permission is denied, the app still opens a Google Maps text search using
  `map_query`.
- If location services are disabled, the user may open settings or continue
  with text search.
- If Google Maps cannot be opened, the app offers to copy the search query.
- Device coordinates are not added to recognition history or the AI request.

The existing map launcher gains query-based search and directions support; its
existing coordinate-based functions remain unchanged for other features.

## History and Backward Compatibility

History saves `food`, `landmark`, `cultural_object`, and `sign_text` only when
the result has useful minimum content. It never saves `unclear`, `unsupported`,
sensitive, or unsafe attempts.

Schema v2 fields are optional when parsing stored records. For an old record
without `result_kind`, Flutter maps legacy `food` to `food` and legacy `object`
to `cultural_object`. Existing thumbnails and database matches remain valid.
The local storage key can remain unchanged because the new parser is backward
compatible. No Supabase database migration is required.

## Error Handling

- Network, timeout, quota, authentication, and Gemini API failures use the
  existing error mapping and return to the initial state with a retry path.
- A Gemini safety block becomes an `unsupported` result with reason
  `unsafe_content` when the provider response exposes a clear block reason.
- Empty or malformed model output returns a controlled server error and never a
  partially invented success result.
- History persistence failure does not turn a valid recognition into a failure.
- Location denial, disabled services, and map-launch failures do not invalidate
  the recognition result.
- Every async UI action checks mounted state and prevents duplicate analysis or
  duplicate map actions.

## Privacy and Safety

- No GPS is sent to Gemini or stored with the recognition.
- No person identification or face inference is performed.
- Sensitive documents and payment information are unsupported and their OCR
  content is omitted from the response and history.
- The UI distinguishes AI inference from verified food database content.
- Medium-confidence results use tentative wording; low-confidence results do
  not render detailed claims.
- Traffic-sign explanations are informational rather than safety guarantees.

## Testing Strategy

### Backend tests

- Normalize every valid result kind.
- Convert unknown kinds to unsupported.
- Clamp invalid confidence values.
- Convert supported results below `0.55` to unclear.
- Preserve tentative supported results from `0.55` through `0.79`.
- Reject incomplete sign OCR, landmark, food, and cultural-object payloads.
- Remove category-incompatible data and non-food database matches.
- Confirm sensitive and unsafe responses contain no OCR or detailed content.
- Preserve existing food matcher thresholds and ambiguity behavior.
- Test the response contract without a live Gemini request.

### Flutter model and repository tests

- JSON parse and round-trip for all six result kinds.
- Legacy food and object history parsing.
- Optional sign text payload parsing.
- Save supported useful results.
- Exclude unclear, unsupported, sensitive, and unsafe results from history.
- Preserve the newest-30 history limit and per-user separation.

### Flutter widget and interaction tests

- Render each category-specific result section.
- Preserve current Food behavior and verified detail navigation.
- Use tentative wording for medium confidence.
- Do not show irrelevant detail cards for unclear or unsupported results.
- Show sign copy, Listen, and conditional map actions.
- Confirm recognition does not request location.
- Confirm a map tap requests location exactly once.
- Confirm denied location still launches text search.
- Confirm disabled location services can fall back to text search.
- Confirm failed map launch exposes query-copy fallback.
- Confirm history save is skipped for unsuccessful categories.

## Acceptance Criteria

1. A street sign can no longer be normalized into a generic object template.
2. A readable street sign shows original text, translation, and relevant
   actions without assuming the user's location.
3. A low-confidence or incomplete result never displays invented detail cards.
4. Selfies, sensitive documents, ordinary unrelated objects, and unsafe content
   are handled as unsupported.
5. Location permission is not requested before a map action.
6. Denying location does not prevent text-based Google Maps search.
7. Existing Food recognition, food database matching, detail navigation, and
   recognition history remain functional.
8. Existing stored history entries remain readable.
9. Flutter retains the current AI Recognition visual design.
10. Backend and Flutter tests cover routing, validation, history, and map
    permission behavior without depending on live Gemini responses.

## Expected Implementation Areas

- `backend/supabase/functions/ai-search/index.ts`
- New pure recognition-contract module and tests under
  `backend/supabase/functions/ai-search/`
- `frontend/lib/features/ai_search/data/ai_search_service.dart`
- `frontend/lib/features/ai_search/presentation/ai_search_page.dart`
- Focused result widgets under the AI Search presentation feature
- `frontend/lib/features/ai_search/data/ai_recognition_history_repository.dart`
- `frontend/lib/core/utils/maps_launcher.dart`
- Existing location and TTS services through injected coordinators
- AI Search backend, model, repository, and widget test suites

No database migration is expected.
