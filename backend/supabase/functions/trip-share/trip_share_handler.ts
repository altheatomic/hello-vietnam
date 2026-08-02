import {
  createShareToken,
  hashShareToken,
  parseExpiryDays,
  publicShareUrl,
} from "../_shared/trip_share_domain.ts";

type JsonObject = Record<string, unknown>;

export interface ShareLinkRecord {
  idShare: string;
  idPlan: string;
  ownerUserId: string;
  tokenHash: string;
  tokenPrefix: string;
  title: string | null;
  allowCopy: boolean;
  expiresAt: string;
  revokedAt: string | null;
  createdAt: string;
}

export interface TripShareGateway {
  ownsPlan(userId: string, planId: string): Promise<boolean>;
  createLink(input: ShareLinkRecord): Promise<ShareLinkRecord>;
  listLinks(userId: string, planId?: string): Promise<ShareLinkRecord[]>;
  revokeLink(userId: string, shareId: string): Promise<boolean>;
  findLinkByHash(tokenHash: string): Promise<ShareLinkRecord | null>;
  getPlan(planId: string, ownerUserId: string): Promise<JsonObject>;
  recordView(shareId: string): Promise<void>;
  clonePlan(planId: string, userId: string): Promise<string>;
}

export type TripShareAuthenticator = (request: Request) => Promise<string | null>;

export interface TripShareOptions {
  shareWebBaseUrl: string;
  allowedOrigins: ReadonlySet<string>;
  now?: () => Date;
}

export async function handleTripShareRequest(
  request: Request,
  gateway: TripShareGateway,
  authenticate: TripShareAuthenticator,
  options: TripShareOptions,
): Promise<Response> {
  const origin = request.headers.get("Origin")?.trim() ?? null;
  const cors = corsHeaders(origin, options.allowedOrigins);
  if (origin && !options.allowedOrigins.has(origin)) {
    return jsonResponse({ error: "Origin is not allowed." }, 403, cors);
  }
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });

  const publicToken = tokenFromPublicPath(new URL(request.url).pathname);
  if (request.method === "GET" && publicToken != null) {
    try {
      return await publicView(publicToken, gateway, options, cors);
    } catch (error) {
      console.error("[trip-share] public view failed", error);
      return jsonResponse(
        { error: "Shared trip is temporarily unavailable." },
        503,
        cors,
      );
    }
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405, cors);
  }

  const userId = await authenticate(request);
  if (!userId) return jsonResponse({ error: "Unauthorized." }, 401, cors);

  const body = await request.json().catch(() => null);
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return jsonResponse({ error: "Invalid JSON body." }, 400, cors);
  }
  const payload = body as JsonObject;
  const action = stringValue(payload.action);

  try {
    switch (action) {
      case "create":
        return createLink(userId, payload, gateway, options, cors);
      case "list":
        return listLinks(userId, payload, gateway, cors);
      case "revoke":
        return revokeLink(userId, payload, gateway, cors);
      case "copy":
        return copyLink(userId, payload, gateway, options, cors);
      default:
        return jsonResponse({ error: "Unsupported action." }, 400, cors);
    }
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unexpected error." },
      400,
      cors,
    );
  }
}

async function createLink(
  userId: string,
  payload: JsonObject,
  gateway: TripShareGateway,
  options: TripShareOptions,
  cors: HeadersInit,
): Promise<Response> {
  const planId = requiredString(payload.idPlan, "idPlan");
  if (!await gateway.ownsPlan(userId, planId)) {
    return jsonResponse({ error: "Trip plan was not found." }, 404, cors);
  }

  const token = createShareToken();
  const tokenHash = await hashShareToken(token);
  const expiryDays = parseExpiryDays(payload.expiryDays);
  const now = (options.now ?? (() => new Date()))();
  const expiresAt = new Date(now.getTime() + expiryDays * 86_400_000);
  const record = await gateway.createLink({
    idShare: crypto.randomUUID(),
    idPlan: planId,
    ownerUserId: userId,
    tokenHash,
    tokenPrefix: token.slice(0, 8),
    title: null,
    allowCopy: payload.allowCopy !== false,
    expiresAt: expiresAt.toISOString(),
    revokedAt: null,
    createdAt: now.toISOString(),
  });

  return jsonResponse(
    {
      link: ownerLinkDto(record),
      url: publicShareUrl(options.shareWebBaseUrl, token),
    },
    201,
    cors,
  );
}

async function listLinks(
  userId: string,
  payload: JsonObject,
  gateway: TripShareGateway,
  cors: HeadersInit,
): Promise<Response> {
  const planId = stringValue(payload.idPlan) ?? undefined;
  const links = await gateway.listLinks(userId, planId);
  return jsonResponse({ links: links.map(ownerLinkDto) }, 200, cors);
}

async function revokeLink(
  userId: string,
  payload: JsonObject,
  gateway: TripShareGateway,
  cors: HeadersInit,
): Promise<Response> {
  const shareId = requiredString(payload.idShare, "idShare");
  const revoked = await gateway.revokeLink(userId, shareId);
  if (!revoked) return jsonResponse({ error: "Share link was not found." }, 404, cors);
  return jsonResponse({ revoked: true }, 200, cors);
}

