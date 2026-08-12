create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema extensions;

-- Provision cf_retrain_shared_secret separately in Supabase Vault. The
-- plaintext value must never be committed or stored in cron.job.
create or replace function public.invoke_cf_retrain_cron()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_shared_secret text;
begin
    select decrypted_secret
    into v_shared_secret
    from vault.decrypted_secrets
    where name = 'cf_retrain_shared_secret'
    order by created_at desc
    limit 1;

    if nullif(v_shared_secret, '') is null then
        raise exception 'Vault secret cf_retrain_shared_secret is missing';
    end if;

    perform net.http_post(
        url := 'https://hello-vietnam-cf-service.onrender.com/admin/cf/retrain',
        headers := pg_catalog.jsonb_build_object(
            'Content-Type', 'application/json',
            'X-Internal-Secret', v_shared_secret
        ),
        body := '{"triggered_by":"pg_cron"}'::jsonb,
        timeout_milliseconds := 10000
    );
end;
$$;

revoke all on function public.invoke_cf_retrain_cron() from public, anon, authenticated;
grant execute on function public.invoke_cf_retrain_cron() to postgres;

do $$
declare
    v_hour_utc smallint := 19;
    v_minute_utc smallint := 0;
begin
    select hour_utc, minute_utc
    into v_hour_utc, v_minute_utc
    from public.cf_retrain_config
    where singleton_id = 1;

    v_hour_utc := coalesce(v_hour_utc, 19);
    v_minute_utc := coalesce(v_minute_utc, 0);

    perform cron.schedule(
        'daily_cf_retrain',
        pg_catalog.format('%s %s * * *', v_minute_utc, v_hour_utc),
        $command$select public.invoke_cf_retrain_cron()$command$
    );
end;
$$;
