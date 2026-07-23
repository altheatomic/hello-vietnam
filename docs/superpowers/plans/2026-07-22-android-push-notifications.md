# Android Push Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the mock notification flow with a Supabase-backed inbox and deliver Android push notifications through Firebase Cloud Messaging for loyalty, forum, voucher, trip, and account events.

**Architecture:** Supabase remains the source of truth: domain events insert a durable row into `public.notification`, while an internal Edge Function claims queued rows and sends them through FCM HTTP v1. Flutter reads the same rows through an authenticated Edge Function, registers the current Android installation token, renders foreground notifications locally, and routes notification taps through the existing `NotificationTarget` handler.

**Tech Stack:** PostgreSQL/Supabase migrations and RLS, Supabase Edge Functions (Deno/TypeScript), Firebase Cloud Messaging HTTP v1, Flutter 3.41/Dart 3.11, `firebase_core ^4.12.1`, `firebase_messaging ^16.4.3`, `flutter_local_notifications ^22.1.0`, GoRouter, Flutter Test.

## Global Constraints

- Android push only; iOS and Firebase Web Push remain out of scope.
- Keep Flutter Web and admin builds working without Firebase Web configuration.
- Never place Firebase service-account credentials or FCM server credentials in Flutter.
- `google-services.json` stays local at `frontend/android/app/google-services.json` and must not be committed.
- Users may read and mutate only their own notifications, devices, and preferences; dispatch uses service-role access.
- Supported notification types are exactly `all`, `loyalty`, `forum`, `voucher`, `trip`, and `account`, where `all` is preference-only.
- Turning push off does not delete or hide existing in-app notification history.
- Existing `NotificationTarget` payload shape remains the single navigation contract.
- Preserve unrelated dirty worktree changes, especially `frontend/lib/app/router.dart` and current forum optimization files.
- No direct FCM calls from feature-specific Flutter code or database clients.

---

## File Map

### Database and backend

- Create `backend/supabase/migrations/20260722000100_android_push_notifications.sql`: schema extensions, RLS, indexes, preference defaults, notification enqueue helper, and durable event triggers.
- Create `backend/supabase/tests/android_push_notifications_test.sql`: SQL assertions for ownership, preference defaults, and event-to-notification mapping.
- Create `backend/supabase/functions/_shared/firebase_messaging.ts`: service-account JWT/OAuth exchange and FCM HTTP v1 request mapping.
- Create `backend/supabase/functions/_shared/firebase_messaging_test.ts`: deterministic signing/request/error parsing tests using injected dependencies.
- Create `backend/supabase/functions/notifications/index.ts`: authenticated client API entrypoint.
- Create `backend/supabase/functions/notifications/notification_handler.ts`: device, inbox, unread, read-state, and preference actions.
- Create `backend/supabase/functions/notifications/notification_handler_test.ts`: action/auth/validation tests with fake Supabase gateways.
- Create `backend/supabase/functions/notifications/deno.json`: function import configuration.
- Create `backend/supabase/functions/notification-dispatch/index.ts`: internal webhook/API entrypoint.
- Create `backend/supabase/functions/notification-dispatch/notification_dispatch_handler.ts`: claim, preference evaluation, multi-device send, token cleanup, and status update.
- Create `backend/supabase/functions/notification-dispatch/notification_dispatch_handler_test.ts`: idempotency, opt-out, partial failure, and invalid-token tests.
- Create `backend/supabase/functions/notification-dispatch/deno.json`: function import configuration.
- Create `backend/supabase/functions/notifications/README.md`: exact Firebase, secret, webhook, deployment, and smoke-test instructions.

### Flutter and Android

