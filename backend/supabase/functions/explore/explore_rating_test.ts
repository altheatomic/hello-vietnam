import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { resolveExploreRating } from "./explore_rating.ts";

Deno.test("official review average replaces the stored content rating", () => {
  assertEquals(
    resolveExploreRating({
      storedRating: 4.7,
      storedReviewCount: 20,
      officialAverageRating: 5,
      officialReviewCount: 1,
    }),
    { rating: 5, reviewCount: 1, usesOfficialReviews: true },
  );
});

Deno.test("stored content rating remains when no official review exists", () => {
  assertEquals(
    resolveExploreRating({
      storedRating: 4.7,
      storedReviewCount: 20,
      officialAverageRating: null,
      officialReviewCount: 0,
    }),
    { rating: 4.7, reviewCount: 20, usesOfficialReviews: false },
  );
});
