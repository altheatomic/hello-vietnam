create table if not exists public.user_location_preference (
    id_location_preference uuid primary key default uuid_generate_v4(),
    id_user uuid not null references public.user_account(id_user) on delete cascade,
    latitude double precision,
    longitude double precision,
    approx_address text,
    province_city text,
    location_source text not null default 'manual'
        check (location_source in ('gps', 'manual', 'map_pin')),
    updated_at timestamp with time zone not null default now(),
    created_at timestamp with time zone not null default now(),
    constraint uq_user_location_preference_user unique (id_user)
);

create index if not exists idx_user_location_preference_user_updated
    on public.user_location_preference (id_user, updated_at desc);

alter table if exists public.user_location_preference enable row level security;
revoke all on table public.user_location_preference from anon, authenticated;

comment on table public.user_location_preference is
  'Per-user location preference for personalization and nearby results.';