- Modify `frontend/pubspec.yaml`: add Firebase Messaging and local-notification dependencies.
- Modify `frontend/android/settings.gradle.kts`: register the Google Services Gradle plugin.
- Modify `frontend/android/app/build.gradle.kts`: apply Google Services to the Android app.
- Modify `frontend/android/app/src/main/AndroidManifest.xml`: add Android 13 notification permission and default channel metadata.
- Modify `frontend/.gitignore`: ignore `android/app/google-services.json` if not already ignored.
- Create `frontend/lib/features/notification/domain/notification_preference.dart`: immutable preference model and master/type effective-state logic.
- Modify `frontend/lib/features/notification/domain/app_notification.dart`: add loyalty type/filter and robust server payload parsing.
- Replace `frontend/lib/features/notification/data/notification_repository.dart`: production repository interface and Supabase implementation; retain a fake only inside tests.
- Create `frontend/lib/features/notification/data/notification_api.dart`: typed calls to the `notifications` Edge Function.
- Create `frontend/lib/features/notification/application/notification_inbox_controller.dart`: paged inbox, refresh, unread count, and read mutations.
- Create `frontend/lib/features/notification/application/push_notification_service.dart`: Android-only Firebase lifecycle, token registration, foreground display, token refresh, and pending tap queue.
- Create `frontend/lib/features/notification/application/notification_tap_router.dart`: parse payload and call the existing `NotificationActionHandler` once navigation is ready.
- Create `frontend/lib/features/notification/presentation/notification_settings_page.dart`: master and per-type switches.
- Modify `frontend/lib/features/notification/presentation/notification_page.dart`: use real paging/controller and load-more states.
- Modify `frontend/lib/features/notification/presentation/notification_controller.dart`: delegate to the production inbox controller or remove obsolete mock state.
- Modify `frontend/lib/features/home/presentation/home_page.dart`: bind bell badge to real unread state.
- Modify `frontend/lib/features/profile/presentation/profile_page.dart`: make Notification open the settings page.
- Modify `frontend/lib/features/loyalty/presentation/loyalty_page.dart`: use the server `loyalty` preference instead of SharedPreferences.
- Modify `frontend/lib/features/loyalty/data/loyalty_award_service.dart`: remove mock notification insertion.
- Modify `frontend/lib/core/auth/auth_repository.dart`: deactivate the current installation token before sign-out.
- Modify `frontend/lib/app/app_bootstrap.dart`: initialize push after core services and session restoration.
- Modify `frontend/lib/app/router.dart`: add the notification-settings route and drain pending notification taps after router readiness.
- Create focused tests under `frontend/test/features/notification/` and update existing home/profile/loyalty tests.

---

### Task 1: Add the durable notification schema and security boundary

**Files:**
- Create: `backend/supabase/migrations/20260722000100_android_push_notifications.sql`
- Create: `backend/supabase/tests/android_push_notifications_test.sql`

**Interfaces:**
- Produces SQL function `public.enqueue_user_notification(p_id_user uuid, p_notification_type text, p_title text, p_body text, p_icon text, p_target jsonb, p_is_push boolean default true) returns uuid`.
- Produces tables `public.user_push_device` and `public.user_notification_preference`.
- Produces helper `public.notification_push_enabled(p_id_user uuid, p_notification_type text) returns boolean`.

- [ ] **Step 1: Write failing pgTAP coverage for schema, defaults, and ownership**

Create a transaction-scoped SQL test that asserts the new tables/functions exist, notification types reject unsupported values, and a user preference is effectively enabled when no row exists:

```sql
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

select has_table('public', 'user_push_device');
select has_table('public', 'user_notification_preference');
select has_function('public', 'enqueue_user_notification', array['uuid', 'text', 'text', 'text', 'text', 'jsonb', 'boolean']);
select has_function('public', 'notification_push_enabled', array['uuid', 'text']);
select col_is_pk('public', 'user_push_device', 'id_device');
select col_is_pk('public', 'user_notification_preference', array['id_user', 'notification_type']);
select ok(
  public.notification_push_enabled('00000000-0000-0000-0000-000000000001', 'forum'),
  'missing preferences default to enabled'
);
select throws_ok(
  $$insert into public.user_notification_preference(id_user, notification_type) values ('00000000-0000-0000-0000-000000000001', 'marketing')$$,
  '23514'
);

select * from finish();
rollback;
```

- [ ] **Step 2: Run the SQL test and verify it fails before the migration**

Run from `backend` with local Supabase running:

```powershell
npx supabase test db supabase/tests/android_push_notifications_test.sql
```

Expected: FAIL because `user_push_device` and `user_notification_preference` do not exist.

- [ ] **Step 3: Implement tables, constraints, indexes, RLS, helpers, and updated-at triggers**

The migration must:

