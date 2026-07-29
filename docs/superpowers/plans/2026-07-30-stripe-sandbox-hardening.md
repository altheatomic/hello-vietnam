# Stripe Sandbox Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Giữ Stripe Checkout Sandbox cho bản demo nhưng loại bỏ đường cấp Premium trái phép, bảo đảm xác nhận thanh toán nguyên tử/idempotent, thêm webhook dự phòng và mô tả đúng đây là thanh toán một lần.

**Architecture:** Flutter chỉ gửi plan/voucher/nền tảng và không còn quyết định callback URL hoặc giá. `subscription-payment` xác minh JWT, tạo `payment_attempt`, gọi Stripe Sandbox và xác minh Checkout Session; `stripe-webhook` xác minh chữ ký Stripe. Cả callback và webhook gọi một RPC chỉ dành cho `service_role` để tạo payment, voucher redemption và Premium trong một transaction.

**Tech Stack:** Flutter/Dart, Supabase Auth/PostgreSQL/RLS/Edge Functions, Deno/TypeScript, Stripe Checkout Sandbox REST API, pgTAP, Flutter Test.

## Global Constraints

- Stripe phải giữ test mode; Edge Function từ chối secret không bắt đầu bằng `sk_test_`.
- Checkout tiếp tục dùng `mode=payment`; không triển khai recurring subscription.
- Không triển khai Google Play Billing, Stripe live mode, refund hoặc chargeback trước phản biện.
- `com.hellovietnam.app` là Android application ID và URL scheme duy nhất của bản demo.
- Flutter không được nhận Stripe secret, Supabase service-role key hoặc quyền gọi RPC finalize.
- Mọi migration phải được tạo bằng `npx supabase migration new`; không tự đặt timestamp migration.
- Tất cả package/dependency mới phải pin phiên bản; kế hoạch này không cần thêm package mới.
- Không sửa hoặc commit hai thư mục tạm `.chrome-diagram-v3/` và `.superpowers/`.

---

## File Map

### Database

- Create via Supabase CLI: migration `stripe_payment_rpc_lockdown`.
- Create via Supabase CLI: migration `stripe_payment_attempts`.
- Create: `backend/supabase/tests/stripe_sandbox_hardening_test.sql`.

### Edge Functions

- Create: `backend/supabase/functions/_shared/stripe_checkout.ts`.
- Create: `backend/supabase/functions/_shared/stripe_checkout_test.ts`.
- Create: `backend/supabase/functions/_shared/stripe_payment_store.ts`.
- Create: `backend/supabase/functions/_shared/stripe_webhook_signature.ts`.
- Create: `backend/supabase/functions/_shared/stripe_webhook_signature_test.ts`.
- Create: `backend/supabase/functions/subscription-payment/subscription_payment_domain.ts`.
- Create: `backend/supabase/functions/subscription-payment/subscription_payment_domain_test.ts`.
- Create: `backend/supabase/functions/subscription-payment/subscription_payment_handler.ts`.
- Create: `backend/supabase/functions/subscription-payment/subscription_payment_handler_test.ts`.
- Modify: `backend/supabase/functions/subscription-payment/index.ts`.
- Modify: `backend/supabase/functions/subscription-payment/deno.json`.
- Create: `backend/supabase/functions/stripe-webhook/index.ts`.
- Create: `backend/supabase/functions/stripe-webhook/stripe_webhook_handler.ts`.
- Create: `backend/supabase/functions/stripe-webhook/stripe_webhook_handler_test.ts`.
- Create: `backend/supabase/functions/stripe-webhook/deno.json`.
- Create: `backend/supabase/functions/subscription-payment/README.md`.

### Flutter

- Modify: `frontend/lib/features/profile/data/subscription_repository.dart`.
- Modify: `frontend/lib/features/profile/presentation/upgrade_payment_page.dart`.
- Delete: `frontend/lib/features/profile/domain/subscription_checkout_urls.dart`.
- Modify: `frontend/test/features/profile/data/subscription_repository_test.dart`.
- Delete: `frontend/test/features/profile/domain/subscription_checkout_urls_test.dart`.
- Create: `frontend/test/features/profile/presentation/upgrade_payment_sandbox_test.dart`.
- Modify: `frontend/test/app/deep_link_state_test.dart` only if the removed `plan` query parameter changes an existing assertion.

---

### Task 1: Emergency Lockdown of Legacy Premium RPCs

**Files:**
- Create: `backend/supabase/tests/stripe_sandbox_hardening_test.sql`
- Create via CLI: migration named `stripe_payment_rpc_lockdown`

**Interfaces:**
- Consumes: current `payment`, `premium_subscription`, legacy RPCs and Supabase roles.
- Produces: read-only client access to owned rows; no client-callable RPC capable of creating Premium.

- [ ] **Step 1: Create the migration through the Supabase CLI**

Run from repository root:

```powershell
npx supabase migration new stripe_payment_rpc_lockdown --workdir backend/supabase
```

Record the exact file path printed by the CLI. All SQL in this task goes into
that generated file.

- [ ] **Step 2: Write the failing pgTAP security test**

Create `backend/supabase/tests/stripe_sandbox_hardening_test.sql` with:

