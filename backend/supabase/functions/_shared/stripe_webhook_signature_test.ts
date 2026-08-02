import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  StripeWebhookSignatureError,
  verifyStripeWebhookSignature,
} from "./stripe_webhook_signature.ts";

const encoder = new TextEncoder();

async function signFixture(
  secret: string,
  timestamp: number,
  rawBody: string,
): Promise<string> {
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
  return [...new Uint8Array(signature)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

Deno.test("verifyStripeWebhookSignature accepts a current matching v1 signature", async () => {
  const secret = "whsec_test_secret";
  const timestamp = 1_700_000_000;
  const rawBody = '{"id":"evt_1","type":"checkout.session.completed"}';
  const signature = await signFixture(secret, timestamp, rawBody);

  await verifyStripeWebhookSignature({
    rawBody,
    signatureHeader: `t=${timestamp},v1=${signature}`,
    secret,
    nowMs: timestamp * 1000,
  });
});

Deno.test("verifyStripeWebhookSignature checks every v1 candidate", async () => {
  const secret = "whsec_test_secret";
  const timestamp = 1_700_000_000;
  const rawBody = '{"id":"evt_2"}';
  const signature = await signFixture(secret, timestamp, rawBody);

  await verifyStripeWebhookSignature({
    rawBody,
    signatureHeader: `t=${timestamp},v1=deadbeef,v1=${signature}`,
    secret,
    nowMs: timestamp * 1000,
  });
});

Deno.test("verifyStripeWebhookSignature rejects a body changed after signing", async () => {
  const secret = "whsec_test_secret";
  const timestamp = 1_700_000_000;
  const signature = await signFixture(secret, timestamp, '{"paid":true}');

  const error = await assertRejects(
    () =>
      verifyStripeWebhookSignature({
        rawBody: '{"paid":false}',
        signatureHeader: `t=${timestamp},v1=${signature}`,
        secret,
        nowMs: timestamp * 1000,
      }),
    StripeWebhookSignatureError,
  ) as StripeWebhookSignatureError;

  assertEquals(error.code, "STRIPE_SIGNATURE_INVALID");
});

Deno.test("verifyStripeWebhookSignature rejects a stale signed event", async () => {
  const secret = "whsec_test_secret";
  const timestamp = 1_700_000_000;
  const rawBody = '{"id":"evt_stale"}';
  const signature = await signFixture(secret, timestamp, rawBody);

  const error = await assertRejects(
    () =>
      verifyStripeWebhookSignature({
        rawBody,
        signatureHeader: `t=${timestamp},v1=${signature}`,
        secret,
        nowMs: (timestamp + 301) * 1000,
      }),
    StripeWebhookSignatureError,
  ) as StripeWebhookSignatureError;

  assertEquals(error.code, "STRIPE_SIGNATURE_EXPIRED");
});
