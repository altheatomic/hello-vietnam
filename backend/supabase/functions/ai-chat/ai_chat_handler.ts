import { corsHeaders } from "../_shared/cors.ts";
import type { VbeeTtsResult } from "../_shared/vbee_tts.ts";
import {
  AiChatValidationError,
  buildDeepSeekMessages,
  type ChatHistoryMessage,
  type DeepSeekMessage,
  parseAiChatRequest,
  parseDeepSeekChatResult,
} from "./ai_chat_domain.ts";

export interface AiChatConversationRecord {
  id: string;
  title: string;
  createdAt: string;
  updatedAt: string;
}

export interface AiChatMessageRecord {
  id: string;
  conversationId: string;
  role: "user" | "assistant";
  content: string;
  actionKey: string | null;
  actionPayload: Record<string, unknown> | null;
  requestId: string | null;
  createdAt: string;
}

export interface CommittedExchange {
  conversationId: string;
  messages: AiChatMessageRecord[];
}

export interface DeepSeekCallResult {
  content: unknown;
  model: string;
  inputTokens: number;
  outputTokens: number;
  estimatedCost: number;
}

export interface CommitExchangeInput {
  userId: string;
  conversationId: string;
  requestId: string;
  userContent: string;
  assistantContent: string;
  actionKey: string | null;
  actionPayload: Record<string, unknown> | null;
  model: string;
  inputTokens: number;
  outputTokens: number;
  estimatedCost: number;
}

export interface ConversationPage {
  items: AiChatConversationRecord[];
  nextCursor: string | null;
}

export interface MessagePage {
  items: AiChatMessageRecord[];
  nextCursor: string | null;
}

export interface AiChatGateway {
  hasActivePremium(userId: string): Promise<boolean>;
  getDailyMessageLimit(userId: string): Promise<number>;
  getSuccessfulMessagesToday(userId: string): Promise<number>;
  findCommittedExchange(
    userId: string,
    conversationId: string,
    requestId: string,
  ): Promise<CommittedExchange | null>;
  loadRecentMessages(
    userId: string,
    conversationId: string,
    limit: number,
  ): Promise<ChatHistoryMessage[]>;
  callDeepSeek(messages: DeepSeekMessage[]): Promise<DeepSeekCallResult>;
  commitExchange(input: CommitExchangeInput): Promise<CommittedExchange>;
  listConversations(
    userId: string,
    cursor: string | null,
    limit: number,
  ): Promise<ConversationPage>;
  listMessages(
    userId: string,
    conversationId: string,
    cursor: string | null,
    limit: number,
  ): Promise<MessagePage>;
  deleteConversation(userId: string, conversationId: string): Promise<void>;
  synthesizeSpeech(
    text: string,
    languageCode: string,
  ): Promise<VbeeTtsResult>;
}

export interface AiChatHandlerDependencies {
  gateway: AiChatGateway;
}

export class AiChatGatewayError extends Error {
  constructor(
    readonly code:
      | "AI_CHAT_CONVERSATION_NOT_FOUND"
      | "AI_CHAT_PROVIDER_UNAVAILABLE"
      | "AI_CHAT_TTS_UNAVAILABLE"
      | "PREMIUM_REQUIRED",
    readonly statusCode: number,
  ) {
    super(code);
    this.name = "AiChatGatewayError";
  }
}

