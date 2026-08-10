-- Backfill historical plans without consulting old_province. The legacy
-- city_province field contains IDs from an older dataset, while each saved
-- place now has the canonical province ID. Use the most frequent province
-- among a plan's places as its destination; plans without usable places stay
-- on the legacy read fallback.

with plan_province_counts as (
  select
    pc.id_plan,
    p.id_province,
    count(*) as place_count
  from public.plan_component pc
  join public.place p on p.id_place = pc.id_place
  where p.id_province is not null
  group by pc.id_plan, p.id_province
), ranked as (
  select
    id_plan,
    id_province,
    row_number() over (
      partition by id_plan
      order by place_count desc, id_province
    ) as rank_no
  from plan_province_counts
)
update public.plan pl
set id_province = ranked.id_province
from ranked
where ranked.rank_no = 1
  and pl.id_plan = ranked.id_plan
  and pl.id_province is null;
