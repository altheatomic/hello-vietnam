import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { JsonObject } from "./freshness_api_handler.ts";
import {
  type FreshnessApiGateway,
  handleFreshnessApiRequest,
} from "./freshness_api_handler.ts";

function requestFor(action: string, payload: JsonObject = {}): Request {
  return new Request("http://localhost/data-freshness", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ action, ...payload }),
  });
}

class FakeFreshnessApiGateway implements FreshnessApiGateway {
  submittedReports: JsonObject[] = [];

  async submitReport(payload: JsonObject): Promise<JsonObject> {
    this.submittedReports.push(payload);
    return { id: "40000000-0000-4000-8000-000000000001" };
  }

  async listMyReports(): Promise<{ rows: JsonObject[]; totalCount: number }> {
    return { rows: [], totalCount: 0 };
  }

  async getOverview(): Promise<JsonObject> {
    return { due: 0, pending: 0, autoExpiredToday: 0, failedRuns: 0 };
  }

  async listQueue(): Promise<{ rows: JsonObject[]; totalCount: number }> {
    return { rows: [], totalCount: 0 };
  }

  async listStale(): Promise<{ rows: JsonObject[]; totalCount: number }> {
    return { rows: [], totalCount: 0 };
  }

  async listReports(): Promise<{ rows: JsonObject[]; totalCount: number }> {
    return { rows: [], totalCount: 0 };
  }

  async listRuns(): Promise<{ rows: JsonObject[]; totalCount: number }> {
    return { rows: [], totalCount: 0 };
  }

  async reviewProposal(): Promise<JsonObject> {
    return { decision: "approved" };
  }

  async requestCheck(): Promise<void> {}

  async updateReportStatus(): Promise<JsonObject> {
    return {};
  }
}

Deno.test("submitReport forwards the authenticated user payload", async () => {
  const gateway = new FakeFreshnessApiGateway();
  const response = await handleFreshnessApiRequest({
    request: requestFor("submitReport", {
      contentType: "place",
      contentId: "10000000-0000-4000-8000-000000000001",
      reason: "wrong_hours",
      note: "Closes at 21:00",
    }),
    userId: "20000000-0000-4000-8000-000000000001",
    isAdmin: false,
    gateway,
  });
  assertEquals(response.status, 200);
  assertEquals(gateway.submittedReports.length, 1);
  assertEquals(gateway.submittedReports[0].contentType, "place");
});

Deno.test("a non-admin cannot review proposals", async () => {
  const response = await handleFreshnessApiRequest({
    request: requestFor("adminReviewProposal", {
      proposalId: "10000000-0000-4000-8000-000000000001",
      decision: "approved",
      appliedData: {},
    }),
    userId: "20000000-0000-4000-8000-000000000001",
    isAdmin: false,
    gateway: new FakeFreshnessApiGateway(),
  });
  assertEquals(response.status, 403);
});

Deno.test("invalid report reason is rejected before the gateway", async () => {
  const gateway = new FakeFreshnessApiGateway();
  const response = await handleFreshnessApiRequest({
    request: requestFor("submitReport", {
      contentType: "place",
      contentId: "10000000-0000-4000-8000-000000000001",
      reason: "spam",
    }),
    userId: "20000000-0000-4000-8000-000000000001",
    isAdmin: false,
    gateway,
  });
  assertEquals(response.status, 400);
  assertEquals(gateway.submittedReports.length, 0);
});

Deno.test("admin queue action returns paged rows", async () => {
  const gateway = new FakeFreshnessApiGateway();
  const response = await handleFreshnessApiRequest({
    request: requestFor("adminListQueue", { page: 2, pageSize: 20 }),
    userId: "20000000-0000-4000-8000-000000000001",
    isAdmin: true,
    gateway,
  });
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { proposals: [], totalCount: 0 });
});

Deno.test("admin stale action returns freshness rows", async () => {
  const response = await handleFreshnessApiRequest({
    request: requestFor("adminListStale", { page: 1, pageSize: 20 }),
    userId: "20000000-0000-4000-8000-000000000001",
    isAdmin: true,
    gateway: new FakeFreshnessApiGateway(),
  });
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { freshness: [], totalCount: 0 });
});
