-- ── CF factor tables (WALS user/place embeddings) ───────────────────────────
-- Runs alongside cf_score_cache (not a replacement). See jobs/cf_retrain.py:
-- both the legacy top-500 cache and these raw factor tables are written by
-- the same retrain run so the runtime dot-product path can be validated
-- before cf_score_cache is retired.

create table if not exists cf_user_factors (
    id_user    uuid not null references user_account(id_user) on delete cascade,
    factors    float8[] not null,
    updated_at timestamp with time zone default now(),
    primary key (id_user)
);

create table if not exists cf_place_factors (
    id_place   uuid not null references place(id_place) on delete cascade,
    factors    float8[] not null,
    updated_at timestamp with time zone default now(),
    primary key (id_place)
);
