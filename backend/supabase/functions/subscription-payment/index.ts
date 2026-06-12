/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { createClient } from "@supabase/supabase-js";

import { corsHeaders } from "../_shared/cors.ts";

type JsonObject = Record<string, unknown>;

type CheckoutPayload = {
  action?: "create_checkout";
  planCode?: string;
  voucherCode?: string | null;
  successUrl?: string;
  cancelUrl?: string;
};

type ConfirmPayload = {
  action: "confirm_checkout";
  sessionId?: string;
};

type PlanRow = {
  id_subscription_plan: string;
  code: string;
  name: string | null;
  duration_days: number | null;
  price_minor: number | null;
  status: string | null;
};

type VoucherRow = {
  id_voucher: string;
  code: string;
  type: string | null;
  value: number | null;
  max_discount_value: number | null;
  min_order_amount_min: number | null;
  usage_limit_total: number | null;
  usage_limit_per_user: number | null;
  id_applicable_plan: string | null;
};

type LoyaltyWalletVoucherRow = {
  id_wallet: string;
  wallet_code: string;
  status: string | null;
  expires_at: string | null;
  voucher_config: {
    title?: string | null;
    discount_type?: string | null;
    discount_value?: number | null;
    target_type?: string | null;
  } | null;
};

type StripeCheckoutSession = {
  id: string;
  url?: string | null;
  client_reference_id?: string | null;
  metadata?: Record<string, string>;
  status?: string | null;
  payment_status?: string | null;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY");

if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY || !STRIPE_SECRET_KEY) {
  throw new Error("Missing subscription-payment environment variables.");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const auth = await requireAuthenticatedUser(req);
    const payload = await req.json() as CheckoutPayload | ConfirmPayload;
    if (payload.action === "confirm_checkout") {
      return jsonResponse(await confirmCheckout(payload, auth.authorization, auth.userId));
    }
    return jsonResponse(await createCheckout(payload as CheckoutPayload, auth.authorization, auth.userId));
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error.";
    const status = message.startsWith("UNAUTHORIZED")
      ? 401
      : message.startsWith("BAD_REQUEST")
      ? 400
      : message.startsWith("PAYMENT_REQUIRED")
      ? 402
      : 500;
    return jsonResponse({ error: message }, status);
  }
});

async function requireAuthenticatedUser(req: Request): Promise<{
  authorization: string;
  userId: string;
  email: string | null;
}> {
  const authorization = req.headers.get("authorization");
  if (!authorization) throw new Error("UNAUTHORIZED: Missing authorization header.");

  const supabase = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
    global: { headers: { Authorization: authorization } },
  });
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) throw new Error("UNAUTHORIZED: Invalid user session.");
  return {
    authorization,
    userId: data.user.id,
    email: data.user.email ?? null,
  };
}

async function createCheckout(
  payload: CheckoutPayload,
  authorization: string,
  userId: string,
): Promise<JsonObject> {
  const planCode = normalizeCode(payload.planCode);
  const voucherCode = normalizeCode(payload.voucherCode);
  const successUrl = payload.successUrl?.trim();
  const cancelUrl = payload.cancelUrl?.trim();
  if (!planCode) throw new Error("BAD_REQUEST: Missing plan code.");
  if (!successUrl || !cancelUrl) throw new Error("BAD_REQUEST: Missing redirect URLs.");

  const service = serviceClient();
  await ensureDefaultSubscriptionData(service);
  const plan = await loadPlan(service, planCode);
  const pricing = await calculatePricing(service, plan, voucherCode, userId);

  if (pricing.finalAmountMinor <= 0) {
    const purchase = await confirmPaidSubscription({
      authorization,
      userId,
      planCode,
      voucherCode: pricing.voucherCode,
      externalRef: `free_${crypto.randomUUID()}`,
      provider: "voucher",
      method: "voucher",
    });
    return {
      status: "completed",
      purchase,
      originalAmountMinor: pricing.originalAmountMinor,
      discountMinor: pricing.discountMinor,
      finalAmountMinor: pricing.finalAmountMinor,
      voucherCode: pricing.voucherCode,
    };
  }

  const session = await createStripeCheckoutSession({
    plan,
    pricing,
    userId,
    successUrl,
    cancelUrl,
  });

  return {
    status: "requires_checkout",
    checkoutUrl: session.url,
    sessionId: session.id,
    originalAmountMinor: pricing.originalAmountMinor,
    discountMinor: pricing.discountMinor,
    finalAmountMinor: pricing.finalAmountMinor,
    voucherCode: pricing.voucherCode,
  };
}

