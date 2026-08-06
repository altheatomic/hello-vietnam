create table public.payment_attempt (
    id_attempt uuid primary key default gen_random_uuid(),
    id_user uuid not null references public.user_account(id_user),
    id_subscription_plan uuid not null
        references public.subscription_plan(id_subscription_plan),
    id_voucher uuid null references public.voucher(id_voucher),
    id_voucher_wallet uuid null references public.voucher_wallet(id_wallet),
    plan_code text not null,
    plan_name text not null,
    duration_days integer not null check (duration_days > 0),
    original_amount_minor bigint not null
        check (original_amount_minor >= 0),
    discount_minor bigint not null check (discount_minor >= 0),
    amount_minor bigint not null check (amount_minor >= 0),
    voucher_code text null,
    currency text not null check (currency = 'USD'),
    stripe_session_id text unique,
    status text not null default 'pending'
        check (
            status in (
                'pending',
                'paid',
                'finalized',
                'expired',
                'failed'
            )
        ),
    failure_reason text null,
    id_payment uuid null references public.payment(id_payment),
    id_subscription uuid null
        references public.premium_subscription(id_prs),
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    finalized_at timestamp with time zone null,
    constraint payment_attempt_amounts_match
        check (original_amount_minor = discount_minor + amount_minor)
);

alter table public.payment_attempt enable row level security;

revoke all on table public.payment_attempt
from public, anon, authenticated;

grant all on table public.payment_attempt to service_role;

drop trigger if exists trg_payment_attempt_updated_at
on public.payment_attempt;

create trigger trg_payment_attempt_updated_at
before update on public.payment_attempt
for each row
execute function public.set_updated_at();

create unique index payment_provider_external_ref_uidx
on public.payment (provider, external_ref)
where external_ref is not null;

alter table public.premium_subscription
add column if not exists id_payment uuid
references public.payment(id_payment);

create unique index premium_subscription_payment_uidx
on public.premium_subscription (id_payment)
where id_payment is not null;

create unique index voucher_redemption_payment_uidx
on public.voucher_redemption (id_payment)
where id_payment is not null;

create index if not exists payment_id_user_idx
on public.payment (id_user);

create index if not exists premium_subscription_id_user_idx
on public.premium_subscription (id_user);

create or replace function public.finalize_verified_payment(
    p_attempt_id uuid,
    p_stripe_session_id text,
    p_amount_total bigint,
    p_currency text
)
returns table (
    id_payment uuid,
    id_subscription uuid,
    original_amount_minor bigint,
    discount_minor bigint,
    final_amount_minor bigint,
    voucher_code text,
    subscription_end_date timestamp with time zone
)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_attempt public.payment_attempt%rowtype;
    v_payment_id uuid;
    v_subscription_id uuid;
    v_start_at timestamp with time zone;
    v_end_at timestamp with time zone;
    v_wallet_updated boolean := false;
begin
    select attempt.*
    into v_attempt
    from public.payment_attempt as attempt
    where attempt.id_attempt = p_attempt_id
    for update;

    if not found then
        raise exception using
            errcode = 'P0001',
            message = 'PAYMENT_ATTEMPT_NOT_FOUND';
    end if;

    if v_attempt.stripe_session_id is null
       or v_attempt.stripe_session_id <> nullif(trim(p_stripe_session_id), '') then
        raise exception using
            errcode = 'P0001',
            message = 'PAYMENT_SESSION_MISMATCH';
    end if;

    if v_attempt.amount_minor <> p_amount_total then
        raise exception using
            errcode = 'P0001',
            message = 'PAYMENT_AMOUNT_MISMATCH';
    end if;

    if v_attempt.currency <> upper(trim(coalesce(p_currency, ''))) then
        raise exception using
            errcode = 'P0001',
            message = 'PAYMENT_CURRENCY_MISMATCH';
    end if;

    if v_attempt.status = 'finalized' then
        return query
        select
            v_attempt.id_payment,
            v_attempt.id_subscription,
            v_attempt.original_amount_minor,
            v_attempt.discount_minor,
            v_attempt.amount_minor,
            v_attempt.voucher_code,
            subscription.end_date
        from public.premium_subscription as subscription
        where subscription.id_prs = v_attempt.id_subscription;
        return;
    end if;

    if v_attempt.status not in ('pending', 'paid') then
        raise exception using
            errcode = 'P0001',
            message = 'PAYMENT_ATTEMPT_CLOSED';
    end if;

    insert into public.payment (
        id_user,
        id_subscription_plan,
        provider,
        method,
        amount_minor,
        currency,
        status,
        external_ref,
        confirmed_at
    )
    values (
        v_attempt.id_user,
        v_attempt.id_subscription_plan,
        'stripe',
        'card',
        v_attempt.amount_minor,
        v_attempt.currency,
        'confirmed',
        v_attempt.stripe_session_id,
        now()
    )
    returning payment.id_payment
    into v_payment_id;

    if v_attempt.id_voucher is not null
       and v_attempt.discount_minor > 0 then
        insert into public.voucher_redemption (
            id_voucher,
            id_user,
            id_payment,
            discount_minor,
            redeemed_at
        )
        values (
            v_attempt.id_voucher,
            v_attempt.id_user,
            v_payment_id,
            v_attempt.discount_minor,
            now()
        );
    end if;

    if v_attempt.id_voucher_wallet is not null then
        update public.voucher_wallet
        set
            status = 'used',
            used_at = now()
        where id_wallet = v_attempt.id_voucher_wallet
          and id_user = v_attempt.id_user
          and status = 'available';

        v_wallet_updated := found;
        if not v_wallet_updated then
            raise exception using
                errcode = 'P0001',
                message = 'VOUCHER_WALLET_NOT_AVAILABLE';
        end if;
    end if;

    select greatest(
        now(),
        coalesce(max(subscription.end_date), now())
    )
    into v_start_at
    from public.premium_subscription as subscription
    where subscription.id_user = v_attempt.id_user
      and subscription.status = 'active';

    v_end_at :=
        v_start_at + make_interval(days => v_attempt.duration_days);

    insert into public.premium_subscription (
        id_user,
        id_plan,
        id_payment,
        start_date,
        end_date,
        currency,
        status
    )
    values (
        v_attempt.id_user,
        v_attempt.id_subscription_plan,
        v_payment_id,
        v_start_at,
        v_end_at,
        v_attempt.currency,
        'active'
    )
    returning premium_subscription.id_prs
    into v_subscription_id;

    update public.payment_attempt
    set
        status = 'finalized',
        id_payment = v_payment_id,
        id_subscription = v_subscription_id,
        failure_reason = null,
        finalized_at = now()
    where payment_attempt.id_attempt = v_attempt.id_attempt;

    return query
    select
        v_payment_id,
        v_subscription_id,
        v_attempt.original_amount_minor,
        v_attempt.discount_minor,
        v_attempt.amount_minor,
        v_attempt.voucher_code,
        v_end_at;
end;
$$;

revoke all on function public.finalize_verified_payment(
    uuid,
    text,
    bigint,
    text
) from public, anon, authenticated;

grant execute on function public.finalize_verified_payment(
    uuid,
    text,
    bigint,
    text
) to service_role;
