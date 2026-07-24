export const AI_CHAT_ACTION_KEYS = [
  "trip_planner",
  "translate",
  "explore",
  "recommend",
  "forum",
  "wishlist",
  "ai_recognition",
  "loyalty",
  "popular_apps",
  "notifications",
  "profile",
  "send_report",
  "upgrade_account",
] as const;

export type AiChatActionKey = typeof AI_CHAT_ACTION_KEYS[number];

export type AiChatRequest =
  | {
    action: "send_message";
    conversationId: string | null;
    requestId: string;
    content: string;
  }
  | {
    action: "list_conversations";
    cursor: string | null;
    limit: number;
  }
  | {
    action: "list_messages";
    conversationId: string;
    cursor: string | null;
    limit: number;
  }
  | {
    action: "delete_conversation";
    conversationId: string;
  }
  | {
    action: "tts";
    text: string;
    languageCode: string;
  };

export interface AiChatSuggestedAction {
  key: AiChatActionKey;
  payload: Record<string, unknown>;
}

export interface AiChatModelResult {
  answer: string;
  action: AiChatSuggestedAction | null;
}

export interface ChatHistoryMessage {
  role: "user" | "assistant";
  content: string;
}

export interface DeepSeekMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

export class AiChatValidationError extends Error {
  constructor(
    readonly code:
      | "AI_CHAT_INVALID_REQUEST"
      | "AI_CHAT_CONTENT_TOO_LONG",
  ) {
    super(code);
    this.name = "AiChatValidationError";
  }
}

const actionKeySet = new Set<string>(AI_CHAT_ACTION_KEYS);
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const languageCodePattern = /^[a-z]{2,3}(?:-[a-z]{2,4})?$/i;
const forbiddenPayloadKeys = new Set([
  "route",
  "url",
  "uri",
  "href",
  "deep_link",
  "deeplink",
]);

const systemInstruction = [
  "Return one JSON object only:",
  '{"answer":"plain user-facing answer","action":null}',
  "or",
  '{"answer":"plain user-facing answer","action":{"key":"one allowlisted key","payload":{}}}',
  "Never return a route, URL, code block, or action outside the provided allowlist.",
  "Answer in the same language as the user's latest message.",
  `Allowed action keys: ${AI_CHAT_ACTION_KEYS.join(", ")}.`,
].join("\n");

export function parseAiChatRequest(value: unknown): AiChatRequest {
  const body = requireRecord(value);
  const action = requireNonEmptyString(body.action);

  switch (action) {
    case "send_message": {
      const conversationId = optionalUuid(body.conversation_id);
      const requestId = requireUuid(body.request_id);
      const content = requireContent(body.content);
      return {
        action,
        conversationId,
        requestId,
        content,
      };
    }
    case "list_conversations":
      return {
        action,
        cursor: optionalString(body.cursor),
        limit: parseLimit(body.limit, 20),
      };
    case "list_messages":
      return {
        action,
        conversationId: requireUuid(body.conversation_id),
        cursor: optionalString(body.cursor),
        limit: parseLimit(body.limit, 50),
      };
    case "delete_conversation":
      return {
        action,
        conversationId: requireUuid(body.conversation_id),
      };
    case "tts": {
      const languageCode = requireNonEmptyString(body.language_code);
      if (!languageCodePattern.test(languageCode)) {
        throw new AiChatValidationError("AI_CHAT_INVALID_REQUEST");
      }
      return {
        action,
        text: requireContent(body.text),
        languageCode,
      };
    }
    default:
      throw new AiChatValidationError("AI_CHAT_INVALID_REQUEST");
  }
}

export function parseDeepSeekChatResult(value: unknown): AiChatModelResult {
  let decoded = value;

  if (typeof value === "string") {
    const raw = value.trim();
    if (!raw) {
      return fallbackModelResult();
    }

    try {
      decoded = JSON.parse(raw);
    } catch {
      return {
        answer: capContent(raw),
        action: null,
      };
    }
  }

  if (!isRecord(decoded)) {
    return fallbackModelResult();
  }

  const answer = typeof decoded.answer === "string" &&
      decoded.answer.trim().length > 0
    ? capContent(decoded.answer.trim())
    : fallbackModelResult().answer;

  if (!isRecord(decoded.action)) {
    return { answer, action: null };
  }

  const key = decoded.action.key;
  if (typeof key !== "string" || !actionKeySet.has(key)) {
    return { answer, action: null };
  }

  const rawPayload = decoded.action.payload;
  const payload = isRecord(rawPayload) ? sanitizePayload(rawPayload) : {};

  return {
    answer,
    action: {
      key: key as AiChatActionKey,
      payload,
    },
  };
}

export function buildDeepSeekMessages(
  history: ChatHistoryMessage[],
  userInput: string,
): DeepSeekMessage[] {
  const recentHistory = history.slice(-12).map((message) => ({
    role: message.role,
    content: message.content,
  }));

  return [
    { role: "system", content: systemInstruction },
    ...recentHistory,
    { role: "user", content: userInput.trim() },
  ];
}