async function confirmCheckout(
  payload: ConfirmPayload,
  authorization: string,
  userId: string,
): Promise<JsonObject> {
  const sessionId = payload.sessionId?.trim();
  if (!sessionId) throw new Error("BAD_REQUEST: Missing checkout session id.");

  const session = await retrieveStripeCheckoutSession(sessionId);
  if (session.client_reference_id !== userId || session.metadata?.user_id !== userId) {
    throw new Error("UNAUTHORIZED: Checkout session does not belong to this user.");
  }

  if (session.status !== "complete" || session.payment_status !== "paid") {
    throw new Error("PAYMENT_REQUIRED: Checkout session is not paid.");
  }

  await ensureDefaultSubscriptionData(serviceClient());
  const planCode = String(session.metadata?.plan_code ?? "");
  const voucherCode = normalizeCode(session.metadata?.voucher_code);
  const purchase = await confirmPaidSubscription({
    authorization,
    userId,
    planCode,
    voucherCode,
    externalRef: session.id,
    provider: "stripe",
    method: "card",
  });

  return {
    status: "completed",
    purchase,
    sessionId: session.id,
  };
}

async function ensureDefaultSubscriptionData(client: ReturnType<typeof createClient>): Promise<void> {
  const { error: planError } = await client
    .from("subscription_plan")
    .upsert(
      [
        {
          code: "1m",
          name: "Premium 1 Month",
          duration_days: 30,
          price_minor: 499,
          status: "active",
        },
        {
          code: "6m",
          name: "Premium 6 Months",
          duration_days: 180,
          price_minor: 1999,
          status: "active",
        },
        {
          code: "12m",
          name: "Premium 12 Months",
          duration_days: 365,
          price_minor: 2999,
          status: "active",
        },
      ],
      { onConflict: "code" },
    );
  if (planError) {
    throw new Error(`PLAN_SEED_FAILED: ${planError.message}`);
  }

  const now = new Date();
  const endAt = new Date(now.getTime() + 365 * 24 * 60 * 60 * 1000).toISOString();
  const startAt = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
  const { error: voucherError } = await client
    .from("voucher")
    .upsert(
      [
        {
          code: "WELCOME2024",
          type: "fixed",
          value: 200,
          max_discount_value: 200,
          start_at: startAt,
          end_at: endAt,
          status: "active",
          usage_limit_total: 10000,
          usage_limit_per_user: 1,
          min_order_amount_min: 0,
        },
        {
          code: "PREMIUM10",
          type: "percent",
          value: 10,
          max_discount_value: 500,
          start_at: startAt,
          end_at: endAt,
          status: "active",
          usage_limit_total: 10000,
          usage_limit_per_user: 1,
          min_order_amount_min: 0,
        },
        {
          code: "HOLIDAY15",
          type: "percent",
          value: 15,
          max_discount_value: 500,
          start_at: startAt,
          end_at: endAt,
          status: "active",
          usage_limit_total: 10000,
          usage_limit_per_user: 1,
          min_order_amount_min: 0,
        },
        {
          code: "PREMIUM200",
          type: "fixed",
          value: 2000,
          max_discount_value: 2000,
          start_at: startAt,
          end_at: endAt,
          status: "active",
          usage_limit_total: 10000,
          usage_limit_per_user: 1,
          min_order_amount_min: 1999,
        },
      ],
      { onConflict: "code" },
    );
  if (voucherError) {
    throw new Error(`VOUCHER_SEED_FAILED: ${voucherError.message}`);
  }
}

