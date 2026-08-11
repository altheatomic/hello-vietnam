# Place Content Supabase Secret Proxy Design

**Date:** 2026-08-11

**Status:** Approved by owner; implementation in progress

## Objective

Allow the five-province place-content pipeline to use the existing
`DEEPSEEK_API_KEY` stored in Supabase Edge Function secrets without exporting
the key to the local workstation or placing it in an artifact. The selected
content model is `deepseek-v4-flash`.

## Security boundary

The local Python process sends only a rendered prompt, its input hash, and the
existing service-role bearer token over HTTPS to a dedicated Edge Function.
The function validates the bearer token, reads the DeepSeek key and model from
its server-side environment, and calls the DeepSeek OpenAI-compatible API.
The key is never returned, logged, serialized into JSONL artifacts, or sent to
the Flutter client. The function performs no Supabase data writes.

## Components

### `place-content-generate` Edge Function

- JWT verification remains enabled at the Supabase gateway.
- The handler accepts only a bounded JSON object containing `prompt` and
  `input_hash`; callers cannot choose the model, endpoint, temperature, or
  token limit.
- It requires the service-role bearer token as an internal owner-only guard,
  reads `DEEPSEEK_API_KEY` and `DEEPSEEK_CONTENT_MODEL`, and uses
  `deepseek-v4-flash` only when the configured model is absent during local
  development.
- DeepSeek requests use JSON Output, `temperature: 0.2`, a 1,400-token cap,
  and non-thinking mode so generated content is returned as one JSON object.
- Responses are normalized to content, model, finish reason, and token usage;
  provider errors preserve retryable HTTP status without leaking headers or
  secret-shaped values.

### Python generator

- If `PLACE_CONTENT_GENERATE_URL` is configured, or if Supabase URL and
  service-role credentials are present while no direct DeepSeek key exists,
  the client calls the proxy.
- Otherwise the existing direct DeepSeek path remains available for local
  development and tests.
- The existing exact-input cache, retry policy, budget accounting, strict
  JSON parsing, and proposal-only workflow remain unchanged.

## Failure handling and rollout

- Missing proxy credentials fail before a network request.
- `429` and `5xx` responses remain retryable by the Python client; malformed,
  empty, or non-object content fails closed as a generation error.
- First deployment is verified with an unauthorized request and a bounded
  authorized fixture request. Only after those checks pass may a pilot
  generation run; no production apply is part of this change.

## Testing

- Deno unit tests cover bearer authorization, request construction, model
  locking, prompt limits, response normalization, and provider error mapping.
- Python tests cover automatic proxy selection, absence of a local DeepSeek
  key, proxy response parsing, retries, cache behavior, and unchanged direct
  mode.
- Existing place-content and Flutter regression suites must remain green.
