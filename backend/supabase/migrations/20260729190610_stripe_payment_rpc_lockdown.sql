revoke all on function public.confirm_paid_subscription_with_voucher(
    text,
    text,
    text,
    text,
    text
) from public, anon, authenticated;

drop function if exists public.purchase_subscription_with_voucher(
    text,
    text,
    text,
    text
);

alter table public.payment enable row level security;
alter table public.premium_subscription enable row level security;

revoke all on table public.payment from anon;
revoke all on table public.premium_subscription from anon;

revoke insert, update, delete, truncate, references, trigger
on table public.payment
from authenticated;

revoke insert, update, delete, truncate, references, trigger
on table public.premium_subscription
from authenticated;

grant select on table public.payment to authenticated;
grant select on table public.premium_subscription to authenticated;

drop policy if exists "Users can read own payments" on public.payment;
create policy "Users can read own payments"
on public.payment
for select
to authenticated
using ((select auth.uid()) = id_user);

drop policy if exists "Users can read own premium subscriptions"
on public.premium_subscription;
create policy "Users can read own premium subscriptions"
on public.premium_subscription
for select
to authenticated
using ((select auth.uid()) = id_user);
