import type { SupabaseClient } from "@supabase/supabase-js";

import type { StripeCheckoutSession } from "./stripe_checkout.ts";
import { SubscriptionPaymentError } from "../subscription-payment/subscription_payment_domain.ts";
import type {
  CreateAttemptInput,
  FinalizedPurchase,
  PaymentAttempt,
  SubscriptionPaymentStore,
} from "../subscription-payment/subscription_payment_handler.ts";

type JsonRecord = Record<string, unknown>;

type StoreOptions = {
  serviceClient: SupabaseClient;
  authClientFactory: (authorization: string) => SupabaseClient;
};

type PricingSnapshot = {
  idVoucher: string | null;
  idVoucherWallet: string | null;
  voucherCode: string | null;
  originalAmountMinor: number;
  discountMinor: number;
  amountMinor: number;
};

export class SupabaseStripePaymentStore implements SubscriptionPaymentStore {
  private readonly serviceClient: SupabaseClient;
  private readonly authClientFactory: (authorization: string) => SupabaseClient;

  constructor(options: StoreOptions) {
    this.serviceClient = options.serviceClient;
    this.authClientFactory = options.authClientFactory;
  }

  async authenticate(
    authorization: string | null,
  ): Promise<{ id: string } | null> {
    if (!authorization?.startsWith("Bearer ")) return null;
    const client = this.authClientFactory(authorization);
    const { data, error } = await client.auth.getUser();
    if (error || !data.user) return null;
    return { id: data.user.id };
  }

  async createAttempt(input: CreateAttemptInput): Promise<PaymentAttempt> {
    const { data: planData, error: planError } = await this.serviceClient
      .from("subscription_plan")
      .select(
        "id_subscription_plan,code,name,duration_days,price_minor,status",
      )
      .eq("code", input.planCode)
      .eq("status", "active")
      .maybeSingle();
    assertDatabaseSuccess(planError, "PLAN_LOAD_FAILED");
    const plan = asRecord(planData);
    if (
      !plan ||
      typeof plan.id_subscription_plan !== "string" ||
      typeof plan.code !== "string"
    ) {
      throw userError("Subscription plan was not found.");
    }

    const durationDays = positiveInteger(plan.duration_days);
    const originalAmountMinor = nonNegativeInteger(plan.price_minor);
    if (!durationDays || originalAmountMinor === null) {
      throw new Error("PLAN_CONFIGURATION_INVALID");
    }

    const pricing = await this.resolvePricing(
      input.userId,
      plan,
      originalAmountMinor,
      input.voucherCode,
    );
    const { data, error } = await this.serviceClient
      .from("payment_attempt")
      .insert({
        id_user: input.userId,
        id_subscription_plan: plan.id_subscription_plan,
        id_voucher: pricing.idVoucher,
        id_voucher_wallet: pricing.idVoucherWallet,
        plan_code: plan.code,
        plan_name: typeof plan.name === "string"
          ? plan.name
          : `Premium ${plan.code}`,
        duration_days: durationDays,
        original_amount_minor: pricing.originalAmountMinor,
        discount_minor: pricing.discountMinor,
        amount_minor: pricing.amountMinor,
        voucher_code: pricing.voucherCode,
        currency: "USD",
        status: "pending",
      })
      .select(attemptColumns)
      .single();
    assertDatabaseSuccess(error, "PAYMENT_ATTEMPT_CREATE_FAILED");
    return mapAttempt(requireRecord(data, "PAYMENT_ATTEMPT_CREATE_FAILED"));
  }

  async attachStripeSession(
    attemptId: string,
    sessionId: string,
  ): Promise<void> {
    const { data, error } = await this.serviceClient
      .from("payment_attempt")
      .update({ stripe_session_id: sessionId })
      .eq("id_attempt", attemptId)
      .is("stripe_session_id", null)
      .select("id_attempt,stripe_session_id")
      .maybeSingle();
    assertDatabaseSuccess(error, "PAYMENT_SESSION_ATTACH_FAILED");
    if (data) return;

    const attempt = await this.findAttemptById(attemptId);
    if (!attempt || attempt.stripeSessionId !== sessionId) {
      throw new SubscriptionPaymentError(
        "PAYMENT_SESSION_MISMATCH",
        "A different Stripe Session is already attached.",
        409,
      );
    }
  }

