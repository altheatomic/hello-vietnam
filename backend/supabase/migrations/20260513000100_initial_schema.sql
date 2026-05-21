create extension if not exists "uuid-ossp";

-- ==========================================
-- LEVEL 1: INDEPENDENT TABLES
-- ==========================================

create table if not exists user_account (
    id_user uuid primary key default uuid_generate_v4(),
    full_name text,
    username text unique,
    password text,
    role text default 'user',
    created_at timestamp with time zone default now()
);

create table if not exists city_province (
    id_city uuid primary key default uuid_generate_v4(),
    name text,
    area text,
    description text
);

create table if not exists place_subcategory (
    id_place_subcategory uuid primary key default uuid_generate_v4(),
    name text,
    place_category text,
    update_by text,
    update_at timestamp with time zone default now()
);

create table if not exists subscription_plan (
    id_subscription_plan uuid primary key default uuid_generate_v4(),
    code text unique,
    name text,
    duration_days int,
    price_minor bigint,
    status text
);

create table if not exists canned_replies (
    id_canned_reply uuid primary key default uuid_generate_v4(),
    content text,
    updated_at timestamp with time zone default now()
);

create table if not exists phrases (
    id_phrase uuid primary key default uuid_generate_v4(),
    content text,
    sound_north text,
    sound_south text,
    phrase_category text,
    example text
);

create table if not exists use_popular_app (
    id_app uuid primary key default uuid_generate_v4(),
    name text,
    type text,
    guide text,
    url_image text,
    url_video text,
    description text,
    update_at timestamp with time zone default now()
);

-- ==========================================
-- LEVEL 2: DIRECT DEPENDENCIES
-- ==========================================

create table if not exists user_contact (
    id_user uuid primary key references user_account(id_user) on delete cascade,
    phone_number text,
    email text unique
);

create table if not exists user_accessibility (
    id_user uuid primary key references user_account(id_user) on delete cascade,
    not_enabled boolean default true,
    email_enabled boolean default true,
    location_enabled boolean default false,
    mic_enabled boolean default false,
    quiet_start text,
    quiet_end text,
    push_token text
);

create table if not exists user_setting (
    id_user uuid primary key references user_account(id_user) on delete cascade,
    language text default 'vi',
    theme text default 'light',
    currency text default 'VND'
);

create table if not exists food (
    id_food uuid primary key default uuid_generate_v4(),
    name text,
    type text,
    id_city uuid references city_province(id_city),
    image_path text,
    description text
);

create table if not exists place (
    id_place uuid primary key default uuid_generate_v4(),
    id_place_subcategory uuid references place_subcategory(id_place_subcategory),
    name text,
    description text,
    timespan text,
    timeclose text,
    status text,
    images_path text,
    created_at timestamp with time zone default now()
);

create table if not exists feature_entitlement (
    id_entitlement uuid primary key default uuid_generate_v4(),
    id_subscription_plan uuid references subscription_plan(id_subscription_plan),
    feature_code text,
    limit_value int,
    notes text,
    statuses text
);

create table if not exists voucher (
    id_voucher uuid primary key default uuid_generate_v4(),
    id_applicable_plan uuid references subscription_plan(id_subscription_plan),
    code text unique,
    type text,
    value bigint,
    max_discount_value bigint,
    start_at timestamp with time zone,
    end_at timestamp with time zone,
    status text,
    usage_limit_total int,
    usage_limit_per_user int,
    min_order_amount_min bigint,
    created_at timestamp with time zone default now()
);

create table if not exists premium_subscription (
    id_prs uuid primary key default uuid_generate_v4(),
    id_user uuid references user_account(id_user),
    id_plan uuid references subscription_plan(id_subscription_plan),
    start_date timestamp with time zone,
    end_date timestamp with time zone,
    currency text,
    status text
);

create table if not exists payment (
    id_payment uuid primary key default uuid_generate_v4(),
    id_user uuid references user_account(id_user),
    id_subscription_plan uuid references subscription_plan(id_subscription_plan),
    provider text,
    method text,
    amount_minor bigint,
    currency text,
    status text,
    external_ref text,
    created_at timestamp with time zone default now(),
    confirmed_at timestamp with time zone,
    failure_reason text
);

create table if not exists forum_topic (
    id_topic uuid primary key default uuid_generate_v4(),
    created_by uuid references user_account(id_user),
    title text,
    description text,
    created_at timestamp with time zone default now(),
    updated_at timestamp with time zone,
    status text,
    last_post_at timestamp with time zone
);

