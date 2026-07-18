export type ExploreRatingInput = {
  storedRating: number | null;
  storedReviewCount: number | null;
  officialAverageRating: number | null;
  officialReviewCount: number;
};

export type ResolvedExploreRating = {
  rating: number | null;
  reviewCount: number;
  usesOfficialReviews: boolean;
};

export function resolveExploreRating(
  input: ExploreRatingInput,
): ResolvedExploreRating {
  const hasOfficialReviews = input.officialReviewCount > 0 &&
    input.officialAverageRating != null &&
    Number.isFinite(input.officialAverageRating);

  if (hasOfficialReviews) {
    return {
      rating: input.officialAverageRating,
      reviewCount: input.officialReviewCount,
      usesOfficialReviews: true,
    };
  }

  return {
    rating: input.storedRating,
    reviewCount: input.storedReviewCount ?? 0,
    usesOfficialReviews: false,
  };
}
