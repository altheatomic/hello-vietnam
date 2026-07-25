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

export type AiChatPreparation =
  | {
      status: "ready";
      history: ChatHistoryMessage[];
    }
  | {
      status: "committed";
      exchange: CommittedExchange;
      remaining: number;
    }
  | { status: "premium_required" }
  | { status: "quota_reached" }
  | { status: "conversation_not_found" };

export interface CommitExchangeResult {
  exchange: CommittedExchange;
  remaining: number;
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
  prepareSendRequest(
    userId: string,
    conversationId: string,
    requestId: string,
    allowNewConversation: boolean,
    historyLimit: number,
  ): Promise<AiChatPreparation>;
  callDeepSeek(messages: DeepSeekMessage[]): Promise<DeepSeekCallResult>;
  commitExchange(input: CommitExchangeInput): Promise<CommitExchangeResult>;
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
  synthesizeSpeech(text: string, languageCode: string): Promise<VbeeTtsResult>;
}

export interface AiChatHandlerDependencies {
  gateway: AiChatGateway;
  now?: () => number;
  recordMetric?: (metric: AiChatRequestMetric) => void;
}

export interface AiChatRequestMetric {
  action: string;
  correlationId: string;
  status: number;
  totalMs: number;
  stagesMs: Record<string, number>;
  model?: string;
  inputTokens?: number;
  outputTokens?: number;
}