```sql
alter table public.notification
  add column if not exists notification_type text,
  add column if not exists icon text,
  add column if not exists push_error text;

update public.notification
set notification_type = coalesce(notification_type, 'account'),
    status = coalesce(status, 'in_app_only');

alter table public.notification
  alter column notification_type set not null,
  alter column status set default 'queued';

alter table public.notification drop constraint if exists notification_notification_type_check;
alter table public.notification add constraint notification_notification_type_check
  check (notification_type in ('loyalty', 'forum', 'voucher', 'trip', 'account'));

alter table public.notification drop constraint if exists notification_status_check;
alter table public.notification add constraint notification_status_check
  check (status in ('queued', 'processing', 'sent', 'partial', 'failed', 'in_app_only'));

create table if not exists public.user_push_device (
  id_device uuid primary key default extensions.uuid_generate_v4(),
  id_user uuid not null references public.user_account(id_user) on delete cascade,
  fcm_token text not null unique,
  platform text not null check (platform in ('android', 'ios', 'web')),
  installation_id text not null,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id_user, installation_id)
);

create table if not exists public.user_notification_preference (
  id_user uuid not null references public.user_account(id_user) on delete cascade,
  notification_type text not null check (notification_type in ('all', 'loyalty', 'forum', 'voucher', 'trip', 'account')),
  push_enabled boolean not null default true,
  in_app_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (id_user, notification_type)
);

create index if not exists idx_notification_user_created
  on public.notification (id_user, created_at desc);
create index if not exists idx_notification_user_unread
  on public.notification (id_user, created_at desc) where read_at is null;
create index if not exists idx_notification_dispatch_queue
  on public.notification (status, created_at) where status = 'queued';
create index if not exists idx_user_push_device_active
  on public.user_push_device (id_user, is_active) where is_active;

alter table public.notification enable row level security;
alter table public.user_push_device enable row level security;
alter table public.user_notification_preference enable row level security;

drop policy if exists "Users read own notifications" on public.notification;
create policy "Users read own notifications" on public.notification
for select to authenticated using (id_user = auth.uid());

drop policy if exists "Users update own notifications" on public.notification;
create policy "Users update own notifications" on public.notification
for update to authenticated using (id_user = auth.uid()) with check (id_user = auth.uid());

drop policy if exists "Users manage own push devices" on public.user_push_device;
create policy "Users manage own push devices" on public.user_push_device
for all to authenticated using (id_user = auth.uid()) with check (id_user = auth.uid());

drop policy if exists "Users manage own notification preferences" on public.user_notification_preference;
create policy "Users manage own notification preferences" on public.user_notification_preference
for all to authenticated using (id_user = auth.uid()) with check (id_user = auth.uid());
```

Implement helpers as `security definer` with explicit `search_path = public, extensions`, validate the type before insert, default missing master/type preferences to enabled, and revoke direct execution from `anon` where appropriate.

- [ ] **Step 4: Run SQL tests and inspect migration locally**

```powershell
npx supabase db reset
npx supabase test db supabase/tests/android_push_notifications_test.sql
```

Expected: migration succeeds and all 8 pgTAP assertions pass.

- [ ] **Step 5: Commit the schema boundary**

```powershell
git add backend/supabase/migrations/20260722000100_android_push_notifications.sql backend/supabase/tests/android_push_notifications_test.sql
git commit -m "feat: add push notification schema"
```

### Task 2: Build and test the shared Firebase HTTP v1 client

**Files:**
- Create: `backend/supabase/functions/_shared/firebase_messaging.ts`
- Create: `backend/supabase/functions/_shared/firebase_messaging_test.ts`

**Interfaces:**
- Produces `FirebaseCredentials { projectId: string; clientEmail: string; privateKey: string }`.
- Produces `sendFcmMessage(input: FcmSendInput, dependencies?: FirebaseDependencies): Promise<FcmSendResult>`.
- Produces `isPermanentTokenError(result: FcmSendResult): boolean`.

- [ ] **Step 1: Write failing tests for OAuth reuse, request payload, and invalid tokens**

Tests inject `fetch`, `now`, and `signJwt` so they do not access real Firebase. Cover:

```ts
Deno.test("sendFcmMessage posts a data notification through HTTP v1", async () => {
  const calls: Array<{ url: string; init: RequestInit }> = [];
  const result = await sendFcmMessage(
    {
      token: "device-token",
      title: "New reply",
      body: "Someone replied to your post",
      data: { id_notification: "notification-id", notification_type: "forum" },
      credentials: {
        projectId: "hello-vietnam",
        clientEmail: "firebase@example.test",
        privateKey: "test-key",
      },
    },
    {
      now: () => 1_700_000_000_000,
      signJwt: async () => "signed-jwt",
      fetch: async (url, init) => {
        calls.push({ url: String(url), init: init ?? {} });
        if (String(url).includes("oauth2.googleapis.com")) {
          return Response.json({ access_token: "oauth-token", expires_in: 3600 });
        }
        return Response.json({ name: "projects/hello-vietnam/messages/1" });
      },
    },
  );
  assertEquals(result.ok, true);
  assertEquals(calls[1].url, "https://fcm.googleapis.com/v1/projects/hello-vietnam/messages:send");
});

Deno.test("isPermanentTokenError recognizes unregistered tokens", () => {
  assertEquals(isPermanentTokenError({ ok: false, status: 404, code: "UNREGISTERED", message: "gone" }), true);
});
```

- [ ] **Step 2: Run the shared tests and verify the missing module failure**

```powershell
deno test backend/supabase/functions/_shared/firebase_messaging_test.ts --allow-env
```

Expected: FAIL because `firebase_messaging.ts` does not exist.

- [ ] **Step 3: Implement JWT assertion, OAuth cache, FCM payload, and error normalization**

Use RS256 Web Crypto signing, replace escaped `\\n` in the private key, request OAuth scope `https://www.googleapis.com/auth/firebase.messaging`, cache the token until 60 seconds before expiry, and send Android high-priority payloads to:

