create or replace function public.ensure_ai_chat_message_order()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_created_at timestamp with time zone;
begin
  if new.role = 'assistant' and new.request_id is not null then
    select message.created_at
    into v_user_created_at
    from public.ai_chat_message message
    where message.id_conversation = new.id_conversation
      and message.request_id = new.request_id
      and message.role = 'user'
    order by message.created_at, message.id_message
    limit 1;

    if v_user_created_at is not null
       and new.created_at <= v_user_created_at then
      new.created_at := v_user_created_at + interval '1 microsecond';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists ensure_ai_chat_message_order
on public.ai_chat_message;

create trigger ensure_ai_chat_message_order
before insert on public.ai_chat_message
for each row
execute function public.ensure_ai_chat_message_order();
