create extension if not exists pgcrypto;

create table if not exists public.loyalty_tier_config (
    tier_code text primary key,
    tier_name text not null,
    min_tier_points integer not null default 0 check (min_tier_points >= 0),
    priority integer not null unique,
    token_bonus_on_upgrade integer not null default 0 check (token_bonus_on_upgrade >= 0),
    color_hex text null,
    is_active boolean not null default true,
    created_at timestamp with time zone not null default now()
);

create table if not exists public.user_loyalty_account (
    id_user uuid primary key references public.user_account(id_user) on delete cascade,
    available_points integer not null default 0 check (available_points >= 0),
    lifetime_points integer not null default 0 check (lifetime_points >= 0),
    tier_points integer not null default 0 check (tier_points >= 0),
    token_balance integer not null default 0 check (token_balance >= 0),
    current_tier text not null default 'member' references public.loyalty_tier_config(tier_code),
    highest_tier text not null default 'member' references public.loyalty_tier_config(tier_code),
    tier_cycle_started_at timestamp with time zone not null default now(),
    tier_cycle_ends_at timestamp with time zone not null default (now() + interval '6 months'),
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now()
);

create table if not exists public.loyalty_rule_config (
    rule_code text primary key,
    rule_name text not null,
    action_type text not null,
    point_amount integer not null default 0,
    tier_point_amount integer not null default 0,
    token_cost integer not null default 0 check (token_cost >= 0),
    daily_limit_count integer null,
    daily_limit_points integer null,
    requires_approval boolean not null default false,
    is_active boolean not null default true,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamp with time zone not null default now()
);

create table if not exists public.loyalty_transaction (
    id_transaction uuid primary key default gen_random_uuid(),
    id_user uuid not null references public.user_account(id_user) on delete cascade,
    transaction_type text not null,
    source_type text null,
    reference_table text null,
    reference_id uuid null,
    point_change integer not null default 0,
    tier_point_change integer not null default 0,
    token_change integer not null default 0,
    status text not null default 'approved',
    description text null,
    metadata jsonb not null default '{}'::jsonb,
    approved_by uuid null references public.user_account(id_user) on delete set null,
    approved_at timestamp with time zone null,
    created_at timestamp with time zone not null default now(),
    constraint loyalty_transaction_status_check check (status in ('pending', 'approved', 'rejected')),
    constraint loyalty_transaction_type_check check (
        transaction_type in (
            'earn',
            'redeem_tokens',
            'use_tokens',
            'refund_tokens',
            'redeem_voucher',
            'tier_upgrade',
            'tier_cycle'
        )
    )
);

create table if not exists public.token_usage (
    id_usage uuid primary key default gen_random_uuid(),
    id_user uuid not null references public.user_account(id_user) on delete cascade,
    feature_type text not null,
    reference_id uuid null,
    token_cost integer not null check (token_cost > 0),
    usage_status text not null default 'used',
    failure_reason text null,
    created_at timestamp with time zone not null default now(),
    refunded_at timestamp with time zone null,
    constraint token_usage_status_check check (usage_status in ('used', 'refunded', 'failed'))
);

create table if not exists public.voucher_config (
    id_voucher uuid primary key default gen_random_uuid(),
    voucher_code text not null unique,
    title text not null,
    description text null,
    points_required integer not null check (points_required >= 0),
    discount_type text not null default 'fixed',
    discount_value integer not null default 0,
    target_type text null,
    valid_days integer not null default 30 check (valid_days > 0),
    quota_total integer null,
    quota_used integer not null default 0 check (quota_used >= 0),
    is_active boolean not null default true,
    starts_at timestamp with time zone null,
    ends_at timestamp with time zone null,
    created_at timestamp with time zone not null default now(),
    constraint voucher_config_discount_type_check check (discount_type in ('fixed', 'percent', 'free_feature', 'subscription')),
    constraint voucher_config_target_type_check check (
        target_type is null or target_type in ('subscription', 'food', 'place', 'activity', 'culture', 'local_product', 'system')
    )
);

