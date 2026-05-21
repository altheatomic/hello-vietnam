create table if not exists forum_post_media (
    id_media uuid primary key default uuid_generate_v4(),
    id_post uuid not null references forum_post(id_post) on delete cascade,
    url text not null,
    position int default 0,
    created_at timestamp with time zone default now()
);

create table if not exists forum_post_like (
    id_post uuid not null references forum_post(id_post) on delete cascade,
    id_user uuid not null references user_account(id_user) on delete cascade,
    created_at timestamp with time zone default now(),
    primary key (id_post, id_user)
);

create table if not exists forum_comment_like (
    id_comment uuid not null references forum_comment(id_comment) on delete cascade,
    id_user uuid not null references user_account(id_user) on delete cascade,
    created_at timestamp with time zone default now(),
    primary key (id_comment, id_user)
);

create table if not exists forum_post_bookmark (
    id_post uuid not null references forum_post(id_post) on delete cascade,
    id_user uuid not null references user_account(id_user) on delete cascade,
    created_at timestamp with time zone default now(),
    primary key (id_post, id_user)
);

create table if not exists forum_user_follow (
    follower_user_id uuid not null references user_account(id_user) on delete cascade,
    following_user_id uuid not null references user_account(id_user) on delete cascade,
    created_at timestamp with time zone default now(),
    primary key (follower_user_id, following_user_id),
    constraint forum_user_follow_no_self check (follower_user_id <> following_user_id)
);

create table if not exists forum_user_block (
    blocker_user_id uuid not null references user_account(id_user) on delete cascade,
    blocked_user_id uuid not null references user_account(id_user) on delete cascade,
    created_at timestamp with time zone default now(),
    primary key (blocker_user_id, blocked_user_id),
    constraint forum_user_block_no_self check (blocker_user_id <> blocked_user_id)
);

create table if not exists forum_post_report (
    id_report uuid primary key default uuid_generate_v4(),
    id_post uuid not null references forum_post(id_post) on delete cascade,
    id_reporter_user uuid references user_account(id_user) on delete set null,
    reason text not null,
    details text,
    status text default 'pending',
    created_at timestamp with time zone default now()
);

create index if not exists forum_post_created_at_idx
    on forum_post(created_at desc);

create index if not exists forum_comment_post_created_at_idx
    on forum_comment(id_post, created_at desc);

create index if not exists forum_post_media_post_position_idx
    on forum_post_media(id_post, position);

create index if not exists forum_post_like_post_idx
    on forum_post_like(id_post);

create index if not exists forum_comment_like_comment_idx
    on forum_comment_like(id_comment);

create index if not exists forum_post_bookmark_user_idx
    on forum_post_bookmark(id_user, created_at desc);

create index if not exists forum_user_follow_following_idx
    on forum_user_follow(following_user_id);

alter table user_account enable row level security;

drop policy if exists "Forum profiles are readable" on user_account;
create policy "Forum profiles are readable"
on user_account for select
using (true);

drop policy if exists "Users can insert own account profile" on user_account;
create policy "Users can insert own account profile"
on user_account for insert
with check (auth.uid() = id_user);

drop policy if exists "Users can update own account profile" on user_account;
create policy "Users can update own account profile"
on user_account for update
using (auth.uid() = id_user)
with check (auth.uid() = id_user);

update user_account
set
    full_name = coalesce(
        nullif(user_account.full_name, ''),
        nullif(auth.users.raw_user_meta_data ->> 'full_name', ''),
        nullif(auth.users.raw_user_meta_data ->> 'name', ''),
        split_part(auth.users.email, '@', 1)
    ),
    username = coalesce(
        nullif(user_account.username, ''),
        auth.users.email
    )
from auth.users
where user_account.id_user = auth.users.id
  and (
      user_account.full_name is null
      or user_account.full_name = ''
      or user_account.username is null
      or user_account.username = ''
  );

alter table forum_post enable row level security;
alter table forum_comment enable row level security;
alter table forum_post_media enable row level security;
alter table forum_post_like enable row level security;
alter table forum_comment_like enable row level security;
alter table forum_post_bookmark enable row level security;
alter table forum_user_follow enable row level security;
alter table forum_user_block enable row level security;
alter table forum_post_report enable row level security;

drop policy if exists "Forum posts are readable" on forum_post;
create policy "Forum posts are readable"
on forum_post for select
using (status is null or status = 'active');

drop policy if exists "Users can create forum posts" on forum_post;
create policy "Users can create forum posts"
on forum_post for insert
with check (auth.uid() = id_author_user);

drop policy if exists "Forum comments are readable" on forum_comment;
create policy "Forum comments are readable"
on forum_comment for select
using (status is null or status = 'active');

drop policy if exists "Users can create forum comments" on forum_comment;
create policy "Users can create forum comments"
on forum_comment for insert
with check (auth.uid() = id_author_user);

drop policy if exists "Forum post media is readable" on forum_post_media;
create policy "Forum post media is readable"
on forum_post_media for select
using (true);

