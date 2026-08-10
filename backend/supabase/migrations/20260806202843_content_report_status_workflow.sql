-- Align freshness reports with the admin review workflow.
alter table public.content_report
  drop constraint if exists content_report_status_check;

alter table public.content_report
  add constraint content_report_status_check
  check (status in ('open', 'pending', 'in_progress', 'resolved', 'dismissed'));

update public.content_report
set status = 'pending'
where status = 'open';

alter table public.content_report
  alter column status set default 'pending';

alter table public.content_report
  drop constraint if exists content_report_status_check;

alter table public.content_report
  add constraint content_report_status_check
  check (status in ('pending', 'in_progress', 'resolved', 'dismissed'));

drop index if exists public.content_report_one_open_reason_idx;
create unique index if not exists content_report_one_open_reason_idx
  on public.content_report (reporter_user_id, content_type, content_id, reason)
  where status in ('pending', 'in_progress');

drop index if exists public.content_report_queue_idx;
create index if not exists content_report_queue_idx
  on public.content_report (status, created_at desc);;