create table if not exists public.voucher_wallet (
    id_wallet uuid primary key default gen_random_uuid(),
    id_user uuid not null references public.user_account(id_user) on delete cascade,
    id_voucher uuid not null references public.voucher_config(id_voucher) on delete cascade,
    wallet_code text not null unique,
    status text not null default 'available',
    redeemed_at timestamp with time zone not null default now(),
    used_at timestamp with time zone null,
    expires_at timestamp with time zone null,
    metadata jsonb not null default '{}'::jsonb,
    constraint voucher_wallet_status_check check (status in ('available', 'used', 'expired', 'cancelled'))
);

create table if not exists public.loyalty_daily_counter (
    id_user uuid not null references public.user_account(id_user) on delete cascade,
    action_type text not null,
    counter_date date not null default current_date,
    action_count integer not null default 0 check (action_count >= 0),
    points_earned integer not null default 0 check (points_earned >= 0),
    tokens_redeemed integer not null default 0 check (tokens_redeemed >= 0),
    updated_at timestamp with time zone not null default now(),
    primary key (id_user, action_type, counter_date)
);

insert into public.loyalty_tier_config (tier_code, tier_name, min_tier_points, priority, token_bonus_on_upgrade, color_hex)
values
    ('member', 'Member', 0, 1, 0, '#38BDF8'),
    ('silver', 'Silver', 500, 2, 5, '#94A3B8'),
    ('gold', 'Gold', 1500, 3, 15, '#FBBF24'),
    ('platinum', 'Platinum', 3500, 4, 30, '#67E8F9'),
    ('diamond', 'Diamond', 7000, 5, 60, '#A78BFA')
on conflict (tier_code) do update set
    tier_name = excluded.tier_name,
    min_tier_points = excluded.min_tier_points,
    priority = excluded.priority,
    token_bonus_on_upgrade = excluded.token_bonus_on_upgrade,
    color_hex = excluded.color_hex,
    is_active = true;

insert into public.loyalty_rule_config (rule_code, rule_name, action_type, point_amount, tier_point_amount, token_cost, daily_limit_count, daily_limit_points, requires_approval, metadata)
values
    ('daily_login', 'Daily login', 'daily_login', 10, 10, 0, 1, 10, false, '{}'::jsonb),
    ('wishlist_add', 'Add item to wishlist', 'wishlist_add', 5, 5, 0, 10, 50, false, '{}'::jsonb),
    ('forum_post', 'Create a forum post', 'forum_post', 15, 15, 0, 5, 75, false, '{}'::jsonb),
    ('review_submit', 'Submit a review', 'review_submit', 20, 20, 0, 5, 100, true, '{}'::jsonb),
    ('check_in', 'Check in at a place', 'check_in', 30, 30, 0, 3, 90, true, '{}'::jsonb),
    ('subscription_purchase', 'Buy premium subscription', 'subscription_purchase', 100, 100, 0, null, null, false, '{"todo":"Adjust points by paid amount when VND revenue fields are finalized."}'::jsonb),
    ('ai_object_recognition', 'AI object recognition', 'ai_object_recognition', 0, 0, 1, null, null, false, '{}'::jsonb),
    ('translation', 'Translation', 'translation', 0, 0, 1, null, null, false, '{}'::jsonb),
    ('trip_planner', 'Trip planner', 'trip_planner', 0, 0, 2, null, null, false, '{}'::jsonb)
on conflict (rule_code) do update set
    rule_name = excluded.rule_name,
    action_type = excluded.action_type,
    point_amount = excluded.point_amount,
    tier_point_amount = excluded.tier_point_amount,
    token_cost = excluded.token_cost,
    daily_limit_count = excluded.daily_limit_count,
    daily_limit_points = excluded.daily_limit_points,
    requires_approval = excluded.requires_approval,
    metadata = excluded.metadata,
    is_active = true;

