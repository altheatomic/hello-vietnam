/// <reference lib="dom" />

import { createClient } from "@supabase/supabase-js";

import { StripeCheckoutClient } from "../_shared/stripe_checkout.ts";
import { SupabaseStripePaymentStore } from "../_shared/stripe_payment_store.ts";
import { createStripeWebhookHandler } from "./stripe_webhook_handler.ts";

const supabaseUrl = requiredEnvironment("SUPABASE_URL");
const supabaseServiceRoleKey = requiredEnvironment(
  "SUPABASE_SERVICE_ROLE_KEY",
);
const stripeSecretKey = requiredEnvironment("STRIPE_SECRET_KEY");
const stripeWebhookSecret = requiredEnvironment("STRIPE_WEBHOOK_SECRET");

const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
  },
});

const handler = createStripeWebhookHandler({
  store: new SupabaseStripePaymentStore({ serviceClient }),
  stripe: new StripeCheckoutClient({ secretKey: stripeSecretKey }),
  webhookSecret: stripeWebhookSecret,
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
