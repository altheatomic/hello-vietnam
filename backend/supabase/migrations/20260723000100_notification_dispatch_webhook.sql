create extension if not exists pg_net with schema extensions;

create or replace function public.dispatch_notification_webhook()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_dispatch_secret text;
begin
    select decrypted_secret
    into v_dispatch_secret
    from vault.decrypted_secrets
    where name = 'notification_dispatch_secret'
    order by created_at desc
    limit 1;

    if nullif(v_dispatch_secret, '') is null then
        raise warning
            'notification_dispatch_secret is missing from Vault; push dispatch skipped for %',
            new.id_notification;
        return new;
    end if;

    perform net.http_post(
        url := 'https://ziouozppetvvdrzgojcx.supabase.co/functions/v1/notification-dispatch',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-notification-secret', v_dispatch_secret
        ),
        body := jsonb_build_object(
            'type', 'INSERT',
            'table', 'notification',
            'schema', 'public',
            'record', to_jsonb(new),
            'old_record', null
        ),
        timeout_milliseconds := 10000
    );

    return new;
exception
    when others then
        raise warning
            'push dispatch enqueue failed for %: %',
            new.id_notification,
            sqlerrm;
        return new;
end;
$$;

revoke all on function public.dispatch_notification_webhook()
from public, anon, authenticated;

drop trigger if exists trg_dispatch_notification_webhook
on public.notification;

create trigger trg_dispatch_notification_webhook
after insert on public.notification
for each row
when (new.is_push and new.status = 'queued')
execute function public.dispatch_notification_webhook();
