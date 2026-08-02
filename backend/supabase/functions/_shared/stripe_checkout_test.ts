import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  StripeCheckoutClient,
  StripeCheckoutError,
} from "./stripe_checkout.ts";

Deno.test("createSession sends server-owned payment details and idempotency key", async () => {
  let capturedUrl = "";
  let capturedInit: RequestInit | undefined;
  const client = new StripeCheckoutClient({
    secretKey: "sk_test_checkout",
    fetcher: async (input: RequestInfo | URL, init?: RequestInit) => {
      capturedUrl = String(input);
      capturedInit = init;
      return Response.json({
        id: "cs_test_created",
        url: "https://checkout.stripe.test/cs_test_created",
        client_reference_id: "user-1",
        metadata: { attempt_id: "attempt-1" },
        status: "open",
        payment_status: "unpaid",
        amount_total: 1999,
        currency: "usd",
      });
    },
  });

  const session = await client.createSession(
    {
      attemptId: "attempt-1",
      userId: "user-1",
      planName: "Premium 6 Months",
      amountMinor: 1999,
      currency: "USD",
      successUrl:
        "intent://upgrade-payment?plan=6m&stripe_session_id={CHECKOUT_SESSION_ID}#Intent;scheme=com.hellovietnam.app;package=com.hellovietnam.app;end",
      cancelUrl:
        "intent://upgrade-payment?plan=6m&stripe_cancelled=1#Intent;scheme=com.hellovietnam.app;package=com.hellovietnam.app;end",
    },
    "attempt-1",
  );

  assertEquals(capturedUrl, "https://api.stripe.com/v1/checkout/sessions");
  assertEquals(capturedInit?.method, "POST");
  assertEquals(
    new Headers(capturedInit?.headers).get("authorization"),
    "Bearer sk_test_checkout",
  );
  assertEquals(
    new Headers(capturedInit?.headers).get("idempotency-key"),
    "attempt-1",
  );

  const body = new URLSearchParams(String(capturedInit?.body));
  assertEquals(body.get("mode"), "payment");
  assertEquals(body.get("client_reference_id"), "user-1");
  assertEquals(body.get("metadata[attempt_id]"), "attempt-1");
  assertEquals(body.get("line_items[0][price_data][currency]"), "usd");
  assertEquals(body.get("line_items[0][price_data][unit_amount]"), "1999");
  assertEquals(
    body.get("line_items[0][price_data][product_data][name]"),
    "Premium 6 Months",
  );
  assertEquals(
    body.get("success_url"),
    "intent://upgrade-payment?plan=6m&stripe_session_id={CHECKOUT_SESSION_ID}#Intent;scheme=com.hellovietnam.app;package=com.hellovietnam.app;end",
  );
  assertEquals(session.id, "cs_test_created");
  assertEquals(session.amountTotal, 1999);
  assertEquals(session.currency, "usd");
});

Deno.test("retrieveSession maps the Stripe Checkout response", async () => {
  const client = new StripeCheckoutClient({
    secretKey: "sk_test_checkout",
    fetcher: async () =>
      Response.json({
        id: "cs_test_paid",
        url: null,
        client_reference_id: "user-2",
        metadata: { attempt_id: "attempt-2" },
        status: "complete",
        payment_status: "paid",
        amount_total: 499,
        currency: "usd",
      }),
  });

  const session = await client.retrieveSession("cs_test_paid");

  assertEquals(session, {
    id: "cs_test_paid",
    url: null,
    clientReferenceId: "user-2",
    metadata: { attempt_id: "attempt-2" },
    status: "complete",
    paymentStatus: "paid",
    amountTotal: 499,
    currency: "usd",
  });
});

Deno.test("Stripe Checkout client rejects a live secret in Sandbox mode", () => {
  assertRejects(
    async () => {
      new StripeCheckoutClient({ secretKey: "sk_live_forbidden" });
    },
    StripeCheckoutError,
    "STRIPE_SANDBOX_KEY_REQUIRED",
  );
});

Deno.test("Stripe Checkout client normalizes an upstream error", async () => {
  const client = new StripeCheckoutClient({
    secretKey: "sk_test_checkout",
    fetcher: async () =>
      Response.json(
        { error: { message: "The card was declined." } },
        { status: 402 },
      ),
  });

  const error = await assertRejects(
    () => client.retrieveSession("cs_test_declined"),
    StripeCheckoutError,
  ) as StripeCheckoutError;

  assertEquals(error.code, "STRIPE_SESSION_LOAD_FAILED");
  assertStringIncludes(error.message, "The card was declined.");
});
