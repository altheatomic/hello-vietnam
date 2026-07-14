create or replace function public.refresh_rating_summary(
    p_content_type text,
    p_content_id uuid
)
returns public.rating_summary
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
    refreshed public.rating_summary%rowtype;
begin
    perform pg_advisory_xact_lock(
        hashtextextended(p_content_type || ':' || p_content_id::text, 0)
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
        rating_5_count,
        last_reviewed_at
    )
    select
        p_content_type,
        p_content_id,
        case
            when count(*) = 0 then null
            else round(avg(rating)::numeric, 2)
        end,
        count(*)::integer,
        count(*) filter (where rating = 1)::integer,
        count(*) filter (where rating = 2)::integer,
        count(*) filter (where rating = 3)::integer,
        count(*) filter (where rating = 4)::integer,
        count(*) filter (where rating = 5)::integer,
        max(updated_at)
    from public.reviews
    where content_type = p_content_type
      and content_id = p_content_id
      and status = 'published'
    on conflict (content_type, content_id) do update
    set
        average_rating = excluded.average_rating,
        review_count = excluded.review_count,
        rating_1_count = excluded.rating_1_count,
        rating_2_count = excluded.rating_2_count,
        rating_3_count = excluded.rating_3_count,
        rating_4_count = excluded.rating_4_count,
        rating_5_count = excluded.rating_5_count,
        last_reviewed_at = excluded.last_reviewed_at
    returning * into refreshed;

    return refreshed;
end;
$$;

revoke all on function public.refresh_rating_summary(text, uuid) from public;
grant execute on function public.refresh_rating_summary(text, uuid) to service_role;
