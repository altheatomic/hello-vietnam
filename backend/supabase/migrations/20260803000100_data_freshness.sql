create extension if not exists "pgcrypto";
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema extensions;

create table if not exists public.content_freshness (
    id uuid primary key default gen_random_uuid(),
    content_type text not null check (
        content_type in ('place', 'activity', 'culture', 'food', 'local_product')
    ),
    content_id uuid not null,
    source_type text not null,
    source_url text,
    source_external_id text,
    availability_type text not null default 'evergreen' check (
        availability_type in ('business', 'scheduled_event', 'evergreen', 'seasonal')
    ),
    valid_from timestamp with time zone,
    valid_until timestamp with time zone,
    freshness_status text not null default 'due' check (
        freshness_status in ('fresh', 'due', 'stale', 'needs_review', 'expired')
    ),
    last_checked_at timestamp with time zone,
    last_verified_at timestamp with time zone,
    next_check_at timestamp with time zone not null default now(),
    source_hash text,
    consecutive_missing_count integer not null default 0 check (
        consecutive_missing_count >= 0
    ),
    last_error text,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    unique (content_type, content_id)
);

create unique index if not exists content_freshness_source_identity_idx
    on public.content_freshness (content_type, source_type, source_external_id)
    where source_external_id is not null;

create index if not exists content_freshness_due_idx
    on public.content_freshness (next_check_at, freshness_status);

create index if not exists content_freshness_status_idx
    on public.content_freshness (content_type, freshness_status, content_id);

create table if not exists public.content_change_proposal (
    id uuid primary key default gen_random_uuid(),
    freshness_id uuid not null references public.content_freshness(id) on delete cascade,
    change_type text not null,
    before_data jsonb not null default '{}'::jsonb,
    proposed_data jsonb not null default '{}'::jsonb,
    changed_fields jsonb not null default '[]'::jsonb,
    reason text not null,
    confidence numeric(5, 4),
    decision text not null default 'pending' check (
        decision in ('pending', 'auto_applied', 'approved', 'rejected')
    ),
    detected_at timestamp with time zone not null default now(),
    reviewed_at timestamp with time zone,
    reviewed_by uuid references public.user_account(id_user),
    applied_data jsonb,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now()
);

create unique index if not exists content_change_proposal_one_pending_idx
    on public.content_change_proposal (freshness_id)
    where decision = 'pending';

create index if not exists content_change_proposal_queue_idx
    on public.content_change_proposal (decision, detected_at desc);

create table if not exists public.content_report (
    id uuid primary key default gen_random_uuid(),
    reporter_user_id uuid not null references public.user_account(id_user) on delete cascade,
    content_type text not null check (
        content_type in ('place', 'activity', 'culture', 'food', 'local_product')
    ),
    content_id uuid not null,
    reason text not null check (
        reason in ('closed', 'wrong_hours', 'wrong_location', 'event_ended', 'other')
    ),
    note text,
    status text not null default 'open' check (
        status in ('open', 'resolved', 'dismissed')
    ),
    created_at timestamp with time zone not null default now(),
    resolved_at timestamp with time zone,
    resolved_by uuid references public.user_account(id_user)
);

create unique index if not exists content_report_one_open_reason_idx
    on public.content_report (reporter_user_id, content_type, content_id, reason)
    where status = 'open';

create index if not exists content_report_queue_idx
    on public.content_report (status, created_at desc);

create index if not exists content_report_content_idx
    on public.content_report (content_type, content_id, status);

create table if not exists public.content_update_run (
    id uuid primary key default gen_random_uuid(),
    trigger_type text not null check (trigger_type in ('cron', 'admin', 'retry')),
    started_at timestamp with time zone not null default now(),
    finished_at timestamp with time zone,
    status text not null default 'running' check (
        status in ('running', 'completed', 'partial_failure', 'failed')
    ),
    selected_count integer not null default 0,
    checked_count integer not null default 0,
    unchanged_count integer not null default 0,
    proposal_count integer not null default 0,
    auto_applied_count integer not null default 0,
    failed_count integer not null default 0,
    error_summary text,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now()
);

alter table if exists public.activity
    add column if not exists status text default 'active',
    add column if not exists updated_at timestamp with time zone default now();
alter table if exists public.culture
    add column if not exists status text default 'active',
    add column if not exists updated_at timestamp with time zone default now();
