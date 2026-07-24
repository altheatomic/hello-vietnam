import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import {
  AuthorizationError,
  requireAuthenticatedUserId,
  requireAuthorizationHeader,
} from "../auth/auth_guard.ts";
import {
  synthesizeVbeeSpeech,
  type VbeeTtsConfig,
} from "../_shared/vbee_tts.ts";
import { corsHeaders } from "../_shared/cors.ts";
import {
  type AiChatConversationRecord,
  type AiChatGateway,
  AiChatGatewayError,
  type AiChatMessageRecord,
  type CommitExchangeInput,
  type CommittedExchange,
  type ConversationPage,
  type DeepSeekCallResult,
  handleAiChatRequest,
  type MessagePage,
} from "./ai_chat_handler.ts";
import {
  type ChatHistoryMessage,
  decodeCursor,
  type DeepSeekMessage,
  encodeCursor,
} from "./ai_chat_domain.ts";

type JsonObject = Record<string, unknown>;

const SUPABASE_URL = requiredEnvironment("SUPABASE_URL");
const SUPABASE_ANON_KEY = requiredEnvironment("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = requiredEnvironment(
  "SUPABASE_SERVICE_ROLE_KEY",
);
const DEEPSEEK_API_KEY = requiredEnvironment("DEEPSEEK_API_KEY");
const DEEPSEEK_BASE_URL = (
  Deno.env.get("DEEPSEEK_BASE_URL") ?? "https://api.deepseek.com"
).replace(/\/+$/u, "");
const DEEPSEEK_MODEL = Deno.env.get("DEEPSEEK_CHAT_MODEL") ?? "deepseek-chat";

class SupabaseAiChatGateway implements AiChatGateway {
  constructor(private readonly client: SupabaseClient) {}

  async hasActivePremium(userId: string): Promise<boolean> {
    const { data, error } = await this.client
      .from("premium_subscription")
      .select("id_prs")
      .eq("id_user", userId)
      .eq("status", "active")
      .gt("end_date", new Date().toISOString())
      .limit(1)
      .maybeSingle();
    assertDatabaseSuccess(error);
    return data !== null;
  }

  async getDailyMessageLimit(userId: string): Promise<number> {
    const { data, error } = await this.client
      .from("ai_user_quota")
      .select("daily_limit")
      .eq("id_user", userId)
      .eq("feature", "ai_chat")
      .maybeSingle();
    assertDatabaseSuccess(error);
    const limit = Number(data?.daily_limit ?? 100);
    return Number.isInteger(limit) && limit >= 0 ? limit : 100;
  }

