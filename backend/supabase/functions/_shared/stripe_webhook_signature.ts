export class StripeWebhookSignatureError extends Error {
  constructor(readonly code: string, message: string) {
    super(`${code}: ${message}`);
    this.name = "StripeWebhookSignatureError";
  }
}

export type VerifyStripeWebhookSignatureInput = {
  rawBody: string;
  signatureHeader: string | null;
  secret: string;
  nowMs?: number;
  toleranceSeconds?: number;
};

const encoder = new TextEncoder();

export async function verifyStripeWebhookSignature(
  input: VerifyStripeWebhookSignatureInput,
): Promise<void> {
  if (!input.signatureHeader) {
    throw new StripeWebhookSignatureError(
      "STRIPE_SIGNATURE_MISSING",
      "Stripe-Signature header is required.",
    );
  }
  if (!input.secret.startsWith("whsec_")) {
    throw new StripeWebhookSignatureError(
      "STRIPE_WEBHOOK_SECRET_INVALID",
      "Stripe webhook secret must start with whsec_.",
    );
  }

  const parsed = parseSignatureHeader(input.signatureHeader);
  const toleranceSeconds = input.toleranceSeconds ?? 300;
  const nowSeconds = Math.floor((input.nowMs ?? Date.now()) / 1000);
  if (Math.abs(nowSeconds - parsed.timestamp) > toleranceSeconds) {
    throw new StripeWebhookSignatureError(
      "STRIPE_SIGNATURE_EXPIRED",
      "Stripe webhook timestamp is outside the allowed tolerance.",
    );
  }

  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(input.secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const signedPayload = encoder.encode(
    `${parsed.timestamp}.${input.rawBody}`,
  );

  for (const candidate of parsed.v1Signatures) {
    const signature = hexToBytes(candidate);
    if (!signature) continue;
    if (
      await crypto.subtle.verify(
        "HMAC",
        key,
        signature,
        signedPayload,
      )
    ) {
      return;
    }
  }

  throw new StripeWebhookSignatureError(
    "STRIPE_SIGNATURE_INVALID",
    "Stripe webhook signature does not match the raw request body.",
  );
}

function parseSignatureHeader(header: string): {
  timestamp: number;
  v1Signatures: string[];
} {
  let timestamp: number | null = null;
  const v1Signatures: string[] = [];

  for (const part of header.split(",")) {
    const [key, value] = part.trim().split("=", 2);
    if (key === "t") {
      const parsedTimestamp = Number(value);
      if (Number.isSafeInteger(parsedTimestamp) && parsedTimestamp > 0) {
        timestamp = parsedTimestamp;
      }
    } else if (key === "v1" && value) {
      v1Signatures.push(value);
    }
  }

  if (timestamp === null || v1Signatures.length === 0) {
    throw new StripeWebhookSignatureError(
      "STRIPE_SIGNATURE_MALFORMED",
      "Stripe-Signature must include t and v1 values.",
    );
  }

  return { timestamp, v1Signatures };
}

function hexToBytes(value: string): Uint8Array<ArrayBuffer> | null {
  if (value.length === 0 || value.length % 2 !== 0) return null;
  if (!/^[0-9a-f]+$/i.test(value)) return null;

  const bytes = new Uint8Array(new ArrayBuffer(value.length / 2));
  for (let index = 0; index < value.length; index += 2) {
    bytes[index / 2] = Number.parseInt(value.slice(index, index + 2), 16);
  }
  return bytes;
}
