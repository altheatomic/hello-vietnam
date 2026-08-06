import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type {
  ContentFreshnessRow,
  JsonObject,
} from "./freshness_domain.ts";
import type { SourceAdapter } from "./source_adapter.ts";
import {
  type DataFreshnessGateway,
  runFreshnessCheck,
} from "./data_freshness_handler.ts";

function freshness(id: string): ContentFreshnessRow {
  return {
    id,
    contentType: "place",
    contentId: `20000000-0000-4000-8000-${id.slice(-12)}`,
    sourceType: "wikipedia",
    sourceUrl: "https://en.wikipedia.org/wiki/Hoi_An",
    sourceExternalId: "wikipedia:https://en.wikipedia.org/wiki/Hoi_An",
    availabilityType: "evergreen",
    validUntil: null,
    freshnessStatus: "due",
    sourceHash: null,
    consecutiveMissingCount: 0,
  };
}

class FakeGateway implements DataFreshnessGateway {
  readonly rows = [freshness("10000000-0000-4000-8000-000000000001"), freshness("10000000-0000-4000-8000-000000000002")];
  readonly records: Array<{ id: string; payload: JsonObject }> = [];
  readonly claims: Array<{ runId: string; limit: number }> = [];
  finished: Array<{ runId: string; status: string }> = [];

  async startRun(): Promise<string> {
    return "30000000-0000-4000-8000-000000000001";
  }

  async claimDue(runId: string, limit: number): Promise<ContentFreshnessRow[]> {
    this.claims.push({ runId, limit });
    return this.rows;
  }

  async loadContent(row: ContentFreshnessRow): Promise<JsonObject> {
    return { name: row.id.endsWith("1") ? "Cafe One" : "Cafe Two", status: "active" };
  }

  async recordResult(id: string, payload: JsonObject): Promise<void> {
    this.records.push({ id, payload });
  }

  async finishRun(runId: string, status: "completed" | "partial_failure" | "failed"): Promise<void> {
    this.finished.push({ runId, status });
  }
}

Deno.test("checker claims 50 and continues after an adapter error", async () => {
  const gateway = new FakeGateway();
  const adapters: Record<string, SourceAdapter> = {
    wikipedia: {
      fetch: async (row) => row.id.endsWith("1")
        ? { outcome: "error", error: "timeout" }
        : { outcome: "found", data: { name: "Cafe Two" }, sourceHash: "hash-two" },
    },
  };
  const result = await runFreshnessCheck({
    gateway,
    adapterFor: async (sourceType) => adapters[sourceType],
    now: new Date("2026-08-03T02:15:00Z"),
    triggerType: "cron",
  });

  assertEquals(gateway.claims[0].limit, 50);
  assertEquals(gateway.records.length, 2);
  assertEquals(gateway.records[0].payload.decision_kind, "error");
  assertEquals(gateway.records[1].payload.decision_kind, "unchanged");
  assertEquals(gateway.finished, [{
    runId: "30000000-0000-4000-8000-000000000001",
    status: "partial_failure",
  }]);
  assertEquals(result.checkedCount, 2);
});

Deno.test("checker always finishes an empty run", async () => {
  const gateway = new FakeGateway();
  gateway.rows.splice(0);
  await runFreshnessCheck({
    gateway,
    adapterFor: async () => ({ fetch: async () => ({ outcome: "missing" }) }),
    now: new Date("2026-08-03T02:15:00Z"),
    triggerType: "admin",
  });
  assertEquals(gateway.finished[0].status, "completed");
});