  async findAttemptById(
    attemptId: string,
  ): Promise<PaymentAttempt | null> {
    const { data, error } = await this.serviceClient
      .from("payment_attempt")
      .select(attemptColumns)
      .eq("id_attempt", attemptId)
      .maybeSingle();
    assertDatabaseSuccess(error, "PAYMENT_ATTEMPT_LOAD_FAILED");
    return data
      ? mapAttempt(requireRecord(data, "PAYMENT_ATTEMPT_LOAD_FAILED"))
      : null;
  }

  async finalizeVerifiedSession(
    attemptId: string,
    session: StripeCheckoutSession,
  ): Promise<FinalizedPurchase> {
    if (session.amountTotal === null || session.currency === null) {
      throw new SubscriptionPaymentError(
        "PAYMENT_SESSION_MISMATCH",
        "Stripe Session is missing amount or currency.",
        409,
      );
    }
    const { data, error } = await this.serviceClient.rpc(
      "finalize_verified_payment",
      {
        p_attempt_id: attemptId,
        p_stripe_session_id: session.id,
        p_amount_total: session.amountTotal,
        p_currency: session.currency.toUpperCase(),
      },
    );
    assertDatabaseSuccess(error, "PAYMENT_FINALIZE_FAILED");
    const row = firstRecord(data, "PAYMENT_FINALIZE_FAILED");
    return {
      paymentId: requireString(row.id_payment, "PAYMENT_FINALIZE_FAILED"),
      subscriptionId: requireString(
        row.id_subscription,
        "PAYMENT_FINALIZE_FAILED",
      ),
      originalAmountMinor: requireInteger(
        row.original_amount_minor,
        "PAYMENT_FINALIZE_FAILED",
      ),
      discountMinor: requireInteger(
        row.discount_minor,
        "PAYMENT_FINALIZE_FAILED",
      ),
      finalAmountMinor: requireInteger(
        row.final_amount_minor,
        "PAYMENT_FINALIZE_FAILED",
      ),
      voucherCode: typeof row.voucher_code === "string"
        ? row.voucher_code
        : null,
      subscriptionEndDate: requireString(
        row.subscription_end_date,
        "PAYMENT_FINALIZE_FAILED",
      ),
    };
  }

  async markAttemptFailed(
    attemptId: string,
    reason: string,
  ): Promise<void> {
    const { error } = await this.serviceClient
      .from("payment_attempt")
      .update({
        status: "failed",
        failure_reason: reason.slice(0, 500),
      })
      .eq("id_attempt", attemptId)
      .eq("status", "pending");
    assertDatabaseSuccess(error, "PAYMENT_ATTEMPT_UPDATE_FAILED");
  }

  async markAttemptExpired(attemptId: string): Promise<void> {
    const { error } = await this.serviceClient
      .from("payment_attempt")
      .update({
        status: "expired",
        failure_reason: "STRIPE_CHECKOUT_EXPIRED",
      })
      .eq("id_attempt", attemptId)
      .eq("status", "pending");
    assertDatabaseSuccess(error, "PAYMENT_ATTEMPT_UPDATE_FAILED");
  }

  async awardLoyaltyPoints(
    _userId: string,
    purchase: FinalizedPurchase,
    _planCode: string,
  ): Promise<void> {
    const { error } = await this.serviceClient.rpc(
      "award_subscription_payment_loyalty",
      { p_payment_id: purchase.paymentId },
    );
    assertDatabaseSuccess(error, "LOYALTY_SUBSCRIPTION_AWARD_FAILED");
  }

