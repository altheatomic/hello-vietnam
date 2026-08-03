export type JsonObject = Record<string, unknown>;

export type FreshnessStatus =
  | "fresh"
  | "due"
  | "stale"
  | "needs_review"
  | "expired";

export type AvailabilityType =
  | "business"
  | "scheduled_event"
  | "evergreen"
  | "seasonal";

export type ContentType =
  | "place"
  | "activity"
  | "culture"
  | "food"
  | "local_product";

export type ContentFreshnessRow = {
  id: string;
  contentType: ContentType;
  contentId: string;
  sourceType: string;
  sourceUrl: string | null;
  sourceExternalId: string | null;
  availabilityType: AvailabilityType;
  validFrom?: string | null;
  validUntil: string | null;
  freshnessStatus: FreshnessStatus;
  lastCheckedAt?: string | null;
  lastVerifiedAt?: string | null;
  nextCheckAt?: string | null;
  sourceHash: string | null;
  consecutiveMissingCount: number;
  lastError?: string | null;
};

export type SourceResult =
  | { outcome: "found"; data: JsonObject; sourceHash: string }
  | { outcome: "missing" }
  | { outcome: "error"; error: string };

export type FreshnessDecision = {
  kind:
    | "unchanged"
    | "proposal"
    | "first_missing"
    | "second_missing"
    | "recovered"
    | "auto_expire"
    | "error";
  freshnessStatus: FreshnessStatus;
  consecutiveMissingCount: number;
  contentPatch: JsonObject;
  proposedData: JsonObject;
  changedFields: string[];
  reason: string;
  nextCheckAt: string;
  sourceHash?: string | null;
  lastError?: string | null;
};

export type FreshnessEvaluationInput = {
  freshness: ContentFreshnessRow;
  source: SourceResult;
  currentContent: JsonObject;
  now: Date;
};

export const SOURCE_OWNED_FIELDS = [
  "name",
  "address",
  "latitude",
  "longitude",
  "timespan",
  "timeclose",
  "phone",
  "website",
  "status",
] as const;

function sortJson(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortJson);
  if (value !== null && typeof value === "object") {
    const object = value as Record<string, unknown>;
    return Object.fromEntries(
      Object.keys(object)
        .sort()
        .map((key) => [key, sortJson(object[key])]),
    );
  }
  return value;
}

function equalJson(left: unknown, right: unknown): boolean {
  return JSON.stringify(sortJson(left)) === JSON.stringify(sortJson(right));
}

export async function stableSourceHash(data: unknown): Promise<string> {
  const encoded = new TextEncoder().encode(JSON.stringify(sortJson(data)));
  const digest = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

export function sourceOwnedPatch(
  before: JsonObject,
  proposed: JsonObject,
): JsonObject {
  const patch: JsonObject = {};
  for (const field of SOURCE_OWNED_FIELDS) {
    if (!Object.prototype.hasOwnProperty.call(proposed, field)) continue;
    if (!equalJson(before[field], proposed[field])) {
      patch[field] = proposed[field];
    }
  }
  return patch;
}

export function nextCheckAt(
  availabilityType: AvailabilityType,
  now: Date,
): string {
  const days = availabilityType === "scheduled_event"
    ? 1
    : availabilityType === "business"
    ? 7
    : availabilityType === "seasonal"
    ? 14
    : 30;
  return new Date(now.getTime() + days * 24 * 60 * 60 * 1000).toISOString();
}

export function evaluateFreshness({
  freshness,
  source,
  currentContent,
  now,
}: FreshnessEvaluationInput): FreshnessDecision {
  const next = nextCheckAt(freshness.availabilityType, now);
  const expiredEvent = freshness.availabilityType === "scheduled_event" &&
    Boolean(freshness.validUntil) &&
    Date.parse(freshness.validUntil as string) <= now.getTime();

  if (expiredEvent) {
    return {
      kind: "auto_expire",
      freshnessStatus: "expired",
      consecutiveMissingCount: 0,
      contentPatch: { status: "expired" },
      proposedData: { status: "expired" },
      changedFields: ["status"],
      reason: "scheduled_event_ended",
      nextCheckAt: next,
      sourceHash: source.outcome === "found" ? source.sourceHash : freshness.sourceHash,
    };
  }

  if (source.outcome === "error") {
    return {
      kind: "error",
      freshnessStatus: freshness.freshnessStatus,
      consecutiveMissingCount: freshness.consecutiveMissingCount,
      contentPatch: {},
      proposedData: {},
      changedFields: [],
      reason: "source_error",
      nextCheckAt: next,
      sourceHash: freshness.sourceHash,
      lastError: source.error,
    };
  }

  if (source.outcome === "missing") {
    const count = freshness.consecutiveMissingCount + 1;
    const needsReview = count >= 2;
    return {
      kind: needsReview ? "second_missing" : "first_missing",
      freshnessStatus: needsReview ? "needs_review" : "stale",
      consecutiveMissingCount: count,
      contentPatch: {},
      proposedData: needsReview ? { status: "archived" } : {},
      changedFields: needsReview ? ["status"] : [],
      reason: needsReview ? "possibly_closed" : "source_missing",
      nextCheckAt: next,
      sourceHash: freshness.sourceHash,
    };
  }

  const patch = sourceOwnedPatch(currentContent, source.data);
  const changedFields = Object.keys(patch).sort();
  const recovered = freshness.consecutiveMissingCount > 0;

  if (patch && changedFields.length > 0) {
    return {
      kind: "proposal",
      freshnessStatus: "needs_review",
      consecutiveMissingCount: 0,
      contentPatch: {},
      proposedData: patch,
      changedFields,
      reason: recovered ? "source_recovered_with_changes" : "source_changed",
      nextCheckAt: next,
      sourceHash: source.sourceHash,
    };
  }

  return {
    kind: recovered ? "recovered" : "unchanged",
    freshnessStatus: "fresh",
    consecutiveMissingCount: 0,
    contentPatch: {},
    proposedData: {},
    changedFields: [],
    reason: recovered ? "source_recovered" : "source_unchanged",
    nextCheckAt: next,
    sourceHash: source.sourceHash,
  };
}
