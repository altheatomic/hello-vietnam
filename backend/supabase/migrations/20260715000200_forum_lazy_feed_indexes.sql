create index if not exists forum_post_active_created_at_idx
on public.forum_post(created_at desc)
where status is null or status = 'active';

create index if not exists forum_post_active_author_created_at_idx
on public.forum_post(id_author_user, created_at desc)
where status is null or status = 'active';

create index if not exists forum_user_follow_follower_following_idx
on public.forum_user_follow(follower_user_id, following_user_id);