  async getSuccessfulMessagesToday(userId: string): Promise<number> {
    const now = new Date();
    const dayStart = new Date(Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate(),
    )).toISOString();
    const { count, error } = await this.client
      .from("ai_usage_log")
      .select("id", { count: "exact", head: true })
      .eq("id_user", userId)
      .eq("provider", "deepseek")
      .eq("feature", "ai_chat")
      .eq("status", "success")
      .gte("created_at", dayStart);
    assertDatabaseSuccess(error);
    return count ?? 0;
  }

  async findCommittedExchange(
    userId: string,
    conversationId: string,
    requestId: string,
  ): Promise<CommittedExchange | null> {
    if (!await this.ownsConversation(userId, conversationId)) return null;

    const { data, error } = await this.client
      .from("ai_chat_message")
      .select(
        "id_message,id_conversation,role,content,action_key,action_payload,request_id,created_at",
      )
      .eq("id_conversation", conversationId)
      .eq("request_id", requestId)
      .order("created_at")
      .order("id_message");
    assertDatabaseSuccess(error);
    if ((data?.length ?? 0) !== 2) return null;
    return {
      conversationId,
      messages: data!.map(mapMessage),
    };
  }

  async loadRecentMessages(
    userId: string,
    conversationId: string,
    limit: number,
  ): Promise<ChatHistoryMessage[]> {
    if (!await this.ownsConversation(userId, conversationId)) return [];

    const { data, error } = await this.client
      .from("ai_chat_message")
      .select("role,content,created_at,id_message")
      .eq("id_conversation", conversationId)
      .order("created_at", { ascending: false })
      .order("id_message", { ascending: false })
      .limit(limit);
    assertDatabaseSuccess(error);
    return ((data ?? []) as JsonObject[]).reverse().map((row) => ({
      role: row.role === "assistant" ? "assistant" : "user",
      content: String(row.content ?? ""),
    }));
  }

  async callDeepSeek(
    messages: DeepSeekMessage[],
  ): Promise<DeepSeekCallResult> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 30_000);
    try {
      const response = await fetch(`${DEEPSEEK_BASE_URL}/chat/completions`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${DEEPSEEK_API_KEY}`,
          "Content-Type": "application/json",
        },
        signal: controller.signal,
        body: JSON.stringify({
          model: DEEPSEEK_MODEL,
          temperature: 0.4,
          max_tokens: 900,
          response_format: { type: "json_object" },
          messages,
        }),
      });
      const body = await response.json().catch(() => null) as JsonObject | null;
      if (!response.ok) {
        throw new Error(`DeepSeek request failed (${response.status})`);
      }
      const content = nestedValue(body, ["choices", 0, "message", "content"]);
      if (typeof content !== "string" || !content.trim()) {
        throw new Error("DeepSeek returned an empty response");
      }
      const inputTokens = numericValue(
        nestedValue(body, ["usage", "prompt_tokens"]),
      );
      const outputTokens = numericValue(
        nestedValue(body, ["usage", "completion_tokens"]),
      );
      return {
        content,
        model: DEEPSEEK_MODEL,
        inputTokens,
        outputTokens,
        estimatedCost: estimateCost(
          DEEPSEEK_MODEL,
          inputTokens,
          outputTokens,
        ),
      };
    } finally {
      clearTimeout(timeout);
    }
  }

  async commitExchange(
    input: CommitExchangeInput,
  ): Promise<CommittedExchange> {
    const { data, error } = await this.client.rpc("commit_ai_chat_exchange", {
      p_id_user: input.userId,
      p_id_conversation: input.conversationId,
      p_request_id: input.requestId,
      p_user_content: input.userContent,
      p_assistant_content: input.assistantContent,
      p_action_key: input.actionKey,
      p_action_payload: input.actionPayload,
      p_model: input.model,
      p_input_tokens: input.inputTokens,
      p_output_tokens: input.outputTokens,
      p_estimated_cost: input.estimatedCost,
    });
    assertDatabaseSuccess(error);
    const result = requireRecord(data);
    const messages = Array.isArray(result.messages) ? result.messages : [];
    return {
      conversationId: String(
        result.conversation_id ?? input.conversationId,
      ),
      messages: messages.map((message) => mapMessage(requireRecord(message))),
    };
  }

  async listConversations(
    userId: string,
    cursor: string | null,
    limit: number,
  ): Promise<ConversationPage> {
    let query = this.client
      .from("ai_chat_conversation")
      .select("id_conversation,title,created_at,updated_at")
      .eq("id_user", userId)
      .order("updated_at", { ascending: false })
      .order("id_conversation", { ascending: false })
      .limit(limit + 1);
    if (cursor !== null) {
      const decoded = decodeCursor(cursor);
      query = query.or(
        `updated_at.lt.${decoded.createdAt},and(updated_at.eq.${decoded.createdAt},id_conversation.lt.${decoded.id})`,
      );
    }
    const { data, error } = await query;
    assertDatabaseSuccess(error);
    const rows = data ?? [];
    const hasMore = rows.length > limit;
    const included = rows.slice(0, limit).map(mapConversation);
    const last = included.at(-1);
    return {
      items: included,
      nextCursor: hasMore && last
        ? encodeCursor(last.updatedAt, last.id)
        : null,
    };
  }

  async listMessages(
    userId: string,
    conversationId: string,
    cursor: string | null,
    limit: number,
  ): Promise<MessagePage> {
    if (!await this.ownsConversation(userId, conversationId)) {
      throw new AiChatGatewayError(
        "AI_CHAT_CONVERSATION_NOT_FOUND",
        404,
      );
    }
    let query = this.client
      .from("ai_chat_message")
      .select(
        "id_message,id_conversation,role,content,action_key,action_payload,request_id,created_at",
      )
      .eq("id_conversation", conversationId)
      .order("created_at", { ascending: false })
      .order("id_message", { ascending: false })
      .limit(limit + 1);
    if (cursor !== null) {
      const decoded = decodeCursor(cursor);
      query = query.or(
        `created_at.lt.${decoded.createdAt},and(created_at.eq.${decoded.createdAt},id_message.lt.${decoded.id})`,
      );
    }
    const { data, error } = await query;
    assertDatabaseSuccess(error);
    const rows = data ?? [];
    const hasMore = rows.length > limit;
    const descending = rows.slice(0, limit).map(mapMessage);
    const last = descending.at(-1);
    return {
      items: descending.reverse(),
      nextCursor: hasMore && last
        ? encodeCursor(last.createdAt, last.id)
        : null,
    };
  }

  async deleteConversation(
    userId: string,
    conversationId: string,
  ): Promise<void> {
    const { data, error } = await this.client
      .from("ai_chat_conversation")
      .delete()
      .eq("id_conversation", conversationId)
      .eq("id_user", userId)
      .select("id_conversation");
    assertDatabaseSuccess(error);
    if ((data?.length ?? 0) === 0) {
      throw new AiChatGatewayError(
        "AI_CHAT_CONVERSATION_NOT_FOUND",
        404,
      );
    }
  }

  synthesizeSpeech(text: string, languageCode: string) {
    return synthesizeVbeeSpeech(
      { text, languageCode },
      vbeeConfiguration(languageCode),
    );
  }

  private async ownsConversation(
    userId: string,
    conversationId: string,
  ): Promise<boolean> {
    const { data, error } = await this.client
      .from("ai_chat_conversation")
      .select("id_conversation")
      .eq("id_conversation", conversationId)
      .eq("id_user", userId)
      .maybeSingle();
    assertDatabaseSuccess(error);
    return data !== null;
  }
}

function mapConversation(row: JsonObject): AiChatConversationRecord {
  return {
    id: String(row.id_conversation ?? ""),
    title: String(row.title ?? "New conversation"),
    createdAt: String(row.created_at ?? ""),
    updatedAt: String(row.updated_at ?? ""),
  };
}

function mapMessage(row: JsonObject): AiChatMessageRecord {
  const payload = row.action_payload;
  return {
    id: String(row.id_message ?? ""),
    conversationId: String(row.id_conversation ?? ""),
    role: row.role === "assistant" ? "assistant" : "user",
    content: String(row.content ?? ""),
    actionKey: typeof row.action_key === "string" ? row.action_key : null,
    actionPayload: isRecord(payload) ? payload : null,
    requestId: typeof row.request_id === "string" ? row.request_id : null,
    createdAt: String(row.created_at ?? ""),
  };
}

function vbeeConfiguration(languageCode: string): VbeeTtsConfig {
  const apiKey = requiredEnvironment("VBEE_API_KEY");
  const appId = Deno.env.get("VBEE_APP_ID") ?? apiKey;
  const locale = normalizeLocale(languageCode);
  const voiceCode = voiceCodeForLocale(locale);
  return {
    apiKey,
    appId,
    baseUrl: Deno.env.get("VBEE_BASE_URL") ?? "https://vbee.vn",
    pollIntervalMs: 750,
    maxPollAttempts: 8,
    voiceCodes: voiceCode ? { [locale]: voiceCode } : undefined,
    vietnameseVoiceCode: locale.startsWith("vi-") ? voiceCode : undefined,
    englishVoiceCode: locale.startsWith("en-") ? voiceCode : undefined,
    defaultVoiceCode: voiceCode,
    callbackUrl: Deno.env.get("VBEE_CALLBACK_URL") ??
      "https://example.com/vbee-callback",
    speedRate: Deno.env.get("VBEE_SPEED_RATE") ?? "1.0",
    bitrate: Deno.env.get("VBEE_BITRATE") ?? "128",
  };
}

function voiceCodeForLocale(locale: string): string | undefined {
  const exact = locale.replaceAll("-", "_").toUpperCase();
  const language = locale.split("-")[0].toUpperCase();
  return Deno.env.get(`VBEE_${exact}_VOICE_CODE`) ??
    Deno.env.get(`VBEE_${language}_VOICE_CODE`) ??
    (locale.startsWith("vi-")
      ? Deno.env.get("VBEE_VOICE_CODE") ??
        "hn_female_ngochuyen_full_48k-fhg"
      : Deno.env.get("VBEE_VOICE_CODE") ?? undefined);
}

function normalizeLocale(value: string): string {
  const code = value.trim().replaceAll("_", "-").toLowerCase();
  if (code.includes("-")) return code;
  if (code === "vi") return "vi-vn";
  if (code === "en") return "en-us";
  return code;
}

function estimateCost(
  model: string,
  inputTokens: number,
  outputTokens: number,
): number {
  const normalized = model.toUpperCase().replaceAll("-", "_");
  const inputRate = Number.parseFloat(
    Deno.env.get(`AI_COST_${normalized}_INPUT_PER_1M`) ?? "0",
  );
  const outputRate = Number.parseFloat(
    Deno.env.get(`AI_COST_${normalized}_OUTPUT_PER_1M`) ?? "0",
  );
  return inputTokens / 1_000_000 * inputRate +
    outputTokens / 1_000_000 * outputRate;
}

function numericValue(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) && parsed >= 0 ? Math.trunc(parsed) : 0;
}

function nestedValue(
  value: unknown,
  path: Array<string | number>,
): unknown {
  let current = value;
  for (const key of path) {
    if (Array.isArray(current) && typeof key === "number") {
      current = current[key];
    } else if (isRecord(current) && typeof key === "string") {
      current = current[key];
    } else {
      return null;
    }
  }
  return current;
}

function requireRecord(value: unknown): JsonObject {
  if (!isRecord(value)) throw new Error("Invalid database response");
  return value;
}

function isRecord(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function assertDatabaseSuccess(error: unknown): void {
  if (error !== null && error !== undefined) {
    throw new Error("AI chat database operation failed");
  }
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing required environment: ${name}`);
  return value;
}

function safeErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Unknown error";
}

function jsonResponse(payload: JsonObject, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json; charset=utf-8",
    },
  });
}

const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const gateway = new SupabaseAiChatGateway(serviceClient);

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return handleAiChatRequest({ gateway }, request, "");
  }

  try {
    const authorization = requireAuthorizationHeader(
      request.headers.get("Authorization"),
    );
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: authorization } },
    });
    const userId = await requireAuthenticatedUserId(userClient);
    return await handleAiChatRequest({ gateway }, request, userId);
  } catch (error) {
    if (error instanceof AuthorizationError) {
      return jsonResponse({ error: "AUTH_REQUIRED" }, error.statusCode);
    }
    console.error("AI chat request failed", safeErrorMessage(error));
    return jsonResponse({ error: "AI_CHAT_PROVIDER_UNAVAILABLE" }, 500);
  }
});
