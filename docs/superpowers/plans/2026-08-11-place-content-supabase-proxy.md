# Place Content Supabase Secret Proxy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Route place-content generation through a protected Supabase Edge Function so the existing Supabase-stored DeepSeek key never leaves the server, using `deepseek-v4-flash`.

**Architecture:** A new `place-content-generate` Edge Function authenticates service-role callers, validates a bounded prompt request, calls DeepSeek JSON Output with fixed content-generation settings, and returns sanitized content plus usage. The Python generator automatically selects this proxy when Supabase URL/service-role credentials are present and no direct DeepSeek key is configured; its direct API mode remains available for isolated tests and local development.

**Tech Stack:** Supabase Edge Functions (Deno/TypeScript), DeepSeek OpenAI-compatible Chat Completions, Python 3.11, `httpx`, Pydantic, unittest, Supabase CLI.

## Global Constraints

- Never export, print, log, or store `DEEPSEEK_API_KEY`.
- The proxy accepts only service-role authenticated internal requests; no anonymous mode.
- The caller cannot select the provider URL, model, temperature, or output limit.
- Use model `deepseek-v4-flash`, JSON Output, temperature `0.2`, non-thinking mode, and max output `1400` tokens.
- Reject missing, malformed, overlong, or non-string prompts before calling DeepSeek.
- Preserve the existing strict `GeneratedContent` validation, retry, cache, budget, and proposal-only workflow.
- Do not write to Supabase data tables from the proxy or generation command.
- Do not run `apply` as part of this implementation; only audit, collect, generate, and validate are in scope.

---

### Task 1: Add pure proxy-domain contracts and failing Deno tests

**Files:**
- Create: `backend/supabase/functions/place-content-generate/place_content_generate_domain.ts`
- Create: `backend/supabase/functions/place-content-generate/place_content_generate_domain_test.ts`

**Interfaces:**
- `authorizeServiceRole(authorization: string | null, expectedToken: string): boolean`
- `parseProxyRequest(value: unknown): { prompt: string; inputHash: string }`
- `buildDeepSeekPayload(prompt: string, model: string): Record<string, unknown>`
- `normalizeDeepSeekResponse(body: unknown, model: string): { content: string; model: string; finishReason: string; inputTokens: number; outputTokens: number }`
- `providerErrorStatus(status: number): number`

- [ ] **Step 1: Write the failing Deno tests**

Cover these exact behaviors:

```ts
Deno.test("rejects a bearer token that is not the service role token", () => {
  assert(!authorizeServiceRole("Bearer wrong", "service-role"));
});

Deno.test("accepts the exact service role bearer token", () => {
  assert(authorizeServiceRole("Bearer service-role", "service-role"));
});

Deno.test("parses a bounded prompt request", () => {
  assertEquals(parseProxyRequest({ prompt: "p", input_hash: "h" }), {
    prompt: "p",
    inputHash: "h",
  });
});

Deno.test("rejects an empty or overlong prompt", () => {
  assertThrows(() => parseProxyRequest({ prompt: "", input_hash: "h" }));
  assertThrows(() => parseProxyRequest({ prompt: "x".repeat(120_001), input_hash: "h" }));
});

Deno.test("locks JSON output request settings", () => {
  assertEquals(buildDeepSeekPayload("prompt", "deepseek-v4-flash"), {
    model: "deepseek-v4-flash",
    temperature: 0.2,
    max_tokens: 1400,
    thinking: { type: "disabled" },
    response_format: { type: "json_object" },
    messages: [{ role: "user", content: "prompt" }],
  });
});

Deno.test("normalizes a valid provider response and maps retry status", () => {
  assertEquals(normalizeDeepSeekResponse({
    model: "deepseek-v4-flash",
    choices: [{
      finish_reason: "stop",
      message: { content: '{"ok":true}' },
    }],
    usage: { prompt_tokens: 10, completion_tokens: 4 },
  }, "deepseek-v4-flash"), {
    content: '{"ok":true}',
    model: "deepseek-v4-flash",
    finishReason: "stop",
    inputTokens: 10,
    outputTokens: 4,
  });
  assertEquals(providerErrorStatus(429), 429);
  assertEquals(providerErrorStatus(500), 502);
});
```

- [ ] **Step 2: Run the tests and confirm the expected missing-module failure**

Run from `backend`:

```powershell
npx deno test supabase/functions/place-content-generate/place_content_generate_domain_test.ts
```

Expected: FAIL because the new domain module does not exist.

