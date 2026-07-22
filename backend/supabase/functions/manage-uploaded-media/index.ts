/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { createClient } from "@supabase/supabase-js";

import { corsHeaders } from "../_shared/cors.ts";

type AuthenticatedUser = { id: string };

export type OwnedForumMedia = {
  id_media: string;
  id_post: string;
  url: string;
  created_at: string;
  post_has_text: boolean;
  author_id: string;
};

type ManageUploadedMediaSupabase = {
  getUser(authorization: string | null): Promise<AuthenticatedUser | null>;
  listOwnedForumMedia(userId: string): Promise<OwnedForumMedia[]>;
  findOwnedForumMedia(userId: string, mediaId: string): Promise<OwnedForumMedia | null>;
  deleteOwnedForumMedia(userId: string, mediaId: string): Promise<boolean>;
};

type ManageUploadedMediaR2 = {
  deleteObject(key: string): Promise<number>;
};

export type ManageUploadedMediaDependencies = {
  publicBaseUrl: string;
  supabase: ManageUploadedMediaSupabase;
  r2: ManageUploadedMediaR2;
};

type ListPayload = { action: "list" };
type DeletePayload = { action: "delete"; mediaIds: string[] };
type RequestPayload = ListPayload | DeletePayload;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const R2_ACCOUNT_ID = Deno.env.get("CLOUDFLARE_R2_ACCOUNT_ID");
const R2_ACCESS_KEY_ID = Deno.env.get("CLOUDFLARE_R2_ACCESS_KEY_ID");
const R2_SECRET_ACCESS_KEY = Deno.env.get("CLOUDFLARE_R2_SECRET_ACCESS_KEY");
const R2_BUCKET = Deno.env.get("CLOUDFLARE_R2_BUCKET");
const R2_PUBLIC_BASE_URL = Deno.env.get("CLOUDFLARE_R2_PUBLIC_BASE_URL");
const R2_REGION = Deno.env.get("CLOUDFLARE_R2_REGION") ?? "auto";
const R2_SERVICE = "s3";

function createProductionDependencies(): ManageUploadedMediaDependencies {
  if (
    !SUPABASE_URL ||
    !SUPABASE_ANON_KEY ||
    !SUPABASE_SERVICE_ROLE_KEY ||
    !R2_ACCOUNT_ID ||
    !R2_ACCESS_KEY_ID ||
    !R2_SECRET_ACCESS_KEY ||
    !R2_BUCKET ||
    !R2_PUBLIC_BASE_URL
  ) {
    throw new Error("Missing manage-uploaded-media environment variables.");
  }

  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  return {
    publicBaseUrl: R2_PUBLIC_BASE_URL,
    supabase: {
      async getUser(authorization) {
        if (!authorization) return null;

        const authClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
          global: { headers: { Authorization: authorization } },
        });
        const { data, error } = await authClient.auth.getUser();
        return error || !data.user ? null : { id: data.user.id };
      },
      async listOwnedForumMedia(userId) {
        const { data, error } = await adminClient
          .from("forum_post_media")
          .select("id_media, id_post, url, created_at, forum_post!inner(id_author_user, title, content)")
          .eq("forum_post.id_author_user", userId)
          .order("created_at", { ascending: false });
        if (error) throw error;
        return (data ?? []).map(toOwnedForumMedia);
      },
      async findOwnedForumMedia(userId, mediaId) {
        const { data, error } = await adminClient
          .from("forum_post_media")
          .select("id_media, id_post, url, created_at, forum_post!inner(id_author_user, title, content)")
          .eq("id_media", mediaId)
          .eq("forum_post.id_author_user", userId)
          .maybeSingle();
        if (error) throw error;
        return data ? toOwnedForumMedia(data) : null;
      },
      async deleteOwnedForumMedia(userId, mediaId) {
        const { data, error } = await adminClient.rpc(
          "delete_owned_forum_media",
          { p_media_id: mediaId, p_user_id: userId },
        );
        if (error) throw error;
        return data === true;
      },
    },
    r2: {
      deleteObject: deleteR2Object,
    },
  };
}

