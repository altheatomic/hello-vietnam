-- Use public.province.id_province as the canonical province key for itinerary
-- generation and newly saved plans. This migration is additive: legacy
-- city_province values remain available for reading old plans.

alter table if exists public.plan
  add column if not exists id_province uuid;
-- Province UUIDs were generated independently. Backfill historical plans by
-- normalized display name, never by assuming UUID equality.
update public.plan pl
set id_province = p.id_province
from public.city_province cp
join public.province p
  on lower(trim(p.name)) = lower(trim(cp.name))
where pl.id_province is null
  and pl.city_province = cp.id_city::text;
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'plan_id_province_fkey'
      and conrelid = 'public.plan'::regclass
  ) then
    alter table public.plan
      add constraint plan_id_province_fkey
      foreign key (id_province) references public.province(id_province)
      not valid;
  end if;
end $$;
-- The column existed before this migration in some environments, so add the
-- canonical FK without invalidating existing rows during deployment.
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'place_id_province_province_fkey'
      and conrelid = 'public.place'::regclass
  ) then
    alter table public.place
      add constraint place_id_province_province_fkey
      foreign key (id_province) references public.province(id_province)
      not valid;
  end if;
end $$;
create index if not exists idx_place_id_province
  on public.place(id_province);
create index if not exists idx_plan_id_province
  on public.plan(id_province);
-- The localized view predates place.id_province. Append the canonical column
-- so existing view column order remains stable for current consumers.
create or replace view public.place_localized_en as
select
  p.id_place,
  p.id_place_subcategory,
  p.status,
  p.old_province,
  p.latitude,
  p.longitude,
  p.estimated_duration_minutes,
  p.gallery,
  p.average_rating,
  p.review_count,
  p.cover_image,
  p.minimum_price,
  p.maximum_price,
  p.price_level,
  p.phone,
  p.website,
  p.timespan,
  p.timeclose,
  coalesce(pt.name, p.name) as name,
  coalesce(pt.description, p.short_description) as short_description,
  coalesce(pt.address, p.address) as address,
  p.id_province
from public.place p
left join public.place_translation pt
  on pt.place_id = p.id_place
 and pt.lang_code = 'en';
create or replace function public.get_planning_reference_data_by_province(
  p_province uuid
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
with province_places as (
  select p.*
  from public.place_localized_en p
  join public.place_subcategory ps
    on ps.id_place_subcategory = p.id_place_subcategory
  where p.id_province = p_province
    and p.status = 'active'
    and ps.is_itinerary_eligible = true
    and p.latitude is not null
    and p.longitude is not null
  limit 500
)
select jsonb_build_object(
  'places', coalesce((
    select jsonb_agg(
      jsonb_set(
        to_jsonb(p),
        '{place_subcategory}',
        to_jsonb(jsonb_build_object(
          'name', ps.name,
          'place_category', ps.place_category,
          'is_itinerary_eligible', ps.is_itinerary_eligible
        )),
        true
      )
    )
    from province_places p
    join public.place_subcategory ps
      on ps.id_place_subcategory = p.id_place_subcategory
  ), '[]'::jsonb),
  'place_tags', coalesce((
    select jsonb_agg(
      to_jsonb(pt) || jsonb_build_object('tag', to_jsonb(t))
    )
    from public.place_tag pt
    join public.tag t on t.id_tag = pt.id_tag
    where exists (
      select 1 from province_places pp where pp.id_place = pt.id_place
    )
  ), '[]'::jsonb),
  'tags', coalesce((
    select jsonb_agg(to_jsonb(t))
    from public.tag t
    where t.is_active = true
  ), '[]'::jsonb)
);
$$;
revoke all on function public.get_planning_reference_data_by_province(uuid)
  from public;
grant execute on function public.get_planning_reference_data_by_province(uuid)
  to service_role;
