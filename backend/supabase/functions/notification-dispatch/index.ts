/// <reference lib="dom" />

import { createClient } from "@supabase/supabase-js";

import { corsHeaders } from "../_shared/cors.ts";
import {
  type FirebaseCredentials,
  sendFcmMessage,
} from "../_shared/firebase_messaging.ts";
import { SupabaseDispatchGateway } from "./notification_dispatch_gateway.ts";
import { dispatchNotification } from "./notification_dispatch_handler.ts";

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const expectedSecret = requiredEnvironment("NOTIFICATION_DISPATCH_SECRET");
  if (!secretsMatch(request.headers.get("x-notification-secret"), expectedSecret)) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  try {
    const payload = await request.json() as Record<string, unknown>;
    const notificationId = extractNotificationId(payload);
    const credentials: FirebaseCredentials = {
      projectId: requiredEnvironment("FIREBASE_PROJECT_ID"),
      clientEmail: requiredEnvironment("FIREBASE_CLIENT_EMAIL"),
      privateKey: requiredEnvironment("FIREBASE_PRIVATE_KEY"),
    };
    const client = createClient(
      requiredEnvironment("SUPABASE_URL"),
      requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    const result = await dispatchNotification({
      notificationId,
      gateway: new SupabaseDispatchGateway(client),
      send: (token, notification, data) =>
        sendFcmMessage({
          token,
          title: notification.title,
          body: notification.body,
          data,
          credentials,
        }),
    });
    return jsonResponse(result);
  } catch (error) {
    console.error("[notification-dispatch] request failed", error);
    return jsonResponse({
      error: error instanceof Error ? error.message : "Unexpected error.",
    }, error instanceof DispatchRequestError ? 400 : 500);
  }
});

export function extractNotificationId(payload: Record<string, unknown>): string {
  const record = asRecord(payload.record);
  const value = record?.id_notification ?? payload.id_notification;
  if (
    typeof value !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value)
  ) {
    throw new DispatchRequestError("Missing or invalid id_notification.");
  }
  return value;
}

class DispatchRequestError extends Error {}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing ${name}.`);
  return value;
}

function secretsMatch(candidate: string | null, expected: string): boolean {
  if (candidate == null || candidate.length !== expected.length) return false;
  let difference = 0;
  for (let index = 0; index < expected.length; index += 1) {
    difference |= candidate.charCodeAt(index) ^ expected.charCodeAt(index);
  }
  return difference === 0;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json; charset=utf-8" },
  });
}
