/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { createClient } from "@supabase/supabase-js";
import {
  handleTripShareRequest,
  type ShareLinkRecord,
  type TripShareGateway,
} from "./trip_share_handler.ts";
import {
  requireAuthenticatedUserId,
  requireAuthorizationHeader,
} from "../auth/auth_guard.ts";

const SUPABASE_URL = requiredEnvironment("SUPABASE_URL");
const SUPABASE_ANON_KEY = requiredEnvironment("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
const CF_SERVICE_URL = (Deno.env.get("CF_SERVICE_URL") ?? "http://localhost:8000")
  .replace(/\/+$/u, "");
const SHARE_WEB_BASE_URL = requiredEnvironment("SHARE_WEB_BASE_URL");
const ALLOWED_ORIGINS = new Set(
  (Deno.env.get("SHARE_WEB_ALLOWED_ORIGINS") ?? SHARE_WEB_BASE_URL)
    .split(",")
    .map((value) => value.trim().replace(/\/+$/u, ""))
    .filter(Boolean),
);

const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

class SupabaseTripShareGateway implements TripShareGateway {
  async ownsPlan(userId: string, planId: string): Promise<boolean> {
    const { data, error } = await adminClient
      .from("plan")
      .select("id_plan")
      .eq("id_plan", planId)
      .eq("id_user", userId)
      .maybeSingle();
    if (error) throw new Error(`Could not validate trip ownership: ${error.message}`);
    return data != null;
  }

  async createLink(input: ShareLinkRecord): Promise<ShareLinkRecord> {
    const { data: plan, error: planError } = await adminClient
      .from("plan")
      .select("custom_title")
      .eq("id_plan", input.idPlan)
      .eq("id_user", input.ownerUserId)
      .single();
    if (planError) throw new Error(`Could not load trip title: ${planError.message}`);

    const row = {
      id_share: input.idShare,
      id_plan: input.idPlan,
      owner_user_id: input.ownerUserId,
      token_hash: input.tokenHash,
      token_prefix: input.tokenPrefix,
      allow_copy: input.allowCopy,
      expires_at: input.expiresAt,
      created_at: input.createdAt,
    };
    const { data, error } = await adminClient
      .from("trip_share_link")
      .insert(row)
      .select("*")
      .single();
    if (error) throw new Error(`Could not create share link: ${error.message}`);
    return mapShareRow(data, stringValue(plan?.custom_title));
  }

  async listLinks(userId: string, planId?: string): Promise<ShareLinkRecord[]> {
    let query = adminClient
      .from("trip_share_link")
      .select("*, plan(custom_title)")
      .eq("owner_user_id", userId)
      .order("created_at", { ascending: false })
      .limit(50);
    if (planId) query = query.eq("id_plan", planId);
    const { data, error } = await query;
    if (error) throw new Error(`Could not list share links: ${error.message}`);
    return (data ?? []).map((row: Record<string, unknown>) => {
      const embeddedPlan = row.plan && typeof row.plan === "object"
        ? row.plan as Record<string, unknown>
        : null;
      return mapShareRow(row, stringValue(embeddedPlan?.custom_title));
    });
  }

  async revokeLink(userId: string, shareId: string): Promise<boolean> {
    const { data, error } = await adminClient
      .from("trip_share_link")
      .update({ revoked_at: new Date().toISOString() })
      .eq("id_share", shareId)
      .eq("owner_user_id", userId)
      .is("revoked_at", null)
      .select("id_share")
      .maybeSingle();
    if (error) throw new Error(`Could not revoke share link: ${error.message}`);
    return data != null;
  }

  async findLinkByHash(tokenHash: string): Promise<ShareLinkRecord | null> {
    const { data, error } = await adminClient
      .from("trip_share_link")
      .select("*, plan(custom_title)")
      .eq("token_hash", tokenHash)
      .maybeSingle();
    if (error) throw new Error(`Could not resolve share link: ${error.message}`);
    if (!data) return null;
    const embeddedPlan = data.plan && typeof data.plan === "object"
      ? data.plan as Record<string, unknown>
      : null;
    return mapShareRow(data, stringValue(embeddedPlan?.custom_title));
  }

  async getPlan(planId: string, ownerUserId: string): Promise<Record<string, unknown>> {
    const response = await fetch(
      `${CF_SERVICE_URL}/api/trips/plan/${encodeURIComponent(planId)}?id_user=${encodeURIComponent(ownerUserId)}`,
    );
    const body = await response.json().catch(() => null);
    if (!response.ok || !body || typeof body !== "object" || Array.isArray(body)) {
      throw new Error("Shared trip data is unavailable.");
    }
    return body as Record<string, unknown>;
  }

  async recordView(shareId: string): Promise<void> {
    const { error } = await adminClient.rpc("record_trip_share_view", {
      p_id_share: shareId,
    });
    if (error) console.warn(`[trip-share] could not record view: ${error.message}`);
  }

  async clonePlan(planId: string, userId: string): Promise<string> {
    const response = await fetch(
      `${CF_SERVICE_URL}/api/trips/${encodeURIComponent(planId)}/clone`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id_user: userId }),
      },
    );
    const body = await response.json().catch(() => null) as Record<string, unknown> | null;
    const idPlan = stringValue(body?.id_plan);
    if (!response.ok || !idPlan) throw new Error("Could not copy shared trip.");
    return idPlan;
  }
}

const gateway = new SupabaseTripShareGateway();

Deno.serve((request: Request) =>
  handleTripShareRequest(
    request,
    gateway,
    async (authenticatedRequest) => {
      const header = authenticatedRequest.headers.get("Authorization");
      if (!header?.trim()) return null;
      const authHeader = requireAuthorizationHeader(header);
      const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        global: { headers: { Authorization: authHeader } },
      });
      try {
        return await requireAuthenticatedUserId(userClient);
      } catch {
        return null;
      }
    },
    {
      shareWebBaseUrl: SHARE_WEB_BASE_URL,
      allowedOrigins: ALLOWED_ORIGINS,
    },
  )
);

function mapShareRow(
  row: Record<string, unknown>,
  title: string | null,
): ShareLinkRecord {
  return {
    idShare: String(row.id_share),
    idPlan: String(row.id_plan),
    ownerUserId: String(row.owner_user_id),
    tokenHash: String(row.token_hash),
    tokenPrefix: String(row.token_prefix),
    title,
    allowCopy: row.allow_copy !== false,
    expiresAt: String(row.expires_at),
    revokedAt: stringValue(row.revoked_at),
    createdAt: String(row.created_at),
  };
}

function stringValue(value: unknown): string | null {
  if (value == null) return null;
  const normalized = String(value).trim();
  return normalized || null;
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}
