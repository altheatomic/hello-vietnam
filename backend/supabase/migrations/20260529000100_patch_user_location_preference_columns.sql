alter table if exists public.user_location_preference
  add column if not exists approx_address text,
  add column if not exists province_city text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists location_source text default 'manual',
  add column if not exists updated_at timestamp with time zone default now(),
  add column if not exists created_at timestamp with time zone default now();

update public.user_location_preference
set location_source = 'manual'
where location_source is null;

alter table if exists public.user_location_preference
  alter column location_source set default 'manual';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_user_location_preference_source'
      and conrelid = 'public.user_location_preference'::regclass
  ) then
    alter table public.user_location_preference
      add constraint chk_user_location_preference_source
      check (location_source in ('gps', 'manual', 'map_pin'));
  end if;
end
$$;