async function copyLink(
  userId: string,
  payload: JsonObject,
  gateway: TripShareGateway,
  options: TripShareOptions,
  cors: HeadersInit,
): Promise<Response> {
  const token = requiredString(payload.token, "token");
  const link = await validLink(token, gateway, options);
  if (!link) return unavailable(cors);
  if (!link.allowCopy) {
    return jsonResponse({ error: "Copying is disabled for this link." }, 403, cors);
  }
  const idPlan = await gateway.clonePlan(link.idPlan, userId);
  return jsonResponse({ id_plan: idPlan }, 200, cors);
}

async function publicView(
  token: string,
  gateway: TripShareGateway,
  options: TripShareOptions,
  cors: HeadersInit,
): Promise<Response> {
  const link = await validLink(token, gateway, options);
  if (!link) return unavailable(cors);

  const rawPlan = await gateway.getPlan(link.idPlan, link.ownerUserId);
  await gateway.recordView(link.idShare);
  return jsonResponse(publicPlanDto(rawPlan, link), 200, cors);
}

async function validLink(
  token: string,
  gateway: TripShareGateway,
  options: TripShareOptions,
): Promise<ShareLinkRecord | null> {
  let hash: string;
  try {
    hash = await hashShareToken(token);
  } catch {
    return null;
  }
  const link = await gateway.findLinkByHash(hash);
  if (!link || link.revokedAt != null) return null;
  const now = (options.now ?? (() => new Date()))().getTime();
  if (!Number.isFinite(Date.parse(link.expiresAt)) || Date.parse(link.expiresAt) <= now) {
    return null;
  }
  return link;
}

function publicPlanDto(raw: JsonObject, link: ShareLinkRecord): JsonObject {
  const rawDays = Array.isArray(raw.days) ? raw.days : [];
  const days = rawDays
    .filter(isJsonObject)
    .map((day) => ({
      day: numberValue(day.day) ?? 0,
      date: stringValue(day.date) ?? "",
      places: (Array.isArray(day.places) ? day.places : [])
        .filter(isJsonObject)
        .map(publicPlaceDto),
    }));

  return {
    title: link.title ?? "Shared Vietnam itinerary",
    n_days: days.length,
    days,
    allow_copy: link.allowCopy,
    expires_at: link.expiresAt,
  };
}

function publicPlaceDto(place: JsonObject): JsonObject {
  const gallery = (Array.isArray(place.gallery) ? place.gallery : [])
    .filter(isJsonObject)
    .map((item) => ({
      url: stringValue(item.url),
      type: stringValue(item.type),
      source: stringValue(item.source),
    }))
    .filter((item) => item.url != null);
  return compactObject({
    type: stringValue(place.type) ?? "place",
    order: numberValue(place.order) ?? numberValue(place.visit_order) ?? 0,
    name: stringValue(place.name) ?? "",
    slot: stringValue(place.slot),
    start_time: stringValue(place.start_time),
    end_time: stringValue(place.end_time),
    warning: stringValue(place.warning),
    latitude: numberValue(place.latitude),
    longitude: numberValue(place.longitude),
    estimated_travel_minutes: numberValue(place.estimated_travel_minutes),
    estimated_duration_minutes: numberValue(place.estimated_duration_minutes),
    cover_image: stringValue(place.cover_image),
    gallery,
  });
}

function ownerLinkDto(link: ShareLinkRecord): JsonObject {
  return {
    id_share: link.idShare,
    id_plan: link.idPlan,
    token_prefix: link.tokenPrefix,
    title: link.title,
    allow_copy: link.allowCopy,
    expires_at: link.expiresAt,
    revoked_at: link.revokedAt,
    created_at: link.createdAt,
  };
}

function tokenFromPublicPath(pathname: string): string | null {
  const match = pathname.match(/\/public\/([^/]+)\/?$/u);
  if (!match) return null;
  try {
    return decodeURIComponent(match[1]);
  } catch {
    return null;
  }
}

function unavailable(cors: HeadersInit): Response {
  return jsonResponse({ error: "Shared trip is unavailable." }, 404, cors);
}

function corsHeaders(origin: string | null, allowed: ReadonlySet<string>): HeadersInit {
  return {
    "Access-Control-Allow-Origin": origin && allowed.has(origin) ? origin : "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Vary": "Origin",
  };
}

function jsonResponse(body: JsonObject, status: number, headers: HeadersInit): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...headers,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function compactObject(value: JsonObject): JsonObject {
  return Object.fromEntries(Object.entries(value).filter(([, item]) => item != null));
}

function isJsonObject(value: unknown): value is JsonObject {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function stringValue(value: unknown): string | null {
  if (value == null) return null;
  const normalized = String(value).trim();
  return normalized ? normalized : null;
}

function requiredString(value: unknown, name: string): string {
  const normalized = stringValue(value);
  if (!normalized) throw new Error(`Missing required field: ${name}`);
  return normalized;
}

function numberValue(value: unknown): number | null {
  if (value == null) return null;
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}
