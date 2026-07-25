create or replace function public.delete_owned_forum_media(
    p_media_id uuid,
    p_user_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    deleted_count integer;
begin
    update public.forum_post_media media
    set url = 'deleted-media://placeholder'
    where media.id_media = p_media_id
      and media.url <> 'deleted-media://placeholder'
      and exists (
          select 1
          from public.forum_post post
          where post.id_post = media.id_post
            and post.id_author_user = p_user_id
      );

    get diagnostics deleted_count = row_count;
    return deleted_count = 1;
end;
$$;

revoke all on function public.delete_owned_forum_media(uuid, uuid) from public;
grant execute on function public.delete_owned_forum_media(uuid, uuid) to service_role;
