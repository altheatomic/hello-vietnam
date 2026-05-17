alter table public.user_account
add column if not exists status text default 'active';

update public.user_account
set status = 'active'
where status is null;

alter table public.user_account
alter column status set default 'active';
