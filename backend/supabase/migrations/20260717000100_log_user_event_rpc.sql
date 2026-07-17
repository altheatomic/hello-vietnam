-- RPC: log_user_event
-- Upserts an implicit-signal event into user_event_log for the CF pipeline
-- (see 20260621000100_user_event_log.sql for the table).
--
-- Restated here as CREATE OR REPLACE (safe to re-run) so the deployed
-- Supabase function has a version-controlled record. Body below is a
-- best-effort reconstruction from the confirmed signature and validation
-- rules only (p_event_type IN ('view_detail','share'); p_user_id must
-- match auth.uid()) — it was NOT diffed against the live function body.
-- Recommend running `select pg_get_functiondef('log_user_event'::regproc);`
-- against the live database and comparing before/after applying this
-- migration to a fresh environment.

create or replace function log_user_event(
    p_user_id    uuid,
    p_place_id   uuid,
    p_event_type text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if p_event_type not in ('view_detail', 'share') then
        raise exception 'Invalid p_event_type: %. Must be one of (view_detail, share).', p_event_type;
    end if;

    if p_user_id is distinct from auth.uid() then
        raise exception 'p_user_id does not match the authenticated user.';
    end if;

    insert into user_event_log (id_user, id_place, event_type, event_count, first_at, last_at)
    values (p_user_id, p_place_id, p_event_type, 1, now(), now())
    on conflict (id_user, id_place, event_type)
    do update set
        event_count = user_event_log.event_count + 1,
        last_at     = now();
end;
$$;

grant execute on function log_user_event(uuid, uuid, text) to authenticated;

-- NOTE: upsert_user_place_event was referenced as an existing RPC but no
-- signature/body was provided, and it is not called anywhere in the
-- current frontend/backend/cf_service codebase (searched, zero matches).
-- It has been intentionally left out of this migration rather than
-- guessed — provide `pg_get_functiondef('upsert_user_place_event'::regproc)`
-- (or the exact overload signature, if arguments are ambiguous) so it can
-- be recorded accurately in a follow-up migration.
