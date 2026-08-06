-- Switches create_plan_with_default_title()'s province-name lookup from
-- old_province (pre-merger, 63 rows) to province (post-merger, 34 rows) —
-- Trip Planner now sources id_province from `province` end-to-end (see
-- frontend trip_location_page.dart's getProvinces() and
-- cf_service/db/place_repository.py's place.id_province filter).
--
-- IMPORTANT: p_id_province / p_business_old_province parameter NAMES are
-- kept as-is here — renaming a plpgsql function's parameters is a breaking
-- signature change for every caller (queries_plan.py's supabase.rpc(...,
-- {"p_id_province": ..., "p_business_old_province": ...})). Only the
-- `from public.old_province op` -> `from public.province op` line changes;
-- every other line of logic is byte-for-byte identical to
-- 20260801000100_plan_titles.sql's create_plan_with_default_title().
-- p_business_old_province now carries a province.id_province value (despite
-- its old_province-era name) — see the paired cf_service change in
-- db/queries_plan.py.

create or replace function public.create_plan_with_default_title(
  p_id_user uuid,
  p_id_province uuid,
  p_business_old_province uuid,
  p_n_days integer,
  p_start_at date,
  p_end_at date,
  p_interest_option_codes text[]
)
returns table(id_plan uuid, custom_title text)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id_plan uuid := gen_random_uuid();
  v_province_name text;
  v_category_label text;
  v_base_title text;
  v_title text;
  v_suffix integer := 0;
  v_codes text[] := coalesce(p_interest_option_codes, '{}'::text[]);
begin
  if p_n_days < 1 then
    raise exception 'n_days must be positive' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_id_user::text, 0));

  select p.name
    into v_province_name
    from public.province p
   where p.id_province = coalesce(p_id_province, p_business_old_province)
   limit 1;

  if nullif(btrim(v_province_name), '') is null then
    v_province_name := case
      when p_id_province is null then 'Business Trip'
      else 'Vietnam'
    end;
  end if;

  select string_agg(tio.display_name, ' + ' order by tio.display_order)
    into v_category_label
    from public.trip_interest_option tio
   where tio.option_code = any(v_codes)
     and tio.is_active = true;

  v_category_label := coalesce(nullif(btrim(v_category_label), ''), 'General');
  v_base_title := left(extensions.unaccent(
    v_province_name || '_' || p_n_days::text || 'days_' || v_category_label
  ), 120);
  v_title := v_base_title;

  while exists (
    select 1
      from public.plan p
     where p.id_user = p_id_user
       and lower(btrim(p.custom_title)) = lower(v_title)
  ) loop
    v_suffix := v_suffix + 1;
    v_title := left(
      v_base_title,
      120 - length(' (' || v_suffix::text || ')')
    ) || ' (' || v_suffix::text || ')';
  end loop;

  insert into public.plan (
    id_plan,
    id_user,
    duration,
    start_at,
    end_at,
    city_province,
    custom_title,
    category_label,
    interest_option_codes
  ) values (
    v_id_plan,
    p_id_user,
    p_n_days::text,
    p_start_at,
    p_end_at,
    p_id_province,
    v_title,
    v_category_label,
    v_codes
  );

  return query select v_id_plan, v_title;
end;
$$;
