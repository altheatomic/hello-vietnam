import type { SupabaseClient } from "@supabase/supabase-js";

import type { AdminDashboardGateway } from "./admin_dashboard_handler.ts";

export class SupabaseAdminDashboardGateway
  implements AdminDashboardGateway {
  constructor(private readonly client: SupabaseClient) {}

  async loadAggregate(userId: string): Promise<Record<string, unknown>> {
    const { data, error } = await this.client.rpc(
      "admin_dashboard_aggregate",
      { p_requesting_user: userId },
    );
    if (error) throw new Error(error.message);
    if (!isRecord(data)) {
      throw new Error("Admin dashboard aggregate returned an invalid payload.");
    }
    return data;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
