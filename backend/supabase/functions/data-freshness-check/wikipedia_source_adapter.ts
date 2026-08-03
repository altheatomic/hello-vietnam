import {
  fetchSourceResponse,
  type DelayLike,
  type FetchLike,
  type SourceAdapter,
} from "./source_adapter.ts";
import {
  stableSourceHash,
  type ContentFreshnessRow,
  type JsonObject,
  type SourceResult,
} from "./freshness_domain.ts";

function decodeHtml(value: string): string {
  const named: Record<string, string> = {
    amp: "&",
    apos: "'",
    gt: ">",
    lt: "<",
    nbsp: " ",
    quot: '"',
  };
  return value
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)))
    .replace(/&#x([\da-f]+);/gi, (_, code) => String.fromCodePoint(parseInt(code, 16)))
    .replace(/&([a-z]+);/gi, (full, name) => named[name.toLowerCase()] ?? full);
}

function htmlText(fragment: string): string {
  return decodeHtml(
    fragment
      .replace(/<br\s*\/?>/gi, " ")
      .replace(/<[^>]+>/g, " ")
      .replace(/\s+/g, " "),
  ).trim();
}

function firstMatch(html: string, patterns: RegExp[]): string | null {
  for (const pattern of patterns) {
    const match = html.match(pattern);
    if (match?.[1]) return htmlText(match[1]);
  }
  return null;
}

function normalizeWikipediaHtml(html: string): JsonObject | null {
  const title = firstMatch(html, [
    /<h1[^>]*id=["']firstHeading["'][^>]*>([\s\S]*?)<\/h1>/i,
    /<h1[^>]*>([\s\S]*?)<\/h1>/i,
    /<title[^>]*>([\s\S]*?)<\/title>/i,
  ]);
  if (!title) return null;
  const normalizedTitle = title.replace(/\s+-\s+Wikipedia\s*$/i, "").trim();
  const paragraphs = [...html.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/gi)]
    .map((match) => htmlText(match[1]))
    .filter((text) => text.length >= 40);
  return {
    name: normalizedTitle,
    summary: paragraphs[0] ?? "",
  };
}

export class WikipediaSourceAdapter implements SourceAdapter {
  private readonly fetchFn: FetchLike;
  private readonly delay: DelayLike | undefined;

  constructor(fetchFn: FetchLike = fetch, delay?: DelayLike) {
    this.fetchFn = fetchFn;
    this.delay = delay;
  }

  async fetch(
    freshness: ContentFreshnessRow,
    signal: AbortSignal,
  ): Promise<SourceResult> {
    const sourceUrl = freshness.sourceUrl ?? "";
    const response = await fetchSourceResponse(sourceUrl, signal, {
      fetchFn: this.fetchFn,
      delay: this.delay,
      headers: { Accept: "text/html,application/xhtml+xml" },
    });
    if (response.kind === "missing") return { outcome: "missing" };
    if (response.kind === "error") return { outcome: "error", error: response.error };

    try {
      const html = await response.response.text();
      const data = normalizeWikipediaHtml(html);
      if (!data || !data.name) {
        return { outcome: "error", error: "Wikipedia page structure could not be parsed." };
      }
      return {
        outcome: "found",
        data,
        sourceHash: await stableSourceHash(data),
      };
    } catch {
      return { outcome: "error", error: "Wikipedia response could not be parsed." };
    }
  }
}

export { normalizeWikipediaHtml };