export function encodeCursor(createdAt: string, id: string): string {
  validateCursorValues(createdAt, id);
  return btoa(JSON.stringify({ createdAt, id }))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/u, "");
}

export function decodeCursor(
  cursor: string,
): { createdAt: string; id: string } {
  try {
    const normalized = cursor.replaceAll("-", "+").replaceAll("_", "/");
    const padding = "=".repeat((4 - normalized.length % 4) % 4);
    const decoded = JSON.parse(atob(normalized + padding));
    const value = requireRecord(decoded);
    const createdAt = requireNonEmptyString(value.createdAt);
    const id = requireNonEmptyString(value.id);
    validateCursorValues(createdAt, id);
    return { createdAt, id };
  } catch (error) {
    if (error instanceof AiChatValidationError) {
      throw error;
    }
    throw new AiChatValidationError("AI_CHAT_INVALID_REQUEST");
  }
}

function validateCursorValues(createdAt: string, id: string): void {
  if (Number.isNaN(Date.parse(createdAt)) || !uuidPattern.test(id)) {
    throw new AiChatValidationError("AI_CHAT_INVALID_REQUEST");
  }
}

function requireRecord(value: unknown): Record<string, unknown> {
  if (!isRecord(value)) {
    throw new AiChatValidationError("AI_CHAT_INVALID_REQUEST");
  }
  return value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requireNonEmptyString(value: unknown): string {
  if (typeof value !== "string" || !value.trim()) {
    throw new AiChatValidationError("AI_CHAT_INVALID_REQUEST");
  }
  return value.trim();
}

function optionalString(value: unknown): string | null {
  if (value === undefined || value === null || value === "") {
    return null;
  }
  return requireNonEmptyString(value);
}

function requireUuid(value: unknown): string {
  const uuid = requireNonEmptyString(value);
  if (!uuidPattern.test(uuid)) {
    throw new AiChatValidationError("AI_CHAT_INVALID_REQUEST");
  }
  return uuid;
}

function optionalUuid(value: unknown): string | null {
  if (value === undefined || value === null || value === "") {
    return null;
  }
  return requireUuid(value);
}

function requireContent(value: unknown): string {
  const content = requireNonEmptyString(value);
  if (content.length > 2000) {
    throw new AiChatValidationError("AI_CHAT_CONTENT_TOO_LONG");
  }
  return content;
}

function parseLimit(value: unknown, maximum: number): number {
  if (value === undefined || value === null) {
    return maximum;
  }
  if (typeof value !== "number" || !Number.isInteger(value) || value < 1) {
    throw new AiChatValidationError("AI_CHAT_INVALID_REQUEST");
  }
  return Math.min(value, maximum);
}

function capContent(value: string): string {
  return value.slice(0, 2000);
}

function fallbackModelResult(): AiChatModelResult {
  return {
    answer: "I could not generate a response. Please try again.",
    action: null,
  };
}

function sanitizePayload(
  payload: Record<string, unknown>,
): Record<string, unknown> {
  const sanitized: Record<string, unknown> = {};

  for (const [key, value] of Object.entries(payload)) {
    const normalizedKey = key.toLowerCase().replaceAll("-", "_");
    if (
      forbiddenPayloadKeys.has(normalizedKey) ||
      normalizedKey === "__proto__" ||
      normalizedKey === "prototype" ||
      normalizedKey === "constructor"
    ) {
      continue;
    }

    const safeValue = sanitizePayloadValue(value, 0);
    if (safeValue !== undefined) {
      sanitized[key] = safeValue;
    }
  }

  return sanitized;
}

function sanitizePayloadValue(
  value: unknown,
  depth: number,
): unknown | undefined {
  if (depth > 5) {
    return undefined;
  }
  if (
    value === null ||
    typeof value === "number" ||
    typeof value === "boolean"
  ) {
    return value;
  }
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (
      trimmed.startsWith("/") ||
      /^[a-z][a-z0-9+.-]*:\/\//iu.test(trimmed)
    ) {
      return undefined;
    }
    return trimmed.slice(0, 500);
  }
  if (Array.isArray(value)) {
    return value
      .slice(0, 20)
      .map((item) => sanitizePayloadValue(item, depth + 1))
      .filter((item) => item !== undefined);
  }
  if (isRecord(value)) {
    const nested: Record<string, unknown> = {};
    for (const [key, item] of Object.entries(value)) {
      const normalizedKey = key.toLowerCase().replaceAll("-", "_");
      if (
        forbiddenPayloadKeys.has(normalizedKey) ||
        normalizedKey === "__proto__" ||
        normalizedKey === "prototype" ||
        normalizedKey === "constructor"
      ) {
        continue;
      }
      const safeItem = sanitizePayloadValue(item, depth + 1);
      if (safeItem !== undefined) {
        nested[key] = safeItem;
      }
    }
    return nested;
  }
  return undefined;
}
