import type { SupabaseClient } from "@supabase/supabase-js";

import type {
  NotificationCursor,
  NotificationGateway,
  NotificationPage,
  NotificationPreferenceRow,
  RegisterDeviceInput,
  UpdatePreferenceInput,
} from "./notification_handler.ts";

type DatabaseRow = Record<string, unknown>;

export class SupabaseNotificationGateway implements NotificationGateway {
  constructor(private readonly client: SupabaseClient) {}

  async registerDevice(input: RegisterDeviceInput): Promise<void> {
    const { error: deleteError } = await this.client
      .from("user_push_device")
      .delete()
      .eq("id_user", input.userId)
      .eq("installation_id", input.installationId)
      .neq("fcm_token", input.fcmToken);
    throwIfError(deleteError, "Could not replace the device token.");

    const { error } = await this.client.from("user_push_device").upsert({
      id_user: input.userId,
      fcm_token: input.fcmToken,
      installation_id: input.installationId,
      platform: input.platform,
      is_active: true,
      last_seen_at: new Date().toISOString(),
    }, { onConflict: "fcm_token" });
    throwIfError(error, "Could not register the push device.");
  }

  async unregisterDevice(
    userId: string,
    installationId: string,
  ): Promise<void> {
    const { error } = await this.client
      .from("user_push_device")
      .update({ is_active: false, last_seen_at: new Date().toISOString() })
      .eq("id_user", userId)
      .eq("installation_id", installationId);
    throwIfError(error, "Could not unregister the push device.");
  }

  async list(
    userId: string,
    limit: number,
    cursor: NotificationCursor | null,
  ): Promise<NotificationPage> {
    let query = this.client
      .from("notification")
      .select(
        "id_notification,title,body,notification_type,icon,payload_jsonb,is_push,sent_at,read_at,status,created_at",
      )
      .eq("id_user", userId)
      .eq("is_in_app", true)
      .order("created_at", { ascending: false })
      .order("id_notification", { ascending: false })
      .limit(limit + 1);

    if (cursor != null) {
      query = query.or(
        `created_at.lt.${cursor.createdAt},and(created_at.eq.${cursor.createdAt},id_notification.lt.${cursor.idNotification})`,
      );
    }

    const { data, error } = await query;
    throwIfError(error, "Could not load notifications.");
    const rows = ((data ?? []) as DatabaseRow[]);
    const hasMore = rows.length > limit;
    const items = hasMore ? rows.slice(0, limit) : rows;
    const last = items.at(-1);
    const overduePlanIds = [...new Set(
      items.map(overduePlanId).filter((value): value is string => value != null),
    )];
    const completedPlanIds = new Set<string>();

    if (overduePlanIds.length > 0) {
      const { data: plans, error: plansError } = await this.client
        .from("plan")
        .select("id_plan,ended_at")
        .eq("id_user", userId)
        .in("id_plan", overduePlanIds);
      throwIfError(plansError, "Could not load trip completion statuses.");
      for (const plan of (plans ?? []) as DatabaseRow[]) {
        if (plan.ended_at != null) completedPlanIds.add(String(plan.id_plan));
      }
    }

    return {
      items: items.map((item) => {
        const idPlan = overduePlanId(item);
        return idPlan == null
          ? item
          : { ...item, is_trip_completed: completedPlanIds.has(idPlan) };
      }),
      nextCursor: hasMore && last
        ? `${String(last.created_at)}|${String(last.id_notification)}`
        : null,
    };
  }

  async unreadCount(userId: string): Promise<number> {
    const { count, error } = await this.client
      .from("notification")
      .select("id_notification", { count: "exact", head: true })
      .eq("id_user", userId)
      .eq("is_in_app", true)
      .is("read_at", null);
    throwIfError(error, "Could not count unread notifications.");
    return count ?? 0;
  }

  async markRead(userId: string, notificationId: string): Promise<boolean> {
    const { data, error } = await this.client
      .from("notification")
      .update({ read_at: new Date().toISOString() })
      .eq("id_user", userId)
      .eq("id_notification", notificationId)
      .is("read_at", null)
      .select("id_notification");
    throwIfError(error, "Could not mark the notification as read.");
    return (data?.length ?? 0) > 0;
  }

  async markAllRead(userId: string): Promise<number> {
    const { data, error } = await this.client
      .from("notification")
      .update({ read_at: new Date().toISOString() })
      .eq("id_user", userId)
      .eq("is_in_app", true)
      .is("read_at", null)
      .select("id_notification");
    throwIfError(error, "Could not mark notifications as read.");
    return data?.length ?? 0;
  }

  async getPreferences(userId: string): Promise<NotificationPreferenceRow[]> {
    const { data, error } = await this.client
      .from("user_notification_preference")
      .select(
        "id_user,notification_type,push_enabled,in_app_enabled",
      )
      .eq("id_user", userId);
    throwIfError(error, "Could not load notification preferences.");
    return (data ?? []) as NotificationPreferenceRow[];
  }

  async updatePreference(
    input: UpdatePreferenceInput,
  ): Promise<NotificationPreferenceRow> {
    const { data, error } = await this.client
      .from("user_notification_preference")
      .upsert({
        id_user: input.userId,
        notification_type: input.notificationType,
        push_enabled: input.pushEnabled,
        in_app_enabled: input.inAppEnabled,
      }, { onConflict: "id_user,notification_type" })
      .select("id_user,notification_type,push_enabled,in_app_enabled")
      .single();
    throwIfError(error, "Could not update the notification preference.");
    return data as NotificationPreferenceRow;
  }
}

function overduePlanId(row: DatabaseRow): string | null {
  const payload = asRecord(row.payload_jsonb);
  const target = asRecord(payload.target);
  if (target.kind !== "tripOverdueCheck") return null;
  const value = typeof target.entityId === "string" ? target.entityId.trim() : "";
  return value.length > 0 ? value : null;
}

function asRecord(value: unknown): DatabaseRow {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? value as DatabaseRow
    : {};
}

function throwIfError(
  error: { message?: string } | null,
  fallback: string,
): void {
  if (error != null) {
    throw new Error(error.message?.trim() || fallback);
  }
}
