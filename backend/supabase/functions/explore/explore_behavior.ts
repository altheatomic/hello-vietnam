export type InterestStateSnapshot = {
  initialWeight: number;
  behaviorScore: number;
  positiveBehaviorCount: number;
  negativeBehaviorCount: number;
  behaviorCount: number;
  source: string | null;
};

export type InterestStateUpdate = InterestStateSnapshot & {
  behaviorWeight: number;
  finalWeight: number;
};

export const USER_INTEREST_SCORE_CAP = 10;

export const EVENT_SCORES = {
  view_detail: 1,
  share: 2,
  favorite: 3,
  add_to_trip: 4,
  skip: -1,
  unfavorite: -3,
  remove_from_trip: -4,
} as const;

export function computeInterestStateUpdate(
  current: InterestStateSnapshot,
  eventScore: number,
  factor: number,
): InterestStateUpdate {
  const delta = eventScore * factor;
  const behaviorScore = current.behaviorScore + delta;
  const positiveBehaviorCount =
    current.positiveBehaviorCount + (delta > 0 ? 1 : 0);
  const negativeBehaviorCount =
    current.negativeBehaviorCount + (delta < 0 ? 1 : 0);
  const behaviorCount = current.behaviorCount + 1;
  const behaviorWeight = clampNumber(
    behaviorScore / USER_INTEREST_SCORE_CAP,
    0,
    1,
  );
  const finalWeight = clampNumber(
    behaviorCount <= 0
      ? current.initialWeight
      : (0.4 * current.initialWeight) + (0.6 * behaviorWeight),
    0,
    1,
  );

  return {
    initialWeight: current.initialWeight,
    behaviorScore,
    behaviorWeight,
    finalWeight,
    positiveBehaviorCount,
    negativeBehaviorCount,
    behaviorCount,
    source: deriveInterestSource(current.source, current.initialWeight),
  };
}

function deriveInterestSource(
  currentSource: string | null,
  initialWeight: number,
): string {
  if (!currentSource) {
    return initialWeight > 0 ? "mixed" : "behavior";
  }
  if (currentSource === "behavior" || currentSource === "mixed") {
    return currentSource;
  }
  return initialWeight > 0 ? "mixed" : currentSource;
}

function clampNumber(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}
