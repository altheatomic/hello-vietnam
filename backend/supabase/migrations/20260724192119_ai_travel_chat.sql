create table public.ai_chat_conversation (
  id_conversation uuid primary key default gen_random_uuid(),
  id_user uuid not null
    references public.user_account (id_user) on delete cascade,
  title text not null default 'New conversation',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint ai_chat_conversation_title_length
    check (char_length(title) between 1 and 120)
);

create table public.ai_chat_message (
  id_message uuid primary key default gen_random_uuid(),
  id_conversation uuid not null
    references public.ai_chat_conversation (id_conversation) on delete cascade,
  role text not null,
  content text not null,
  action_key text null,
  action_payload jsonb null,
  request_id uuid null,
  created_at timestamp with time zone not null default now(),
  constraint ai_chat_message_role_check
    check (role in ('user', 'assistant')),
  constraint ai_chat_message_content_length
    check (char_length(content) between 1 and 2000),
  constraint ai_chat_message_action_key_check
    check (
      action_key is null
      or action_key in (
        'trip_planner',
        'translate',
        'explore',
        'recommend',
        'forum',
        'wishlist',
        'ai_recognition',
        'loyalty',
        'popular_apps',
        'notifications',
        'profile',
        'send_report',
        'upgrade_account'
      )
    )
);

create index idx_ai_chat_conversation_user_updated
on public.ai_chat_conversation (
  id_user,
  updated_at desc,
  id_conversation desc
);

create index idx_ai_chat_message_conversation_created
on public.ai_chat_message (
  id_conversation,
  created_at,
  id_message
);

create unique index uq_ai_chat_message_request_role
on public.ai_chat_message (
  id_conversation,
  request_id,
  role
)
where request_id is not null;

alter table public.ai_chat_conversation enable row level security;
alter table public.ai_chat_message enable row level security;

create policy "Users can read own AI chat conversations"
on public.ai_chat_conversation
for select
to authenticated
using ((select auth.uid()) = id_user);

create policy "Users can delete own AI chat conversations"
on public.ai_chat_conversation
for delete
to authenticated
using ((select auth.uid()) = id_user);

create policy "Users can read own AI chat messages"
on public.ai_chat_message
for select
to authenticated
using (
  exists (
    select 1
    from public.ai_chat_conversation conversation
    where conversation.id_conversation =
      ai_chat_message.id_conversation
      and conversation.id_user = (select auth.uid())
  )
);

grant select, delete on public.ai_chat_conversation to authenticated;
grant select on public.ai_chat_message to authenticated;
grant all on public.ai_chat_conversation to service_role;
grant all on public.ai_chat_message to service_role;

alter table public.ai_usage_log
drop constraint if exists ai_usage_log_feature_check;

alter table public.ai_usage_log
add constraint ai_usage_log_feature_check
check (
  feature in (
    'translate',
    'phrase_practice',
    'report_classify',
    'forum_moderation',
    'admin_content',
    'recommendation',
    'generic',
    'ai_chat'
  )
);

create or replace function public.commit_ai_chat_exchange(
  p_id_user uuid,
  p_id_conversation uuid,
  p_request_id uuid,
  p_user_content text,
  p_assistant_content text,
  p_action_key text,
  p_action_payload jsonb,
  p_model text,
  p_input_tokens integer,
  p_output_tokens integer,
  p_estimated_cost numeric
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_owner uuid;
  v_result jsonb;
begin
  if p_id_user is null
     or p_id_conversation is null
     or p_request_id is null then
    raise exception using
      errcode = '22023',
      message = 'AI_CHAT_INVALID_REQUEST';
  end if;

  if nullif(btrim(p_user_content), '') is null
     or nullif(btrim(p_assistant_content), '') is null then
    raise exception using
      errcode = '22023',
      message = 'AI_CHAT_CONTENT_REQUIRED';
  end if;

  if char_length(btrim(p_user_content)) > 2000
     or char_length(btrim(p_assistant_content)) > 2000 then
    raise exception using
      errcode = '22023',
      message = 'AI_CHAT_CONTENT_TOO_LONG';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      p_id_conversation::text || ':' || p_request_id::text,
      0
    )
  );

  select id_user
  into v_owner
  from public.ai_chat_conversation
  where id_conversation = p_id_conversation;

  if v_owner is null then
    insert into public.ai_chat_conversation (
      id_conversation,
      id_user,
      title
    )
    values (
      p_id_conversation,
      p_id_user,
      left(btrim(p_user_content), 60)
    );
  elsif v_owner <> p_id_user then
    raise exception using
      errcode = '42501',
      message = 'AI_CHAT_CONVERSATION_FORBIDDEN';
  end if;

  select jsonb_build_object(
    'conversation_id',
    p_id_conversation,
    'messages',
    coalesce(
      jsonb_agg(to_jsonb(message) order by message.created_at, message.id_message),
      '[]'::jsonb
    )
  )
  into v_result
  from public.ai_chat_message message
  where message.id_conversation = p_id_conversation
    and message.request_id = p_request_id;

  if jsonb_array_length(v_result -> 'messages') = 2 then
    return v_result;
  end if;

  insert into public.ai_chat_message (
    id_conversation,
    role,
    content,
    request_id
  )
  values (
    p_id_conversation,
    'user',
    btrim(p_user_content),
    p_request_id
  );

  insert into public.ai_chat_message (
    id_conversation,
    role,
    content,
    action_key,
    action_payload,
    request_id
  )
  values (
    p_id_conversation,
    'assistant',
    btrim(p_assistant_content),
    p_action_key,
    p_action_payload,
    p_request_id
  );

  update public.ai_chat_conversation
  set title = case
        when title = 'New conversation'
          then left(btrim(p_user_content), 60)
        else title
      end,
      updated_at = now()
  where id_conversation = p_id_conversation;

  insert into public.ai_usage_log (
    id_user,
    provider,
    feature,
    model,
    input_tokens,
    output_tokens,
    estimated_cost,
    status
  )
  values (
    p_id_user,
    'deepseek',
    'ai_chat',
    p_model,
    p_input_tokens,
    p_output_tokens,
    p_estimated_cost,
    'success'
  );

  select jsonb_build_object(
    'conversation_id',
    p_id_conversation,
    'messages',
    jsonb_agg(
      to_jsonb(message)
      order by message.created_at, message.id_message
    )
  )
  into v_result
  from public.ai_chat_message message
  where message.id_conversation = p_id_conversation
    and message.request_id = p_request_id;

  return v_result;
end;
$$;

revoke all on function public.commit_ai_chat_exchange(
  uuid,
  uuid,
  uuid,
  text,
  text,
  text,
  jsonb,
  text,
  integer,
  integer,
  numeric
)
from public, anon, authenticated;

grant execute on function public.commit_ai_chat_exchange(
  uuid,
  uuid,
  uuid,
  text,
  text,
  text,
  jsonb,
  text,
  integer,
  integer,
  numeric
)
to service_role;
