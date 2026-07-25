alter table public.user_account
add column if not exists avatar text;

create index if not exists forum_post_active_created_id_idx
on public.forum_post(created_at desc, id_post desc)
where status is null or status = 'active';

create index if not exists forum_post_active_author_created_id_idx
on public.forum_post(id_author_user, created_at desc, id_post desc)
where status is null or status = 'active';

create index if not exists forum_comment_active_post_created_id_idx
on public.forum_comment(id_post, created_at desc, id_comment desc)
where status is null or status = 'active';

create index if not exists forum_post_report_reporter_post_idx
on public.forum_post_report(id_reporter_user, id_post);

create or replace function public.forum_feed_page(
  p_feed text default 'for_you',
  p_limit integer default 20,
  p_before_created_at timestamp with time zone default null,
  p_before_post_id uuid default null
)
returns table (
  id_post uuid,
  id_author_user uuid,
  title text,
  content text,
  shared_item jsonb,
  created_at timestamp with time zone,
  author_name text,
  author_username text,
  author_avatar text,
  author_role text,
  author_follower_count bigint,
  author_following_count bigint,
  image_urls text[],
  like_count bigint,
  comment_count bigint,
  is_liked boolean,
  is_bookmarked boolean,
  is_following boolean,
  is_reported boolean
)
language plpgsql
stable
security invoker
set search_path = public, extensions
as $$
declare
  v_user_id uuid := auth.uid();
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 50));
begin
  if v_user_id is null then
    raise exception 'AUTH_REQUIRED' using errcode = 'P0001';
  end if;

  if p_feed not in ('for_you', 'following') then
    raise exception 'INVALID_FORUM_FEED' using errcode = '22023';
  end if;

  if (p_before_created_at is null) <> (p_before_post_id is null) then
    raise exception 'INVALID_FORUM_CURSOR' using errcode = '22023';
  end if;

  return query
  with post_page as materialized (
    select
      post.id_post,
      post.id_author_user,
      post.title,
      post.content,
      post.shared_item,
      post.created_at
    from public.forum_post as post
    where (post.status is null or post.status = 'active')
      and (
        p_before_created_at is null
        or (post.created_at, post.id_post)
          < (p_before_created_at, p_before_post_id)
      )
      and not exists (
        select 1
        from public.forum_user_block as blocked
        where blocked.blocker_user_id = v_user_id
          and blocked.blocked_user_id = post.id_author_user
      )
      and (
        p_feed = 'for_you'
        or exists (
          select 1
          from public.forum_user_follow as followed
          where followed.follower_user_id = v_user_id
            and followed.following_user_id = post.id_author_user
        )
      )
    order by post.created_at desc, post.id_post desc
    limit v_limit
  )
  select
    post.id_post,
    post.id_author_user,
    post.title,
    post.content,
    post.shared_item,
    post.created_at,
    coalesce(
      nullif(profile.full_name, ''),
      nullif(profile.username, ''),
      'Forum user'
    ) as author_name,
    coalesce(profile.username, '') as author_username,
    coalesce(profile.avatar, '') as author_avatar,
    coalesce(profile.role, 'user') as author_role,
    (
      select count(*)
      from public.forum_user_follow as follower_count
      where follower_count.following_user_id = post.id_author_user
    ) as author_follower_count,
    (
      select count(*)
      from public.forum_user_follow as following_count
      where following_count.follower_user_id = post.id_author_user
    ) as author_following_count,
    coalesce(
      (
        select array_agg(
          media.url
          order by media.position, media.created_at, media.id_media
        )
        from public.forum_post_media as media
        where media.id_post = post.id_post
      ),
      array[]::text[]
    ) as image_urls,
    (
      select count(*)
      from public.forum_post_like as post_like
      where post_like.id_post = post.id_post
    ) as like_count,
    (
      select count(*)
      from public.forum_comment as comment
      where comment.id_post = post.id_post
        and (comment.status is null or comment.status = 'active')
    ) as comment_count,
    exists (
      select 1
      from public.forum_post_like as own_like
      where own_like.id_post = post.id_post
        and own_like.id_user = v_user_id
    ) as is_liked,
    exists (
      select 1
      from public.forum_post_bookmark as own_bookmark
      where own_bookmark.id_post = post.id_post
        and own_bookmark.id_user = v_user_id
    ) as is_bookmarked,
    exists (
      select 1
      from public.forum_user_follow as own_follow
      where own_follow.follower_user_id = v_user_id
        and own_follow.following_user_id = post.id_author_user
    ) as is_following,
    exists (
      select 1
      from public.forum_post_report as own_report
      where own_report.id_post = post.id_post
        and own_report.id_reporter_user = v_user_id
    ) as is_reported
  from post_page as post
  join public.user_account as profile
    on profile.id_user = post.id_author_user
  order by post.created_at desc, post.id_post desc;
end;
$$;

create or replace function public.forum_comments_page(
  p_post_id uuid,
  p_limit integer default 20,
  p_before_created_at timestamp with time zone default null,
  p_before_comment_id uuid default null
)
returns table (
  id_comment uuid,
  id_post uuid,
  id_author_user uuid,
  content text,
  created_at timestamp with time zone,
  author_name text,
  author_username text,
  author_avatar text,
  author_role text,
  like_count bigint,
  is_liked boolean
)
language plpgsql
stable
security invoker
set search_path = public, extensions
as $$
declare
  v_user_id uuid := auth.uid();
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 50));
begin
  if v_user_id is null then
    raise exception 'AUTH_REQUIRED' using errcode = 'P0001';
  end if;

  if p_post_id is null then
    raise exception 'POST_ID_REQUIRED' using errcode = '22023';
  end if;

  if (p_before_created_at is null) <> (p_before_comment_id is null) then
    raise exception 'INVALID_FORUM_CURSOR' using errcode = '22023';
  end if;

  return query
  select
    comment.id_comment,
    comment.id_post,
    comment.id_author_user,
    comment.content,
    comment.created_at,
    coalesce(
      nullif(profile.full_name, ''),
      nullif(profile.username, ''),
      'Forum user'
    ) as author_name,
    coalesce(profile.username, '') as author_username,
    coalesce(profile.avatar, '') as author_avatar,
    coalesce(profile.role, 'user') as author_role,
    (
      select count(*)
      from public.forum_comment_like as comment_like
      where comment_like.id_comment = comment.id_comment
    ) as like_count,
    exists (
      select 1
      from public.forum_comment_like as own_like
      where own_like.id_comment = comment.id_comment
        and own_like.id_user = v_user_id
    ) as is_liked
  from public.forum_comment as comment
  join public.user_account as profile
    on profile.id_user = comment.id_author_user
  where comment.id_post = p_post_id
    and (comment.status is null or comment.status = 'active')
    and (
      p_before_created_at is null
      or (comment.created_at, comment.id_comment)
        < (p_before_created_at, p_before_comment_id)
    )
  order by comment.created_at desc, comment.id_comment desc
  limit v_limit;
end;
$$;

revoke all on function public.forum_feed_page(
  text,
  integer,
  timestamp with time zone,
  uuid
) from public, anon;
grant execute on function public.forum_feed_page(
  text,
  integer,
  timestamp with time zone,
  uuid
) to authenticated;

revoke all on function public.forum_comments_page(
  uuid,
  integer,
  timestamp with time zone,
  uuid
) from public, anon;
grant execute on function public.forum_comments_page(
  uuid,
  integer,
  timestamp with time zone,
  uuid
) to authenticated;
