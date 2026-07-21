-- Integration test for 20260718000100_add_place_interest_behavior.sql.
-- Run after the migration in Supabase SQL Editor.
-- All test writes are rolled back, including the cascade-delete scenario.

begin;

do $$
declare
  v_user_id uuid;
  v_temp_user_id uuid := extensions.uuid_generate_v4();
  v_tag_id uuid;
  v_place_id uuid := extensions.uuid_generate_v4();
  v_cascade_place_id uuid := extensions.uuid_generate_v4();
  v_score numeric;
  v_weight numeric;
  v_final numeric;
  v_positive integer;
  v_negative integer;
  v_total integer;
  v_event_count integer;
begin
  select ua.id_user
  into v_user_id
  from public.user_account ua
  order by ua.id_user
  limit 1;

  if v_user_id is null then
    raise exception 'Test requires at least one existing user_account row';
  end if;

  select t.id_tag
  into v_tag_id
  from public.tag t
  order by t.id_tag
  limit 1;

  if v_tag_id is null then
    raise exception 'Test requires at least one existing tag row';
  end if;

  insert into public.place (id_place, name)
  values
    (v_place_id, '__place_interest_test__'),
    (v_cascade_place_id, '__place_interest_cascade_test__');

  insert into public.place_tag (id_place, id_tag, confidence_score, tag_role)
  values
    (v_place_id, v_tag_id, 1.0, 'primary'),
    (v_cascade_place_id, v_tag_id, 1.0, 'primary');

  -- Isolate this user/tag from any pre-existing personalization. ROLLBACK at
  -- the end restores the original row exactly.
  delete from public.user_interest_tag
  where id_user = v_user_id
    and id_tag = v_tag_id;

  delete from public.user_event_log
  where id_user = v_user_id
    and id_place in (v_place_id, v_cascade_place_id);

  -- 1) First favorite: the existing favorite_place INSERT trigger writes
  -- add_favorite once; the new user_event_log trigger applies +3 once.
  insert into public.favorite_place (id_user, id_place)
  values (v_user_id, v_place_id);

  select
    behavior_score,
    behavior_weight,
    final_weight,
    positive_behavior_count,
    negative_behavior_count,
    behavior_count
  into
    v_score,
    v_weight,
    v_final,
    v_positive,
    v_negative,
    v_total
  from public.user_interest_tag
  where id_user = v_user_id
    and id_tag = v_tag_id;

  if v_score is distinct from 3::numeric
     or v_weight is distinct from 0.3::numeric
     or v_final is distinct from 0.18::numeric
     or v_positive is distinct from 1
     or v_negative is distinct from 0
     or v_total is distinct from 1 then
    raise exception
      'First favorite failed: score=%, weight=%, final=%, pos=%, neg=%, total=%',
      v_score, v_weight, v_final, v_positive, v_negative, v_total;
  end if;

  -- 2) Idempotent favorite: conflict UPDATE must not fire the existing
  -- AFTER INSERT trigger, so no second behavior event is produced.
  insert into public.favorite_place (id_user, id_place, created_at)
  values (v_user_id, v_place_id, now())
  on conflict (id_user, id_place) do update
  set created_at = excluded.created_at;

  select behavior_score, behavior_count
  into v_score, v_total
  from public.user_interest_tag
  where id_user = v_user_id
    and id_tag = v_tag_id;

  if v_score is distinct from 3::numeric
     or v_total is distinct from 1 then
    raise exception
      'Idempotent favorite double-counted: score=%, total=%',
      v_score, v_total;
  end if;

  -- 3) Unfavorite: DELETE trigger writes one unfavorite and applies -3 once.
  delete from public.favorite_place
  where id_user = v_user_id
    and id_place = v_place_id;

  select
    behavior_score,
    behavior_weight,
    final_weight,
    positive_behavior_count,
    negative_behavior_count,
    behavior_count
  into
    v_score,
    v_weight,
    v_final,
    v_positive,
    v_negative,
    v_total
  from public.user_interest_tag
  where id_user = v_user_id
    and id_tag = v_tag_id;

  if v_score is distinct from 0::numeric
     or v_weight is distinct from 0::numeric
     or v_final is distinct from 0::numeric
     or v_positive is distinct from 1
     or v_negative is distinct from 1
     or v_total is distinct from 2 then
    raise exception
      'Unfavorite failed: score=%, weight=%, final=%, pos=%, neg=%, total=%',
      v_score, v_weight, v_final, v_positive, v_negative, v_total;
  end if;

  select uel.event_count
  into v_event_count
  from public.user_event_log uel
  where uel.id_user = v_user_id
    and uel.id_place = v_place_id
    and uel.event_type = 'unfavorite';

  if v_event_count is distinct from 1 then
    raise exception 'Expected exactly one unfavorite event, got %', v_event_count;
  end if;

  -- 4) Favorite again after DELETE: another genuine INSERT applies +3 once.
  insert into public.favorite_place (id_user, id_place)
  values (v_user_id, v_place_id);

  select
    behavior_score,
    positive_behavior_count,
    negative_behavior_count,
    behavior_count
  into v_score, v_positive, v_negative, v_total
  from public.user_interest_tag
  where id_user = v_user_id
    and id_tag = v_tag_id;

  if v_score is distinct from 3::numeric
     or v_positive is distinct from 2
     or v_negative is distinct from 1
     or v_total is distinct from 3 then
    raise exception
      'Favorite-after-delete failed: score=%, pos=%, neg=%, total=%',
      v_score, v_positive, v_negative, v_total;
  end if;

  -- 5) Real cascade path: favorite_place.id_user has ON DELETE CASCADE.
  -- Use a disposable user so the primary test user and its preceding state
  -- remain available for comparison.
  insert into public.user_account (id_user)
  values (v_temp_user_id);

  insert into public.favorite_place (id_user, id_place)
  values (v_temp_user_id, v_cascade_place_id);

  if not exists (
    select 1
    from public.favorite_place
    where id_user = v_temp_user_id
      and id_place = v_cascade_place_id
  ) then
    raise exception 'Cascade setup failed: temporary favorite was not created';
  end if;

  delete from public.user_account
  where id_user = v_temp_user_id;

  if exists (
    select 1
    from public.favorite_place
    where id_user = v_temp_user_id
  ) then
    raise exception 'Cascade failed: temporary user favorite still exists';
  end if;

  if exists (
    select 1
    from public.user_event_log
    where id_user = v_temp_user_id
  ) then
    raise exception 'Cascade produced or retained an event for the deleted user';
  end if;

  raise notice 'All PLACE interest behavior tests passed.';
end
$$;

rollback;
