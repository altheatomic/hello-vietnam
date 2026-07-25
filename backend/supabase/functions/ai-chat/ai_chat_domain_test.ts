import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  AI_CHAT_ACTION_KEYS,
  AiChatValidationError,
  buildDeepSeekMessages,
  decodeCursor,
  encodeCursor,
  parseAiChatRequest,
  parseDeepSeekChatResult,
} from "./ai_chat_domain.ts";

const conversationId = "83c776cf-562f-4d92-9a41-37e06f78b020";
const requestId = "3d582a7d-a025-42a5-b878-6b079aa57da8";

Deno.test("send_message rejects empty content", () => {
  const error = assertThrows(
    () =>
      parseAiChatRequest({
        action: "send_message",
        request_id: requestId,
        content: "   ",
      }),
    AiChatValidationError,
  );

  assertEquals(error.code, "AI_CHAT_INVALID_REQUEST");
});

Deno.test("send_message rejects content longer than 2000 characters", () => {
  const error = assertThrows(
    () =>
      parseAiChatRequest({
        action: "send_message",
        request_id: requestId,
        content: "a".repeat(2001),
      }),
    AiChatValidationError,
  );

  assertEquals(error.code, "AI_CHAT_CONTENT_TOO_LONG");
});

Deno.test("requests reject malformed UUID fields", () => {
  const error = assertThrows(
    () =>
      parseAiChatRequest({
        action: "list_messages",
        conversation_id: "not-a-uuid",
      }),
    AiChatValidationError,
  );

  assertEquals(error.code, "AI_CHAT_INVALID_REQUEST");
});

Deno.test("all five request actions are parsed", () => {
  assertEquals(
    parseAiChatRequest({
      action: "send_message",
      conversation_id: conversationId,
      request_id: requestId,
      content: "  Plan a trip to Hue.  ",
    }),
    {
      action: "send_message",
      conversationId,
      requestId,
      content: "Plan a trip to Hue.",
    },
  );
  assertEquals(
    parseAiChatRequest({
      action: "list_conversations",
      cursor: "cursor-1",
      limit: 999,
    }),
    {
      action: "list_conversations",
      cursor: "cursor-1",
      limit: 20,
    },
  );
  assertEquals(
    parseAiChatRequest({
      action: "list_messages",
      conversation_id: conversationId,
      limit: 999,
    }),
    {
      action: "list_messages",
      conversationId,
      cursor: null,
      limit: 50,
    },
  );
  assertEquals(
    parseAiChatRequest({
      action: "delete_conversation",
      conversation_id: conversationId,
    }),
    {
      action: "delete_conversation",
      conversationId,
    },
  );
  assertEquals(
    parseAiChatRequest({
      action: "tts",
      text: "  Xin chao  ",
      language_code: "vi-VN",
    }),
    {
      action: "tts",
      text: "Xin chao",
      languageCode: "vi-VN",
    },
  );
});

Deno.test("send_message permits a new conversation without conversation_id", () => {
  assertEquals(
    parseAiChatRequest({
      action: "send_message",
      request_id: requestId,
      content: "Where should I go?",
    }),
    {
      action: "send_message",
      conversationId: null,
      requestId,
      content: "Where should I go?",
    },
  );
});

Deno.test("all allowlisted model action keys are retained", () => {
  assertEquals(AI_CHAT_ACTION_KEYS.length, 13);

  for (const key of AI_CHAT_ACTION_KEYS) {
    assertEquals(
      parseDeepSeekChatResult({
        answer: `Open ${key}`,
        action: { key, payload: { source: "assistant" } },
      }),
      {
        answer: `Open ${key}`,
        action: { key, payload: { source: "assistant" } },
      },
    );
  }
});

Deno.test("unknown model action is discarded without discarding the answer", () => {
  const result = parseDeepSeekChatResult({
    answer: "I can explain that.",
    action: { key: "/admin/users", payload: { url: "https://bad.test" } },
  });

  assertEquals(result.answer, "I can explain that.");
  assertEquals(result.action, null);
});

Deno.test("raw routes and URLs are removed from an allowed action payload", () => {
  const result = parseDeepSeekChatResult({
    answer: "Open your planner.",
    action: {
      key: "trip_planner",
      payload: {
        destination: "Hue",
        route: "/trip-planner",
        url: "https://bad.test",
        nested: {
          href: "com.example.hellovietnam://profile",
          days: 3,
        },
      },
    },
  });

  assertEquals(result, {
    answer: "Open your planner.",
    action: {
      key: "trip_planner",
      payload: {
        destination: "Hue",
        nested: { days: 3 },
      },
    },
  });
});

Deno.test("malformed model JSON falls back to plain answer text", () => {
  assertEquals(
    parseDeepSeekChatResult("  A normal answer, not JSON.  "),
    {
      answer: "A normal answer, not JSON.",
      action: null,
    },
  );
});

Deno.test("model answer is trimmed and capped at 2000 characters", () => {
  const result = parseDeepSeekChatResult({
    answer: ` ${"a".repeat(2100)} `,
    action: null,
  });

  assertEquals(result.answer.length, 2000);
  assertEquals(result.action, null);
});

Deno.test("context contains only the latest twelve messages plus new input", () => {
  const history = Array.from({ length: 14 }, (_, index) => ({
    role: index % 2 === 0 ? "user" as const : "assistant" as const,
    content: `message-${index}`,
  }));

  const messages = buildDeepSeekMessages(history, "new question");

  assertEquals(messages.length, 14);
  assertEquals(messages[0].role, "system");
  assertEquals(messages[1].content, "message-2");
  assertEquals(messages.at(-1), {
    role: "user",
    content: "new question",
  });
});

Deno.test("cursor encoding round-trips timestamp and id", () => {
  const createdAt = "2026-07-25T03:04:05.000Z";
  const id = "02e56992-bc37-4baa-9448-c6af0469f0e2";

  assertEquals(decodeCursor(encodeCursor(createdAt, id)), {
    createdAt,
    id,
  });
});

Deno.test("malformed cursors are rejected", () => {
  const error = assertThrows(
    () => decodeCursor("not-a-valid-cursor"),
    AiChatValidationError,
  );

  assertEquals(error.code, "AI_CHAT_INVALID_REQUEST");
});
