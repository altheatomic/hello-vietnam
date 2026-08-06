# Data freshness operations

This runbook describes the hybrid freshness workflow for the travel content
tables (`place`, `activity`, `culture`, `food`, and `local_products`). Supabase
is the source of truth; crawlers only write deterministic identities and
source-owned operational fields.

For a tester-facing checklist with SQL fixtures, UI steps, expected results,
and evidence requirements, see
[data-freshness-manual-test.md](data-freshness-manual-test.md).

## Components and secrets

- Migration: `backend/supabase/migrations/20260803000100_data_freshness.sql`
- Checker Edge Function: `data-freshness-check`
- Authenticated report/admin Edge Function: `data-freshness`
- Cron job: `data-freshness-daily`, scheduled at 02:15 UTC
- Default checker batch: 50 records per run
- Supabase Vault secret: `data_freshness_check_secret`
- Edge Function secret: `DATA_FRESHNESS_CHECK_SECRET`

The migration currently points the cron HTTP request at the configured project
URL `ziouozppetvvdrzgojcx`. A different staging project must override that URL
before claiming that its cron is active.

The checker secret must be identical in Vault and the Edge Function secret. It
must never be bundled into Flutter, crawler output, or a client-side config.

## Deployment order

1. Apply the migration from `backend`.
2. Set the Vault secret and the Edge Function secret.
3. Deploy `data-freshness-check` and `data-freshness`.
4. Confirm that `data-freshness-daily` exists in `cron.job`.
5. Open `/admin/data-freshness` and verify the overview cards and run history.

If the Vault secret is absent, the cron function emits a warning and returns
without making a request. This is safe during a staged deployment, but no rows
will be checked until the secret is configured.

## Normal workflow

The daily checker claims at most 50 due rows with `FOR UPDATE SKIP LOCKED`.
Each source adapter is allowlisted and has bounded retries. A timeout or parser
error records an error and preserves the missing counter. A valid missing source
increments the counter; the first missing result is `stale`, and the second
creates one `possibly_closed` review proposal. A past scheduled event is the
only automatic content expiry path.

Operational changes (name, address, coordinates, opening hours, phone, website,
and lifecycle status) are proposed for review. Descriptions, curated media,
tags, ratings, and other editorial fields are not overwritten by crawlers.

Users can report closed places, wrong hours, wrong locations, ended events, or
other errors from a detail page. Reports are authenticated, limited to three
per UTC day, and de-duplicated while an identical report is open.

## Manual checks and recovery

The admin page's **Check now** action calls `adminRequestCheck` for a selected
content UUID. It sets `next_check_at = now()` and the next checker run picks up
the row.

Useful read-only queries:

```sql
select id, trigger_type, status, selected_count, checked_count,
       unchanged_count, proposal_count, auto_applied_count, failed_count,
       started_at, finished_at, error_summary
from public.content_update_run
order by started_at desc
limit 20;

select content_type, content_id, freshness_status, next_check_at,
       consecutive_missing_count, last_error
from public.content_freshness
where freshness_status in ('due', 'stale', 'needs_review', 'expired')
order by next_check_at;
```

To retry a failed or stuck row after diagnosing the source, use an explicit
admin SQL change:

```sql
update public.content_freshness
set next_check_at = now(), freshness_status = 'due', last_error = null
where id = '<freshness-row-uuid>';
```

To disable the schedule without deleting freshness history:

```sql
select cron.unschedule('data-freshness-daily');
```

To restore an archived record, first verify the source and the admin proposal,
then restore the canonical row and request a recheck:

```sql
update public.place
set status = 'active'
where id_place = '<content-uuid>';

update public.content_freshness
set freshness_status = 'due', next_check_at = now()
where content_type = 'place' and content_id = '<content-uuid>';
```

Use the matching canonical table and content type for activities, culture,
food, and local products. Do not delete the freshness, proposal, report, or run
records; they provide the audit trail.

## Demo evidence sequence

For a non-production Supabase project, capture the following evidence:

1. A past `scheduled_event` becomes `expired` and records an `auto_applied`
   proposal.
2. One valid missing source response makes content `stale` while its canonical
   status remains active.
3. A second valid missing response creates one `possibly_closed` proposal.
4. Admin approval archives the content and removes it from Explore and Trip
   Planner candidate lists.
5. A user wrong-hours report appears in the admin report tab without changing
   the content row.
6. A forced adapter timeout records an error without changing the source hash
   or missing counter.
7. Two identical crawler imports leave the canonical content count unchanged.

This is a demo-ready freshness workflow, not a claim of production-grade
multi-source verification. Source allowlists, cadence, rate limits, and review
decisions should be revisited when more authoritative providers are added.
