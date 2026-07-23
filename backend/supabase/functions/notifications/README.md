# Android push notification deployment

The app stores notifications in `public.notification` first. A database
trigger created by migration `20260723000100_notification_dispatch_webhook.sql`
uses `pg_net` to invoke `notification-dispatch`, which delivers Android push
notifications through Firebase Cloud Messaging (FCM HTTP v1).

## 1. Firebase Android configuration

1. Create a Firebase Android app whose package is
   `com.example.hellovietnam`.
2. Download `google-services.json` and place it at
   `frontend/android/app/google-services.json`.
3. In Firebase Console, create a service-account private key JSON file.
4. Do not commit either JSON file. The Android config path is ignored by Git.

## 2. Database and secrets

Run from `backend`:

```powershell
npx supabase db push --include-all
npx supabase secrets set FIREBASE_PROJECT_ID="<project_id from service-account JSON>"
npx supabase secrets set FIREBASE_CLIENT_EMAIL="<client_email from service-account JSON>"
npx supabase secrets set FIREBASE_PRIVATE_KEY="<private_key with literal \n sequences>"
npx supabase secrets set NOTIFICATION_DISPATCH_SECRET="<at least 32 random characters>"
```

The Firebase private key and dispatch secret must only exist in Supabase
Secrets. Never add them to Dart files, `.env` files committed to Git, or the
Flutter build command.

The same `NOTIFICATION_DISPATCH_SECRET` value must also be stored in Supabase
Vault under the name `notification_dispatch_secret`. The database trigger
reads it at runtime, so the value is never embedded in a migration.

## 3. Deploy Edge Functions

```powershell
npx supabase functions deploy notifications --use-api
npx supabase functions deploy notification-dispatch --use-api --no-verify-jwt
```

`notification-dispatch` disables Supabase JWT verification so `pg_net` can
call it, but the function still requires its own constant-time checked
internal secret.

## 4. Verify automatic dispatch

No Dashboard webhook is required. After the database migration is applied,
verify that the automatic dispatcher exists:

```sql
select to_regprocedure('public.dispatch_notification_webhook()');

select tgname
from pg_trigger
where tgname = 'trg_dispatch_notification_webhook';
```

The trigger runs only for new rows where `is_push = true` and
`status = 'queued'`. If the Vault secret or network call is temporarily
unavailable, the notification row is still preserved for in-app display.

## 5. Smoke test

Use a real test user's UUID in Supabase SQL Editor:

```sql
select public.enqueue_user_notification(
  '<test-user-uuid>'::uuid,
  'account',
  'Push notification test',
  'Android delivery is configured correctly.',
  'badge',
  jsonb_build_object('kind', 'upgradeAccount'),
  true
);
```

Verify that:

1. A row appears in `public.notification` and in the app inbox.
2. An active Android installation exists in `public.user_push_device`.
3. The notification status becomes `sent`.
4. Tapping the Android notification opens Upgrade Account.

If no Android token exists, sign in on a physical Android device after adding
`google-services.json`, allow notification permission, then retry the SQL.
