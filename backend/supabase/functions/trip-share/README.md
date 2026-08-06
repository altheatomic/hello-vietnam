# Trip share Edge Function

This function intentionally permits anonymous `GET /public/<token>` requests,
while authenticating every POST action inside the handler.

Required secrets:

```text
CF_SERVICE_URL=https://<fastapi-host>
SHARE_WEB_BASE_URL=https://<pages-project>.pages.dev
SHARE_WEB_ALLOWED_ORIGINS=https://<pages-project>.pages.dev
```

Deploy with JWT verification disabled so the public read route can execute:

```powershell
supabase functions deploy trip-share --no-verify-jwt
```

The function still validates a Supabase access token for `create`, `list`,
`revoke`, and `copy` actions. The public token is a bearer credential and only
its SHA-256 hash is stored in PostgreSQL.
