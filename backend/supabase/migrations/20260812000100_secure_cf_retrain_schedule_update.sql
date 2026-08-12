create or replace function public.update_cf_retrain_schedule(
    p_hour_utc smallint,
    p_minute_utc smallint,
    p_updated_by uuid default null
)
returns table (
    hour_utc smallint,
    minute_utc smallint,
    updated_at timestamp with time zone,
    updated_by uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_job_id bigint;
begin
    if p_hour_utc not between 0 and 23 then
        raise exception 'hour_utc must be between 0 and 23';
    end if;

    if p_minute_utc not between 0 and 59 then
        raise exception 'minute_utc must be between 0 and 59';
    end if;

    select jobid
    into v_job_id
    from cron.job
    where jobname = 'daily_cf_retrain'
      and username = current_user
    order by jobid desc
    limit 1;

    if v_job_id is null then
        raise exception 'pg_cron job % is not registered', 'daily_cf_retrain';
    end if;

    perform cron.alter_job(
        job_id := v_job_id,
        schedule := pg_catalog.format(
            '%s %s * * *',
            p_minute_utc,
            p_hour_utc
        )
    );

    return query
    insert into public.cf_retrain_config (
        singleton_id,
        hour_utc,
        minute_utc,
        updated_at,
        updated_by
    )
    values (1, p_hour_utc, p_minute_utc, pg_catalog.now(), p_updated_by)
    on conflict (singleton_id) do update
    set hour_utc = excluded.hour_utc,
        minute_utc = excluded.minute_utc,
        updated_at = pg_catalog.now(),
        updated_by = excluded.updated_by
    returning
        cf_retrain_config.hour_utc,
        cf_retrain_config.minute_utc,
        cf_retrain_config.updated_at,
        cf_retrain_config.updated_by;
end;
$$;

alter function public.update_cf_retrain_schedule(smallint, smallint, uuid)
    owner to postgres;

revoke all on function public.update_cf_retrain_schedule(smallint, smallint, uuid)
    from public, anon, authenticated, service_role;
grant execute on function public.update_cf_retrain_schedule(smallint, smallint, uuid)
    to postgres;

comment on function public.update_cf_retrain_schedule(smallint, smallint, uuid) is
    'Atomically updates only the daily_cf_retrain pg_cron schedule and its singleton display config.';
