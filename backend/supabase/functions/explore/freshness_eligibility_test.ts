import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { resolveFreshnessEligibility } from "./freshness_eligibility.ts";

Deno.test("stale content remains listable with a warning", () => {
  const result = resolveFreshnessEligibility({
    freshness_status: "stale",
    last_verified_at: "2026-07-01T00:00:00Z",
  });
  assertEquals(result.listable, true);
  assertEquals(result.plannerEligible, true);
  assertEquals(result.warning, "stale");
});

Deno.test("needs_review content is not listable or planner eligible", () => {
  const result = resolveFreshnessEligibility({ freshness_status: "needs_review" });
  assertEquals(result.listable, false);
  assertEquals(result.plannerEligible, false);
  assertEquals(result.warning, "needs_review");
});

Deno.test("expired content is hidden", () => {
  const result = resolveFreshnessEligibility({ freshness_status: "expired" });
  assertEquals(result.listable, false);
  assertEquals(result.plannerEligible, false);
  assertEquals(result.warning, "expired");
});

Deno.test("fresh, due, and missing legacy rows remain eligible", () => {
  for (const freshness of [
    { freshness_status: "fresh" },
    { freshness_status: "due" },
    null,
  ]) {
    const result = resolveFreshnessEligibility(freshness);
    assertEquals(result.listable, true);
    assertEquals(result.plannerEligible, true);
    assertEquals(result.warning, null);
  }
});
