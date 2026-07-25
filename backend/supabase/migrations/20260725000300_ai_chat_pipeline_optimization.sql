create or replace function public.prepare_ai_chat_request(
  p_id_user uuid,
  p_id_conversation uuid,
  p_request_id uuid,
  p_allow_new_conversation boolean,
  p_history_limit integer default 12
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner uuid;
  v_conversation_exists boolean := false;
  v_daily_limit integer;
  v_used integer;
  v_remaining integer;
  v_messages jsonb;
  v_history jsonb;
  v_history_limit integer := least(greatest(coalesce(p_history_limit, 12), 0), 20);
  v_day_start timestamp with time zone :=
    date_trunc('day', now() at time zone 'UTC') at time zone 'UTC';
begin
  if p_id_user is null
     or p_id_conversation is null
     or p_request_id is null then
    raise exception using
      errcode = '22023',
      message = 'AI_CHAT_INVALID_REQUEST';
  end if;

  if not exists (
    select 1
    from public.premium_subscription subscription
    where subscription.id_user = p_id_user
      and subscription.status = 'active'
      and subscription.end_date > now()
  ) then
    return jsonb_build_object('status', 'premium_required');
  end if;

  select conversation.id_user
  into v_owner
  from public.ai_chat_conversation conversation
  where conversation.id_conversation = p_id_conversation;

  v_conversation_exists := found;

  if v_conversation_exists and v_owner <> p_id_user then
    return jsonb_build_object('status', 'conversation_not_found');
  end if;

  if not v_conversation_exists and not p_allow_new_conversation then
    return jsonb_build_object('status', 'conversation_not_found');
  end if;

  select coalesce(
    (
      select quota.daily_limit
      from public.ai_user_quota quota
      where quota.id_user = p_id_user
        and quota.feature = 'ai_chat'
    ),
    100
  )
  into v_daily_limit;

  select count(*)::integer
  into v_used
  from public.ai_usage_log usage
  where usage.id_user = p_id_user
    and usage.provider = 'deepseek'
    and usage.feature = 'ai_chat'
    and usage.status = 'success'
    and usage.created_at >= v_day_start;

  v_remaining := greatest(v_daily_limit - v_used, 0);

  if v_conversation_exists then
    select coalesce(
      jsonb_agg(
        to_jsonb(message)
        order by message.created_at, message.id_message
      ),
      '[]'::jsonb
    )
    into v_messages
    from public.ai_chat_message message
    where message.id_conversation = p_id_conversation
      and message.request_id = p_request_id;

    if jsonb_array_length(v_messages) = 2 then
      return jsonb_build_object(
        'status', 'committed',
        'conversation_id', p_id_conversation,
        'messages', v_messages,
        'remaining', v_remaining
      );
    end if;
  end if;

  if v_remaining <= 0 then
    return jsonb_build_object(
      'status', 'quota_reached',
      'remaining', 0
    );
  end if;

  if v_conversation_exists and v_history_limit > 0 then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'role', recent.role,
          'content', recent.content
        )
        order by recent.created_at, recent.id_message
      ),
      '[]'::jsonb
    )
    into v_history
    from (
      select
        message.role,
        message.content,
        message.created_at,
        message.id_message
      from public.ai_chat_message message
      where message.id_conversation = p_id_conversation
      order by message.created_at desc, message.id_message desc
      limit v_history_limit
    ) recent;
  else
    v_history := '[]'::jsonb;
  end if;

  return jsonb_build_object(
    'status', 'ready',
    'history', v_history,
    'remaining', v_remaining
  );
end;
$$;

revoke all on function public.prepare_ai_chat_request(
  uuid,
  uuid,
  uuid,
  boolean,
  integer
)
from public, anon, authenticated;

grant execute on function public.prepare_ai_chat_request(
  uuid,
  uuid,
  uuid,
  boolean,
  integer
)
to service_role;

create or replace function public.list_ai_chat_messages(
  p_id_user uuid,
  p_id_conversation uuid,
  p_before_created_at timestamp with time zone default null,
  p_before_id uuid default null,
  p_limit integer default 50
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 50);
  v_items jsonb;
  v_selected_count integer;
