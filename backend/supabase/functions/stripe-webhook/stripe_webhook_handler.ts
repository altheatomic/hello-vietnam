import type { StripeCheckoutSession } from "../_shared/stripe_checkout.ts";
import {
  StripeWebhookSignatureError,
  verifyStripeWebhookSignature,
} from "../_shared/stripe_webhook_signature.ts";
import {
  SubscriptionPaymentError,
  validatePaidSession,
} from "../subscription-payment/subscription_payment_domain.ts";
import type {
  StripeCheckoutGateway,
  SubscriptionPaymentStore,
} from "../subscription-payment/subscription_payment_handler.ts";

export type StripeWebhookDependencies = {
  store: SubscriptionPaymentStore;
  stripe: StripeCheckoutGateway;
  webhookSecret: string;
  nowMs?: () => number;
  logError?: (event: string, error: unknown) => void;
};

type StripeEvent = {
  id: string;
  type: string;
  object: {
    id: string;
    attemptId: string | null;
  } | null;
};

export function createStripeWebhookHandler(
  dependencies: StripeWebhookDependencies,
): (request: Request) => Promise<Response> {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
    }

    const rawBody = await request.text();
    try {
      await verifyStripeWebhookSignature({
        rawBody,
        signatureHeader: request.headers.get("stripe-signature"),
        secret: dependencies.webhookSecret,
        nowMs: dependencies.nowMs?.(),
      });
    } catch (error) {
      if (error instanceof StripeWebhookSignatureError) {
        return jsonResponse({ error: error.code }, 400);
      }
      dependencies.logError?.("STRIPE_SIGNATURE_CHECK_FAILED", error);
      return jsonResponse({ error: "STRIPE_SIGNATURE_INVALID" }, 400);
    }

    let event: StripeEvent;
    try {
      event = parseStripeEvent(JSON.parse(rawBody));
    } catch {
      return jsonResponse({ error: "STRIPE_EVENT_INVALID" }, 400);
    }

    if (
      event.type !== "checkout.session.completed" &&
      event.type !== "checkout.session.expired"
    ) {
      return jsonResponse({
        outcome: "ignored",
        eventId: event.id,
        eventType: event.type,
      });
    }

    try {
      if (event.type === "checkout.session.completed") {
        return await handleCompleted(dependencies, event);
      }
      return await handleExpired(dependencies, event);
    } catch (error) {
      if (error instanceof SubscriptionPaymentError) {
        dependencies.logError?.(error.code, error);
        return jsonResponse(
          { error: error.code, message: error.message },
          error.statusCode,
        );
      }
      dependencies.logError?.("STRIPE_WEBHOOK_FAILED", error);
      return jsonResponse({ error: "STRIPE_WEBHOOK_FAILED" }, 500);
    }
  };
}

async function handleCompleted(
  dependencies: StripeWebhookDependencies,
  event: StripeEvent,
): Promise<Response> {
  const eventObject = requireCheckoutObject(event);
  const session = await dependencies.stripe.retrieveSession(eventObject.id);
  if (session.id !== eventObject.id) {
    throw mismatch("Stripe event and retrieved Session IDs differ.");
  }

  const attemptId = session.metadata.attempt_id;
  if (!attemptId || attemptId !== eventObject.attemptId) {
    throw mismatch("Stripe Session payment attempt metadata differs.");
  }
  const attempt = await dependencies.store.findAttemptById(attemptId);
  if (!attempt) throw mismatch("Payment attempt was not found.");

  await attachSessionWhenMissing(dependencies, attempt, session);
  validatePaidSession(session, attempt, attempt.userId);
  const purchase = await dependencies.store.finalizeVerifiedSession(
    attempt.idAttempt,
    session,
  );
  try {
    await dependencies.store.awardLoyaltyPoints(
      attempt.userId,
      purchase,
      attempt.planCode,
    );
  } catch (error) {
    dependencies.logError?.("LOYALTY_SUBSCRIPTION_AWARD_FAILED", error);
  }

  return jsonResponse({
    outcome: "finalized",
    eventId: event.id,
    attemptId: attempt.idAttempt,
    sessionId: session.id,
    paymentId: purchase.paymentId,
  });
}

async function handleExpired(
  dependencies: StripeWebhookDependencies,
  event: StripeEvent,
): Promise<Response> {
  const eventObject = requireCheckoutObject(event);
  if (!eventObject.attemptId) {
    throw mismatch("Expired Session is missing payment attempt metadata.");
  }
  const attempt = await dependencies.store.findAttemptById(
    eventObject.attemptId,
  );
  if (!attempt) throw mismatch("Payment attempt was not found.");
  if (
    attempt.stripeSessionId !== null &&
    attempt.stripeSessionId !== eventObject.id
  ) {
    throw mismatch("Expired Session ID does not match payment attempt.");
  }
  if (attempt.stripeSessionId === null) {
    await dependencies.store.attachStripeSession(
      attempt.idAttempt,
      eventObject.id,
    );
  }
  if (attempt.status === "pending") {
    await dependencies.store.markAttemptExpired(attempt.idAttempt);
  }

  return jsonResponse({
    outcome: attempt.status === "finalized" ? "already_finalized" : "expired",
    eventId: event.id,
    attemptId: attempt.idAttempt,
    sessionId: eventObject.id,
  });
}

async function attachSessionWhenMissing(
  dependencies: StripeWebhookDependencies,
  attempt: Awaited<
    ReturnType<SubscriptionPaymentStore["findAttemptById"]>
  > & {},
  session: StripeCheckoutSession,
): Promise<void> {
  if (attempt.stripeSessionId === null) {
    await dependencies.store.attachStripeSession(attempt.idAttempt, session.id);
    attempt.stripeSessionId = session.id;
  }
}

function parseStripeEvent(value: unknown): StripeEvent {
  const event = requireRecord(value);
  const id = requireString(event.id);
  const type = requireString(event.type);
  if (type !== "checkout.session.completed" && type !== "checkout.session.expired") {
    return { id, type, object: null };
  }

  const data = requireRecord(event.data);
  const object = requireRecord(data.object);
  const metadata = object.metadata === null || object.metadata === undefined
    ? {}
    : requireRecord(object.metadata);
  return {
    id,
    type,
    object: {
      id: requireString(object.id),
      attemptId: typeof metadata.attempt_id === "string"
        ? metadata.attempt_id
        : null,
    },
  };
}

function requireCheckoutObject(
  event: StripeEvent,
): NonNullable<StripeEvent["object"]> {
  if (!event.object) throw new Error("STRIPE_EVENT_INVALID");
  return event.object;
}

function requireRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("STRIPE_EVENT_INVALID");
  }
  return value as Record<string, unknown>;
}

function requireString(value: unknown): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error("STRIPE_EVENT_INVALID");
  }
  return value;
}

function mismatch(message: string): SubscriptionPaymentError {
  return new SubscriptionPaymentError(
    "PAYMENT_SESSION_MISMATCH",
    message,
    409,
  );
}

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}
