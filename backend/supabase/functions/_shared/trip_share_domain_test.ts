import {
  assertEquals,
  assertMatch,
  assertRejects,
  assertThrows,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  createShareToken,
  hashShareToken,
  parseExpiryDays,
  publicShareUrl,
} from "./trip_share_domain.ts";

Deno.test("createShareToken returns distinct URL-safe bearer tokens", () => {
  const first = createShareToken();
  const second = createShareToken();

  assertMatch(first, /^[A-Za-z0-9_-]{43}$/);
  assertMatch(second, /^[A-Za-z0-9_-]{43}$/);
  assertNotEquals(first, second);
});

Deno.test("hashShareToken returns a stable lowercase SHA-256 digest", async () => {
  const first = await hashShareToken("share-token");
  const second = await hashShareToken("share-token");

  assertEquals(first, second);
  assertMatch(first, /^[a-f0-9]{64}$/);
});

Deno.test("hashShareToken rejects an empty token", async () => {
  await assertRejects(() => hashShareToken("  "), Error, "Invalid share token");
});

Deno.test("parseExpiryDays accepts only supported durations", () => {
  assertEquals(parseExpiryDays(undefined), 30);
  assertEquals(parseExpiryDays(7), 7);
  assertEquals(parseExpiryDays("30"), 30);
  assertEquals(parseExpiryDays(90), 90);
  assertThrows(() => parseExpiryDays(14), Error, "7, 30, or 90");
});

Deno.test("publicShareUrl normalizes the base URL and escapes the token", () => {
  assertEquals(
    publicShareUrl("https://share.example.test/", "abc_123-XYZ"),
    "https://share.example.test/trip/abc_123-XYZ",
  );
  assertThrows(
    () => publicShareUrl("http://share.example.test", "abc"),
    Error,
    "HTTPS",
  );
});
