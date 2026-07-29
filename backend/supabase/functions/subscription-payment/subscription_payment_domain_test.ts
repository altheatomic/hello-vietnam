import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  buildCheckoutCallbacks,
  parseSubscriptionPaymentCommand,
  SubscriptionPaymentError,
  validatePaidSession,
} from "./subscription_payment_domain.ts";

Deno.test("parse create_checkout accepts Android without redirect URLs", () => {
  assertEquals(
    parseSubscriptionPaymentCommand({
      action: "create_checkout",
      planCode: "6m",
      voucherCode: " loyalty10 ",
      platform: "android",
      webOrigin: null,
    }),
    {
      action: "create_checkout",
      planCode: "6m",
      voucherCode: "LOYALTY10",
      platform: "android",
      webOrigin: null,
    },
  );
});

Deno.test("parse create_checkout rejects client-owned redirect URLs", () => {
  const error = assertThrows(
    () =>
      parseSubscriptionPaymentCommand({
        action: "create_checkout",
        planCode: "6m",
        voucherCode: null,
        platform: "android",
        webOrigin: null,
        successUrl: "https://evil.test/success",
      }),
    SubscriptionPaymentError,
  ) as SubscriptionPaymentError;

  assertEquals(error.code, "BAD_REQUEST");
});

Deno.test("Android callbacks are pinned to com.hellovietnam.app", () => {
  assertEquals(
    buildCheckoutCallbacks({
      platform: "android",
      planCode: "6m",
      webOrigin: null,
      allowedWebOrigins: new Set(),
    }),
    {
      successUrl:
        "intent://upgrade-payment?plan=6m&stripe_session_id={CHECKOUT_SESSION_ID}#Intent;scheme=com.hellovietnam.app;package=com.hellovietnam.app;end",
      cancelUrl:
        "intent://upgrade-payment?plan=6m&stripe_cancelled=1#Intent;scheme=com.hellovietnam.app;package=com.hellovietnam.app;end",
    },
  );
});

Deno.test("web callbacks require an allowlisted normalized origin", () => {
  assertEquals(
    buildCheckoutCallbacks({
      platform: "web",
      planCode: "12m",
      webOrigin: "http://localhost:3000",
      allowedWebOrigins: new Set(["http://localhost:3000"]),
    }),
    {
      successUrl:
        "http://localhost:3000/#/upgrade-payment?plan=12m&stripe_session_id={CHECKOUT_SESSION_ID}",
      cancelUrl:
        "http://localhost:3000/#/upgrade-payment?plan=12m&stripe_cancelled=1",
    },
  );

  const error = assertThrows(
    () =>
      buildCheckoutCallbacks({
        platform: "web",
        planCode: "12m",
        webOrigin: "https://evil.test",
        allowedWebOrigins: new Set(["http://localhost:3000"]),
      }),
    SubscriptionPaymentError,
  ) as SubscriptionPaymentError;
  assertEquals(error.code, "BAD_REQUEST");
});

Deno.test("validatePaidSession accepts a fully matching paid session", () => {
  validatePaidSession(
    {
      id: "cs_test_paid",
      url: null,
      clientReferenceId: "user-1",
      metadata: { attempt_id: "attempt-1" },
      status: "complete",
      paymentStatus: "paid",
      amountTotal: 1999,
      currency: "usd",
    },
    {
      idAttempt: "attempt-1",
      userId: "user-1",
      amountMinor: 1999,
      currency: "USD",
      stripeSessionId: "cs_test_paid",
      status: "pending",
    },
    "user-1",
  );
});

Deno.test("validatePaidSession rejects ownership, amount and unpaid mismatches", () => {
  const baseSession = {
    id: "cs_test_paid",
    url: null,
    clientReferenceId: "user-1",
    metadata: { attempt_id: "attempt-1" },
    status: "complete",
    paymentStatus: "paid",
    amountTotal: 1999,
    currency: "usd",
  };
  const attempt = {
    idAttempt: "attempt-1",
    userId: "user-1",
    planCode: "6m",
    planName: "Premium 6 Months",
    durationDays: 180,
    originalAmountMinor: 1999,
    discountMinor: 0,
    amountMinor: 1999,
    currency: "USD" as const,
    stripeSessionId: "cs_test_paid",
    status: "pending" as const,
    failureReason: null,
  };

  assertEquals(
    (assertThrows(
      () => validatePaidSession(baseSession, attempt, "user-2"),
      SubscriptionPaymentError,
    ) as SubscriptionPaymentError).code,
    "UNAUTHORIZED",
  );
  assertEquals(
    (assertThrows(
      () =>
        validatePaidSession(
          { ...baseSession, amountTotal: 499 },
          attempt,
          "user-1",
        ),
      SubscriptionPaymentError,
    ) as SubscriptionPaymentError).code,
    "PAYMENT_AMOUNT_MISMATCH",
  );
  assertEquals(
    (assertThrows(
      () =>
        validatePaidSession(
          {
            ...baseSession,
            status: "open",
            paymentStatus: "unpaid",
          },
          attempt,
          "user-1",
        ),
      SubscriptionPaymentError,
    ) as SubscriptionPaymentError).code,
    "PAYMENT_REQUIRED",
  );
});
