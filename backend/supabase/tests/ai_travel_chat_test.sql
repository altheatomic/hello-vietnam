begin;

create extension if not exists pgtap with schema extensions;

select plan(20);

select has_table('public', 'ai_chat_conversation');
select has_table('public', 'ai_chat_message');
select col_is_pk('public', 'ai_chat_conversation', 'id_conversation');
select col_is_pk('public', 'ai_chat_message', 'id_message');
select fk_ok(
  'public',
  'ai_chat_conversation',
  'id_user',
  'public',
  'user_account',
  'id_user'
);
select fk_ok(
  'public',
  'ai_chat_message',
  'id_conversation',
  'public',
  'ai_chat_conversation',
  'id_conversation'
);
select has_index(
  'public',
  'ai_chat_conversation',
  'idx_ai_chat_conversation_user_updated'
);
select has_index(
  'public',
  'ai_chat_message',
  'idx_ai_chat_message_conversation_created'
);
select has_function(
  'public',
  'commit_ai_chat_exchange',
  array[
    'uuid',
    'uuid',
    'uuid',
    'text',
    'text',
    'text',
    'jsonb',
    'text',
    'integer',
    'integer',
    'numeric'
  ]
);

select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.ai_chat_conversation'::regclass
  ),
  'conversation RLS is enabled'
);
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.ai_chat_message'::regclass
  ),
  'message RLS is enabled'
);
select lives_ok(
  $$insert into public.ai_usage_log (
      id_user,
      provider,
      feature,
      model,
      status
    ) values (
      null,
      'deepseek',
      'ai_chat',
      'deepseek-chat',
      'success'
    )$$,
  'ai_usage_log accepts ai_chat feature'
);

insert into public.user_account (id_user, username, full_name)
values (
  '71000000-0000-4000-8000-000000000001',
  'ai-chat-owner',
  'AI Chat Owner'
);

select lives_ok(
  $$select public.commit_ai_chat_exchange(
      '71000000-0000-4000-8000-000000000001',
      '72000000-0000-4000-8000-000000000001',
      '73000000-0000-4000-8000-000000000001',
      'Plan a day in Hue',
      'Start with the Imperial City.',
      'tripPlanner',
      '{"route":"/trip-planner"}'::jsonb,
      'deepseek-chat',
      20,
      30,
      0.0001
    )$$,
  'atomic chat exchange commits successfully'
);
select is(
  (
    select count(*)
    from public.ai_chat_message
    where id_conversation = '72000000-0000-4000-8000-000000000001'
  ),
  2::bigint,
  'atomic exchange creates exactly two messages'
);
select is(
  (
    select count(*)
    from public.ai_usage_log
    where id_user = '71000000-0000-4000-8000-000000000001'
      and feature = 'ai_chat'
  ),
  1::bigint,
  'atomic exchange creates exactly one usage record'
);

select lives_ok(
  $$select public.commit_ai_chat_exchange(
      '71000000-0000-4000-8000-000000000001',
      '72000000-0000-4000-8000-000000000001',
      '73000000-0000-4000-8000-000000000001',
      'Plan a day in Hue',
      'Start with the Imperial City.',
      'tripPlanner',
      '{"route":"/trip-planner"}'::jsonb,
      'deepseek-chat',
      20,
      30,
      0.0001
    )$$,
  'retrying the same request succeeds idempotently'
);
select is(
  (
    select count(*)
    from public.ai_chat_message
    where id_conversation = '72000000-0000-4000-8000-000000000001'
  ),
  2::bigint,
  'retry does not duplicate messages'
);
select is(
  (
    select count(*)
    from public.ai_usage_log
    where id_user = '71000000-0000-4000-8000-000000000001'
      and feature = 'ai_chat'
  ),
  1::bigint,
  'retry does not duplicate usage'
);

delete from public.ai_chat_conversation
where id_conversation = '72000000-0000-4000-8000-000000000001';

select is(
  (
    select count(*)
    from public.ai_chat_message
    where id_conversation = '72000000-0000-4000-8000-000000000001'
  ),
  0::bigint,
  'deleting a conversation cascades to its messages'
);

select throws_ok(
  $$select public.commit_ai_chat_exchange(
      '71000000-0000-4000-8000-000000000001',
      '72000000-0000-4000-8000-000000000002',
      '73000000-0000-4000-8000-000000000002',
      repeat('x', 2001),
      'No response',
      null,
      '{}'::jsonb,
      'deepseek-chat',
      1,
      1,
      0
    )$$,
  '22023',
  'AI_CHAT_CONTENT_TOO_LONG',
  'oversized user content is rejected'
);

select * from finish();
rollback;
