-- Read-only access for Home featured sections.
-- Run this after the base schema/migrations if Home still shows fallback data.

alter table if exists public.province enable row level security;
alter table if exists public.food enable row level security;

drop policy if exists "Home can read provinces" on public.province;
create policy "Home can read provinces"
on public.province for select
to anon, authenticated
using (true);

drop policy if exists "Home can read foods" on public.food;
create policy "Home can read foods"
on public.food for select
to anon, authenticated
using (true);

grant select on public.province to anon, authenticated;
grant select on public.food to anon, authenticated;
