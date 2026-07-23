import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  clearFirebaseAccessTokenCacheForTests,
  isPermanentTokenError,
  sendFcmMessage,
} from "./firebase_messaging.ts";

const credentials = {
  projectId: "hello-vietnam",
  clientEmail: "firebase@example.test",
  privateKey: "unused-by-injected-signer",
};

Deno.test("sendFcmMessage posts an Android high-priority HTTP v1 message", async () => {
  clearFirebaseAccessTokenCacheForTests();
  const calls: Array<{ url: string; init: RequestInit }> = [];

  const result = await sendFcmMessage(
    {
      token: "device-token",
      title: "New reply",
      body: "Someone replied to your post",
      data: {
        id_notification: "notification-id",
        notification_type: "forum",
      },
      credentials,
    },
    {
      now: () => 1_700_000_000_000,
      signJwt: async () => "signed-jwt",
      fetch: async (input, init) => {
        calls.push({ url: String(input), init: init ?? {} });
        if (String(input).includes("oauth2.googleapis.com")) {
          return Response.json({ access_token: "oauth-token", expires_in: 3600 });
        }
        return Response.json(
          { name: "projects/hello-vietnam/messages/1" },
          { status: 200 },
        );
      },
    },
  );

  assertEquals(result.ok, true);
  assertEquals(calls.length, 2);
  assertEquals(
    calls[1].url,
    "https://fcm.googleapis.com/v1/projects/hello-vietnam/messages:send",
  );
  const request = JSON.parse(String(calls[1].init.body));
  assertEquals(request.message.android.priority, "HIGH");
  assertEquals(request.message.android.notification.channel_id, "hello_vietnam_updates");
  assertEquals(calls[1].init.headers, {
    authorization: "Bearer oauth-token",
    "content-type": "application/json",
  });
});

Deno.test("sendFcmMessage reuses an unexpired OAuth token", async () => {
  clearFirebaseAccessTokenCacheForTests();
  let oauthCalls = 0;
  const fetcher: typeof fetch = async (input) => {
    if (String(input).includes("oauth2.googleapis.com")) {
      oauthCalls += 1;
      return Response.json({ access_token: "cached-token", expires_in: 3600 });
    }
    return Response.json({ name: "message-id" });
  };
  const input = {
    token: "token",
    title: "Title",
    body: "Body",
    data: {},
    credentials,
  };

  await sendFcmMessage(input, {
    fetch: fetcher,
    now: () => 1_700_000_000_000,
    signJwt: async () => "jwt",
  });
  await sendFcmMessage(input, {
    fetch: fetcher,
    now: () => 1_700_000_030_000,
    signJwt: async () => "jwt",
  });

  assertEquals(oauthCalls, 1);
});

Deno.test("sendFcmMessage normalizes an unregistered token response", async () => {
  clearFirebaseAccessTokenCacheForTests();
  const result = await sendFcmMessage(
    {
      token: "expired-token",
      title: "Title",
      body: "Body",
      data: {},
      credentials,
    },
    {
      now: () => 1_700_000_000_000,
      signJwt: async () => "jwt",
      fetch: async (input) => {
        if (String(input).includes("oauth2.googleapis.com")) {
          return Response.json({ access_token: "oauth-token", expires_in: 3600 });
        }
        return Response.json(
          {
            error: {
              status: "NOT_FOUND",
              message: "Requested entity was not found.",
              details: [{ errorCode: "UNREGISTERED" }],
            },
          },
          { status: 404 },
        );
      },
    },
  );

  assertEquals(result.ok, false);
  assertEquals(result.code, "UNREGISTERED");
  assertEquals(isPermanentTokenError(result), true);
});

Deno.test("sendFcmMessage rejects failed OAuth exchange", async () => {
  clearFirebaseAccessTokenCacheForTests();
  await assertRejects(
    () =>
      sendFcmMessage(
        {
          token: "token",
          title: "Title",
          body: "Body",
          data: {},
          credentials,
        },
        {
          now: () => 1_700_000_000_000,
          signJwt: async () => "jwt",
          fetch: async () =>
            Response.json(
              { error: "invalid_grant", error_description: "invalid key" },
              { status: 400 },
            ),
        },
      ),
    Error,
    "FIREBASE_OAUTH_FAILED",
  );
});
