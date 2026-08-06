/// <reference lib="dom" />

import { createClient } from "@supabase/supabase-js";

import { corsHeaders } from "../_shared/cors.ts";
import {
  AuthorizationError,
  requireAuthenticatedUserId,
  requireAuthorizationHeader,
} from "../auth/auth_guard.ts";
import { SupabaseFreshnessApiGateway } from "./freshness_api_gateway.ts";
import { handleFreshnessApiRequest } from "./freshness_api_handler.ts";

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") return withCors(new Response("ok"));
  if (request.method !== "POST") return withCors(jsonResponse({ error: "Method not allowed." }, 405));

  try {
    const supabaseUrl = requiredEnvironment("SUPABASE_URL");
    const anonKey = requiredEnvironment("SUPABASE_ANON_KEY");
    const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
    const authorization = requireAuthorizationHeader(request.headers.get("Authorization"));
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const userId = await requireAuthenticatedUserId(userClient);
    const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: account, error: roleError } = await serviceClient
      .from("user_account")
      .select("role")
      .eq("id_user", userId)
      .maybeSingle();
    if (roleError) throw new AuthorizationError("Unable to verify role.", 403);
    const isAdmin = String(account?.role ?? "").toLowerCase() === "admin";

    return withCors(await handleFreshnessApiRequest({
      request,
      userId,
      isAdmin,
      gateway: new SupabaseFreshnessApiGateway(serviceClient, userClient),
    }));
  } catch (error) {
    console.error("[data-freshness] request failed", error);
    if (error instanceof AuthorizationError) {
      return withCors(jsonResponse({ error: error.message }, error.statusCode));
    }
    return withCors(jsonResponse({
      error: error instanceof Error ? error.message : "Unexpected error.",
    }, 500));
  }
});

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

export { requiredEnvironment };