```sql
begin;

create extension if not exists pgtap with schema extensions;

select plan(10);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.confirm_paid_subscription_with_voucher(text,text,text,text,text)',
    'EXECUTE'
  ),
  'authenticated cannot execute legacy Stripe confirmation'
);

select is(
  to_regprocedure(
    'public.purchase_subscription_with_voucher(text,text,text,text)'
  ),
  null::regprocedure,
  'legacy direct-purchase function is removed'
);

select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.payment'::regclass
  ),
  'payment has RLS enabled'
);

select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.premium_subscription'::regclass
  ),
  'premium_subscription has RLS enabled'
);

select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'payment'
      and cmd = 'SELECT'
      and policyname = 'Users can read own payments'
  ),
  1::bigint,
  'payment has one ownership SELECT policy'
);

select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'premium_subscription'
      and cmd = 'SELECT'
      and policyname = 'Users can read own premium subscriptions'
  ),
  1::bigint,
  'premium_subscription has one ownership SELECT policy'
);

select ok(
  not has_table_privilege('anon', 'public.payment', 'SELECT'),
  'anon cannot read payments'
);

select ok(
  not has_table_privilege('anon', 'public.premium_subscription', 'SELECT'),
  'anon cannot read Premium subscriptions'
);

select ok(
  not has_table_privilege('authenticated', 'public.payment', 'INSERT,UPDATE,DELETE'),
  'authenticated cannot mutate payments'
);

select ok(
  not has_table_privilege(
    'authenticated',
    'public.premium_subscription',
    'INSERT,UPDATE,DELETE'
  ),
  'authenticated cannot mutate Premium subscriptions'
);

select * from finish();
rollback;
```

- [ ] **Step 3: Run the test and verify RED**

```powershell
npx supabase test db backend/supabase/tests/stripe_sandbox_hardening_test.sql
```

Expected: the legacy RPC privilege assertions fail on the current schema.

- [ ] **Step 4: Implement the lockdown migration**

Put this SQL into the CLI-generated migration:

```sql
revoke all on function public.confirm_paid_subscription_with_voucher(
  text, text, text, text, text
) from public, anon, authenticated;

drop function if exists public.purchase_subscription_with_voucher(
  text, text, text, text
);

alter table public.payment enable row level security;
alter table public.premium_subscription enable row level security;

revoke all on table public.payment from anon;
revoke all on table public.premium_subscription from anon;

revoke insert, update, delete, truncate, references, trigger
  on table public.payment from authenticated;
revoke insert, update, delete, truncate, references, trigger
  on table public.premium_subscription from authenticated;

grant select on table public.payment to authenticated;
grant select on table public.premium_subscription to authenticated;

drop policy if exists "Users can read own payments" on public.payment;
create policy "Users can read own payments"
on public.payment
for select
to authenticated
using ((select auth.uid()) = id_user);

drop policy if exists "Users can read own premium subscriptions"
on public.premium_subscription;
create policy "Users can read own premium subscriptions"
on public.premium_subscription
for select
to authenticated
using ((select auth.uid()) = id_user);
```

Do not grant either legacy function back to `service_role`; the new finalize
function in Task 2 replaces it.

- [ ] **Step 5: Run the pgTAP test and verify GREEN**

```powershell
npx supabase test db backend/supabase/tests/stripe_sandbox_hardening_test.sql
```

Expected: all 10 assertions pass.

- [ ] **Step 6: Commit the lockdown**

```powershell
git add backend/supabase/migrations backend/supabase/tests/stripe_sandbox_hardening_test.sql
git commit -m "fix: lock down legacy Premium payment RPCs"
```

---

### Task 2: Add Payment Attempts and Atomic Finalization

**Files:**
- Modify: `backend/supabase/tests/stripe_sandbox_hardening_test.sql`
- Create via CLI: migration named `stripe_payment_attempts`

**Interfaces:**
- Consumes: authenticated user ID, server-calculated plan/voucher snapshot and Stripe Session result.
- Produces:
  - `public.payment_attempt`
  - `public.finalize_verified_payment(uuid,text,bigint,text)`
  - one idempotent payment/Premium result per Stripe Session.

- [ ] **Step 1: Create the second migration through the CLI**

```powershell
npx supabase migration new stripe_payment_attempts --workdir backend/supabase
```

Use the exact generated path printed by the CLI.

- [ ] **Step 2: Add failing schema and idempotency assertions**

Change the pgTAP declaration to `select plan(20);` and append assertions
covering:

```sql
select has_table('public', 'payment_attempt');
select has_column('public', 'payment_attempt', 'stripe_session_id');
select has_column('public', 'premium_subscription', 'id_payment');

select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.payment_attempt'::regclass
  ),
  'payment_attempt has RLS enabled'
);

select ok(
  not has_table_privilege('authenticated', 'public.payment_attempt', 'SELECT'),
  'client cannot read payment attempts'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.finalize_verified_payment(uuid,text,bigint,text)',
    'EXECUTE'
  ),
  'service role can finalize a verified payment'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.finalize_verified_payment(uuid,text,bigint,text)',
    'EXECUTE'
  ),
  'authenticated cannot finalize a payment'
);
```

Then insert deterministic test fixtures and call finalize twice:

