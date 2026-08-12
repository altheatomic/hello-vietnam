-- Trip lifecycle tracking for Trip Tracker + overdue check.
--
-- Independent of the existing `status` column (draft/saved — a save-state
-- flag, unrelated to whether the user has started/ended the trip itself).
--
-- activated_at / ended_at mirror what TripStore already tracks locally via
-- SharedPreferences, now synced to the server so it survives reinstalls and
-- is visible to any future scheduled job.
--
-- overdue_notified_at marks that the user has already been asked "did you
-- finish your trip?" once, so the client-pull check in Home doesn't ask again
-- every time the app opens.
alter table plan
    add column if not exists activated_at        timestamp with time zone,
    add column if not exists ended_at             timestamp with time zone,
    add column if not exists overdue_notified_at  timestamp with time zone;

-- Matches the exact predicate used by cf_service's get_overdue_plans(): an
-- activated, not-yet-ended, not-yet-notified plan whose end_at has passed.
-- This same index is what a future pg_cron job scanning the same predicate
-- (Option A) would rely on — no schema change needed to upgrade to it.
create index if not exists idx_plan_overdue_check
    on plan (end_at)
    where activated_at is not null
      and ended_at is null
      and overdue_notified_at is null;