```ts
const endpoint = `https://fcm.googleapis.com/v1/projects/${credentials.projectId}/messages:send`;
const payload = {
  message: {
    token: input.token,
    notification: { title: input.title, body: input.body },
    data: input.data,
    android: {
      priority: "HIGH",
      notification: { channel_id: "hello_vietnam_updates", sound: "default" },
    },
  },
};
```

Return normalized `FcmSendResult` instead of throwing for FCM 4xx/5xx responses so dispatch can distinguish partial delivery from function failure.

- [ ] **Step 4: Run shared Firebase tests**

```powershell
deno test backend/supabase/functions/_shared/firebase_messaging_test.ts --allow-env
```

Expected: all Firebase client tests pass without network access.

- [ ] **Step 5: Commit the shared sender**

```powershell
git add backend/supabase/functions/_shared/firebase_messaging.ts backend/supabase/functions/_shared/firebase_messaging_test.ts
git commit -m "feat: add Firebase messaging client"
```

### Task 3: Implement the authenticated notification client API

**Files:**
- Create: `backend/supabase/functions/notifications/index.ts`
- Create: `backend/supabase/functions/notifications/notification_handler.ts`
- Create: `backend/supabase/functions/notifications/notification_handler_test.ts`
- Create: `backend/supabase/functions/notifications/deno.json`

**Interfaces:**
- Consumes authenticated `User` and a user-scoped Supabase client from `auth_guard.ts`.
- Produces JSON actions `register-device`, `unregister-device`, `list`, `unread-count`, `mark-read`, `mark-all-read`, `get-preferences`, and `update-preference`.
- `list` returns `{ items: NotificationRow[]; nextCursor: string | null }` with cursor `<created_at>|<id_notification>`.

- [ ] **Step 1: Write handler tests against an injected `NotificationGateway`**

Cover token ownership/upsert, cursor validation, max page size 50, own-user read mutation, six preference rows, and unsupported action/type errors. The gateway contract is:

```ts
export interface NotificationGateway {
  registerDevice(input: RegisterDeviceInput): Promise<void>;
  unregisterDevice(userId: string, installationId: string): Promise<void>;
  list(userId: string, limit: number, cursor: NotificationCursor | null): Promise<NotificationPage>;
  unreadCount(userId: string): Promise<number>;
  markRead(userId: string, notificationId: string): Promise<boolean>;
  markAllRead(userId: string): Promise<number>;
  getPreferences(userId: string): Promise<NotificationPreferenceRow[]>;
  updatePreference(input: UpdatePreferenceInput): Promise<NotificationPreferenceRow>;
}
```

- [ ] **Step 2: Run handler tests and verify failure**

```powershell
deno test backend/supabase/functions/notifications/notification_handler_test.ts --allow-env
```

Expected: FAIL because the handler and gateway do not exist.

- [ ] **Step 3: Implement validation and action routing**

`handleNotificationRequest` accepts `{ request, user, gateway }`, parses a JSON object, enforces:

```ts
const supportedTypes = new Set(["all", "loyalty", "forum", "voucher", "trip", "account"]);
const limit = Math.min(Math.max(Number(body.limit ?? 20), 1), 50);
```

`get-preferences` merges missing rows with enabled defaults. `register-device` accepts only `android` for this release while retaining the database enum for future clients. Never accept `id_user` from the request body.

- [ ] **Step 4: Implement the Supabase gateway and function entrypoint**

The entrypoint must handle CORS, authenticate with the existing auth guard, create a user-scoped Supabase client, and map domain errors to stable HTTP statuses:

```ts
if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
const auth = await requireUser(request);
const result = await handleNotificationRequest({
  request,
  user: auth.user,
  gateway: createSupabaseNotificationGateway(auth.client),
});
return Response.json(result.body, { status: result.status, headers: corsHeaders });
```

- [ ] **Step 5: Run client API tests**

```powershell
deno test backend/supabase/functions/notifications/notification_handler_test.ts --allow-env
```

Expected: all notification API tests pass.

- [ ] **Step 6: Commit the authenticated API**

```powershell
git add backend/supabase/functions/notifications
git commit -m "feat: add notification client API"
```

### Task 4: Implement idempotent notification dispatch

**Files:**
- Create: `backend/supabase/functions/notification-dispatch/index.ts`
- Create: `backend/supabase/functions/notification-dispatch/notification_dispatch_handler.ts`
- Create: `backend/supabase/functions/notification-dispatch/notification_dispatch_handler_test.ts`
- Create: `backend/supabase/functions/notification-dispatch/deno.json`

**Interfaces:**
- Consumes `sendFcmMessage` from Task 2.
- Consumes `{ id_notification: string }` or a Supabase Database Webhook payload whose `record.id_notification` is present.
- Produces `{ status: 'sent' | 'partial' | 'failed' | 'in_app_only' | 'already_processed'; sent: number; failed: number }`.

- [ ] **Step 1: Write failing dispatch behavior tests**

Use a fake `DispatchGateway` with these exact methods:

```ts
export interface DispatchGateway {
  claim(notificationId: string): Promise<DispatchNotification | null>;
  isPushEnabled(userId: string, type: NotificationType): Promise<boolean>;
  activeDevices(userId: string): Promise<PushDevice[]>;
  deactivateTokens(tokens: string[]): Promise<void>;
  complete(notificationId: string, result: DispatchCompletion): Promise<void>;
}
```

Tests must prove: a second claim does not resend, disabled master/type ends as `in_app_only`, no devices ends as `in_app_only`, all successes become `sent`, mixed results become `partial`, all failures become `failed`, and `UNREGISTERED` tokens are deactivated.

- [ ] **Step 2: Run dispatch tests and verify failure**

```powershell
deno test backend/supabase/functions/notification-dispatch/notification_dispatch_handler_test.ts --allow-env
```

Expected: FAIL because dispatch handler is missing.

- [ ] **Step 3: Implement the dispatch state machine**

Implement `dispatchNotification` so `claim` atomically updates only `status = 'queued'` to `processing`. Build string-only FCM data:

```ts
const data = {
  id_notification: notification.id,
  notification_type: notification.type,
  target: JSON.stringify(notification.target ?? {}),
};
```

Send devices with a concurrency cap of 5, redact tokens from logs, collect permanent-token failures, and always finalize claimed notifications.

- [ ] **Step 4: Implement internal authorization and webhook parsing**

`index.ts` must accept either `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>` or `x-notification-secret` matching `NOTIFICATION_DISPATCH_SECRET`. Reject absent/mismatched credentials with 401 before reading notification data.

- [ ] **Step 5: Run dispatch and shared tests**

```powershell
deno test backend/supabase/functions/_shared/firebase_messaging_test.ts backend/supabase/functions/notification-dispatch/notification_dispatch_handler_test.ts --allow-env
```

Expected: all tests pass.

- [ ] **Step 6: Commit dispatch**

```powershell
git add backend/supabase/functions/notification-dispatch backend/supabase/functions/_shared/firebase_messaging.ts
git commit -m "feat: dispatch queued notifications through FCM"
```

### Task 5: Connect real domain events to the shared notification outbox

**Files:**
- Modify: `backend/supabase/migrations/20260722000100_android_push_notifications.sql`
- Modify: `backend/supabase/tests/android_push_notifications_test.sql`

**Interfaces:**
- Consumes `public.enqueue_user_notification(...)` from Task 1.
- Produces one notification row for known loyalty, forum, voucher, trip, and account events without direct FCM calls.

- [ ] **Step 1: Extend SQL tests with one representative trigger per type**

Add fixture inserts in a rolled-back transaction and assert the resulting row has the expected recipient/type and a `payload_jsonb.target.kind` supported by Flutter. Required mappings:

| Source event | Recipient | Type | Target kind |
| --- | --- | --- | --- |
| approved loyalty transaction | transaction user | `loyalty` | `loyaltyRewards` |
| forum comment/reply | post author, excluding self | `forum` | `forumPost` |
| voucher wallet grant | wallet owner | `voucher` | `voucherCenter` |
| generated/saved plan | plan owner | `trip` | `tripPlannerSaved` |
| successful subscription/payment | subscriber | `account` | `upgradeAccount` |

- [ ] **Step 2: Run pgTAP and verify event assertions fail**

```powershell
npx supabase test db supabase/tests/android_push_notifications_test.sql
```

Expected: base schema tests pass and new event assertions fail because triggers are absent.

- [ ] **Step 3: Add narrowly scoped trigger functions**

Each trigger function must call only `enqueue_user_notification`, avoid self-notifications for forum, guard state transitions so updates do not duplicate sends, and use `jsonb_build_object('kind', ..., 'entityId', ...)` for targets. Attach triggers only after confirming the exact current table/column names in the migration history; do not invent compatibility aliases.

- [ ] **Step 4: Re-run all SQL tests**

```powershell
npx supabase db reset
npx supabase test db supabase/tests/android_push_notifications_test.sql
```

Expected: all schema and five event-family assertions pass.

- [ ] **Step 5: Commit event producers**

```powershell
git add backend/supabase/migrations/20260722000100_android_push_notifications.sql backend/supabase/tests/android_push_notifications_test.sql
git commit -m "feat: enqueue notifications from domain events"
```

### Task 6: Replace Flutter mock data with a typed Supabase repository

**Files:**
- Create: `frontend/lib/features/notification/domain/notification_preference.dart`
- Modify: `frontend/lib/features/notification/domain/app_notification.dart`
- Create: `frontend/lib/features/notification/data/notification_api.dart`
- Replace: `frontend/lib/features/notification/data/notification_repository.dart`
- Create: `frontend/lib/features/notification/application/notification_inbox_controller.dart`
- Create: `frontend/test/features/notification/data/notification_repository_test.dart`
- Create: `frontend/test/features/notification/application/notification_inbox_controller_test.dart`
- Modify: `frontend/test/features/notification/presentation/notification_page_test.dart`

**Interfaces:**
- Produces `NotificationRepository` with `fetchPage`, `unreadCount`, `markRead`, `markAllRead`, device operations, and preference operations.
- Produces `NotificationInboxController extends ChangeNotifier` with `items`, `isInitialLoading`, `isLoadingMore`, `hasMore`, `unreadCount`, `loadInitial()`, `loadMore()`, `refresh()`, `markRead()`, and `markAllRead()`.

- [ ] **Step 1: Write model/repository tests for server rows and preference merging**

Use a fake `NotificationApi` and verify server snake_case maps to existing domain objects, unknown icon falls back safely, loyalty parses correctly, and page cursors are preserved:

```dart
expect(page.items.single.type, AppNotificationType.loyalty);
expect(page.items.single.target.kind, NotificationTargetKind.loyaltyRewards);
expect(page.nextCursor, '2026-07-22T10:00:00Z|notification-1');
```

- [ ] **Step 2: Run focused Flutter tests and verify failure**

```powershell
cd frontend
flutter test test/features/notification/data/notification_repository_test.dart test/features/notification/application/notification_inbox_controller_test.dart
```

Expected: FAIL because production repository/controller contracts are missing.

- [ ] **Step 3: Implement robust domain parsing and preference logic**

Add `loyalty` to `AppNotificationType` and `NotificationFilter`. Parse date labels from `created_at` in Flutter rather than trusting backend display text. `NotificationPreference.effectivePushEnabled(master)` must be `master.pushEnabled && pushEnabled`; in-app history remains governed separately.

- [ ] **Step 4: Implement Edge Function API adapter and repository**

`NotificationApi.invoke` calls:

```dart
final response = await Supabase.instance.client.functions.invoke(
  'notifications',
  body: <String, dynamic>{'action': action, ...body},
);
```

Normalize `FunctionException` into a feature exception without leaking tokens or raw authorization headers. The repository maps the typed response and has no mock singleton.

- [ ] **Step 5: Implement controller pagination and stale-request protection**

Use a monotonically increasing request generation so a late refresh cannot overwrite newer state. Dedupe by notification ID and permit only one load-more request at a time.

- [ ] **Step 6: Run notification repository/controller/widget tests**

```powershell
flutter test test/features/notification
```

Expected: all notification tests pass.

- [ ] **Step 7: Commit the real Flutter data layer**

```powershell
git add frontend/lib/features/notification frontend/test/features/notification
git commit -m "feat: load notifications from Supabase"
```

### Task 7: Add Android Firebase bootstrap, token lifecycle, and foreground notifications

**Files:**
- Modify: `frontend/pubspec.yaml`
- Modify: `frontend/android/settings.gradle.kts`
- Modify: `frontend/android/app/build.gradle.kts`
- Modify: `frontend/android/app/src/main/AndroidManifest.xml`
- Modify: `frontend/.gitignore`
- Create: `frontend/lib/features/notification/application/push_notification_service.dart`
- Create: `frontend/test/features/notification/application/push_notification_service_test.dart`
- Modify: `frontend/lib/app/app_bootstrap.dart`
- Modify: `frontend/lib/core/auth/auth_repository.dart`

**Interfaces:**
- Consumes device registration methods from Task 6.
- Produces singleton `PushNotificationService` with `initialize()`, `syncForCurrentSession()`, `unregisterCurrentInstallation()`, and `dispose()`.
- Produces top-level `@pragma('vm:entry-point') Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message)`.

- [ ] **Step 1: Add dependency and platform bootstrap tests around injected adapters**

Create fake messaging/local-notification/install-ID adapters and verify: web skips initialization, Android creates channel once, signed-in session registers token, token refresh re-registers, foreground message displays locally, and sign-out unregisters before Supabase session removal.

- [ ] **Step 2: Run service tests and verify failure**

```powershell
cd frontend
flutter test test/features/notification/application/push_notification_service_test.dart
```

Expected: FAIL because `PushNotificationService` is absent.

- [ ] **Step 3: Add Flutter packages and Android Gradle configuration**

Add:

```yaml
firebase_core: ^4.12.1
firebase_messaging: ^16.4.3
flutter_local_notifications: ^22.1.0
```

Register `com.google.gms.google-services` in `settings.gradle.kts`, apply it in the app module, add `android.permission.POST_NOTIFICATIONS`, and declare default notification channel `hello_vietnam_updates`. Add `/android/app/google-services.json` to `frontend/.gitignore`.

- [ ] **Step 4: Implement Android-only service with dependency injection**

Guard Firebase initialization with `!kIsWeb && defaultTargetPlatform == TargetPlatform.android`. Request permission only when the user enables notifications or when a signed-in Android user has not made a choice. Store a random installation UUID in SharedPreferences, never the FCM token.

Foreground messages use `AndroidNotificationDetails('hello_vietnam_updates', 'Hello Vietnam updates', importance: Importance.high, priority: Priority.high)` and serialize only the routing data into the local notification payload.

- [ ] **Step 5: Wire bootstrap and sign-out ordering**

After Supabase/session initialization, call `PushNotificationService.instance.initialize()`. In `AuthRepository.signOut`, await `unregisterCurrentInstallation()` before `Supabase.instance.client.auth.signOut()`; failure to unregister must be logged and must not prevent sign-out.

- [ ] **Step 6: Run package resolution, tests, and Android manifest checks**

```powershell
flutter pub get
flutter test test/features/notification/application/push_notification_service_test.dart
flutter build apk --debug
flutter build web --debug
```

Expected: service tests pass; Android and Web builds both succeed. Android build requires a valid local `google-services.json`.

- [ ] **Step 7: Commit Android integration without credentials**

```powershell
git add frontend/pubspec.yaml frontend/pubspec.lock frontend/android frontend/.gitignore frontend/lib/features/notification/application/push_notification_service.dart frontend/lib/app/app_bootstrap.dart frontend/lib/core/auth/auth_repository.dart frontend/test/features/notification/application/push_notification_service_test.dart
git status --short
git commit -m "feat: integrate Android Firebase messaging"
```

Before committing, confirm `google-services.json` is absent from staged files.

### Task 8: Route taps and connect the real inbox, badge, and settings UI

**Files:**
- Create: `frontend/lib/features/notification/application/notification_tap_router.dart`
- Create: `frontend/test/features/notification/application/notification_tap_router_test.dart`
- Modify: `frontend/lib/features/notification/presentation/notification_page.dart`
- Modify: `frontend/lib/features/notification/presentation/notification_controller.dart`
- Create: `frontend/lib/features/notification/presentation/notification_settings_page.dart`
- Create: `frontend/test/features/notification/presentation/notification_settings_page_test.dart`
- Modify: `frontend/lib/features/home/presentation/home_page.dart`
- Modify: `frontend/lib/features/profile/presentation/profile_page.dart`
- Modify: `frontend/lib/features/loyalty/presentation/loyalty_page.dart`
- Modify: `frontend/lib/features/loyalty/data/loyalty_award_service.dart`
- Modify: `frontend/lib/app/router.dart`

**Interfaces:**
- Consumes `NotificationTarget.fromJson`, `NotificationActionHandler`, `rootNavigatorKey`, and `NotificationRepository`.
- Produces `NotificationTapRouter.enqueue(Map<String, dynamic>)` and `drainWhenReady()`.
- Produces route `/notification-settings`.

- [ ] **Step 1: Write tap queue tests**

Test immediate routing when context is ready, FIFO pending behavior when it is not, malformed target fallback to `/notification`, and no duplicate handling of the same notification ID.

- [ ] **Step 2: Write settings and inbox widget tests**

Test that the master switch disables push delivery controls without hiding inbox history, five type switches render, loyalty settings updates the shared server preference, inbox load-more shows a small footer progress indicator, and the bell badge reflects controller unread count.

- [ ] **Step 3: Run focused tests and verify failure**

```powershell
cd frontend
flutter test test/features/notification/application/notification_tap_router_test.dart test/features/notification/presentation/notification_settings_page_test.dart test/features/notification/presentation/notification_page_test.dart
```

Expected: FAIL because the tap router/settings page and real bindings are missing.

- [ ] **Step 4: Implement tap routing through the existing handler**

Parse `target` whether FCM supplies it as a JSON string or local notification supplies decoded JSON. Queue until `rootNavigatorKey.currentContext` exists and auth bootstrap is complete. Mark the notification read opportunistically, then call `NotificationActionHandler.open(context, target)`; on malformed data, route to `AppRoutes.notification`.

- [ ] **Step 5: Convert notification page and Home badge to production state**

Initial load shows the existing full-page loading treatment, scrolling within 300 px of the end calls `loadMore`, pull-to-refresh resets the cursor, and errors preserve already-loaded rows with a retry footer. Home subscribes to the same inbox controller unread count instead of `MockNotificationRepository`.

- [ ] **Step 6: Implement settings and remove local/mock preference paths**

Profile's Notification row navigates to `/notification-settings`. The settings page reads server preferences and updates optimistic state with rollback on failure. Loyalty page edits the `loyalty` row through the repository; remove the `loyalty_rewards_notifications_enabled` SharedPreferences path and mock notification insertion from `LoyaltyAwardService`.

- [ ] **Step 7: Run all affected Flutter tests**

```powershell
flutter test test/features/notification test/features/home test/features/profile test/features/loyalty
flutter analyze
```

Expected: all tests pass and analyzer reports no new issues.

- [ ] **Step 8: Commit UI and navigation integration carefully**

```powershell
git diff -- frontend/lib/app/router.dart frontend/lib/features/home/presentation/home_page.dart
git add frontend/lib/features/notification frontend/lib/features/home/presentation/home_page.dart frontend/lib/features/profile/presentation/profile_page.dart frontend/lib/features/loyalty frontend/lib/app/router.dart frontend/test/features/notification frontend/test/features/home frontend/test/features/profile frontend/test/features/loyalty
git commit -m "feat: connect push inbox and notification settings"
```

Review the router diff before staging because it already contains unrelated local changes.

### Task 9: Document deployment, configure the webhook, and verify end to end

**Files:**
- Create: `backend/supabase/functions/notifications/README.md`
- Modify: `docs/superpowers/specs/2026-07-22-android-push-notification-design.md` only if implementation names differ from the approved contract.

**Interfaces:**
- Consumes Firebase Android config, service-account values, Supabase secrets, migration, and both deployed Edge Functions.
- Produces a repeatable operator checklist and smoke-test payload.

- [ ] **Step 1: Write the exact operator instructions**

Document these commands from `backend`:

```powershell
npx supabase db push --include-all
npx supabase secrets set FIREBASE_PROJECT_ID="<firebase-project-id>"
npx supabase secrets set FIREBASE_CLIENT_EMAIL="<service-account-email>"
npx supabase secrets set FIREBASE_PRIVATE_KEY="<private-key-with-literal-backslash-n>"
npx supabase secrets set NOTIFICATION_DISPATCH_SECRET="<at-least-32-random-characters>"
npx supabase functions deploy notifications --use-api
npx supabase functions deploy notification-dispatch --use-api --no-verify-jwt
```

Document a Supabase Database Webhook on `public.notification`, event `INSERT`, URL `https://ziouozppetvvdrzgojcx.supabase.co/functions/v1/notification-dispatch`, header `x-notification-secret: <same secret>`. Explain that the internal secret is required because `--no-verify-jwt` permits the database webhook to reach the function but the function performs its own authorization.