```sql
insert into public.user_account (id_user, username, full_name)
values (
  '91000000-0000-4000-8000-000000000001',
  'stripe-test-user',
  'Stripe Test User'
);

insert into public.subscription_plan (
  id_subscription_plan, code, name, duration_days, price_minor, status
) values (
  '92000000-0000-4000-8000-000000000001',
  'stripe_test_6m',
  'Stripe Test 6 Months',
  180,
  1999,
  'active'
);

insert into public.payment_attempt (
  id_attempt,
  id_user,
  id_subscription_plan,
  plan_code,
  plan_name,
  duration_days,
  original_amount_minor,
  discount_minor,
  amount_minor,
  currency,
  stripe_session_id,
  status
) values (
  '93000000-0000-4000-8000-000000000001',
  '91000000-0000-4000-8000-000000000001',
  '92000000-0000-4000-8000-000000000001',
  'stripe_test_6m',
  'Stripe Test 6 Months',
  180,
  1999,
  0,
  1999,
  'USD',
  'cs_test_atomic_1',
  'pending'
);

set local role service_role;

select * from public.finalize_verified_payment(
  '93000000-0000-4000-8000-000000000001',
  'cs_test_atomic_1',
  1999,
  'USD'
);

select * from public.finalize_verified_payment(
  '93000000-0000-4000-8000-000000000001',
  'cs_test_atomic_1',
  1999,
  'USD'
);

reset role;

select is(
  (
    select count(*)
    from public.payment
    where provider = 'stripe'
      and external_ref = 'cs_test_atomic_1'
  ),
  1::bigint,
  'duplicate finalize creates one payment'
);

select is(
  (
    select count(*)
    from public.premium_subscription
    where id_payment = (
      select id_payment
      from public.payment
      where external_ref = 'cs_test_atomic_1'
    )
  ),
  1::bigint,
  'duplicate finalize creates one entitlement'
);
```

Add a second pending attempt and verify wrong amount throws:

```sql
insert into public.payment_attempt (
  id_attempt,
  id_user,
  id_subscription_plan,
  plan_code,
  plan_name,
  duration_days,
  original_amount_minor,
  discount_minor,
  amount_minor,
  currency,
  stripe_session_id,
  status
) values (
  '93000000-0000-4000-8000-000000000002',
  '91000000-0000-4000-8000-000000000001',
  '92000000-0000-4000-8000-000000000001',
  'stripe_test_6m',
  'Stripe Test 6 Months',
  180,
  1999,
  0,
  1999,
  'USD',
  'cs_test_amount_mismatch',
  'pending'
);

select throws_ok(
  $$
    select * from public.finalize_verified_payment(
      '93000000-0000-4000-8000-000000000002',
      'cs_test_amount_mismatch',
      499,
      'USD'
    )
  $$,
  'P0001',
  'PAYMENT_AMOUNT_MISMATCH',
  'amount mismatch does not grant Premium'
);
```

- [ ] **Step 3: Run pgTAP and verify RED**

```powershell
npx supabase test db backend/supabase/tests/stripe_sandbox_hardening_test.sql
```

Expected: missing table/function/column assertions fail.

- [ ] **Step 4: Add a production duplicate preflight**

Before applying the unique index to the linked database, run this read-only SQL:

```sql
select provider, external_ref, count(*)
from public.payment
where external_ref is not null
group by provider, external_ref
having count(*) > 1;
```

Expected: zero rows. If rows exist, stop and reconcile them manually before
applying the migration; do not silently delete payments.

- [ ] **Step 5: Implement the payment schema**

The migration must create:

```sql
create table public.payment_attempt (
  id_attempt uuid primary key default gen_random_uuid(),
  id_user uuid not null references public.user_account(id_user),
  id_subscription_plan uuid not null
    references public.subscription_plan(id_subscription_plan),
  id_voucher uuid null references public.voucher(id_voucher),
  id_voucher_wallet uuid null references public.voucher_wallet(id_wallet),
  plan_code text not null,
  plan_name text not null,
  duration_days integer not null check (duration_days > 0),
  original_amount_minor bigint not null check (original_amount_minor >= 0),
  discount_minor bigint not null check (discount_minor >= 0),
  amount_minor bigint not null check (amount_minor >= 0),
  voucher_code text null,
  currency text not null check (currency = 'USD'),
  stripe_session_id text unique,
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'finalized', 'expired', 'failed')),
  failure_reason text null,
  id_payment uuid null references public.payment(id_payment),
  id_subscription uuid null references public.premium_subscription(id_prs),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  finalized_at timestamptz null
);

alter table public.payment_attempt
add constraint payment_attempt_amounts_match
check (original_amount_minor = discount_minor + amount_minor);

alter table public.payment_attempt enable row level security;
revoke all on table public.payment_attempt from public, anon, authenticated;
grant all on table public.payment_attempt to service_role;

create unique index payment_provider_external_ref_uidx
on public.payment (provider, external_ref)
where external_ref is not null;

alter table public.premium_subscription
add column if not exists id_payment uuid
references public.payment(id_payment);

create unique index premium_subscription_payment_uidx
on public.premium_subscription (id_payment)
where id_payment is not null;
```

Add an `updated_at` trigger using the existing project trigger helper when it
exists; otherwise update `updated_at` explicitly in the finalize RPC.

- [ ] **Step 6: Implement `finalize_verified_payment`**

Create exactly this public interface:

```sql
create or replace function public.finalize_verified_payment(
  p_attempt_id uuid,
  p_stripe_session_id text,
  p_amount_total bigint,
  p_currency text
)
returns table (
  id_payment uuid,
  id_subscription uuid,
  original_amount_minor bigint,
  discount_minor bigint,
  final_amount_minor bigint,
  voucher_code text,
  subscription_end_date timestamptz
)
language plpgsql
security definer
set search_path = ''
```

Inside the function:

1. Khóa đúng hàng `payment_attempt` bằng `SELECT INTO ... FOR UPDATE`.
2. Return stored IDs immediately when status is `finalized`.
3. Raise exact errors:
   - `PAYMENT_ATTEMPT_NOT_FOUND`
   - `PAYMENT_SESSION_MISMATCH`
   - `PAYMENT_AMOUNT_MISMATCH`
   - `PAYMENT_CURRENCY_MISMATCH`
   - `PAYMENT_ATTEMPT_CLOSED`
4. Insert payment with `provider='stripe'`, `method='card'`,
   `external_ref=p_stripe_session_id`.
5. Calculate Premium start as:

```sql
greatest(
  now(),
  coalesce(
    (
      select max(end_date)
      from public.premium_subscription
      where id_user = attempt.id_user
        and status = 'active'
    ),
    now()
  )
)
```

6. Add `attempt.duration_days` to the start date.
7. Insert voucher redemption only when `id_voucher` is present and no
   redemption for this payment exists.
8. Mark `id_voucher_wallet` used when present and currently `available`.
9. Store payment/subscription IDs on the attempt and mark it `finalized`.

End the migration with:

```sql
revoke all on function public.finalize_verified_payment(
  uuid, text, bigint, text
) from public, anon, authenticated;

grant execute on function public.finalize_verified_payment(
  uuid, text, bigint, text
) to service_role;
```

- [ ] **Step 7: Run the database test and verify GREEN**

```powershell
npx supabase test db backend/supabase/tests/stripe_sandbox_hardening_test.sql
```

Expected: all schema, privilege, amount mismatch and duplicate-finalize
assertions pass.

- [ ] **Step 8: Commit atomic persistence**

```powershell
git add backend/supabase/migrations backend/supabase/tests/stripe_sandbox_hardening_test.sql
git commit -m "feat: finalize Stripe Sandbox payments atomically"
```

---

### Task 3: Build Testable Stripe Checkout and Signature Adapters

**Files:**
- Create: `backend/supabase/functions/_shared/stripe_checkout.ts`
- Create: `backend/supabase/functions/_shared/stripe_checkout_test.ts`
- Create: `backend/supabase/functions/_shared/stripe_webhook_signature.ts`
- Create: `backend/supabase/functions/_shared/stripe_webhook_signature_test.ts`

**Interfaces:**
- Produces:
  - `StripeCheckoutClient.createSession(input, idempotencyKey)`
  - `StripeCheckoutClient.retrieveSession(sessionId)`
  - `verifyStripeWebhookSignature(input)`

- [ ] **Step 1: Write failing Checkout adapter tests**

Cover these exact behaviors using an injected `fetch`:

```ts
Deno.test("createSession sends payment mode, attempt metadata and idempotency key", async () => {
  // Assert Authorization uses sk_test_*, body has mode=payment,
  // metadata[attempt_id], client_reference_id, amount, USD and server-built URLs.
});

Deno.test("retrieveSession maps amount_total and currency", async () => {
  // Return a Stripe fixture and assert amountTotal=1999, currency="usd".
});

Deno.test("Stripe client rejects a live secret in Sandbox mode", () => {
  // Constructing with sk_live_* must throw STRIPE_SANDBOX_KEY_REQUIRED.
});
```

The public types must be:

```ts
export type StripeSession = {
  id: string;
  url: string | null;
  clientReferenceId: string | null;
  attemptId: string | null;
  status: string | null;
  paymentStatus: string | null;
  amountTotal: number | null;
  currency: string | null;
};

export type CreateStripeSessionInput = {
  attemptId: string;
  userId: string;
  productName: string;
  amountMinor: number;
  currency: "usd";
  successUrl: string;
  cancelUrl: string;
};
```

- [ ] **Step 2: Write failing webhook signature tests**

Use deterministic timestamp `1_800_000_000` and secret
`whsec_test_signature`:

```ts
Deno.test("accepts a valid Stripe v1 HMAC within five minutes", async () => {});
Deno.test("rejects an invalid Stripe signature", async () => {});
Deno.test("rejects a valid signature older than five minutes", async () => {});
Deno.test("accepts any matching v1 during Stripe secret rotation", async () => {});
```

Public interface:

```ts
export async function verifyStripeWebhookSignature(input: {
  rawBody: string;
  signatureHeader: string | null;
  secret: string;
  nowSeconds?: number;
  toleranceSeconds?: number;
}): Promise<boolean>;
```

- [ ] **Step 3: Run tests and verify RED**

```powershell
deno test backend/supabase/functions/_shared/stripe_checkout_test.ts backend/supabase/functions/_shared/stripe_webhook_signature_test.ts
```

Expected: imports/functions do not exist.

- [ ] **Step 4: Implement the Checkout adapter**

Use the existing REST approach but move it out of `subscription-payment`.
Requirements:

- Reject non-`sk_test_` keys.
- Add `Idempotency-Key: attemptId` when creating.
- Add `Stripe-Version: 2025-06-30.basil`.
- Normalize Stripe JSON to `StripeSession`.
- Never log request headers or full Stripe response.
- Throw typed messages `STRIPE_CHECKOUT_FAILED` and
  `STRIPE_SESSION_LOAD_FAILED`.

- [ ] **Step 5: Implement signature verification**

Parse all `t=` and `v1=` values from `Stripe-Signature`. Compute:

```text
HMAC_SHA256(secret, timestamp + "." + rawBody)
```

Compare bytes in constant time and reject timestamps outside 300 seconds.
Use `crypto.subtle`; do not add a dependency.

- [ ] **Step 6: Run tests and verify GREEN**

```powershell
deno test backend/supabase/functions/_shared/stripe_checkout_test.ts backend/supabase/functions/_shared/stripe_webhook_signature_test.ts
```

Expected: all adapter and signature tests pass without network access.

- [ ] **Step 7: Commit shared Stripe adapters**

```powershell
git add backend/supabase/functions/_shared/stripe_checkout.ts backend/supabase/functions/_shared/stripe_checkout_test.ts backend/supabase/functions/_shared/stripe_webhook_signature.ts backend/supabase/functions/_shared/stripe_webhook_signature_test.ts
git commit -m "feat: add verified Stripe Sandbox adapters"
```

---

### Task 4: Replace the Subscription Payment Handler