async function loadPlan(client: ReturnType<typeof createClient>, code: string): Promise<PlanRow> {
  const { data, error } = await client
    .from("subscription_plan")
    .select("id_subscription_plan, code, name, duration_days, price_minor, status")
    .eq("code", code)
    .maybeSingle();

  if (error) throw new Error(`PLAN_LOAD_FAILED: ${error.message}`);
  if (!data) return fallbackPlan(code);
  return data as PlanRow;
}

function fallbackPlan(code: string): PlanRow {
  const normalized = code.toLowerCase();
  if (normalized === "1m") {
    return {
      id_subscription_plan: "",
      code: "1m",
      name: "Premium 1 Month",
      duration_days: 30,
      price_minor: 499,
      status: "active",
    };
  }
  if (normalized === "6m") {
    return {
      id_subscription_plan: "",
      code: "6m",
      name: "Premium 6 Months",
      duration_days: 180,
      price_minor: 1999,
      status: "active",
    };
  }
  if (normalized === "12m") {
    return {
      id_subscription_plan: "",
      code: "12m",
      name: "Premium 12 Months",
      duration_days: 365,
      price_minor: 2999,
      status: "active",
    };
  }
  throw new Error("BAD_REQUEST: Subscription plan not found.");
}

async function calculatePricing(
  client: ReturnType<typeof createClient>,
  plan: PlanRow,
  voucherCode: string | null,
  userId: string,
): Promise<{
  originalAmountMinor: number;
  discountMinor: number;
  finalAmountMinor: number;
  voucherCode: string | null;
  loyaltyWalletId: string | null;
}> {
  const originalAmountMinor = Math.max(0, Number(plan.price_minor ?? 0));
  if (!voucherCode) {
    return {
      originalAmountMinor,
      discountMinor: 0,
      finalAmountMinor: originalAmountMinor,
      voucherCode: null,
      loyaltyWalletId: null,
    };
  }

  const loyaltyPricing = await calculateLoyaltyWalletPricing(client, plan, voucherCode, userId);
  if (loyaltyPricing) return loyaltyPricing;

  const { data, error } = await client
    .from("voucher")
    .select("id_voucher, code, type, value, max_discount_value, min_order_amount_min, usage_limit_total, usage_limit_per_user, id_applicable_plan")
    .ilike("code", voucherCode)
    .eq("status", "active")
    .maybeSingle();

  if (error) throw new Error(`VOUCHER_LOAD_FAILED: ${error.message}`);
  if (!data) throw new Error("BAD_REQUEST: Voucher is invalid or expired.");

  const voucher = data as VoucherRow;
  if (
    voucher.id_applicable_plan &&
    plan.id_subscription_plan &&
    voucher.id_applicable_plan !== plan.id_subscription_plan
  ) {
    throw new Error("BAD_REQUEST: Voucher is not valid for the selected plan.");
  }

  const minOrder = Math.max(0, Number(voucher.min_order_amount_min ?? 0));
  if (originalAmountMinor < minOrder) {
    throw new Error("BAD_REQUEST: Selected plan does not meet voucher minimum spend.");
  }

  await assertVoucherUsage(client, voucher, userId);

  let discount = 0;
  const value = Math.max(0, Number(voucher.value ?? 0));
  const type = String(voucher.type ?? "").toLowerCase();
  if (type === "percent" || type === "percentage") {
    discount = Math.floor(originalAmountMinor * value / 100);
    if (voucher.max_discount_value !== null && voucher.max_discount_value !== undefined) {
      discount = Math.min(discount, Number(voucher.max_discount_value));
    }
  } else {
    discount = value;
  }

  discount = Math.max(0, Math.min(discount, originalAmountMinor));
  return {
    originalAmountMinor,
    discountMinor: discount,
    finalAmountMinor: originalAmountMinor - discount,
    voucherCode: voucher.code,
    loyaltyWalletId: null,
  };
}

