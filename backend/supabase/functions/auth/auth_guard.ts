import { createClient } from "@supabase/supabase-js";

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
  client: ReturnType<typeof createClient>,
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
