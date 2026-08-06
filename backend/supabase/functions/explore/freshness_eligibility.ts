export type FreshnessEligibility = {
  listable: boolean;
  plannerEligible: boolean;
  warning: "stale" | "needs_review" | "expired" | null;
  freshnessStatus: "fresh" | "due" | "stale" | "needs_review" | "expired" | null;
  lastVerifiedAt: string | null;
};

export function resolveFreshnessEligibility(
  row: Record<string, unknown> | null | undefined,
): FreshnessEligibility {
  const rawStatus = typeof row?.freshness_status === "string"
    ? row.freshness_status.trim().toLowerCase()
    : null;
  const status = rawStatus === "fresh" || rawStatus === "due" || rawStatus === "stale" ||
      rawStatus === "needs_review" || rawStatus === "expired"
    ? rawStatus
    : null;
  const blocked = status === "needs_review" || status === "expired";
  return {
    listable: !blocked,
    plannerEligible: !blocked,
    warning: status === "stale" || status === "needs_review" || status === "expired"
      ? status
      : null,
    freshnessStatus: status,
    lastVerifiedAt: typeof row?.last_verified_at === "string"
      ? row.last_verified_at
      : null,
  };
}

export function freshnessWarningText(
  warning: FreshnessEligibility["warning"],
): string | null {
  switch (warning) {
    case "stale":
      return "Thông tin chưa được xác minh gần đây";
    case "needs_review":
      return "Địa điểm đang được kiểm tra lại";
    case "expired":
      return "Nội dung đã kết thúc";
    default:
      return null;
  }
}