function toOwnedForumMedia(row: Record<string, unknown>): OwnedForumMedia {
  const post = Array.isArray(row.forum_post) ? row.forum_post[0] : row.forum_post;
  if (!post || typeof post !== "object") {
    throw new Error("Forum media is missing its post.");
  }

  const forumPost = post as Record<string, unknown>;
  const title = typeof forumPost.title === "string" ? forumPost.title.trim() : "";
  const content = typeof forumPost.content === "string" ? forumPost.content.trim() : "";
  return {
    id_media: String(row.id_media),
    id_post: String(row.id_post),
    url: String(row.url),
    created_at: String(row.created_at),
    post_has_text: title.length > 0 || content.length > 0,
    author_id: String(forumPost.id_author_user),
  };
}

export function createManageUploadedMediaHandler(
  dependencies: ManageUploadedMediaDependencies,
): (request: Request) => Promise<Response> {
  return async (request) => {
    if (request.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }
    if (request.method !== "POST") {
      return jsonResponse({ error: "Method not allowed." }, 405);
    }

    try {
      const user = await dependencies.supabase.getUser(
        request.headers.get("authorization"),
      );
      if (!user) {
        return jsonResponse({ error: "Unauthorized." }, 401);
      }

      const payload = await parsePayload(request);
      if (payload.action === "list") {
        const items = await dependencies.supabase.listOwnedForumMedia(user.id);
        return jsonResponse({
          items: items.map((media) => ({
            id_media: media.id_media,
            source: "forum",
            url: media.url,
            created_at: media.created_at,
            id_post: media.id_post,
            post_has_text: media.post_has_text,
          })),
        });
      }

      const results = [];
      for (const mediaId of payload.mediaIds) {
        try {
          results.push(await deleteOwnedMedia(dependencies, user.id, mediaId));
        } catch {
          results.push({
            mediaId,
            status: "failed",
            message: "Unable to manage media item.",
          });
        }
      }
      return jsonResponse({ results });
    } catch (error) {
      if (error instanceof RequestValidationError) {
        return jsonResponse({ error: error.message }, 400);
      }
      return jsonResponse({ error: "Unable to manage uploaded media." }, 500);
    }
  };
}

async function parsePayload(request: Request): Promise<RequestPayload> {
  let value: unknown;
  try {
    value = await request.json();
  } catch {
    throw new RequestValidationError("Request body must be valid JSON.");
  }
  if (!value || typeof value !== "object") {
    throw new RequestValidationError("Request body must be an object.");
  }

  const payload = value as Record<string, unknown>;
  if (payload.action === "list") return { action: "list" };
  if (
    payload.action === "delete" &&
    Array.isArray(payload.mediaIds) &&
    payload.mediaIds.length > 0 &&
    payload.mediaIds.every((mediaId) => typeof mediaId === "string" && mediaId.trim().length > 0)
  ) {
    return { action: "delete", mediaIds: payload.mediaIds };
  }
  throw new RequestValidationError("Invalid uploaded media request.");
}

async function deleteOwnedMedia(
  dependencies: ManageUploadedMediaDependencies,
  userId: string,
  mediaId: string,
): Promise<Record<string, string>> {
  let media: OwnedForumMedia | null;
  try {
    media = await dependencies.supabase.findOwnedForumMedia(userId, mediaId);
  } catch {
    return { mediaId, status: "failed", message: "Unable to load media item." };
  }
  if (!media) return { mediaId, status: "not_found" };

  const key = keyFromPublicUrl(media.url, dependencies.publicBaseUrl);
  if (!key) {
    return { mediaId, status: "failed", message: "Media URL is not managed by configured storage." };
  }
  const ownerPostPrefix = `forum/${userId}/${media.id_post}/`;
  if (!key.startsWith(ownerPostPrefix)) {
    return {
      mediaId,
      status: "failed",
      message: "Media storage ownership could not be verified.",
    };
  }

  let r2Status: number;
  try {
    r2Status = await dependencies.r2.deleteObject(key);
  } catch {
    return { mediaId, status: "failed", message: "Unable to delete media object." };
  }
  if (r2Status < 200 || (r2Status >= 300 && r2Status !== 404)) {
    return { mediaId, status: "failed", message: "Unable to delete media object." };
  }

  try {
    const deleted = await dependencies.supabase.deleteOwnedForumMedia(userId, mediaId);
    return deleted
      ? { mediaId, status: "deleted" }
      : { mediaId, status: "failed", message: "Unable to remove media record." };
  } catch {
    return { mediaId, status: "failed", message: "Unable to remove media record." };
  }
}