insert into public.voucher_config (voucher_code, title, description, points_required, discount_type, discount_value, target_type, valid_days, quota_total)
values
    ('LOYAL-STARTER', 'Starter Premium Discount', 'A starter reward for your next premium subscription.', 200, 'fixed', 200, 'subscription', 30, null),
    ('LOYAL-PLUS10', '10% Premium Discount', 'Save 10% on a premium upgrade.', 600, 'percent', 10, 'subscription', 30, null),
    ('LOYAL-AI', 'Free AI Token Bundle', 'Redeem a voucher for AI-powered travel help.', 350, 'free_feature', 5, 'system', 14, null)
on conflict (voucher_code) do update set
    title = excluded.title,
    description = excluded.description,
    points_required = excluded.points_required,
    discount_type = excluded.discount_type,
    discount_value = excluded.discount_value,
    target_type = excluded.target_type,
    valid_days = excluded.valid_days,
    quota_total = excluded.quota_total,
    is_active = true;

create or replace function public.is_admin_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.user_account ua
        where ua.id_user = auth.uid()
          and ua.role = 'admin'
    );
$$;

create or replace function public.ensure_loyalty_account(p_user uuid)
returns public.user_loyalty_account
language plpgsql
security definer
set search_path = public
as $$
declare
    v_account public.user_loyalty_account;
begin
    if auth.uid() is null then
        raise exception 'AUTH_REQUIRED';
    end if;

    if auth.uid() <> p_user and not public.is_admin_user() then
        raise exception 'FORBIDDEN';
    end if;

    insert into public.user_loyalty_account (id_user)
    values (p_user)
    on conflict (id_user) do update set updated_at = public.user_loyalty_account.updated_at
    returning * into v_account;

    return v_account;
end;
$$;

create or replace function public.evaluate_user_tier(p_user uuid)
returns public.user_loyalty_account
language plpgsql
security definer
set search_path = public
as $$
declare
    v_account public.user_loyalty_account;
    v_target public.loyalty_tier_config;
    v_current_priority integer;
    v_highest_priority integer;
begin
    select * into v_account from public.ensure_loyalty_account(p_user);

    select * into v_target
    from public.loyalty_tier_config
    where is_active = true and min_tier_points <= v_account.tier_points
    order by priority desc
    limit 1;

    select priority into v_current_priority
    from public.loyalty_tier_config
    where tier_code = v_account.current_tier;

    select priority into v_highest_priority
    from public.loyalty_tier_config
    where tier_code = v_account.highest_tier;

    if v_target.tier_code is not null and v_target.priority > coalesce(v_current_priority, 0) then
        update public.user_loyalty_account
        set current_tier = v_target.tier_code,
            highest_tier = case when v_target.priority > coalesce(v_highest_priority, 0) then v_target.tier_code else highest_tier end,
            token_balance = token_balance + v_target.token_bonus_on_upgrade,
            updated_at = now()
        where id_user = p_user
        returning * into v_account;

        insert into public.loyalty_transaction (
            id_user, transaction_type, source_type, token_change, status, description, metadata
        )
        values (
            p_user,
            'tier_upgrade',
            v_target.tier_code,
            v_target.token_bonus_on_upgrade,
            'approved',
            'Tier upgraded to ' || v_target.tier_name,
            jsonb_build_object('tier', v_target.tier_code)
        );
    end if;

    return v_account;
end;
$$;

create or replace function public.earn_loyalty_points(
    p_user uuid,
    p_action_type text,
    p_reference_table text default null,
    p_reference_id uuid default null,
    p_description text default null,
    p_metadata jsonb default '{}'::jsonb
)
returns public.loyalty_transaction
language plpgsql
security definer
set search_path = public
as $$
declare
    v_rule public.loyalty_rule_config;
    v_counter public.loyalty_daily_counter;
    v_status text;
    v_tx public.loyalty_transaction;