begin
  if not exists (
    select 1
    from public.ai_chat_conversation conversation
    where conversation.id_conversation = p_id_conversation
      and conversation.id_user = p_id_user
  ) then
    return jsonb_build_object(
      'status', 'conversation_not_found',
      'items', '[]'::jsonb,
      'has_more', false
    );
  end if;

  with selected as (
    select
      message.id_message,
      message.id_conversation,
      message.role,
      message.content,
      message.action_key,
      message.action_payload,
      message.request_id,
      message.created_at
    from public.ai_chat_message message
    where message.id_conversation = p_id_conversation
      and (
        p_before_created_at is null
        or p_before_id is null
        or (message.created_at, message.id_message)
          < (p_before_created_at, p_before_id)
      )
    order by message.created_at desc, message.id_message desc
    limit v_limit + 1
  ),
  included as (
    select *
    from selected
    order by created_at desc, id_message desc
    limit v_limit
  )
  select
    coalesce(
      (
        select jsonb_agg(
          to_jsonb(item)
          order by item.created_at, item.id_message
        )
        from included item
      ),
      '[]'::jsonb
    ),
    (select count(*)::integer from selected)
  into v_items, v_selected_count;

  return jsonb_build_object(
    'status', 'ready',
    'items', v_items,
    'has_more', v_selected_count > v_limit
  );
end;
$$;

revoke all on function public.list_ai_chat_messages(
  uuid,
  uuid,
  timestamp with time zone,
  uuid,
  integer
)
from public, anon, authenticated;

grant execute on function public.list_ai_chat_messages(
  uuid,
  uuid,
  timestamp with time zone,
  uuid,
  integer
)
to service_role;

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
  v_conversation_exists boolean := false;
  v_result jsonb;
  v_daily_limit integer;
  v_used integer;
  v_remaining integer;
  v_day_start timestamp with time zone :=
    date_trunc('day', now() at time zone 'UTC') at time zone 'UTC';
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
    hashtextextended(p_id_conversation::text, 0)
  );
  perform pg_advisory_xact_lock(
    hashtextextended(
      p_id_conversation::text || ':' || p_request_id::text,
      0
    )
  );

  select conversation.id_user
  into v_owner
  from public.ai_chat_conversation conversation
  where conversation.id_conversation = p_id_conversation;

  v_conversation_exists := found;

  if v_conversation_exists and v_owner <> p_id_user then
    raise exception using
      errcode = '42501',
      message = 'AI_CHAT_CONVERSATION_FORBIDDEN';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      p_id_user::text || ':' ||
        (now() at time zone 'UTC')::date::text || ':ai_chat',
      0
    )
  );

  select coalesce(
    (
      select quota.daily_limit
      from public.ai_user_quota quota
      where quota.id_user = p_id_user
        and quota.feature = 'ai_chat'
    ),
    100
  )
  into v_daily_limit;

  select count(*)::integer
  into v_used
  from public.ai_usage_log usage
  where usage.id_user = p_id_user
    and usage.provider = 'deepseek'
    and usage.feature = 'ai_chat'
    and usage.status = 'success'
    and usage.created_at >= v_day_start;

  v_remaining := greatest(v_daily_limit - v_used, 0);

  if v_conversation_exists then
    select jsonb_build_object(
      'conversation_id',
      p_id_conversation,
      'messages',
      coalesce(
        jsonb_agg(
          to_jsonb(message)
          order by message.created_at, message.id_message
        ),
        '[]'::jsonb
      ),
      'remaining',
      v_remaining
    )
    into v_result
    from public.ai_chat_message message
    where message.id_conversation = p_id_conversation
      and message.request_id = p_request_id;

    if jsonb_array_length(v_result -> 'messages') = 2 then
      return v_result;
    end if;
  end if;

  if v_remaining <= 0 then
    raise exception using
      errcode = 'P0001',
      message = 'AI_CHAT_DAILY_LIMIT_REACHED';
  end if;

  if not v_conversation_exists then
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
    ),
    'remaining',
    greatest(v_remaining - 1, 0)
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
