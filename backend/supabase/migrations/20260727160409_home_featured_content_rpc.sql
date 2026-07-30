alter table public.rating_summary enable row level security;

grant select on public.rating_summary to anon, authenticated;

drop policy if exists "Home can read rating summaries" on public.rating_summary;
create policy "Home can read rating summaries"
on public.rating_summary
for select
to anon, authenticated
using (true);

create or replace function public.get_home_featured_content(
  p_limit integer default 4
)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  with limits as (
    select greatest(1, least(coalesce(p_limit, 4), 12)) as item_limit
  ),
  destination_candidates as (
    select
      p.id_province as id,
      trim(coalesce(p.name, '')) as name,
      coalesce(nullif(trim(p.region_code), ''), 'Vietnam destination') as category,
      coalesce(
        nullif(trim(p.detailed_description), ''),
        nullif(trim(p.short_description), '')
      ) as description,
      trim(coalesce(p.cover_image, '')) as image_path,
      case
        when coalesce(rs.review_count, 0) > 0 then rs.average_rating
        else null
      end as display_rating,
      coalesce(rs.review_count, 0)::integer as review_count,
      coalesce(rs.average_rating, p.average_rating) as rank_rating,
      (
        case when nullif(trim(p.cover_image), '') is not null then 1 else 0 end
        + case when coalesce(
            nullif(trim(p.detailed_description), ''),
            nullif(trim(p.short_description), '')
          ) is not null then 1 else 0 end
      ) as completeness
    from public.province p
    left join public.rating_summary rs
      on rs.content_type = 'province'
     and rs.content_id = p.id_province
    where p.id_province is not null
      and nullif(trim(p.name), '') is not null
  ),
  destinations as (
    select dc.*
    from destination_candidates dc
    cross join limits l
    order by
      (dc.review_count > 0) desc,
      dc.rank_rating desc nulls last,
      dc.completeness desc,
      lower(dc.name),
      dc.id
    limit (select item_limit from limits)
  ),
  dish_candidates as (
    select
      f.id_food as id,
      trim(coalesce(f.name, '')) as name,
      coalesce(
        nullif(trim(ft.type), ''),
        nullif(trim(ft.category), ''),
        'Vietnamese dish'
      ) as category,
      coalesce(
        nullif(trim(f.detailed_description), ''),
        nullif(trim(f.short_description), ''),
        nullif(trim(f.description), '')
      ) as description,
      coalesce(
        nullif(trim(f.cover_image), ''),
        nullif(trim(f.image_path), ''),
        ''
      ) as image_path,
      case
        when coalesce(rs.review_count, 0) > 0 then rs.average_rating
        else null
      end as display_rating,
      coalesce(rs.review_count, 0)::integer as review_count,
      rs.average_rating as rank_rating,
      (
        case when coalesce(
            nullif(trim(f.cover_image), ''),
            nullif(trim(f.image_path), '')
          ) is not null then 1 else 0 end
        + case when coalesce(
            nullif(trim(f.detailed_description), ''),
            nullif(trim(f.short_description), ''),
            nullif(trim(f.description), '')
          ) is not null then 1 else 0 end
      ) as completeness
    from public.food f
    left join public.food_type ft
      on ft.id = f.food_type_id
    left join public.rating_summary rs
      on rs.content_type = 'food'
     and rs.content_id = f.id_food
    where nullif(trim(f.name), '') is not null
  ),
  dishes as (
    select dc.*
    from dish_candidates dc
    cross join limits l
    order by
      (dc.review_count > 0) desc,
      dc.rank_rating desc nulls last,
      dc.completeness desc,
      lower(dc.name),
      dc.id
    limit (select item_limit from limits)
  )
  select jsonb_build_object(
    'destinations',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', id,
            'name', name,
            'category', category,
            'description', description,
            'image_path', image_path,
            'rating', display_rating,
            'review_count', review_count
          )
          order by
            (review_count > 0) desc,
            rank_rating desc nulls last,
            completeness desc,
            lower(name),
            id
        )
        from destinations
      ),
      '[]'::jsonb
    ),
    'dishes',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', id,
            'name', name,
            'category', category,
            'description', description,
            'image_path', image_path,
            'rating', display_rating,
            'review_count', review_count
          )
          order by
            (review_count > 0) desc,
            rank_rating desc nulls last,
            completeness desc,
            lower(name),
            id
        )
        from dishes
      ),
      '[]'::jsonb
    )
  );
$$;

revoke all on function public.get_home_featured_content(integer) from public;
grant execute on function public.get_home_featured_content(integer)
  to anon, authenticated;
