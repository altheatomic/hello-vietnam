# Edge Functions

Use one folder per business capability that requires privileged, server-side logic.

## Rules

- Keep each function small and feature-scoped.
- Put shared helpers in `_shared/`.
- Prefer database constraints, RLS, views, and SQL functions first.
- Use Edge Functions for workflows like payments, moderation, AI processing, or scheduled jobs.

## Suggested folders

- `auth/`
- `users/`
- `forum/`
- `planner/`
- `recommendation/`
- `payments/`
- `notifications/`
- `admin/`
