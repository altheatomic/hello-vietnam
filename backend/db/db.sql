-- Kích hoạt extension để tạo UUID tự động
create extension if not exists "uuid-ossp";

-- ==========================================
-- TẦNG 1: CÁC BẢNG ĐỘC LẬP (KHÔNG CÓ KHÓA NGOẠI)
-- ==========================================

create table user_account (
    id_user uuid primary key default uuid_generate_v4(),
    full_name text,
    username text unique,
    password text,
    role text default 'user',
    created_at timestamp with time zone default now()
);

create table city_province (
    id_city uuid primary key default uuid_generate_v4(),
    name text,
    area text,
    description text
);

create table place_subcategory (
    id_place_subcategory uuid primary key default uuid_generate_v4(),
    name text,
    place_category text,
    update_by text,
    update_at timestamp with time zone default now()
);

create table subscription_plan (
    id_subscription_plan uuid primary key default uuid_generate_v4(),
    code text unique,
    name text,
    duration_days int,
    price_minor bigint,
    status text
);

create table canned_replies (
    id_canned_reply uuid primary key default uuid_generate_v4(),
    content text,
    updated_at timestamp with time zone default now()
);

create table phrases (
    id_phrase uuid primary key default uuid_generate_v4(),
    content text,
    sound_north text,
    sound_south text,
    phrase_category text,
    example text
);

create table use_popular_app (
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
-- TẦNG 2: CÁC BẢNG PHỤ THUỘC TRỰC TIẾP VÀO TẦNG 1
-- ==========================================

-- Cụm thông tin mở rộng của User
create table user_contact (
    id_user uuid primary key references user_account(id_user) on delete cascade,
    phone_number text,
    email text unique
);

create table user_accessibility (
    id_user uuid primary key references user_account(id_user) on delete cascade,
    not_enabled boolean default true,
    email_enabled boolean default true,
    location_enabled boolean default false,
    mic_enabled boolean default false,
    quiet_start text,
    quiet_end text,
    push_token text
);

create table user_setting (
    id_user uuid primary key references user_account(id_user) on delete cascade,
    language text default 'vi',
    theme text default 'light',
    currency text default 'VND'
);

-- Cụm Địa điểm & Đồ ăn
create table food (
    id_food uuid primary key default uuid_generate_v4(),
    name text,
    type text,
    id_city uuid references city_province(id_city),
    image_path text,
    description text
);

create table place (
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

-- Cụm Thanh toán & Gói cước
create table feature_entitlement (
    id_entitlement uuid primary key default uuid_generate_v4(),
    id_subscription_plan uuid references subscription_plan(id_subscription_plan),
    feature_code text,
    limit_value int,
    notes text,
    statuses text
);

create table voucher (
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

create table premium_subscription (
    id_prs uuid primary key default uuid_generate_v4(),
    id_user uuid references user_account(id_user),
    id_plan uuid references subscription_plan(id_subscription_plan),
    start_date timestamp with time zone,
    end_date timestamp with time zone,
    currency text,
    status text
);

create table payment (
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

-- Cụm Cộng đồng (Diễn đàn, Plan, Media)
create table forum_topic (
    id_topic uuid primary key default uuid_generate_v4(),
    created_by uuid references user_account(id_user),
    title text,
    description text,
    created_at timestamp with time zone default now(),
    updated_at timestamp with time zone,
    status text,
    last_post_at timestamp with time zone
);

create table plan (
    id_plan uuid primary key default uuid_generate_v4(),
    id_user uuid references user_account(id_user),
    duration text,
    start_at timestamp with time zone,
    end_at timestamp with time zone,
    city_province text,
    created_at timestamp with time zone default now()
);

create table media_asset (
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
-- TẦNG 3 & 4: CÁC BẢNG TRUNG GIAN & TƯƠNG TÁC SÂU
-- ==========================================

create table place_address (
    id_address uuid primary key default uuid_generate_v4(),
    id_place uuid references place(id_place) on delete cascade,
    address text,
    id_city uuid references city_province(id_city)
);

create table place_rating (
    id_place uuid primary key references place(id_place) on delete cascade,
    rating_avg numeric(3,2),
    rating_count int default 0,
    updated_at timestamp with time zone default now()
);

create table hobby (
    id_user uuid references user_account(id_user) on delete cascade,
    id_subcategory uuid references place_subcategory(id_place_subcategory) on delete cascade,
    primary key (id_user, id_subcategory)
);

create table forum_post (
    id_post uuid primary key default uuid_generate_v4(),
    id_topic uuid references forum_topic(id_topic) on delete cascade,
    id_author_user uuid references user_account(id_user),
    title text,
    content text,
    created_at timestamp with time zone default now(),
    updated_at timestamp with time zone,
    status text
);

create table forum_comment (
    id_comment uuid primary key default uuid_generate_v4(),
    id_post uuid references forum_post(id_post) on delete cascade,
    id_author_user uuid references user_account(id_user),
    content text,
    created_at timestamp with time zone default now(),
    updated_at timestamp with time zone,
    status text
);

create table plan_component (
    id_component uuid primary key default uuid_generate_v4(),
    id_plan uuid references plan(id_plan) on delete cascade,
    day int,
    time_part text
);

create table voucher_grant (
    id_grant uuid primary key default uuid_generate_v4(),
    id_voucher uuid references voucher(id_voucher),
    id_user uuid references user_account(id_user),
    source_type text,
    granted_at timestamp with time zone default now(),
    expires_at timestamp with time zone,
    status text
);

create table voucher_redemption (
    id_redemption uuid primary key default uuid_generate_v4(),
    id_voucher uuid references voucher(id_voucher),
    id_user uuid references user_account(id_user),
    id_payment uuid references payment(id_payment),
    discount_minor bigint,
    redeemed_at timestamp with time zone default now()
);

create table notification (
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

-- Các bảng tương tác chung (Dùng id_item dạng UUID chung cho nhiều loại)
create table rate_item (
    id_rate uuid primary key default uuid_generate_v4(),
    id_user uuid references user_account(id_user),
    id_item uuid,
    review text,
    rating int,
    create_at timestamp with time zone default now(),
    update_at timestamp with time zone,
    report_status text
);

create table feedback (
    id_feedback uuid primary key default uuid_generate_v4(),
    id_user uuid references user_account(id_user),
    id_item uuid,
    type text,
    report_content text,
    create_at timestamp with time zone default now(),
    status text
);

-- Legacy polymorphic table (deprecated):
-- keep only for backward compatibility and data migration.
create table favorite (
    id_user uuid references user_account(id_user) on delete cascade,
    id_item uuid,
    type text,
    primary key (id_user, id_item)
);

-- Strongly-typed wishlist tables (recommended):
create table favorite_food (
    id_user uuid not null references user_account(id_user) on delete cascade,
    id_food uuid not null references food(id_food) on delete cascade,
    created_at timestamp with time zone default now(),
    primary key (id_user, id_food)
);

create table favorite_place (
    id_user uuid not null references user_account(id_user) on delete cascade,
    id_place uuid not null references place(id_place) on delete cascade,
    created_at timestamp with time zone default now(),
    primary key (id_user, id_place)
);

create table favorite_city (
    id_user uuid not null references user_account(id_user) on delete cascade,
    id_province uuid not null references city_province(id_city) on delete cascade,
    created_at timestamp with time zone default now(),
    primary key (id_user, id_province)
);

create table report (
    id_report uuid primary key default uuid_generate_v4(),
    id_user uuid references user_account(id_user),
    id_content uuid,
    content_type text,
    report text
);

create table ai_identification (
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
