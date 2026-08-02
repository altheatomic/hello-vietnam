const SUPPORTED_EXPIRY_DAYS = new Set([7, 30, 90]);

export function createShareToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/u, "");
}

export async function hashShareToken(token: string): Promise<string> {
  const normalized = token.trim();
  if (!normalized) throw new Error("Invalid share token.");

  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(normalized),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function parseExpiryDays(value: unknown): 7 | 30 | 90 {
  const parsed = value == null ? 30 : Number(value);
  if (!Number.isInteger(parsed) || !SUPPORTED_EXPIRY_DAYS.has(parsed)) {
    throw new Error("expiryDays must be 7, 30, or 90.");
  }
  return parsed as 7 | 30 | 90;
}

export function publicShareUrl(baseUrl: string, token: string): string {
  const normalizedToken = token.trim();
  if (!normalizedToken) throw new Error("Invalid share token.");

  const url = new URL(baseUrl.trim());
  if (url.protocol !== "https:") {
    throw new Error("Public share URL must use HTTPS.");
  }
  url.pathname = `${url.pathname.replace(/\/+$/u, "")}/trip/${encodeURIComponent(normalizedToken)}`;
  url.search = "";
  url.hash = "";
  return url.toString().replace(/\/$/u, "");
}