create table if not exists plan (
    id_plan uuid primary key default uuid_generate_v4(),
    id_user uuid references user_account(id_user),
    duration text,
    start_at timestamp with time zone,
    end_at timestamp with time zone,
    city_province text,
    created_at timestamp with time zone default now()
);

create table if not exists media_asset (
    id_media uuid primary key default uuid_generate_v4(),
    owner_user_id uuid references user_account(id_user),
    url text,
    mime_type text,
    sha256_hash text,
    width int,
    height int,
    ext_json jsonb,
    created_at timestamp with time zone default now()
);

-- ==========================================
-- LEVEL 3 AND 4: RELATIONS AND INTERACTIONS
-- ==========================================

create table if not exists place_address (
    id_address uuid primary key default uuid_generate_v4(),
    id_place uuid references place(id_place) on delete cascade,
    address text,
    id_city uuid references city_province(id_city)
);

create table if not exists place_rating (
    id_place uuid primary key references place(id_place) on delete cascade,
    rating_avg numeric(3,2),
    rating_count int default 0,
    updated_at timestamp with time zone default now()
);

create table if not exists hobby (
    id_user uuid references user_account(id_user) on delete cascade,
    id_subcategory uuid references place_subcategory(id_place_subcategory) on delete cascade,
    primary key (id_user, id_subcategory)
);

create table if not exists forum_post (
    id_post uuid primary key default uuid_generate_v4(),
    id_topic uuid references forum_topic(id_topic) on delete cascade,
    id_author_user uuid references user_account(id_user),
    title text,
    content text,
    created_at timestamp with time zone default now(),
    updated_at timestamp with time zone,
    status text
);

create table if not exists forum_comment (
    id_comment uuid primary key default uuid_generate_v4(),
    id_post uuid references forum_post(id_post) on delete cascade,
    id_author_user uuid references user_account(id_user),
    content text,
    created_at timestamp with time zone default now(),
    updated_at timestamp with time zone,
    status text
);

create table if not exists plan_component (
    id_component uuid primary key default uuid_generate_v4(),
    id_plan uuid references plan(id_plan) on delete cascade,
    day int,
    time_part text
);

create table if not exists voucher_grant (
    id_grant uuid primary key default uuid_generate_v4(),
    id_voucher uuid references voucher(id_voucher),
    id_user uuid references user_account(id_user),
    source_type text,
    granted_at timestamp with time zone default now(),
    expires_at timestamp with time zone,
    status text
);

create table if not exists voucher_redemption (
    id_redemption uuid primary key default uuid_generate_v4(),
    id_voucher uuid references voucher(id_voucher),
    id_user uuid references user_account(id_user),
    id_payment uuid references payment(id_payment),
    discount_minor bigint,
    redeemed_at timestamp with time zone default now()
);

create table if not exists notification (
    id_notification uuid primary key default uuid_generate_v4(),
    id_user uuid references user_account(id_user),
    id_voucher uuid references voucher(id_voucher),
    id_comment uuid references forum_comment(id_comment),
    title text,
    body text,
    deeplink text,
    payload_jsonb jsonb,
    is_in_app boolean default true,
    is_push boolean default false,
    sent_at timestamp with time zone,
    read_at timestamp with time zone,
    status text,
    created_at timestamp with time zone default now()
);

create table if not exists rate_item (
    id_rate uuid primary key default uuid_generate_v4(),
    id_user uuid references user_account(id_user),
    id_item uuid,
    review text,
    rating int,
    create_at timestamp with time zone default now(),
    update_at timestamp with time zone,
    report_status text
);

create table if not exists feedback (
    id_feedback uuid primary key default uuid_generate_v4(),
    id_user uuid references user_account(id_user),
    id_item uuid,
    type text,
    report_content text,
    create_at timestamp with time zone default now(),
    status text
);

create table if not exists favorite (
    id_user uuid references user_account(id_user) on delete cascade,
    id_item uuid,
    type text,
    primary key (id_user, id_item)
);

create table if not exists report (
    id_report uuid primary key default uuid_generate_v4(),
    id_user uuid references user_account(id_user),
    id_content uuid,
    content_type text,
    report text
);

create table if not exists ai_identification (
    id_ai_ident uuid primary key default uuid_generate_v4(),
    id_user uuid references user_account(id_user),
    id_input_media uuid references media_asset(id_media),
    input_media_type text,
    model text,
    status text,
    confidence numeric,
    alt_candidates text,
    created_at timestamp with time zone default now(),
    processed_at timestamp with time zone
);
