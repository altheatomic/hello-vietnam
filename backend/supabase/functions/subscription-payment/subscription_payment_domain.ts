import type { StripeCheckoutSession } from "../_shared/stripe_checkout.ts";

export type CheckoutPlatform = "android" | "web";

export type CreateCheckoutCommand = {
  action: "create_checkout";
  planCode: string;
  voucherCode: string | null;
  platform: CheckoutPlatform;
  webOrigin: string | null;
};

export type ConfirmCheckoutCommand = {
  action: "confirm_checkout";
  sessionId: string;
};

export type SubscriptionPaymentCommand =
  | CreateCheckoutCommand
  | ConfirmCheckoutCommand;

export type ValidatablePaymentAttempt = {
  idAttempt: string;
  userId: string;
  amountMinor: number;
  currency: "USD";
  stripeSessionId: string | null;
  status: "pending" | "paid" | "finalized" | "expired" | "failed";
};

export type CheckoutCallbacks = {
  successUrl: string;
  cancelUrl: string;
};

export type SubscriptionPaymentErrorCode =
  | "UNAUTHORIZED"
  | "BAD_REQUEST"
  | "PAYMENT_REQUIRED"
  | "PAYMENT_SESSION_MISMATCH"
  | "PAYMENT_AMOUNT_MISMATCH"
  | "PAYMENT_CURRENCY_MISMATCH"
  | "PAYMENT_ATTEMPT_CLOSED"
  | "PAYMENT_PROVIDER_UNAVAILABLE"
  | "INTERNAL_ERROR";

export class SubscriptionPaymentError extends Error {
  constructor(
    readonly code: SubscriptionPaymentErrorCode,
    message: string,
    readonly statusCode: number,
  ) {
    super(`${code}: ${message}`);
    this.name = "SubscriptionPaymentError";
  }
}

const planCodePattern = /^[a-z0-9][a-z0-9_-]{0,49}$/i;
const voucherCodePattern = /^[a-z0-9][a-z0-9_-]{0,63}$/i;

export function parseSubscriptionPaymentCommand(
  value: unknown,
): SubscriptionPaymentCommand {
  const body = requireRecord(value);
  const action = requireString(body.action);

  if (action === "create_checkout") {
    assertOnlyKeys(body, [
      "action",
      "planCode",
      "voucherCode",
      "platform",
      "webOrigin",
    ]);
    const planCode = requireString(body.planCode).toLowerCase();
    if (!planCodePattern.test(planCode)) {
      throw badRequest("Invalid plan code.");
    }
    const voucherCode = optionalCode(body.voucherCode);
    const platform = requireString(body.platform);
    if (platform !== "android" && platform !== "web") {
      throw badRequest("Unsupported checkout platform.");
    }

    const webOrigin = optionalString(body.webOrigin);
    if (platform === "web" && webOrigin === null) {
      throw badRequest("Web checkout requires an origin.");
    }
    if (platform === "android" && webOrigin !== null) {
      throw badRequest("Android checkout must not provide a web origin.");
    }

    return {
      action,
      planCode,
      voucherCode,
      platform,
      webOrigin,
    };
  }

  if (action === "confirm_checkout") {
    assertOnlyKeys(body, ["action", "sessionId"]);
    return {
      action,
      sessionId: requireString(body.sessionId),
    };
  }

  throw badRequest("Unsupported payment action.");
}

export function buildCheckoutCallbacks(input: {
  platform: CheckoutPlatform;
  planCode: string;
  webOrigin: string | null;
  allowedWebOrigins: ReadonlySet<string>;
}): CheckoutCallbacks {
  const encodedPlanCode = encodeURIComponent(input.planCode);
  if (input.platform === "android") {
    return {
      successUrl:
        `intent://upgrade-payment?plan=${encodedPlanCode}` +
        `&stripe_session_id={CHECKOUT_SESSION_ID}` +
        "#Intent;scheme=com.hellovietnam.app;" +
        "package=com.hellovietnam.app;end",
      cancelUrl:
        `intent://upgrade-payment?plan=${encodedPlanCode}&stripe_cancelled=1` +
        "#Intent;scheme=com.hellovietnam.app;" +
        "package=com.hellovietnam.app;end",
    };
  }

  const origin = normalizeOrigin(input.webOrigin);
  if (!input.allowedWebOrigins.has(origin)) {
    throw badRequest("Web checkout origin is not allowlisted.");
  }
  return {
    successUrl:
      `${origin}/#/upgrade-payment?plan=${encodedPlanCode}` +
      `&stripe_session_id={CHECKOUT_SESSION_ID}`,
    cancelUrl:
      `${origin}/#/upgrade-payment?plan=${encodedPlanCode}` +
      "&stripe_cancelled=1",
  };
}