function keyFromPublicUrl(url: string, publicBaseUrl: string): string | null {
  try {
    const rawPathMatch = url.trim().match(/^[a-z][a-z\d+.-]*:\/\/[^/?#]+([^?#]*)/i);
    if (!rawPathMatch) return null;
    const decodedRawPath = decodeURIComponent(rawPathMatch[1]);
    const rawSegments = decodedRawPath
      .split("/")
      .filter((segment) => segment.length > 0)
      .map((segment) => decodeURIComponent(segment));
    if (rawSegments.some((segment) => segment === "." || segment === "..")) {
      return null;
    }

    const storedUrl = new URL(url);
    const baseUrl = new URL(publicBaseUrl);
    const basePath = baseUrl.pathname.replace(/\/+$/, "");
    const prefix = `${basePath}/`;
    if (storedUrl.origin !== baseUrl.origin || !storedUrl.pathname.startsWith(prefix)) {
      return null;
    }

    const key = storedUrl.pathname.slice(prefix.length)
      .split("/")
      .map((segment) => decodeURIComponent(segment))
      .filter((segment) => segment.length > 0);
    if (key.length === 0 || key.some((segment) => segment === "." || segment === "..")) {
      return null;
    }
    return key.join("/");
  } catch {
    return null;
  }
}

async function deleteR2Object(key: string): Promise<number> {
  const endpoint = new URL(
    `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${R2_BUCKET}/${encodeKey(key)}`,
  );
  const payloadHash = await sha256Hex(new Uint8Array());
  const amzDate = new Date().toISOString().replace(/[:-]|\.\d{3}/g, "");
  const dateStamp = amzDate.slice(0, 8);
  const headers = new Headers({
    host: endpoint.host,
    "x-amz-content-sha256": payloadHash,
    "x-amz-date": amzDate,
  });
  const signedHeaders = Array.from(headers.keys()).sort().join(";");
  const canonicalHeaders = Array.from(headers.keys()).sort()
    .map((name) => `${name}:${headers.get(name)!.trim()}\n`).join("");
  const credentialScope = `${dateStamp}/${R2_REGION}/${R2_SERVICE}/aws4_request`;
  const canonicalRequest = [
    "DELETE",
    endpoint.pathname,
    "",
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join("\n");
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    credentialScope,
    await sha256Hex(canonicalRequest),
  ].join("\n");
  const signingKey = await signingKeyForDate(dateStamp);
  const authorization =
    `AWS4-HMAC-SHA256 Credential=${R2_ACCESS_KEY_ID}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${await hmacHex(signingKey, stringToSign)}`;
  headers.set("authorization", authorization);

  const response = await fetch(endpoint, { method: "DELETE", headers });
  return response.status;
}

function encodeKey(key: string): string {
  return key.split("/").map((segment) => encodeURIComponent(segment)).join("/");
}

async function sha256Hex(data: string | Uint8Array): Promise<string> {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  return toHex(new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)));
}

async function hmac(key: Uint8Array, data: string): Promise<Uint8Array> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(await crypto.subtle.sign("HMAC", cryptoKey, new TextEncoder().encode(data)));
}

async function hmacHex(key: Uint8Array, data: string): Promise<string> {
  return toHex(await hmac(key, data));
}

async function signingKeyForDate(dateStamp: string): Promise<Uint8Array> {
  const dateKey = await hmac(new TextEncoder().encode(`AWS4${R2_SECRET_ACCESS_KEY}`), dateStamp);
  const regionKey = await hmac(dateKey, R2_REGION);
  const serviceKey = await hmac(regionKey, R2_SERVICE);
  return await hmac(serviceKey, "aws4_request");
}

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

class RequestValidationError extends Error {}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

if (import.meta.main) {
  Deno.serve(createManageUploadedMediaHandler(createProductionDependencies()));
}
