type JsonObject = Record<string, unknown>;

const USER_ACCOUNT_TABLE = "user_account";

export class AuthorizationError extends Error {
  constructor(
    public readonly statusCode: number,
    message: string,
  ) {
    super(message);
    this.name = "AuthorizationError";
  }
}

type UserClientLike = {
  auth: {
    getUser: () => Promise<{
      data: { user: { id?: string | null } | null };
      error: { message?: string } | null;
    }>;
  };
};

type AdminClientLike = {
  from: (table: string) => {
    select: (columns: string) => {
      eq: (column: string, value: string) => {
        maybeSingle: () => Promise<{
          data: JsonObject | null;
          error: { message?: string } | null;
        }>;
      };
    };
  };
};

export function requireAuthorizationHeader(
  authHeader: string | null,
): string {
  const token = authHeader?.trim();
  if (!token) {
    throw new AuthorizationError(401, "Missing Authorization header.");
  }
  return token;
}

export async function requireAuthenticatedUserId(
  userClient: UserClientLike,
): Promise<string> {
  const {
    data: { user },
    error: authError,
  } = await userClient.auth.getUser();

  if (authError || !user?.id) {
    throw new AuthorizationError(401, "Unauthorized.");
  }

  return user.id;
}

export async function requireRole(
  adminClient: AdminClientLike,
  userId: string,
  roleName: string,
): Promise<void> {
  const { data, error } = await adminClient
    .from(USER_ACCOUNT_TABLE)
    .select("role")
    .eq("id_user", userId)
    .maybeSingle();

  if (error) {
    throw new Error(`Failed to load user role: ${error.message ?? "unknown"}`);
  }

  const roleRaw = (data ?? {}).role;
  const role = roleRaw == null ? "" : String(roleRaw).trim().toLowerCase();
  if (role.length === 0) {
    throw new Error("User role is missing.");
  }

  if (role !== roleName.trim().toLowerCase()) {
    throw new AuthorizationError(403, `${roleName} access required.`);
  }
}
