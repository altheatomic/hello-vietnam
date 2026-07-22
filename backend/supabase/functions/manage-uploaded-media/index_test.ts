import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  createManageUploadedMediaHandler,
  type ManageUploadedMediaDependencies,
  type OwnedForumMedia,
} from "./index.ts";

const ownerId = "owner-user";
const otherUserId = "other-user";
const publicBaseUrl = "https://media.example.test";

type FakeState = {
  authUserId: string | null;
  media: OwnedForumMedia[];
  deletedKeys: string[];
  deletedMediaIds: string[];
  events: string[];
  r2Statuses: Map<string, number>;
};

function createState(overrides: Partial<FakeState> = {}): FakeState {
  return {
    authUserId: ownerId,
    media: [],
    deletedKeys: [],
    deletedMediaIds: [],
    events: [],
    r2Statuses: new Map(),
    ...overrides,
  };
}

function forumMedia(
  idMedia: string,
  authorId: string,
  url = `${publicBaseUrl}/forum/${idMedia}.jpg`,
): OwnedForumMedia {
  return {
    id_media: idMedia,
    id_post: `post-${idMedia}`,
    url,
    created_at: "2026-07-22T00:00:00.000Z",
    post_has_text: true,
    author_id: authorId,
  };
}

function createDependencies(state: FakeState): ManageUploadedMediaDependencies {
  return {
    publicBaseUrl,
    supabase: {
      async getUser(authorization) {
        if (authorization !== "Bearer valid-token" || !state.authUserId) {
          return null;
        }
        return { id: state.authUserId };
      },
      async listOwnedForumMedia(userId) {
        return state.media.filter((media) => media.author_id === userId);
      },
      async findOwnedForumMedia(userId, mediaId) {
        return state.media.find(
          (media) => media.id_media === mediaId && media.author_id === userId,
        ) ?? null;
      },
      async deleteOwnedForumMedia(userId, mediaId) {
        const index = state.media.findIndex(
          (media) => media.id_media === mediaId && media.author_id === userId,
        );
        if (index < 0) return false;
        state.media.splice(index, 1);
        state.events.push(`db:${mediaId}`);
        state.deletedMediaIds.push(mediaId);
        return true;
      },
    },
    r2: {
      async deleteObject(key) {
        state.deletedKeys.push(key);
        state.events.push(`r2:${key}`);
        return state.r2Statuses.get(key) ?? 204;
      },
    },
  };
}

function request(body: unknown, token = "Bearer valid-token"): Request {
  return new Request("http://localhost/manage-uploaded-media", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      authorization: token,
    },
    body: JSON.stringify(body),
  });
}

async function json(response: Response): Promise<Record<string, unknown>> {
  return await response.json() as Record<string, unknown>;
}

Deno.test("rejects missing or invalid authentication with 401", async () => {
  const state = createState();
  const handler = createManageUploadedMediaHandler(createDependencies(state));

  const missing = await handler(request({ action: "list" }, ""));
  const invalid = await handler(request({ action: "list" }, "Bearer invalid-token"));

  assertEquals(missing.status, 401);
  assertEquals(invalid.status, 401);
});

Deno.test("lists only forum media owned by the authenticated user", async () => {
  const owned = forumMedia("owned-media", ownerId);
  const other = forumMedia("other-media", otherUserId);
  const state = createState({ media: [owned, other] });
  const handler = createManageUploadedMediaHandler(createDependencies(state));

  const response = await handler(request({ action: "list" }));
  const body = await json(response);

  assertEquals(response.status, 200);
  assertEquals(body.items, [{
    id_media: owned.id_media,
    source: "forum",
    url: owned.url,
    created_at: owned.created_at,
    id_post: owned.id_post,
    post_has_text: true,
  }]);
});

Deno.test("reports another user's media id as not_found without R2 or DB deletion", async () => {
  const other = forumMedia("other-media", otherUserId);
  const state = createState({ media: [other] });
  const handler = createManageUploadedMediaHandler(createDependencies(state));

  const response = await handler(request({ action: "delete", mediaIds: [other.id_media] }));
  const body = await json(response);

  assertEquals(response.status, 200);
  assertEquals(body.results, [{ mediaId: other.id_media, status: "not_found" }]);
  assertEquals(state.deletedKeys, []);
  assertEquals(state.deletedMediaIds, []);
});

