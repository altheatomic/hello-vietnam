create or replace view public.admin_report_list
with (security_invoker = true)
as
select
  r.id_report,
  r.id_user,
  coalesce(
    nullif(trim(ua.full_name), ''),
    nullif(split_part(nullif(trim(ua.username), ''), '@', 1), ''),
    case
      when r.id_user is null then 'Anonymous user'
      else 'User ' || left(r.id_user::text, 8)
    end
  ) as reporter_name,
  coalesce(nullif(trim(ua.username), ''), 'No email') as reporter_email,
  r.report_category,
  case
    when lower(coalesce(r.feature_area, '')) like '%map%' then 'map_address_issue'
    when lower(coalesce(r.feature_area, '')) like '%media%'
      or lower(coalesce(r.feature_area, '')) like '%image%'
      then 'inappropriate_media'
    when r.report_category = 'content_report' then 'incorrect_data'
    when r.report_category in ('bug_report', 'account_issue', 'payment_issue')
      then 'app_function'
    when r.report_category = 'suggestion' then 'other'
    else 'other'
  end as issue_type,
  r.target_type,
  r.target_id,
  r.feature_area,
  r.report_content,
  r.images,
  r.status,
  r.action_taken,
  r.created_at
from public.report r
left join public.user_account ua on ua.id_user = r.id_user;

create index if not exists report_admin_status_created_idx
  on public.report(status, created_at desc);

create index if not exists report_admin_category_created_idx
  on public.report(report_category, created_at desc);

create index if not exists report_admin_target_type_created_idx
  on public.report(target_type, created_at desc);

grant select on public.admin_report_list to authenticated;
