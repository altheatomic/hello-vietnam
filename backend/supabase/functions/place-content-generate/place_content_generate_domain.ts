export const DEFAULT_CONTENT_MODEL = "deepseek-v4-flash";
export const MAX_PROMPT_CHARACTERS = 120_000;
export const MAX_OUTPUT_TOKENS = 1_400;

export type ProxyRequest = {
  prompt: string;
  inputHash: string;
};

export type NormalizedProviderResponse = {
  content: string;
  model: string;
  finishReason: string;
  inputTokens: number;
  outputTokens: number;
};

export function authorizeServiceRole(
  authorization: string | null,
  expectedToken: string,
): boolean {
  const prefix = "Bearer ";
  if (!authorization?.startsWith(prefix) || !expectedToken) return false;
  return constantTimeEqual(authorization.slice(prefix.length), expectedToken);
}

export function parseProxyRequest(value: unknown): ProxyRequest {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Request body must be a JSON object.");
  }
  const body = value as Record<string, unknown>;
  const prompt = typeof body.prompt === "string" ? body.prompt.trim() : "";
  const inputHash = typeof body.input_hash === "string"
    ? body.input_hash.trim()
    : "";
  if (!prompt) throw new Error("prompt is required.");
  if (prompt.length > MAX_PROMPT_CHARACTERS) {
    throw new Error("prompt exceeds the maximum length.");
  }
  if (!inputHash) throw new Error("input_hash is required.");
  return { prompt, inputHash };
}

export function buildDeepSeekPayload(
  prompt: string,
  model: string,
): Record<string, unknown> {
  return {
    model,
    temperature: 0.2,
    max_tokens: MAX_OUTPUT_TOKENS,
    thinking: { type: "disabled" },
    response_format: { type: "json_object" },
    messages: [{ role: "user", content: prompt }],
  };
}

export function normalizeDeepSeekResponse(
  value: unknown,
  fallbackModel: string,
): NormalizedProviderResponse {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("DeepSeek response is not an object.");
  }
  const body = value as Record<string, unknown>;
  const choices = body.choices;
  if (!Array.isArray(choices) || choices.length === 0) {
    throw new Error("DeepSeek response has no choices.");
  }
  const choice = choices[0];
  if (!choice || typeof choice !== "object" || Array.isArray(choice)) {
    throw new Error("DeepSeek response choice is invalid.");
  }
  const choiceObject = choice as Record<string, unknown>;
  if (choiceObject.finish_reason !== "stop") {
    throw new Error(
      `DeepSeek finish_reason is ${String(choiceObject.finish_reason)}.`,
    );
  }
  const message = choiceObject.message;
  if (!message || typeof message !== "object" || Array.isArray(message)) {
    throw new Error("DeepSeek response message is invalid.");
  }
  const content = (message as Record<string, unknown>).content;
  if (typeof content !== "string" || !content.trim()) {
    throw new Error("DeepSeek response content is empty.");
  }
  return {
    content: content.trim(),
    model: typeof body.model === "string" && body.model.trim()
      ? body.model.trim()
      : fallbackModel,
    finishReason: "stop",
    inputTokens: usageInteger(body.usage, "prompt_tokens"),
    outputTokens: usageInteger(body.usage, "completion_tokens"),
  };
}

export function providerErrorStatus(status: number): number {
  if (status === 429) return 429;
  if (status >= 500) return 502;
  return 502;
}

function usageInteger(value: unknown, key: string): number {
  if (!value || typeof value !== "object" || Array.isArray(value)) return 0;
  const raw = (value as Record<string, unknown>)[key];
  const parsed = typeof raw === "number" ? raw : Number(raw);
  return Number.isFinite(parsed) ? Math.max(0, Math.trunc(parsed)) : 0;
}

function constantTimeEqual(left: string, right: string): boolean {
  const leftBytes = new TextEncoder().encode(left);
  const rightBytes = new TextEncoder().encode(right);
  let difference = leftBytes.length ^ rightBytes.length;
  const length = Math.max(leftBytes.length, rightBytes.length);
  for (let index = 0; index < length; index += 1) {
    difference |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }
  return difference === 0;
}
