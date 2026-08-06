import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import type {
  CreateStripeCheckoutInput,
  StripeCheckoutSession,
} from "../_shared/stripe_checkout.ts";
import {
  createSubscriptionPaymentHandler,
  type FinalizedPurchase,
  type PaymentAttempt,
  type SubscriptionPaymentStore,
} from "./subscription_payment_handler.ts";

const attempt: PaymentAttempt = {
  idAttempt: "attempt-1",
  userId: "user-1",
  planCode: "6m",
  planName: "Premium 6 Months",
  durationDays: 180,
  originalAmountMinor: 1999,
  discountMinor: 0,
  amountMinor: 1999,
  currency: "USD",
  stripeSessionId: null,
  status: "pending",
  failureReason: null,
};

const finalized: FinalizedPurchase = {
  paymentId: "payment-1",
  subscriptionId: "subscription-1",
  originalAmountMinor: 1999,
  discountMinor: 0,
  finalAmountMinor: 1999,
  voucherCode: null,
  subscriptionEndDate: "2027-01-26T00:00:00.000Z",
};

const paidSession: StripeCheckoutSession = {
  id: "cs_test_paid",
  url: null,
  clientReferenceId: "user-1",
  metadata: { attempt_id: "attempt-1" },
  status: "complete",
  paymentStatus: "paid",
  amountTotal: 1999,
  currency: "usd",
};

class FakeStore implements SubscriptionPaymentStore {
  authenticatedUser: { id: string } | null = { id: "user-1" };
  currentAttempt: PaymentAttempt | null = { ...attempt };
  createCalls = 0;
  attachCalls: Array<{ attemptId: string; sessionId: string }> = [];
  finalizedCalls = 0;
  failedReasons: string[] = [];
  loyaltyCalls = 0;

  authenticate(): Promise<{ id: string } | null> {
    return Promise.resolve(this.authenticatedUser);
  }

  createAttempt(): Promise<PaymentAttempt> {
    this.createCalls += 1;
    return Promise.resolve({ ...attempt });
  }

  attachStripeSession(attemptId: string, sessionId: string): Promise<void> {
    this.attachCalls.push({ attemptId, sessionId });
    if (this.currentAttempt?.idAttempt === attemptId) {
      this.currentAttempt = {
        ...this.currentAttempt,
        stripeSessionId: sessionId,
      };
    }
    return Promise.resolve();
  }

  findAttemptById(): Promise<PaymentAttempt | null> {
    return Promise.resolve(
      this.currentAttempt ? { ...this.currentAttempt } : null,
    );
  }

  finalizeVerifiedSession(): Promise<FinalizedPurchase> {
    this.finalizedCalls += 1;
    return Promise.resolve(finalized);
  }

  markAttemptFailed(_attemptId: string, reason: string): Promise<void> {
    this.failedReasons.push(reason);
    return Promise.resolve();
  }

  markAttemptExpired(): Promise<void> {
    return Promise.resolve();
  }

  awardLoyaltyPoints(): Promise<void> {
    this.loyaltyCalls += 1;
    return Promise.resolve();
  }
}

class FakeStripe {
  createdInput: CreateStripeCheckoutInput | null = null;
  idempotencyKey: string | null = null;
  createError: Error | null = null;
  retrievedSession: StripeCheckoutSession = paidSession;

  createSession(
    input: CreateStripeCheckoutInput,
    idempotencyKey: string,
  ): Promise<StripeCheckoutSession> {
    if (this.createError) return Promise.reject(this.createError);
    this.createdInput = input;
    this.idempotencyKey = idempotencyKey;
    return Promise.resolve({
      ...paidSession,
      id: "cs_test_created",
      url: "https://checkout.stripe.test/cs_test_created",
      status: "open",
      paymentStatus: "unpaid",
    });
  }

  retrieveSession(): Promise<StripeCheckoutSession> {
    return Promise.resolve(this.retrievedSession);
  }
}

