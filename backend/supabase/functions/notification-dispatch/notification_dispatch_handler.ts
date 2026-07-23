import {
  isPermanentTokenError,
  type FcmSendResult,
} from "../_shared/firebase_messaging.ts";

export type DispatchNotification = {
  idNotification: string;
  userId: string;
  notificationType: string;
  title: string;
  body: string;
  payload: Record<string, unknown>;
  isPush: boolean;
};

export type PushDevice = {
  idDevice: string;
  fcmToken: string;
};

export interface DispatchGateway {
  claim(notificationId: string): Promise<DispatchNotification | null>;
  pushEnabled(userId: string, notificationType: string): Promise<boolean>;
  activeDevices(userId: string): Promise<PushDevice[]>;
  updateStatus(
    notificationId: string,
    status: string,
    error: string | null,
    sentAt: string | null,
  ): Promise<void>;
  deactivateDevice(deviceId: string): Promise<void>;
}

type DispatchInput = {
  notificationId: string;
  gateway: DispatchGateway;
  send: (
    token: string,
    notification: DispatchNotification,
    data: Record<string, string>,
  ) => Promise<FcmSendResult>;
  now?: () => Date;
};

export type DispatchOutcome =
  | { outcome: "already-processed" }
  | { outcome: "push-disabled" }
  | { outcome: "no-active-device" }
  | {
    outcome: "sent" | "partial" | "failed";
    sent: number;
    failed: number;
  };

export async function dispatchNotification({
  notificationId,
  gateway,
  send,
  now = () => new Date(),
}: DispatchInput): Promise<DispatchOutcome> {
  const notification = await gateway.claim(notificationId);
  if (notification == null) return { outcome: "already-processed" };

  if (
    !notification.isPush ||
    !await gateway.pushEnabled(
      notification.userId,
      notification.notificationType,
    )
  ) {
    await gateway.updateStatus(notificationId, "in_app_only", null, null);
    return { outcome: "push-disabled" };
  }

  const devices = await gateway.activeDevices(notification.userId);
  if (devices.length === 0) {
    await gateway.updateStatus(notificationId, "in_app_only", null, null);
    return { outcome: "no-active-device" };
  }

  const data = notificationData(notification);
  const results = await Promise.all(devices.map(async (device) => {
    let result: FcmSendResult;
    try {
      result = await send(device.fcmToken, notification, data);
    } catch (error) {
      result = {
        ok: false,
        status: 0,
        code: "SEND_FAILED",
        message: error instanceof Error ? error.message : "FCM send failed.",
      };
    }
    if (isPermanentTokenError(result)) {
      await gateway.deactivateDevice(device.idDevice);
    }
    return result;
  }));

  const sent = results.filter((result) => result.ok).length;
  const failed = results.length - sent;
  const status = sent === results.length
    ? "sent"
    : sent === 0
    ? "failed"
    : "partial";
  const errors = results
    .filter((result) => !result.ok)
    .map((result) => `${result.code ?? result.status}: ${result.message ?? "failed"}`)
    .join("; ");

  await gateway.updateStatus(
    notificationId,
    status,
    errors || null,
    sent > 0 ? now().toISOString() : null,
  );
  return { outcome: status, sent, failed };
}

export function notificationData(
  notification: DispatchNotification,
): Record<string, string> {
  return {
    id_notification: notification.idNotification,
    notification_type: notification.notificationType,
    target: JSON.stringify(notification.payload.target ?? {}),
  };
}
