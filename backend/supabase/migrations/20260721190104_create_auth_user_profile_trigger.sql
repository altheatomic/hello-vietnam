create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_account (id_user, full_name, username)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      split_part(coalesce(new.email, ''), '@', 1)
    ),
    new.email
  )
  on conflict (id_user) do update
    set full_name = coalesce(nullif(excluded.full_name, ''), user_account.full_name),
        username = coalesce(excluded.username, user_account.username);

  insert into public.user_contact (id_user, email)
  values (new.id, new.email)
  on conflict (id_user) do update
    set email = excluded.email;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_auth_user();;
