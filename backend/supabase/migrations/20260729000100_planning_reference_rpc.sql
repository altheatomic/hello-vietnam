-- Read-only planning reference bundle.
-- Rollback: DROP FUNCTION IF EXISTS public.get_planning_reference_data(uuid);

create or replace function public.get_planning_reference_data(p_old_province uuid)
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
  where p.old_province = p_old_province
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
revoke all on function public.get_planning_reference_data(uuid) from public;
grant execute on function public.get_planning_reference_data(uuid) to service_role;
