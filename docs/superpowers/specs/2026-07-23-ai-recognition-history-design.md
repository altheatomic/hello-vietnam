# AI Recognition History Design

## Goal

Persist successful AI Recognition results locally so users can revisit recent
results without uploading their history to the backend.

## Storage

- Store history in `SharedPreferences` through a dedicated repository.
- Persist at most 30 entries, newest first.
- Save a compact JPEG thumbnail instead of the original image.
- Treat malformed or outdated stored entries as recoverable data and skip them.
- Do not store failed or cancelled recognition attempts.

Each entry contains:

- A locally generated ID.
- Recognition timestamp.
- Compressed thumbnail bytes.
- The complete `AiSearchResult`, including an optional database match.

## User Flow

1. The user selects or captures an image.
2. AI Recognition returns a successful result.
3. The app compresses the selected image and saves the result automatically.
4. The AI Recognition header exposes a History button.
5. History opens a separate screen with newest results first.
6. Each entry displays its thumbnail, detected name, result type, confidence,
   timestamp, and database-match indicator when available.
7. The user can delete an individual entry after confirmation.

## Architecture

- Extend `AiSearchResult` and `AiSearchDatabaseMatch` with symmetric JSON
  serialization.
- Add `AiRecognitionHistoryEntry` as the persisted model.
- Add `AiRecognitionHistoryRepository` as the only storage boundary.
- Keep persistence out of the recognition API service.
- Inject the repository into the AI Recognition and history pages for tests.
- Add `/ai-search/history` to the app router.

## Privacy And Limits

History remains on the current device and disappears when application data is
cleared or the app is removed. No image or recognition result is sent to
Supabase specifically for history storage.

The 30-entry cap and thumbnail compression prevent unbounded local storage
growth. If storage is unavailable or full, recognition still succeeds and the
app reports only the history-save failure without losing the current result.

## Testing

- JSON round-trip for recognition results and database matches.
- Save, order, cap, malformed-data recovery, and per-entry deletion.
- Automatic save after a successful recognition.
- History empty state, populated list, and deletion interaction.
- Router registration for the history page.
