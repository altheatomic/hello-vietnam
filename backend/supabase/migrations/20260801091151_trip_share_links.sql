create table public.trip_share_link (
    id_share uuid primary key default gen_random_uuid(),
    id_plan uuid not null
        references public.plan(id_plan) on delete cascade,
    owner_user_id uuid not null
        references public.user_account(id_user) on delete cascade,
    token_hash text not null unique
        check (token_hash ~ '^[a-f0-9]{64}$'),
    token_prefix text not null
        check (char_length(token_prefix) between 6 and 12),
    allow_copy boolean not null default true,
    expires_at timestamp with time zone not null,
    revoked_at timestamp with time zone null,
    view_count bigint not null default 0 check (view_count >= 0),
    last_accessed_at timestamp with time zone null,
    created_at timestamp with time zone not null default now(),
    constraint trip_share_link_expiry_after_creation
        check (expires_at > created_at)
);

create index trip_share_link_owner_created_idx
on public.trip_share_link (owner_user_id, created_at desc);

create index trip_share_link_plan_active_idx
on public.trip_share_link (id_plan, revoked_at, expires_at);

alter table public.trip_share_link enable row level security;

-- Share tokens are bearer credentials. All table access is deliberately
-- centralized in the trip-share Edge Function, including owner operations.
revoke all on table public.trip_share_link
from public, anon, authenticated;

grant all on table public.trip_share_link to service_role;

comment on table public.trip_share_link is
'Revocable public itinerary links. Only SHA-256 token hashes are persisted.';

comment on column public.trip_share_link.token_prefix is
'Non-secret prefix displayed to the owner when managing share links.';

create or replace function public.record_trip_share_view(p_id_share uuid)
returns void
language sql
security definer
set search_path = ''
as $$
    update public.trip_share_link
    set
        view_count = view_count + 1,
        last_accessed_at = now()
    where id_share = p_id_share;
$$;

revoke all on function public.record_trip_share_view(uuid)
from public, anon, authenticated;

grant execute on function public.record_trip_share_view(uuid)
to service_role;
