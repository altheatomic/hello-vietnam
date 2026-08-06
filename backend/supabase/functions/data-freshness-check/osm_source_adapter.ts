import {
  fetchSourceResponse,
  isAllowedSourceUrl,
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

const DEFAULT_OVERPASS_URL = "https://overpass-api.de/api/interpreter";
const OSM_ID_PATTERN = /^osm:(node|way|relation):(\d+)$/i;
const TIME_RANGE_PATTERN = /(\d{1,2}:\d{2})\s*[-–]\s*(\d{1,2}:\d{2})/;

function canonicalOsmSourceUrl(sourceExternalId: string | null): string | null {
  const match = sourceExternalId?.match(OSM_ID_PATTERN);
  if (!match) return null;
  return `https://www.openstreetmap.org/${match[1].toLowerCase()}/${match[2]}`;
}

function cleanText(value: unknown): string | null {
  const text = String(value ?? "").replace(/\s+/g, " ").trim();
  return text || null;
}

function parseTimeRange(value: unknown): { timespan: string | null; timeclose: string | null } {
  const match = String(value ?? "").match(TIME_RANGE_PATTERN);
  return {
    timespan: match?.[1] ?? null,
    timeclose: match?.[2] ?? null,
  };
}

function normalizeElement(element: JsonObject): JsonObject | null {
  const tags = (element.tags ?? {}) as Record<string, unknown>;
  const name = cleanText(tags.name);
  if (!name) return null;

  const center = (element.center ?? {}) as Record<string, unknown>;
  const latitude = Number(element.lat ?? center.lat);
  const longitude = Number(element.lon ?? center.lon);
  const hasCoordinates = Number.isFinite(latitude) && Number.isFinite(longitude);
  const address = cleanText(
    tags["addr:full"] ??
      [
        tags["addr:housenumber"],
        tags["addr:street"],
        tags["addr:suburb"],
        tags["addr:district"],
        tags["addr:city"],
      ].filter(Boolean).join(", "),
  );
  const time = parseTimeRange(tags.opening_hours);
  const disused = Boolean(tags.disused || tags.abandoned || tags["disused:amenity"]);
  const data: JsonObject = {
    name,
    address,
    latitude: hasCoordinates ? latitude : null,
    longitude: hasCoordinates ? longitude : null,
    timespan: time.timespan,
    timeclose: time.timeclose,
    phone: cleanText(tags["contact:phone"] ?? tags.phone),
    website: cleanText(tags["contact:website"] ?? tags.website),
    status: disused ? "hidden" : "active",
  };
  return data;
}

export class OsmSourceAdapter implements SourceAdapter {
  private readonly fetchFn: FetchLike;
  private readonly delay: DelayLike | undefined;
  private readonly overpassUrl: string;

  constructor(
    fetchFn: FetchLike = fetch,
    delay?: DelayLike,
    overpassUrl = DEFAULT_OVERPASS_URL,
  ) {
    this.fetchFn = fetchFn;
    this.delay = delay;
    this.overpassUrl = overpassUrl;
  }

  async fetch(
    freshness: ContentFreshnessRow,
    signal: AbortSignal,
  ): Promise<SourceResult> {
    const match = freshness.sourceExternalId?.match(OSM_ID_PATTERN);
    if (!match) {
      return { outcome: "error", error: "Invalid OSM source identity." };
    }
    const sourceUrl = freshness.sourceUrl?.trim() ||
      canonicalOsmSourceUrl(freshness.sourceExternalId);
    if (!sourceUrl || !isAllowedSourceUrl(sourceUrl)) {
      return { outcome: "error", error: "Source host is not allowed." };
    }

    const [_, elementType, elementId] = match;
    const query = `[out:json][timeout:30];${elementType}(id:${elementId});out center tags;`;
    const response = await fetchSourceResponse(this.overpassUrl, signal, {
      fetchFn: this.fetchFn,
      delay: this.delay,
      extraAllowedUrl: this.overpassUrl,
      headers: {
        "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
        Accept: "application/json",
      },
      body: new URLSearchParams({ data: query }),
    });
    if (response.kind === "missing") return { outcome: "missing" };
    if (response.kind === "error") return { outcome: "error", error: response.error };

    try {
      const payload = await response.response.json() as { elements?: JsonObject[] };
      const element = payload.elements?.[0];
      if (!element) return { outcome: "missing" };
      const data = normalizeElement(element);
      if (!data) return { outcome: "missing" };
      return {
        outcome: "found",
        data,
        sourceHash: await stableSourceHash(data),
      };
    } catch {
      return { outcome: "error", error: "Source response could not be parsed." };
    }
  }
}

export { DEFAULT_OVERPASS_URL, canonicalOsmSourceUrl };