export class AiChatGatewayError extends Error {
  constructor(
    readonly code:
      | "AI_CHAT_CONVERSATION_NOT_FOUND"
      | "AI_CHAT_DAILY_LIMIT_REACHED"
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
  const metrics = new RequestMetrics(
    request.headers.get("x-request-id"),
    dependencies.now,
    dependencies.recordMetric,
  );
  let action = request.method === "OPTIONS" ? "options" : "unknown";
  const finish = (response: Response) => metrics.finish(response, action);

  if (request.method === "OPTIONS") {
    return finish(new Response("ok", { headers: corsHeaders }));
  }
  if (request.method !== "POST") {
    return finish(jsonResponse({ error: "AI_CHAT_INVALID_REQUEST" }, 405));
  }

  try {
    const body = await readJsonBody(request);
    const parsed = parseAiChatRequest(body);
    action = parsed.action;
    const gateway = dependencies.gateway;

    switch (parsed.action) {
      case "send_message": {
        const id = parsed.conversationId ?? crypto.randomUUID();
        const preparation = await metrics.measure("prepare", () =>
          gateway.prepareSendRequest(
            userId,
            id,
            parsed.requestId,
            parsed.conversationId === null,
            12,
          ),
        );

        if (preparation.status === "premium_required") {
          return finish(jsonResponse({ error: "PREMIUM_REQUIRED" }, 403));
        }
        if (preparation.status === "quota_reached") {
          return finish(
            jsonResponse(
              {
                error: "AI_CHAT_DAILY_LIMIT_REACHED",
                remaining: 0,
              },
              429,
            ),
          );
        }
        if (preparation.status === "conversation_not_found") {
          throw new AiChatGatewayError("AI_CHAT_CONVERSATION_NOT_FOUND", 404);
        }
        if (preparation.status === "committed") {
          return finish(
            exchangeResponse(preparation.exchange, preparation.remaining, true),
          );
        }

        let deepSeekResult: DeepSeekCallResult;
        try {
          deepSeekResult = await metrics.measure("deepseek", () =>
            gateway.callDeepSeek(
              buildDeepSeekMessages(preparation.history, parsed.content),
            ),
          );
        } catch (error) {
          console.error(
            "[ai-chat] DeepSeek provider call failed:",
            error instanceof Error ? error.message : String(error),
          );
          throw new AiChatGatewayError("AI_CHAT_PROVIDER_UNAVAILABLE", 503);
        }

        metrics.recordUsage(deepSeekResult);
        const modelResult = parseDeepSeekChatResult(deepSeekResult.content);
        const committed = await metrics.measure("commit", () =>
          gateway.commitExchange({
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
          }),
        );

        return finish(
          exchangeResponse(committed.exchange, committed.remaining, false),
        );
      }
      case "list_conversations": {
        const page = await metrics.measure("database", () =>
          gateway.listConversations(userId, parsed.cursor, parsed.limit),
        );
        return finish(
          jsonResponse({
            items: page.items.map(serializeConversation),
            next_cursor: page.nextCursor,
          }),
        );
      }
      case "list_messages": {
        const page = await metrics.measure("database", () =>
          gateway.listMessages(
            userId,
            parsed.conversationId,
            parsed.cursor,
            parsed.limit,
          ),
        );
        return finish(
          jsonResponse({
            items: page.items.map(serializeMessage),
            next_cursor: page.nextCursor,
          }),
        );
      }
      case "delete_conversation":
        await metrics.measure("database", () =>
          gateway.deleteConversation(userId, parsed.conversationId),
        );
        return finish(jsonResponse({ deleted: true }));
      case "tts": {
        await metrics.measure("premium", () => requirePremium(gateway, userId));
        try {
          const result = await metrics.measure("vbee", () =>
            gateway.synthesizeSpeech(parsed.text, parsed.languageCode),
          );
          return finish(
            jsonResponse({
              audio_url: result.audioUrl,
              request_id: result.requestId,
            }),
          );
        } catch {
          throw new AiChatGatewayError("AI_CHAT_TTS_UNAVAILABLE", 503);
        }
      }
    }
  } catch (error) {
    if (error instanceof AiChatValidationError) {
      return finish(jsonResponse({ error: error.code }, 400));
    }
    if (error instanceof AiChatGatewayError) {
      return finish(jsonResponse({ error: error.code }, error.statusCode));
    }
    return finish(jsonResponse({ error: "AI_CHAT_PROVIDER_UNAVAILABLE" }, 500));
  }
}

async function requirePremium(
  gateway: AiChatGateway,
  userId: string,
): Promise<void> {
  if (!(await gateway.hasActivePremium(userId))) {
    throw new AiChatGatewayError("PREMIUM_REQUIRED", 403);
  }
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

class RequestMetrics {
  readonly correlationId: string;
  private readonly startedAt: number;
  private readonly stagesMs: Record<string, number> = {};
  private readonly now: () => number;
  private model: string | undefined;
  private inputTokens: number | undefined;
  private outputTokens: number | undefined;

  constructor(
    requestedCorrelationId: string | null,
    now: (() => number) | undefined,
    private readonly recordMetric:
      | ((metric: AiChatRequestMetric) => void)
      | undefined,
  ) {
    this.now = now ?? (() => performance.now());
    this.startedAt = this.now();
    const requested = requestedCorrelationId?.trim() ?? "";
    this.correlationId =
      requested && requested.length <= 100 ? requested : crypto.randomUUID();
  }

  async measure<T>(stage: string, operation: () => Promise<T>): Promise<T> {
    const startedAt = this.now();
    try {
      return await operation();
    } finally {
      this.stagesMs[stage] = Math.max(
        (this.stagesMs[stage] ?? 0) + this.now() - startedAt,
        0,
      );
    }
  }

  recordUsage(result: DeepSeekCallResult): void {
    this.model = result.model;
    this.inputTokens = result.inputTokens;
    this.outputTokens = result.outputTokens;
  }

  finish(response: Response, action: string): Response {
    const totalMs = Math.max(this.now() - this.startedAt, 0);
    const headers = new Headers(response.headers);
    headers.set("x-request-id", this.correlationId);
    headers.set(
      "server-timing",
      [
        ...Object.entries(this.stagesMs).map(
          ([stage, duration]) => `${stage};dur=${duration.toFixed(1)}`,
        ),
        `total;dur=${totalMs.toFixed(1)}`,
      ].join(", "),
    );
    this.recordMetric?.({
      action,
      correlationId: this.correlationId,
      status: response.status,
      totalMs,
      stagesMs: { ...this.stagesMs },
      model: this.model,
      inputTokens: this.inputTokens,
      outputTokens: this.outputTokens,
    });
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
  }
}
