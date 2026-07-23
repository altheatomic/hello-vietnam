alter table public.forum_post enable row level security;
alter table public.forum_post_media enable row level security;

drop policy if exists "Users can update own forum posts" on public.forum_post;
create policy "Users can update own forum posts"
on public.forum_post for update
using (auth.uid() = id_author_user)
with check (auth.uid() = id_author_user);

drop policy if exists "Users can delete own forum posts" on public.forum_post;
create policy "Users can delete own forum posts"
on public.forum_post for delete
using (auth.uid() = id_author_user);

drop policy if exists "Users can update media on own posts"
on public.forum_post_media;
create policy "Users can update media on own posts"
on public.forum_post_media for update
using (
  exists (
    select 1
    from public.forum_post
    where forum_post.id_post = forum_post_media.id_post
      and forum_post.id_author_user = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.forum_post
    where forum_post.id_post = forum_post_media.id_post
      and forum_post.id_author_user = auth.uid()
  )
);

drop policy if exists "Users can delete media from own posts"
on public.forum_post_media;
create policy "Users can delete media from own posts"
on public.forum_post_media for delete
using (
  exists (
    select 1
    from public.forum_post
    where forum_post.id_post = forum_post_media.id_post
      and forum_post.id_author_user = auth.uid()
  )
);