alter table if exists public.local_products
    add column if not exists status text default 'active',
    add column if not exists updated_at timestamp with time zone default now();
alter table if exists public.food
    add column if not exists status text default 'active',
    add column if not exists updated_at timestamp with time zone default now();
alter table if exists public.place
    add column if not exists status text default 'active',
    add column if not exists updated_at timestamp with time zone default now();

do $$
declare
    target_table text;
begin
    foreach target_table in array array[
        'public.activity',
        'public.culture',
        'public.local_products',
        'public.food',
        'public.place'
    ] loop
        if to_regclass(target_table) is not null then
            execute format(
                'update %s set status = coalesce(nullif(status, ''''), ''active''), updated_at = coalesce(updated_at, now()) where status is null or status = '''' or updated_at is null',
                target_table
            );
        end if;
    end loop;
end $$;

create or replace function public.set_row_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists content_freshness_set_updated_at on public.content_freshness;
create trigger content_freshness_set_updated_at
before update on public.content_freshness
for each row execute function public.set_row_updated_at();

drop trigger if exists content_change_proposal_set_updated_at on public.content_change_proposal;
create trigger content_change_proposal_set_updated_at
before update on public.content_change_proposal
for each row execute function public.set_row_updated_at();

drop trigger if exists content_update_run_set_updated_at on public.content_update_run;
create trigger content_update_run_set_updated_at
before update on public.content_update_run
for each row execute function public.set_row_updated_at();

do $$
declare
    target_table text;
    trigger_name text;
begin
    foreach target_table in array array['activity', 'culture', 'local_products', 'food', 'place'] loop
        if to_regclass(format('public.%s', target_table)) is not null then
            trigger_name := target_table || '_set_updated_at';
            execute format('drop trigger if exists %I on public.%I', trigger_name, target_table);
            execute format(
                'create trigger %I before update on public.%I for each row execute function public.set_row_updated_at()',
                trigger_name,
                target_table
            );
        end if;
    end loop;
end $$;

do $freshness_backfill$
begin
    -- Some installations provision the optional activity/culture/product
    -- tables separately. Guard every backfill so this migration remains
    -- idempotent on a partially provisioned database.
    if to_regclass('public.place') is not null then
        execute $place_backfill$
            insert into public.content_freshness (
                content_type, content_id, source_type, source_url,
                source_external_id, availability_type, freshness_status,
                next_check_at
            )
            select
                'place', p.id_place,
                coalesce(nullif(p.source, ''), 'legacy_import'),
                null,
                nullif(p.source_place_id, ''),
                'business',
                case when nullif(p.source_place_id, '') is null
                     then 'stale' else 'due' end,
                now()
            from public.place p
            where not exists (
                select 1 from public.content_freshness cf
                where cf.content_type = 'place' and cf.content_id = p.id_place
            )
        $place_backfill$;
    end if;

    if to_regclass('public.activity') is not null then
        execute $activity_backfill$
            insert into public.content_freshness (
                content_type, content_id, source_type, availability_type,
                freshness_status, next_check_at
            )
            select 'activity', a.id, 'legacy_import', 'evergreen', 'stale', now()
            from public.activity a
            where not exists (
                select 1 from public.content_freshness cf
                where cf.content_type = 'activity' and cf.content_id = a.id
            )
        $activity_backfill$;
    end if;

    if to_regclass('public.culture') is not null then
        execute $culture_backfill$
            insert into public.content_freshness (
                content_type, content_id, source_type, availability_type,
                freshness_status, next_check_at
            )
            select 'culture', c.id, 'legacy_import', 'evergreen', 'stale', now()
            from public.culture c
            where not exists (
                select 1 from public.content_freshness cf
                where cf.content_type = 'culture' and cf.content_id = c.id
            )
        $culture_backfill$;
    end if;

    if to_regclass('public.local_products') is not null then
        execute $product_backfill$
            insert into public.content_freshness (
                content_type, content_id, source_type, availability_type,
                freshness_status, next_check_at
            )
            select 'local_product', lp.id, 'legacy_import', 'evergreen', 'stale', now()
            from public.local_products lp
            where not exists (
                select 1 from public.content_freshness cf
                where cf.content_type = 'local_product' and cf.content_id = lp.id
            )
        $product_backfill$;
    end if;

    if to_regclass('public.food') is not null then
        execute $food_backfill$
            insert into public.content_freshness (
                content_type, content_id, source_type, availability_type,
                freshness_status, next_check_at
            )
            select 'food', f.id_food, 'legacy_import', 'evergreen', 'stale', now()
            from public.food f
            where not exists (
                select 1 from public.content_freshness cf
                where cf.content_type = 'food' and cf.content_id = f.id_food
            )
        $food_backfill$;
    end if;
