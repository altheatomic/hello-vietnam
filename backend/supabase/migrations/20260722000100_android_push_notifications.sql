-- Durable in-app and Android push notification infrastructure.

alter table public.notification
    add column if not exists notification_type text,
    add column if not exists icon text,
    add column if not exists push_error text;

update public.notification
set notification_type = coalesce(notification_type, 'account'),
    status = case
        when status in ('queued', 'processing', 'sent', 'partial', 'failed', 'in_app_only') then status
        when coalesce(is_push, false) then 'queued'
        else 'in_app_only'
    end;

alter table public.notification
    alter column notification_type set not null,
    alter column status set default 'queued',
    alter column status set not null,
    alter column is_in_app set default true,
    alter column is_push set default true;

alter table public.notification
    drop constraint if exists notification_notification_type_check;
alter table public.notification
    add constraint notification_notification_type_check
    check (notification_type in ('loyalty', 'forum', 'voucher', 'trip', 'account'));

alter table public.notification
    drop constraint if exists notification_status_check;
alter table public.notification
    add constraint notification_status_check
    check (status in ('queued', 'processing', 'sent', 'partial', 'failed', 'in_app_only'));

create table if not exists public.user_push_device (
    id_device uuid primary key default gen_random_uuid(),
    id_user uuid not null references public.user_account(id_user) on delete cascade,
    fcm_token text not null unique,
    platform text not null,
    installation_id text not null,
    is_active boolean not null default true,
    last_seen_at timestamptz not null default now(),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint user_push_device_platform_check
        check (platform in ('android', 'ios', 'web')),
    constraint user_push_device_user_installation_key
        unique (id_user, installation_id)
);

create table if not exists public.user_notification_preference (
    id_user uuid not null references public.user_account(id_user) on delete cascade,
    notification_type text not null,
    push_enabled boolean not null default true,
    in_app_enabled boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    primary key (id_user, notification_type),
    constraint user_notification_preference_type_check
        check (notification_type in ('all', 'loyalty', 'forum', 'voucher', 'trip', 'account'))
);

create index if not exists idx_notification_user_created
    on public.notification (id_user, created_at desc, id_notification desc);
create index if not exists idx_notification_user_unread
    on public.notification (id_user, created_at desc)
    where read_at is null;
create index if not exists idx_notification_dispatch_queue
    on public.notification (status, created_at)
    where status = 'queued';
create index if not exists idx_user_push_device_active
    on public.user_push_device (id_user, is_active)
    where is_active;

create or replace function public.touch_notification_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists trg_user_push_device_updated_at on public.user_push_device;
create trigger trg_user_push_device_updated_at
before update on public.user_push_device
for each row execute function public.touch_notification_updated_at();

drop trigger if exists trg_user_notification_preference_updated_at
    on public.user_notification_preference;
create trigger trg_user_notification_preference_updated_at
before update on public.user_notification_preference
for each row execute function public.touch_notification_updated_at();