Deno.test("deletes the owned R2 object before removing its database relation", async () => {
  const owned = forumMedia("owned-media", ownerId);
  const state = createState({ media: [owned] });
  const handler = createManageUploadedMediaHandler(createDependencies(state));

  const response = await handler(request({ action: "delete", mediaIds: [owned.id_media] }));
  const body = await json(response);

  assertEquals(response.status, 200);
  assertEquals(body.results, [{ mediaId: owned.id_media, status: "deleted" }]);
  assertEquals(state.deletedKeys, ["forum/owned-media.jpg"]);
  assertEquals(state.deletedMediaIds, [owned.id_media]);
  assertEquals(state.media, []);
  assertEquals(state.events, ["r2:forum/owned-media.jpg", "db:owned-media"]);
});

Deno.test("retains the database relation when R2 cleanup fails so deletion can retry", async () => {
  const owned = forumMedia("owned-media", ownerId);
  const state = createState({
    media: [owned],
    r2Statuses: new Map([["forum/owned-media.jpg", 500]]),
  });
  const handler = createManageUploadedMediaHandler(createDependencies(state));

  const response = await handler(request({ action: "delete", mediaIds: [owned.id_media] }));
  const body = await json(response);

  assertEquals(response.status, 200);
  const result = (body.results as Array<Record<string, unknown>>)[0];
  assertEquals(result.mediaId, owned.id_media);
  assertEquals(result.status, "failed");
  assertExists(result.message);
  assertEquals(state.deletedMediaIds, []);
  assertEquals(state.media, [owned]);
});

Deno.test("treats an already deleted R2 object as successful cleanup", async () => {
  const owned = forumMedia("owned-media", ownerId);
  const state = createState({
    media: [owned],
    r2Statuses: new Map([["forum/owned-media.jpg", 404]]),
  });
  const handler = createManageUploadedMediaHandler(createDependencies(state));

  const response = await handler(request({ action: "delete", mediaIds: [owned.id_media] }));
  const body = await json(response);

  assertEquals(response.status, 200);
  assertEquals(body.results, [{ mediaId: owned.id_media, status: "deleted" }]);
  assertEquals(state.deletedMediaIds, [owned.id_media]);
});

Deno.test("rejects malformed requests with 400", async () => {
  const state = createState();
  const handler = createManageUploadedMediaHandler(createDependencies(state));

  const missingAction = await handler(request({}));
  const invalidDelete = await handler(request({ action: "delete", mediaIds: [] }));

  assertEquals(missingAction.status, 400);
  assertEquals(invalidDelete.status, 400);
});

Deno.test("continues with remaining ids when one lookup fails", async () => {
  const first = forumMedia("lookup-fails", ownerId);
  const second = forumMedia("deletes", ownerId);
  const state = createState({ media: [first, second] });
  const dependencies = createDependencies(state);
  const originalFind = dependencies.supabase.findOwnedForumMedia;
  dependencies.supabase.findOwnedForumMedia = async (userId, mediaId) => {
    if (mediaId === first.id_media) throw new Error("lookup failed");
    return await originalFind(userId, mediaId);
  };
  const handler = createManageUploadedMediaHandler(dependencies);

  const response = await handler(
    request({ action: "delete", mediaIds: [first.id_media, second.id_media] }),
  );
  const body = await json(response);

  assertEquals(response.status, 200);
  assertEquals(body.results, [
    {
      mediaId: first.id_media,
      status: "failed",
      message: "Unable to load media item.",
    },
    { mediaId: second.id_media, status: "deleted" },
  ]);
  assertEquals(state.deletedMediaIds, [second.id_media]);
});

Deno.test("rejects traversal and cross-origin media URLs before R2 deletion", async () => {
  const traversal = forumMedia(
    "traversal",
    ownerId,
    `${publicBaseUrl}/forum/../other-owner.jpg`,
  );
  const crossOrigin = forumMedia(
    "cross-origin",
    ownerId,
    "https://other.example.test/forum/cross-origin.jpg",
  );
  const state = createState({ media: [traversal, crossOrigin] });
  const handler = createManageUploadedMediaHandler(createDependencies(state));

  const response = await handler(
    request({
      action: "delete",
      mediaIds: [traversal.id_media, crossOrigin.id_media],
    }),
  );
  const body = await json(response);

  assertEquals(response.status, 200);
  assertEquals(body.results, [
    {
      mediaId: traversal.id_media,
      status: "failed",
      message: "Media URL is not managed by configured storage.",
    },
    {
      mediaId: crossOrigin.id_media,
      status: "failed",
      message: "Media URL is not managed by configured storage.",
    },
  ]);
  assertEquals(state.deletedKeys, []);
  assertEquals(state.deletedMediaIds, []);
});
