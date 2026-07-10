alter table if exists public.user_account
  add column if not exists currency text not null default 'VND';

update public.user_account ua
set currency = coalesce(nullif(ua.currency, ''), us.currency, 'VND')
from public.user_setting us
where ua.id_user = us.id_user;

update public.user_account
set currency = 'VND'
where currency is null or currency = '';
