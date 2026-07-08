do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'user_interest_tag_source_check'
      and conrelid = 'public.user_interest_tag'::regclass
  ) then
    alter table public.user_interest_tag
      drop constraint user_interest_tag_source_check;
  end if;
end
$$;

alter table public.user_interest_tag
  add constraint user_interest_tag_source_check
  check (
    source = any (
      array[
        'onboarding'::text,
        'system'::text,
        'behavior'::text,
        'manual'::text,
        'mixed'::text
      ]
    )
  );
