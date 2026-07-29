/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { createClient } from "@supabase/supabase-js";

import { StripeCheckoutClient } from "../_shared/stripe_checkout.ts";
import { SupabaseStripePaymentStore } from "../_shared/stripe_payment_store.ts";
import { createSubscriptionPaymentHandler } from "./subscription_payment_handler.ts";

const supabaseUrl = requiredEnvironment("SUPABASE_URL");
const supabaseAnonKey = requiredEnvironment("SUPABASE_ANON_KEY");
const supabaseServiceRoleKey = requiredEnvironment(
  "SUPABASE_SERVICE_ROLE_KEY",
);
const stripeSecretKey = requiredEnvironment("STRIPE_SECRET_KEY");
const allowedWebOrigins = parseAllowedOrigins(
  Deno.env.get("CHECKOUT_ALLOWED_WEB_ORIGINS") ?? "http://localhost:3000",
);

const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
  },
});

const store = new SupabaseStripePaymentStore({
  serviceClient,
  authClientFactory: (authorization) =>
    createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
      global: {
        headers: { Authorization: authorization },
      },
    }),
});

const handler = createSubscriptionPaymentHandler({
  store,
  stripe: new StripeCheckoutClient({ secretKey: stripeSecretKey }),
  allowedWebOrigins,
  logError: (event, error) => {
    console.error(
      JSON.stringify({
        event,
        message: error instanceof Error ? error.message : "Unknown error",
      }),
    );
  },
});

Deno.serve(handler);

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing required environment: ${name}`);
  return value;
}

function parseAllowedOrigins(rawValue: string): ReadonlySet<string> {
  const origins = rawValue
    .split(",")
    .map((value) => value.trim())
    .filter((value) => value.length > 0)
    .map((value) => {
      const url = new URL(value);
      if (url.origin !== value) {
        throw new Error(
          "CHECKOUT_ALLOWED_WEB_ORIGINS must contain origins only.",
        );
      }
      return url.origin;
    });
  return new Set(origins);
}
