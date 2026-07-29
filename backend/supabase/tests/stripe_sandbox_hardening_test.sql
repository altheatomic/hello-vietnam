begin;

create extension if not exists pgtap with schema extensions;

select plan(20);

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
          and roles = array['authenticated']::name[]
    ),
    1::bigint,
    'payment has one authenticated ownership SELECT policy'
);

select is(
    (
        select count(*)
        from pg_policies
        where schemaname = 'public'
          and tablename = 'premium_subscription'
          and cmd = 'SELECT'
          and policyname = 'Users can read own premium subscriptions'
          and roles = array['authenticated']::name[]
    ),
    1::bigint,
    'premium_subscription has one authenticated ownership SELECT policy'
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
    not has_table_privilege(
        'authenticated',
        'public.payment',
        'INSERT,UPDATE,DELETE'
    ),
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
    not has_table_privilege(
        'authenticated',
        'public.payment_attempt',
        'SELECT'
    ),
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

insert into public.user_account (id_user, username, full_name)
values (
    '91000000-0000-4000-8000-000000000001',
    'stripe-test-user',
    'Stripe Test User'
);

insert into public.subscription_plan (
    id_subscription_plan,
    code,
    name,
    duration_days,
    price_minor,
    status
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
            where provider = 'stripe'
              and external_ref = 'cs_test_atomic_1'
        )
    ),
    1::bigint,
    'duplicate finalize creates one entitlement'
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

set local role service_role;

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

reset role;

select * from finish();
rollback;