async function calculateLoyaltyWalletPricing(
  client: ReturnType<typeof createClient>,
  plan: PlanRow,
  voucherCode: string,
  userId: string,
): Promise<{
  originalAmountMinor: number;
  discountMinor: number;
  finalAmountMinor: number;
  voucherCode: string | null;
  loyaltyWalletId: string | null;
} | null> {
  const { data, error } = await client
    .from("voucher_wallet")
    .select("id_wallet, wallet_code, status, expires_at, voucher_config:id_voucher(title, discount_type, discount_value, target_type)")
    .eq("id_user", userId)
    .eq("wallet_code", voucherCode)
    .maybeSingle();

  if (error) throw new Error(`LOYALTY_VOUCHER_LOAD_FAILED: ${error.message}`);
  if (!data) return null;

  const wallet = data as LoyaltyWalletVoucherRow;
  if (wallet.status !== "available") {
    throw new Error("BAD_REQUEST: Loyalty voucher is already used or unavailable.");
  }
  if (wallet.expires_at && new Date(wallet.expires_at).getTime() < Date.now()) {
    throw new Error("BAD_REQUEST: Loyalty voucher is expired.");
  }

  const config = wallet.voucher_config;
  if (!config) throw new Error("BAD_REQUEST: Loyalty voucher configuration not found.");
  if (config.target_type && config.target_type !== "subscription") {
    throw new Error("BAD_REQUEST: Loyalty voucher is not valid for subscription upgrades.");
  }

  const originalAmountMinor = Math.max(0, Number(plan.price_minor ?? 0));
  const value = Math.max(0, Number(config.discount_value ?? 0));
  const type = String(config.discount_type ?? "").toLowerCase();
  let discount = type === "percent" || type === "percentage"
    ? Math.floor(originalAmountMinor * value / 100)
    : value;
  discount = Math.max(0, Math.min(discount, originalAmountMinor));

  return {
    originalAmountMinor,
    discountMinor: discount,
    finalAmountMinor: originalAmountMinor - discount,
    voucherCode: wallet.wallet_code,
    loyaltyWalletId: wallet.id_wallet,
  };
}

async function assertVoucherUsage(
  client: ReturnType<typeof createClient>,
  voucher: VoucherRow,
  userId: string,
): Promise<void> {
  if (voucher.usage_limit_total !== null && voucher.usage_limit_total !== undefined) {
    const { count, error } = await client
      .from("voucher_redemption")
      .select("id_voucher", { count: "exact", head: true })
      .eq("id_voucher", voucher.id_voucher);
    if (error) throw new Error(`VOUCHER_USAGE_LOAD_FAILED: ${error.message}`);
    if ((count ?? 0) >= Number(voucher.usage_limit_total)) {
      throw new Error("BAD_REQUEST: Voucher usage limit reached.");
    }
  }

  if (voucher.usage_limit_per_user !== null && voucher.usage_limit_per_user !== undefined) {
    const { count, error } = await client
      .from("voucher_redemption")
      .select("id_voucher", { count: "exact", head: true })
      .eq("id_voucher", voucher.id_voucher)
      .eq("id_user", userId);
    if (error) throw new Error(`VOUCHER_USAGE_LOAD_FAILED: ${error.message}`);
    if ((count ?? 0) >= Number(voucher.usage_limit_per_user)) {
      throw new Error("BAD_REQUEST: Voucher already used.");
    }
  }
}

