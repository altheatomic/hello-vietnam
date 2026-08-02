create table public.subscription_payment_loyalty_award (
    id_payment uuid primary key
        references public.payment(id_payment) on delete cascade,
    id_transaction uuid null
        references public.loyalty_transaction(id_transaction),
    awarded_at timestamp with time zone not null default now()
);

alter table public.subscription_payment_loyalty_award
enable row level security;

revoke all on table public.subscription_payment_loyalty_award
from public, anon, authenticated;

grant all on table public.subscription_payment_loyalty_award
to service_role;

insert into public.subscription_payment_loyalty_award (
    id_payment,
    id_transaction,
    awarded_at
)
select distinct on (transaction.reference_id)
    transaction.reference_id,
    transaction.id_transaction,
    coalesce(transaction.created_at, now())
from public.loyalty_transaction as transaction
join public.payment as payment
  on payment.id_payment = transaction.reference_id
where transaction.source_type = 'subscription_purchase'
  and transaction.reference_table = 'payment'
  and transaction.reference_id is not null
order by
    transaction.reference_id,
    transaction.created_at asc nulls last,
    transaction.id_transaction
on conflict (id_payment) do nothing;

create or replace function public.award_subscription_payment_loyalty(
    p_payment_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_payment public.payment%rowtype;
    v_rule public.loyalty_rule_config%rowtype;
    v_counter public.loyalty_daily_counter%rowtype;
    v_transaction_id uuid;
    v_status text;
    v_plan_code text;
    v_account public.user_loyalty_account%rowtype;
    v_target public.loyalty_tier_config%rowtype;
    v_current_priority integer;
    v_highest_priority integer;
begin
    select payment.*
    into v_payment
    from public.payment as payment
    where payment.id_payment = p_payment_id
      and payment.status = 'confirmed'
    for update;

    if not found or v_payment.id_user is null then
        raise exception using
            errcode = 'P0001',
            message = 'CONFIRMED_PAYMENT_NOT_FOUND';
    end if;

    select award.id_transaction
    into v_transaction_id
    from public.subscription_payment_loyalty_award as award
    where award.id_payment = p_payment_id;

    if found then
        return v_transaction_id;
    end if;

    insert into public.subscription_payment_loyalty_award (
        id_payment
    )
    values (
        p_payment_id
    )
    on conflict (id_payment) do nothing
    returning id_transaction
    into v_transaction_id;

    if not found then
        select award.id_transaction
        into v_transaction_id
        from public.subscription_payment_loyalty_award as award
        where award.id_payment = p_payment_id;
        return v_transaction_id;
    end if;

    insert into public.user_loyalty_account (id_user)
    values (v_payment.id_user)
    on conflict (id_user)
    do update set
        updated_at = public.user_loyalty_account.updated_at
    returning *
    into v_account;

    select rule.*
    into v_rule
    from public.loyalty_rule_config as rule
    where rule.action_type = 'subscription_purchase'
      and rule.is_active = true
    limit 1;

    if not found then
        raise exception using
            errcode = 'P0001',
            message = 'LOYALTY_RULE_NOT_FOUND';
    end if;

    insert into public.loyalty_daily_counter (
        id_user,
        action_type,
        counter_date
    )
    values (
        v_payment.id_user,
        'subscription_purchase',
        current_date
    )
    on conflict (id_user, action_type, counter_date)
    do update set updated_at = now()
    returning *
    into v_counter;

    if v_rule.daily_limit_count is not null
       and v_counter.action_count >= v_rule.daily_limit_count then
        raise exception using
            errcode = 'P0001',
            message = 'DAILY_ACTION_LIMIT_REACHED';
    end if;

    if v_rule.daily_limit_points is not null
       and v_counter.points_earned + greatest(v_rule.point_amount, 0)
           > v_rule.daily_limit_points then
        raise exception using
            errcode = 'P0001',
            message = 'DAILY_POINT_LIMIT_REACHED';
    end if;

    select plan.code
    into v_plan_code
    from public.subscription_plan as plan
    where plan.id_subscription_plan = v_payment.id_subscription_plan;

    v_status := case
        when v_rule.requires_approval then 'pending'
        else 'approved'
    end;

    insert into public.loyalty_transaction (
        id_user,
        transaction_type,
        source_type,
        reference_table,
        reference_id,
        point_change,
        tier_point_change,
        token_change,
        status,
        description,
        metadata
    )
    values (
        v_payment.id_user,
        'earn',
        'subscription_purchase',
        'payment',
        p_payment_id,
        v_rule.point_amount,
        v_rule.tier_point_amount,
        0,
        v_status,
        'Premium subscription ' || coalesce(v_plan_code, ''),
        jsonb_build_object(
            'plan_code',
            v_plan_code,
            'final_amount_minor',
            v_payment.amount_minor,
            'currency',
            v_payment.currency
        )
    )
    returning id_transaction
    into v_transaction_id;

    update public.loyalty_daily_counter
    set
        action_count = action_count + 1,
        points_earned =
            points_earned + greatest(v_rule.point_amount, 0),
        updated_at = now()
    where id_user = v_payment.id_user
      and action_type = 'subscription_purchase'
      and counter_date = current_date;

    if v_status = 'approved' then
        update public.user_loyalty_account
        set
            available_points = available_points + v_rule.point_amount,
            lifetime_points =
                lifetime_points + greatest(v_rule.point_amount, 0),
            tier_points = tier_points + v_rule.tier_point_amount,
            updated_at = now()
        where id_user = v_payment.id_user;

        select account.*
        into v_account
        from public.user_loyalty_account as account
        where account.id_user = v_payment.id_user;

        select tier.*
        into v_target
        from public.loyalty_tier_config as tier
        where tier.is_active = true
          and tier.min_tier_points <= v_account.tier_points
        order by tier.priority desc
        limit 1;

        select tier.priority
        into v_current_priority
        from public.loyalty_tier_config as tier
        where tier.tier_code = v_account.current_tier;

        select tier.priority
        into v_highest_priority
        from public.loyalty_tier_config as tier
        where tier.tier_code = v_account.highest_tier;

        if v_target.tier_code is not null
           and v_target.priority > coalesce(v_current_priority, 0) then
            update public.user_loyalty_account
            set
                current_tier = v_target.tier_code,
                highest_tier = case
                    when v_target.priority
                        > coalesce(v_highest_priority, 0)
                    then v_target.tier_code
                    else highest_tier
                end,
                token_balance =
                    token_balance + v_target.token_bonus_on_upgrade,
                updated_at = now()
            where id_user = v_payment.id_user;
        end if;
    end if;

    update public.subscription_payment_loyalty_award
    set
        id_transaction = v_transaction_id,
        awarded_at = now()
    where id_payment = p_payment_id;

    return v_transaction_id;
end;
$$;

revoke all on function public.award_subscription_payment_loyalty(uuid)
from public, anon, authenticated;

grant execute
on function public.award_subscription_payment_loyalty(uuid)
to service_role;
