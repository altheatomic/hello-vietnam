-- Read-only user-specific planning data bundle.
-- Rollback: DROP FUNCTION IF EXISTS public.get_user_planning_data(uuid, uuid[]);

create or replace function public.get_user_planning_data(
  p_user uuid,
  p_place_ids uuid[]
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
select jsonb_build_object(
  'profile', (
    select to_jsonb(utp)
    from public.user_travel_profile utp
    where utp.id_user = p_user
    limit 1
  ),
  'interest_tags', coalesce((
    select jsonb_agg(
      to_jsonb(uit) || jsonb_build_object('tag', to_jsonb(t))
    )
    from public.user_interest_tag uit
    left join public.tag t on t.id_tag = uit.id_tag
    where uit.id_user = p_user
  ), '[]'::jsonb),
  'onboarding_choices', coalesce((
    select jsonb_agg(to_jsonb(uoc))
    from public.user_onboarding_choice uoc
    where uoc.id_user = p_user
  ), '[]'::jsonb),
  'rated_places', coalesce((
    select jsonb_agg(to_jsonb(ri))
    from public.rate_item ri
    where ri.id_user = p_user
      and ri.item_type = 'place'
  ), '[]'::jsonb),
  'cf_scores', coalesce((
    select jsonb_object_agg(cs.id_place::text, cs.score)
    from public.cf_score_cache cs
    where cs.id_user = p_user
      and cs.id_place = any(coalesce(p_place_ids, '{}'::uuid[]))
  ), '{}'::jsonb)
);
$$;
revoke all on function public.get_user_planning_data(uuid, uuid[]) from public;
grant execute on function public.get_user_planning_data(uuid, uuid[]) to service_role;
