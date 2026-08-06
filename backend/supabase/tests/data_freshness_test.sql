begin;

create extension if not exists pgtap with schema extensions;

select plan(14);

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
select has_column('public', 'activity', 'status');
select has_column('public', 'culture', 'status');
select has_column('public', 'local_products', 'status');
select has_column('public', 'food', 'status');

select * from finish();

rollback;