function request(body: Record<string, unknown>): Request {
  return new Request("https://function.test/subscription-payment", {
    method: "POST",
    headers: {
      authorization: "Bearer user-token",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

Deno.test("handler rejects an invalid JWT before creating an attempt", async () => {
  const store = new FakeStore();
  store.authenticatedUser = null;
  const handler = createSubscriptionPaymentHandler({
    store,
    stripe: new FakeStripe(),
    allowedWebOrigins: new Set(),
  });

  const response = await handler(
    request({
      action: "create_checkout",
      planCode: "6m",
      platform: "android",
      webOrigin: null,
    }),
  );

  assertEquals(response.status, 401);
  assertEquals(store.createCalls, 0);
});

Deno.test("create_checkout uses the server snapshot and pinned Android callback", async () => {
  const store = new FakeStore();
  const stripe = new FakeStripe();
  const handler = createSubscriptionPaymentHandler({
    store,
    stripe,
    allowedWebOrigins: new Set(),
  });

  const response = await handler(
    request({
      action: "create_checkout",
      planCode: "6m",
      voucherCode: null,
      platform: "android",
      webOrigin: null,
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.status, "requires_checkout");
  assertEquals(stripe.idempotencyKey, "attempt-1");
  assertEquals(stripe.createdInput?.amountMinor, 1999);
  assertEquals(
    stripe.createdInput?.successUrl,
    "intent://upgrade-payment?plan=6m&stripe_session_id={CHECKOUT_SESSION_ID}#Intent;scheme=com.hellovietnam.app;package=com.hellovietnam.app;end",
  );
  assertEquals(store.attachCalls, [{
    attemptId: "attempt-1",
    sessionId: "cs_test_created",
  }]);
});

Deno.test("create_checkout rejects client-supplied redirect URLs", async () => {
  const store = new FakeStore();
  const handler = createSubscriptionPaymentHandler({
    store,
    stripe: new FakeStripe(),
    allowedWebOrigins: new Set(),
  });

  const response = await handler(
    request({
      action: "create_checkout",
      planCode: "6m",
      platform: "android",
      webOrigin: null,
      successUrl: "https://evil.test",
    }),
  );

  assertEquals(response.status, 400);
  assertEquals(store.createCalls, 0);
});

Deno.test("Stripe creation failure marks the pending attempt failed", async () => {
  const store = new FakeStore();
  const stripe = new FakeStripe();
  stripe.createError = new Error("Stripe unavailable");
  const handler = createSubscriptionPaymentHandler({
    store,
    stripe,
    allowedWebOrigins: new Set(),
  });

  const response = await handler(
    request({
      action: "create_checkout",
      planCode: "6m",
      platform: "android",
      webOrigin: null,
    }),
  );

  assertEquals(response.status, 502);
  assertEquals(store.failedReasons.length, 1);
  assertStringIncludes(store.failedReasons[0], "Stripe unavailable");
});

Deno.test("confirm_checkout rejects a Session owned by another user", async () => {
  const store = new FakeStore();
  store.authenticatedUser = { id: "user-2" };
  store.currentAttempt = {
    ...attempt,
    stripeSessionId: "cs_test_paid",
  };
  const handler = createSubscriptionPaymentHandler({
    store,
    stripe: new FakeStripe(),
    allowedWebOrigins: new Set(),
  });

  const response = await handler(
    request({ action: "confirm_checkout", sessionId: "cs_test_paid" }),
  );

  assertEquals(response.status, 401);
  assertEquals(store.finalizedCalls, 0);
});

Deno.test("confirm_checkout finalizes a matching paid Session once", async () => {
  const store = new FakeStore();
  store.currentAttempt = {
    ...attempt,
    stripeSessionId: "cs_test_paid",
  };
  const handler = createSubscriptionPaymentHandler({
    store,
    stripe: new FakeStripe(),
    allowedWebOrigins: new Set(),
  });

  const response = await handler(
    request({ action: "confirm_checkout", sessionId: "cs_test_paid" }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body, {
    status: "completed",
    purchase: {
      id_payment: "payment-1",
      id_subscription: "subscription-1",
      original_amount_minor: 1999,
      discount_minor: 0,
      final_amount_minor: 1999,
      voucher_code: null,
      subscription_end_date: "2027-01-26T00:00:00.000Z",
    },
    sessionId: "cs_test_paid",
  });
  assertEquals(store.finalizedCalls, 1);
  assertEquals(store.loyaltyCalls, 1);
});
