import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import type { FcmSendResult } from "../_shared/firebase_messaging.ts";
import {
  dispatchNotification,
  type DispatchGateway,
  type DispatchNotification,
  type PushDevice,
} from "./notification_dispatch_handler.ts";

class FakeDispatchGateway implements DispatchGateway {
  claimed: DispatchNotification | null = notification();
  enabled = true;
  devices: PushDevice[] = [
    { idDevice: "device-1", fcmToken: "token-1" },
  ];
  statusUpdates: Array<{
    notificationId: string;
    status: string;
    error: string | null;
    sentAt: string | null;
  }> = [];
  deactivated: string[] = [];

  claim(_notificationId: string): Promise<DispatchNotification | null> {
    return Promise.resolve(this.claimed);
  }

  pushEnabled(_userId: string, _type: string): Promise<boolean> {
    return Promise.resolve(this.enabled);
  }

  activeDevices(_userId: string): Promise<PushDevice[]> {
    return Promise.resolve(this.devices);
  }

  async updateStatus(
    notificationId: string,
    status: string,
    error: string | null,
    sentAt: string | null,
  ): Promise<void> {
    this.statusUpdates.push({ notificationId, status, error, sentAt });
  }

  async deactivateDevice(deviceId: string): Promise<void> {
    this.deactivated.push(deviceId);
  }
}

function notification(): DispatchNotification {
  return {
    idNotification: "11111111-1111-4111-8111-111111111111",
    userId: "22222222-2222-4222-8222-222222222222",
    notificationType: "forum",
    title: "New reply",
    body: "Someone replied to your post",
    payload: {
      target: {
        kind: "forumPost",
        entityId: "33333333-3333-4333-8333-333333333333",
      },
    },
    isPush: true,
  };
}

Deno.test("already claimed notifications are skipped without sending", async () => {
  const gateway = new FakeDispatchGateway();
  gateway.claimed = null;
  let sends = 0;

  const result = await dispatchNotification({
    notificationId: "11111111-1111-4111-8111-111111111111",
    gateway,
    send: () => {
      sends += 1;
      return Promise.resolve({ ok: true, status: 200 });
    },
    now: () => new Date("2026-07-22T10:00:00.000Z"),
  });

  assertEquals(result, { outcome: "already-processed" });
  assertEquals(sends, 0);
});

Deno.test("disabled notification types stay in the inbox without FCM calls", async () => {
  const gateway = new FakeDispatchGateway();
  gateway.enabled = false;
  let sends = 0;

  const result = await dispatchNotification({
    notificationId: notification().idNotification,
    gateway,
    send: () => {
      sends += 1;
      return Promise.resolve({ ok: true, status: 200 });
    },
    now: () => new Date("2026-07-22T10:00:00.000Z"),
  });

  assertEquals(result, { outcome: "push-disabled" });
  assertEquals(sends, 0);
  assertEquals(gateway.statusUpdates[0].status, "in_app_only");
});

Deno.test("dispatch sends to all active devices and records success", async () => {
  const gateway = new FakeDispatchGateway();
  gateway.devices.push({ idDevice: "device-2", fcmToken: "token-2" });
  const tokens: string[] = [];

  const result = await dispatchNotification({
    notificationId: notification().idNotification,
    gateway,
    send: (token: string) => {
      tokens.push(token);
      return Promise.resolve({ ok: true, status: 200 });
    },
    now: () => new Date("2026-07-22T10:00:00.000Z"),
  });

  assertEquals(result, { outcome: "sent", sent: 2, failed: 0 });
  assertEquals(tokens.sort(), ["token-1", "token-2"]);
  assertEquals(gateway.statusUpdates[0], {
    notificationId: notification().idNotification,
    status: "sent",
    error: null,
    sentAt: "2026-07-22T10:00:00.000Z",
  });
});

Deno.test("invalid tokens are deactivated while valid devices still succeed", async () => {
  const gateway = new FakeDispatchGateway();
  gateway.devices.push({ idDevice: "device-2", fcmToken: "token-2" });

  const result = await dispatchNotification({
    notificationId: notification().idNotification,
    gateway,
    send: (token: string): Promise<FcmSendResult> =>
      Promise.resolve(token === "token-1"
        ? {
          ok: false,
          status: 404,
          code: "UNREGISTERED",
          message: "Token is gone",
        }
        : { ok: true, status: 200 }),
    now: () => new Date("2026-07-22T10:00:00.000Z"),
  });

  assertEquals(result, { outcome: "partial", sent: 1, failed: 1 });
  assertEquals(gateway.deactivated, ["device-1"]);
  assertEquals(gateway.statusUpdates[0].status, "partial");
});

Deno.test("a notification with no active device remains in-app only", async () => {
  const gateway = new FakeDispatchGateway();
  gateway.devices = [];

  const result = await dispatchNotification({
    notificationId: notification().idNotification,
    gateway,
    send: () => Promise.resolve({ ok: true, status: 200 }),
    now: () => new Date("2026-07-22T10:00:00.000Z"),
  });

  assertEquals(result, { outcome: "no-active-device" });
  assertEquals(gateway.statusUpdates[0].status, "in_app_only");
});
