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

select * from finish();
rollback;