**Files:**
- Create: `backend/supabase/functions/subscription-payment/subscription_payment_domain.ts`
- Create: `backend/supabase/functions/subscription-payment/subscription_payment_domain_test.ts`
- Create: `backend/supabase/functions/subscription-payment/subscription_payment_handler.ts`
- Create: `backend/supabase/functions/subscription-payment/subscription_payment_handler_test.ts`
- Create: `backend/supabase/functions/_shared/stripe_payment_store.ts`
- Modify: `backend/supabase/functions/subscription-payment/index.ts`
- Modify: `backend/supabase/functions/subscription-payment/deno.json`

**Interfaces:**
- Consumes: JWT, plan/voucher/platform, `StripeCheckoutClient`,
  `SubscriptionPaymentStore`.
- Produces:
  - `create_checkout`
  - `confirm_checkout`
  - server-owned callbacks and verified finalize calls.

- [ ] **Step 1: Write failing domain tests**

Test:

```ts
Deno.test("parse create_checkout accepts android without client URLs", () => {});
Deno.test("parse create_checkout requires an allowlisted web origin", () => {});
Deno.test("Android callbacks are pinned to com.hellovietnam.app", () => {});
Deno.test("web callbacks reject an origin outside the allowlist", () => {});
Deno.test("paid session must match attempt user, id, amount and currency", () => {});
Deno.test("unpaid or incomplete sessions are rejected", () => {});
```

Define these public types:

```ts
export type CheckoutPlatform = "android" | "web";

export type CreateCheckoutCommand = {
  action: "create_checkout";
  planCode: string;
  voucherCode: string | null;
  platform: CheckoutPlatform;
  webOrigin: string | null;
};

export type ConfirmCheckoutCommand = {
  action: "confirm_checkout";
  sessionId: string;
};
```

Server callback builder must use these exact templates after validating `origin`
against the allowlist:

```ts
const encodedPlanCode = encodeURIComponent(planCode);
const androidSuccess =
  `intent://upgrade-payment?plan=${encodedPlanCode}` +
  `&stripe_session_id={CHECKOUT_SESSION_ID}` +
  "#Intent;scheme=com.hellovietnam.app;" +
  "package=com.hellovietnam.app;end";
const androidCancel =
  `intent://upgrade-payment?plan=${encodedPlanCode}&stripe_cancelled=1` +
  "#Intent;scheme=com.hellovietnam.app;" +
  "package=com.hellovietnam.app;end";
const webSuccess =
  `${origin}/#/upgrade-payment?plan=${encodedPlanCode}` +
  `&stripe_session_id={CHECKOUT_SESSION_ID}`;
const webCancel =
  `${origin}/#/upgrade-payment?plan=${encodedPlanCode}&stripe_cancelled=1`;
```

- [ ] **Step 2: Write failing handler tests with fake dependencies**

`SubscriptionPaymentStore` must expose:

```ts
export interface SubscriptionPaymentStore {
  authenticate(authorization: string | null): Promise<{ id: string } | null>;
  createAttempt(input: CreateAttemptInput): Promise<PaymentAttempt>;
  attachStripeSession(attemptId: string, sessionId: string): Promise<void>;
  findAttemptById(attemptId: string): Promise<PaymentAttempt | null>;
  finalizeVerifiedSession(
    attemptId: string,
    session: StripeSession,
  ): Promise<FinalizedPurchase>;
  markAttemptFailed(attemptId: string, reason: string): Promise<void>;
}
```

Implement the production adapter in
`backend/supabase/functions/_shared/stripe_payment_store.ts`. It uses the
service-role Supabase client only inside Edge Functions; tests inject fakes and
must never read real environment variables or call the network.

Use these exact neighboring types:

```ts
export type CreateAttemptInput = {
  userId: string;
  planCode: string;
  voucherCode: string | null;
};

export type PaymentAttempt = {
  idAttempt: string;
  userId: string;
  planCode: string;
  planName: string;
  durationDays: number;
  originalAmountMinor: number;
  discountMinor: number;
  amountMinor: number;
  currency: "USD";
  stripeSessionId: string | null;
  status: "pending" | "paid" | "finalized" | "expired" | "failed";
  failureReason: string | null;
};