create or replace function public.notification_push_enabled(
    p_id_user uuid,
    p_notification_type text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select
        coalesce((
            select p.push_enabled
            from public.user_notification_preference p
            where p.id_user = p_id_user and p.notification_type = 'all'
        ), true)
        and
        coalesce((
            select p.push_enabled
            from public.user_notification_preference p
            where p.id_user = p_id_user
              and p.notification_type = p_notification_type
        ), true);
$$;

create or replace function public.enqueue_user_notification(
    p_id_user uuid,
    p_notification_type text,
    p_title text,
    p_body text,
    p_icon text,
    p_target jsonb,
    p_is_push boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_id_notification uuid;
    v_in_app_enabled boolean;
begin
    if p_notification_type not in ('loyalty', 'forum', 'voucher', 'trip', 'account') then
        raise exception 'UNSUPPORTED_NOTIFICATION_TYPE' using errcode = '22023';
    end if;

    select
        coalesce((
            select p.in_app_enabled
            from public.user_notification_preference p
            where p.id_user = p_id_user and p.notification_type = 'all'
        ), true)
        and
        coalesce((
            select p.in_app_enabled
            from public.user_notification_preference p
            where p.id_user = p_id_user
              and p.notification_type = p_notification_type
        ), true)
    into v_in_app_enabled;

    if not v_in_app_enabled and not p_is_push then
        return null;
    end if;

    insert into public.notification (
        id_user,
        title,
        body,
        payload_jsonb,
        notification_type,
        icon,
        is_in_app,
        is_push,
        status
    )
    values (
        p_id_user,
        p_title,
        p_body,
        jsonb_build_object('target', coalesce(p_target, '{}'::jsonb)),
        p_notification_type,
        p_icon,
        v_in_app_enabled,
        p_is_push,
        case when p_is_push then 'queued' else 'in_app_only' end
    )
    returning id_notification into v_id_notification;

    return v_id_notification;
end;
$$;

create or replace function public.claim_notification_for_dispatch(
    p_id_notification uuid
)
returns setof public.notification
language plpgsql
security definer
set search_path = public
as $$
begin
    return query
    update public.notification n
    set status = 'processing',
        push_error = null
    where n.id_notification = p_id_notification
      and n.status = 'queued'
    returning n.*;
end;
$$;

create or replace function public.notify_approved_loyalty_transaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.status = 'approved'
       and new.point_change > 0
       and (tg_op = 'INSERT' or old.status is distinct from 'approved') then
        perform public.enqueue_user_notification(
            new.id_user,
            'loyalty',
            'Loyalty points earned',
            format('You earned %s loyalty points.', new.point_change),
            'star',
            jsonb_build_object(
                'kind', 'loyaltyRewards',
                'entityId', new.id_transaction,
                'metadata', jsonb_build_object(
                    'pointChange', new.point_change,
                    'sourceType', coalesce(new.source_type, '')
                )
            ),
            true
        );
    end if;
    return new;
end;
$$;

drop trigger if exists trg_notify_approved_loyalty_transaction
    on public.loyalty_transaction;
create trigger trg_notify_approved_loyalty_transaction
after insert or update of status on public.loyalty_transaction
for each row execute function public.notify_approved_loyalty_transaction();

create or replace function public.notify_forum_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_post_author uuid;
begin
    select p.id_author_user
    into v_post_author
    from public.forum_post p
    where p.id_post = new.id_post;

    if v_post_author is not null
       and v_post_author is distinct from new.id_author_user
       and coalesce(new.status, 'active') not in ('blocked', 'deleted') then
        perform public.enqueue_user_notification(
            v_post_author,
            'forum',
            'New reply to your post',
            left(coalesce(new.content, 'Someone replied to your post.'), 180),
            'comment',
            jsonb_build_object(
                'kind', 'forumPost',
                'entityId', new.id_post,
                'metadata', jsonb_build_object('commentId', new.id_comment)
            ),
            true
        );
    end if;
    return new;
end;
$$;

drop trigger if exists trg_notify_forum_comment on public.forum_comment;
create trigger trg_notify_forum_comment
after insert on public.forum_comment
for each row execute function public.notify_forum_comment();

create or replace function public.notify_voucher_wallet_grant()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_title text;
begin
    if new.status = 'available' then
        select v.title into v_title
        from public.voucher_config v
        where v.id_voucher = new.id_voucher;

        perform public.enqueue_user_notification(
            new.id_user,
            'voucher',
            'You received a voucher',
            coalesce(v_title, 'A new voucher is ready in your wallet.'),
            'gift',
            jsonb_build_object(
                'kind', 'voucherCenter',
                'entityId', new.id_wallet
            ),
            true
        );
    end if;
    return new;
end;
$$;

drop trigger if exists trg_notify_voucher_wallet_grant on public.voucher_wallet;
create trigger trg_notify_voucher_wallet_grant
after insert on public.voucher_wallet
for each row execute function public.notify_voucher_wallet_grant();

create or replace function public.notify_saved_trip_plan()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.status = 'saved'
       and (tg_op = 'INSERT' or old.status is distinct from 'saved') then
        perform public.enqueue_user_notification(
            new.id_user,
            'trip',
            'Your itinerary is ready',
            coalesce(new.custom_title, 'Your saved itinerary is ready to view.'),
            'calendar',
            jsonb_build_object(
                'kind', 'tripPlannerSaved',
                'entityId', new.id_plan
            ),
            true
        );
    end if;
    return new;
end;
$$;

drop trigger if exists trg_notify_saved_trip_plan on public.plan;
create trigger trg_notify_saved_trip_plan
after insert or update of status on public.plan
for each row execute function public.notify_saved_trip_plan();

create or replace function public.notify_active_subscription()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.status = 'active'
       and (tg_op = 'INSERT' or old.status is distinct from 'active') then
        perform public.enqueue_user_notification(
            new.id_user,
            'account',
            'Premium activated',
            'Your Premium subscription is now active.',
            'badge',
            jsonb_build_object(
                'kind', 'upgradeAccount',
                'entityId', new.id_prs,
                'metadata', jsonb_build_object(
                    'endDate', coalesce(new.end_date::text, '')
                )
            ),
            true
        );
    end if;
    return new;
end;
$$;

drop trigger if exists trg_notify_active_subscription
    on public.premium_subscription;
create trigger trg_notify_active_subscription
after insert or update of status on public.premium_subscription
for each row execute function public.notify_active_subscription();

alter table public.notification enable row level security;
alter table public.user_push_device enable row level security;
alter table public.user_notification_preference enable row level security;

drop policy if exists "Users read own notifications" on public.notification;
create policy "Users read own notifications"
on public.notification for select to authenticated
using (id_user = auth.uid());

drop policy if exists "Users mark own notifications read" on public.notification;
create policy "Users mark own notifications read"
on public.notification for update to authenticated
using (id_user = auth.uid())
with check (id_user = auth.uid());

drop policy if exists "Users read own push devices" on public.user_push_device;
create policy "Users read own push devices"
on public.user_push_device for select to authenticated
using (id_user = auth.uid());

drop policy if exists "Users insert own push devices" on public.user_push_device;
create policy "Users insert own push devices"
on public.user_push_device for insert to authenticated
with check (id_user = auth.uid());

drop policy if exists "Users update own push devices" on public.user_push_device;
create policy "Users update own push devices"
on public.user_push_device for update to authenticated
using (id_user = auth.uid())
with check (id_user = auth.uid());

drop policy if exists "Users delete own push devices" on public.user_push_device;
create policy "Users delete own push devices"
on public.user_push_device for delete to authenticated
using (id_user = auth.uid());

drop policy if exists "Users read own notification preferences"
    on public.user_notification_preference;
create policy "Users read own notification preferences"
on public.user_notification_preference for select to authenticated
using (id_user = auth.uid());

drop policy if exists "Users insert own notification preferences"
    on public.user_notification_preference;
create policy "Users insert own notification preferences"
on public.user_notification_preference for insert to authenticated
with check (id_user = auth.uid());

drop policy if exists "Users update own notification preferences"
    on public.user_notification_preference;
create policy "Users update own notification preferences"
on public.user_notification_preference for update to authenticated
using (id_user = auth.uid())
with check (id_user = auth.uid());

revoke all on public.user_push_device from anon;
revoke all on public.user_notification_preference from anon;
revoke insert, delete on public.notification from anon, authenticated;
revoke update on public.notification from authenticated;

grant select on public.notification to authenticated;
grant update (read_at) on public.notification to authenticated;
grant select, insert, update, delete on public.user_push_device to authenticated;
grant select, insert, update on public.user_notification_preference to authenticated;

revoke all on function public.enqueue_user_notification(uuid, text, text, text, text, jsonb, boolean)
    from public, anon, authenticated;
grant execute on function public.enqueue_user_notification(uuid, text, text, text, text, jsonb, boolean)
    to service_role;

revoke all on function public.claim_notification_for_dispatch(uuid)
    from public, anon, authenticated;
grant execute on function public.claim_notification_for_dispatch(uuid)
    to service_role;

revoke all on function public.notification_push_enabled(uuid, text)
    from public, anon, authenticated;
grant execute on function public.notification_push_enabled(uuid, text)
    to service_role;
