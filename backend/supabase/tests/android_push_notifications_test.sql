begin;

create extension if not exists pgtap with schema extensions;

select plan(16);

select has_table('public', 'user_push_device');
select has_table('public', 'user_notification_preference');
select has_column('public', 'notification', 'notification_type');
select has_column('public', 'notification', 'push_error');
select has_function(
    'public',
    'enqueue_user_notification',
    array['uuid', 'text', 'text', 'text', 'text', 'jsonb', 'boolean']
);
select has_function(
    'public',
    'notification_push_enabled',
    array['uuid', 'text']
);
select has_function(
    'public',
    'claim_notification_for_dispatch',
    array['uuid']
);
select has_function(
    'public',
    'dispatch_notification_webhook',
    array[]::text[]
);
select has_trigger(
    'public',
    'notification',
    'trg_dispatch_notification_webhook'
);
select col_is_pk('public', 'user_push_device', 'id_device');
select col_is_pk(
    'public',
    'user_notification_preference',
    array['id_user', 'notification_type']
);

insert into public.user_account (id_user, username, full_name)
values
    ('10000000-0000-4000-8000-000000000001', 'push-owner', 'Push Owner'),
    ('10000000-0000-4000-8000-000000000002', 'push-actor', 'Push Actor');

insert into public.loyalty_transaction (
    id_transaction,
    id_user,
    transaction_type,
    source_type,
    point_change,
    status,
    description
) values (
    '20000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    'earn',
    'daily_login',
    10,
    'approved',
    'Daily login'
);

select is(
    (
        select count(*)
        from public.notification
        where id_user = '10000000-0000-4000-8000-000000000001'
          and notification_type = 'loyalty'
          and payload_jsonb #>> '{target,kind}' = 'loyaltyRewards'
    ),
    1::bigint,
    'approved loyalty awards enqueue a loyalty notification'
);

insert into public.forum_topic (id_topic, created_by, title, status)
values (
    '30000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    'Push test topic',
    'active'
);
insert into public.forum_post (
    id_post,
    id_topic,
    id_author_user,
    title,
    content,
    status
) values (
    '30000000-0000-4000-8000-000000000002',
    '30000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    'Push test post',
    'Testing forum notifications',
    'active'
);
insert into public.forum_comment (
    id_comment,
    id_post,
    id_author_user,
    content,
    status
) values (
    '30000000-0000-4000-8000-000000000003',
    '30000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002',
    'A real reply',
    'active'
);

select is(
    (
        select count(*)
        from public.notification
        where id_user = '10000000-0000-4000-8000-000000000001'
          and notification_type = 'forum'
          and payload_jsonb #>> '{target,kind}' = 'forumPost'
    ),
    1::bigint,
    'comments enqueue a forum notification for the post owner'
);

insert into public.voucher_config (
    id_voucher,
    voucher_code,
    title,
    points_required,
    discount_type,
    discount_value
) values (
    '40000000-0000-4000-8000-000000000001',
    'PUSH-TEST',
    'Push test voucher',
    10,
    'percent',
    10
);
insert into public.voucher_wallet (
    id_wallet,
    id_user,
    id_voucher,
    wallet_code,
    status
) values (
    '40000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    'PUSH-WALLET-TEST',
    'available'
);

select is(
    (
        select count(*)
        from public.notification
        where id_user = '10000000-0000-4000-8000-000000000001'
          and notification_type = 'voucher'
          and payload_jsonb #>> '{target,kind}' = 'voucherCenter'
    ),
    1::bigint,
    'wallet grants enqueue a voucher notification'
);

insert into public.plan (
    id_plan,
    id_user,
    duration,
    city_province,
    status,
    custom_title
) values (
    '50000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '3 days',
    'Da Nang',
    'saved',
    'Push test trip'
);

select is(
    (
        select count(*)
        from public.notification
        where id_user = '10000000-0000-4000-8000-000000000001'
          and notification_type = 'trip'
          and payload_jsonb #>> '{target,kind}' = 'tripPlannerSaved'
    ),
    1::bigint,
    'saved plans enqueue a trip notification'
);

insert into public.subscription_plan (
    id_subscription_plan,
    code,
    name,
    duration_days,
    price_minor,
    status
) values (
    '60000000-0000-4000-8000-000000000001',
    'push-test-plan',
    'Push test plan',
    30,
    100,
    'active'
);
insert into public.premium_subscription (
    id_prs,
    id_user,
    id_plan,
    start_date,
    end_date,
    currency,
    status
) values (
    '60000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    '60000000-0000-4000-8000-000000000001',
    now(),
    now() + interval '30 days',
    'USD',
    'active'
);

select is(
    (
        select count(*)
        from public.notification
        where id_user = '10000000-0000-4000-8000-000000000001'
          and notification_type = 'account'
          and payload_jsonb #>> '{target,kind}' = 'upgradeAccount'
    ),
    1::bigint,
    'active subscriptions enqueue an account notification'
);

select * from finish();
rollback;
