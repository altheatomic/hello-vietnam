export type ReviewContentType =
  | "activity"
  | "culture"
  | "food"
  | "local_product"
  | "place"
  | "province"
  | "old_province";

export type ContentRegistryEntry = {
  table: string;
  idColumn: string;
};

export const CONTENT_REGISTRY: Record<ReviewContentType, ContentRegistryEntry> = {
  activity: { table: "activity", idColumn: "id_activity" },
  culture: { table: "culture", idColumn: "id_culture" },
  food: { table: "food", idColumn: "id_food" },
  local_product: { table: "local_products", idColumn: "id_local_product" },
  place: { table: "place", idColumn: "id_place" },
  province: { table: "province", idColumn: "id_province" },
  old_province: { table: "old_province", idColumn: "id_province" },
};

export type ContentRef = {
  contentType: ReviewContentType;
  contentId: string;
};

export type UpsertReviewPayload = ContentRef & {
  rating: number;
  comment: string;
};

export type ReviewListPayload = ContentRef & {
  page: number;
  pageSize: number;
};

export type ModerationKeyword = {
  normalized_keyword: string;
  match_type: string;
  severity: string;
};

export type ModerationDecision = {
  status: "published" | "blocked";
  moderationResult: "clean" | "banned" | "suspected";
};

export type RatingSummaryRecord = {
  average_rating: number | null;
  review_count: number;
  rating_1_count: number;
  rating_2_count: number;
  rating_3_count: number;
  rating_4_count: number;
  rating_5_count: number;
  last_reviewed_at: string | null;
};

export function normalizeReviewText(value: string): string {
  return value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

export function evaluateModeration(
  comment: string,
  keywords: ModerationKeyword[],
): ModerationDecision {
  const normalizedComment = normalizeReviewText(comment);
  let hasSuspectedMatch = false;

  for (const keyword of keywords) {
    if (!matchesKeyword(normalizedComment, keyword)) continue;
    if (keyword.severity === "banned") {
      return { status: "blocked", moderationResult: "banned" };
    }
    if (keyword.severity === "suspected") hasSuspectedMatch = true;
  }

  return hasSuspectedMatch
    ? { status: "published", moderationResult: "suspected" }
    : { status: "published", moderationResult: "clean" };
}

export function summarizePublishedReviews(
  rows: Array<{ rating: number; status: string; updated_at: string | null }>,
): RatingSummaryRecord {
  const counts = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 } as Record<number, number>;
  let total = 0;
  let reviewCount = 0;
  let lastReviewedAt: string | null = null;

  for (const row of rows) {
    if (row.status !== "published" || !Number.isInteger(row.rating) || row.rating < 1 || row.rating > 5) continue;
    counts[row.rating] += 1;
    total += row.rating;
    reviewCount += 1;
    if (row.updated_at && (!lastReviewedAt || row.updated_at > lastReviewedAt)) {
      lastReviewedAt = row.updated_at;
    }
  }

  return {
    average_rating: reviewCount > 0 ? Number((total / reviewCount).toFixed(2)) : null,
    review_count: reviewCount,
    rating_1_count: counts[1],
    rating_2_count: counts[2],
    rating_3_count: counts[3],
    rating_4_count: counts[4],
    rating_5_count: counts[5],
    last_reviewed_at: lastReviewedAt,
  };
}

function matchesKeyword(comment: string, keyword: ModerationKeyword): boolean {
  const pattern = normalizeReviewText(keyword.normalized_keyword);
  if (!pattern) return false;
  if (keyword.match_type === "exact") return comment === pattern;
  if (keyword.match_type === "contains") return comment.includes(pattern);
  if (keyword.match_type === "regex") {
    try {
      return new RegExp(pattern, "u").test(comment);
    } catch {
      return false;
    }
  }
  return false;
}
