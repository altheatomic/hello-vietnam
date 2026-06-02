/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { createClient } from "@supabase/supabase-js";

import { corsHeaders } from "../_shared/cors.ts";

type JsonObject = Record<string, unknown>;

type UploadPayload = {
  action?: "upload";
  folder?: string;
  fileName?: string;
  contentType?: string;
  dataBase64?: string;
};

type DeletePayload = {
  action: "delete";
  keys?: string[];
  key?: string;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const R2_ACCOUNT_ID = Deno.env.get("CLOUDFLARE_R2_ACCOUNT_ID");
const R2_ACCESS_KEY_ID = Deno.env.get("CLOUDFLARE_R2_ACCESS_KEY_ID");
const R2_SECRET_ACCESS_KEY = Deno.env.get("CLOUDFLARE_R2_SECRET_ACCESS_KEY");
const R2_BUCKET = Deno.env.get("CLOUDFLARE_R2_BUCKET");
const R2_PUBLIC_BASE_URL = Deno.env.get("CLOUDFLARE_R2_PUBLIC_BASE_URL");

const R2_REGION = Deno.env.get("CLOUDFLARE_R2_REGION") ?? "auto";
const MAX_UPLOAD_BYTES = Number(Deno.env.get("CLOUDFLARE_R2_MAX_UPLOAD_BYTES") ?? 8 * 1024 * 1024);
const R2_SERVICE = "s3";

if (
  !SUPABASE_URL ||
  !SUPABASE_ANON_KEY ||
  !R2_ACCOUNT_ID ||
  !R2_ACCESS_KEY_ID ||
  !R2_SECRET_ACCESS_KEY ||
  !R2_BUCKET ||
  !R2_PUBLIC_BASE_URL
) {
  throw new Error("Missing media-upload environment variables.");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const userId = await requireAuthenticatedUserId(req);
    const payload = await req.json() as UploadPayload | DeletePayload;

    if (payload.action === "delete") {
      const deleted = await deleteMedia(payload);
      return jsonResponse({ deleted });
    }

    const uploaded = await uploadMedia(payload as UploadPayload, userId);
    return jsonResponse(uploaded);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error.";
    const status = message.startsWith("UNAUTHORIZED")
      ? 401
      : message.startsWith("BAD_REQUEST")
      ? 400
      : message.startsWith("PAYLOAD_TOO_LARGE")
      ? 413
      : 500;
    return jsonResponse({ error: message }, status);
  }
});

async function requireAuthenticatedUserId(req: Request): Promise<string> {
  const authorization = req.headers.get("authorization");
  if (!authorization) {
    throw new Error("UNAUTHORIZED: Missing authorization header.");
  }

  const supabase = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
    global: {
      headers: { Authorization: authorization },
    },
  });
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) {
    throw new Error("UNAUTHORIZED: Invalid user session.");
  }
  return data.user.id;
}

async function uploadMedia(
  payload: UploadPayload,
  userId: string,
): Promise<JsonObject> {
  const folder = sanitizePath(payload.folder ?? "");
  const fileName = sanitizeFileName(payload.fileName ?? "upload.bin");
  const contentType = sanitizeContentType(payload.contentType ?? "application/octet-stream");
  const dataBase64 = payload.dataBase64;

  if (!dataBase64) {
    throw new Error("BAD_REQUEST: Missing file data.");
  }

  const bytes = decodeBase64(dataBase64);
  if (bytes.byteLength === 0) {
    throw new Error("BAD_REQUEST: Empty file.");
  }
  if (bytes.byteLength > MAX_UPLOAD_BYTES) {
    throw new Error("PAYLOAD_TOO_LARGE: File is too large.");
  }

  const key = sanitizePath(
    `${folder || `uploads/${userId}`}/${fileName}`,
  );

  await sendR2Request({
    method: "PUT",
    key,
    body: bytes,
    contentType,
  });

  return {
    key,
    url: publicUrlForKey(key),
    size: bytes.byteLength,
    contentType,
  };
}

