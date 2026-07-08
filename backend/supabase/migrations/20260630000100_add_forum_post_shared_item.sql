alter table public.forum_post
add column if not exists shared_item jsonb null;

comment on column public.forum_post.shared_item is
'Metadata snapshot and reference for an Explore item shared into a forum post';
