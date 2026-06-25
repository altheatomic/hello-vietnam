import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  computeInterestStateUpdate,
  EVENT_SCORES,
} from "./explore_behavior.ts";

Deno.test("computeInterestStateUpdate applies positive favorite delta", () => {
  const next = computeInterestStateUpdate(
    {
      initialWeight: 0.4,
      behaviorScore: 0,
      positiveBehaviorCount: 0,
      negativeBehaviorCount: 0,
      behaviorCount: 0,
      source: "initial",
    },
    EVENT_SCORES.favorite,
    1,
  );

  assertEquals(next.behaviorScore, 3);
  assertEquals(next.behaviorWeight, 0.3);
  assertEquals(next.finalWeight, 0.34);
  assertEquals(next.positiveBehaviorCount, 1);
  assertEquals(next.negativeBehaviorCount, 0);
  assertEquals(next.behaviorCount, 1);
  assertEquals(next.source, "mixed");
});

Deno.test("computeInterestStateUpdate applies negative unfavorite delta", () => {
  const afterFavorite = computeInterestStateUpdate(
    {
      initialWeight: 0.4,
      behaviorScore: 0,
      positiveBehaviorCount: 0,
      negativeBehaviorCount: 0,
      behaviorCount: 0,
      source: "initial",
    },
    EVENT_SCORES.favorite,
    1,
  );

  const afterUnfavorite = computeInterestStateUpdate(afterFavorite, EVENT_SCORES.unfavorite, 1);

  assertEquals(afterUnfavorite.behaviorScore, 0);
  assertEquals(afterUnfavorite.behaviorWeight, 0);
  assertEquals(afterUnfavorite.finalWeight, 0.16);
  assertEquals(afterUnfavorite.positiveBehaviorCount, 1);
  assertEquals(afterUnfavorite.negativeBehaviorCount, 1);
  assertEquals(afterUnfavorite.behaviorCount, 2);
  assertEquals(afterUnfavorite.source, "mixed");
});

Deno.test("computeInterestStateUpdate clamps behavior score into weight range", () => {
  const next = computeInterestStateUpdate(
    {
      initialWeight: 0,
      behaviorScore: 9,
      positiveBehaviorCount: 3,
      negativeBehaviorCount: 0,
      behaviorCount: 3,
      source: "behavior",
    },
    EVENT_SCORES.add_to_trip,
    1,
  );

  assertEquals(next.behaviorScore, 13);
  assertEquals(next.behaviorWeight, 1);
  assertEquals(next.finalWeight, 0.6);
  assertEquals(next.positiveBehaviorCount, 4);
  assertEquals(next.behaviorCount, 4);
});
