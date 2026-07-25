export interface FirebaseCredentials {
  projectId: string;
  clientEmail: string;
  privateKey: string;
}

export interface FcmSendInput {
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
  credentials: FirebaseCredentials;
}

export interface FcmSendResult {
  ok: boolean;
  status: number;
  messageId?: string;
  code?: string;
  message?: string;
}

export interface FirebaseDependencies {
  fetch: typeof fetch;
  now: () => number;
  signJwt: (
    credentials: FirebaseCredentials,
    issuedAtSeconds: number,
  ) => Promise<string>;
}

interface CachedAccessToken {
  value: string;
  expiresAtMs: number;
}

const oauthTokens = new Map<string, CachedAccessToken>();
const firebaseScope = "https://www.googleapis.com/auth/firebase.messaging";
const oauthEndpoint = "https://oauth2.googleapis.com/token";

const defaultDependencies: FirebaseDependencies = {
  fetch,
  now: () => Date.now(),
  signJwt: createServiceAccountJwt,
};

export async function sendFcmMessage(
  input: FcmSendInput,
  dependencies: Partial<FirebaseDependencies> = {},
): Promise<FcmSendResult> {
  const deps = { ...defaultDependencies, ...dependencies };
  const accessToken = await getAccessToken(input.credentials, deps);
  const endpoint =
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(input.credentials.projectId)}/messages:send`;
  const response = await deps.fetch(endpoint, {
    method: "POST",
    headers: {
      authorization: `Bearer ${accessToken}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token: input.token,
        notification: {
          title: input.title,
          body: input.body,
        },
        data: input.data,
        android: {
          priority: "HIGH",
          notification: {
            channel_id: "hello_vietnam_updates",
            sound: "default",
          },
        },
      },
    }),
  });

  const payload = await readJson(response);
  if (response.ok) {
    return {
      ok: true,
      status: response.status,
      messageId: asString(payload?.name),
    };
  }

  const error = asRecord(payload?.error);
  const details = Array.isArray(error?.details) ? error.details : [];
  const fcmDetail = details
    .map(asRecord)
    .find((detail) => typeof detail?.errorCode === "string");

  return {
    ok: false,
    status: response.status,
    code: asString(fcmDetail?.errorCode) ?? asString(error?.status),
    message: asString(error?.message) ?? `FCM request failed (${response.status})`,
  };
}

export function isPermanentTokenError(result: FcmSendResult): boolean {
  return !result.ok &&
    (result.code === "UNREGISTERED" || result.code === "SENDER_ID_MISMATCH");
}

export function clearFirebaseAccessTokenCacheForTests(): void {
  oauthTokens.clear();
}

async function getAccessToken(
  credentials: FirebaseCredentials,
  dependencies: FirebaseDependencies,
): Promise<string> {
  const cacheKey = `${credentials.projectId}:${credentials.clientEmail}`;
  const cached = oauthTokens.get(cacheKey);
  const nowMs = dependencies.now();
  if (cached != null && cached.expiresAtMs - 60_000 > nowMs) {
    return cached.value;
  }

  const issuedAtSeconds = Math.floor(nowMs / 1000);
  const assertion = await dependencies.signJwt(credentials, issuedAtSeconds);
  const response = await dependencies.fetch(oauthEndpoint, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const payload = await readJson(response);
  const token = asString(payload?.access_token);
  if (!response.ok || token == null) {
    const description = asString(payload?.error_description) ??
      asString(payload?.error) ?? `OAuth request failed (${response.status})`;
    throw new Error(`FIREBASE_OAUTH_FAILED: ${description}`);
  }

  const expiresInSeconds = typeof payload?.expires_in === "number"
    ? payload.expires_in
    : 3600;
  oauthTokens.set(cacheKey, {
    value: token,
    expiresAtMs: nowMs + expiresInSeconds * 1000,
  });
  return token;
}

async function createServiceAccountJwt(
  credentials: FirebaseCredentials,
  issuedAtSeconds: number,
): Promise<string> {
  const header = encodeJson({ alg: "RS256", typ: "JWT" });
  const claims = encodeJson({
    iss: credentials.clientEmail,
    sub: credentials.clientEmail,
    aud: oauthEndpoint,
    scope: firebaseScope,
    iat: issuedAtSeconds,
    exp: issuedAtSeconds + 3600,
  });
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(credentials.privateKey.replaceAll("\\n", "\n")),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${base64Url(new Uint8Array(signature))}`;
}

function encodeJson(value: Record<string, unknown>): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)));
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/u, "");
}

function pemToArrayBuffer(value: string): ArrayBuffer {
  const base64 = value
    .replace(/-----BEGIN PRIVATE KEY-----/gu, "")
    .replace(/-----END PRIVATE KEY-----/gu, "")
    .replace(/\s/gu, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes.buffer;
}

async function readJson(response: Response): Promise<Record<string, unknown>> {
  try {
    return asRecord(await response.json()) ?? {};
  } catch (_) {
    return {};
  }
}

function asRecord(value: unknown): Record<string, any> | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, any>;
}

function asString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}
