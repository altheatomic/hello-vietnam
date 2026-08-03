import type { SupabaseClient } from "@supabase/supabase-js";

import type {
  DataFreshnessGateway,
} from "./data_freshness_handler.ts";
import type {
  ContentFreshnessRow,
  ContentType,
  JsonObject,
} from "./freshness_domain.ts";

const CONTENT_TABLES: Record<ContentType, { table: string; idColumn: string }> = {
  place: { table: "place", idColumn: "id_place" },
  activity: { table: "activity", idColumn: "id" },
  culture: { table: "culture", idColumn: "id" },
  food: { table: "food", idColumn: "id_food" },
  local_product: { table: "local_products", idColumn: "id" },
};

export class SupabaseDataFreshnessGateway implements DataFreshnessGateway {
  constructor(private readonly client: SupabaseClient) {}

  async startRun(triggerType: "cron" | "admin" | "retry"): Promise<string> {
    const { data, error } = await this.client
      .from("content_update_run")
      .insert({ trigger_type: triggerType })
      .select("id")
      .single();
    if (error) throw new Error(error.message);
    const id = (data as { id?: unknown } | null)?.id;
    if (typeof id !== "string") throw new Error("Update run did not return an id.");
    return id;
  }

  async claimDue(runId: string, limit: number): Promise<ContentFreshnessRow[]> {
    const { data, error } = await this.client.rpc("claim_due_content_freshness", {
      p_run_id: runId,
      p_limit: limit,
    });
    if (error) throw new Error(error.message);
    if (!Array.isArray(data)) return [];
    return data.map(toFreshnessRow);
  }

  async loadContent(row: ContentFreshnessRow): Promise<JsonObject> {
    const config = CONTENT_TABLES[row.contentType];
    if (!config) throw new Error(`Unsupported content type: ${row.contentType}`);
    const { data, error } = await this.client
      .from(config.table)
      .select("*")
      .eq(config.idColumn, row.contentId)
      .maybeSingle();
    if (error) throw new Error(error.message);
    if (!data || typeof data !== "object") {
      throw new Error("Content row no longer exists.");
    }
    return data as JsonObject;
  }

  async recordResult(rowId: string, payload: JsonObject): Promise<void> {
    const { error } = await this.client.rpc("record_content_freshness_result", {
      p_freshness_id: rowId,
      p_payload: payload,
    });
    if (error) throw new Error(error.message);
  }

  async finishRun(
    runId: string,
    status: "completed" | "partial_failure" | "failed",
  ): Promise<void> {
    const { error } = await this.client
      .from("content_update_run")
      .update({ status, finished_at: new Date().toISOString() })
      .eq("id", runId);
    if (error) throw new Error(error.message);
  }
}

function toFreshnessRow(value: unknown): ContentFreshnessRow {
  if (!value || typeof value !== "object") {
    throw new Error("Freshness claim returned an invalid row.");
  }
  const row = value as Record<string, unknown>;
  return {
    id: String(row.id),
    contentType: String(row.content_type) as ContentType,
    contentId: String(row.content_id),
    sourceType: String(row.source_type),
    sourceUrl: asNullableString(row.source_url),
    sourceExternalId: asNullableString(row.source_external_id),
    availabilityType: String(row.availability_type) as ContentFreshnessRow["availabilityType"],
    validFrom: asNullableString(row.valid_from),
    validUntil: asNullableString(row.valid_until),
    freshnessStatus: String(row.freshness_status) as ContentFreshnessRow["freshnessStatus"],
    lastCheckedAt: asNullableString(row.last_checked_at),
    lastVerifiedAt: asNullableString(row.last_verified_at),
    nextCheckAt: asNullableString(row.next_check_at),
    sourceHash: asNullableString(row.source_hash),
    consecutiveMissingCount: Number(row.consecutive_missing_count ?? 0),
    lastError: asNullableString(row.last_error),
  };
}

function asNullableString(value: unknown): string | null {
  return value === null || value === undefined ? null : String(value);
}

export { CONTENT_TABLES, toFreshnessRow };
