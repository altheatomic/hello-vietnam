create extension if not exists "uuid-ossp";

create table if not exists report (
    id_report uuid primary key default uuid_generate_v4(),
    id_user uuid references user_account(id_user) on delete set null,
    report_category text not null,
    target_type text,
    target_id uuid,
    feature_area text,
    report_content text,
    images jsonb,
    status text not null default 'pending',
    resolved_at timestamp with time zone,
    action_taken text,
    created_at timestamp with time zone not null default now(),
    constraint report_category_check check (
        report_category in (
            'content_report',
            'bug_report',
            'suggestion',
            'account_issue',
            'payment_issue'
        )
    ),
    constraint report_status_check check (
        status in ('pending', 'reviewing', 'resolved', 'rejected')
    ),
    constraint report_target_type_check check (
        target_type is null
        or target_type in (
            'food',
            'culture',
            'activity',
            'local_product',
            'place',
            'province',
            'feature',
            'system',
            'user_account'
        )
    )
);

create index if not exists report_created_at_idx
    on report(created_at desc);

create index if not exists report_status_idx
    on report(status);

create index if not exists report_user_idx
    on report(id_user, created_at desc);

alter table user_account enable row level security;

create or replace function current_user_is_admin()
returns boolean
language sql
security definer
set search_path = public, auth
as $$
    select exists (
        select 1
        from user_account
        where id_user = auth.uid()
          and role = 'admin'
    );
$$;

drop policy if exists "Report users can read own account" on user_account;
create policy "Report users can read own account"
on user_account for select
using (auth.uid() = id_user);

drop policy if exists "Report admins can read user accounts" on user_account;
create policy "Report admins can read user accounts"
on user_account for select
using (current_user_is_admin());

drop policy if exists "Report users can insert own account" on user_account;
create policy "Report users can insert own account"
on user_account for insert
with check (auth.uid() = id_user);

drop policy if exists "Report users can update own account" on user_account;
create policy "Report users can update own account"
on user_account for update
using (auth.uid() = id_user)
with check (auth.uid() = id_user);

alter table report enable row level security;

drop policy if exists "Users can create reports" on report;
create policy "Users can create reports"
on report for insert
with check (auth.uid() is null or auth.uid() = id_user);

drop policy if exists "Users can read own reports" on report;
create policy "Users can read own reports"
on report for select
using (auth.uid() = id_user);

drop policy if exists "Admins can read reports" on report;
create policy "Admins can read reports"
on report for select
using (current_user_is_admin());

drop policy if exists "Admins can update reports" on report;
create policy "Admins can update reports"
on report for update
using (current_user_is_admin())
with check (current_user_is_admin());

grant insert on report to anon, authenticated;
grant select on report to authenticated;
grant update on report to authenticated;
grant select, insert, update on user_account to authenticated;
grant execute on function current_user_is_admin() to authenticated;
