# Stripe Sandbox payment runbook

This project intentionally uses Stripe **test mode**. The payment flow must not
be presented as production billing and must never receive a live Stripe key.

## Security model

- `subscription-payment` requires a valid Supabase user JWT.
- Prices, discounts, callback URLs, and the payment owner are resolved by the
  server. The Flutter client only sends the plan, optional voucher, platform,
  and (for web) an allow-listed origin.
- Stripe Checkout is created with an idempotency key tied to `payment_attempt`.
- Premium is granted only after Stripe reports a paid Checkout Session whose
  user, attempt, amount, currency, and Session ID match the server snapshot.
- `finalize_verified_payment` atomically writes the payment and subscription.
  Replaying the app callback or webhook returns the existing result.
- `stripe-webhook` has no Supabase JWT requirement because Stripe calls it, but
  it verifies the raw request body with `STRIPE_WEBHOOK_SECRET` before parsing.
- The app callback is only a recovery/UX path. The signed webhook is the
  authoritative asynchronous completion path.

## Required secrets

Configure these as Supabase Edge Function secrets, never in Flutter assets,
source control, screenshots, logs, or a live demo:

```text
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
CHECKOUT_ALLOWED_WEB_ORIGINS=http://localhost:3000
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are supplied
by Supabase to deployed functions. `CHECKOUT_ALLOWED_WEB_ORIGINS` is a
comma-separated list of exact origins, with no path or trailing slash.

For a hosted admin/client, replace or extend localhost with its exact HTTPS
origin. Never use `*`.

## Deployment order

Run from the repository root after linking the intended Supabase project:

```powershell
npx --yes supabase@2.110.0 db push --linked --workdir backend --dry-run
npx --yes supabase@2.110.0 db push --linked --workdir backend --dry-run --include-all
npx --yes supabase@2.110.0 db push --linked --workdir backend --include-all
npx --yes supabase@2.110.0 functions deploy subscription-payment --workdir backend
npx --yes supabase@2.110.0 functions deploy stripe-webhook --no-verify-jwt --workdir backend
```

The linked project currently reports two older local migrations before the
Stripe migrations:

- `20260724000100_add_old_province_description_en.sql`
- `20260727000100_migrate_province_cover_image_to_old_province.sql`

That is why the reviewed command uses `--include-all`. Do not run the
non-dry-run command until its list contains only those two reviewed migrations
and the three Stripe migrations. The cover-image migration performs a partial
name-based backfill, so verify its match/unmatched counts for the target
database first.

Deploy `subscription-payment` with JWT verification enabled (the default).
Deploy only `stripe-webhook` with `--no-verify-jwt`.

In Stripe Dashboard test mode, register:

```text
https://<project-ref>.supabase.co/functions/v1/stripe-webhook
```

Subscribe only to:

- `checkout.session.completed`
- `checkout.session.expired`

Copy that endpoint's test-mode signing secret into
`STRIPE_WEBHOOK_SECRET`. Keep the Stripe account in test mode and use only
Stripe test cards.

## Smoke test

1. Sign in as a non-Premium test user.
2. Open Upgrade Account and confirm the UI says `TEST MODE · No real charge`.
3. Start one Checkout using a Stripe test card.
4. Confirm the deep link returns to `com.hellovietnam.app`.
5. Verify Premium becomes active once and loyalty points are awarded once.
6. Reopen the same callback URL or press retry. Verify no duplicate payment,
   subscription, or loyalty transaction is created.
7. Cancel one Checkout and allow one Checkout to expire. Verify neither grants
   Premium.
8. Send a webhook with an invalid signature. Verify it receives HTTP 400.
9. Sign in as a second user and try the first user's Session ID. Verify it is
   rejected.

Useful read-only checks:

```sql
select provider, external_ref, count(*)
from payment
where provider = 'stripe'
group by provider, external_ref
having count(*) > 1;

select stripe_session_id, count(*)
from payment_attempt
where stripe_session_id is not null
group by stripe_session_id
having count(*) > 1;

select status, count(*)
from payment_attempt
group by status
order by status;
```

The first two queries must return no rows.

## Incident response

- Do not re-enable either legacy client-callable purchase RPC.
- If checkout must be stopped, roll back the Edge Function release or rotate
  the Stripe test key. Do not delete payment/subscription rows.
- A failed app callback is safe to retry with the same Session ID.
- For webhook failures, fix the endpoint/secret and use Stripe Dashboard test
  mode to resend the event. Atomic finalization makes resends idempotent.
- Database migrations are additive and contain security revocations. Do not
  reverse them on a database that has recorded payments without a reviewed
  data migration.
