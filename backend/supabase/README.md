# Supabase Backend

This project uses a feature-first backend structure on top of Supabase.

## Source of truth

- Database schema: `supabase/migrations/`
- Seed data: `supabase/seed.sql`
- Edge Functions: `supabase/functions/`
- Access rules and SQL conventions: [docs/backend-architecture.md](../docs/backend-architecture.md)

## Recommended workflow

1. Initialize the local Supabase project if needed: `supabase init`
2. Create schema changes with: `supabase migration new <name>`
3. Keep each migration scoped to one feature or one concern.
4. Put privileged or multi-step business logic in `supabase/functions/<feature>/`.
5. Treat `db/db.sql` as a legacy schema snapshot until everything has been migrated and reviewed.

## Deploy admin-food Edge Function

This repo deploys the function from `functions/admin-food/` (Supabase default
layout), including its business logic.

From `backend/`, run:

```powershell
supabase login
supabase link --project-ref ziouozppetvvdrzgojcx
supabase functions deploy admin-food --use-api
```

After deploy, verify `admin-food` appears in Dashboard -> Edge Functions.

## Feature map

- `auth` and `users`: account, profile, settings, permissions
- `content`: cities, places, food, phrases, popular apps
- `forum`: topics, posts, comments, moderation
- `planner`: trip plans and plan components
- `recommendation`: recommendation logic and AI-assisted flows
- `payments`: subscriptions, vouchers, payments
- `notifications`: in-app and push delivery
- `admin`: moderation and operational tools
