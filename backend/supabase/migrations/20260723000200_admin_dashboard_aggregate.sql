create index if not exists idx_user_account_created_at
  on public.user_account (created_at desc);

create index if not exists idx_place_created_at
  on public.place (created_at desc);

create index if not exists idx_province_created_at
  on public.province (created_at desc);

create index if not exists idx_activity_created_at
  on public.activity (created_at desc);

create index if not exists idx_culture_created_at
  on public.culture (created_at desc);

create index if not exists idx_local_products_created_at
  on public.local_products (created_at desc);

create index if not exists idx_forum_post_created_at
  on public.forum_post (created_at desc);

create index if not exists idx_plan_created_at
  on public.plan (created_at desc);

create index if not exists idx_favorite_food_created_at
  on public.favorite_food (created_at desc);

create index if not exists idx_favorite_place_created_at
  on public.favorite_place (created_at desc);

create index if not exists idx_favorite_city_created_at
  on public.favorite_city (created_at desc);

create index if not exists idx_favorite_activity_created_at
  on public.favorite_activity (created_at desc);

create index if not exists idx_favorite_culture_created_at
  on public.favorite_culture (created_at desc);

create index if not exists idx_favorite_local_product_created_at
  on public.favorite_local_product (created_at desc);

create index if not exists idx_user_event_log_place_last_at
  on public.user_event_log (id_place, last_at desc);

