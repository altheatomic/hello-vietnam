import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  evaluateModeration,
  normalizeReviewText,
  parseReviewListPayload,
  parseUpsertPayload,
  summarizePublishedReviews,
} from "./reviews_handler.ts";
import { rejectBannedReview } from "./review_service.ts";
import { CONTENT_REGISTRY } from "./review_types.ts";

const validContentId = "11111111-1111-4111-8111-111111111111";

Deno.test("parseUpsertPayload rejects unsupported content types", () => {
  assertThrows(
    () =>
      parseUpsertPayload({
        contentType: "hotel",
        contentId: validContentId,
        rating: 5,
        comment: "Great",
      }),
    Error,
    "Invalid contentType",
  );
});

Deno.test("parseUpsertPayload rejects inherited content type names", () => {
  assertThrows(
    () =>
      parseUpsertPayload({
        contentType: "toString",
        contentId: validContentId,
        rating: 5,
        comment: "Great",
      }),
    Error,
    "Invalid contentType",
  );
});

Deno.test("parseReviewListPayload accepts an optional rating filter", () => {
  const payload = parseReviewListPayload({
    contentType: "food",
    contentId: validContentId,
    ratingFilter: 4,
  });

  assertEquals(payload.ratingFilter, 4);
  assertEquals(
    parseReviewListPayload({
      contentType: "food",
      contentId: validContentId,
    }).ratingFilter,
    undefined,
  );
});

Deno.test("parseReviewListPayload rejects an invalid rating filter", () => {
  assertThrows(
    () =>
      parseReviewListPayload({
        contentType: "food",
        contentId: validContentId,
        ratingFilter: 6,
      }),
    Error,
    "ratingFilter must be an integer between 1 and 5.",
  );
});

Deno.test("content registry matches the current database id columns", () => {
  assertEquals(CONTENT_REGISTRY.activity.idCandidates, ["id"]);
  assertEquals(CONTENT_REGISTRY.culture.idCandidates, ["id"]);
  assertEquals(CONTENT_REGISTRY.food.idCandidates, ["id_food"]);
  assertEquals(CONTENT_REGISTRY.local_product.idCandidates, ["id"]);
  assertEquals(CONTENT_REGISTRY.place.idCandidates, ["id_place"]);
  assertEquals(CONTENT_REGISTRY.province.idCandidates, ["id_province"]);
  assertEquals(CONTENT_REGISTRY.old_province.idCandidates, ["id_province"]);
});

Deno.test("normalizeReviewText removes Vietnamese diacritics and normalizes whitespace", () => {
  assertEquals(normalizeReviewText("  Pho   Bo  "), "pho bo");
});

Deno.test("evaluateModeration blocks banned keywords before suspected matches", () => {
  assertEquals(
    evaluateModeration("A harmless suspected phrase and a banned phrase", [
      {
        normalized_keyword: "suspected phrase",
        match_type: "contains",
        severity: "suspected",
      },
      {
        normalized_keyword: "banned phrase",
        match_type: "contains",
        severity: "banned",
      },
    ]),
    { status: "blocked", moderationResult: "banned" },
  );
});

Deno.test("evaluateModeration preserves regex syntax and case", () => {
  assertEquals(
    evaluateModeration("AB", [
      {
        normalized_keyword: "^[A-Z]{2}$",
        match_type: "regex",
        severity: "banned",
      },
    ]),
    { status: "blocked", moderationResult: "banned" },
  );
});

Deno.test("rejectBannedReview rejects banned submissions before persistence", () => {
  assertThrows(
    () => rejectBannedReview({ status: "blocked", moderationResult: "banned" }),
    Error,
    "Review contains prohibited content.",
  );
});

Deno.test("summarizePublishedReviews computes per-star counts", () => {
  const result = summarizePublishedReviews([
    { rating: 5, status: "published", updated_at: "2026-07-11T10:00:00Z" },
    { rating: 4, status: "published", updated_at: "2026-07-11T11:00:00Z" },
    { rating: 4, status: "published", updated_at: "2026-07-11T12:00:00Z" },
    { rating: 1, status: "blocked", updated_at: "2026-07-11T12:30:00Z" },
  ]);

  assertEquals(result.review_count, 3);
  assertEquals(result.rating_5_count, 1);
  assertEquals(result.rating_4_count, 2);
  assertEquals(result.rating_1_count, 0);
  assertEquals(result.average_rating, 4.33);
});
