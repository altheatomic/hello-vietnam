export const notificationTypes = [
  "all",
  "loyalty",
  "forum",
  "voucher",
  "trip",
  "account",
] as const;

export type NotificationType = typeof notificationTypes[number];

export type NotificationCursor = {
  createdAt: string;
  idNotification: string;
};

export type NotificationRow = Record<string, unknown>;

export type NotificationPage = {
  items: NotificationRow[];
  nextCursor: string | null;
};

export type NotificationPreferenceRow = {
  id_user: string;
  notification_type: NotificationType;
  push_enabled: boolean;
  in_app_enabled: boolean;
};

export type RegisterDeviceInput = {
  userId: string;
  fcmToken: string;
  installationId: string;
  platform: "android" | "ios" | "web";
};

export type UpdatePreferenceInput = {
  userId: string;
  notificationType: NotificationType;
  pushEnabled: boolean;
  inAppEnabled: boolean;
};

export interface NotificationGateway {
  registerDevice(input: RegisterDeviceInput): Promise<void>;
  unregisterDevice(userId: string, installationId: string): Promise<void>;
  list(
    userId: string,
    limit: number,
    cursor: NotificationCursor | null,
  ): Promise<NotificationPage>;
  unreadCount(userId: string): Promise<number>;
  markRead(userId: string, notificationId: string): Promise<boolean>;
  markAllRead(userId: string): Promise<number>;
  getPreferences(userId: string): Promise<NotificationPreferenceRow[]>;
  updatePreference(
    input: UpdatePreferenceInput,
  ): Promise<NotificationPreferenceRow>;
}

export class NotificationRequestError extends Error {
  constructor(message: string, public readonly statusCode = 400) {
    super(message);
    this.name = "NotificationRequestError";
  }
}

type HandlerInput = {
  request: Request;
  userId: string;
  gateway: NotificationGateway;
};

export function defaultNotificationPreferences(
  userId: string,
): NotificationPreferenceRow[] {
  return notificationTypes.map((notificationType) => ({
    id_user: userId,
    notification_type: notificationType,
    push_enabled: true,
    in_app_enabled: true,
  }));
}

export async function handleNotificationRequest({
  request,
  userId,
  gateway,
}: HandlerInput): Promise<Response> {
  let body: Record<string, unknown>;
  try {
    const decoded = await request.json();
    if (!decoded || typeof decoded !== "object" || Array.isArray(decoded)) {
      return jsonResponse({ error: "Invalid JSON body." }, 400);
    }
    body = decoded as Record<string, unknown>;
  } catch {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  try {
    const action = requiredString(body.action, "action");
    switch (action) {
      case "register-device": {
        const platform = requiredPlatform(body.platform);
        await gateway.registerDevice({
          userId,
          fcmToken: requiredString(body.fcmToken, "fcmToken"),
          installationId: requiredString(
            body.installationId,
            "installationId",
          ),
          platform,
        });
        return jsonResponse({ registered: true });
      }
      case "unregister-device": {
        await gateway.unregisterDevice(
          userId,
          requiredString(body.installationId, "installationId"),
        );
        return jsonResponse({ unregistered: true });
      }
      case "list": {
        const limit = clampLimit(body.limit);
        const cursor = parseNotificationCursor(optionalString(body.cursor));
        return jsonResponse(await gateway.list(userId, limit, cursor));
      }
      case "unread-count":
        return jsonResponse({ count: await gateway.unreadCount(userId) });
      case "mark-read": {
        const updated = await gateway.markRead(
          userId,
          requiredString(body.notificationId, "notificationId"),
        );
        return jsonResponse({ updated });
      }
      case "mark-all-read":
        return jsonResponse({ updated: await gateway.markAllRead(userId) });
      case "get-preferences": {
        const saved = await gateway.getPreferences(userId);
        const savedByType = new Map(
          saved.map((preference) => [preference.notification_type, preference]),
        );
        const preferences = defaultNotificationPreferences(userId).map(
          (preference) =>
            savedByType.get(preference.notification_type) ?? preference,
        );
        return jsonResponse({ preferences });
      }
      case "update-preference": {
        const notificationType = requiredNotificationType(
          body.notificationType,
        );
        const preference = await gateway.updatePreference({
          userId,
          notificationType,
          pushEnabled: requiredBoolean(body.pushEnabled, "pushEnabled"),
          inAppEnabled: requiredBoolean(
            body.inAppEnabled,
            "inAppEnabled",
          ),
        });
        return jsonResponse({ preference });
      }
      default:
        throw new NotificationRequestError(`Unsupported action: ${action}`);
    }
  } catch (error) {
    if (error instanceof NotificationRequestError) {
      return jsonResponse({ error: error.message }, error.statusCode);
    }
    throw error;
  }
}

export function parseNotificationCursor(
  value: string | null,
): NotificationCursor | null {
  if (value == null) return null;
  const separator = value.lastIndexOf("|");
  if (separator <= 0 || separator === value.length - 1) {
    throw new NotificationRequestError("Invalid notification cursor.");
  }

  const createdAt = value.slice(0, separator);
  const idNotification = value.slice(separator + 1);
  if (
    Number.isNaN(Date.parse(createdAt)) ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(idNotification)
  ) {
    throw new NotificationRequestError("Invalid notification cursor.");
  }
  return { createdAt, idNotification };
}

function clampLimit(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(value ?? 20);
  if (!Number.isFinite(parsed)) return 20;
  return Math.min(Math.max(Math.trunc(parsed), 1), 50);
}

function requiredString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new NotificationRequestError(`Missing or invalid ${field}.`);
  }
  return value.trim();
}

function optionalString(value: unknown): string | null {
  if (value == null) return null;
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new NotificationRequestError("Invalid notification cursor.");
  }
  return value.trim();
}

function requiredBoolean(value: unknown, field: string): boolean {
  if (typeof value !== "boolean") {
    throw new NotificationRequestError(`Missing or invalid ${field}.`);
  }
  return value;
}

function requiredPlatform(value: unknown): RegisterDeviceInput["platform"] {
  if (value !== "android" && value !== "ios" && value !== "web") {
    throw new NotificationRequestError("Unsupported device platform.");
  }
  return value;
}

function requiredNotificationType(value: unknown): NotificationType {
  if (
    typeof value !== "string" ||
    !notificationTypes.includes(value as NotificationType)
  ) {
    throw new NotificationRequestError("Unsupported notification type.");
  }
  return value as NotificationType;
}

export function jsonResponse(
  payload: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}
