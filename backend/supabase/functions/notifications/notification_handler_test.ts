import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  defaultNotificationPreferences,
  handleNotificationRequest,
  type NotificationCursor,
  type NotificationGateway,
  type NotificationPage,
  type NotificationPreferenceRow,
  type RegisterDeviceInput,
  type UpdatePreferenceInput,
} from "./notification_handler.ts";

class FakeGateway implements NotificationGateway {
  registered: RegisterDeviceInput | null = null;
  unregistered: { userId: string; installationId: string } | null = null;
  listArgs: {
    userId: string;
    limit: number;
    cursor: NotificationCursor | null;
  } | null = null;
  markedRead: { userId: string; notificationId: string } | null = null;
  updatedPreference: UpdatePreferenceInput | null = null;
  preferences: NotificationPreferenceRow[] = [];

  async registerDevice(input: RegisterDeviceInput): Promise<void> {
    this.registered = input;
  }

  async unregisterDevice(
    userId: string,
    installationId: string,
  ): Promise<void> {
    this.unregistered = { userId, installationId };
  }

  async list(
    userId: string,
    limit: number,
    cursor: NotificationCursor | null,
  ): Promise<NotificationPage> {
    this.listArgs = { userId, limit, cursor };
    return { items: [], nextCursor: null };
  }

  unreadCount(_userId: string): Promise<number> {
    return Promise.resolve(3);
  }

  async markRead(userId: string, notificationId: string): Promise<boolean> {
    this.markedRead = { userId, notificationId };
    return true;
  }

  markAllRead(_userId: string): Promise<number> {
    return Promise.resolve(4);
  }

  getPreferences(_userId: string): Promise<NotificationPreferenceRow[]> {
    return Promise.resolve(this.preferences);
  }

  async updatePreference(
    input: UpdatePreferenceInput,
  ): Promise<NotificationPreferenceRow> {
    this.updatedPreference = input;
    return {
      id_user: input.userId,
      notification_type: input.notificationType,
      push_enabled: input.pushEnabled,
      in_app_enabled: input.inAppEnabled,
    };
  }
}

const userId = "11111111-1111-4111-8111-111111111111";

function request(body: Record<string, unknown>): Request {
  return new Request("https://example.test/notifications", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

Deno.test("register-device always uses the authenticated user id", async () => {
  const gateway = new FakeGateway();
  const response = await handleNotificationRequest({
    request: request({
      action: "register-device",
      id_user: "attacker-user",
      fcmToken: "device-token",
      installationId: "installation-1",
      platform: "android",
    }),
    userId,
    gateway,
  });

  assertEquals(response.status, 200);
  assertEquals(gateway.registered?.userId, userId);
  assertEquals(gateway.registered?.fcmToken, "device-token");
});

Deno.test("list clamps page size and parses a stable cursor", async () => {
  const gateway = new FakeGateway();
  const response = await handleNotificationRequest({
    request: request({
      action: "list",
      limit: 500,
      cursor:
        "2026-07-22T10:00:00.000Z|22222222-2222-4222-8222-222222222222",
    }),
    userId,
    gateway,
  });

  assertEquals(response.status, 200);
  assertEquals(gateway.listArgs, {
    userId,
    limit: 50,
    cursor: {
      createdAt: "2026-07-22T10:00:00.000Z",
      idNotification: "22222222-2222-4222-8222-222222222222",
    },
  });
});

Deno.test("list rejects malformed cursors", async () => {
  const response = await handleNotificationRequest({
    request: request({ action: "list", cursor: "not-a-cursor" }),
    userId,
    gateway: new FakeGateway(),
  });

  assertEquals(response.status, 400);
  assertEquals((await response.json()).error, "Invalid notification cursor.");
});

Deno.test("mark-read scopes the mutation to the authenticated user", async () => {
  const gateway = new FakeGateway();
  const response = await handleNotificationRequest({
    request: request({
      action: "mark-read",
      notificationId: "33333333-3333-4333-8333-333333333333",
      id_user: "attacker-user",
    }),
    userId,
    gateway,
  });

  assertEquals(response.status, 200);
  assertEquals(gateway.markedRead, {
    userId,
    notificationId: "33333333-3333-4333-8333-333333333333",
  });
});

Deno.test("get-preferences fills all six defaults", async () => {
  const gateway = new FakeGateway();
  gateway.preferences = [{
    id_user: userId,
    notification_type: "forum",
    push_enabled: false,
    in_app_enabled: true,
  }];

  const response = await handleNotificationRequest({
    request: request({ action: "get-preferences" }),
    userId,
    gateway,
  });
  const payload = await response.json();

  assertEquals(payload.preferences.length, 6);
  assertEquals(
    payload.preferences.find(
      (item: NotificationPreferenceRow) =>
        item.notification_type === "forum",
    ).push_enabled,
    false,
  );
  assertEquals(defaultNotificationPreferences(userId).length, 6);
});

Deno.test("update-preference rejects unsupported notification types", async () => {
  const response = await handleNotificationRequest({
    request: request({
      action: "update-preference",
      notificationType: "marketing",
      pushEnabled: false,
      inAppEnabled: true,
    }),
    userId,
    gateway: new FakeGateway(),
  });

  assertEquals(response.status, 400);
  assertEquals((await response.json()).error, "Unsupported notification type.");
});

Deno.test("unsupported actions return a client error", async () => {
  const response = await handleNotificationRequest({
    request: request({ action: "send-everything" }),
    userId,
    gateway: new FakeGateway(),
  });

  assertEquals(response.status, 400);
});

Deno.test("invalid JSON is rejected before gateway access", async () => {
  const invalidRequest = new Request("https://example.test/notifications", {
    method: "POST",
    body: "{",
  });

  const response = await handleNotificationRequest({
    request: invalidRequest,
    userId,
    gateway: new FakeGateway(),
  });

  assertEquals(response.status, 400);
  assertEquals((await response.json()).error, "Invalid JSON body.");
});