begin
    perform public.ensure_loyalty_account(p_user);

    if auth.uid() <> p_user and not public.is_admin_user() then
        raise exception 'FORBIDDEN';
    end if;

    select * into v_rule
    from public.loyalty_rule_config
    where action_type = p_action_type and is_active = true
    limit 1;

    if v_rule.rule_code is null then
        raise exception 'LOYALTY_RULE_NOT_FOUND';
    end if;

    insert into public.loyalty_daily_counter (id_user, action_type, counter_date)
    values (p_user, p_action_type, current_date)
    on conflict (id_user, action_type, counter_date) do update set updated_at = now()
    returning * into v_counter;

    if v_rule.daily_limit_count is not null and v_counter.action_count >= v_rule.daily_limit_count then
        raise exception 'DAILY_ACTION_LIMIT_REACHED';
    end if;

    if v_rule.daily_limit_points is not null and v_counter.points_earned + greatest(v_rule.point_amount, 0) > v_rule.daily_limit_points then
        raise exception 'DAILY_POINT_LIMIT_REACHED';
    end if;

    v_status := case when v_rule.requires_approval then 'pending' else 'approved' end;

    insert into public.loyalty_transaction (
        id_user, transaction_type, source_type, reference_table, reference_id,
        point_change, tier_point_change, token_change, status, description, metadata
    )
    values (
        p_user, 'earn', p_action_type, p_reference_table, p_reference_id,
        v_rule.point_amount, v_rule.tier_point_amount, 0, v_status,
        coalesce(p_description, v_rule.rule_name), coalesce(p_metadata, '{}'::jsonb)
    )
    returning * into v_tx;

    update public.loyalty_daily_counter
    set action_count = action_count + 1,
        points_earned = points_earned + greatest(v_rule.point_amount, 0),
        updated_at = now()
    where id_user = p_user and action_type = p_action_type and counter_date = current_date;

    if v_status = 'approved' then
        update public.user_loyalty_account
        set available_points = available_points + v_rule.point_amount,
            lifetime_points = lifetime_points + greatest(v_rule.point_amount, 0),
            tier_points = tier_points + v_rule.tier_point_amount,
            updated_at = now()
        where id_user = p_user;

        perform public.evaluate_user_tier(p_user);
    end if;

    return v_tx;
end;
$$;

create or replace function public.approve_loyalty_transaction(p_transaction uuid)
returns public.loyalty_transaction
language plpgsql
security definer
set search_path = public
as $$
declare
    v_tx public.loyalty_transaction;
begin
    if not public.is_admin_user() then
        raise exception 'FORBIDDEN';
    end if;

    select * into v_tx
    from public.loyalty_transaction
    where id_transaction = p_transaction
    for update;

    if v_tx.id_transaction is null then
        raise exception 'TRANSACTION_NOT_FOUND';
    end if;
    if v_tx.status <> 'pending' then
        return v_tx;
    end if;

    update public.user_loyalty_account
    set available_points = greatest(0, available_points + v_tx.point_change),
        lifetime_points = lifetime_points + greatest(v_tx.point_change, 0),
        tier_points = greatest(0, tier_points + v_tx.tier_point_change),
        token_balance = greatest(0, token_balance + v_tx.token_change),
        updated_at = now()
    where id_user = v_tx.id_user;

    update public.loyalty_transaction
    set status = 'approved', approved_by = auth.uid(), approved_at = now()
    where id_transaction = p_transaction
    returning * into v_tx;

    perform public.evaluate_user_tier(v_tx.id_user);
    return v_tx;
end;
$$;

create or replace function public.reject_loyalty_transaction(p_transaction uuid)
returns public.loyalty_transaction
language plpgsql
security definer
set search_path = public
as $$
declare
    v_tx public.loyalty_transaction;
begin
    if not public.is_admin_user() then
        raise exception 'FORBIDDEN';
    end if;

    update public.loyalty_transaction
    set status = 'rejected', approved_by = auth.uid(), approved_at = now()
    where id_transaction = p_transaction and status = 'pending'
    returning * into v_tx;

    if v_tx.id_transaction is null then
        select * into v_tx from public.loyalty_transaction where id_transaction = p_transaction;
    end if;
    return v_tx;