end
$freshness_backfill$;

create or replace function public.content_freshness_table_config(
    p_content_type text
)
returns table (table_name text, id_column text)
language plpgsql
immutable
as $$
begin
    return query
    select * from (
        values
            ('place', 'place', 'id_place'),
            ('activity', 'activity', 'id'),
            ('culture', 'culture', 'id'),
            ('local_product', 'local_products', 'id'),
            ('food', 'food', 'id_food')
    ) as config(content_type, table_name, id_column)
    where config.content_type = p_content_type;
end;
$$;

create or replace function public.content_freshness_content_exists(
    p_content_type text,
    p_content_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    config record;
    found_row boolean;
begin
    select * into config
    from public.content_freshness_table_config(p_content_type);
    if config.table_name is null then
        return false;
    end if;
    if to_regclass(format('public.%I', config.table_name)) is null then
        return false;
    end if;

    execute format(
        'select exists(select 1 from public.%I where %I = $1)',
        config.table_name,
        config.id_column
    ) into found_row using p_content_id;
    return found_row;
end;
$$;

create or replace function public.content_freshness_set_status(
    p_content_type text,
    p_content_id uuid,
    p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    config record;
begin
    if p_status not in ('active', 'draft', 'hidden', 'expired', 'archived') then
        raise exception 'Unsupported content status: %', p_status using errcode = '22023';
    end if;

    select * into config
    from public.content_freshness_table_config(p_content_type);
    if config.table_name is null then
        raise exception 'Unsupported content type: %', p_content_type using errcode = '22023';
    end if;
    if to_regclass(format('public.%I', config.table_name)) is null then
        raise exception 'Content table is unavailable: %', config.table_name using errcode = '42P01';
    end if;

    execute format(
        'update public.%I set status = $1 where %I = $2',
        config.table_name,
        config.id_column
    ) using p_status, p_content_id;
end;
$$;

create or replace function public.claim_due_content_freshness(
    p_run_id uuid,
    p_limit integer
)
returns setof public.content_freshness
language plpgsql
security definer
set search_path = public
as $$
declare
    v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 50);
begin
    if p_run_id is null then
        raise exception 'Run id is required.' using errcode = '22023';
    end if;
    if not exists (select 1 from public.content_update_run where id = p_run_id) then
        raise exception 'Update run not found: %', p_run_id using errcode = 'P0002';
    end if;

    return query
    with claimed as (
        select cf.id
        from public.content_freshness cf
        where cf.next_check_at <= now()
          and cf.freshness_status in ('fresh', 'due', 'stale')
        order by cf.next_check_at asc, cf.created_at asc
        for update skip locked
        limit v_limit
    ), marked as (
        update public.content_freshness cf
        set freshness_status = 'due', updated_at = now()
        from claimed
        where cf.id = claimed.id
        returning cf.*
    ), run_updated as (
        update public.content_update_run
        set selected_count = selected_count + (select count(*) from marked)
        where id = p_run_id
        returning 1
    )
    select marked.*
    from marked
    cross join run_updated;
end;
$$;

create or replace function public.record_content_freshness_result(
    p_freshness_id uuid,
    p_payload jsonb
)
returns public.content_freshness
language plpgsql
security definer
set search_path = public
as $$
declare
    current_row public.content_freshness;
    updated_row public.content_freshness;
    decision_kind text := coalesce(p_payload->>'decision_kind', 'error');
    run_id uuid := nullif(p_payload->>'run_id', '')::uuid;
    before_data jsonb := coalesce(p_payload->'before_data', '{}'::jsonb);
    proposed_data jsonb := coalesce(p_payload->'proposed_data', '{}'::jsonb);
    changed_fields jsonb := coalesce(p_payload->'changed_fields', '[]'::jsonb);
    change_type text := coalesce(p_payload->>'change_type', decision_kind);
    reason text := coalesce(p_payload->>'reason', decision_kind);
    content_patch jsonb := coalesce(p_payload->'content_patch', '{}'::jsonb);
begin
    select * into current_row
    from public.content_freshness
    where id = p_freshness_id
    for update;
    if current_row.id is null then
        raise exception 'Freshness row not found: %', p_freshness_id using errcode = 'P0002';
    end if;

    if decision_kind = 'auto_expire' then
        perform public.content_freshness_set_status(
            current_row.content_type,
            current_row.content_id,
            'expired'
        );
        insert into public.content_change_proposal (
            freshness_id, change_type, before_data, proposed_data,
            changed_fields, reason, confidence, decision, reviewed_at
        ) values (
            current_row.id,
            'auto_expired',
            before_data,
            proposed_data,
            changed_fields,
            reason,
            nullif(p_payload->>'confidence', '')::numeric,
            'auto_applied',
            now()
        )
        on conflict (freshness_id) where decision = 'pending'
        do update set
            change_type = excluded.change_type,
            before_data = excluded.before_data,
            proposed_data = excluded.proposed_data,
            changed_fields = excluded.changed_fields,
            reason = excluded.reason,
            confidence = excluded.confidence,
            decision = excluded.decision,
            reviewed_at = excluded.reviewed_at;
    elsif decision_kind in ('proposal', 'second_missing') then
        insert into public.content_change_proposal (
            freshness_id, change_type, before_data, proposed_data,
            changed_fields, reason, confidence
        ) values (
            current_row.id,
            change_type,
            before_data,
            proposed_data,
            changed_fields,
            reason,
            nullif(p_payload->>'confidence', '')::numeric
        )
        on conflict (freshness_id) where decision = 'pending'
        do update set
            proposed_data = excluded.proposed_data,
            changed_fields = excluded.changed_fields,
            reason = excluded.reason,
            confidence = excluded.confidence,
            detected_at = now();
    elsif decision_kind = 'recovered' then
        update public.content_change_proposal
        set decision = 'rejected', reviewed_at = now()
        where freshness_id = current_row.id and decision = 'pending';
    end if;

    update public.content_freshness
    set freshness_status = coalesce(nullif(p_payload->>'freshness_status', ''), freshness_status),
        last_checked_at = coalesce(nullif(p_payload->>'last_checked_at', '')::timestamptz, now()),
        last_verified_at = coalesce(nullif(p_payload->>'last_verified_at', '')::timestamptz, last_verified_at),
        next_check_at = coalesce(nullif(p_payload->>'next_check_at', '')::timestamptz, next_check_at),
        source_hash = coalesce(nullif(p_payload->>'source_hash', ''), source_hash),
        consecutive_missing_count = coalesce(
            nullif(p_payload->>'consecutive_missing_count', '')::integer,
            consecutive_missing_count
        ),
        last_error = nullif(p_payload->>'last_error', '')
    where id = current_row.id
    returning * into updated_row;

    if run_id is not null then
        update public.content_update_run
        set checked_count = checked_count + 1,
            unchanged_count = unchanged_count + case when decision_kind = 'unchanged' then 1 else 0 end,
            proposal_count = proposal_count + case when decision_kind in ('proposal', 'second_missing') then 1 else 0 end,
            auto_applied_count = auto_applied_count + case when decision_kind = 'auto_expire' then 1 else 0 end,
            failed_count = failed_count + case when decision_kind = 'error' then 1 else 0 end
        where id = run_id;
    end if;

    if jsonb_typeof(content_patch) = 'object' and content_patch ? 'status' and decision_kind = 'auto_expire' then
        perform public.content_freshness_set_status(
            current_row.content_type,
            current_row.content_id,
            content_patch->>'status'
        );
    end if;

    return updated_row;
end;
$$;

create or replace function public.review_content_change_proposal(
    p_proposal_id uuid,
    p_decision text,
    p_applied_data jsonb
)
returns public.content_change_proposal
language plpgsql
security definer
set search_path = public
as $$
declare
    proposal public.content_change_proposal;
    freshness public.content_freshness;
    config record;
    current_data jsonb;
    source_key text;
    allowed_keys constant text[] := array[
        'name', 'address', 'latitude', 'longitude',
        'timespan', 'timeclose', 'phone', 'website', 'status'
    ];
begin
    if not public.admin_content_is_admin() then
        raise exception 'Admin role required.' using errcode = '42501';
    end if;
    if p_decision not in ('approved', 'rejected') then
        raise exception 'Unsupported proposal decision.' using errcode = '22023';
    end if;

    select * into proposal
    from public.content_change_proposal
    where id = p_proposal_id
    for update;
    if proposal.id is null then
        raise exception 'Proposal not found.' using errcode = 'P0002';
    end if;
    if proposal.decision <> 'pending' then
        raise exception 'Proposal is no longer pending.' using errcode = '40001';
    end if;

    select * into freshness
    from public.content_freshness
    where id = proposal.freshness_id
    for update;
    select * into config
    from public.content_freshness_table_config(freshness.content_type);

    if p_decision = 'approved' then
        execute format(
            'select to_jsonb(row_data) from public.%I row_data where %I = $1',
            config.table_name,
            config.id_column
        ) into current_data using freshness.content_id;
        foreach source_key in array allowed_keys loop
            if (current_data->source_key) is distinct from (proposal.before_data->source_key) then
                raise exception 'Content changed since proposal was created.' using errcode = '40001';
            end if;
        end loop;

        if freshness.content_type = 'place' then
            execute format(
                'update public.%I set
                    name = case when $1 ? ''name'' then nullif($1->>''name'', '''') else name end,
                    address = case when $1 ? ''address'' then nullif($1->>''address'', '''') else address end,
                    latitude = case when $1 ? ''latitude'' then nullif($1->>''latitude'', '''')::double precision else latitude end,
                    longitude = case when $1 ? ''longitude'' then nullif($1->>''longitude'', '''')::double precision else longitude end,
                    timespan = case when $1 ? ''timespan'' then nullif($1->>''timespan'', '''') else timespan end,
                    timeclose = case when $1 ? ''timeclose'' then nullif($1->>''timeclose'', '''') else timeclose end,
                    phone = case when $1 ? ''phone'' then nullif($1->>''phone'', '''') else phone end,
                    website = case when $1 ? ''website'' then nullif($1->>''website'', '''') else website end,
                    status = case when $1 ? ''status'' then nullif($1->>''status'', '''') else status end
                 where %I = $2',
                config.table_name,
                config.id_column
            ) using coalesce(p_applied_data, '{}'::jsonb), freshness.content_id;
        else
            execute format(
                'update public.%I set
                    name = case when $1 ? ''name'' then nullif($1->>''name'', '''') else name end,
                    status = case when $1 ? ''status'' then nullif($1->>''status'', '''') else status end
                 where %I = $2',
                config.table_name,
                config.id_column
            ) using coalesce(p_applied_data, '{}'::jsonb), freshness.content_id;
        end if;
    else
        update public.content_freshness
        set freshness_status = 'fresh',
            consecutive_missing_count = 0,
            last_verified_at = now(),
            next_check_at = now() + interval '1 day'
        where id = freshness.id;
    end if;

    update public.content_change_proposal
    set decision = p_decision,
        reviewed_at = now(),
        reviewed_by = auth.uid(),
        applied_data = case when p_decision = 'approved' then coalesce(p_applied_data, '{}'::jsonb) else null end
    where id = proposal.id
    returning * into proposal;

    if p_decision = 'approved' then
        update public.content_freshness
        set freshness_status = 'fresh',
            consecutive_missing_count = 0,
            last_verified_at = now(),
            next_check_at = now() + interval '7 days'
        where id = freshness.id;
    end if;

    return proposal;
end;
$$;

create or replace function public.submit_content_report(
    p_content_type text,
    p_content_id uuid,
    p_reason text,
    p_note text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    current_user_id uuid := auth.uid();
    report_id uuid;
begin
    if current_user_id is null then
        raise exception 'Authentication required.' using errcode = '42501';
    end if;
    if not public.content_freshness_content_exists(p_content_type, p_content_id) then
        raise exception 'Content not found.' using errcode = 'P0002';
    end if;
    if p_reason not in ('closed', 'wrong_hours', 'wrong_location', 'event_ended', 'other') then
        raise exception 'Unsupported report reason.' using errcode = '22023';
    end if;
    if length(coalesce(p_note, '')) > 1000 then
        raise exception 'Report note is too long.' using errcode = '22023';
    end if;
    if (
        select count(*)
        from public.content_report
        where reporter_user_id = current_user_id
          and created_at >= date_trunc('day', now() at time zone 'UTC') at time zone 'UTC'
    ) >= 3 then
        raise exception 'Daily content report limit reached.' using errcode = 'P0003';
    end if;
    if exists (
        select 1 from public.content_report
        where reporter_user_id = current_user_id
          and content_type = p_content_type
          and content_id = p_content_id
          and reason = p_reason
          and status = 'open'
    ) then
        raise exception 'Duplicate open report.' using errcode = '23505';
    end if;

    insert into public.content_report (
        reporter_user_id, content_type, content_id, reason, note
    ) values (
        current_user_id, p_content_type, p_content_id, p_reason, nullif(trim(p_note), '')
    ) returning id into report_id;
    return report_id;
end;
$$;

create or replace function public.request_content_freshness_check(
    p_content_type text,
    p_content_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if not public.admin_content_is_admin() then
        raise exception 'Admin role required.' using errcode = '42501';
    end if;
    if not public.content_freshness_content_exists(p_content_type, p_content_id) then
        raise exception 'Content freshness row not found.' using errcode = 'P0002';
    end if;

    update public.content_freshness
    set next_check_at = now(), freshness_status = 'due'
    where content_type = p_content_type and content_id = p_content_id;
end;
$$;

create or replace function public.invoke_data_freshness_cron()
returns void
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
    check_secret text;
begin
    select decrypted_secret into check_secret
    from vault.decrypted_secrets
    where name = 'data_freshness_check_secret'
    order by created_at desc
    limit 1;

    if nullif(check_secret, '') is null then
        raise warning 'data_freshness_check_secret is missing; freshness cron skipped';
        return;
    end if;

    perform net.http_post(
        url := 'https://ziouozppetvvdrzgojcx.supabase.co/functions/v1/data-freshness-check',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-data-freshness-secret', check_secret
        ),
        body := jsonb_build_object('triggerType', 'cron'),
        timeout_milliseconds := 10000
    );
exception
    when others then
        raise warning 'data freshness cron invocation failed: %', sqlerrm;
end;
$$;

do $$
begin
    if exists (select 1 from cron.job where jobname = 'data-freshness-daily') then
        perform cron.unschedule('data-freshness-daily');
    end if;
    perform cron.schedule(
        'data-freshness-daily',
        '15 2 * * *',
        $cron$select public.invoke_data_freshness_cron()$cron$
    );
exception
    when undefined_table or undefined_function then
        raise warning 'pg_cron is unavailable; configure data-freshness-daily in Supabase dashboard';
end $$;

alter table public.content_freshness enable row level security;
alter table public.content_change_proposal enable row level security;
alter table public.content_report enable row level security;
alter table public.content_update_run enable row level security;

revoke all on public.content_freshness from anon, authenticated;
revoke all on public.content_change_proposal from anon, authenticated;
revoke all on public.content_update_run from anon, authenticated;
grant select, insert on public.content_report to authenticated;

drop policy if exists "Users can read own freshness reports" on public.content_report;
create policy "Users can read own freshness reports"
on public.content_report for select to authenticated
using (reporter_user_id = auth.uid() or public.admin_content_is_admin());

drop policy if exists "Users can submit freshness reports" on public.content_report;
create policy "Users can submit freshness reports"
on public.content_report for insert to authenticated
with check (reporter_user_id = auth.uid());

revoke all on function public.content_freshness_table_config(text) from public, anon, authenticated;
revoke all on function public.content_freshness_content_exists(text, uuid) from public, anon, authenticated;
revoke all on function public.content_freshness_set_status(text, uuid, text) from public, anon, authenticated;
revoke all on function public.claim_due_content_freshness(uuid, integer) from public, anon, authenticated;
revoke all on function public.record_content_freshness_result(uuid, jsonb) from public, anon, authenticated;
revoke all on function public.review_content_change_proposal(uuid, text, jsonb) from public, anon;
revoke all on function public.submit_content_report(text, uuid, text, text) from public, anon;
revoke all on function public.request_content_freshness_check(text, uuid) from public, anon;
revoke all on function public.invoke_data_freshness_cron() from public, anon, authenticated;

grant execute on function public.claim_due_content_freshness(uuid, integer) to service_role;
grant execute on function public.record_content_freshness_result(uuid, jsonb) to service_role;
grant execute on function public.review_content_change_proposal(uuid, text, jsonb) to authenticated, service_role;
grant execute on function public.submit_content_report(text, uuid, text, text) to authenticated;
grant execute on function public.request_content_freshness_check(text, uuid) to authenticated, service_role;
grant execute on function public.invoke_data_freshness_cron() to service_role;
