import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  configuredGeminiKeys,
  configuredGeminiModels,
  requestGeminiWithFallback,
} from "./gemini_fallback.ts";

Deno.test("Gemini keys use the legacy key before numbered fallbacks", () => {
  const values: Record<string, string> = {
    GEMINI_API_KEY: "legacy",
    GEMINI_API_KEY_1: "first",
    GEMINI_API_KEY_2: "second",
    GEMINI_API_KEY_3: "second",
  };
  assertEquals(configuredGeminiKeys((name) => values[name]), [
    "legacy",
    "first",
    "second",
  ]);
});

Deno.test("Gemini models keep configured models before the stable fallback", () => {
  const values: Record<string, string> = {
    GEMINI_AI_SEARCH_MODEL: "old-model",
    GEMINI_AI_SEARCH_MODEL_1: "preferred-model",
  };
  assertEquals(configuredGeminiModels((name) => values[name]), [
    "old-model",
    "preferred-model",
    "gemini-3.5-flash-lite",
  ]);
});

Deno.test("Gemini retries with the next key after a quota error", async () => {
  const seenKeys: string[] = [];
  const result = await requestGeminiWithFallback({
    apiKeys: ["first", "second"],
    models: ["gemini-test"],
    body: { contents: [] },
    fetchFn: async (_url, init) => {
      seenKeys.push(
        (init?.headers as Record<string, string>)["x-goog-api-key"],
      );
      if (seenKeys.length === 1) {
        return new Response(
          JSON.stringify({ error: { message: "Quota exceeded" } }),
          {
            status: 429,
            headers: { "Content-Type": "application/json" },
          },
        );
      }
      return new Response(JSON.stringify({ candidates: [] }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    },
  });

  assertEquals(result.response.status, 200);
  assertEquals(result.attempts, 2);
  assertEquals(seenKeys, ["first", "second"]);
});

Deno.test("Gemini does not retry another key for an invalid request", async () => {
  let calls = 0;
  const result = await requestGeminiWithFallback({
    apiKeys: ["first", "second"],
    models: ["gemini-test"],
    body: { contents: [] },
    fetchFn: async () => {
      calls += 1;
      return new Response(
        JSON.stringify({ error: { message: "Bad request" } }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    },
  });

  assertEquals(result.response.status, 400);
  assertEquals(calls, 1);
});

Deno.test("Gemini changes model when the configured model is unavailable", async () => {
  const models: string[] = [];
  const result = await requestGeminiWithFallback({
    apiKeys: ["first"],
    models: ["retired-model", "gemini-3.5-flash-lite"],
    body: { contents: [] },
    fetchFn: async (url) => {
      const requestUrl = url instanceof Request ? url.url : url;
      const model = new URL(requestUrl).pathname.split("/").at(-1)?.split(
        ":",
      )[0];
      models.push(model ?? "");
      if (models.length === 1) {
        return new Response(
          JSON.stringify({ error: { message: "Model retired" } }),
          {
            status: 404,
            headers: { "Content-Type": "application/json" },
          },
        );
      }
      return new Response(JSON.stringify({ candidates: [] }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    },
  });

  assertEquals(result.response.status, 200);
  assertEquals(result.model, "gemini-3.5-flash-lite");
  assertEquals(result.attempts, 2);
  assertEquals(models, ["retired-model", "gemini-3.5-flash-lite"]);
});
