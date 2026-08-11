import {
  assert,
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  authorizeServiceRole,
  buildDeepSeekPayload,
  normalizeDeepSeekResponse,
  parseProxyRequest,
  providerErrorStatus,
} from "./place_content_generate_domain.ts";

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
  assertThrows(() =>
    parseProxyRequest({ prompt: "x".repeat(120_001), input_hash: "h" })
  );
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
  assertEquals(
    normalizeDeepSeekResponse(
      {
        model: "deepseek-v4-flash",
        choices: [{
          finish_reason: "stop",
          message: { content: '{"ok":true}' },
        }],
        usage: { prompt_tokens: 10, completion_tokens: 4 },
      },
      "deepseek-v4-flash",
    ),
    {
      content: '{"ok":true}',
      model: "deepseek-v4-flash",
      finishReason: "stop",
      inputTokens: 10,
      outputTokens: 4,
    },
  );
  assertEquals(providerErrorStatus(429), 429);
  assertEquals(providerErrorStatus(500), 502);
});