- [ ] **Step 3: Implement the minimal pure domain module**

Use constant-time byte comparison for authorization, require a non-empty
`prompt` and `input_hash`, cap the prompt at 120,000 UTF-8 characters, keep
provider content as a string, require `finish_reason = "stop"`, and normalize
missing usage counts to zero. Throw ordinary `Error` instances with messages
that contain no request headers or secret values.

- [ ] **Step 4: Run the Deno tests and commit the domain contract**

```powershell
npx deno test supabase/functions/place-content-generate/place_content_generate_domain_test.ts
git add supabase/functions/place-content-generate/place_content_generate_domain.ts supabase/functions/place-content-generate/place_content_generate_domain_test.ts
git commit -m "feat: define place content proxy contract"
```

### Task 2: Implement the protected Edge Function

**Files:**
- Create: `backend/supabase/functions/place-content-generate/index.ts`
- Create: `backend/supabase/functions/place-content-generate/index_test.ts`

**Interfaces:**
- HTTP `POST /functions/v1/place-content-generate` with `{prompt,input_hash}`.
- Success JSON: `{content,model,finish_reason,input_tokens,output_tokens}`.
- Error JSON: `{error}` with `401`, `400`, `413`, `429`, `502`, or `500`.

- [ ] **Step 1: Write failing handler tests with a fake fetch**

Test the handler factory (not a live network call) for unauthorized requests,
invalid JSON, a valid request forwarding the fixed model/payload, and provider
429/5xx mapping. Assert the response never includes an API key or Authorization
header.

- [ ] **Step 2: Run the handler tests and confirm failure**

```powershell
npx deno test supabase/functions/place-content-generate/index_test.ts
```

- [ ] **Step 3: Implement the handler**

Read `SUPABASE_SERVICE_ROLE_KEY`, `DEEPSEEK_API_KEY`, and
`DEEPSEEK_CONTENT_MODEL` with required-environment guards. Set the model to
`deepseek-v4-flash` only for local development when the model env is absent;
production deployment includes the explicit secret. Call
`https://api.deepseek.com/chat/completions` with the domain payload, propagate
`Retry-After` for retryable errors, and return sanitized normalized JSON.

- [ ] **Step 4: Run Deno tests and lint/type-check**

```powershell
npx deno test supabase/functions/place-content-generate/index_test.ts supabase/functions/place-content-generate/place_content_generate_domain_test.ts
npx deno check supabase/functions/place-content-generate/index.ts
```

- [ ] **Step 5: Commit the Edge Function**

```powershell
git add supabase/functions/place-content-generate
git commit -m "feat: add protected place content generation proxy"
```

### Task 3: Add proxy mode to the Python generator with TDD

**Files:**
- Modify: `cf_service/scripts/place_content_backfill/generator.py`
- Modify: `cf_service/test_place_content_generator.py`
- Modify: `cf_service/scripts/place_content_backfill/cli.py`
- Modify: `cf_service/.env.example`

**Interfaces:**
- `DeepSeekContentClient(..., endpoint: str | None = None, auth_token: str | None = None)`.
- Proxy mode is selected from `PLACE_CONTENT_GENERATE_URL`, or from
  `SUPABASE_URL` plus `SUPABASE_SERVICE_ROLE_KEY` when no direct
  `DEEPSEEK_API_KEY` is configured.

- [ ] **Step 1: Add failing Python proxy tests**

Add tests that instantiate `DeepSeekContentClient` with only
`endpoint="https://proxy.test"` and `auth_token="service-role"`, verify the
request uses the proxy path and contains `{prompt,input_hash}` rather than a
DeepSeek Authorization header, parse the normalized proxy response, retry a
proxy `429`, and retain the existing direct-mode tests.

- [ ] **Step 2: Run the new tests and confirm failure**

```powershell
cd D:\Work\hello-vietnam\cf_service
& '.venv\Scripts\python.exe' -m unittest test_place_content_generator.PlaceContentGeneratorTest.test_proxy_mode_uses_service_role_without_deepseek_key -v
```

- [ ] **Step 3: Implement proxy selection and response parsing**

Construct the default endpoint as
`<SUPABASE_URL>/functions/v1/place-content-generate` only when the direct key
is absent and both Supabase variables exist. Send `Authorization: Bearer
<SUPABASE_SERVICE_ROLE_KEY>` to the proxy. Parse normalized proxy content into
the same `GenerationResult` contract; keep the input hash, cache, budget, and
retry behavior identical.

