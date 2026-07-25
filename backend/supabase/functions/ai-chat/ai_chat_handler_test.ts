import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { ChatHistoryMessage, DeepSeekMessage } from "./ai_chat_domain.ts";
import {
  type AiChatConversationRecord,
  type AiChatGateway,
  type AiChatMessageRecord,
  type CommitExchangeInput,
  type CommittedExchange,
  type ConversationPage,
  type DeepSeekCallResult,
  handleAiChatRequest,
  type MessagePage,
} from "./ai_chat_handler.ts";
import type { VbeeTtsResult } from "../_shared/vbee_tts.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const conversationId = "22222222-2222-4222-8222-222222222222";
const requestId = "33333333-3333-4333-8333-333333333333";
const createdAt = "2026-07-25T01:00:00.000Z";

class FakeGateway implements AiChatGateway {
  premium = true;
  dailyLimit = 100;
  successfulToday = 0;
  committed: CommittedExchange | null = null;
  recentMessages: ChatHistoryMessage[] = [];
  deepSeekResult: DeepSeekCallResult = {
    content: JSON.stringify({
      answer: "Here is a plan.",
      action: { key: "trip_planner", payload: { destination: "Hue" } },
    }),
    model: "deepseek-chat",
    inputTokens: 20,
    outputTokens: 30,
    estimatedCost: 0.001,
  };
  conversationPage: ConversationPage = {
    items: [],
    nextCursor: null,
  };
  messagePage: MessagePage = {
    items: [],
    nextCursor: null,
  };
  premiumChecks = 0;
  deepSeekCalls = 0;
  deepSeekMessages: DeepSeekMessage[] | null = null;
  findArgs: {
    userId: string;
    conversationId: string;
    requestId: string;
  } | null = null;
  committedInput: CommitExchangeInput | null = null;
  listConversationsArgs: {
    userId: string;
    cursor: string | null;
    limit: number;
  } | null = null;
  listMessagesArgs: {
    userId: string;
    conversationId: string;
    cursor: string | null;
    limit: number;
  } | null = null;
  deleted: { userId: string; conversationId: string } | null = null;
  synthesized: { text: string; languageCode: string } | null = null;

  hasActivePremium(_userId: string): Promise<boolean> {
    this.premiumChecks += 1;
    return Promise.resolve(this.premium);
  }

  getDailyMessageLimit(_userId: string): Promise<number> {
    return Promise.resolve(this.dailyLimit);
  }

  getSuccessfulMessagesToday(_userId: string): Promise<number> {
    return Promise.resolve(this.successfulToday);
  }

  findCommittedExchange(
    authenticatedUserId: string,
    id: string,
    idempotencyKey: string,
  ): Promise<CommittedExchange | null> {
    this.findArgs = {
      userId: authenticatedUserId,
      conversationId: id,
      requestId: idempotencyKey,
    };
    return Promise.resolve(this.committed);
  }

  loadRecentMessages(
    _userId: string,
    _conversationId: string,
    limit: number,
  ): Promise<ChatHistoryMessage[]> {
    return Promise.resolve(this.recentMessages.slice(-limit));
  }

  callDeepSeek(messages: DeepSeekMessage[]): Promise<DeepSeekCallResult> {
    this.deepSeekCalls += 1;
    this.deepSeekMessages = messages;
    return Promise.resolve(this.deepSeekResult);
  }

  commitExchange(input: CommitExchangeInput): Promise<CommittedExchange> {
    this.committedInput = input;
    return Promise.resolve(exchangeFromInput(input));
  }

  listConversations(
    authenticatedUserId: string,
    cursor: string | null,
    limit: number,
  ): Promise<ConversationPage> {
    this.listConversationsArgs = {
      userId: authenticatedUserId,
      cursor,
      limit,
    };
    return Promise.resolve(this.conversationPage);
  }

  listMessages(
    authenticatedUserId: string,
    id: string,
    cursor: string | null,
    limit: number,
  ): Promise<MessagePage> {
    this.listMessagesArgs = {
      userId: authenticatedUserId,
      conversationId: id,
      cursor,
      limit,
    };
    return Promise.resolve(this.messagePage);
  }