export type FinalizedPurchase = {
  paymentId: string;
  subscriptionId: string;
  originalAmountMinor: number;
  discountMinor: number;
  finalAmountMinor: number;
  voucherCode: string | null;
  subscriptionEndDate: string;
};
```

Test these cases:

- Missing/invalid JWT returns 401 before DB or Stripe access.
- Client-supplied `successUrl`/`cancelUrl` is rejected as malformed payload.
- Plan price comes from store snapshot, not request body.
- Stripe Session is created with `attempt.idAttempt` as idempotency key.
- Session creation failure marks attempt failed.
- Confirm rejects missing attempt, wrong user, wrong amount and unpaid session.
- Valid confirm calls finalize exactly once.
- Duplicate confirm returns the existing finalized purchase.

- [ ] **Step 3: Run handler tests and verify RED**

```powershell
deno test backend/supabase/functions/subscription-payment/subscription_payment_domain_test.ts backend/supabase/functions/subscription-payment/subscription_payment_handler_test.ts
```

Expected: new modules are missing.

- [ ] **Step 4: Implement domain parsing and validation**

Keep parsing and validation pure. Normalize currency to uppercase for DB and
lowercase for Stripe. Error codes returned to the handler must be:

```text
UNAUTHORIZED
BAD_REQUEST
PAYMENT_REQUIRED
PAYMENT_SESSION_MISMATCH
PAYMENT_AMOUNT_MISMATCH
PAYMENT_CURRENCY_MISMATCH
```

- [ ] **Step 5: Implement the handler with dependency injection**

Create:

```ts
export function createSubscriptionPaymentHandler(
  dependencies: SubscriptionPaymentDependencies,
): (request: Request) => Promise<Response>;
```

The create flow is:

```text
authenticate
→ load server plan/voucher and create pending attempt
→ build server callbacks
→ Stripe createSession(attempt, attempt.idAttempt)
→ attach Stripe Session ID
→ return requires_checkout
```

The confirm flow is:

```text
authenticate
→ retrieve Stripe Session
→ require metadata.attempt_id
→ find attempt by ID
→ attach/compare Stripe Session ID
→ validate ownership/status/amount/currency
→ finalize_verified_payment RPC
→ award loyalty idempotently by payment ID
→ return completed
```

Remove `ensureDefaultSubscriptionData`; plan/voucher seeds belong to migrations,
not runtime payment requests.

- [ ] **Step 6: Reduce `index.ts` to environment wiring**

`index.ts` should only:

- Read required environment variables.
- Require `STRIPE_SECRET_KEY` to be test mode.
- Parse `CHECKOUT_ALLOWED_WEB_ORIGINS`.
- Create Supabase user/service clients.
- Instantiate store, Stripe client and handler.
- Call `Deno.serve(handler)`.

Keep `verify_jwt=true` when deploying this function.

- [ ] **Step 7: Run handler tests and Deno check**

```powershell
deno test backend/supabase/functions/subscription-payment/subscription_payment_domain_test.ts backend/supabase/functions/subscription-payment/subscription_payment_handler_test.ts
deno check backend/supabase/functions/subscription-payment/index.ts
```

Expected: all tests pass and type checking reports no errors.

- [ ] **Step 8: Commit the authenticated payment flow**

```powershell
git add backend/supabase/functions/subscription-payment backend/supabase/functions/_shared/stripe_checkout.ts
git commit -m "refactor: secure Stripe Sandbox checkout confirmation"
```

---

### Task 5: Add the Signed Stripe Webhook

**Files:**
- Create: `backend/supabase/functions/stripe-webhook/index.ts`
- Create: `backend/supabase/functions/stripe-webhook/stripe_webhook_handler.ts`
- Create: `backend/supabase/functions/stripe-webhook/stripe_webhook_handler_test.ts`
- Create: `backend/supabase/functions/stripe-webhook/deno.json`

**Interfaces:**
- Consumes: raw Stripe event body and `Stripe-Signature`.
- Produces: idempotent finalize for `checkout.session.completed`; expiration for
  `checkout.session.expired`.

The webhook depends on this minimum store contract:

```ts
export interface StripeWebhookStore {
  findAttemptById(attemptId: string): Promise<PaymentAttempt | null>;
  attachStripeSession(attemptId: string, sessionId: string): Promise<void>;
  finalizeVerifiedSession(
    attemptId: string,
    session: StripeSession,
  ): Promise<FinalizedPurchase>;
  markAttemptExpired(attemptId: string): Promise<void>;
}
```

The production object is the shared Supabase adapter created in Task 4. The
handler receives only this interface so unit tests can use an in-memory fake.

- [ ] **Step 1: Write failing webhook handler tests**

Use a fixed signed fixture and fake store. Test:

```ts
Deno.test("rejects a missing signature with 400", async () => {});
Deno.test("rejects an invalid signature without touching the store", async () => {});
Deno.test("completed event retrieves and finalizes the verified session", async () => {});
Deno.test("expired event marks only the matching pending attempt expired", async () => {});
Deno.test("unknown signed events return 200 ignored", async () => {});
Deno.test("duplicate completed events return 200 finalized", async () => {});
```

Public handler:

```ts
export function createStripeWebhookHandler(
  dependencies: StripeWebhookDependencies,
): (request: Request) => Promise<Response>;
```

- [ ] **Step 2: Run tests and verify RED**

```powershell
deno test backend/supabase/functions/stripe-webhook/stripe_webhook_handler_test.ts
```

Expected: webhook modules are missing.

- [ ] **Step 3: Implement raw-body signature verification**

Read exactly once:

```ts
const rawBody = await request.text();
```

Verify the signature before `JSON.parse`. Never log the raw body. After
verification:

- `checkout.session.completed`: read the event Session ID, retrieve the current
  Session from Stripe, require `metadata.attempt_id`, find the attempt by that
  ID, attach the Session ID only when the attempt has none, reject a different
  stored Session ID, compare `client_reference_id`, amount, currency and paid
  status, then call the finalize RPC.
- `checkout.session.expired`: require `metadata.attempt_id`, find the attempt by
  ID, require its Session ID to match the event, then mark only a pending
  attempt expired.
- Other event types: return `{ outcome: "ignored" }`.

Return 2xx for an already finalized event so Stripe does not retry forever.

- [ ] **Step 4: Wire the webhook index**

Required secrets:

```text
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET
```

The index must reject a non-test Stripe key and instantiate the same Stripe
client/store used by `subscription-payment`.

- [ ] **Step 5: Run webhook tests and type checking**

```powershell
deno test backend/supabase/functions/stripe-webhook/stripe_webhook_handler_test.ts backend/supabase/functions/_shared/stripe_webhook_signature_test.ts
deno check backend/supabase/functions/stripe-webhook/index.ts
```

Expected: all tests pass; no network is used by unit tests.

- [ ] **Step 6: Commit the webhook**

```powershell
git add backend/supabase/functions/stripe-webhook backend/supabase/functions/_shared/stripe_webhook_signature.ts
git commit -m "feat: finalize Stripe Sandbox payments by signed webhook"
```

---

### Task 6: Update Flutter Payload, Copy and Retry UX

**Files:**
- Modify: `frontend/lib/features/profile/data/subscription_repository.dart`
- Modify: `frontend/lib/features/profile/presentation/upgrade_payment_page.dart`
- Delete: `frontend/lib/features/profile/domain/subscription_checkout_urls.dart`
- Modify: `frontend/test/features/profile/data/subscription_repository_test.dart`
- Delete: `frontend/test/features/profile/domain/subscription_checkout_urls_test.dart`
- Create: `frontend/test/features/profile/presentation/upgrade_payment_sandbox_test.dart`
- Modify: `frontend/test/app/deep_link_state_test.dart` when required by routing assertion

**Interfaces:**
- Consumes: `create_checkout` with platform/origin and `confirm_checkout` with
  Session ID.
- Produces: Sandbox-only UI, truthful one-time copy and retryable entitlement
  synchronization.

- [ ] **Step 1: Change repository tests first**

Update the expected create body to:

```dart
expect(capturedBody, <String, Object?>{
  'action': 'create_checkout',
  'planCode': '6m',
  'voucherCode': 'LOYALTY10',
  'platform': 'android',
  'webOrigin': null,
});
```

Add a web case:

```dart
expect(capturedBody, <String, Object?>{
  'action': 'create_checkout',
  'planCode': '6m',
  'voucherCode': null,
  'platform': 'web',
  'webOrigin': 'https://hello-vietnam.test',
});
```

Delete tests for client-built checkout URLs.

- [ ] **Step 2: Write failing presentation tests**

Create `upgrade_payment_sandbox_test.dart` and assert keys:

```dart
expect(find.byKey(const Key('stripe-sandbox-badge')), findsOneWidget);
expect(find.textContaining('TEST MODE'), findsOneWidget);
expect(find.byKey(const Key('premium-one-time-copy')), findsOneWidget);
expect(find.textContaining('does not renew automatically'), findsOneWidget);
expect(find.textContaining('automatically renew'), findsNothing);
```

Add a fake repository whose first `confirmStripeCheckout` throws a network
error and second call succeeds. Assert:

```dart
expect(find.byKey(const Key('stripe-sync-retry')), findsOneWidget);
await tester.tap(find.byKey(const Key('stripe-sync-retry')));
await tester.pumpAndSettle();
expect(fakeRepository.confirmCalls, 2);
```

- [ ] **Step 3: Run Flutter tests and verify RED**

```powershell
Set-Location frontend
flutter test test/features/profile/data/subscription_repository_test.dart test/features/profile/presentation/upgrade_payment_sandbox_test.dart test/app/deep_link_state_test.dart
```

Expected: old payload and missing Sandbox widgets fail.

- [ ] **Step 4: Remove the legacy direct purchase API**

Delete the complete `SubscriptionRepository.purchase` method at
`frontend/lib/features/profile/data/subscription_repository.dart:554`.
Confirm no call sites:

```powershell
rg -n "\.purchase\(|purchase_subscription_with_voucher" frontend/lib
```

Expected: zero matches.

- [ ] **Step 5: Change Checkout creation payload**

Use:

```dart
Future<SubscriptionCheckoutResult> createStripeCheckout({
  required String planCode,
  String? voucherCode,
  required bool isWeb,
  String? webOrigin,
})
```

Send:

```dart
<String, Object?>{
  'action': 'create_checkout',
  'planCode': planCode,
  'voucherCode': voucherCode,
  'platform': isWeb ? 'web' : 'android',
  'webOrigin': isWeb ? webOrigin : null,
}
```

Before sending a web request, require `webOrigin` to be non-null and normalize
it to `Uri.base.origin`. Android must always send `null`.

Delete `subscription_checkout_urls.dart`; callback construction is now
server-owned.

- [ ] **Step 6: Add truthful Sandbox UI**

Add stable widget keys:

```dart
const Key('stripe-sandbox-badge')
const Key('premium-one-time-copy')
const Key('stripe-sync-retry')
```

Copy:

```text
TEST MODE · No real charge
This is a one-time sandbox payment. Premium access does not renew automatically.
```

Remove every occurrence of:

```text
Your subscription will automatically renew.
```

Keep plan duration and expiration date visible.

- [ ] **Step 7: Make callback synchronization retryable**

When `confirmStripeCheckout` fails:

- Keep the Session ID in page state.
- Explain that payment state could not yet be synchronized.
- Show `stripe-sync-retry`.
- Do not label a paid Stripe attempt as declined.
- On retry success, refresh `PremiumEntitlementController`.

When the app resumes on this callback page, retry once only if a Session ID
exists and no confirmation request is currently running.

- [ ] **Step 8: Run Flutter tests and analyzer**

```powershell
Set-Location frontend
flutter test test/features/profile/data/subscription_repository_test.dart test/features/profile/presentation/upgrade_payment_sandbox_test.dart test/app/deep_link_state_test.dart test/features/profile/application/premium_entitlement_controller_test.dart
flutter analyze
```

Expected: all selected tests pass and analyzer has no errors.

- [ ] **Step 9: Commit Flutter changes**

```powershell
git add frontend/lib/features/profile frontend/test/features/profile frontend/test/app/deep_link_state_test.dart
git commit -m "fix: present Stripe Sandbox as one-time Premium access"
```

---

### Task 7: Add the Sandbox Runbook and Complete Verification

**Files:**
- Create: `backend/supabase/functions/subscription-payment/README.md`
- Modify: only files required by failures discovered in the verification commands

**Interfaces:**
- Consumes: completed database, Edge Function and Flutter tasks.
- Produces: repeatable deployment/test procedure and evidence for the defense.

- [ ] **Step 1: Document required Sandbox secrets**

The README must list the secret names and validation rules:

```text
STRIPE_SECRET_KEY must start with sk_test_
STRIPE_WEBHOOK_SECRET must start with whsec_
CHECKOUT_ALLOWED_WEB_ORIGINS=http://localhost:3000
```

It must also state:

- Never use `sk_live_` before the Google Play billing migration.
- `subscription-payment` requires JWT verification.
- `stripe-webhook` disables JWT verification only because it verifies
  `Stripe-Signature`.
- No card data is stored in Supabase.

- [ ] **Step 2: Run the complete local test suite for this scope**

```powershell
npx supabase test db backend/supabase/tests/stripe_sandbox_hardening_test.sql

