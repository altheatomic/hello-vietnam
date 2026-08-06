import type { ContentFreshnessRow, SourceResult } from "./freshness_domain.ts";

export type FetchLike = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;
export type DelayLike = (milliseconds: number) => Promise<void>;

export interface SourceAdapter {
  fetch(
    freshness: ContentFreshnessRow,
    signal: AbortSignal,
  ): Promise<SourceResult>;
}

export type AdapterOptions = {
  fetchFn?: FetchLike;
  delay?: DelayLike;
  overpassUrl?: string;
};

export const SOURCE_HOST_ALLOWLIST = new Set([
  "overpass-api.de",
  "www.openstreetmap.org",
  "en.wikipedia.org",
  "vi.wikipedia.org",
  "commons.wikimedia.org",
]);

export function isAllowedSourceUrl(
  rawUrl: string,
  extraAllowedUrl?: string,
): boolean {
  try {
    const url = new URL(rawUrl);
    const configuredOverpass = extraAllowedUrl
      ? new URL(extraAllowedUrl)
      : null;
    const isConfiguredOverpass = configuredOverpass?.toString() === url.toString();
    if (url.protocol !== "https:" && !isConfiguredOverpass) return false;
    return SOURCE_HOST_ALLOWLIST.has(url.hostname.toLowerCase()) ||
      isConfiguredOverpass === true;
  } catch {
    return false;
  }
}

export type FetchSourceResponse =
  | { kind: "response"; response: Response; finalUrl: string }
  | { kind: "missing" }
  | { kind: "error"; error: string };

const DEFAULT_DELAY: DelayLike = (milliseconds) =>
  new Promise((resolve) => setTimeout(resolve, milliseconds));

function classifyRequestError(error: unknown, signal: AbortSignal): string {
  if (signal.aborted || (error instanceof DOMException && error.name === "AbortError")) {
    return "Source request timed out.";
  }
  if (error instanceof Error && error.message) return error.message;
  return "Source request failed.";
}

export async function fetchSourceResponse(
  rawUrl: string,
  signal: AbortSignal,
  options: {
    fetchFn?: FetchLike;
    delay?: DelayLike;
    extraAllowedUrl?: string;
    headers?: HeadersInit;
    body?: BodyInit;
  } = {},
): Promise<FetchSourceResponse> {
  if (!isAllowedSourceUrl(rawUrl, options.extraAllowedUrl)) {
    return { kind: "error", error: "Source host is not allowed." };
  }

  const fetchFn = options.fetchFn ?? fetch;
  const delay = options.delay ?? DEFAULT_DELAY;
  let requestUrl = rawUrl;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const response = await fetchFn(requestUrl, {
        headers: options.headers,
        body: options.body,
        redirect: "manual",
        signal,
      });

      if (response.status === 404 || response.status === 410) {
        return { kind: "missing" };
      }

      if (response.status >= 300 && response.status < 400) {
        const location = response.headers.get("location");
        if (!location) {
          return { kind: "error", error: "Source redirect is missing a location." };
        }
        const redirectedUrl = new URL(location, requestUrl).toString();
        if (!isAllowedSourceUrl(redirectedUrl, options.extraAllowedUrl)) {
          return { kind: "error", error: "Source redirect host is not allowed." };
        }
        requestUrl = redirectedUrl;
        continue;
      }

      const retryable = response.status === 429 || response.status >= 500;
      if (retryable && attempt < 2) {
        await delay(attempt === 0 ? 200 : 500);
        continue;
      }
      if (!response.ok) {
        return { kind: "error", error: `Source returned HTTP ${response.status}.` };
      }
      return { kind: "response", response, finalUrl: requestUrl };
    } catch (error) {
      if (attempt < 2 && !signal.aborted) {
        await delay(attempt === 0 ? 200 : 500);
        continue;
      }
      return { kind: "error", error: classifyRequestError(error, signal) };
    }
  }
  return { kind: "error", error: "Source request failed after retries." };
}

export async function adapterFor(
  sourceType: string,
  options: AdapterOptions = {},
): Promise<SourceAdapter> {
  switch (sourceType.trim().toLowerCase()) {
    case "osm": {
      const { OsmSourceAdapter } = await import("./osm_source_adapter.ts");
      return new OsmSourceAdapter(options.fetchFn, options.delay, options.overpassUrl);
    }
    case "wikipedia":
    case "wiki": {
      const { WikipediaSourceAdapter } = await import("./wikipedia_source_adapter.ts");
      return new WikipediaSourceAdapter(options.fetchFn, options.delay);
    }
    default:
      throw new Error(`Unsupported source type: ${sourceType}`);
  }
}
