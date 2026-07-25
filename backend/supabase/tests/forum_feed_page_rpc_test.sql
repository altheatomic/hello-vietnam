begin;

create extension if not exists pgtap with schema extensions;

select plan(13);

select has_function(
  'public',
  'forum_feed_page',
  array['text', 'integer', 'timestamp with time zone', 'uuid']
);
select has_function(
  'public',
  'forum_comments_page',
  array['uuid', 'integer', 'timestamp with time zone', 'uuid']
);
select has_index(
  'public',
  'forum_post',
  'forum_post_active_created_id_idx'
);
select has_index(
  'public',
  'forum_comment',
  'forum_comment_active_post_created_id_idx'
);

insert into public.user_account (id_user, username, full_name, avatar)
values
  (
    '81000000-0000-4000-8000-000000000001',
    'forum-page-reader',
    'Forum Page Reader',
    'avatars/reader.jpg'
  ),
  (
    '81000000-0000-4000-8000-000000000002',
    'forum-page-author',
    'Forum Page Author',
    'avatars/author.jpg'
  ),
  (
    '81000000-0000-4000-8000-000000000003',
    'forum-page-blocked',
    'Forum Page Blocked',
    null
  );

insert into public.forum_user_follow (follower_user_id, following_user_id)
values
  (
    '81000000-0000-4000-8000-000000000001',
    '81000000-0000-4000-8000-000000000002'
  ),
  (
    '81000000-0000-4000-8000-000000000001',
    '81000000-0000-4000-8000-000000000003'
  );

insert into public.forum_user_block (blocker_user_id, blocked_user_id)
values (
  '81000000-0000-4000-8000-000000000001',
  '81000000-0000-4000-8000-000000000003'
);

insert into public.forum_post (
  id_post,
  id_author_user,
  content,
  created_at,
  status
)
values
  (
    '82000000-0000-4000-8000-000000000001',
    '81000000-0000-4000-8000-000000000002',
    'Oldest visible post',
    '2026-07-25 01:00:00+00',
    'active'
  ),
  (
    '82000000-0000-4000-8000-000000000002',
    '81000000-0000-4000-8000-000000000002',
    'First post at shared time',
    '2026-07-25 02:00:00+00',
    'active'
  ),
  (
    '82000000-0000-4000-8000-000000000003',
    '81000000-0000-4000-8000-000000000002',
    'Second post at shared time',
    '2026-07-25 02:00:00+00',
    'active'
  ),
  (
    '82000000-0000-4000-8000-000000000004',
    '81000000-0000-4000-8000-000000000003',
    'Blocked post',
    '2026-07-25 03:00:00+00',
    'active'
  );

insert into public.forum_post_media (id_post, url, position)
values
  (
    '82000000-0000-4000-8000-000000000003',
    'https://cdn.example.com/forum/second.jpg',
    1
  ),
  (
    '82000000-0000-4000-8000-000000000003',
    'https://cdn.example.com/forum/first.jpg',
    0
  );

insert into public.forum_post_like (id_post, id_user)
values (
  '82000000-0000-4000-8000-000000000003',
  '81000000-0000-4000-8000-000000000001'
);

insert into public.forum_post_bookmark (id_post, id_user)
values (
  '82000000-0000-4000-8000-000000000003',
  '81000000-0000-4000-8000-000000000001'
);

insert into public.forum_comment (
  id_comment,
  id_post,
  id_author_user,
  content,
  created_at,
  status
)
values
  (
    '83000000-0000-4000-8000-000000000001',
    '82000000-0000-4000-8000-000000000003',
    '81000000-0000-4000-8000-000000000002',
    'Older comment',
    '2026-07-25 04:00:00+00',
    'active'
  ),
  (
    '83000000-0000-4000-8000-000000000002',
    '82000000-0000-4000-8000-000000000003',
    '81000000-0000-4000-8000-000000000002',
    'First comment at shared time',
    '2026-07-25 05:00:00+00',
    'active'
  ),
  (
    '83000000-0000-4000-8000-000000000003',
    '82000000-0000-4000-8000-000000000003',
    '81000000-0000-4000-8000-000000000002',
    'Second comment at shared time',
    '2026-07-25 05:00:00+00',
    'active'
  );

insert into public.forum_comment_like (id_comment, id_user)
values (
  '83000000-0000-4000-8000-000000000003',
  '81000000-0000-4000-8000-000000000001'
);

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"81000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is(
  (
    select array_agg(page.id_post order by page.created_at desc, page.id_post desc)
    from public.forum_feed_page('for_you', 2, null, null) as page
  ),
  array[
    '82000000-0000-4000-8000-000000000003'::uuid,
    '82000000-0000-4000-8000-000000000002'::uuid
  ],
  'feed uses the UUID tie-breaker for equal timestamps'
);

select is(
  (
    select array_agg(page.id_post order by page.created_at desc, page.id_post desc)
    from public.forum_feed_page(
      'for_you',
      2,
      '2026-07-25 02:00:00+00',
      '82000000-0000-4000-8000-000000000002'
    ) as page
  ),
  array['82000000-0000-4000-8000-000000000001'::uuid],
  'the next page neither duplicates nor skips a post'
);

select is(
  (
    select count(*)
    from public.forum_feed_page('for_you', 20, null, null) as page
    where page.id_author_user = '81000000-0000-4000-8000-000000000003'
  ),
  0::bigint,
  'blocked authors are excluded'
);

select is(
  (
    select count(*)
    from public.forum_feed_page('following', 20, null, null)
  ),
  3::bigint,
  'following feed only returns visible posts from followed authors'
);

select is(
  (
    select page.image_urls
    from public.forum_feed_page('for_you', 20, null, null) as page
    where page.id_post = '82000000-0000-4000-8000-000000000003'
  ),
  array[
    'https://cdn.example.com/forum/first.jpg',
    'https://cdn.example.com/forum/second.jpg'
  ],
  'media URLs retain their configured position'
);

select ok(
  (
    select
      page.like_count = 1
      and page.comment_count = 3
      and page.is_liked
      and page.is_bookmarked
      and page.is_following
    from public.forum_feed_page('for_you', 20, null, null) as page
    where page.id_post = '82000000-0000-4000-8000-000000000003'
  ),
  'feed returns aggregate and current-user interaction state'
);

select is(
  (
    select array_agg(
      page.id_comment order by page.created_at desc, page.id_comment desc
    )
    from public.forum_comments_page(
      '82000000-0000-4000-8000-000000000003',
      2,
      null,
      null
    ) as page
  ),
  array[
    '83000000-0000-4000-8000-000000000003'::uuid,
    '83000000-0000-4000-8000-000000000002'::uuid
  ],
  'comments use the UUID tie-breaker for equal timestamps'
);

select is(
  (
    select array_agg(
      page.id_comment order by page.created_at desc, page.id_comment desc
    )
    from public.forum_comments_page(
      '82000000-0000-4000-8000-000000000003',
      2,
      '2026-07-25 05:00:00+00',
      '83000000-0000-4000-8000-000000000002'
    ) as page
  ),
  array['83000000-0000-4000-8000-000000000001'::uuid],
  'comment pagination neither duplicates nor skips a row'
);

select ok(
  (
    select page.like_count = 1 and page.is_liked
    from public.forum_comments_page(
      '82000000-0000-4000-8000-000000000003',
      20,
      null,
      null
    ) as page
    where page.id_comment = '83000000-0000-4000-8000-000000000003'
  ),
  'comment page returns like state for the current user'
);

select * from finish();
rollback;