async function deleteMedia(payload: DeletePayload): Promise<string[]> {
  const keys = new Set<string>();
  if (payload.key) keys.add(sanitizePath(payload.key));
  for (const key of payload.keys ?? []) {
    keys.add(sanitizePath(key));
  }

  const deleted: string[] = [];
  for (const key of keys) {
    if (!key) continue;
    await sendR2Request({ method: "DELETE", key });
    deleted.push(key);
  }
  return deleted;
}

async function sendR2Request(options: {
  method: "PUT" | "DELETE";
  key: string;
  body?: Uint8Array;
  contentType?: string;
}): Promise<void> {
  const encodedKey = encodeKey(options.key);
  const endpoint = new URL(
    `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${R2_BUCKET}/${encodedKey}`,
  );
  const payload = options.body ?? new Uint8Array();
  const payloadHash = await sha256Hex(payload);
  const amzDate = amzDateString(new Date());
  const dateStamp = amzDate.substring(0, 8);
  const contentType = options.contentType ?? "application/octet-stream";

  const headers = new Headers({
    "host": endpoint.host,
    "x-amz-content-sha256": payloadHash,
    "x-amz-date": amzDate,
  });
  if (options.method === "PUT") {
    headers.set("content-type", contentType);
  }

  const signedHeaders = Array.from(headers.keys()).sort().join(";");
  const canonicalHeaders = Array.from(headers.keys())
    .sort()
    .map((name) => `${name}:${headers.get(name)!.trim()}\n`)
    .join("");
  const canonicalRequest = [
    options.method,
    endpoint.pathname,
    "",
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join("\n");
  const credentialScope = `${dateStamp}/${R2_REGION}/${R2_SERVICE}/aws4_request`;
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    credentialScope,
    await sha256Hex(canonicalRequest),
  ].join("\n");
  const signingKey = await getSigningKey(dateStamp);
  const signature = await hmacHex(signingKey, stringToSign);
  const authorization =
    `AWS4-HMAC-SHA256 Credential=${R2_ACCESS_KEY_ID}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

  headers.set("authorization", authorization);

  const response = await fetch(endpoint, {
    method: options.method,
    headers,
    body: options.method === "PUT" ? payload : undefined,
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`R2_UPLOAD_FAILED: ${response.status} ${body}`);
  }
}

function sanitizePath(path: string): string {
  return path
    .replaceAll("\\", "/")
    .split("/")
    .map((segment) => segment.trim())
    .filter((segment) => segment.length > 0 && segment !== "." && segment !== "..")
    .map((segment) => segment.replace(/[^a-zA-Z0-9._-]/g, "-"))
    .join("/");
}

function sanitizeFileName(fileName: string): string {
  const sanitized = sanitizePath(fileName).split("/").pop() ?? "upload.bin";
  return sanitized || "upload.bin";
}

function sanitizeContentType(contentType: string): string {
  return contentType.includes("/") ? contentType : "application/octet-stream";
}

function decodeBase64(dataBase64: string): Uint8Array {
  const binary = atob(dataBase64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function publicUrlForKey(key: string): string {
  return `${R2_PUBLIC_BASE_URL!.replace(/\/+$/, "")}/${encodeKey(key)}`;
}

function encodeKey(key: string): string {
  return key.split("/").map((segment) => encodeURIComponent(segment)).join("/");
}

function amzDateString(date: Date): string {
  return date.toISOString().replace(/[:-]|\.\d{3}/g, "");
}

async function sha256Hex(data: string | Uint8Array): Promise<string> {
  const bytes = typeof data === "string"
    ? new TextEncoder().encode(data)
    : data;
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  return toHex(new Uint8Array(hash));
}

async function hmac(key: Uint8Array, data: string): Promise<Uint8Array> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    new TextEncoder().encode(data),
  );
  return new Uint8Array(signature);
}

async function hmacHex(key: Uint8Array, data: string): Promise<string> {
  return toHex(await hmac(key, data));
}

async function getSigningKey(dateStamp: string): Promise<Uint8Array> {
  const dateKey = await hmac(
    new TextEncoder().encode(`AWS4${R2_SECRET_ACCESS_KEY}`),
    dateStamp,
  );
  const regionKey = await hmac(dateKey, R2_REGION);
  const serviceKey = await hmac(regionKey, R2_SERVICE);
  return await hmac(serviceKey, "aws4_request");
}

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function jsonResponse(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
