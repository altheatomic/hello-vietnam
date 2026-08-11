/// <reference lib="dom" />

import { corsHeaders } from "../_shared/cors.ts";
import {
  authorizeServiceRole,
  buildDeepSeekPayload,
  DEFAULT_CONTENT_MODEL,
  normalizeDeepSeekResponse,
  parseProxyRequest,
  providerErrorStatus,
} from "./place_content_generate_domain.ts";

const DEFAULT_DEEPSEEK_BASE_URL = "https://api.deepseek.com";

export type PlaceContentProxyEnvironment = Record<string, string | undefined>;

export type PlaceContentProxyDependencies = {
  env?: PlaceContentProxyEnvironment;
  fetchFn?: typeof fetch;
};

export function createPlaceContentHandler(
  dependencies: PlaceContentProxyDependencies = {},
): (request: Request) => Promise<Response> {
  const env = dependencies.env ?? readEnvironment();
  const fetchFn = dependencies.fetchFn ?? fetch;

  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return withCors(new Response("ok"));
    if (request.method !== "POST") {
      return jsonResponse({ error: "Method not allowed." }, 405);
    }

    const serviceRoleKey = requiredEnvironment(env, "SUPABASE_SERVICE_ROLE_KEY");
    if (!authorizeServiceRole(
      request.headers.get("Authorization"),
      serviceRoleKey,
    )) {
      return jsonResponse({ error: "Unauthorized." }, 401);
    }

    let proxyRequest: ReturnType<typeof parseProxyRequest>;
    try {
      const body = await request.json();
      proxyRequest = parseProxyRequest(body);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Invalid request.";
      const status = message.includes("maximum length") ? 413 : 400;
      return jsonResponse({ error: message }, status);
    }

    const deepSeekKey = requiredEnvironment(env, "DEEPSEEK_API_KEY");
    const model = env.DEEPSEEK_CONTENT_MODEL?.trim() || DEFAULT_CONTENT_MODEL;
    const baseUrl = (env.DEEPSEEK_BASE_URL?.trim() || DEFAULT_DEEPSEEK_BASE_URL)
      .replace(/\/+$/u, "");

    let response: Response;
    try {
      response = await fetchFn(`${baseUrl}/chat/completions`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${deepSeekKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(buildDeepSeekPayload(proxyRequest.prompt, model)),
      });
    } catch (_) {
      return jsonResponse({ error: "DeepSeek request failed." }, 502);
    }

    const raw = await response.json().catch(() => null);
    if (!response.ok) {
      const headers: Record<string, string> = {};
      const retryAfter = response.headers.get("Retry-After");
      if (retryAfter && /^\d{1,3}$/u.test(retryAfter)) {
        headers["Retry-After"] = retryAfter;
      }
      return jsonResponse(
        { error: "DeepSeek request failed." },
        providerErrorStatus(response.status),
        headers,
      );
    }

    try {
      const normalized = normalizeDeepSeekResponse(raw, model);
      return jsonResponse({
        content: normalized.content,
        model: normalized.model,
        finish_reason: normalized.finishReason,
        input_tokens: normalized.inputTokens,
        output_tokens: normalized.outputTokens,
      }, 200);
    } catch (_) {
      return jsonResponse({ error: "DeepSeek response was invalid." }, 502);
    }
  };
}

function readEnvironment(): PlaceContentProxyEnvironment {
  return {
    SUPABASE_SERVICE_ROLE_KEY: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
    DEEPSEEK_API_KEY: Deno.env.get("DEEPSEEK_API_KEY"),
    DEEPSEEK_CONTENT_MODEL: Deno.env.get("DEEPSEEK_CONTENT_MODEL"),
    DEEPSEEK_BASE_URL: Deno.env.get("DEEPSEEK_BASE_URL"),
  };
}

function requiredEnvironment(
  env: PlaceContentProxyEnvironment,
  name: string,
): string {
  const value = env[name]?.trim();
  if (!value) throw new Error(`Missing ${name}.`);
  return value;
}

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
  extraHeaders: Record<string, string> = {},
): Response {
  return withCors(new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...extraHeaders,
    },
  }));
}

function withCors(response: Response): Response {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(corsHeaders)) headers.set(key, value);
  return new Response(response.body, { status: response.status, headers });
}

if (import.meta.main) {
  Deno.serve(createPlaceContentHandler());
}
