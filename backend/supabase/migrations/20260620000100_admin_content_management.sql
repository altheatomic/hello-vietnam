create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

create or replace function public.admin_content_is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_account ua
    where ua.id_user = auth.uid()
      and lower(coalesce(ua.role, '')) = 'admin'
  );
$$;

grant execute on function public.admin_content_is_admin() to authenticated;

alter table if exists public.province
  add column if not exists id_province uuid default extensions.uuid_generate_v4(),
  add column if not exists name text,
  add column if not exists short_description text,
  add column if not exists region_code text,
  add column if not exists detailed_description text,
  add column if not exists cover_image text,
  add column if not exists gallery jsonb,
  add column if not exists average_rating numeric,
  add column if not exists review_count integer default 0,
  add column if not exists created_at timestamp with time zone default now(),
  add column if not exists updated_at timestamp with time zone default now();

alter table if exists public.place
  add column if not exists id_place uuid default extensions.uuid_generate_v4(),
  add column if not exists id_place_subcategory uuid,
  add column if not exists name text,
  add column if not exists short_description text,
  add column if not exists timespan text,
  add column if not exists timeclose text,
  add column if not exists status text,
  add column if not exists cover_image text,
  add column if not exists created_at timestamp with time zone default now(),
  add column if not exists gallery jsonb,
  add column if not exists address text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists source text,
  add column if not exists source_place_id text,
  add column if not exists average_rating numeric(2, 1),
  add column if not exists phone text,
  add column if not exists website text,
  add column if not exists id_province uuid,
  add column if not exists id_region uuid,
  add column if not exists id_zone uuid,
  add column if not exists updated_at timestamp with time zone default now(),
  add column if not exists review_count bigint,
  add column if not exists minimum_price numeric,
  add column if not exists maximum_price numeric,
  add column if not exists estimated_duration_minutes integer,
  add column if not exists detailed_description text,
  add column if not exists price_level numeric default 0,
  add column if not exists old_province uuid;

alter table if exists public.activity
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists name text,
  add column if not exists cover_image text,
  add column if not exists gallery jsonb,
  add column if not exists short_description text,
  add column if not exists detailed_description text,
  add column if not exists activity_type text,
  add column if not exists opening_hours jsonb,
  add column if not exists price_range text,
  add column if not exists safety_notes text,
  add column if not exists average_rating numeric(2, 1),
  add column if not exists review_count integer default 0,
  add column if not exists created_at timestamp with time zone default now(),
  add column if not exists updated_at timestamp with time zone default now(),
  add column if not exists id_province uuid;

alter table if exists public.culture
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists name text,
  add column if not exists cover_image text,
  add column if not exists gallery jsonb,
  add column if not exists short_description text,
  add column if not exists detailed_description text,
  add column if not exists origin_history text,
  add column if not exists cultural_significance text,
  add column if not exists event_time text,
  add column if not exists etiquette text,
  add column if not exists notable_figures text,
  add column if not exists average_rating numeric(2, 1),
  add column if not exists review_count integer default 0,
  add column if not exists created_at timestamp with time zone default now(),
  add column if not exists updated_at timestamp with time zone default now(),
  add column if not exists id_province uuid;

alter table if exists public.local_products
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists name text,
  add column if not exists cover_image text,
  add column if not exists gallery jsonb,
  add column if not exists short_description text,
  add column if not exists detailed_description text,
  add column if not exists category text,
  add column if not exists storage_transport text,
  add column if not exists price_range text,
  add column if not exists trusted_places text,
  add column if not exists average_rating numeric(2, 1),
  add column if not exists review_count integer default 0,
  add column if not exists created_at timestamp with time zone default now(),
  add column if not exists updated_at timestamp with time zone default now(),
  add column if not exists id_province uuid;

do $$
declare
  target_table text;
begin
  foreach target_table in array array[
    'province',
    'place',
    'activity',
    'culture',
    'local_products'
  ]
  loop
    if to_regclass(format('public.%I', target_table)) is not null then
      execute format('alter table public.%I enable row level security', target_table);
      execute format(
        'grant select on public.%I to anon, authenticated',
        target_table
      );
      execute format(
        'grant insert, update, delete on public.%I to authenticated',
        target_table
      );
      execute format(
        'drop policy if exists "Public can read %s" on public.%I',
        target_table,
        target_table
      );
      execute format(
        'create policy "Public can read %s" on public.%I for select to anon, authenticated using (true)',
        target_table,
        target_table
      );
      execute format(
        'drop policy if exists "Admin can manage %s" on public.%I',
        target_table,
        target_table
      );
      execute format(
        'create policy "Admin can manage %s" on public.%I for all to authenticated using (public.admin_content_is_admin()) with check (public.admin_content_is_admin())',
        target_table,
        target_table
      );
    end if;
  end loop;
end $$;