- [ ] **Step 4: Document proxy environment variables**

Add the following non-secret settings to `.env.example` without adding any
secret value:

```env
PLACE_CONTENT_GENERATE_URL=https://ziouozppetvvdrzgojcx.supabase.co/functions/v1/place-content-generate
DEEPSEEK_CONTENT_MODEL=deepseek-v4-flash
```

- [ ] **Step 5: Run the complete Python pipeline suite**

```powershell
& '.venv\Scripts\python.exe' -m unittest test_place_content_models.py test_place_content_artifacts.py test_place_content_repository.py test_place_content_sources.py test_place_content_naming.py test_place_content_generator.py test_place_content_validators.py test_place_content_apply.py test_recommend_place_detail.py -v
```

- [ ] **Step 6: Commit Python proxy mode**

```powershell
git add cf_service/scripts/place_content_backfill/generator.py cf_service/test_place_content_generator.py cf_service/scripts/place_content_backfill/cli.py cf_service/.env.example
git commit -m "feat: route place content generation through Supabase proxy"
```

### Task 4: Configure, deploy, and verify the remote proxy

**Files:**
- Modify remotely: Supabase Edge Function deployment and secret metadata only.

- [ ] **Step 1: Confirm model configuration without printing values**

```powershell
npx supabase secrets set DEEPSEEK_CONTENT_MODEL=deepseek-v4-flash --project-ref ziouozppetvvdrzgojcx --yes
npx supabase secrets list --project-ref ziouozppetvvdrzgojcx --output json | ConvertFrom-Json | Where-Object { $_.name -in @('DEEPSEEK_API_KEY','DEEPSEEK_CONTENT_MODEL') } | Select-Object name,updated_at
```

- [ ] **Step 2: Discover deploy flags and deploy with JWT verification**

```powershell
npx supabase functions deploy --help
npx supabase functions deploy place-content-generate --project-ref ziouozppetvvdrzgojcx
```

- [ ] **Step 3: Verify unauthorized reachability**

Send `OPTIONS` and a `POST` without authorization. Require `OPTIONS 200` and
`POST 401`; do not send a generation prompt in the unauthorized request.

- [ ] **Step 4: Run a bounded authorized fixture generation**

Use the local service-role credential in-process (never print it) with one
synthetic prompt and a 50-token budget. Require the response model to be
`deepseek-v4-flash`, `finish_reason = stop`, and valid JSON content. Do not
write the result to Supabase.

- [ ] **Step 5: Commit only sanitized verification notes if needed**

Record status codes, model name, and token counts only. Never record prompt
content, headers, keys, or response secrets.

### Task 5: Run the guarded content pipeline checkpoint

**Files:**
- No production table writes.
- Local untracked artifacts under `cf_service/.artifacts/place-content/`.

- [ ] **Step 1: Re-run read-only audit and retain the run ID**

```powershell
Set-Location D:\Work\hello-vietnam\cf_service
$audit = & '.venv\Scripts\python.exe' -c "from dotenv import load_dotenv; load_dotenv(); from scripts.place_content_backfill.cli import main; raise SystemExit(main(['audit','--scope','approved-five']))" | ConvertFrom-Json
$placeContentRunId = $audit.run_id
if ($audit.total -ne 1533 -or $audit.outside_scope -ne 0) { throw 'Audit scope/count gate failed.' }
```

- [ ] **Step 2: Collect grounded sources with the existing resumable command**

```powershell
& '.venv\Scripts\python.exe' -m scripts.place_content_backfill.cli collect --run-id $placeContentRunId
```

- [ ] **Step 3: Generate a bounded first checkpoint**

The current CLI bounds generation by requests rather than a stratified pilot
selector. Use the owner-approved cap and stop after the first 100 successful
requests; do not run an unbounded command:

```powershell
& '.venv\Scripts\python.exe' -m scripts.place_content_backfill.cli generate --run-id $placeContentRunId --max-requests 100
```

- [ ] **Step 4: Validate and export `needs-review.csv`**

```powershell
& '.venv\Scripts\python.exe' -m scripts.place_content_backfill.cli validate --run-id $placeContentRunId
& '.venv\Scripts\python.exe' -m scripts.place_content_backfill.cli status --run-id $placeContentRunId
```

- [ ] **Step 5: Stop for owner review before any `apply` command**

The checkpoint is complete only when audit counts remain 1,533, the proxy
fixture is healthy, generation artifacts contain no secret-shaped fields, and
all non-approved pilot rows are visible for review.
