import { corsHeaders } from "../_shared/cors.ts";
import type {
  CreateStripeCheckoutInput,
  StripeCheckoutSession,
} from "../_shared/stripe_checkout.ts";
import {
  buildCheckoutCallbacks,
  parseSubscriptionPaymentCommand,
  SubscriptionPaymentError,
  validatePaidSession,
} from "./subscription_payment_domain.ts";

export type CreateAttemptInput = {
  userId: string;
  planCode: string;
  voucherCode: string | null;
};

export type PaymentAttempt = {
  idAttempt: string;
  userId: string;
  planCode: string;
  planName: string;
  durationDays: number;
  originalAmountMinor: number;
  discountMinor: number;
  amountMinor: number;
  currency: "USD";
  stripeSessionId: string | null;
  status: "pending" | "paid" | "finalized" | "expired" | "failed";
  failureReason: string | null;
};

export type FinalizedPurchase = {
  paymentId: string;
  subscriptionId: string;
  originalAmountMinor: number;
  discountMinor: number;
  finalAmountMinor: number;
  voucherCode: string | null;
  subscriptionEndDate: string;
};

export interface SubscriptionPaymentStore {
  authenticate(
    authorization: string | null,
  ): Promise<{ id: string } | null>;
  createAttempt(input: CreateAttemptInput): Promise<PaymentAttempt>;
  attachStripeSession(attemptId: string, sessionId: string): Promise<void>;
  findAttemptById(attemptId: string): Promise<PaymentAttempt | null>;
  finalizeVerifiedSession(
    attemptId: string,
    session: StripeCheckoutSession,
  ): Promise<FinalizedPurchase>;
  markAttemptFailed(attemptId: string, reason: string): Promise<void>;
  markAttemptExpired(attemptId: string): Promise<void>;
  awardLoyaltyPoints(
    userId: string,
    purchase: FinalizedPurchase,
    planCode: string,
  ): Promise<void>;
}

export interface StripeCheckoutGateway {
  createSession(
    input: CreateStripeCheckoutInput,
    idempotencyKey: string,
  ): Promise<StripeCheckoutSession>;
  retrieveSession(sessionId: string): Promise<StripeCheckoutSession>;
}

export type SubscriptionPaymentDependencies = {
  store: SubscriptionPaymentStore;
  stripe: StripeCheckoutGateway;
  allowedWebOrigins: ReadonlySet<string>;
  logError?: (event: string, error: unknown) => void;
};

export function createSubscriptionPaymentHandler(
  dependencies: SubscriptionPaymentDependencies,
): (request: Request) => Promise<Response> {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }
    if (request.method !== "POST") {
      return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
    }

    try {
      const user = await dependencies.store.authenticate(
        request.headers.get("authorization"),
      );
      if (!user) {
        throw new SubscriptionPaymentError(
          "UNAUTHORIZED",
          "A valid user session is required.",
          401,
        );
      }

      let rawBody: unknown;
      try {
        rawBody = await request.json();
      } catch {
        throw new SubscriptionPaymentError(
          "BAD_REQUEST",
          "Request body must be valid JSON.",
          400,
        );
      }
      const command = parseSubscriptionPaymentCommand(rawBody);
      if (command.action === "create_checkout") {
        return await createCheckout(dependencies, user.id, command);
      }
      return await confirmCheckout(
        dependencies,
        user.id,
        command.sessionId,
      );
    } catch (error) {
      if (error instanceof SubscriptionPaymentError) {
        return jsonResponse(
          { error: error.code, message: error.message },
          error.statusCode,
        );
      }
      dependencies.logError?.("SUBSCRIPTION_PAYMENT_FAILED", error);
      return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
    }
  };
}

