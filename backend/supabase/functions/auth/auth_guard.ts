/// <reference lib="dom" />

import { SupabaseClient } from "@supabase/supabase-js";

export class AuthorizationError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number = 401,
  ) {
    super(message);
    this.name = "AuthorizationError";
  }
}

/**
 * Validates that an Authorization header value is present and Bearer-prefixed.
 * Returns the raw header value (e.g. "Bearer <token>") for passing to createClient.
 */
export function requireAuthorizationHeader(value: string | null): string {
  if (!value || !value.startsWith("Bearer ")) {
    throw new AuthorizationError(
      "Missing or invalid Authorization header.",
      401,
    );
  }
  return value;
}

/**
 * Calls auth.getUser() on the *user-scoped* client (created with the caller's
 * JWT).  Returns the authenticated user ID or throws AuthorizationError.
 */
export async function requireAuthenticatedUserId(
  client: SupabaseClient,
): Promise<string> {
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) {
    throw new AuthorizationError("Unauthorized.", 401);
  }
  return data.user.id;
}

/**
 * Like requireAuthenticatedUserId but also checks that the user's role
 * (stored in user_metadata.role or app_metadata.role) matches the required role.
 */
export async function requireRole(
  client: SupabaseClient,
  role: string,
): Promise<string> {
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) {
    throw new AuthorizationError("Unauthorized.", 401);
  }

  const userRole =
    (data.user.app_metadata?.role as string | undefined) ??
    (data.user.user_metadata?.role as string | undefined);

  if (userRole !== role) {
    throw new AuthorizationError(
      `Forbidden: role "${role}" required.`,
      403,
    );
  }

  return data.user.id;
}
