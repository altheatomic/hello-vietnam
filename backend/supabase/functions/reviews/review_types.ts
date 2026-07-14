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
  idCandidates: string[];
};

export const CONTENT_REGISTRY: Record<ReviewContentType, ContentRegistryEntry> =
  {
    activity: { table: "activity", idCandidates: ["id"] },
    culture: { table: "culture", idCandidates: ["id"] },
    food: { table: "food", idCandidates: ["id_food"] },
    local_product: { table: "local_products", idCandidates: ["id"] },
    place: { table: "place", idCandidates: ["id_place"] },
    province: { table: "province", idCandidates: ["id_province"] },
    old_province: { table: "old_province", idCandidates: ["id_province"] },
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
  ratingFilter?: number;
};

export type ModerationKeyword = {
  keyword?: string;
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
    if (!matchesKeyword(comment, normalizedComment, keyword)) continue;
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
    if (
      row.status !== "published" || !Number.isInteger(row.rating) ||
      row.rating < 1 || row.rating > 5
    ) continue;
    counts[row.rating] += 1;
    total += row.rating;
    reviewCount += 1;
    if (
      row.updated_at && (!lastReviewedAt || row.updated_at > lastReviewedAt)
    ) {
      lastReviewedAt = row.updated_at;
    }
  }

  return {
    average_rating: reviewCount > 0
      ? Number((total / reviewCount).toFixed(2))
      : null,
    review_count: reviewCount,
    rating_1_count: counts[1],
    rating_2_count: counts[2],
    rating_3_count: counts[3],
    rating_4_count: counts[4],
    rating_5_count: counts[5],
    last_reviewed_at: lastReviewedAt,
  };
}

function matchesKeyword(
  comment: string,
  normalizedComment: string,
  keyword: ModerationKeyword,
): boolean {
  if (keyword.match_type === "regex") {
    const pattern = keyword.keyword ?? keyword.normalized_keyword;
    if (!pattern) return false;
    try {
      return new RegExp(pattern, "u").test(comment);
    } catch {
      return false;
    }
  }
  const pattern = normalizeReviewText(keyword.normalized_keyword);
  if (!pattern) return false;
  if (keyword.match_type === "exact") return normalizedComment === pattern;
  if (keyword.match_type === "contains") {
    return normalizedComment.includes(pattern);
  }
  return false;
}
