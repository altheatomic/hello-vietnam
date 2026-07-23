import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  AdminDashboardCache,
  handleAdminDashboardRequest,
  type AdminDashboardGateway,
} from "./admin_dashboard_handler.ts";

class FakeGateway implements AdminDashboardGateway {
  loadCount = 0;

  async loadAggregate(userId: string): Promise<Record<string, unknown>> {
    this.loadCount += 1;
    return {
      generated_at: "2026-07-23T08:00:00Z",
      requested_by: userId,
      load_count: this.loadCount,
    };
  }
}

const userId = "11111111-1111-4111-8111-111111111111";

function request(forceRefresh = false): Request {
  return new Request("https://example.test/admin-dashboard", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ forceRefresh }),
  });
}

Deno.test("dashboard aggregate is reused within the cache TTL", async () => {
  const gateway = new FakeGateway();
  const cache = new AdminDashboardCache(120_000);

  const first = await handleAdminDashboardRequest({
    request: request(),
    userId,
    gateway,
    cache,
  });
  const second = await handleAdminDashboardRequest({
    request: request(),
    userId,
    gateway,
    cache,
  });

  assertEquals(first.status, 200);
  assertEquals(second.status, 200);
  assertEquals(first.headers.get("X-Admin-Dashboard-Cache"), "MISS");
  assertEquals(second.headers.get("X-Admin-Dashboard-Cache"), "HIT");
  assertEquals(gateway.loadCount, 1);
});

Deno.test("forceRefresh bypasses the dashboard cache", async () => {
  const gateway = new FakeGateway();
  const cache = new AdminDashboardCache(120_000);

  await handleAdminDashboardRequest({
    request: request(),
    userId,
    gateway,
    cache,
  });
  const refreshed = await handleAdminDashboardRequest({
    request: request(true),
    userId,
    gateway,
    cache,
  });

  assertEquals(refreshed.status, 200);
  assertEquals(refreshed.headers.get("X-Admin-Dashboard-Cache"), "MISS");
  assertEquals(gateway.loadCount, 2);
});