async function createCheckout(
  dependencies: SubscriptionPaymentDependencies,
  userId: string,
  command: {
    planCode: string;
    voucherCode: string | null;
    platform: "android" | "web";
    webOrigin: string | null;
  },
): Promise<Response> {
  const attempt = await dependencies.store.createAttempt({
    userId,
    planCode: command.planCode,
    voucherCode: command.voucherCode,
  });
  if (attempt.amountMinor <= 0) {
    await dependencies.store.markAttemptFailed(
      attempt.idAttempt,
      "ZERO_AMOUNT_CHECKOUT_UNSUPPORTED",
    );
    throw new SubscriptionPaymentError(
      "BAD_REQUEST",
      "A fully discounted Premium checkout is not supported.",
      400,
    );
  }

  const callbacks = buildCheckoutCallbacks({
    platform: command.platform,
    planCode: attempt.planCode,
    webOrigin: command.webOrigin,
    allowedWebOrigins: dependencies.allowedWebOrigins,
  });

  let session: StripeCheckoutSession;
  try {
    session = await dependencies.stripe.createSession(
      {
        attemptId: attempt.idAttempt,
        userId,
        planName: attempt.planName,
        amountMinor: attempt.amountMinor,
        currency: attempt.currency,
        successUrl: callbacks.successUrl,
        cancelUrl: callbacks.cancelUrl,
      },
      attempt.idAttempt,
    );
  } catch (error) {
    const reason = error instanceof Error ? error.message : "Unknown error";
    await dependencies.store.markAttemptFailed(attempt.idAttempt, reason);
    dependencies.logError?.("STRIPE_CHECKOUT_CREATE_FAILED", error);
    throw new SubscriptionPaymentError(
      "PAYMENT_PROVIDER_UNAVAILABLE",
      "Stripe Sandbox Checkout is temporarily unavailable.",
      502,
    );
  }

  if (!session.url) {
    await dependencies.store.markAttemptFailed(
      attempt.idAttempt,
      "STRIPE_CHECKOUT_URL_MISSING",
    );
    throw new SubscriptionPaymentError(
      "PAYMENT_PROVIDER_UNAVAILABLE",
      "Stripe Sandbox did not return a Checkout URL.",
      502,
    );
  }

  await dependencies.store.attachStripeSession(
    attempt.idAttempt,
    session.id,
  );

  return jsonResponse({
    status: "requires_checkout",
    checkoutUrl: session.url,
    sessionId: session.id,
    originalAmountMinor: attempt.originalAmountMinor,
    discountMinor: attempt.discountMinor,
    finalAmountMinor: attempt.amountMinor,
  });
}

async function confirmCheckout(
  dependencies: SubscriptionPaymentDependencies,
  userId: string,
  sessionId: string,
): Promise<Response> {
  let session: StripeCheckoutSession;
  try {
    session = await dependencies.stripe.retrieveSession(sessionId);
  } catch (error) {
    dependencies.logError?.("STRIPE_CHECKOUT_RETRIEVE_FAILED", error);
    throw new SubscriptionPaymentError(
      "PAYMENT_PROVIDER_UNAVAILABLE",
      "Stripe Sandbox Session could not be loaded.",
      502,
    );
  }

  const attemptId = session.metadata.attempt_id;
  if (!attemptId) {
    throw new SubscriptionPaymentError(
      "PAYMENT_SESSION_MISMATCH",
      "Checkout Session is missing its payment attempt.",
      409,
    );
  }
  const attempt = await dependencies.store.findAttemptById(attemptId);
  if (!attempt) {
    throw new SubscriptionPaymentError(
      "PAYMENT_SESSION_MISMATCH",
      "Payment attempt was not found.",
      409,
    );
  }
  if (attempt.userId !== userId) {
    throw new SubscriptionPaymentError(
      "UNAUTHORIZED",
      "Checkout Session does not belong to this user.",
      401,
    );
  }
  if (attempt.stripeSessionId === null) {
    await dependencies.store.attachStripeSession(attempt.idAttempt, session.id);
    attempt.stripeSessionId = session.id;
  }

  validatePaidSession(session, attempt, userId);
  const purchase = await dependencies.store.finalizeVerifiedSession(
    attempt.idAttempt,
    session,
  );

  try {
    await dependencies.store.awardLoyaltyPoints(
      userId,
      purchase,
      attempt.planCode,
    );
  } catch (error) {
    dependencies.logError?.("LOYALTY_SUBSCRIPTION_AWARD_FAILED", error);
  }

  return jsonResponse({
    status: "completed",
    purchase: serializePurchase(purchase),
    sessionId: session.id,
  });
}

function serializePurchase(
  purchase: FinalizedPurchase,
): Record<string, unknown> {
  return {
    id_payment: purchase.paymentId,
    id_subscription: purchase.subscriptionId,
    original_amount_minor: purchase.originalAmountMinor,
    discount_minor: purchase.discountMinor,
    final_amount_minor: purchase.finalAmountMinor,
    voucher_code: purchase.voucherCode,
    subscription_end_date: purchase.subscriptionEndDate,
  };
}

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json; charset=utf-8",
    },
  });
}
