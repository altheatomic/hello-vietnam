/// <reference lib="dom" />
/// <reference path="../deno-globals.d.ts" />

import { corsHeaders } from "../_shared/cors.ts";

type CurrencyRatesPayload = {
  base?: string;
  symbols?: string[];
  provider?: string;
};

type RatesResponse = {
  provider: string;
  base_code: string;
  updated_at: string | null;
  rates: Record<string, number>;
};

const DEFAULT_SYMBOLS = [
  "USD",
  "VND",
  "EUR",
  "GBP",
  "JPY",
  "CNY",
  "KRW",
  "AUD",
  "CAD",
  "CHF",
  "SGD",
  "HKD",
  "INR",
  "THB",
  "MYR",
  "IDR",
  "PHP",
  "RUB",
  "BRL",
  "MXN",
];

const DEFAULT_BASE = "USD";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST" && request.method !== "GET") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const payload = request.method === "GET"
    ? getPayloadFromUrl(request.url)
    : await readPayload(request);

  const base = normalizeCurrencyCode(payload.base) ?? DEFAULT_BASE;
  const symbols = normalizeSymbols(payload.symbols);
  const provider = (payload.provider ?? Deno.env.get("CURRENCY_RATES_PROVIDER") ?? "open-er-api")
    .trim()
    .toLowerCase();

  try {
    const response = provider === "frankfurter"
      ? await loadFrankfurterRates(base, symbols)
      : await loadOpenExchangeRates(base, symbols);

    return jsonResponse(response, 200);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to load currency rates.";
    return jsonResponse({ error: message }, 502);
  }
});

async function readPayload(request: Request): Promise<CurrencyRatesPayload> {
  try {
    const payload = await request.json();
    return payload && typeof payload === "object" ? payload as CurrencyRatesPayload : {};
  } catch (_) {
    return {};
  }
}

function getPayloadFromUrl(url: string): CurrencyRatesPayload {
  const params = new URL(url).searchParams;
  return {
    base: params.get("base") ?? undefined,
    provider: params.get("provider") ?? undefined,
    symbols: params
      .get("symbols")
      ?.split(",")
      .map((symbol) => symbol.trim())
      .filter((symbol) => symbol.length > 0),
  };
}

function normalizeCurrencyCode(value: string | undefined): string | null {
  const code = value?.trim().toUpperCase();
  if (!code || code.length !== 3) return null;
  return code;
}

function normalizeSymbols(symbols: string[] | undefined): string[] {
  const values = (symbols?.length ? symbols : DEFAULT_SYMBOLS)
    .map((symbol) => symbol.trim().toUpperCase())
    .filter((symbol, index, list) => symbol.length === 3 && list.indexOf(symbol) === index);
  return values.length > 0 ? values : DEFAULT_SYMBOLS;
}

async function loadOpenExchangeRates(base: string, symbols: string[]): Promise<RatesResponse> {
  const endpoint = `https://open.er-api.com/v6/latest/${encodeURIComponent(base)}`;
  const response = await fetch(endpoint, { headers: { accept: "application/json" } });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(readErrorMessage(data) ?? `ExchangeRate request failed (${response.status}).`);
  }

  if (data?.result !== "success" || typeof data?.rates !== "object" || data?.rates == null) {
    throw new Error("ExchangeRate response was missing rates.");
  }

  return {
    provider: String(data.provider ?? "open-er-api"),
    base_code: String(data.base_code ?? base),
    updated_at: String(data.time_last_update_utc ?? data.time_last_update_unix ?? "") || null,
    rates: pickRates(data.rates as Record<string, unknown>, symbols),
  };
}

async function loadFrankfurterRates(base: string, symbols: string[]): Promise<RatesResponse> {
  const endpoint = new URL("https://api.frankfurter.app/latest");
  endpoint.searchParams.set("from", base);
  endpoint.searchParams.set("to", symbols.join(","));

  const response = await fetch(endpoint, { headers: { accept: "application/json" } });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(readErrorMessage(data) ?? `Frankfurter request failed (${response.status}).`);
  }

  if (typeof data?.rates !== "object" || data?.rates == null) {
    throw new Error("Frankfurter response was missing rates.");
  }

  return {
    provider: "frankfurter",
    base_code: String(data.base ?? base),
    updated_at: String(data.date ?? "") || null,
    rates: pickRates(data.rates as Record<string, unknown>, symbols),
  };
}

function pickRates(
  rates: Record<string, unknown>,
  symbols: string[],
): Record<string, number> {
  const result: Record<string, number> = {};
  for (const symbol of symbols) {
    const raw = rates[symbol];
    const value = typeof raw === "number" ? raw : Number(raw);
    if (Number.isFinite(value)) {
      result[symbol] = value;
    }
  }
  return result;
}

function readErrorMessage(value: unknown): string | null {
  if (typeof value === "string") return value;
  if (!value || typeof value !== "object") return null;
  const message = (value as Record<string, unknown>).error;
  return typeof message === "string" ? message : null;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json; charset=utf-8",
    },
  });
}