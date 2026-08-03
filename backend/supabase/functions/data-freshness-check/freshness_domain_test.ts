import {
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  evaluateFreshness,
  nextCheckAt,
  sourceOwnedPatch,
  stableSourceHash,
  type ContentFreshnessRow,
} from "./freshness_domain.ts";

const NOW = new Date("2026-08-03T02:15:00Z");

function fixtureFreshness(
  overrides: Partial<ContentFreshnessRow> = {},
): ContentFreshnessRow {
  return {
    id: "10000000-0000-4000-8000-000000000001",
    contentType: "place",
    contentId: "20000000-0000-4000-8000-000000000001",
    sourceType: "osm",
    sourceUrl: "https://www.openstreetmap.org/node/123",
    sourceExternalId: "osm:node:123",
    availabilityType: "business",
    validUntil: null,
    freshnessStatus: "due",
    sourceHash: "same",
    consecutiveMissingCount: 0,
    ...overrides,
  };
}

Deno.test("a past scheduled event auto expires", () => {
  const decision = evaluateFreshness({
    freshness: fixtureFreshness({
      availabilityType: "scheduled_event",
      validUntil: "2026-08-02T23:59:00Z",
    }),
    source: { outcome: "found", data: {}, sourceHash: "same" },
    currentContent: { status: "active" },
    now: NOW,
  });
  assertEquals(decision.kind, "auto_expire");
  assertEquals(decision.contentPatch, { status: "expired" });
});

Deno.test("an error never increments missing count", () => {
  const decision = evaluateFreshness({
    freshness: fixtureFreshness({ consecutiveMissingCount: 1 }),
    source: { outcome: "error", error: "timeout" },
    currentContent: { status: "active" },
    now: NOW,
  });
  assertEquals(decision.kind, "error");
  assertEquals(decision.consecutiveMissingCount, 1);
});

Deno.test("unchanged source becomes fresh and resets missing count", () => {
  const decision = evaluateFreshness({
    freshness: fixtureFreshness(),
    source: { outcome: "found", data: { name: "Cafe" }, sourceHash: "same" },
    currentContent: { name: "Cafe", status: "active" },
    now: NOW,
  });
  assertEquals(decision.kind, "unchanged");
  assertEquals(decision.freshnessStatus, "fresh");
  assertEquals(decision.consecutiveMissingCount, 0);
});

Deno.test("first valid missing source is stale but remains visible", () => {
  const decision = evaluateFreshness({
    freshness: fixtureFreshness(),
    source: { outcome: "missing" },
    currentContent: { status: "active" },
    now: NOW,
  });
  assertEquals(decision.kind, "first_missing");
  assertEquals(decision.freshnessStatus, "stale");
  assertEquals(decision.consecutiveMissingCount, 1);
});

Deno.test("second valid missing source needs review without archiving", () => {
  const decision = evaluateFreshness({
    freshness: fixtureFreshness({ consecutiveMissingCount: 1 }),
    source: { outcome: "missing" },
    currentContent: { status: "active" },
    now: NOW,
  });
  assertEquals(decision.kind, "second_missing");
  assertEquals(decision.freshnessStatus, "needs_review");
  assertEquals(decision.proposedData, { status: "archived" });
  assertEquals(decision.contentPatch, {});
});

Deno.test("a recovered source clears missing history", () => {
  const decision = evaluateFreshness({
    freshness: fixtureFreshness({
      consecutiveMissingCount: 1,
      sourceHash: "old",
    }),
    source: { outcome: "found", data: { name: "Cafe" }, sourceHash: "new" },
    currentContent: { name: "Cafe", status: "active" },
    now: NOW,
  });
  assertEquals(decision.kind, "recovered");
  assertEquals(decision.freshnessStatus, "fresh");
  assertEquals(decision.consecutiveMissingCount, 0);
});

Deno.test("operational address changes create a review proposal", () => {
  const decision = evaluateFreshness({
    freshness: fixtureFreshness(),
    source: {
      outcome: "found",
      data: { name: "Cafe", address: "2 New Street" },
      sourceHash: "new",
    },
    currentContent: { name: "Cafe", address: "1 Old Street", status: "active" },
    now: NOW,
  });
  assertEquals(decision.kind, "proposal");
  assertEquals(decision.freshnessStatus, "needs_review");
  assertEquals(decision.changedFields, ["address"]);
  assertEquals(decision.proposedData, { address: "2 New Street" });
});

Deno.test("editorial fields are never proposed by the source patch", () => {
  assertEquals(
    sourceOwnedPatch(
      { name: "Cafe", description: "Curated copy", status: "active" },
      { name: "Cafe", description: null, status: "active" },
    ),
    {},
  );
});

Deno.test("hashing is stable regardless of object key order", async () => {
  const first = await stableSourceHash({ b: 2, a: { d: 4, c: 3 } });
  const second = await stableSourceHash({ a: { c: 3, d: 4 }, b: 2 });
  assertEquals(first, second);
  assertNotEquals(first, await stableSourceHash({ a: 1 }));
});

Deno.test("cadence follows availability type", () => {
  assertEquals(nextCheckAt("business", NOW), "2026-08-10T02:15:00.000Z");
  assertEquals(nextCheckAt("scheduled_event", NOW), "2026-08-04T02:15:00.000Z");
  assertEquals(nextCheckAt("evergreen", NOW), "2026-09-02T02:15:00.000Z");
});