drop policy if exists "Users can add media to own posts" on forum_post_media;
create policy "Users can add media to own posts"
on forum_post_media for insert
with check (
    exists (
        select 1
        from forum_post
        where forum_post.id_post = forum_post_media.id_post
          and forum_post.id_author_user = auth.uid()
    )
);

drop policy if exists "Users can read post likes" on forum_post_like;
create policy "Users can read post likes"
on forum_post_like for select
using (true);

drop policy if exists "Users can like posts" on forum_post_like;
create policy "Users can like posts"
on forum_post_like for insert
with check (auth.uid() = id_user);

drop policy if exists "Users can update own post likes" on forum_post_like;
create policy "Users can update own post likes"
on forum_post_like for update
using (auth.uid() = id_user)
with check (auth.uid() = id_user);

drop policy if exists "Users can remove own post likes" on forum_post_like;
create policy "Users can remove own post likes"
on forum_post_like for delete
using (auth.uid() = id_user);

drop policy if exists "Users can read comment likes" on forum_comment_like;
create policy "Users can read comment likes"
on forum_comment_like for select
using (true);

drop policy if exists "Users can like comments" on forum_comment_like;
create policy "Users can like comments"
on forum_comment_like for insert
with check (auth.uid() = id_user);

drop policy if exists "Users can update own comment likes" on forum_comment_like;
create policy "Users can update own comment likes"
on forum_comment_like for update
using (auth.uid() = id_user)
with check (auth.uid() = id_user);

drop policy if exists "Users can remove own comment likes" on forum_comment_like;
create policy "Users can remove own comment likes"
on forum_comment_like for delete
using (auth.uid() = id_user);

drop policy if exists "Users can read own bookmarks" on forum_post_bookmark;
create policy "Users can read own bookmarks"
on forum_post_bookmark for select
using (auth.uid() = id_user);

drop policy if exists "Users can bookmark posts" on forum_post_bookmark;
create policy "Users can bookmark posts"
on forum_post_bookmark for insert
with check (auth.uid() = id_user);

drop policy if exists "Users can update own bookmarks" on forum_post_bookmark;
create policy "Users can update own bookmarks"
on forum_post_bookmark for update
using (auth.uid() = id_user)
with check (auth.uid() = id_user);

drop policy if exists "Users can remove own bookmarks" on forum_post_bookmark;
create policy "Users can remove own bookmarks"
on forum_post_bookmark for delete
using (auth.uid() = id_user);

drop policy if exists "Users can read follows" on forum_user_follow;
create policy "Users can read follows"
on forum_user_follow for select
using (true);

drop policy if exists "Users can follow others" on forum_user_follow;
create policy "Users can follow others"
on forum_user_follow for insert
with check (auth.uid() = follower_user_id);

drop policy if exists "Users can update own follows" on forum_user_follow;
create policy "Users can update own follows"
on forum_user_follow for update
using (auth.uid() = follower_user_id)
with check (auth.uid() = follower_user_id);

drop policy if exists "Users can unfollow others" on forum_user_follow;
create policy "Users can unfollow others"
on forum_user_follow for delete
using (auth.uid() = follower_user_id);

drop policy if exists "Users can read own blocks" on forum_user_block;
create policy "Users can read own blocks"
on forum_user_block for select
using (auth.uid() = blocker_user_id);

drop policy if exists "Users can block others" on forum_user_block;
create policy "Users can block others"
on forum_user_block for insert
with check (auth.uid() = blocker_user_id);

drop policy if exists "Users can update own blocks" on forum_user_block;
create policy "Users can update own blocks"
on forum_user_block for update
using (auth.uid() = blocker_user_id)
with check (auth.uid() = blocker_user_id);

drop policy if exists "Users can unblock others" on forum_user_block;
create policy "Users can unblock others"
on forum_user_block for delete
using (auth.uid() = blocker_user_id);

drop policy if exists "Users can read own reports" on forum_post_report;
create policy "Users can read own reports"
on forum_post_report for select
using (auth.uid() = id_reporter_user);

drop policy if exists "Users can report posts" on forum_post_report;
create policy "Users can report posts"
on forum_post_report for insert
with check (auth.uid() = id_reporter_user);

insert into storage.buckets (id, name, public)
values ('forum-media', 'forum-media', true)
on conflict (id) do update set public = true;

drop policy if exists "Forum media is publicly readable" on storage.objects;
create policy "Forum media is publicly readable"
on storage.objects for select
using (bucket_id = 'forum-media');

drop policy if exists "Users can upload forum media" on storage.objects;
create policy "Users can upload forum media"
on storage.objects for insert
with check (
    bucket_id = 'forum-media'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can update own forum media" on storage.objects;
create policy "Users can update own forum media"
on storage.objects for update
using (
    bucket_id = 'forum-media'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
    bucket_id = 'forum-media'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can delete own forum media" on storage.objects;
create policy "Users can delete own forum media"
on storage.objects for delete
using (
    bucket_id = 'forum-media'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
);