create or replace function public.admin_dashboard_aggregate(
  p_requesting_user uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if not exists (
    select 1
    from public.user_account
    where id_user = p_requesting_user
      and lower(coalesce(role, '')) = 'admin'
  ) then
    raise exception 'FORBIDDEN'
      using errcode = '42501';
  end if;

  with
  bounds as (
    select
      now() as generated_at,
      now() - interval '30 days' as current_30_start,
      now() - interval '60 days' as previous_30_start,
      now() - interval '90 days' as current_90_start
  ),
  user_counts as (
    select
      count(*)::bigint as total,
      count(*) filter (
        where created_at >= (select current_30_start from bounds)
      )::bigint as new_30d,
      count(*) filter (
        where created_at >= (select previous_30_start from bounds)
          and created_at < (select current_30_start from bounds)
      )::bigint as previous_30d
    from public.user_account
  ),
  content_counts as (
    select
      (select count(*) from public.place)::bigint as places_total,
      (select count(*) from public.place
        where created_at >= (select current_30_start from bounds)
      )::bigint as places_new_30d,
      (select count(*) from public.place
        where created_at >= (select previous_30_start from bounds)
          and created_at < (select current_30_start from bounds)
      )::bigint as places_previous_30d,
      (select count(*) from public.food)::bigint as foods_total,
      (select count(*) from public.province)::bigint as provinces_total,
      (select count(*) from public.province
        where created_at >= (select current_30_start from bounds)
      )::bigint as provinces_new_30d,
      (select count(*) from public.activity)::bigint as activities_total,
      (select count(*) from public.activity
        where created_at >= (select current_30_start from bounds)
      )::bigint as activities_new_30d,
      (select count(*) from public.culture)::bigint as cultures_total,
      (select count(*) from public.culture
        where created_at >= (select current_30_start from bounds)
      )::bigint as cultures_new_30d,
      (select count(*) from public.local_products)::bigint
        as local_products_total,
      (select count(*) from public.local_products
        where created_at >= (select current_30_start from bounds)
      )::bigint as local_products_new_30d
  ),
  report_counts as (
    select
      count(*) filter (
        where status in ('pending', 'reviewing')
      )::bigint as open,
      count(*) filter (
        where created_at >= date_trunc('day', now())
      )::bigint as new_today
    from public.report
  ),
  engagement_counts as (
    select
      (select count(*) from public.forum_post
        where created_at >= (select current_30_start from bounds)
      )::bigint as forum_posts_30d,
      (select count(*) from public.plan
        where created_at >= (select current_30_start from bounds)
      )::bigint as plans_30d,
      (
        (select count(*) from public.favorite_food
          where created_at >= (select current_30_start from bounds))
        + (select count(*) from public.favorite_place
          where created_at >= (select current_30_start from bounds))
        + (select count(*) from public.favorite_city
          where created_at >= (select current_30_start from bounds))
        + (select count(*) from public.favorite_activity
          where created_at >= (select current_30_start from bounds))
        + (select count(*) from public.favorite_culture
          where created_at >= (select current_30_start from bounds))
        + (select count(*) from public.favorite_local_product
          where created_at >= (select current_30_start from bounds))
      )::bigint as favorites_30d,
      (
        (select count(*) from public.favorite_food
          where created_at >= (select current_90_start from bounds))
        + (select count(*) from public.favorite_place
          where created_at >= (select current_90_start from bounds))
        + (select count(*) from public.favorite_city
          where created_at >= (select current_90_start from bounds))
        + (select count(*) from public.favorite_activity
          where created_at >= (select current_90_start from bounds))
        + (select count(*) from public.favorite_culture
          where created_at >= (select current_90_start from bounds))
        + (select count(*) from public.favorite_local_product
          where created_at >= (select current_90_start from bounds))
      )::bigint as favorites_90d,
      (select count(*) from public.forum_post
        where created_at >= (select current_90_start from bounds)
      )::bigint as forum_posts_90d,
      (select count(*) from public.plan
        where created_at >= (select current_90_start from bounds)
      )::bigint as plans_90d
  ),
  report_status as (
    select expected.label, count(r.id_report)::bigint as count
    from (
      values ('pending'), ('reviewing'), ('resolved'), ('rejected')
    ) as expected(label)
    left join public.report r on r.status = expected.label
    group by expected.label
  ),
  report_category as (
    select expected.label, count(r.id_report)::bigint as count
    from (
      values
        ('content_report'),
        ('bug_report'),
        ('suggestion'),
        ('account_issue'),
        ('payment_issue')
    ) as expected(label)
    left join public.report r on r.report_category = expected.label
    group by expected.label
  ),
  user_daily as (
    select
      to_char(day_value, 'Dy') as label,
      count(u.id_user)::bigint as count,
      day_value
    from generate_series(
      date_trunc('day', now()) - interval '6 days',
      date_trunc('day', now()),
      interval '1 day'
    ) as days(day_value)
    left join public.user_account u
      on u.created_at >= day_value
      and u.created_at < day_value + interval '1 day'
    group by day_value
    order by day_value
  ),
  weekly_buckets as (
    select
      bucket_start,
      row_number() over (order by bucket_start) as bucket_number
    from generate_series(
      date_trunc('week', now()) - interval '3 weeks',
      date_trunc('week', now()),
      interval '1 week'
    ) as buckets(bucket_start)
  ),
  weekly_activity as (
    select
      'W' || bucket_number::text as label,
      (
        select count(*)
        from public.forum_post fp
        where fp.created_at >= bucket_start
          and fp.created_at < bucket_start + interval '1 week'
      )::bigint as forum_posts,
      (
        select count(*)
        from public.plan p
        where p.created_at >= bucket_start
          and p.created_at < bucket_start + interval '1 week'
      )::bigint as plans,
      (
        (select count(*) from public.favorite_food f
          where f.created_at >= bucket_start
            and f.created_at < bucket_start + interval '1 week')
        + (select count(*) from public.favorite_place f
          where f.created_at >= bucket_start
            and f.created_at < bucket_start + interval '1 week')
        + (select count(*) from public.favorite_city f
          where f.created_at >= bucket_start
            and f.created_at < bucket_start + interval '1 week')
        + (select count(*) from public.favorite_activity f
          where f.created_at >= bucket_start
            and f.created_at < bucket_start + interval '1 week')
        + (select count(*) from public.favorite_culture f
          where f.created_at >= bucket_start
            and f.created_at < bucket_start + interval '1 week')
        + (select count(*) from public.favorite_local_product f
          where f.created_at >= bucket_start
            and f.created_at < bucket_start + interval '1 week')
      )::bigint as favorites,
      bucket_start
    from weekly_buckets
    order by bucket_start
  ),
  weekly_places as (
    select
      'W' || wb.bucket_number::text as label,
      count(p.id_place)::bigint as count,
      wb.bucket_start
    from weekly_buckets wb
    left join public.place p
      on p.created_at >= wb.bucket_start
      and p.created_at < wb.bucket_start + interval '1 week'
    group by wb.bucket_start, wb.bucket_number
    order by wb.bucket_start
  ),
  trending_places as (
    select
      p.id_place as id,
      coalesce(p.name, 'Unnamed place') as name,
      coalesce(sum(uel.event_count), 0)::bigint as views,
      (
        select count(*)
        from public.favorite_place fp
        where fp.id_place = p.id_place
      )::bigint as saves,
      p.average_rating as rating
    from public.place p
    left join public.user_event_log uel on uel.id_place = p.id_place
    group by p.id_place, p.name, p.average_rating
    order by views desc, saves desc, p.name
    limit 5
  )
  select jsonb_build_object(
    'generated_at', (select generated_at from bounds),
    'users', jsonb_build_object(
      'total', uc.total,
      'new_30d', uc.new_30d,
      'previous_30d', uc.previous_30d,
      'daily_7d', coalesce((
        select jsonb_agg(
          jsonb_build_object('label', label, 'count', count)
          order by day_value
        )
        from user_daily
      ), '[]'::jsonb)
    ),
    'content', jsonb_build_object(
      'total',
        cc.places_total
        + cc.foods_total
        + cc.provinces_total
        + cc.activities_total
        + cc.cultures_total
        + cc.local_products_total,
      'places_total', cc.places_total,
      'places_new_30d', cc.places_new_30d,
      'places_previous_30d', cc.places_previous_30d,
      'foods_total', cc.foods_total,
      'provinces_total', cc.provinces_total,
      'activities_total', cc.activities_total,
      'cultures_total', cc.cultures_total,
      'local_products_total', cc.local_products_total,
      'weekly_places_4', coalesce((
        select jsonb_agg(
          jsonb_build_object('label', label, 'count', count)
          order by bucket_start
        )
        from weekly_places
      ), '[]'::jsonb),
      'inventory', jsonb_build_array(
        jsonb_build_object(
          'key', 'place',
          'label', 'Places',
          'count', cc.places_total,
          'new_30d', cc.places_new_30d
        ),
        jsonb_build_object(
          'key', 'food',
          'label', 'Food',
          'count', cc.foods_total,
          'new_30d', 0
        ),
        jsonb_build_object(
          'key', 'province',
          'label', 'Provinces',
          'count', cc.provinces_total,
          'new_30d', cc.provinces_new_30d
        ),
        jsonb_build_object(
          'key', 'activity',
          'label', 'Activities',
          'count', cc.activities_total,
          'new_30d', cc.activities_new_30d
        ),
        jsonb_build_object(
          'key', 'culture',
          'label', 'Culture',
          'count', cc.cultures_total,
          'new_30d', cc.cultures_new_30d
        ),
        jsonb_build_object(
          'key', 'local_product',
          'label', 'Local Products',
          'count', cc.local_products_total,
          'new_30d', cc.local_products_new_30d
        )
      )
    ),
    'reports', jsonb_build_object(
      'open', rc.open,
      'new_today', rc.new_today,
      'by_status', coalesce((
        select jsonb_agg(
          jsonb_build_object('label', label, 'count', count)
          order by label
        )
        from report_status
      ), '[]'::jsonb),
      'by_category', coalesce((
        select jsonb_agg(
          jsonb_build_object('label', label, 'count', count)
          order by label
        )
        from report_category
      ), '[]'::jsonb)
    ),
    'engagement', jsonb_build_object(
      'forum_posts_30d', ec.forum_posts_30d,
      'plans_30d', ec.plans_30d,
      'favorites_30d', ec.favorites_30d,
      'weekly_4', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'label', label,
            'forum_posts', forum_posts,
            'plans', plans,
            'favorites', favorites
          )
          order by bucket_start
        )
        from weekly_activity
      ), '[]'::jsonb),
      'feature_30d', jsonb_build_array(
        jsonb_build_object(
          'feature', 'Wishlist',
          'count', ec.favorites_30d
        ),
        jsonb_build_object(
          'feature', 'Trip Planner',
          'count', ec.plans_30d
        ),
        jsonb_build_object(
          'feature', 'Forum',
          'count', ec.forum_posts_30d
        )
      ),
      'feature_90d', jsonb_build_array(
        jsonb_build_object(
          'feature', 'Wishlist',
          'count', ec.favorites_90d
        ),
        jsonb_build_object(
          'feature', 'Trip Planner',
          'count', ec.plans_90d
        ),
        jsonb_build_object(
          'feature', 'Forum',
          'count', ec.forum_posts_90d
        )
      )
    ),
    'subscriptions', jsonb_build_object(
      'active', (
        select count(*)::bigint
        from public.premium_subscription
        where lower(coalesce(status, '')) = 'active'
          and (end_date is null or end_date > now())
      )
    ),
    'trending_places', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', id,
          'name', name,
          'views', views,
          'saves', saves,
          'rating', rating
        )
        order by views desc, saves desc, name
      )
      from trending_places
    ), '[]'::jsonb)
  )
  into v_result
  from user_counts uc
  cross join content_counts cc
  cross join report_counts rc
  cross join engagement_counts ec;

  return v_result;
end;
$$;

revoke all on function public.admin_dashboard_aggregate(uuid)
  from public, anon, authenticated;
grant execute on function public.admin_dashboard_aggregate(uuid)
  to service_role;

comment on function public.admin_dashboard_aggregate(uuid) is
  'Returns one admin-only dashboard snapshot. Execute through the admin-dashboard Edge Function.';
