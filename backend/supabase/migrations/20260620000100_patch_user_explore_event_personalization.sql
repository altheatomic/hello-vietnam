alter table if exists public.user_explore_event
  add column if not exists event_score integer not null default 0;

alter table if exists public.user_explore_event
  add column if not exists request_id text null;

create unique index if not exists idx_user_explore_event_user_request
  on public.user_explore_event using btree (id_user, request_id)
  where request_id is not null;

create index if not exists idx_user_explore_event_user_created_at
  on public.user_explore_event using btree (id_user, created_at desc);

create index if not exists idx_user_explore_event_user_content
  on public.user_explore_event using btree (id_user, content_type, content_id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'user_explore_event_content_type_check'
      and conrelid = 'public.user_explore_event'::regclass
  ) then
    alter table public.user_explore_event
      add constraint user_explore_event_content_type_check
      check (
        content_type = any (
          array[
            'activity'::text,
            'culture'::text,
            'food'::text,
            'local_product'::text
          ]
        )
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'user_explore_event_event_type_check'
      and conrelid = 'public.user_explore_event'::regclass
  ) then
    alter table public.user_explore_event
      add constraint user_explore_event_event_type_check
      check (
        event_type = any (
          array[
            'view_detail'::text,
            'share'::text,
            'favorite'::text,
            'add_to_trip'::text,
            'skip'::text,
            'unfavorite'::text,
            'remove_from_trip'::text
          ]
        )
      );
  end if;
end
$$;

comment on column public.user_explore_event.event_score is
  'Signed explore event weight used to update user_interest_tag behavior scores.';

comment on column public.user_explore_event.request_id is
  'Client-generated idempotency key for explore behavior events.';
