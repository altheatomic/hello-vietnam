import type { SupabaseClient } from "@supabase/supabase-js";

import type {
  DispatchGateway,
  DispatchNotification,
  PushDevice,
} from "./notification_dispatch_handler.ts";

type Row = Record<string, unknown>;

export class SupabaseDispatchGateway implements DispatchGateway {
  constructor(private readonly client: SupabaseClient) {}

  async claim(notificationId: string): Promise<DispatchNotification | null> {
    const { data, error } = await this.client.rpc(
      "claim_notification_for_dispatch",
      { p_id_notification: notificationId },
    );
    throwIfError(error, "Could not claim the notification.");
    const row = Array.isArray(data) ? data[0] as Row | undefined : undefined;
    if (row == null) return null;
    return {
      idNotification: String(row.id_notification),
      userId: String(row.id_user),
      notificationType: String(row.notification_type),
      title: String(row.title ?? "Hello Vietnam"),
      body: String(row.body ?? ""),
      payload: asRecord(row.payload_jsonb),
      isPush: row.is_push === true,
    };
  }

  async pushEnabled(userId: string, notificationType: string): Promise<boolean> {
    const { data, error } = await this.client.rpc(
      "notification_push_enabled",
      { p_id_user: userId, p_notification_type: notificationType },
    );
    throwIfError(error, "Could not load push preferences.");
    return data !== false;
  }

  async activeDevices(userId: string): Promise<PushDevice[]> {
    const { data, error } = await this.client
      .from("user_push_device")
      .select("id_device,fcm_token")
      .eq("id_user", userId)
      .eq("platform", "android")
      .eq("is_active", true)
      .order("last_seen_at", { ascending: false })
      .limit(10);
    throwIfError(error, "Could not load active push devices.");
    return ((data ?? []) as Row[]).map((row) => ({
      idDevice: String(row.id_device),
      fcmToken: String(row.fcm_token),
    }));
  }

  async updateStatus(
    notificationId: string,
    status: string,
    errorMessage: string | null,
    sentAt: string | null,
  ): Promise<void> {
    const { error } = await this.client
      .from("notification")
      .update({
        status,
        push_error: errorMessage,
        sent_at: sentAt,
      })
      .eq("id_notification", notificationId);
    throwIfError(error, "Could not update notification delivery status.");
  }

  async deactivateDevice(deviceId: string): Promise<void> {
    const { error } = await this.client
      .from("user_push_device")
      .update({ is_active: false })
      .eq("id_device", deviceId);
    throwIfError(error, "Could not deactivate an invalid push token.");
  }
}

function asRecord(value: unknown): Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function throwIfError(
  error: { message?: string } | null,
  fallback: string,
): void {
  if (error != null) throw new Error(error.message?.trim() || fallback);
}
