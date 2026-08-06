import {
  assertEquals,
  assertMatch,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  handleTripShareRequest,
  type ShareLinkRecord,
  type TripShareGateway,
} from "./trip_share_handler.ts";

const ownerId = "11111111-1111-4111-8111-111111111111";
const planId = "22222222-2222-4222-8222-222222222222";

class FakeGateway implements TripShareGateway {
  owns = true;
  created: ShareLinkRecord | null = null;
  active: ShareLinkRecord | null = null;
  clonedPlanId = "33333333-3333-4333-8333-333333333333";

  ownsPlan(_userId: string, _planId: string): Promise<boolean> {
    return Promise.resolve(this.owns);
  }

  async createLink(input: ShareLinkRecord): Promise<ShareLinkRecord> {
    this.created = input;
    this.active = input;
    return input;
  }

  listLinks(_userId: string, _planId?: string): Promise<ShareLinkRecord[]> {
    return Promise.resolve(this.created == null ? [] : [this.created]);
  }

  revokeLink(_userId: string, _shareId: string): Promise<boolean> {
    return Promise.resolve(true);
  }

  findLinkByHash(_tokenHash: string): Promise<ShareLinkRecord | null> {
    return Promise.resolve(this.active);
  }

  getPlan(_planId: string, _ownerUserId: string): Promise<Record<string, unknown>> {
    return Promise.resolve({
      id_plan: planId,
      internal_user_id: ownerId,
      days: [{
        day: 1,
        date: "2026-08-10",
        places: [{
          id_place: "private-place-id",
          name: "Hoan Kiem Lake",
          latitude: 21.0287,
          longitude: 105.8522,
          final_score: 0.98,
          gallery: [{ url: "https://img.test/lake.jpg", type: "cover", secret: "x" }],
        }],
      }],
    });
  }

  recordView(_shareId: string): Promise<void> {
    return Promise.resolve();
  }

  clonePlan(_planId: string, _userId: string): Promise<string> {
    return Promise.resolve(this.clonedPlanId);
  }
}

const authenticate = (_request: Request) => Promise.resolve(ownerId);
const options = {
  shareWebBaseUrl: "https://share.example.test",
  allowedOrigins: new Set(["https://share.example.test"]),
  now: () => new Date("2026-08-01T00:00:00Z"),
};

Deno.test("create stores only a token hash and returns the bearer URL once", async () => {
  const gateway = new FakeGateway();
  const response = await handleTripShareRequest(
    new Request("https://edge.test/trip-share", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ action: "create", idPlan: planId, expiryDays: 30 }),
    }),
    gateway,
    authenticate,
    options,
  );
  const body = await response.json();

  assertEquals(response.status, 201);
  assertMatch(body.url, /^https:\/\/share\.example\.test\/trip\/[A-Za-z0-9_-]{43}$/);
  assertMatch(gateway.created!.tokenHash, /^[a-f0-9]{64}$/);
  assertNotEquals(body.url.split("/").at(-1), gateway.created!.tokenHash);
});

Deno.test("public view returns a whitelisted DTO without plan or score identifiers", async () => {
  const gateway = new FakeGateway();
  gateway.active = {
    idShare: "share-1",
    idPlan: planId,
    ownerUserId: ownerId,
    tokenHash: "a".repeat(64),
    tokenPrefix: "prefix12",
    title: "Hanoi weekend",
    allowCopy: true,
    expiresAt: "2026-08-31T00:00:00Z",
    revokedAt: null,
    createdAt: "2026-08-01T00:00:00Z",
  };

  const response = await handleTripShareRequest(
    new Request("https://edge.test/trip-share/public/token", {
      headers: { origin: "https://share.example.test" },
    }),
    gateway,
    authenticate,
    options,
  );
  const body = await response.json();
  const serialized = JSON.stringify(body);

  assertEquals(response.status, 200);
  assertEquals(body.title, "Hanoi weekend");
  assertEquals(body.n_days, 1);
  assertEquals(body.days[0].places[0].name, "Hoan Kiem Lake");
  assertEquals(serialized.includes("id_plan"), false);
  assertEquals(serialized.includes("id_place"), false);
  assertEquals(serialized.includes("final_score"), false);
  assertEquals(serialized.includes("secret"), false);
  assertEquals(response.headers.get("cache-control"), "no-store");
});

Deno.test("expired, revoked and unknown tokens use the same public 404", async () => {
  for (const active of [
    null,
    {
      idShare: "expired",
      idPlan: planId,
      ownerUserId: ownerId,
      tokenHash: "a".repeat(64),
      tokenPrefix: "expired1",
      title: null,
      allowCopy: true,
      expiresAt: "2026-07-31T23:59:59Z",
      revokedAt: null,
      createdAt: "2026-07-01T00:00:00Z",
    },
    {
      idShare: "revoked",
      idPlan: planId,
      ownerUserId: ownerId,
      tokenHash: "b".repeat(64),
      tokenPrefix: "revoked1",
      title: null,
      allowCopy: true,
      expiresAt: "2026-08-31T00:00:00Z",
      revokedAt: "2026-08-01T00:00:00Z",
      createdAt: "2026-07-01T00:00:00Z",
    },
  ] as Array<ShareLinkRecord | null>) {
    const gateway = new FakeGateway();
    gateway.active = active;
    const response = await handleTripShareRequest(
      new Request("https://edge.test/trip-share/public/token"),
      gateway,
      authenticate,
      options,
    );
    assertEquals(response.status, 404);
    assertEquals(await response.json(), { error: "Shared trip is unavailable." });
  }
});

Deno.test("copy rejects a valid view-only link", async () => {
  const gateway = new FakeGateway();
  gateway.active = {
    idShare: "share-1",
    idPlan: planId,
    ownerUserId: ownerId,
    tokenHash: "a".repeat(64),
    tokenPrefix: "prefix12",
    title: null,
    allowCopy: false,
    expiresAt: "2026-08-31T00:00:00Z",
    revokedAt: null,
    createdAt: "2026-08-01T00:00:00Z",
  };

  const response = await handleTripShareRequest(
    new Request("https://edge.test/trip-share", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ action: "copy", token: "token" }),
    }),
    gateway,
    authenticate,
    options,
  );

  assertEquals(response.status, 403);
  assertEquals(await response.json(), { error: "Copying is disabled for this link." });
});

Deno.test("public upstream failures stay JSON with CORS headers", async () => {
  const gateway = new FakeGateway();
  gateway.active = {
    idShare: "share-1",
    idPlan: planId,
    ownerUserId: ownerId,
    tokenHash: "a".repeat(64),
    tokenPrefix: "prefix12",
    title: null,
    allowCopy: true,
    expiresAt: "2026-08-31T00:00:00Z",
    revokedAt: null,
    createdAt: "2026-08-01T00:00:00Z",
  };
  gateway.getPlan = () => Promise.reject(new Error("upstream offline"));

  const response = await handleTripShareRequest(
    new Request("https://edge.test/trip-share/public/token", {
      headers: { origin: "https://share.example.test" },
    }),
    gateway,
    authenticate,
    options,
  );

  assertEquals(response.status, 503);
  assertEquals(response.headers.get("access-control-allow-origin"), "https://share.example.test");
  assertEquals(await response.json(), { error: "Shared trip is temporarily unavailable." });
});
