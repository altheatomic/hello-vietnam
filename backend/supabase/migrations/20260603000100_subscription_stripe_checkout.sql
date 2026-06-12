insert into subscription_plan (code, name, duration_days, price_minor, status)
values
    ('1m', 'Premium 1 Month', 30, 499, 'active'),
    ('6m', 'Premium 6 Months', 180, 1999, 'active'),
    ('12m', 'Premium 12 Months', 365, 2999, 'active')
on conflict (code) do update set
    name = excluded.name,
    duration_days = excluded.duration_days,
    price_minor = excluded.price_minor,
    status = excluded.status;

insert into voucher (
    code,
    type,
    value,
    max_discount_value,
    start_at,
    end_at,
    status,
    usage_limit_total,
    usage_limit_per_user,
    min_order_amount_min
)
values
    ('WELCOME2024', 'fixed', 200, 200, now() - interval '1 day', now() + interval '1 year', 'active', 10000, 1, 0),
    ('PREMIUM10', 'percent', 10, 500, now() - interval '1 day', now() + interval '1 year', 'active', 10000, 1, 0),
    ('HOLIDAY15', 'percent', 15, 500, now() - interval '1 day', now() + interval '1 year', 'active', 10000, 1, 0),
    ('PREMIUM200', 'fixed', 2000, 2000, now() - interval '1 day', now() + interval '1 year', 'active', 10000, 1, 1999)
on conflict (code) do update set
    type = excluded.type,
    value = excluded.value,
    max_discount_value = excluded.max_discount_value,
    start_at = excluded.start_at,
    end_at = excluded.end_at,
    status = excluded.status,
    usage_limit_total = excluded.usage_limit_total,
    usage_limit_per_user = excluded.usage_limit_per_user,
    min_order_amount_min = excluded.min_order_amount_min;

create or replace function confirm_paid_subscription_with_voucher(
    p_plan_code text,
    p_provider text,
    p_method text,
    p_external_ref text,
    p_voucher_code text default null
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
set search_path = public, auth
as $$
declare
    v_user_id uuid := auth.uid();
    v_plan subscription_plan%rowtype;
    v_voucher voucher%rowtype;
    v_discount bigint := 0;
    v_final_amount bigint := 0;
    v_total_uses int := 0;
    v_user_uses int := 0;
    v_start_at timestamp with time zone := now();
    v_end_at timestamp with time zone;
    v_payment_id uuid;
    v_subscription_id uuid;
    v_code text := nullif(upper(trim(coalesce(p_voucher_code, ''))), '');
    v_external_ref text := nullif(trim(coalesce(p_external_ref, '')), '');
begin
    if v_user_id is null then
        raise exception 'NOT_AUTHENTICATED';
    end if;

    if v_external_ref is null then
        raise exception 'PAYMENT_REFERENCE_REQUIRED';
    end if;

    select pay.id_payment
    into v_payment_id
    from payment pay
    where pay.id_user = v_user_id
      and pay.external_ref = v_external_ref
      and pay.status = 'confirmed'
    limit 1;

    if v_payment_id is not null then
        select prs.id_prs, prs.end_date
        into v_subscription_id, v_end_at
        from premium_subscription prs
        where prs.id_user = v_user_id
          and prs.status = 'active'
        order by prs.end_date desc
        limit 1;

        select
            coalesce(sp.price_minor, 0),
            coalesce(pay.amount_minor, 0),
            nullif(v_code, ''),
            v_end_at
        into
            original_amount_minor,
            final_amount_minor,
            voucher_code,
            subscription_end_date
        from payment pay
        left join subscription_plan sp
          on sp.id_subscription_plan = pay.id_subscription_plan
        where pay.id_payment = v_payment_id;

        discount_minor := greatest(0, original_amount_minor - final_amount_minor);
        id_payment := v_payment_id;
        id_subscription := v_subscription_id;
        return next;
        return;
    end if;

    select *
    into v_plan
    from subscription_plan
    where code = p_plan_code
      and (status is null or status = 'active')
    limit 1;

    if not found then
        raise exception 'PLAN_NOT_FOUND';
    end if;

    if v_code is not null then
        select *
        into v_voucher
        from voucher
        where upper(code) = v_code
          and status = 'active'
          and (start_at is null or start_at <= now())
          and (end_at is null or end_at >= now())
          and (id_applicable_plan is null or id_applicable_plan = v_plan.id_subscription_plan)
        limit 1;

        if not found then
            raise exception 'VOUCHER_INVALID';
        end if;

        if coalesce(v_plan.price_minor, 0) < coalesce(v_voucher.min_order_amount_min, 0) then
            raise exception 'VOUCHER_MIN_ORDER_NOT_MET';
        end if;

        select count(*)
        into v_total_uses
        from voucher_redemption
        where id_voucher = v_voucher.id_voucher;

        if v_voucher.usage_limit_total is not null and v_total_uses >= v_voucher.usage_limit_total then
            raise exception 'VOUCHER_USAGE_LIMIT_REACHED';
        end if;

        select count(*)
        into v_user_uses
        from voucher_redemption
        where id_voucher = v_voucher.id_voucher
          and id_user = v_user_id;

        if v_voucher.usage_limit_per_user is not null and v_user_uses >= v_voucher.usage_limit_per_user then
            raise exception 'VOUCHER_ALREADY_USED';
        end if;

        if lower(v_voucher.type) in ('percent', 'percentage') then
            v_discount := floor(coalesce(v_plan.price_minor, 0) * coalesce(v_voucher.value, 0) / 100.0)::bigint;
            if v_voucher.max_discount_value is not null then
                v_discount := least(v_discount, v_voucher.max_discount_value);
            end if;
        else
            v_discount := coalesce(v_voucher.value, 0);
        end if;
    end if;

    v_discount := greatest(0, least(v_discount, coalesce(v_plan.price_minor, 0)));
    v_final_amount := greatest(0, coalesce(v_plan.price_minor, 0) - v_discount);
    v_end_at := v_start_at + make_interval(days => coalesce(v_plan.duration_days, 30));

    insert into payment (
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
        v_user_id,
        v_plan.id_subscription_plan,
        p_provider,
        p_method,
        v_final_amount,
        'USD',
        'confirmed',
        v_external_ref,
        now()
    )
    returning payment.id_payment into v_payment_id;

    if v_voucher.id_voucher is not null and v_discount > 0 then
        insert into voucher_redemption (
            id_voucher,
            id_user,
            id_payment,
            discount_minor,
            redeemed_at
        )
        values (
            v_voucher.id_voucher,
            v_user_id,
            v_payment_id,
            v_discount,
            now()
        );
    end if;

    insert into premium_subscription (
        id_user,
        id_plan,
        start_date,
        end_date,
        currency,
        status
    )
    values (
        v_user_id,
        v_plan.id_subscription_plan,
        v_start_at,
        v_end_at,
        'USD',
        'active'
    )
    returning premium_subscription.id_prs into v_subscription_id;

    return query
    select
        v_payment_id,
        v_subscription_id,
        coalesce(v_plan.price_minor, 0),
        v_discount,
        v_final_amount,
        v_voucher.code,
        v_end_at;
end;
$$;

grant execute on function confirm_paid_subscription_with_voucher(text, text, text, text, text) to authenticated;
