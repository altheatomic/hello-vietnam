import {
  evaluateFreshness,
  SOURCE_OWNED_FIELDS,
  type ContentFreshnessRow,
  type FreshnessDecision,
  type JsonObject,
} from "./freshness_domain.ts";
import type { SourceAdapter } from "./source_adapter.ts";

export interface DataFreshnessGateway {
  startRun(triggerType: "cron" | "admin" | "retry"): Promise<string>;
  claimDue(runId: string, limit: number): Promise<ContentFreshnessRow[]>;
  loadContent(row: ContentFreshnessRow): Promise<JsonObject>;
  recordResult(rowId: string, payload: JsonObject): Promise<void>;
  finishRun(
    runId: string,
    status: "completed" | "partial_failure" | "failed",
  ): Promise<void>;
}

export type AdapterResolver = (
  sourceType: string,
) => SourceAdapter | Promise<SourceAdapter>;

export type FreshnessCheckResult = {
  runId: string;
  selectedCount: number;
  checkedCount: number;
  failedCount: number;
  status: "completed" | "partial_failure" | "failed";
};

export type FreshnessCheckOptions = {
  gateway: DataFreshnessGateway;
  adapterFor: AdapterResolver;
  now?: Date;
  triggerType: "cron" | "admin" | "retry";
  batchSize?: number;
  signal?: AbortSignal;
};

export function normalizeBatchSize(value: unknown): number | undefined {
  const candidate = typeof value === "number"
    ? value
    : typeof value === "string" && value.trim() !== ""
    ? Number(value)
    : NaN;
  if (!Number.isFinite(candidate)) return undefined;
  return Math.min(Math.max(Math.trunc(candidate), 1), 50);
}

function sourceSnapshot(content: JsonObject): JsonObject {
  return Object.fromEntries(
    SOURCE_OWNED_FIELDS
      .filter((field) => Object.prototype.hasOwnProperty.call(content, field))
      .map((field) => [field, content[field]]),
  );
}

function decisionPayload(
  runId: string,
  row: ContentFreshnessRow,
  currentContent: JsonObject,
  decision: FreshnessDecision,
  now: Date,
): JsonObject {
  const payload: JsonObject = {
    run_id: runId,
    decision_kind: decision.kind,
    freshness_status: decision.freshnessStatus,
    consecutive_missing_count: decision.consecutiveMissingCount,
    before_data: sourceSnapshot(currentContent),
    proposed_data: decision.proposedData,
    changed_fields: decision.changedFields,
    reason: decision.reason,
    next_check_at: decision.nextCheckAt,
    last_checked_at: now.toISOString(),
    source_hash: decision.sourceHash ?? row.sourceHash,
    content_patch: decision.contentPatch,
    last_error: decision.lastError ?? "",
  };
  if (decision.kind === "unchanged" || decision.kind === "recovered") {
    payload.last_verified_at = now.toISOString();
  }
  return payload;
}

function errorPayload(
  runId: string,
  row: ContentFreshnessRow,
  error: string,
  now: Date,
): JsonObject {
  return {
    run_id: runId,
    decision_kind: "error",
    freshness_status: row.freshnessStatus,
    consecutive_missing_count: row.consecutiveMissingCount,
    before_data: {},
    proposed_data: {},
    changed_fields: [],
    reason: "checker_error",
    next_check_at: row.nextCheckAt ?? now.toISOString(),
    last_checked_at: now.toISOString(),
    source_hash: row.sourceHash,
    content_patch: {},
    last_error: error,
  };
}

export async function runFreshnessCheck({
  gateway,
  adapterFor,
  now = new Date(),
  triggerType,
  batchSize = 50,
  signal,
}: FreshnessCheckOptions): Promise<FreshnessCheckResult> {
  const runId = await gateway.startRun(triggerType);
  let rows: ContentFreshnessRow[] = [];
  let checkedCount = 0;
  let failedCount = 0;
  let cursor = 0;
  const parentSignal = signal ?? new AbortController().signal;

  const processOne = async (row: ContentFreshnessRow): Promise<void> => {
    let currentContent: JsonObject = {};
    let payload: JsonObject;
    try {
      currentContent = await gateway.loadContent(row);
      const adapter = await adapterFor(row.sourceType);
      const source = await adapter.fetch(row, parentSignal);
      const decision = evaluateFreshness({
        freshness: row,
        source,
        currentContent,
        now,
      });
      payload = decisionPayload(runId, row, currentContent, decision, now);
      if (decision.kind === "error") failedCount += 1;
    } catch (error) {
      failedCount += 1;
      payload = errorPayload(
        runId,
        row,
        error instanceof Error ? error.message : "Checker item failed.",
        now,
      );
    }

    try {
      await gateway.recordResult(row.id, payload);
    } catch {
      failedCount += 1;
    }
    checkedCount += 1;
  };

  try {
    rows = await gateway.claimDue(runId, Math.min(Math.max(batchSize, 1), 50));
    const workerCount = Math.min(5, rows.length);
    const worker = async (): Promise<void> => {
      while (true) {
        const index = cursor++;
        if (index >= rows.length) return;
        await processOne(rows[index]);
      }
    };
    await Promise.all(Array.from({ length: workerCount }, worker));
  } catch (error) {
    failedCount += 1;
    if (rows.length === 0) {
      checkedCount = 0;
    }
    // The run is still finalized in finally; the caller receives a failed
    // summary after the database records the run status.
    void error;
  } finally {
    const status = failedCount === 0
      ? "completed"
      : checkedCount > 0
      ? "partial_failure"
      : "failed";
    await gateway.finishRun(runId, status);
  }

  const status = failedCount === 0
    ? "completed"
    : checkedCount > 0
    ? "partial_failure"
    : "failed";
  return {
    runId,
    selectedCount: rows.length,
    checkedCount,
    failedCount,
    status,
  };
}

export { decisionPayload, errorPayload, sourceSnapshot };