  private async resolvePricing(
    userId: string,
    plan: JsonRecord,
    originalAmountMinor: number,
    voucherCode: string | null,
  ): Promise<PricingSnapshot> {
    if (!voucherCode) {
      return {
        idVoucher: null,
        idVoucherWallet: null,
        voucherCode: null,
        originalAmountMinor,
        discountMinor: 0,
        amountMinor: originalAmountMinor,
      };
    }

    const walletPricing = await this.resolveWalletVoucher(
      userId,
      originalAmountMinor,
      voucherCode,
    );
    if (walletPricing) return walletPricing;

    const { data, error } = await this.serviceClient
      .from("voucher")
      .select(
        "id_voucher,code,type,value,max_discount_value,start_at,end_at,status,usage_limit_total,usage_limit_per_user,min_order_amount_min,id_applicable_plan",
      )
      .ilike("code", voucherCode)
      .eq("status", "active")
      .maybeSingle();
    assertDatabaseSuccess(error, "VOUCHER_LOAD_FAILED");
    const voucher = asRecord(data);
    if (!voucher) throw userError("Voucher is invalid or expired.");
    validateVoucherWindow(voucher);

    if (
      typeof voucher.id_applicable_plan === "string" &&
      voucher.id_applicable_plan !== plan.id_subscription_plan
    ) {
      throw userError("Voucher is not valid for the selected plan.");
    }
    const minimum = nonNegativeInteger(voucher.min_order_amount_min) ?? 0;
    if (originalAmountMinor < minimum) {
      throw userError("Selected plan does not meet voucher minimum spend.");
    }
    await this.assertVoucherUsage(userId, voucher);

    const discountMinor = discountForVoucher(
      originalAmountMinor,
      String(voucher.type ?? ""),
      nonNegativeInteger(voucher.value) ?? 0,
      nonNegativeInteger(voucher.max_discount_value),
    );
    return {
      idVoucher: requireString(voucher.id_voucher, "VOUCHER_LOAD_FAILED"),
      idVoucherWallet: null,
      voucherCode: requireString(voucher.code, "VOUCHER_LOAD_FAILED"),
      originalAmountMinor,
      discountMinor,
      amountMinor: originalAmountMinor - discountMinor,
    };
  }

  private async resolveWalletVoucher(
    userId: string,
    originalAmountMinor: number,
    voucherCode: string,
  ): Promise<PricingSnapshot | null> {
    const { data, error } = await this.serviceClient
      .from("voucher_wallet")
      .select(
        "id_wallet,wallet_code,status,expires_at,voucher_config:id_voucher(discount_type,discount_value,target_type)",
      )
      .eq("id_user", userId)
      .eq("wallet_code", voucherCode)
      .maybeSingle();
    assertDatabaseSuccess(error, "LOYALTY_VOUCHER_LOAD_FAILED");
    const wallet = asRecord(data);
    if (!wallet) return null;
    if (wallet.status !== "available") {
      throw userError("Loyalty voucher is already used or unavailable.");
    }
    if (
      typeof wallet.expires_at === "string" &&
      Date.parse(wallet.expires_at) < Date.now()
    ) {
      throw userError("Loyalty voucher is expired.");
    }

    const config = relationRecord(wallet.voucher_config);
    if (!config || config.target_type !== "subscription") {
      throw userError("Loyalty voucher is not valid for Premium.");
    }
    const discountMinor = discountForVoucher(
      originalAmountMinor,
      String(config.discount_type ?? ""),
      nonNegativeInteger(config.discount_value) ?? 0,
      null,
    );
    return {
      idVoucher: null,
      idVoucherWallet: requireString(
        wallet.id_wallet,
        "LOYALTY_VOUCHER_LOAD_FAILED",
      ),
      voucherCode: requireString(
        wallet.wallet_code,
        "LOYALTY_VOUCHER_LOAD_FAILED",
      ),
      originalAmountMinor,
      discountMinor,
      amountMinor: originalAmountMinor - discountMinor,
    };
  }

  private async assertVoucherUsage(
    userId: string,
    voucher: JsonRecord,
  ): Promise<void> {
    const voucherId = requireString(voucher.id_voucher, "VOUCHER_LOAD_FAILED");
    const totalLimit = nonNegativeInteger(voucher.usage_limit_total);
    if (totalLimit !== null) {
      const { count, error } = await this.serviceClient
        .from("voucher_redemption")
        .select("id_redemption", { count: "exact", head: true })
        .eq("id_voucher", voucherId);
      assertDatabaseSuccess(error, "VOUCHER_USAGE_LOAD_FAILED");
      if ((count ?? 0) >= totalLimit) {
        throw userError("Voucher usage limit reached.");
      }
    }

    const userLimit = nonNegativeInteger(voucher.usage_limit_per_user);
    if (userLimit !== null) {
      const { count, error } = await this.serviceClient
        .from("voucher_redemption")
        .select("id_redemption", { count: "exact", head: true })
        .eq("id_voucher", voucherId)
        .eq("id_user", userId);
      assertDatabaseSuccess(error, "VOUCHER_USAGE_LOAD_FAILED");
      if ((count ?? 0) >= userLimit) {
        throw userError("Voucher was already used.");
      }
    }
  }
}