  deleteConversation(
    authenticatedUserId: string,
    id: string,
  ): Promise<void> {
    this.deleted = {
      userId: authenticatedUserId,
      conversationId: id,
    };
    return Promise.resolve();
  }

  synthesizeSpeech(
    text: string,
    languageCode: string,
  ): Promise<VbeeTtsResult> {
    this.synthesized = { text, languageCode };
    return Promise.resolve({
      audioUrl: "https://audio.test/result.mp3",
      requestId: "vbee-request",
    });
  }
}

Deno.test("non-Premium users cannot send messages", async () => {
  const gateway = new FakeGateway();
  gateway.premium = false;

  const response = await handleAiChatRequest(
    { gateway },
    post({
      action: "send_message",
      conversation_id: conversationId,
      request_id: requestId,
      content: "Plan a trip.",
    }),
    userId,
  );

  assertEquals(response.status, 403);
  assertEquals((await response.json()).error, "PREMIUM_REQUIRED");
  assertEquals(gateway.deepSeekCalls, 0);
});

Deno.test("non-Premium users cannot synthesize speech", async () => {
  const gateway = new FakeGateway();
  gateway.premium = false;

  const response = await handleAiChatRequest(
    { gateway },
    post({
      action: "tts",
      text: "Xin chao",
      language_code: "vi-VN",
    }),
    userId,
  );

  assertEquals(response.status, 403);
  assertEquals((await response.json()).error, "PREMIUM_REQUIRED");
  assertEquals(gateway.synthesized, null);
});

Deno.test("expired Premium users can still list and delete history", async () => {
  const gateway = new FakeGateway();
  gateway.premium = false;

  const listResponse = await handleAiChatRequest(
    { gateway },
    post({ action: "list_conversations" }),
    userId,
  );
  const deleteResponse = await handleAiChatRequest(
    { gateway },
    post({
      action: "delete_conversation",
      conversation_id: conversationId,
      id_user: "attacker",
    }),
    userId,
  );

  assertEquals(listResponse.status, 200);
  assertEquals(deleteResponse.status, 200);
  assertEquals(gateway.premiumChecks, 0);
  assertEquals(gateway.deleted, { userId, conversationId });
});

Deno.test("daily quota rejects the 101st successful message", async () => {
  const gateway = new FakeGateway();
  gateway.successfulToday = 100;

  const response = await handleAiChatRequest(
    { gateway },
    sendRequest(),
    userId,
  );

  assertEquals(response.status, 429);
  assertEquals(
    (await response.json()).error,
    "AI_CHAT_DAILY_LIMIT_REACHED",
  );
  assertEquals(gateway.deepSeekCalls, 0);
});

Deno.test("the 100th message succeeds and reports zero remaining", async () => {
  const gateway = new FakeGateway();
  gateway.successfulToday = 99;

  const response = await handleAiChatRequest(
    { gateway },
    sendRequest(),
    userId,
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.remaining, 0);
  assertEquals(gateway.deepSeekCalls, 1);
  assertEquals(gateway.committedInput?.actionKey, "trip_planner");
  assertEquals(gateway.committedInput?.actionPayload, {
    destination: "Hue",
  });
});

Deno.test("an idempotent retry returns the committed exchange", async () => {
  const gateway = new FakeGateway();
  gateway.committed = existingExchange();

  const response = await handleAiChatRequest(
    { gateway },
    sendRequest(),
    userId,
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.conversation_id, conversationId);
  assertEquals(body.idempotent, true);
  assertEquals(gateway.deepSeekCalls, 0);
  assertEquals(gateway.committedInput, null);
});

Deno.test("send forwards only twelve history messages plus new input", async () => {
  const gateway = new FakeGateway();
  gateway.recentMessages = Array.from({ length: 14 }, (_, index) => ({
    role: index % 2 === 0 ? "user" as const : "assistant" as const,
    content: `message-${index}`,
  }));

  await handleAiChatRequest({ gateway }, sendRequest(), userId);

  assertEquals(gateway.deepSeekMessages?.length, 14);
  assertEquals(gateway.deepSeekMessages?.[1].content, "message-2");
  assertEquals(gateway.deepSeekMessages?.at(-1)?.content, "Plan Hue");
});