- [ ] **Step 2: Add a safe smoke-test flow**

Use SQL to enqueue for the currently authenticated test user's UUID, then verify inbox first and push second:

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

Expected: one in-app row appears, dispatch status becomes `sent` when an active Android token exists, and tapping the Android notification opens Upgrade Account.

- [ ] **Step 3: Run the complete automated verification matrix**

```powershell
cd D:\Work\hello-vietnam
deno test backend/supabase/functions/_shared/firebase_messaging_test.ts backend/supabase/functions/notifications/notification_handler_test.ts backend/supabase/functions/notification-dispatch/notification_dispatch_handler_test.ts --allow-env
cd frontend
flutter test
flutter analyze
flutter build web --debug
flutter build apk --debug
```

Expected: all Deno and Flutter tests pass; analyzer has no new errors; Web and Android builds succeed.

- [ ] **Step 4: Perform the Android manual matrix**

Verify on a physical Android device:

1. Foreground push shows a native heads-up notification and refreshes the badge.
2. Background push appears and routes to the target when tapped.
3. Killed-app push routes after bootstrap without a Page Not Found screen.
4. Token refresh keeps one active installation row.
5. Logging out deactivates the installation before another user signs in.
6. Master push off retains inbox rows but prevents native delivery.
7. Each of loyalty, forum, voucher, trip, and account can be independently disabled.
8. Flutter Web admin still starts without Firebase initialization errors.

- [ ] **Step 5: Commit deployment documentation**

```powershell
git add backend/supabase/functions/notifications/README.md docs/superpowers/specs/2026-07-22-android-push-notification-design.md
git commit -m "docs: add push notification deployment guide"
```

---

## Self-Review Result

- Spec coverage: schema, RLS, token lifecycle, preferences, five categories, authenticated inbox API, idempotent dispatch, FCM HTTP v1, foreground/background/cold-start handling, tap routing, real inbox/badge/settings, deployment, and Android manual verification are each assigned to a task.
- Scope control: iOS, Web Push, rich media, action buttons, and marketing campaigns remain excluded; Web receives only compatibility verification.
- Type consistency: notification types and preference names match across SQL, Deno, and Dart; `NotificationTarget` remains the navigation payload; both Edge Functions use the approved names.
- Security: service credentials stay in Supabase Secrets, client ownership comes from auth rather than request bodies, and the dispatch webhook uses a separate internal secret.
- Performance: inbox uses cursor pagination, unread count has a partial index, dispatch caps concurrency, and foreground refresh reuses one shared controller.
