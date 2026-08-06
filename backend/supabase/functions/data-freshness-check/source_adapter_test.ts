import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { ContentFreshnessRow } from "./freshness_domain.ts";
import {
  WikipediaSourceAdapter,
} from "./wikipedia_source_adapter.ts";
import { OsmSourceAdapter } from "./osm_source_adapter.ts";
import { SOURCE_HOST_ALLOWLIST } from "./source_adapter.ts";

function fixtureWikipediaFreshness(
  sourceUrl = "https://en.wikipedia.org/wiki/Hoi_An",
): ContentFreshnessRow {
  return {
    id: "10000000-0000-4000-8000-000000000001",
    contentType: "activity",
    contentId: "20000000-0000-4000-8000-000000000001",
    sourceType: "wikipedia",
    sourceUrl,
    sourceExternalId: `wikipedia:${sourceUrl}`,
    availabilityType: "evergreen",
    validUntil: null,
    freshnessStatus: "due",
    sourceHash: null,
    consecutiveMissingCount: 0,
  };
}

function fixtureOsmFreshness(): ContentFreshnessRow {
  return {
    ...fixtureWikipediaFreshness("https://www.openstreetmap.org/node/123"),
    contentType: "place",
    sourceType: "osm",
    sourceExternalId: "osm:node:123",
    availabilityType: "business",
  };
}

Deno.test("the source allowlist contains only configured providers", () => {
  assertEquals(SOURCE_HOST_ALLOWLIST.has("en.wikipedia.org"), true);
  assertEquals(SOURCE_HOST_ALLOWLIST.has("overpass-api.de"), true);
  assertEquals(SOURCE_HOST_ALLOWLIST.has("127.0.0.1"), false);
});

Deno.test("rejects a source URL outside the configured allowlist", async () => {
  const adapter = new WikipediaSourceAdapter(async () => new Response("ok"));
  const result = await adapter.fetch(
    fixtureWikipediaFreshness("http://127.0.0.1/admin"),
    AbortSignal.timeout(100),
  );
  assertEquals(result, { outcome: "error", error: "Source host is not allowed." });
});

Deno.test("OSM 404 is a valid missing result", async () => {
  const adapter = new OsmSourceAdapter(async () => new Response("", { status: 404 }));
  const result = await adapter.fetch(fixtureOsmFreshness(), AbortSignal.timeout(100));
  assertEquals(result, { outcome: "missing" });
});

Deno.test("Wikipedia parses a canonical title and summary", async () => {
  const html = `
    <html><head><title>Hoi An - Wikipedia</title></head>
    <body><h1 id="firstHeading">Hoi An</h1>
      <div class="mw-parser-output"><p>Hoi An is a well-preserved ancient town in Vietnam with a long history.</p></div>
    </body></html>`;
  const adapter = new WikipediaSourceAdapter(async () => new Response(html, { status: 200 }));
  const result = await adapter.fetch(fixtureWikipediaFreshness(), AbortSignal.timeout(100));
  assertEquals(result.outcome, "found");
  if (result.outcome === "found") {
    assertEquals(result.data.name, "Hoi An");
    assertStringIncludes(String(result.data.summary), "well-preserved ancient town");
    assertEquals(result.sourceHash.length, 64);
  }
});

Deno.test("OSM normalizes only operational fields", async () => {
  const payload = {
    elements: [{
      type: "node",
      id: 123,
      lat: 16.06,
      lon: 108.2,
      tags: {
        name: "Cafe Example",
        "addr:street": "New Street",
        opening_hours: "08:00-21:00",
        phone: "+84 123",
        website: "https://example.com",
      },
    }],
  };
  const adapter = new OsmSourceAdapter(async () =>
    new Response(JSON.stringify(payload), {
      status: 200,
      headers: { "content-type": "application/json" },
    }));
  const result = await adapter.fetch(fixtureOsmFreshness(), AbortSignal.timeout(100));
  assertEquals(result.outcome, "found");
  if (result.outcome === "found") {
    assertEquals(result.data, {
      name: "Cafe Example",
      address: "New Street",
      latitude: 16.06,
      longitude: 108.2,
      timespan: "08:00",
      timeclose: "21:00",
      phone: "+84 123",
      website: "https://example.com",
      status: "active",
    });
  }
});

Deno.test("source adapter turns an aborted request into an error", async () => {
  const adapter = new WikipediaSourceAdapter(async (_url, init) => {
    init?.signal?.throwIfAborted();
    throw new DOMException("aborted", "AbortError");
  });
  const result = await adapter.fetch(fixtureWikipediaFreshness(), AbortSignal.timeout(100));
  assertEquals(result.outcome, "error");
});
