insert into public.loyalty_rule_config (
    rule_code,
    rule_name,
    action_type,
    point_amount,
    tier_point_amount,
    token_cost,
    daily_limit_count,
    daily_limit_points,
    requires_approval,
    metadata,
    is_active
)
values (
    'test_bonus_500',
    'Add 500 test loyalty points',
    'test_bonus',
    500,
    500,
    0,
    null,
    null,
    false,
    '{"temporary": true, "note": "Manual test-only loyalty bonus"}'::jsonb,
    true
)
on conflict (rule_code) do update
set rule_name = excluded.rule_name,
    action_type = excluded.action_type,
    point_amount = excluded.point_amount,
    tier_point_amount = excluded.tier_point_amount,
    token_cost = excluded.token_cost,
    daily_limit_count = excluded.daily_limit_count,
    daily_limit_points = excluded.daily_limit_points,
    requires_approval = excluded.requires_approval,
    metadata = excluded.metadata,
    is_active = excluded.is_active;
