begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select has_column('public', 'place_translation', 'detailed_description');
select col_type_is('public', 'place_translation', 'detailed_description', 'text');
select col_is_null('public', 'place_translation', 'detailed_description');
select has_column('public', 'place_localized_en', 'detailed_description');
select ok(
  coalesce((select reloptions @> array['security_invoker=true']
              from pg_class
             where oid = 'public.place_localized_en'::regclass), false),
  'English place view uses security_invoker'
);
select results_eq(
  $$ select count(*)::bigint from public.place_localized_en $$,
  $$ select count(*)::bigint from public.place $$,
  'view remains one row per place'
);

select * from finish();
rollback;
