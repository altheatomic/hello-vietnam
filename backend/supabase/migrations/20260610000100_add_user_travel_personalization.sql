create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.user_onboarding_choice (
  id_user uuid not null,
  screen_code text not null,
  option_code text not null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint user_onboarding_choice_pkey primary key (id_user, screen_code, option_code),
  constraint user_onboarding_choice_id_user_fkey
    foreign key (id_user) references public.user_account (id_user) on delete cascade,
  constraint user_onboarding_choice_screen_code_check
    check (
      screen_code = any (
        array[
          'trip_style'::text,
          'companion_style'::text,
          'pace_level'::text,
          'specific_interest'::text
        ]
      )
    )
);

create index if not exists idx_user_onboarding_choice_id_user
  on public.user_onboarding_choice using btree (id_user);

create index if not exists idx_user_onboarding_choice_screen_code
  on public.user_onboarding_choice using btree (screen_code);

create index if not exists idx_user_onboarding_choice_user_screen
  on public.user_onboarding_choice using btree (id_user, screen_code);

drop trigger if exists trg_user_onboarding_choice_updated_at on public.user_onboarding_choice;
create trigger trg_user_onboarding_choice_updated_at
before update on public.user_onboarding_choice
for each row
execute function public.set_updated_at();

create table if not exists public.user_travel_profile (
  id_user uuid not null,
  companion_style text null,
  budget_level text null,
  pace_level text null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  min_places_per_day integer not null default 3,
  target_places_per_day integer not null default 4,
  max_places_per_day integer not null default 5,
  onboarding_completed boolean not null default false,
  onboarding_completed_at timestamp with time zone null,
  constraint user_travel_profile_pkey primary key (id_user),
  constraint user_travel_profile_id_user_fkey
    foreign key (id_user) references public.user_account (id_user) on delete cascade,
  constraint user_travel_profile_budget_level_check
    check (
      budget_level is null
      or budget_level = any (
        array[
          'budget'::text,
          'mid_range'::text,
          'comfort'::text,
          'premium'::text
        ]
      )
    ),
  constraint user_travel_profile_companion_style_check
    check (
      companion_style is null
      or companion_style = any (
        array[
          'solo'::text,
          'couple'::text,
          'friends'::text,
          'family'::text,
          'seniors'::text,
          'business'::text
        ]
      )
    ),
  constraint user_travel_profile_pace_level_check
    check (
      pace_level is null
      or pace_level = any (
        array[
          'easy'::text,
          'balanced'::text,
          'active'::text,
          'packed'::text
        ]
      )
    ),
  constraint user_travel_profile_places_per_day_check
    check (
      min_places_per_day > 0
      and target_places_per_day > 0
      and max_places_per_day > 0
      and min_places_per_day <= target_places_per_day
      and target_places_per_day <= max_places_per_day
    )
);

create index if not exists idx_user_travel_profile_companion_style
  on public.user_travel_profile using btree (companion_style);

create index if not exists idx_user_travel_profile_budget_level
  on public.user_travel_profile using btree (budget_level);

create index if not exists idx_user_travel_profile_pace_level
  on public.user_travel_profile using btree (pace_level);

drop trigger if exists trg_user_travel_profile_updated_at on public.user_travel_profile;
create trigger trg_user_travel_profile_updated_at
before update on public.user_travel_profile
for each row
execute function public.set_updated_at();

alter table if exists public.user_onboarding_choice enable row level security;
alter table if exists public.user_travel_profile enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_onboarding_choice'
      and policyname = 'user_onboarding_choice_select_own'
  ) then
    create policy user_onboarding_choice_select_own
      on public.user_onboarding_choice
      for select
      to authenticated
      using (auth.uid() = id_user);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_onboarding_choice'
      and policyname = 'user_onboarding_choice_insert_own'
  ) then
    create policy user_onboarding_choice_insert_own
      on public.user_onboarding_choice
      for insert
      to authenticated
      with check (auth.uid() = id_user);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_onboarding_choice'
      and policyname = 'user_onboarding_choice_update_own'
  ) then
    create policy user_onboarding_choice_update_own
      on public.user_onboarding_choice
      for update
      to authenticated
      using (auth.uid() = id_user)
      with check (auth.uid() = id_user);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_onboarding_choice'
      and policyname = 'user_onboarding_choice_delete_own'
  ) then
    create policy user_onboarding_choice_delete_own
      on public.user_onboarding_choice
      for delete
      to authenticated
      using (auth.uid() = id_user);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_travel_profile'
      and policyname = 'user_travel_profile_select_own'
  ) then
    create policy user_travel_profile_select_own
      on public.user_travel_profile
      for select
      to authenticated
      using (auth.uid() = id_user);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_travel_profile'
      and policyname = 'user_travel_profile_insert_own'
  ) then
    create policy user_travel_profile_insert_own
      on public.user_travel_profile
      for insert
      to authenticated
      with check (auth.uid() = id_user);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_travel_profile'
      and policyname = 'user_travel_profile_update_own'
  ) then
    create policy user_travel_profile_update_own
      on public.user_travel_profile
      for update
      to authenticated
      using (auth.uid() = id_user)
      with check (auth.uid() = id_user);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_travel_profile'
      and policyname = 'user_travel_profile_delete_own'
  ) then
    create policy user_travel_profile_delete_own
      on public.user_travel_profile
      for delete
      to authenticated
      using (auth.uid() = id_user);
  end if;
end
$$;

comment on table public.user_onboarding_choice is
  'Stores multi-select onboarding choices by user and screen.';

comment on table public.user_travel_profile is
  'Stores per-user travel profile settings and onboarding completion state.';
