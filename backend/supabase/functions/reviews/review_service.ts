import type { SupabaseClient } from "@supabase/supabase-js";

import { evaluateModeration } from "./review_types.ts";
import {
  CONTENT_REGISTRY,
  type ContentRef,
  type ModerationDecision,
  type ModerationKeyword,
  type RatingSummaryRecord,
  type ReviewListPayload,
  type UpsertReviewPayload,
} from "./review_types.ts";

type ReviewRow = {
  id_review: string;
  rating: number;
  comment: string;
  status: string;
  moderation_result: string;
  created_at: string;
  updated_at: string;
  user_account?: ReviewUserRow | ReviewUserRow[] | null;
};

type ReviewUserRow = {
  full_name?: string | null;
  username?: string | null;
};

const REVIEW_SELECT =
  "id_review, rating, comment, status, moderation_result, created_at, updated_at, user_account(full_name, username)";

export class ReviewService {
  constructor(private readonly client: SupabaseClient) {}

  async getReviewSummary(payload: ContentRef): Promise<RatingSummaryRecord> {
    const { data, error } = await this.client
      .from("rating_summary")
      .select(
        "average_rating, review_count, rating_1_count, rating_2_count, rating_3_count, rating_4_count, rating_5_count, last_reviewed_at",
      )
      .eq("content_type", payload.contentType)
      .eq("content_id", payload.contentId)
      .maybeSingle();
    if (error) throw new Error(`rating_summary: ${error.message}`);
    return data ?? emptySummary();
  }

  async getReviews(
    payload: ReviewListPayload,
  ): Promise<Record<string, unknown>> {
    const from = (payload.page - 1) * payload.pageSize;
    const to = from + payload.pageSize;
    let query = this.client
      .from("reviews")
      .select(REVIEW_SELECT)
      .eq("content_type", payload.contentType)
      .eq("content_id", payload.contentId)
      .eq("status", "published");
    if (payload.ratingFilter !== undefined) {
      query = query.eq("rating", payload.ratingFilter);
    }
    const { data, error } = await query
      .order("updated_at", { ascending: false })
      .range(from, to);
    if (error) throw new Error(`reviews: ${error.message}`);
    const fetchedRows = data ?? [];
    const hasMore = fetchedRows.length > payload.pageSize;
    const visibleRows = hasMore
      ? fetchedRows.slice(0, payload.pageSize)
      : fetchedRows;
    const totalCount = from + visibleRows.length + (hasMore ? 1 : 0);
    return {
      items: visibleRows.map(mapReviewRow),
      page: payload.page,
      pageSize: payload.pageSize,
      totalCount,
      hasMore,
    };
  }

  async getMyReview(
    userId: string,
    payload: ContentRef,
  ): Promise<Record<string, unknown> | null> {
    const { data, error } = await this.client
      .from("reviews")
      .select(REVIEW_SELECT)
      .eq("id_user", userId)
      .eq("content_type", payload.contentType)
      .eq("content_id", payload.contentId)
      .maybeSingle();
    if (error) throw new Error(`reviews: ${error.message}`);
    return data ? mapReviewRow(data) : null;
  }

  async upsertReview(
    userId: string,
    payload: UpsertReviewPayload,
  ): Promise<Record<string, unknown>> {
    await this.assertContentExists(payload);
    const decision = evaluateModeration(
      payload.comment,
      await this.getActiveKeywords(),
    );
    rejectBannedReview(decision);
    const { data, error } = await this.client
      .from("reviews")
      .upsert({
        id_user: userId,
        content_type: payload.contentType,
        content_id: payload.contentId,
        rating: payload.rating,
        comment: payload.comment,
        status: decision.status,
        moderation_result: decision.moderationResult,
      } as never, { onConflict: "id_user,content_type,content_id" })
      .select(REVIEW_SELECT)
      .single();
    if (error) throw new Error(`reviews: ${error.message}`);
    const summary = await this.refreshRatingSummary(
      payload.contentType,
      payload.contentId,
    );
    return { review: mapReviewRow(data), summary };
  }

  async refreshRatingSummary(
    contentType: ContentRef["contentType"],
    contentId: string,
  ): Promise<RatingSummaryRecord> {
    const { data, error } = await this.client
      .rpc("refresh_rating_summary", {
        p_content_type: contentType,
        p_content_id: contentId,
      })
      .single();
    if (error) throw new Error(`refresh_rating_summary: ${error.message}`);
    if (!data) throw new Error("refresh_rating_summary returned no summary.");
    return data as RatingSummaryRecord;
  }

  private async assertContentExists(payload: ContentRef): Promise<void> {
    const entry = CONTENT_REGISTRY[payload.contentType];
    let sawMissingColumn = false;

    for (const idColumn of entry.idCandidates) {
      const { data, error } = await this.client
        .from(entry.table)
        .select(idColumn)
        .eq(idColumn, payload.contentId)
        .maybeSingle();

      if (!error) {
        if (data) return;
        continue;
      }

      if (isMissingColumnError(error.message, idColumn)) {
        sawMissingColumn = true;
        continue;
      }

      throw new Error(`${entry.table}: ${error.message}`);
    }

    if (sawMissingColumn) {
      throw new Error(`No compatible id column found for ${entry.table}.`);
    }
    throw new Error("Content not found.");
  }

  private async getActiveKeywords(): Promise<ModerationKeyword[]> {
    const { data, error } = await this.client
      .from("moderation_keyword")
      .select("keyword, normalized_keyword, match_type, severity")
      .eq("is_active", true);
    if (error) throw new Error(`moderation_keyword: ${error.message}`);
    return data ?? [];
  }
}

export class ReviewModerationError extends Error {
  constructor(message: string, readonly statusCode = 400) {
    super(message);
    this.name = "ReviewModerationError";
  }
}

export function rejectBannedReview(decision: ModerationDecision): void {
  if (decision.moderationResult === "banned") {
    throw new ReviewModerationError("Review contains prohibited content.");
  }
}

function mapReviewRow(row: ReviewRow): Record<string, unknown> {
  return {
    id: row.id_review,
    rating: row.rating,
    comment: row.comment,
    status: row.status,
    moderationResult: row.moderation_result,
    userName: reviewerName(row.user_account),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function reviewerName(value: ReviewRow["user_account"]): string | null {
  const account = Array.isArray(value) ? value[0] : value;
  const fullName = account?.full_name?.trim();
  if (fullName) return fullName;
  const username = account?.username?.trim();
  return username || null;
}

function emptySummary(): RatingSummaryRecord {
  return {
    average_rating: null,
    review_count: 0,
    rating_1_count: 0,
    rating_2_count: 0,
    rating_3_count: 0,
    rating_4_count: 0,
    rating_5_count: 0,
    last_reviewed_at: null,
  };
}

function isMissingColumnError(message: string, column: string): boolean {
  return message.includes(`column ${column} does not exist`);
}
