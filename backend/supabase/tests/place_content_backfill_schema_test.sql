begin;

select plan(6);

select has_column(
  'public',
  'place_translation',
  'detailed_description',
  'place_translation exposes localized detailed descriptions'
);

select col_type_is(
  'public',
  'place_translation',
  'detailed_description',
  'text',
  'localized detailed descriptions use text'
);

select ok(
  (
    select is_nullable = 'YES'
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'place_translation'
      and column_name = 'detailed_description'
  ),
  'localized detailed descriptions are nullable'
);

select has_column(
  'public',
  'place_localized_en',
  'detailed_description',
  'English localized view exposes detailed descriptions'
);

select ok(
  exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'place_localized_en'
      and c.reloptions @> array['security_invoker=true']
  ),
  'English localized view runs with security_invoker'
);

select is(
  (select count(*) from public.place_localized_en),
  (select count(*) from public.place),
  'English localized view retains one row per place'
);

select * from finish();

rollback;
