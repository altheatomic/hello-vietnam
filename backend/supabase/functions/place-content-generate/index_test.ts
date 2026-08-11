import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { createPlaceContentHandler } from "./index.ts";

const ENV = {
  SUPABASE_SERVICE_ROLE_KEY: "service-role",
  DEEPSEEK_API_KEY: "deepseek-secret",
  DEEPSEEK_CONTENT_MODEL: "deepseek-v4-flash",
};

function request(
  body: string,
  authorization = "Bearer service-role",
): Request {
  return new Request("https://example.test/functions/v1/place-content-generate", {
    method: "POST",
    headers: {
      Authorization: authorization,
      "Content-Type": "application/json",
    },
    body,
  });
}

Deno.test("handler rejects unauthorized requests before provider access", async () => {
  let calls = 0;
  const handler = createPlaceContentHandler({
    env: ENV,
    fetchFn: async () => {
      calls += 1;
      return new Response("unexpected", { status: 500 });
    },
  });

  const response = await handler(request('{"prompt":"p","input_hash":"h"}', "Bearer wrong"));
  assertEquals(response.status, 401);
  assertEquals(calls, 0);
  assert(!(await response.text()).includes("deepseek-secret"));
});

Deno.test("handler rejects invalid JSON and missing prompt", async () => {
  const handler = createPlaceContentHandler({ env: ENV, fetchFn: fetch });

  const invalidJson = await handler(request("not-json"));
  assertEquals(invalidJson.status, 400);

  const missingPrompt = await handler(request('{"input_hash":"h"}'));
  assertEquals(missingPrompt.status, 400);
});

Deno.test("handler forwards fixed settings and returns normalized content", async () => {
  let seenUrl = "";
  let seenInit: RequestInit | undefined;
  const handler = createPlaceContentHandler({
    env: ENV,
    fetchFn: async (url, init) => {
      seenUrl = String(url);
      seenInit = init;
      return new Response(JSON.stringify({
        model: "deepseek-v4-flash",
        choices: [{
          finish_reason: "stop",
          message: { content: '{"short_description_vi":"ok"}' },
        }],
        usage: { prompt_tokens: 12, completion_tokens: 5 },
      }), { status: 200, headers: { "Content-Type": "application/json" } });
    },
  });

  const response = await handler(request('{"prompt":"p","input_hash":"h"}'));
  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    content: '{"short_description_vi":"ok"}',
    model: "deepseek-v4-flash",
    finish_reason: "stop",
    input_tokens: 12,
    output_tokens: 5,
  });
  assertEquals(seenUrl, "https://api.deepseek.com/chat/completions");
  const payload = JSON.parse(String(seenInit?.body));
  assertEquals(payload.model, "deepseek-v4-flash");
  assertEquals(payload.thinking, { type: "disabled" });
  assertEquals(payload.response_format, { type: "json_object" });
  assertEquals(new Headers(seenInit?.headers).get("Authorization"), "Bearer deepseek-secret");
});

Deno.test("handler preserves retryable provider status without leaking details", async () => {
  const handler = createPlaceContentHandler({
    env: ENV,
    fetchFn: async () => new Response(JSON.stringify({
      error: { message: "provider unavailable", secret: "do-not-return" },
    }), {
      status: 429,
      headers: { "Retry-After": "2", "Content-Type": "application/json" },
    }),
  });

  const response = await handler(request('{"prompt":"p","input_hash":"h"}'));
  assertEquals(response.status, 429);
  assertEquals(response.headers.get("Retry-After"), "2");
  const body = await response.text();
  assertStringIncludes(body, "DeepSeek request failed");
  assert(!body.includes("do-not-return"));
});
