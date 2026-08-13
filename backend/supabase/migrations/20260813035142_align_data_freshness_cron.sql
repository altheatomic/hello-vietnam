-- Keep the freshness checker in the same overnight operating window as
-- collaborative-filtering retraining, while avoiding a simultaneous start.
-- 19:15 UTC is 02:15 the following day in Vietnam (UTC+7).
do $$
begin
    perform cron.schedule(
        'data-freshness-daily',
        '15 19 * * *',
        $cron$select public.invoke_data_freshness_cron()$cron$
    );
exception
    when undefined_table or undefined_function then
        raise warning 'pg_cron is unavailable; configure data-freshness-daily in Supabase dashboard';
end $$;
