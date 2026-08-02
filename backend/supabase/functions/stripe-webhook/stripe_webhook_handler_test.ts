import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import type {
  CreateAttemptInput,
  FinalizedPurchase,
  PaymentAttempt,
  SubscriptionPaymentStore,
} from "../subscription-payment/subscription_payment_handler.ts";
import type {
  CreateStripeCheckoutInput,
  StripeCheckoutSession,
} from "../_shared/stripe_checkout.ts";
import {
  createStripeWebhookHandler,
} from "./stripe_webhook_handler.ts";

const secret = "whsec_webhook_test";
const timestamp = 1_700_000_000;
const encoder = new TextEncoder();

const paidSession: StripeCheckoutSession = {
  id: "cs_test_webhook",
  url: null,
  clientReferenceId: "user-1",
  metadata: { attempt_id: "attempt-1" },
  status: "complete",
  paymentStatus: "paid",
  amountTotal: 1999,
  currency: "usd",
};

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
  stripeSessionId: "cs_test_webhook",
  status: "pending",
  failureReason: null,
};

const purchase: FinalizedPurchase = {
  paymentId: "payment-1",
  subscriptionId: "subscription-1",
  originalAmountMinor: 1999,
  discountMinor: 0,
  finalAmountMinor: 1999,
  voucherCode: null,
  subscriptionEndDate: "2027-01-26T00:00:00.000Z",
};

class FakeStore implements SubscriptionPaymentStore {
  currentAttempt: PaymentAttempt | null = { ...attempt };
  finalizedCalls = 0;
  expiredCalls = 0;
  attachCalls = 0;
  loyaltyCalls = 0;

  authenticate(): Promise<{ id: string } | null> {
    throw new Error("Webhook must not authenticate as an app user.");
  }

  createAttempt(_input: CreateAttemptInput): Promise<PaymentAttempt> {
    throw new Error("Webhook must not create payment attempts.");
  }

  attachStripeSession(): Promise<void> {
    this.attachCalls += 1;
    return Promise.resolve();
  }

  findAttemptById(): Promise<PaymentAttempt | null> {
    return Promise.resolve(
      this.currentAttempt ? { ...this.currentAttempt } : null,
    );
  }

  finalizeVerifiedSession(): Promise<FinalizedPurchase> {
    this.finalizedCalls += 1;
    return Promise.resolve(purchase);
  }

  markAttemptFailed(): Promise<void> {
    throw new Error("Webhook does not mark a paid attempt failed.");
  }

  markAttemptExpired(): Promise<void> {
    this.expiredCalls += 1;
    return Promise.resolve();
  }

  awardLoyaltyPoints(): Promise<void> {
    this.loyaltyCalls += 1;
    return Promise.resolve();
  }
}

class FakeStripe {
  retrieveCalls = 0;

  createSession(
    _input: CreateStripeCheckoutInput,
    _idempotencyKey: string,
  ): Promise<StripeCheckoutSession> {
    throw new Error("Webhook must not create Checkout Sessions.");
  }

  retrieveSession(): Promise<StripeCheckoutSession> {
    this.retrieveCalls += 1;
    return Promise.resolve(paidSession);
  }
}

async function signedRequest(event: Record<string, unknown>): Promise<Request> {
  const rawBody = JSON.stringify(event);
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(`${timestamp}.${rawBody}`),
  );
  const hex = [...new Uint8Array(signature)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return new Request("https://function.test/stripe-webhook", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "stripe-signature": `t=${timestamp},v1=${hex}`,
    },
    body: rawBody,
  });
}

function completedEvent(): Record<string, unknown> {
  return {
    id: "evt_completed",
    type: "checkout.session.completed",
    data: {
      object: {
        id: "cs_test_webhook",
        metadata: { attempt_id: "attempt-1" },
      },
    },
  };
}

Deno.test("webhook rejects a missing Stripe signature without DB access", async () => {
  const store = new FakeStore();
  const handler = createStripeWebhookHandler({
    store,
    stripe: new FakeStripe(),
    webhookSecret: secret,
    nowMs: () => timestamp * 1000,
  });

  const response = await handler(
    new Request("https://function.test/stripe-webhook", {
      method: "POST",
      body: JSON.stringify(completedEvent()),
    }),
  );

  assertEquals(response.status, 400);
  assertEquals(store.finalizedCalls, 0);
});

Deno.test("webhook rejects an invalid Stripe signature", async () => {
  const store = new FakeStore();
  const handler = createStripeWebhookHandler({
    store,
    stripe: new FakeStripe(),
    webhookSecret: secret,
    nowMs: () => timestamp * 1000,
  });
  const request = await signedRequest(completedEvent());
  request.headers.set(
    "stripe-signature",
    `t=${timestamp},v1=${"0".repeat(64)}`,
  );

  const response = await handler(request);

  assertEquals(response.status, 400);
  assertEquals(store.finalizedCalls, 0);
});

Deno.test("completed webhook retrieves and finalizes the current Session", async () => {
  const store = new FakeStore();
  const stripe = new FakeStripe();
  const handler = createStripeWebhookHandler({
    store,
    stripe,
    webhookSecret: secret,
    nowMs: () => timestamp * 1000,
  });

  const response = await handler(await signedRequest(completedEvent()));
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.outcome, "finalized");
  assertEquals(stripe.retrieveCalls, 1);
  assertEquals(store.finalizedCalls, 1);
  assertEquals(store.loyaltyCalls, 1);
});

Deno.test("expired webhook marks only its matching pending attempt expired", async () => {
  const store = new FakeStore();
  const handler = createStripeWebhookHandler({
    store,
    stripe: new FakeStripe(),
    webhookSecret: secret,
    nowMs: () => timestamp * 1000,
  });
  const event = {
    id: "evt_expired",
    type: "checkout.session.expired",
    data: {
      object: {
        id: "cs_test_webhook",
        metadata: { attempt_id: "attempt-1" },
      },
    },
  };

  const response = await handler(await signedRequest(event));

  assertEquals(response.status, 200);
  assertEquals(store.expiredCalls, 1);
  assertEquals(store.finalizedCalls, 0);
});

Deno.test("unknown signed webhook event returns ignored without DB access", async () => {
  const store = new FakeStore();
  const stripe = new FakeStripe();
  const handler = createStripeWebhookHandler({
    store,
    stripe,
    webhookSecret: secret,
    nowMs: () => timestamp * 1000,
  });

  const response = await handler(
    await signedRequest({
      id: "evt_unknown",
      type: "customer.created",
      data: { object: { id: "cus_test" } },
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.outcome, "ignored");
  assertEquals(stripe.retrieveCalls, 0);
  assertEquals(store.finalizedCalls, 0);
});

Deno.test("duplicate completed webhook returns a successful idempotent outcome", async () => {
  const store = new FakeStore();
  store.currentAttempt = { ...attempt, status: "finalized" };
  const handler = createStripeWebhookHandler({
    store,
    stripe: new FakeStripe(),
    webhookSecret: secret,
    nowMs: () => timestamp * 1000,
  });

  const first = await handler(await signedRequest(completedEvent()));
  const second = await handler(await signedRequest(completedEvent()));

  assertEquals(first.status, 200);
  assertEquals(second.status, 200);
  assertEquals(store.finalizedCalls, 2);
});
