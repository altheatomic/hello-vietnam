import type { SupabaseClient } from "@supabase/supabase-js";

export class AuthorizationError extends Error {
  constructor(
    message = "Unauthorized.",
    public readonly statusCode = 401,
  ) {
    super(message);
    this.name = "AuthorizationError";
  }
}

export function requireAuthorizationHeader(value: string | null): string {
  const token = value?.trim();
  if (!token) {
    throw new AuthorizationError("Unauthorized: missing Authorization header.");
  }
  return token;
}

export async function requireAuthenticatedUserId(
  client: SupabaseClient,
): Promise<string> {
  const {
    data: { user },
    error,
  } = await client.auth.getUser();

  if (error || !user?.id) {
    throw new AuthorizationError("Unauthorized.");
  }

  return user.id;
}

export async function requireRole(
  client: SupabaseClient,
  userId: string,
  role: string,
): Promise<void> {
  const { data, error } = await client
    .from("user_account")
    .select("role")
    .eq("id_user", userId)
    .maybeSingle();

  if (error) {
    throw new AuthorizationError("Forbidden.", 403);
  }

  const actualRole = String(data?.role ?? "").toLowerCase();
  if (actualRole !== role.toLowerCase()) {
    throw new AuthorizationError("Forbidden.", 403);
  }
}