async function createStripeCheckoutSession(input: {
  plan: PlanRow;
  pricing: {
    originalAmountMinor: number;
    discountMinor: number;
    finalAmountMinor: number;
    voucherCode: string | null;
  };
  userId: string;
  successUrl: string;
  cancelUrl: string;
}): Promise<StripeCheckoutSession> {
  const params = new URLSearchParams();
  params.set("mode", "payment");
  params.set("payment_method_types[0]", "card");
  params.set("client_reference_id", input.userId);
  params.set("success_url", input.successUrl);
  params.set("cancel_url", input.cancelUrl);
  params.set("line_items[0][quantity]", "1");
  params.set("line_items[0][price_data][currency]", "usd");
  params.set("line_items[0][price_data][unit_amount]", String(input.pricing.finalAmountMinor));
  params.set("line_items[0][price_data][product_data][name]", input.plan.name ?? `Premium ${input.plan.code}`);
  params.set("metadata[user_id]", input.userId);
  params.set("metadata[plan_code]", input.plan.code);
  if (input.pricing.voucherCode) params.set("metadata[voucher_code]", input.pricing.voucherCode);
  params.set("metadata[original_amount_minor]", String(input.pricing.originalAmountMinor));
  params.set("metadata[discount_minor]", String(input.pricing.discountMinor));
  params.set("metadata[final_amount_minor]", String(input.pricing.finalAmountMinor));

  const response = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${STRIPE_SECRET_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params,
  });
  const data = await response.json() as JsonObject;
  if (!response.ok) {
    throw new Error(`STRIPE_CHECKOUT_FAILED: ${String((data.error as JsonObject | undefined)?.message ?? response.status)}`);
  }
  return data as StripeCheckoutSession;
}

async function retrieveStripeCheckoutSession(sessionId: string): Promise<StripeCheckoutSession> {
  const response = await fetch(
    `https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(sessionId)}`,
    {
      headers: {
        "Authorization": `Bearer ${STRIPE_SECRET_KEY}`,
      },
    },
  );
  const data = await response.json() as JsonObject;
  if (!response.ok) {
    throw new Error(`STRIPE_SESSION_LOAD_FAILED: ${String((data.error as JsonObject | undefined)?.message ?? response.status)}`);
  }
  return data as StripeCheckoutSession;
}

