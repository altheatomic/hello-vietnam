-- =============================================================================
-- Plan Trip schema migration
-- Adds: geo columns to place, itinerary eligibility flag to place_subcategory,
--       new tables for ML pipeline and trip storage.
-- Safe to re-run: uses IF NOT EXISTS / IF NOT EXISTS everywhere.
-- =============================================================================

-- ── Extensions ────────────────────────────────────────────────────────────────

create extension if not exists "uuid-ossp";

-- ── Extend existing tables ────────────────────────────────────────────────────

alter table place
  add column if not exists id_province       uuid references city_province(id_city),
  add column if not exists latitude          double precision,
  add column if not exists longitude         double precision,
  add column if not exists price_level       numeric(3,1) default 0,
  add column if not exists average_rating    numeric(3,2) default 3,
  add column if not exists estimated_duration_minutes int,
  add column if not exists minimum_price     bigint,
  add column if not exists maximum_price     bigint;

alter table place_subcategory
  add column if not exists is_itinerary_eligible boolean default false;

-- ── Tag catalogue ─────────────────────────────────────────────────────────────

create table if not exists tag (
    id_tag   uuid primary key default uuid_generate_v4(),
    name     text not null,
    category text
);

-- ── Place ↔ Tag (confidence scored) ──────────────────────────────────────────

create table if not exists place_tag (
    id_place         uuid not null references place(id_place) on delete cascade,
    id_tag           uuid not null references tag(id_tag) on delete cascade,
    confidence_score numeric(5,4) default 1.0,
    primary key (id_place, id_tag)
);

create index if not exists idx_place_tag_place on place_tag(id_place);

-- ── User interest tags (weighted) ─────────────────────────────────────────────

create table if not exists user_interest_tag (
    id_user      uuid not null references user_account(id_user) on delete cascade,
    id_tag       uuid not null references tag(id_tag) on delete cascade,
    final_weight numeric(6,4) default 1.0,
    primary key (id_user, id_tag)
);

create index if not exists idx_uit_user on user_interest_tag(id_user);

-- ── User travel profile ───────────────────────────────────────────────────────

create table if not exists user_travel_profile (
    id_user          uuid primary key references user_account(id_user) on delete cascade,
    companion_style  text,   -- solo | couple | friends | family | ...
    budget_level     text,   -- budget | mid_range | comfort | premium
    pace_level       text    -- easy | balanced | active | packed
);

-- ── Hobbies (user ↔ subcategory) ─────────────────────────────────────────────

create table if not exists hobby (
    id_hobby        uuid primary key default uuid_generate_v4(),
    id_user         uuid not null references user_account(id_user) on delete cascade,
    id_subcategory  uuid not null references place_subcategory(id_place_subcategory) on delete cascade,
    unique (id_user, id_subcategory)
);

create index if not exists idx_hobby_user on hobby(id_user);

-- ── Rate item (reviews / ratings for places, foods, …) ───────────────────────

create table if not exists rate_item (
    id_rate    uuid primary key default uuid_generate_v4(),
    id_user    uuid not null references user_account(id_user) on delete cascade,
    id_item    uuid not null,
    item_type  text not null,   -- 'place' | 'food' | ...
    rating     numeric(3,1),
    review     text,
    created_at timestamp with time zone default now(),
    unique (id_user, id_item, item_type)
);

create index if not exists idx_rate_item_user on rate_item(id_user);

-- ── Trip plan header ──────────────────────────────────────────────────────────

create table if not exists plan (
    id_plan       uuid primary key default uuid_generate_v4(),
    id_user       uuid not null references user_account(id_user) on delete cascade,
    duration      text,   -- number of days as text (kept compatible with Python service)
    start_at      date,
    end_at        date,
    city_province uuid references city_province(id_city),
    created_at    timestamp with time zone default now()
);

create index if not exists idx_plan_user on plan(id_user);

-- ── Trip plan components ──────────────────────────────────────────────────────

create table if not exists plan_component (
    id_component              uuid primary key default uuid_generate_v4(),
    id_plan                   uuid not null references plan(id_plan) on delete cascade,
    day                       int,
    time_part                 text,   -- morning | afternoon | evening | lunch
    id_place                  uuid references place(id_place),
    visit_order               int,
    slot                      text,
    estimated_travel_minutes  int,
    cb_score                  numeric(6,4),
    cf_score                  numeric(6,4),
    final_score               numeric(6,4)
);

create index if not exists idx_plan_component_plan on plan_component(id_plan);

-- ── CF score cache ────────────────────────────────────────────────────────────

create table if not exists cf_score_cache (
    id_user    uuid not null references user_account(id_user) on delete cascade,
    id_place   uuid not null references place(id_place) on delete cascade,
    score      numeric(7,6) not null,
    updated_at timestamp with time zone default now(),
    primary key (id_user, id_place)
);

create index if not exists idx_cf_cache_user on cf_score_cache(id_user);

-- ── CF retrain log ────────────────────────────────────────────────────────────

create table if not exists cf_retrain_log (
    id_log        uuid primary key default uuid_generate_v4(),
    triggered_by  text,
    started_at    timestamp with time zone default now(),
    finished_at   timestamp with time zone,
    status        text,   -- running | success | failed
    rows_written  int,
    error_msg     text
);
