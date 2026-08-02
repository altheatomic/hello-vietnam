import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { isRawCloneAllowed } from "./trip_clone_authorization.ts";

Deno.test("raw clone is allowed for the plan owner", () => {
  assertEquals(
    isRawCloneAllowed({
      requestingUserId: "owner",
      ownerUserId: "owner",
      hasActiveForumShare: false,
    }),
    true,
  );
});

Deno.test("raw clone is allowed for an active internal forum share", () => {
  assertEquals(
    isRawCloneAllowed({
      requestingUserId: "recipient",
      ownerUserId: "owner",
      hasActiveForumShare: true,
    }),
    true,
  );
});

Deno.test("raw clone rejects an unrelated plan UUID", () => {
  assertEquals(
    isRawCloneAllowed({
      requestingUserId: "recipient",
      ownerUserId: "owner",
      hasActiveForumShare: false,
    }),
    false,
  );
});