async function confirmPaidSubscription(input: {
  authorization: string;
  userId: string;
  planCode: string;
  voucherCode: string | null;
  externalRef: string;
  provider: string;
  method: string;
}): Promise<JsonObject> {
  const service = serviceClient();
  await ensureDefaultSubscriptionData(service);

  const { data: existingPayment, error: existingError } = await service
    .from("payment")
    .select("id_payment, amount_minor, id_subscription_plan")
    .eq("id_user", input.userId)
    .eq("external_ref", input.externalRef)
    .eq("status", "confirmed")
    .maybeSingle();
  if (existingError) {
    throw new Error(`SUBSCRIPTION_CONFIRM_FAILED: ${existingError.message}`);
  }
  if (existingPayment) {
    const { data: existingSubscription, error: subError } = await service
      .from("premium_subscription")
      .select("id_prs, end_date")
      .eq("id_user", input.userId)
      .eq("id_plan", existingPayment.id_subscription_plan)
      .eq("status", "active")
      .order("end_date", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (subError) {
      throw new Error(`SUBSCRIPTION_CONFIRM_FAILED: ${subError.message}`);
    }
    const plan = await loadPlan(service, input.planCode);
    const finalAmountMinor = Number(existingPayment.amount_minor ?? 0);
    const originalAmountMinor = Number(plan.price_minor ?? finalAmountMinor);
    return {
      id_payment: existingPayment.id_payment,
      id_subscription: existingSubscription?.id_prs ?? "",
      original_amount_minor: originalAmountMinor,
      discount_minor: Math.max(0, originalAmountMinor - finalAmountMinor),
      final_amount_minor: finalAmountMinor,
      voucher_code: input.voucherCode,
      subscription_end_date: existingSubscription?.end_date ?? null,
    };
  }

  const plan = await loadPlan(service, input.planCode);
  if (!plan.id_subscription_plan) {
    throw new Error("SUBSCRIPTION_CONFIRM_FAILED: Subscription plan id missing.");
  }
  const pricing = await calculatePricing(service, plan, input.voucherCode, input.userId);
  const startAt = new Date();
  const endAt = new Date(
    startAt.getTime() + Number(plan.duration_days ?? 30) * 24 * 60 * 60 * 1000,
  );
  const paymentId = crypto.randomUUID();
  const subscriptionId = crypto.randomUUID();

  const { error: paymentError } = await service
    .from("payment")
    .insert({
      id_payment: paymentId,
      id_user: input.userId,
      id_subscription_plan: plan.id_subscription_plan,
      provider: input.provider,
      method: input.method,
      amount_minor: pricing.finalAmountMinor,
      currency: "USD",
      status: "confirmed",
      external_ref: input.externalRef,
      confirmed_at: startAt.toISOString(),
    });
  if (paymentError) {
    throw new Error(`SUBSCRIPTION_CONFIRM_FAILED: ${paymentError.message}`);
  }

  if (pricing.voucherCode && pricing.discountMinor > 0) {
    const { data: voucher, error: voucherError } = await service
      .from("voucher")
      .select("id_voucher")
      .ilike("code", pricing.voucherCode)
      .eq("status", "active")
      .maybeSingle();
    if (voucherError) {
      throw new Error(`SUBSCRIPTION_CONFIRM_FAILED: ${voucherError.message}`);
    }
    if (voucher?.id_voucher) {
      const { error: redemptionError } = await service
        .from("voucher_redemption")
        .insert({
          id_redemption: crypto.randomUUID(),
          id_voucher: voucher.id_voucher,
          id_user: input.userId,
          id_payment: paymentId,
          discount_minor: pricing.discountMinor,
          redeemed_at: startAt.toISOString(),
        });
      if (redemptionError) {
        throw new Error(`SUBSCRIPTION_CONFIRM_FAILED: ${redemptionError.message}`);
      }
    }
  }

  const { error: subscriptionError } = await service
    .from("premium_subscription")
    .insert({
      id_prs: subscriptionId,
      id_user: input.userId,
      id_plan: plan.id_subscription_plan,
      start_date: startAt.toISOString(),
      end_date: endAt.toISOString(),
      currency: "USD",
      status: "active",
    });
  if (subscriptionError) {
    throw new Error(`SUBSCRIPTION_CONFIRM_FAILED: ${subscriptionError.message}`);
  }

  if (pricing.loyaltyWalletId) {
    await markLoyaltyWalletVoucherUsed(service, pricing.loyaltyWalletId);
  }

  await awardSubscriptionLoyaltyPoints({
    authorization: input.authorization,
    userId: input.userId,
    paymentId,
    planCode: plan.code,
    finalAmountMinor: pricing.finalAmountMinor,
  });

  return {
    id_payment: paymentId,
    id_subscription: subscriptionId,
    original_amount_minor: pricing.originalAmountMinor,
    discount_minor: pricing.discountMinor,
    final_amount_minor: pricing.finalAmountMinor,
    voucher_code: pricing.voucherCode,
    subscription_end_date: endAt.toISOString(),
  };
}

async function markLoyaltyWalletVoucherUsed(
  client: ReturnType<typeof createClient>,
  walletId: string,
): Promise<void> {
  const { error } = await client
    .from("voucher_wallet")
    .update({
      status: "used",
      used_at: new Date().toISOString(),
    })
    .eq("id_wallet", walletId)
    .eq("status", "available");

  if (error) {
    throw new Error(`LOYALTY_VOUCHER_USE_FAILED: ${error.message}`);
  }
}

async function awardSubscriptionLoyaltyPoints(input: {
  authorization: string;
  userId: string;
  paymentId: string;
  planCode: string;
  finalAmountMinor: number;
}): Promise<void> {
  const userClient = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
    global: { headers: { Authorization: input.authorization } },
  });

  const { error } = await userClient.rpc("earn_loyalty_points", {
    p_user: input.userId,
    p_action_type: "subscription_purchase",
    p_reference_table: "payment",
    p_reference_id: input.paymentId,
    p_description: `Premium subscription ${input.planCode}`,
    p_metadata: {
      plan_code: input.planCode,
      final_amount_minor: input.finalAmountMinor,
      currency: "USD",
    },
  });

  if (error) {
    console.error("LOYALTY_SUBSCRIPTION_AWARD_FAILED", error.message);
  }
}

function serviceClient(): ReturnType<typeof createClient> {
  return createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!);
}

function normalizeCode(value: unknown): string | null {
  const normalized = String(value ?? "").trim().toUpperCase();
  return normalized.isEmpty ? null : normalized;
}

function jsonResponse(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