deno test backend/supabase/functions/_shared/stripe_checkout_test.ts backend/supabase/functions/_shared/stripe_webhook_signature_test.ts backend/supabase/functions/subscription-payment/subscription_payment_domain_test.ts backend/supabase/functions/subscription-payment/subscription_payment_handler_test.ts backend/supabase/functions/stripe-webhook/stripe_webhook_handler_test.ts

deno check backend/supabase/functions/subscription-payment/index.ts
deno check backend/supabase/functions/stripe-webhook/index.ts

Set-Location frontend
flutter test test/features/profile test/app/deep_link_state_test.dart
flutter analyze
Set-Location ..
```

Expected: every command exits 0.

- [ ] **Step 3: Inspect migration status and security advisors**

Before remote mutation:

```powershell
npx supabase db push --help
npx supabase migration list --workdir backend/supabase
```

Confirm from the installed CLI help that `--workdir`, `--linked` and `--yes`
are supported, then apply the two reviewed migrations:

```powershell
npx supabase db push --workdir backend/supabase --linked --yes
```

If the installed CLI does not list one of those flags, stop and adjust the
command to the exact syntax printed by `db push --help`; do not guess flags.

After applying the approved migrations, run Supabase Security Advisor and verify
that neither payment RPC appears under:

```text
anon_security_definer_function_executable
authenticated_security_definer_function_executable
```

Also run:

```sql
select
  p.proname,
  p.prosecdef,
  p.proacl::text
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'confirm_paid_subscription_with_voucher',
    'purchase_subscription_with_voucher',
    'finalize_verified_payment'
  );
