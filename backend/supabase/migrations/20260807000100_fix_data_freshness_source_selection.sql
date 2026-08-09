-- Keep the freshness checker from repeatedly claiming legacy rows that have no
-- configured source adapter. OSM rows imported with only source_external_id
-- remain eligible because the adapter can derive their canonical source URL.

create or replace function public.content_freshness_source_is_supported(
    p_source_type text
)
returns boolean
language sql
immutable
as $$
    select lower(trim(coalesce(p_source_type, ''))) in ('osm', 'wikipedia', 'wiki');
$$;

update public.content_freshness
set source_url = format(
        'https://www.openstreetmap.org/%s/%s',
        lower(split_part(source_external_id, ':', 2)),
        split_part(source_external_id, ':', 3)
    ),
    updated_at = now()
where lower(trim(source_type)) = 'osm'
  and nullif(trim(source_url), '') is null
  and source_external_id ~* '^osm:(node|way|relation):[0-9]+$';

create or replace function public.claim_due_content_freshness(
    p_run_id uuid,
    p_limit integer
)
returns setof public.content_freshness
language plpgsql
security definer
set search_path = public
as $$
declare
    v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 50);
begin
    if p_run_id is null then
        raise exception 'Run id is required.' using errcode = '22023';
    end if;
    if not exists (select 1 from public.content_update_run where id = p_run_id) then
        raise exception 'Update run not found: %', p_run_id using errcode = 'P0002';
    end if;

    return query
    with claimed as (
        select cf.id
        from public.content_freshness cf
        where cf.next_check_at <= now()
          and cf.freshness_status in ('fresh', 'due', 'stale')
          and public.content_freshness_source_is_supported(cf.source_type)
          and (
              lower(trim(cf.source_type)) = 'osm'
              or nullif(trim(cf.source_url), '') is not null
          )
        order by cf.next_check_at asc, cf.created_at asc
        for update skip locked
        limit v_limit
    ), marked as (
        update public.content_freshness cf
        set freshness_status = 'due', updated_at = now()
        from claimed
        where cf.id = claimed.id
        returning cf.*
    ), run_updated as (
        update public.content_update_run
        set selected_count = selected_count + (select count(*) from marked)
        where id = p_run_id
        returning 1
    )
    select marked.*
    from marked
    cross join run_updated;
end;
$$;