export async function handleAiChatRequest(
  dependencies: AiChatHandlerDependencies,
  request: Request,
  userId: string,
): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "AI_CHAT_INVALID_REQUEST" }, 405);
  }

  try {
    const body = await readJsonBody(request);
    const parsed = parseAiChatRequest(body);
    const gateway = dependencies.gateway;

    switch (parsed.action) {
      case "send_message": {
        await requirePremium(gateway, userId);
        const id = parsed.conversationId ?? crypto.randomUUID();
        const existing = await gateway.findCommittedExchange(
          userId,
          id,
          parsed.requestId,
        );

        if (existing !== null) {
          const remaining = await loadRemainingQuota(gateway, userId);
          return exchangeResponse(existing, remaining, true);
        }

        const limit = await gateway.getDailyMessageLimit(userId);
        const successful = await gateway.getSuccessfulMessagesToday(userId);
        if (successful >= limit) {
          return jsonResponse({
            error: "AI_CHAT_DAILY_LIMIT_REACHED",
            remaining: 0,
          }, 429);
        }

        const history = await gateway.loadRecentMessages(userId, id, 12);
        let deepSeekResult: DeepSeekCallResult;
        try {
          deepSeekResult = await gateway.callDeepSeek(
            buildDeepSeekMessages(history, parsed.content),
          );
        } catch {
          throw new AiChatGatewayError(
            "AI_CHAT_PROVIDER_UNAVAILABLE",
            503,
          );
        }

        const modelResult = parseDeepSeekChatResult(deepSeekResult.content);
        const exchange = await gateway.commitExchange({
          userId,
          conversationId: id,
          requestId: parsed.requestId,
          userContent: parsed.content,
          assistantContent: modelResult.answer,
          actionKey: modelResult.action?.key ?? null,
          actionPayload: modelResult.action?.payload ?? null,
          model: deepSeekResult.model,
          inputTokens: deepSeekResult.inputTokens,
          outputTokens: deepSeekResult.outputTokens,
          estimatedCost: deepSeekResult.estimatedCost,
        });

        return exchangeResponse(
          exchange,
          Math.max(limit - successful - 1, 0),
          false,
        );
      }
      case "list_conversations": {
        const page = await gateway.listConversations(
          userId,
          parsed.cursor,
          parsed.limit,
        );
        return jsonResponse({
          items: page.items.map(serializeConversation),
          next_cursor: page.nextCursor,
        });
      }
      case "list_messages": {
        const page = await gateway.listMessages(
          userId,
          parsed.conversationId,
          parsed.cursor,
          parsed.limit,
        );
        return jsonResponse({
          items: page.items.map(serializeMessage),
          next_cursor: page.nextCursor,
        });
      }
      case "delete_conversation":
        await gateway.deleteConversation(userId, parsed.conversationId);
        return jsonResponse({ deleted: true });
      case "tts": {
        await requirePremium(gateway, userId);
        try {
          const result = await gateway.synthesizeSpeech(
            parsed.text,
            parsed.languageCode,
          );
          return jsonResponse({
            audio_url: result.audioUrl,
            request_id: result.requestId,
          });
        } catch {
          throw new AiChatGatewayError("AI_CHAT_TTS_UNAVAILABLE", 503);
        }
      }
    }
  } catch (error) {
    if (error instanceof AiChatValidationError) {
      return jsonResponse({ error: error.code }, 400);
    }
    if (error instanceof AiChatGatewayError) {
      return jsonResponse({ error: error.code }, error.statusCode);
    }
    return jsonResponse({ error: "AI_CHAT_PROVIDER_UNAVAILABLE" }, 500);
  }
}

async function requirePremium(
  gateway: AiChatGateway,
  userId: string,
): Promise<void> {
  if (!await gateway.hasActivePremium(userId)) {
    throw new AiChatGatewayError("PREMIUM_REQUIRED", 403);
  }
}

async function loadRemainingQuota(
  gateway: AiChatGateway,
  userId: string,
): Promise<number> {
  const [limit, successful] = await Promise.all([
    gateway.getDailyMessageLimit(userId),
    gateway.getSuccessfulMessagesToday(userId),
  ]);
  return Math.max(limit - successful, 0);
}

async function readJsonBody(
  request: Request,
): Promise<Record<string, unknown>> {
  try {
    const body = await request.json();
    if (typeof body !== "object" || body === null || Array.isArray(body)) {
      throw new Error("invalid body");
    }
    return body as Record<string, unknown>;
  } catch {
    throw new AiChatValidationError("AI_CHAT_INVALID_REQUEST");
  }
}

function exchangeResponse(
  exchange: CommittedExchange,
  remaining: number,
  idempotent: boolean,
): Response {
  return jsonResponse({
    conversation_id: exchange.conversationId,
    messages: exchange.messages.map(serializeMessage),
    remaining,
    idempotent,
  });
}

function serializeConversation(
  conversation: AiChatConversationRecord,
): Record<string, unknown> {
  return {
    id_conversation: conversation.id,
    title: conversation.title,
    created_at: conversation.createdAt,
    updated_at: conversation.updatedAt,
  };
}

function serializeMessage(
  message: AiChatMessageRecord,
): Record<string, unknown> {
  const serialized: Record<string, unknown> = {
    id_message: message.id,
    id_conversation: message.conversationId,
    role: message.role,
    content: message.content,
    request_id: message.requestId,
    created_at: message.createdAt,
  };
  if (message.actionKey !== null) {
    serialized.action = {
      key: message.actionKey,
      payload: message.actionPayload ?? {},
    };
  }
  return serialized;
}

function jsonResponse(
  payload: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json; charset=utf-8",
    },
  });
}