Deno.test("malformed model actions are absent from committed response", async () => {
  const gateway = new FakeGateway();
  gateway.deepSeekResult.content = JSON.stringify({
    answer: "I can help explain it.",
    action: {
      key: "/admin/users",
      payload: { url: "https://bad.test" },
    },
  });

  const response = await handleAiChatRequest(
    { gateway },
    sendRequest(),
    userId,
  );
  const body = await response.json();
  const assistant = body.messages.find(
    (message: Record<string, unknown>) => message.role === "assistant",
  );

  assertEquals(gateway.committedInput?.actionKey, null);
  assertEquals(gateway.committedInput?.actionPayload, null);
  assertEquals("action" in assistant, false);
});

Deno.test("list actions force page limits to 20 and 50", async () => {
  const gateway = new FakeGateway();

  await handleAiChatRequest(
    { gateway },
    post({ action: "list_conversations", limit: 1000 }),
    userId,
  );
  await handleAiChatRequest(
    { gateway },
    post({
      action: "list_messages",
      conversation_id: conversationId,
      limit: 1000,
    }),
    userId,
  );

  assertEquals(gateway.listConversationsArgs?.limit, 20);
  assertEquals(gateway.listMessagesArgs?.limit, 50);
});

Deno.test("delete is always scoped to the authenticated user", async () => {
  const gateway = new FakeGateway();

  const response = await handleAiChatRequest(
    { gateway },
    post({
      action: "delete_conversation",
      conversation_id: conversationId,
      id_user: "attacker",
    }),
    userId,
  );

  assertEquals(response.status, 200);
  assertEquals(gateway.deleted, { userId, conversationId });
});

Deno.test("tts returns the Vbee audio URL without exposing credentials", async () => {
  const gateway = new FakeGateway();

  const response = await handleAiChatRequest(
    { gateway },
    post({
      action: "tts",
      text: "Xin chao",
      language_code: "vi-VN",
    }),
    userId,
  );

  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    audio_url: "https://audio.test/result.mp3",
    request_id: "vbee-request",
  });
});

Deno.test("OPTIONS returns the shared CORS response", async () => {
  const response = await handleAiChatRequest(
    { gateway: new FakeGateway() },
    new Request("https://example.test/ai-chat", { method: "OPTIONS" }),
    userId,
  );

  assertEquals(response.status, 200);
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
});

function post(body: Record<string, unknown>): Request {
  return new Request("https://example.test/ai-chat", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

function sendRequest(): Request {
  return post({
    action: "send_message",
    conversation_id: conversationId,
    request_id: requestId,
    content: "Plan Hue",
  });
}

function existingExchange(): CommittedExchange {
  return {
    conversationId,
    messages: [
      message({
        id: "44444444-4444-4444-8444-444444444444",
        role: "user",
        content: "Plan Hue",
      }),
      message({
        id: "55555555-5555-4555-8555-555555555555",
        role: "assistant",
        content: "Here is a plan.",
      }),
    ],
  };
}

function exchangeFromInput(input: CommitExchangeInput): CommittedExchange {
  return {
    conversationId: input.conversationId,
    messages: [
      message({
        id: "66666666-6666-4666-8666-666666666666",
        role: "user",
        content: input.userContent,
      }),
      message({
        id: "77777777-7777-4777-8777-777777777777",
        role: "assistant",
        content: input.assistantContent,
        actionKey: input.actionKey,
        actionPayload: input.actionPayload,
      }),
    ],
  };
}

function message({
  id,
  role,
  content,
  actionKey = null,
  actionPayload = null,
}: {
  id: string;
  role: AiChatMessageRecord["role"];
  content: string;
  actionKey?: AiChatMessageRecord["actionKey"];
  actionPayload?: AiChatMessageRecord["actionPayload"];
}): AiChatMessageRecord {
  return {
    id,
    conversationId,
    role,
    content,
    actionKey,
    actionPayload,
    requestId,
    createdAt,
  };
}

// Referenced so the compiler validates the public page record contract.
const _conversationShape: AiChatConversationRecord = {
  id: conversationId,
  title: "Hue trip",
  createdAt,
  updatedAt: createdAt,
};