```

Expected: legacy functions are absent or not executable by client roles;
`finalize_verified_payment` is executable only by service role.

- [ ] **Step 4: Configure and deploy Sandbox functions**

Set secrets using PowerShell environment variables so secret values do not
appear in shell history:

```powershell
npx supabase secrets set "STRIPE_SECRET_KEY=$env:HV_STRIPE_TEST_KEY" "STRIPE_WEBHOOK_SECRET=$env:HV_STRIPE_WEBHOOK_SECRET" "CHECKOUT_ALLOWED_WEB_ORIGINS=http://localhost:3000"
npx supabase functions deploy subscription-payment --use-api
npx supabase functions deploy stripe-webhook --use-api --no-verify-jwt
```

Expected: both functions deploy successfully; only `stripe-webhook` has JWT
verification disabled.

- [ ] **Step 5: Run Stripe Sandbox smoke tests**

With Stripe CLI authenticated to the Sandbox account:

```powershell
stripe listen --forward-to https://ziouozppetvvdrzgojcx.supabase.co/functions/v1/stripe-webhook
```

Copy the emitted `whsec_` into `HV_STRIPE_WEBHOOK_SECRET`, update the Supabase
secret, then test:

| Case | Stripe test input | Expected |
|---|---|---|
| Success | `4242 4242 4242 4242` | one payment, one Premium, attempt finalized |
| Decline | `4000 0000 0000 9995` | no payment/Premium |
| Duplicate | resend `checkout.session.completed` | counts remain one |
| No deep link | close browser after success | webhook still grants Premium |
| Wrong user | confirm user A Session while signed in as B | 401/403, no new row |

Use any future expiry and any three-digit CVC.

- [ ] **Step 6: Capture defense evidence**

Save redacted screenshots/log extracts showing:

- Stripe Dashboard Session in test mode.
- `payment_attempt.status=finalized`.
- Exactly one `payment`.
- Exactly one linked `premium_subscription`.
- Premium screen refreshed in the app.
- Duplicate webhook returning a successful idempotent outcome.

Do not include JWTs, Stripe secrets, webhook secrets or full request headers.

- [ ] **Step 7: Final regression and diff review**

```powershell
git status --short
git diff --check
git diff --stat HEAD~6..HEAD
```

Verify `.chrome-diagram-v3/` and `.superpowers/` remain untracked and are not
included in any commit.

- [ ] **Step 8: Commit the runbook**

```powershell
git add backend/supabase/functions/subscription-payment/README.md
git commit -m "docs: add Stripe Sandbox verification runbook"
```

---

## Final Acceptance Checklist

- [ ] Legacy payment RPCs cannot be executed by `anon` or `authenticated`.
- [ ] Client roles cannot insert/update/delete payment or Premium rows.
- [ ] Only a verified Stripe Sandbox Session can reach finalize.
- [ ] Amount, currency, user, attempt and Session ID all match.
- [ ] Callback and webhook are idempotent under concurrent execution.
- [ ] Payment/Premium/voucher persistence occurs in one transaction.
- [ ] Closing the browser after payment does not lose entitlement.
- [ ] UI explicitly says test mode, no real charge and no automatic renewal.
- [ ] All pgTAP, Deno and Flutter tests pass.
- [ ] Security Advisor no longer reports the two payment elevation paths.
- [ ] Architecture/report calls this `Stripe Checkout Sandbox`, not a production recurring subscription.
