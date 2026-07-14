import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { SupabaseClient } from "@supabase/supabase-js";

import { ReviewService } from "./review_service.ts";

const validContentId = "11111111-1111-4111-8111-111111111111";

Deno.test("getReviewSummary returns an empty summary when no summary row exists", async () => {
  const service = new ReviewService(
    createFakeClient({
      rating_summary: { maybeSingle: () => ({ data: null, error: null }) },
    }) as unknown as SupabaseClient,
  );

  const result = await service.getReviewSummary({
    contentType: "activity",
    contentId: validContentId,
  });

  assertEquals(result.review_count, 0);
  assertEquals(result.average_rating, null);
});

Deno.test("getReviews infers hasMore without requesting an exact count", async () => {
  const service = new ReviewService(
    createFakeClient({
      reviews: {
        range: () => ({
          data: [
            {
              id_review: "review-1",
              rating: 5,
              comment: "Should not be returned",
              status: "published",
              moderation_result: "clean",
              created_at: "2026-07-13T10:00:00Z",
              updated_at: "2026-07-13T10:00:00Z",
            },
            {
              id_review: "review-2",
              rating: 4,
              comment: "Second row",
              status: "published",
              moderation_result: "clean",
              created_at: "2026-07-13T10:05:00Z",
              updated_at: "2026-07-13T10:05:00Z",
            },
          ],
          error: null,
        }),
      },
    }) as unknown as SupabaseClient,
  );

  const result = await service.getReviews({
    contentType: "food",
    contentId: validContentId,
    page: 1,
    pageSize: 1,
  });

  assertEquals(result["hasMore"], true);
  assertEquals((result["items"] as unknown[]).length, 1);
  assertEquals(result["totalCount"], 2);
});

type FakeResponse = {
  data?: unknown;
  count?: number | null;
  error?: { message: string } | null;
};

type FakeTableHandlers = {
  maybeSingle?: () => FakeResponse;
  range?: () => FakeResponse;
};

function createFakeClient(
  tables: Record<string, FakeTableHandlers>,
): Record<string, unknown> {
  return {
    from(table: string) {
      const handlers = tables[table] ?? {};
      return createFakeQueryBuilder(handlers);
    },
  };
}

function createFakeQueryBuilder(handlers: FakeTableHandlers) {
  return {
    select(_columns: string, _options?: unknown) {
      return this;
    },
    eq(_column: string, _value: unknown) {
      return this;
    },
    order(_column: string, _options?: unknown) {
      return this;
    },
    range(_from: number, _to: number) {
      const response = handlers.range?.() ??
        { data: [], count: 0, error: null };
      return Promise.resolve(response);
    },
    maybeSingle() {
      const response = handlers.maybeSingle?.() ?? { data: null, error: null };
      return Promise.resolve(response);
    },
  };
}
