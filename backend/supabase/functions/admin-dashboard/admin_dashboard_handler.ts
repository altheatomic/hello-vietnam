export interface AdminDashboardGateway {
  loadAggregate(userId: string): Promise<Record<string, unknown>>;
}

type CacheEntry = {
  expiresAt: number;
  snapshot: Record<string, unknown>;
};

export class AdminDashboardCache {
  private entry: CacheEntry | null = null;

  constructor(
    private readonly ttlMilliseconds = 120_000,
    private readonly now: () => number = () => Date.now(),
  ) {}

  read(): Record<string, unknown> | null {
    if (!this.entry || this.entry.expiresAt <= this.now()) {
      this.entry = null;
      return null;
    }
    return this.entry.snapshot;
  }

  write(snapshot: Record<string, unknown>): void {
    this.entry = {
      expiresAt: this.now() + this.ttlMilliseconds,
      snapshot,
    };
  }
}

type HandlerInput = {
  request: Request;
  userId: string;
  gateway: AdminDashboardGateway;
  cache: AdminDashboardCache;
};

export async function handleAdminDashboardRequest(
  input: HandlerInput,
): Promise<Response> {
  const payload = await input.request.json().catch(() => ({}));
  const forceRefresh = isRecord(payload) && payload.forceRefresh === true;

  if (!forceRefresh) {
    const cached = input.cache.read();
    if (cached) return dashboardResponse(cached, "HIT");
  }

  const snapshot = await input.gateway.loadAggregate(input.userId);
  input.cache.write(snapshot);
  return dashboardResponse(snapshot, "MISS");
}

function dashboardResponse(
  snapshot: Record<string, unknown>,
  cacheStatus: "HIT" | "MISS",
): Response {
  return new Response(JSON.stringify({ snapshot }), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "X-Admin-Dashboard-Cache": cacheStatus,
    },
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