end;
$$;

create or replace function public.redeem_points_to_tokens(p_user uuid, p_token_amount integer)
returns public.loyalty_transaction
language plpgsql
security definer
set search_path = public
as $$
declare
    v_points integer;
    v_today_tokens integer;
    v_tx public.loyalty_transaction;
begin
    perform public.ensure_loyalty_account(p_user);

    if auth.uid() <> p_user then
        raise exception 'FORBIDDEN';
    end if;
    if p_token_amount <= 0 then
        raise exception 'INVALID_TOKEN_AMOUNT';
    end if;

    v_points := p_token_amount * 10;

    select coalesce(sum(token_change), 0) into v_today_tokens
    from public.loyalty_transaction
    where id_user = p_user
      and transaction_type = 'redeem_tokens'
      and status = 'approved'
      and created_at >= date_trunc('day', now());

    if v_today_tokens + p_token_amount > 50 then
        raise exception 'DAILY_TOKEN_REDEEM_LIMIT_REACHED';
    end if;

    update public.user_loyalty_account
    set available_points = available_points - v_points,
        token_balance = token_balance + p_token_amount,
        updated_at = now()
    where id_user = p_user and available_points >= v_points
    returning id_user into p_user;

    if not found then
        raise exception 'NOT_ENOUGH_POINTS';
    end if;

    insert into public.loyalty_transaction (
        id_user, transaction_type, point_change, token_change, status, description
    )
    values (p_user, 'redeem_tokens', -v_points, p_token_amount, 'approved', 'Redeemed points to tokens')
    returning * into v_tx;

    return v_tx;
end;
$$;

create or replace function public.use_tokens(
    p_user uuid,
    p_feature_type text,
    p_reference_id uuid default null
)
returns public.token_usage
language plpgsql
security definer
set search_path = public
as $$
declare
    v_rule public.loyalty_rule_config;
    v_usage public.token_usage;
begin
    perform public.ensure_loyalty_account(p_user);

    if auth.uid() <> p_user then
        raise exception 'FORBIDDEN';
    end if;

    select * into v_rule
    from public.loyalty_rule_config
    where action_type = p_feature_type and is_active = true and token_cost > 0
    limit 1;

    if v_rule.rule_code is null then
        raise exception 'TOKEN_RULE_NOT_FOUND';
    end if;

    update public.user_loyalty_account
    set token_balance = token_balance - v_rule.token_cost,
        updated_at = now()
    where id_user = p_user and token_balance >= v_rule.token_cost;

    if not found then
        raise exception 'NOT_ENOUGH_TOKENS';
    end if;

    insert into public.token_usage (id_user, feature_type, reference_id, token_cost)
    values (p_user, p_feature_type, p_reference_id, v_rule.token_cost)
    returning * into v_usage;

    insert into public.loyalty_transaction (
        id_user, transaction_type, source_type, reference_table, reference_id, token_change, status, description
    )
    values (
        p_user, 'use_tokens', p_feature_type, 'token_usage', v_usage.id_usage,
        -v_rule.token_cost, 'approved', 'Used tokens for ' || p_feature_type
    );

    return v_usage;
end;
$$;

create or replace function public.refund_tokens(p_user uuid, p_usage_id uuid, p_reason text)
returns public.token_usage
language plpgsql
security definer
set search_path = public
as $$
declare
    v_usage public.token_usage;