export function discountForVoucher(
  originalAmountMinor: number,
  type: string,
  value: number,
  maximumDiscountMinor: number | null,
): number {
  const normalizedType = type.trim().toLowerCase();
  let discount = normalizedType === "percent" ||
      normalizedType === "percentage"
    ? Math.floor(originalAmountMinor * value / 100)
    : value;
  if (maximumDiscountMinor !== null) {
    discount = Math.min(discount, maximumDiscountMinor);
  }
  return Math.max(0, Math.min(discount, originalAmountMinor));
}

const attemptColumns = [
  "id_attempt",
  "id_user",
  "plan_code",
  "plan_name",
  "duration_days",
  "original_amount_minor",
  "discount_minor",
  "amount_minor",
  "currency",
  "stripe_session_id",
  "status",
  "failure_reason",
].join(",");

function mapAttempt(row: JsonRecord): PaymentAttempt {
  const currency = requireString(row.currency, "PAYMENT_ATTEMPT_INVALID");
  if (currency !== "USD") throw new Error("PAYMENT_ATTEMPT_INVALID");
  const status = requireString(row.status, "PAYMENT_ATTEMPT_INVALID");
  if (
    status !== "pending" &&
    status !== "paid" &&
    status !== "finalized" &&
    status !== "expired" &&
    status !== "failed"
  ) {
    throw new Error("PAYMENT_ATTEMPT_INVALID");
  }
  return {
    idAttempt: requireString(row.id_attempt, "PAYMENT_ATTEMPT_INVALID"),
    userId: requireString(row.id_user, "PAYMENT_ATTEMPT_INVALID"),
    planCode: requireString(row.plan_code, "PAYMENT_ATTEMPT_INVALID"),
    planName: requireString(row.plan_name, "PAYMENT_ATTEMPT_INVALID"),
    durationDays: requireInteger(
      row.duration_days,
      "PAYMENT_ATTEMPT_INVALID",
    ),
    originalAmountMinor: requireInteger(
      row.original_amount_minor,
      "PAYMENT_ATTEMPT_INVALID",
    ),
    discountMinor: requireInteger(
      row.discount_minor,
      "PAYMENT_ATTEMPT_INVALID",
    ),
    amountMinor: requireInteger(
      row.amount_minor,
      "PAYMENT_ATTEMPT_INVALID",
    ),
    currency,
    stripeSessionId: typeof row.stripe_session_id === "string"
      ? row.stripe_session_id
      : null,
    status,
    failureReason: typeof row.failure_reason === "string"
      ? row.failure_reason
      : null,
  };
}

function validateVoucherWindow(voucher: JsonRecord): void {
  const now = Date.now();
  if (
    typeof voucher.start_at === "string" &&
    Date.parse(voucher.start_at) > now
  ) {
    throw userError("Voucher is not active yet.");
  }
  if (
    typeof voucher.end_at === "string" &&
    Date.parse(voucher.end_at) < now
  ) {
    throw userError("Voucher is expired.");
  }
}

function relationRecord(value: unknown): JsonRecord | null {
  if (Array.isArray(value)) return asRecord(value[0]);
  return asRecord(value);
}

function firstRecord(value: unknown, code: string): JsonRecord {
  const row = Array.isArray(value) ? value[0] : value;
  return requireRecord(row, code);
}

function asRecord(value: unknown): JsonRecord | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as JsonRecord
    : null;
}

function requireRecord(value: unknown, code: string): JsonRecord {
  const record = asRecord(value);
  if (!record) throw new Error(code);
  return record;
}

function requireString(value: unknown, code: string): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(code);
  }
  return value;
}

function requireInteger(value: unknown, code: string): number {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed)) throw new Error(code);
  return parsed;
}

function positiveInteger(value: unknown): number | null {
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null;
}

function nonNegativeInteger(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed >= 0 ? parsed : null;
}

function assertDatabaseSuccess(error: unknown, code: string): void {
  if (error) {
    const message = error instanceof Error
      ? error.message
      : asRecord(error)?.message;
    throw new Error(`${code}: ${String(message ?? "Database operation failed.")}`);
  }
}

function userError(message: string): SubscriptionPaymentError {
  return new SubscriptionPaymentError("BAD_REQUEST", message, 400);
}
