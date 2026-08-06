export type StripeCheckoutSession = {
  id: string;
  url: string | null;
  clientReferenceId: string | null;
  metadata: Record<string, string>;
  status: string | null;
  paymentStatus: string | null;
  amountTotal: number | null;
  currency: string | null;
};

export type CreateStripeCheckoutInput = {
  attemptId: string;
  userId: string;
  planName: string;
  amountMinor: number;
  currency: "USD";
  successUrl: string;
  cancelUrl: string;
};

export type StripeFetcher = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;

export class StripeCheckoutError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly status: number | null = null,
  ) {
    super(`${code}: ${message}`);
    this.name = "StripeCheckoutError";
  }
}

type StripeCheckoutClientOptions = {
  secretKey: string;
  fetcher?: StripeFetcher;
  baseUrl?: string;
};

type StripeSessionJson = {
  id?: unknown;
  url?: unknown;
  client_reference_id?: unknown;
  metadata?: unknown;
  status?: unknown;
  payment_status?: unknown;
  amount_total?: unknown;
  currency?: unknown;
  error?: {
    message?: unknown;
  };
};

export class StripeCheckoutClient {
  private readonly secretKey: string;
  private readonly fetcher: StripeFetcher;
  private readonly baseUrl: string;

  constructor(options: StripeCheckoutClientOptions) {
    if (!options.secretKey.startsWith("sk_test_")) {
      throw new StripeCheckoutError(
        "STRIPE_SANDBOX_KEY_REQUIRED",
        "Stripe Sandbox requires an sk_test_ secret.",
      );
    }
    this.secretKey = options.secretKey;
    this.fetcher = options.fetcher ?? fetch;
    this.baseUrl = (options.baseUrl ?? "https://api.stripe.com/v1")
      .replace(/\/+$/, "");
  }

  async createSession(
    input: CreateStripeCheckoutInput,
    idempotencyKey: string,
  ): Promise<StripeCheckoutSession> {
    const body = new URLSearchParams();
    body.set("mode", "payment");
    body.set("payment_method_types[0]", "card");
    body.set("client_reference_id", input.userId);
    body.set("success_url", input.successUrl);
    body.set("cancel_url", input.cancelUrl);
    body.set("line_items[0][quantity]", "1");
    body.set(
      "line_items[0][price_data][currency]",
      input.currency.toLowerCase(),
    );
    body.set(
      "line_items[0][price_data][unit_amount]",
      String(input.amountMinor),
    );
    body.set(
      "line_items[0][price_data][product_data][name]",
      input.planName,
    );
    body.set("metadata[attempt_id]", input.attemptId);

    return await this.request(
      `${this.baseUrl}/checkout/sessions`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${this.secretKey}`,
          "content-type": "application/x-www-form-urlencoded",
          "idempotency-key": idempotencyKey,
        },
        body,
      },
      "STRIPE_CHECKOUT_FAILED",
    );
  }

  async retrieveSession(sessionId: string): Promise<StripeCheckoutSession> {
    return await this.request(
      `${this.baseUrl}/checkout/sessions/${encodeURIComponent(sessionId)}`,
      {
        headers: {
          authorization: `Bearer ${this.secretKey}`,
        },
      },
      "STRIPE_SESSION_LOAD_FAILED",
    );
  }

  private async request(
    url: string,
    init: RequestInit,
    errorCode: string,
  ): Promise<StripeCheckoutSession> {
    const response = await this.fetcher(url, init);
    const payload = await readJson(response);
    if (!response.ok) {
      throw new StripeCheckoutError(
        errorCode,
        String(payload.error?.message ?? `Stripe returned ${response.status}.`),
        response.status,
      );
    }
    if (typeof payload.id !== "string" || payload.id.length === 0) {
      throw new StripeCheckoutError(
        errorCode,
        "Stripe response is missing a Checkout Session ID.",
        response.status,
      );
    }
    return mapSession(payload);
  }
}

async function readJson(response: Response): Promise<StripeSessionJson> {
  try {
    return await response.json() as StripeSessionJson;
  } catch {
    throw new StripeCheckoutError(
      "STRIPE_RESPONSE_INVALID",
      "Stripe returned an invalid JSON response.",
      response.status,
    );
  }
}

function mapSession(payload: StripeSessionJson): StripeCheckoutSession {
  const metadata = isStringRecord(payload.metadata) ? payload.metadata : {};
  return {
    id: String(payload.id),
    url: typeof payload.url === "string" ? payload.url : null,
    clientReferenceId: typeof payload.client_reference_id === "string"
      ? payload.client_reference_id
      : null,
    metadata,
    status: typeof payload.status === "string" ? payload.status : null,
    paymentStatus: typeof payload.payment_status === "string"
      ? payload.payment_status
      : null,
    amountTotal: typeof payload.amount_total === "number"
      ? payload.amount_total
      : null,
    currency: typeof payload.currency === "string"
      ? payload.currency.toLowerCase()
      : null,
  };
}

function isStringRecord(value: unknown): value is Record<string, string> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  return Object.values(value).every((item) => typeof item === "string");
}
