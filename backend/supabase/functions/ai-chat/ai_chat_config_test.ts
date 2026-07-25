import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { resolveDeepSeekChatModel } from "./ai_chat_config.ts";

Deno.test("uses the current DeepSeek chat model when no override is set", () => {
  assertEquals(resolveDeepSeekChatModel(undefined), "deepseek-v4-flash");
});

Deno.test("uses a configured DeepSeek chat model override", () => {
  assertEquals(
    resolveDeepSeekChatModel("deepseek-v4-pro"),
    "deepseek-v4-pro",
  );
});