begin
    if auth.uid() <> p_user and not public.is_admin_user() then
        raise exception 'FORBIDDEN';
    end if;

    select * into v_usage
    from public.token_usage
    where id_usage = p_usage_id and id_user = p_user
    for update;

    if v_usage.id_usage is null then
        raise exception 'TOKEN_USAGE_NOT_FOUND';
    end if;
    if v_usage.usage_status = 'refunded' then
        return v_usage;
    end if;

    update public.user_loyalty_account
    set token_balance = token_balance + v_usage.token_cost,
        updated_at = now()
    where id_user = p_user;

    update public.token_usage
    set usage_status = 'refunded',
        failure_reason = p_reason,
        refunded_at = now()
    where id_usage = p_usage_id
    returning * into v_usage;

    insert into public.loyalty_transaction (
        id_user, transaction_type, source_type, reference_table, reference_id, token_change, status, description
    )
    values (
        p_user, 'refund_tokens', v_usage.feature_type, 'token_usage', p_usage_id,
        v_usage.token_cost, 'approved', coalesce(p_reason, 'Token refund')
    );

    return v_usage;
end;
$$;

create or replace function public.redeem_voucher(p_user uuid, p_voucher_id uuid)
returns public.voucher_wallet
language plpgsql
security definer
set search_path = public
as $$
declare
    v_voucher public.voucher_config;
    v_wallet public.voucher_wallet;
begin
    perform public.ensure_loyalty_account(p_user);

    if auth.uid() <> p_user then
        raise exception 'FORBIDDEN';
    end if;

    select * into v_voucher
    from public.voucher_config
    where id_voucher = p_voucher_id
      and is_active = true
      and (starts_at is null or starts_at <= now())
      and (ends_at is null or ends_at >= now())
      and (quota_total is null or quota_used < quota_total)
    for update;

    if v_voucher.id_voucher is null then
        raise exception 'VOUCHER_NOT_AVAILABLE';
    end if;

    update public.user_loyalty_account
    set available_points = available_points - v_voucher.points_required,
        updated_at = now()
    where id_user = p_user and available_points >= v_voucher.points_required;

    if not found then
        raise exception 'NOT_ENOUGH_POINTS';
    end if;

    update public.voucher_config
    set quota_used = quota_used + 1
    where id_voucher = p_voucher_id;

    insert into public.voucher_wallet (
        id_user, id_voucher, wallet_code, expires_at
    )
    values (
        p_user,
        p_voucher_id,
        'LOY-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)),
        now() + make_interval(days => v_voucher.valid_days)
    )
    returning * into v_wallet;

    insert into public.loyalty_transaction (
        id_user, transaction_type, source_type, reference_table, reference_id,
        point_change, status, description, metadata
    )
    values (
        p_user,
        'redeem_voucher',
        v_voucher.voucher_code,
        'voucher_wallet',
        v_wallet.id_wallet,
        -v_voucher.points_required,
        'approved',
        'Redeemed voucher ' || v_voucher.title,
        jsonb_build_object('voucher_id', p_voucher_id, 'wallet_code', v_wallet.wallet_code)
    );

    return v_wallet;
end;
$$;

create or replace function public.close_tier_cycle(p_user uuid)
returns public.user_loyalty_account
language plpgsql
security definer
set search_path = public
as $$
declare
    v_account public.user_loyalty_account;
    v_current_priority integer;
    v_new_tier text;
begin
    select * into v_account from public.ensure_loyalty_account(p_user);

    if auth.uid() <> p_user and not public.is_admin_user() then
        raise exception 'FORBIDDEN';
    end if;

    if v_account.tier_cycle_ends_at > now() then
        return v_account;
    end if;

    select priority into v_current_priority
    from public.loyalty_tier_config
    where tier_code = v_account.current_tier;

    select tier_code into v_new_tier
    from public.loyalty_tier_config
    where is_active = true and priority = greatest(1, coalesce(v_current_priority, 1) - 1);

    update public.user_loyalty_account
    set current_tier = coalesce(v_new_tier, 'member'),
        tier_points = 0,
        tier_cycle_started_at = now(),
        tier_cycle_ends_at = now() + interval '6 months',
        updated_at = now()
    where id_user = p_user
    returning * into v_account;

    insert into public.loyalty_transaction (
        id_user, transaction_type, source_type, status, description, metadata
    )
    values (
        p_user,
        'tier_cycle',
        v_account.current_tier,
        'approved',
        'Tier cycle closed',
        jsonb_build_object('new_tier', v_account.current_tier)
    );

    return v_account;
