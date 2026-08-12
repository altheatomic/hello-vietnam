-- =============================================================================
-- Add include_lunch_break to plan (Step 5 wizard: "Có nghỉ trưa không?")
-- Plan-level (not per-day, not per-component) — the whole trip either
-- reserves a lunch break or it doesn't, matching how schedule_builder.py's
-- include_lunch flag is threaded through (one value per plan() call).
--
-- Same class of bug as start_time/end_time (20260715000300), the Goong
-- travel columns (20260806000100), and plan_component.tags
-- (20260809000100): a value computed at plan() request time must be
-- persisted explicitly or it "disappears" the moment a saved trip is
-- reloaded (get_plan()) or copied (clone_plan()) — see queries_plan.py.
--
-- NOT NULL with default true: unlike the nullable Goong/tags columns, every
-- row (including ones inserted before this migration) has a well-defined
-- answer here — "true" is the behaviour that existed before this feature,
-- so backfilling existing rows to true is correct, not just a placeholder.
-- Safe to re-run: uses IF NOT EXISTS.
-- =============================================================================

alter table plan
  add column if not exists include_lunch_break boolean not null default true;

-- create_plan_with_default_title() creates the `plan` row (see
-- 20260801000100_plan_titles.sql / 20260806090200_plan_default_title_use_province.sql)
-- — it is the only INSERT path for `plan`, so the new column must be threaded
-- through here too, not just added to the table. New parameter appended last
-- with a default so it stays backward-compatible with any caller that
-- doesn't pass it. Every other line is byte-for-byte identical to the prior
-- version.
create or replace function public.create_plan_with_default_title(
  p_id_user uuid,
  p_id_province uuid,
  p_business_old_province uuid,
  p_n_days integer,
  p_start_at date,
  p_end_at date,
  p_interest_option_codes text[],
  p_include_lunch_break boolean default true
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
    interest_option_codes,
    include_lunch_break
  ) values (
    v_id_plan,
    p_id_user,
    p_n_days::text,
    p_start_at,
    p_end_at,
    p_id_province,
    v_title,
    v_category_label,
    v_codes,
    coalesce(p_include_lunch_break, true)
  );

  return query select v_id_plan, v_title;
end;
$$;
