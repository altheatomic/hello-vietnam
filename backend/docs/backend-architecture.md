# Backend Architecture

## Chosen structure

This project should use a feature-first modular monolith on Supabase.

That means:

- the database is the core backend runtime
- schema changes are tracked in `supabase/migrations/`
- privileged workflows live in `supabase/functions/`
- modules are split by business domain, not by technical layer

## Why this structure fits this repo

The Flutter app already follows a feature-first structure under `frontend/lib/features/`.
The backend should mirror that language so the team can move faster:

- `forum` in Flutter maps to `forum` in backend
- `planner` in Flutter maps to `planner` in backend
- `profile` and `auth` map to `users` and `auth`
- `admin` stays isolated from user-facing modules

## Backend module map

### `auth`

Responsibility:
- sign-up hooks
- sign-in related server logic
- secure role and identity flows

Database:
- `user_account`
- auth-related policies

### `users`

Responsibility:
- profile
- settings
- accessibility
- account lifecycle

Database:
- `user_contact`
- `user_accessibility`
- `user_setting`
- `favorite`

### `content`

Responsibility:
- cities
- places
- food
- phrases
- popular apps

Database:
- `city_province`
- `place_subcategory`
- `place`
- `place_address`
- `place_rating`
- `food`
- `phrases`
- `use_popular_app`

### `forum`

Responsibility:
- topic, post, comment
- report and moderation
- saved content and notifications

Database:
- `forum_topic`
- `forum_post`
- `forum_comment`
- `report`
- related `notification`

### `planner`

Responsibility:
- trip plans
- day breakdowns
- business trip flow

Database:
- `plan`
- `plan_component`

### `recommendation`

Responsibility:
- recommendation rules
- AI or ranking workflows
- search enrichment

Database:
- `hobby`
- `ai_identification`
- cross-feature query views

### `payments`

Responsibility:
- plans
- vouchers
- payments
- premium status

Database:
- `subscription_plan`
- `feature_entitlement`
- `voucher`
- `voucher_grant`
- `voucher_redemption`
- `premium_subscription`
- `payment`

### `notifications`

Responsibility:
- in-app delivery
- push delivery
- reminders

Database:
- `notification`

### `admin`

Responsibility:
- canned replies
- dashboard summaries
- moderation commands

Database:
- `canned_replies`
- admin-facing views and RPCs

## Folder rules

### Database

- One migration per concern.
- Use descriptive names such as `add_forum_post_status_index`.
- Prefer additive migrations.
- Avoid one huge migration touching unrelated features.

### Edge Functions

Each function folder should stay feature-scoped:

```txt
supabase/functions/forum/
  create-post/
  report-post/
  moderate-post/
```

Shared helpers go in:

```txt
supabase/functions/_shared/
```

### SQL conventions

When the project grows, keep extra SQL grouped by concern:

```txt
supabase/sql/
  policies/
    forum.sql
    planner.sql
  rpc/
    forum.sql
    payments.sql
  views/
    admin.sql
    recommendations.sql
```

## Decision rules

Use:

- table constraints for data integrity
- RLS for row access
- SQL functions and views for reusable database logic
- Edge Functions for sensitive multi-step workflows

Avoid:

- putting payment or moderation logic in the Flutter client
- mixing unrelated domains in the same migration
- creating a generic `services/` bucket for everything

## Next cleanup steps

1. Move future schema work into feature-scoped migrations under `supabase/migrations/`.
2. Add RLS policies for all exposed tables before production use.
3. Split the current large schema into follow-up migrations by domain once the team is ready.
4. Add seed data only for stable reference tables.