end;
$$;

alter table public.loyalty_tier_config enable row level security;
alter table public.user_loyalty_account enable row level security;
alter table public.loyalty_rule_config enable row level security;
alter table public.loyalty_transaction enable row level security;
alter table public.token_usage enable row level security;
alter table public.voucher_config enable row level security;
alter table public.voucher_wallet enable row level security;
alter table public.loyalty_daily_counter enable row level security;

drop policy if exists "Active loyalty tiers are readable" on public.loyalty_tier_config;
create policy "Active loyalty tiers are readable" on public.loyalty_tier_config
for select to authenticated using (is_active = true or public.is_admin_user());

drop policy if exists "Admins manage loyalty tiers" on public.loyalty_tier_config;
create policy "Admins manage loyalty tiers" on public.loyalty_tier_config
for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());

drop policy if exists "Users read own loyalty account" on public.user_loyalty_account;
create policy "Users read own loyalty account" on public.user_loyalty_account
for select to authenticated using (id_user = auth.uid() or public.is_admin_user());

drop policy if exists "Active loyalty rules are readable" on public.loyalty_rule_config;
create policy "Active loyalty rules are readable" on public.loyalty_rule_config
for select to authenticated using (is_active = true or public.is_admin_user());

drop policy if exists "Admins manage loyalty rules" on public.loyalty_rule_config;
create policy "Admins manage loyalty rules" on public.loyalty_rule_config
for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());

drop policy if exists "Users read own loyalty transactions" on public.loyalty_transaction;
create policy "Users read own loyalty transactions" on public.loyalty_transaction
for select to authenticated using (id_user = auth.uid() or public.is_admin_user());

drop policy if exists "Users read own token usage" on public.token_usage;
create policy "Users read own token usage" on public.token_usage
for select to authenticated using (id_user = auth.uid() or public.is_admin_user());

drop policy if exists "Active loyalty vouchers are readable" on public.voucher_config;
create policy "Active loyalty vouchers are readable" on public.voucher_config
for select to authenticated using (
    (is_active = true and (starts_at is null or starts_at <= now()) and (ends_at is null or ends_at >= now()))
    or public.is_admin_user()
);

drop policy if exists "Admins manage loyalty vouchers" on public.voucher_config;
create policy "Admins manage loyalty vouchers" on public.voucher_config
for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());

drop policy if exists "Users read own voucher wallet" on public.voucher_wallet;
create policy "Users read own voucher wallet" on public.voucher_wallet
for select to authenticated using (id_user = auth.uid() or public.is_admin_user());

drop policy if exists "Users read own loyalty daily counters" on public.loyalty_daily_counter;
create policy "Users read own loyalty daily counters" on public.loyalty_daily_counter
for select to authenticated using (id_user = auth.uid() or public.is_admin_user());

grant select on public.loyalty_tier_config, public.loyalty_rule_config, public.voucher_config to authenticated;
grant select on public.user_loyalty_account, public.loyalty_transaction, public.token_usage, public.voucher_wallet, public.loyalty_daily_counter to authenticated;
grant execute on function public.ensure_loyalty_account(uuid) to authenticated;
grant execute on function public.earn_loyalty_points(uuid, text, text, uuid, text, jsonb) to authenticated;
grant execute on function public.approve_loyalty_transaction(uuid) to authenticated;
grant execute on function public.reject_loyalty_transaction(uuid) to authenticated;
grant execute on function public.redeem_points_to_tokens(uuid, integer) to authenticated;
grant execute on function public.use_tokens(uuid, text, uuid) to authenticated;
grant execute on function public.refund_tokens(uuid, uuid, text) to authenticated;
grant execute on function public.redeem_voucher(uuid, uuid) to authenticated;
grant execute on function public.evaluate_user_tier(uuid) to authenticated;
grant execute on function public.close_tier_cycle(uuid) to authenticated;
