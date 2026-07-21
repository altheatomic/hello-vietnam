-- Feed PLACE behavior into user_interest_tag using the same fixed formula as
-- backend/supabase/functions/explore/explore_behavior.ts.
--
-- Intentionally does not replace public.track_favorite_place_insert() or
-- public.favorite_place_track_add. The existing INSERT trigger remains the
-- sole producer of add_favorite events.

alter table public.place_tag
  add column if not exists tag_role text null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'place_tag_tag_role_check'
      and conrelid = 'public.place_tag'::regclass
  ) then
    alter table public.place_tag
      add constraint place_tag_tag_role_check
      check (tag_role is null or tag_role in ('primary', 'secondary'));
  end if;
end
$$;

comment on column public.place_tag.tag_role is
  'PLACE behavior factor: primary=1.0; secondary or null=0.5.';

create or replace function public.apply_place_interest_event(
  p_user_id uuid,
  p_place_id uuid,
  p_event_type text,
  p_occurrences integer default 1
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event_score numeric;
begin
  if p_user_id is null or p_place_id is null then
    raise exception 'p_user_id and p_place_id must not be null';
  end if;

  if p_occurrences is null or p_occurrences <= 0 then
    return;
  end if;

  v_event_score := case p_event_type
    when 'view_detail' then 1
    when 'share' then 2
    when 'add_favorite' then 3
    when 'unfavorite' then -3
    else null
  end;

  if v_event_score is null then
    raise exception 'Unsupported PLACE interest event type: %', p_event_type;
  end if;

  -- One atomic upsert per place tag. The conflict branch calculates from the
  -- locked current row, so concurrent events cannot overwrite each other with
  -- a stale read. EXCLUDED.behavior_score carries this event's signed delta.
  insert into public.user_interest_tag as current_interest (
    id_user,
    id_tag,
    initial_weight,
    behavior_score,
    behavior_weight,
    final_weight,
    positive_behavior_count,
    negative_behavior_count,
    behavior_count,
    source
  )
  select
    p_user_id,
    pt.id_tag,
    0::numeric as initial_weight,
    (
      v_event_score
      * case when pt.tag_role = 'primary' then 1.0 else 0.5 end
      * p_occurrences
    )::numeric as behavior_score,
    least(
      greatest(
        (
          v_event_score
          * case when pt.tag_role = 'primary' then 1.0 else 0.5 end
          * p_occurrences
        ) / 10.0,
        0.0
      ),
      1.0
    )::numeric as behavior_weight,
    least(
      greatest(
        0.6 * least(
          greatest(
            (
              v_event_score
              * case when pt.tag_role = 'primary' then 1.0 else 0.5 end
              * p_occurrences
            ) / 10.0,
            0.0
          ),
          1.0
        ),
        0.0
      ),
      1.0
    )::numeric as final_weight,
    case when v_event_score > 0 then p_occurrences else 0 end,
    case when v_event_score < 0 then p_occurrences else 0 end,
    p_occurrences,
    'behavior'
  from public.place_tag pt
  where pt.id_place = p_place_id
  on conflict (id_user, id_tag) do update
  set
    behavior_score =
      coalesce(current_interest.behavior_score, 0)
      + excluded.behavior_score,
    behavior_weight = least(
      greatest(
        (
          coalesce(current_interest.behavior_score, 0)
          + excluded.behavior_score
        ) / 10.0,
        0.0
      ),
      1.0
    ),
    final_weight = least(
      greatest(
        0.4 * coalesce(current_interest.initial_weight, 0)
        + 0.6 * least(
          greatest(
            (
              coalesce(current_interest.behavior_score, 0)
              + excluded.behavior_score
            ) / 10.0,
            0.0
          ),
          1.0
        ),
        0.0
      ),
      1.0
    ),
    positive_behavior_count =
      coalesce(current_interest.positive_behavior_count, 0)
      + excluded.positive_behavior_count,
    negative_behavior_count =
      coalesce(current_interest.negative_behavior_count, 0)
      + excluded.negative_behavior_count,
    behavior_count =
      coalesce(current_interest.behavior_count, 0)
      + excluded.behavior_count,
    source = case
      when current_interest.source is null then
        case
          when coalesce(current_interest.initial_weight, 0) > 0 then 'mixed'
          else 'behavior'
        end
      when current_interest.source in ('behavior', 'mixed') then
        current_interest.source
      when coalesce(current_interest.initial_weight, 0) > 0 then 'mixed'
      else current_interest.source
    end;
end;
$$;

revoke all on function public.apply_place_interest_event(uuid, uuid, text, integer)
  from public;

create or replace function public.track_user_event_log_place_interest()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_occurrences integer;
begin
  if new.event_type not in (
    'view_detail',
    'share',
    'add_favorite',
    'unfavorite'
  ) then
    return new;
  end if;

  v_occurrences := new.event_count - case
    when tg_op = 'UPDATE' then coalesce(old.event_count, 0)
    else 0
  end;

  if v_occurrences > 0 then
    perform public.apply_place_interest_event(
      new.id_user,
      new.id_place,
      new.event_type,
      v_occurrences
    );
  end if;

  return new;
end;
$$;

drop trigger if exists user_event_log_track_place_interest
  on public.user_event_log;

create trigger user_event_log_track_place_interest
after insert or update of event_count on public.user_event_log
for each row
execute function public.track_user_event_log_place_interest();

create or replace function public.track_favorite_place_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- A parent cascade also deletes favorite_place rows. Only a user-initiated
  -- unfavorite still has both parent rows visible and is a behavior signal.
  if exists (
    select 1
    from public.user_account ua
    where ua.id_user = old.id_user
  ) and exists (
    select 1
    from public.place p
    where p.id_place = old.id_place
  ) then
    insert into public.user_event_log (
      id_user,
      id_place,
      event_type,
      event_count,
      first_at,
      last_at
    )
    values (
      old.id_user,
      old.id_place,
      'unfavorite',
      1,
      now(),
      now()
    )
    on conflict (id_user, id_place, event_type) do update
    set
      event_count = public.user_event_log.event_count + 1,
      last_at = now();
  end if;

  return old;
end;
$$;

-- Do not modify public.favorite_place_track_add or
-- public.track_favorite_place_insert(). This is a DELETE-only addition.
drop trigger if exists favorite_place_track_remove
  on public.favorite_place;

create trigger favorite_place_track_remove
after delete on public.favorite_place
for each row
execute function public.track_favorite_place_delete();
