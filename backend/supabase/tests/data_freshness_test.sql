begin;

create extension if not exists pgtap with schema extensions;

select plan(18);

select has_table('public', 'content_freshness');
select has_table('public', 'content_change_proposal');
select has_table('public', 'content_report');
select has_table('public', 'content_update_run');
select col_is_pk('public', 'content_freshness', 'id');
select has_function(
  'public',
  'claim_due_content_freshness',
  array['uuid', 'integer']
);
select has_function(
  'public',
  'record_content_freshness_result',
  array['uuid', 'jsonb']
);
select has_function(
  'public',
  'review_content_change_proposal',
  array['uuid', 'text', 'jsonb']
);
select has_function(
  'public',
  'submit_content_report',
  array['text', 'uuid', 'text', 'text']
);
select has_function(
  'public',
  'request_content_freshness_check',
  array['text', 'uuid']
);
select results_eq(
  $$ select public.content_freshness_source_is_supported(source_type)
     from (values ('osm'::text), ('wikipedia'::text), ('wiki'::text), ('legacy_import'::text))
       as sources(source_type) $$,
  $$ values (true), (true), (true), (false) $$,
  'freshness checker only claims configured source adapters'
);
select results_eq(
  $$ select table_name, id_column
     from public.content_freshness_table_config('place') $$,
  $$ values ('place'::text, 'id_place'::text) $$,
  'content freshness table config returns the declared columns'
);
select has_column('public', 'activity', 'status');
select has_column('public', 'culture', 'status');
select has_column('public', 'local_products', 'status');
select has_column('public', 'food', 'status');
select is(
  (
    select schedule
    from cron.job
    where jobname = 'data-freshness-daily'
  ),
  '15 19 * * *',
  'data freshness runs at 19:15 UTC (02:15 Vietnam time)'
);
select like(
  (
    select command
    from cron.job
    where jobname = 'data-freshness-daily'
  ),
  '%invoke_data_freshness_cron()%',
  'data freshness cron keeps the existing invocation command'
);

select * from finish();

rollback;
