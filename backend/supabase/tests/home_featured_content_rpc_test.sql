begin;

insert into public.province (
  id_province,
  name,
  region_code,
  detailed_description,
  cover_image,
  average_rating
) values
  (
    '00000000-0000-0000-0000-00000000a001',
    '__home_rpc_reviewed_high',
    'BTB',
    'complete',
    'province/high.jpg',
    4.10
  ),
  (
    '00000000-0000-0000-0000-00000000a002',
    '__home_rpc_reviewed_low',
    'BTB',
    'complete',
    'province/low.jpg',
    4.90
  ),
  (
    '00000000-0000-0000-0000-00000000a003',
    '__home_rpc_unreviewed',
    'BTB',
    'complete',
    'province/unreviewed.jpg',
    5.00
  );

insert into public.food (
  id_food,
  name,
  image_path,
  description
) values
  (
    '00000000-0000-0000-0000-00000000b001',
    '__home_rpc_food_reviewed',
    'food/reviewed.jpg',
    'complete'
  ),
  (
    '00000000-0000-0000-0000-00000000b002',
    '__home_rpc_food_unreviewed',
    'food/unreviewed.jpg',
    'complete'
  );

insert into public.rating_summary (
  content_type,
  content_id,
  average_rating,
  review_count,
  rating_1_count,
  rating_2_count,
  rating_3_count,
  rating_4_count,
  rating_5_count
) values
  (
    'province',
    '00000000-0000-0000-0000-00000000a001',
    5.00,
    3,
    0,
    0,
    0,
    0,
    3
  ),
  (
    'province',
    '00000000-0000-0000-0000-00000000a002',
    4.99,
    2,
    0,
    0,
    0,
    1,
    1
  ),
  (
    'food',
    '00000000-0000-0000-0000-00000000b001',
    5.00,
    1,
    0,
    0,
    0,
    0,
    1
  );

set local role anon;

do $$
declare
  v_first jsonb := public.get_home_featured_content(12);
  v_second jsonb := public.get_home_featured_content(12);
  v_destinations jsonb;
  v_dishes jsonb;
  v_high_index integer;
  v_low_index integer;
  v_unreviewed jsonb;
begin
  v_destinations := v_first -> 'destinations';
  v_dishes := v_first -> 'dishes';

  if v_first is distinct from v_second then
    raise exception 'Home RPC order is not deterministic';
  end if;

  select ordinal - 1 into v_high_index
  from jsonb_array_elements(v_destinations) with ordinality item(value, ordinal)
  where value ->> 'id' = '00000000-0000-0000-0000-00000000a001';

  select ordinal - 1 into v_low_index
  from jsonb_array_elements(v_destinations) with ordinality item(value, ordinal)
  where value ->> 'id' = '00000000-0000-0000-0000-00000000a002';

  if v_high_index is null or v_low_index is null or v_high_index >= v_low_index then
    raise exception 'Reviewed destination rating order is incorrect';
  end if;

  select value into v_unreviewed
  from jsonb_array_elements(v_destinations) item(value)
  where value ->> 'id' = '00000000-0000-0000-0000-00000000a003';

  if v_unreviewed is null
     or v_unreviewed -> 'rating' <> 'null'::jsonb
     or (v_unreviewed ->> 'review_count')::integer <> 0 then
    raise exception 'Unreviewed destination exposed a fabricated rating';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(v_dishes) item(value)
    where value ->> 'id' = '00000000-0000-0000-0000-00000000b002'
      and value -> 'rating' = 'null'::jsonb
      and (value ->> 'review_count')::integer = 0
  ) then
    raise exception 'Unreviewed food was not returned as unrated';
  end if;

  if jsonb_array_length(public.get_home_featured_content(100) -> 'destinations') > 12
     or jsonb_array_length(public.get_home_featured_content(0) -> 'destinations') > 1 then
    raise exception 'p_limit clamp is incorrect';
  end if;
end
$$;

reset role;
rollback;