export function validatePaidSession(
  session: StripeCheckoutSession,
  attempt: ValidatablePaymentAttempt,
  authenticatedUserId: string,
): void {
  if (
    attempt.userId !== authenticatedUserId ||
    session.clientReferenceId !== authenticatedUserId
  ) {
    throw new SubscriptionPaymentError(
      "UNAUTHORIZED",
      "Checkout Session does not belong to this user.",
      401,
    );
  }
  if (session.metadata.attempt_id !== attempt.idAttempt) {
    throw new SubscriptionPaymentError(
      "PAYMENT_SESSION_MISMATCH",
      "Checkout Session references a different payment attempt.",
      409,
    );
  }
  if (
    attempt.stripeSessionId !== null &&
    attempt.stripeSessionId !== session.id
  ) {
    throw new SubscriptionPaymentError(
      "PAYMENT_SESSION_MISMATCH",
      "Checkout Session ID does not match the payment attempt.",
      409,
    );
  }
  if (attempt.status === "expired" || attempt.status === "failed") {
    throw new SubscriptionPaymentError(
      "PAYMENT_ATTEMPT_CLOSED",
      "Payment attempt is no longer active.",
      409,
    );
  }
  if (session.status !== "complete" || session.paymentStatus !== "paid") {
    throw new SubscriptionPaymentError(
      "PAYMENT_REQUIRED",
      "Checkout Session is not paid.",
      402,
    );
  }
  if (session.amountTotal !== attempt.amountMinor) {
    throw new SubscriptionPaymentError(
      "PAYMENT_AMOUNT_MISMATCH",
      "Stripe amount does not match the server snapshot.",
      409,
    );
  }
  if (session.currency?.toUpperCase() !== attempt.currency) {
    throw new SubscriptionPaymentError(
      "PAYMENT_CURRENCY_MISMATCH",
      "Stripe currency does not match the server snapshot.",
      409,
    );
  }
}

function normalizeOrigin(value: string | null): string {
  if (!value) throw badRequest("Web checkout requires an origin.");
  try {
    const parsed = new URL(value);
    if (
      parsed.origin !== value ||
      parsed.username ||
      parsed.password ||
      parsed.search ||
      parsed.hash
    ) {
      throw badRequest("Web origin must not contain a path or credentials.");
    }
    return parsed.origin;
  } catch (error) {
    if (error instanceof SubscriptionPaymentError) throw error;
    throw badRequest("Web checkout origin is invalid.");
  }
}

function assertOnlyKeys(
  body: Record<string, unknown>,
  allowedKeys: string[],
): void {
  const allowed = new Set(allowedKeys);
  if (Object.keys(body).some((key) => !allowed.has(key))) {
    throw badRequest("Payment payload contains unsupported fields.");
  }
}

function requireRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw badRequest("Payment payload must be a JSON object.");
  }
  return value as Record<string, unknown>;
}

function requireString(value: unknown): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw badRequest("A required payment field is missing.");
  }
  return value.trim();
}

function optionalString(value: unknown): string | null {
  if (value === undefined || value === null || value === "") return null;
  return requireString(value);
}

function optionalCode(value: unknown): string | null {
  const code = optionalString(value)?.toUpperCase() ?? null;
  if (code !== null && !voucherCodePattern.test(code)) {
    throw badRequest("Voucher code is invalid.");
  }
  return code;
}

function badRequest(message: string): SubscriptionPaymentError {
  return new SubscriptionPaymentError("BAD_REQUEST", message, 400);
}
