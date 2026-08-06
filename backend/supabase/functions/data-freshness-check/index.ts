/// <reference lib="dom" />

import { createClient } from "@supabase/supabase-js";

import { corsHeaders } from "../_shared/cors.ts";
import { SupabaseDataFreshnessGateway } from "./data_freshness_gateway.ts";
import { runFreshnessCheck } from "./data_freshness_handler.ts";
import { adapterFor } from "./source_adapter.ts";

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse({ error: "Method not allowed." }, 405);

  const configuredSecret = Deno.env.get("DATA_FRESHNESS_CHECK_SECRET")?.trim();
  const providedSecret = request.headers.get("x-data-freshness-secret") ?? "";
  if (!configuredSecret || !constantTimeEqual(providedSecret, configuredSecret)) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  try {
    const supabaseUrl = requiredEnvironment("SUPABASE_URL");
    const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
    const body = await request.json().catch(() => ({})) as Record<string, unknown>;
    const triggerType = body.triggerType === "admin" || body.triggerType === "retry"
      ? body.triggerType
      : "cron";
    const client = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const result = await runFreshnessCheck({
      gateway: new SupabaseDataFreshnessGateway(client),
      adapterFor,
      triggerType,
    });
    return withCors(jsonResponse(result, 200));
  } catch (error) {
    console.error("[data-freshness-check] failed", error);
    return withCors(jsonResponse({
      error: error instanceof Error ? error.message : "Unexpected error.",
    }, 500));
  }
});

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

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing ${name}.`);
  return value;
}

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function withCors(response: Response): Response {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(corsHeaders)) headers.set(key, value);
  return new Response(response.body, { status: response.status, headers });
}

export { constantTimeEqual, requiredEnvironment };
