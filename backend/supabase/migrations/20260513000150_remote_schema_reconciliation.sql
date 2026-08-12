-- LOCAL REPLAY RECONCILIATION ONLY
-- Generated from the read-only public schema snapshot at
-- /tmp/hello-vietnam-schema-snapshot.qmdslc/public-schema.sql.
--
-- This baseline is intentionally not a deployment migration. It exists only
-- to let a clean local replay model objects already present on the linked
-- project while the historical migration chain is reviewed. Do not push this
-- file or repair remote migration history as part of this task.
--
-- Foreign keys are intentionally deferred: several referenced tables are
-- created by later local migrations. The original migration chain remains
-- authoritative for those later constraints.

CREATE TABLE IF NOT EXISTS "public"."activity" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "cover_image" "text",
    "gallery" "jsonb",
    "short_description" "text",
    "detailed_description" "text",
    "activity_type" "text",
    "opening_hours" "jsonb",
    "price_range" "text",
    "safety_notes" "text",
    "average_rating" numeric(2,1),
    "review_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "id_province" "uuid",
    "status" "text" DEFAULT 'active'::"text"
);


CREATE TABLE IF NOT EXISTS "public"."activity_tag" (
    "id_activity" "uuid" NOT NULL,
    "id_tag" "uuid" NOT NULL,
    "tag_role" "text" DEFAULT 'secondary'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "activity_tag_role_check" CHECK (("tag_role" = ANY (ARRAY['primary'::"text", 'secondary'::"text"])))
);


CREATE TABLE IF NOT EXISTS "public"."activity_translation" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "activity_id" "uuid" NOT NULL,
    "lang_code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "short_description" "text",
    "detailed_description" "text",
    "activity_type" "text",
    "price_range" "text",
    "safety_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


CREATE TABLE IF NOT EXISTS "public"."culture" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "cover_image" "text",
    "gallery" "jsonb",
    "short_description" "text",
    "detailed_description" "text",
    "origin_history" "text",
    "cultural_significance" "text",
    "event_time" "text",
    "etiquette" "text",
    "notable_figures" "text",
    "average_rating" numeric(2,1),
    "review_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "id_province" "uuid",
    "status" "text" DEFAULT 'active'::"text"
);


CREATE TABLE IF NOT EXISTS "public"."culture_tag" (
    "id_culture" "uuid" NOT NULL,
    "id_tag" "uuid" NOT NULL,
    "tag_role" "text" DEFAULT 'secondary'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "culture_tag_role_check" CHECK (("tag_role" = ANY (ARRAY['primary'::"text", 'secondary'::"text"])))
);


CREATE TABLE IF NOT EXISTS "public"."culture_translation" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "culture_id" "uuid" NOT NULL,
    "lang_code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "short_description" "text",
    "detailed_description" "text",
    "origin_history" "text",
    "cultural_significance" "text",
    "event_time" "text",
    "etiquette" "text",
    "notable_figures" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


CREATE TABLE IF NOT EXISTS "public"."food_type" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "type" "text" NOT NULL,
    "category" "text"
);


CREATE TABLE IF NOT EXISTS "public"."province" (
    "id_province" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "short_description" "text",
    "region_code" "text" NOT NULL,
    "detailed_description" "text",
    "cover_image" "text",
    "gallery" "jsonb",
    "average_rating" numeric,
    "review_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "description_en" "text"
);


CREATE TABLE IF NOT EXISTS "public"."food_tag" (
    "id_food" "uuid" NOT NULL,
    "id_tag" "uuid" NOT NULL,
    "tag_role" "text" DEFAULT 'secondary'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "food_tag_role_check" CHECK (("tag_role" = ANY (ARRAY['primary'::"text", 'secondary'::"text"])))
);


CREATE TABLE IF NOT EXISTS "public"."food_translation" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "food_id" "uuid" NOT NULL,
    "lang_code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "short_description" "text",
    "detailed_description" "text",
    "ingredients" "text",
    "taste_profile" "text",
    "dietary_warnings" "text",
    "auto_translated" boolean DEFAULT false NOT NULL,
    "translation_status" "text" DEFAULT 'done'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "food_translation_translation_status_check" CHECK (("translation_status" = ANY (ARRAY['draft'::"text", 'auto'::"text", 'reviewed'::"text", 'done'::"text"])))
);


CREATE TABLE IF NOT EXISTS "public"."food_type_translation" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "food_type" "text" NOT NULL,
    "lang_code" "text" NOT NULL,
    "category" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


CREATE TABLE IF NOT EXISTS "public"."forum_comment_like" (
    "id_comment" "uuid" NOT NULL,
    "id_user" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


CREATE TABLE IF NOT EXISTS "public"."forum_post_bookmark" (
    "id_post" "uuid" NOT NULL,
    "id_user" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


CREATE TABLE IF NOT EXISTS "public"."forum_post_like" (
    "id_post" "uuid" NOT NULL,
    "id_user" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


CREATE TABLE IF NOT EXISTS "public"."forum_post_media" (
    "id_media" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "id_post" "uuid" NOT NULL,
    "url" "text" NOT NULL,
    "position" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"()
);


CREATE TABLE IF NOT EXISTS "public"."forum_post_report" (
    "id_report" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "id_post" "uuid" NOT NULL,
    "id_reporter_user" "uuid",
    "reason" "text" NOT NULL,
    "details" "text",
    "status" "text" DEFAULT 'pending'::"text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


CREATE TABLE IF NOT EXISTS "public"."forum_user_block" (
    "blocker_user_id" "uuid" NOT NULL,
    "blocked_user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "forum_user_block_no_self" CHECK (("blocker_user_id" <> "blocked_user_id"))
);


CREATE TABLE IF NOT EXISTS "public"."forum_user_follow" (
    "follower_user_id" "uuid" NOT NULL,
    "following_user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "forum_user_follow_no_self" CHECK (("follower_user_id" <> "following_user_id"))
);


CREATE TABLE IF NOT EXISTS "public"."language" (
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "native_name" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "is_default" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


CREATE TABLE IF NOT EXISTS "public"."local_product_tag" (
    "id_local_product" "uuid" NOT NULL,
    "id_tag" "uuid" NOT NULL,
    "tag_role" "text" DEFAULT 'secondary'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "local_product_tag_role_check" CHECK (("tag_role" = ANY (ARRAY['primary'::"text", 'secondary'::"text"])))
);


CREATE TABLE IF NOT EXISTS "public"."local_products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "cover_image" "text",
    "gallery" "jsonb",
    "short_description" "text",
    "detailed_description" "text",
    "category" "text",
    "storage_transport" "text",
    "price_range" "text",
    "trusted_places" "text",
    "average_rating" numeric(2,1),
    "review_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "id_province" "uuid",
    "status" "text" DEFAULT 'active'::"text"
);


CREATE TABLE IF NOT EXISTS "public"."local_products_translation" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "local_product_id" "uuid" NOT NULL,
    "lang_code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "short_description" "text",
    "detailed_description" "text",
    "category" "text",
    "storage_transport" "text",
    "price_range" "text",
    "trusted_places" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


CREATE TABLE IF NOT EXISTS "public"."region" (
    "id_region" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "region_code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "zone_code" "text" NOT NULL
);


CREATE TABLE IF NOT EXISTS "public"."zone" (
    "id_zone" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "zone_code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text"
);


CREATE TABLE IF NOT EXISTS "public"."old_province" (
    "id_province" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "region_code" "text",
    "average_rating" numeric,
    "review_count" integer DEFAULT 0,
    "description_en" "text",
    "cover_image" "text"
);


CREATE TABLE IF NOT EXISTS "public"."place_tag_backup_before_full_run" (
    "id_place" "uuid",
    "id_tag" "uuid",
    "confidence_score" numeric,
    "source" "text",
    "created_at" timestamp with time zone
);


CREATE TABLE IF NOT EXISTS "public"."pre-written reply" (
    "id_canned_reply" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "content" "text",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


CREATE TABLE IF NOT EXISTS "public"."province_translation" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "province_id" "uuid" NOT NULL,
    "lang_code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "short_description" "text",
    "detailed_description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


CREATE TABLE IF NOT EXISTS "public"."recommendation_cache" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "id_user" "uuid" NOT NULL,
    "id_province" "uuid",
    "recommendation_type" "text" NOT NULL,
    "result_json" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone NOT NULL
);


CREATE TABLE IF NOT EXISTS "public"."tag_content_type" (
    "id_tag" "uuid" NOT NULL,
    "content_type" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "tag_content_type_check" CHECK (("content_type" = ANY (ARRAY['place'::"text", 'activity'::"text", 'culture'::"text", 'food'::"text", 'local_product'::"text"])))
);


CREATE TABLE IF NOT EXISTS "public"."trip_interest_choice" (
    "id_trip_plan" "uuid" NOT NULL,
    "id_trip_interest_option" "uuid" NOT NULL,
    "selection_order" integer,
    "source" "text" DEFAULT 'user_selected'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "trip_interest_choice_order_check" CHECK ((("selection_order" IS NULL) OR ("selection_order" > 0))),
    CONSTRAINT "trip_interest_choice_source_check" CHECK (("source" = ANY (ARRAY['user_selected'::"text", 'profile_default'::"text", 'system_suggested'::"text"])))
);


CREATE TABLE IF NOT EXISTS "public"."trip_interest_option" (
    "id_trip_interest_option" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "option_code" "text" NOT NULL,
    "display_name" "text" NOT NULL,
    "description" "text",
    "display_order" integer DEFAULT 0 NOT NULL,
    "min_selection" integer,
    "max_selection" integer,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "trip_interest_option_display_order_check" CHECK (("display_order" >= 0)),
    CONSTRAINT "trip_interest_option_selection_check" CHECK ((("min_selection" IS NULL) OR ("max_selection" IS NULL) OR (("min_selection" >= 0) AND ("max_selection" >= "min_selection"))))
);


CREATE TABLE IF NOT EXISTS "public"."trip_interest_option_subcategory" (
    "id_trip_interest_option" "uuid" NOT NULL,
    "id_place_subcategory" "uuid" NOT NULL,
    "priority_level" "text" NOT NULL,
    "priority_weight" double precision NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "trip_interest_option_subcategory_level_check" CHECK (("priority_level" = ANY (ARRAY['primary'::"text", 'secondary'::"text", 'context'::"text"]))),
    CONSTRAINT "trip_interest_option_subcategory_level_weight_check" CHECK (((("priority_level" = 'primary'::"text") AND ("priority_weight" = (1.0)::double precision)) OR (("priority_level" = 'secondary'::"text") AND ("priority_weight" = (0.6)::double precision)) OR (("priority_level" = 'context'::"text") AND ("priority_weight" = (0.3)::double precision)))),
    CONSTRAINT "trip_interest_option_subcategory_weight_check" CHECK ((("priority_weight" > (0)::double precision) AND ("priority_weight" <= (1)::double precision)))
);


CREATE TABLE IF NOT EXISTS "public"."trip_interest_option_tag" (
    "id_trip_interest_option" "uuid" NOT NULL,
    "id_tag" "uuid" NOT NULL,
    "weight_level" "text" NOT NULL,
    "raw_weight" double precision NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "trip_interest_option_tag_level_weight_check" CHECK (((("weight_level" = 'primary'::"text") AND ("raw_weight" = (1.0)::double precision)) OR (("weight_level" = 'secondary'::"text") AND ("raw_weight" = (0.6)::double precision)) OR (("weight_level" = 'context'::"text") AND ("raw_weight" = (0.3)::double precision)))),
    CONSTRAINT "trip_interest_option_tag_raw_weight_check" CHECK ((("raw_weight" > (0)::double precision) AND ("raw_weight" <= (1)::double precision))),
    CONSTRAINT "trip_interest_option_tag_weight_level_check" CHECK (("weight_level" = ANY (ARRAY['primary'::"text", 'secondary'::"text", 'context'::"text"])))
);


CREATE TABLE IF NOT EXISTS "public"."trip_plan" (
    "id_trip_plan" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "id_user" "uuid" NOT NULL,
    "id_province" "uuid" NOT NULL,
    "start_date" "date" NOT NULL,
    "end_date" "date" NOT NULL,
    "total_days" integer NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "trip_plan_date_check" CHECK (("end_date" >= "start_date")),
    CONSTRAINT "trip_plan_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'generating'::"text", 'generated'::"text", 'confirmed'::"text", 'cancelled'::"text", 'failed'::"text"]))),
    CONSTRAINT "trip_plan_total_days_check" CHECK (("total_days" > 0))
);


CREATE TABLE IF NOT EXISTS "public"."use_popular_app_category" (
    "id" "text" NOT NULL,
    "label" "text" NOT NULL,
    "color_index" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


CREATE TABLE IF NOT EXISTS "public"."user_explore_event" (
    "id_event" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "id_user" "uuid" NOT NULL,
    "content_type" "text" NOT NULL,
    "content_id" "uuid" NOT NULL,
    "id_province" "uuid",
    "event_type" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "event_score" integer DEFAULT 0 NOT NULL,
    "request_id" "text",
    CONSTRAINT "user_explore_event_content_type_check" CHECK (("content_type" = ANY (ARRAY['activity'::"text", 'culture'::"text", 'food'::"text", 'local_product'::"text"]))),
    CONSTRAINT "user_explore_event_event_type_check" CHECK (("event_type" = ANY (ARRAY['view_detail'::"text", 'share'::"text", 'favorite'::"text", 'add_to_trip'::"text", 'skip'::"text", 'unfavorite'::"text", 'remove_from_trip'::"text"]))),
    CONSTRAINT "user_explore_event_type_check" CHECK (("event_type" = ANY (ARRAY['view'::"text", 'view_detail'::"text", 'favorite'::"text", 'unfavorite'::"text", 'share'::"text"])))
);


CREATE TABLE IF NOT EXISTS "public"."user_interest_tag" (
    "id_user" "uuid" NOT NULL,
    "id_tag" "uuid" NOT NULL,
    "initial_weight" double precision DEFAULT 0 NOT NULL,
    "behavior_score" double precision DEFAULT 0 NOT NULL,
    "behavior_weight" double precision DEFAULT 0 NOT NULL,
    "final_weight" double precision DEFAULT 0 NOT NULL,
    "source" "text" DEFAULT 'onboarding'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "positive_behavior_count" integer DEFAULT 0 NOT NULL,
    "negative_behavior_count" integer DEFAULT 0 NOT NULL,
    "behavior_count" integer DEFAULT 0 NOT NULL,
    CONSTRAINT "user_interest_tag_behavior_count_check" CHECK (("behavior_count" >= 0)),
    CONSTRAINT "user_interest_tag_behavior_weight_check" CHECK ((("behavior_weight" >= (0)::double precision) AND ("behavior_weight" <= (1)::double precision))),
    CONSTRAINT "user_interest_tag_final_weight_check" CHECK ((("final_weight" >= (0)::double precision) AND ("final_weight" <= (1)::double precision))),
    CONSTRAINT "user_interest_tag_initial_weight_check" CHECK ((("initial_weight" >= (0)::double precision) AND ("initial_weight" <= (1)::double precision))),
    CONSTRAINT "user_interest_tag_negative_behavior_count_check" CHECK (("negative_behavior_count" >= 0)),
    CONSTRAINT "user_interest_tag_positive_behavior_count_check" CHECK (("positive_behavior_count" >= 0)),
    CONSTRAINT "user_interest_tag_source_check" CHECK (("source" = ANY (ARRAY['onboarding'::"text", 'system'::"text", 'behavior'::"text", 'manual'::"text", 'mixed'::"text"])))
);


CREATE TABLE IF NOT EXISTS "public"."user_tag_preference" (
    "id_user" "uuid" NOT NULL,
    "id_tag" "uuid" NOT NULL,
    "preference_weight" numeric DEFAULT 0,
    "last_interacted_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"()
);

-- Compatibility columns for a local table whose historical definition is
-- older than the linked schema used by the later admin-report migration.
ALTER TABLE public.report
    ADD COLUMN IF NOT EXISTS report_category text,
    ADD COLUMN IF NOT EXISTS target_type text,
    ADD COLUMN IF NOT EXISTS target_id uuid,
    ADD COLUMN IF NOT EXISTS feature_area text,
    ADD COLUMN IF NOT EXISTS report_content text,
    ADD COLUMN IF NOT EXISTS images jsonb,
    ADD COLUMN IF NOT EXISTS status text DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS resolved_at timestamp with time zone,
    ADD COLUMN IF NOT EXISTS action_taken text,
    ADD COLUMN IF NOT EXISTS created_at timestamp with time zone DEFAULT now();

ALTER TABLE public.food
    ADD COLUMN IF NOT EXISTS food_type_id uuid,
    ADD COLUMN IF NOT EXISTS cover_image text,
    ADD COLUMN IF NOT EXISTS gallery jsonb,
    ADD COLUMN IF NOT EXISTS short_description text,
    ADD COLUMN IF NOT EXISTS ingredients text,
    ADD COLUMN IF NOT EXISTS taste_profile text,
    ADD COLUMN IF NOT EXISTS dietary_warnings text,
    ADD COLUMN IF NOT EXISTS average_rating numeric(2,1),
    ADD COLUMN IF NOT EXISTS review_count integer DEFAULT 0,
    ADD COLUMN IF NOT EXISTS detailed_description text,
    ADD COLUMN IF NOT EXISTS id_province uuid,
    ADD COLUMN IF NOT EXISTS id_region uuid,
    ADD COLUMN IF NOT EXISTS id_zone uuid,
    ADD COLUMN IF NOT EXISTS status text DEFAULT 'active',
    ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();

ALTER TABLE public.place
    ADD COLUMN IF NOT EXISTS old_province uuid,
    ADD COLUMN IF NOT EXISTS latitude double precision,
    ADD COLUMN IF NOT EXISTS longitude double precision,
    ADD COLUMN IF NOT EXISTS estimated_duration_minutes integer,
    ADD COLUMN IF NOT EXISTS gallery jsonb,
    ADD COLUMN IF NOT EXISTS average_rating numeric,
    ADD COLUMN IF NOT EXISTS review_count bigint,
    ADD COLUMN IF NOT EXISTS cover_image text,
    ADD COLUMN IF NOT EXISTS minimum_price numeric,
    ADD COLUMN IF NOT EXISTS maximum_price numeric,
    ADD COLUMN IF NOT EXISTS price_level numeric,
    ADD COLUMN IF NOT EXISTS phone text,
    ADD COLUMN IF NOT EXISTS website text,
    ADD COLUMN IF NOT EXISTS short_description text,
    ADD COLUMN IF NOT EXISTS address text,
    ADD COLUMN IF NOT EXISTS id_province uuid,
    ADD COLUMN IF NOT EXISTS id_region uuid,
    ADD COLUMN IF NOT EXISTS id_zone uuid,
    ADD COLUMN IF NOT EXISTS source text,
    ADD COLUMN IF NOT EXISTS source_place_id text,
    ADD COLUMN IF NOT EXISTS detailed_description text,
    ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();

ALTER TABLE public.rate_item
    ADD COLUMN IF NOT EXISTS item_type text,
    ADD COLUMN IF NOT EXISTS created_at timestamp with time zone DEFAULT now(),
    ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();

ALTER TABLE public.plan_component
    ADD COLUMN IF NOT EXISTS id_place uuid,
    ADD COLUMN IF NOT EXISTS visit_order integer,
    ADD COLUMN IF NOT EXISTS slot text,
    ADD COLUMN IF NOT EXISTS estimated_travel_minutes integer,
    ADD COLUMN IF NOT EXISTS cb_score double precision,
    ADD COLUMN IF NOT EXISTS cf_score double precision,
    ADD COLUMN IF NOT EXISTS final_score double precision,
    ADD COLUMN IF NOT EXISTS entry_type text DEFAULT 'place',
    ADD COLUMN IF NOT EXISTS start_time text,
    ADD COLUMN IF NOT EXISTS end_time text,
    ADD COLUMN IF NOT EXISTS travel_time_car_seconds integer,
    ADD COLUMN IF NOT EXISTS travel_time_bike_seconds integer,
    ADD COLUMN IF NOT EXISTS travel_distance_car_meters integer,
    ADD COLUMN IF NOT EXISTS travel_distance_bike_meters integer,
    ADD COLUMN IF NOT EXISTS tags text[];

CREATE TABLE IF NOT EXISTS "public"."place_translation" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "place_id" "uuid" NOT NULL,
    "lang_code" "text" NOT NULL,
    "name" "text",
    "description" "text",
    "timespan" "text",
    "timeclose" "text",
    "address" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."tag" (
    "id_tag" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tag_code" "text" NOT NULL,
    "tag_name" "text" NOT NULL,
    "description" "text",
    "tag_group" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_user_selectable" boolean DEFAULT false NOT NULL,
    "use_for_auto_tagging" boolean DEFAULT true NOT NULL
);

-- Historical view creator absent from the local migration repository. Keep
-- the 22-column shape expected by the planning migrations; the feature
-- migration replaces it with the detailed-description shape later.
CREATE OR REPLACE VIEW public.place_localized_en
WITH (security_invoker = true)
AS
SELECT
  p.id_place,
  p.id_place_subcategory,
  p.status,
  p.old_province,
  p.latitude,
  p.longitude,
  p.estimated_duration_minutes,
  p.gallery,
  p.average_rating,
  p.review_count,
  p.cover_image,
  p.minimum_price,
  p.maximum_price,
  p.price_level,
  p.phone,
  p.website,
  p.timespan,
  p.timeclose,
  coalesce(pt.name, p.name) AS name,
  coalesce(pt.description, p.short_description) AS short_description,
  coalesce(pt.address, p.address) AS address,
  p.id_province
FROM public.place p
LEFT JOIN public.place_translation pt
  ON pt.place_id = p.id_place
 AND pt.lang_code = 'en';

-- Primary and unique constraints required by later local migrations.

ALTER TABLE ONLY "public"."tag"
    ADD CONSTRAINT "tag_pkey" PRIMARY KEY ("id_tag");

ALTER TABLE ONLY "public"."place_translation"
    ADD CONSTRAINT "place_translation_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."place_translation"
    ADD CONSTRAINT "place_translation_place_id_lang_code_key" UNIQUE ("place_id", "lang_code");

ALTER TABLE ONLY "public"."activity"
    ADD CONSTRAINT "activity_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."activity_tag"
    ADD CONSTRAINT "activity_tag_pkey" PRIMARY KEY ("id_activity", "id_tag");

ALTER TABLE ONLY "public"."activity_translation"
    ADD CONSTRAINT "activity_translation_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."activity_translation"
    ADD CONSTRAINT "activity_translation_unique" UNIQUE ("activity_id", "lang_code");

ALTER TABLE ONLY "public"."pre-written reply"
    ADD CONSTRAINT "pre_written_reply_pkey" PRIMARY KEY ("id_canned_reply");

ALTER TABLE ONLY "public"."culture"
    ADD CONSTRAINT "culture_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."culture_tag"
    ADD CONSTRAINT "culture_tag_pkey" PRIMARY KEY ("id_culture", "id_tag");

ALTER TABLE ONLY "public"."culture_translation"
    ADD CONSTRAINT "culture_translation_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."culture_translation"
    ADD CONSTRAINT "culture_translation_unique" UNIQUE ("culture_id", "lang_code");

ALTER TABLE ONLY "public"."food_tag"
    ADD CONSTRAINT "food_tag_pkey" PRIMARY KEY ("id_food", "id_tag");

ALTER TABLE ONLY "public"."food_translation"
    ADD CONSTRAINT "food_translation_food_id_lang_code_key" UNIQUE ("food_id", "lang_code");

ALTER TABLE ONLY "public"."food_translation"
    ADD CONSTRAINT "food_translation_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."food_type"
    ADD CONSTRAINT "food_type_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."food_type_translation"
    ADD CONSTRAINT "food_type_translation_food_type_id_lang_code_key" UNIQUE ("food_type", "lang_code");

ALTER TABLE ONLY "public"."food_type_translation"
    ADD CONSTRAINT "food_type_translation_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."food_type"
    ADD CONSTRAINT "food_type_type_key" UNIQUE ("type");

ALTER TABLE ONLY "public"."forum_comment_like"
    ADD CONSTRAINT "forum_comment_like_pkey" PRIMARY KEY ("id_comment", "id_user");

ALTER TABLE ONLY "public"."forum_post_bookmark"
    ADD CONSTRAINT "forum_post_bookmark_pkey" PRIMARY KEY ("id_post", "id_user");

ALTER TABLE ONLY "public"."forum_post_like"
    ADD CONSTRAINT "forum_post_like_pkey" PRIMARY KEY ("id_post", "id_user");

ALTER TABLE ONLY "public"."forum_post_media"
    ADD CONSTRAINT "forum_post_media_pkey" PRIMARY KEY ("id_media");

ALTER TABLE ONLY "public"."forum_post_report"
    ADD CONSTRAINT "forum_post_report_pkey" PRIMARY KEY ("id_report");

ALTER TABLE ONLY "public"."forum_user_block"
    ADD CONSTRAINT "forum_user_block_pkey" PRIMARY KEY ("blocker_user_id", "blocked_user_id");

ALTER TABLE ONLY "public"."forum_user_follow"
    ADD CONSTRAINT "forum_user_follow_pkey" PRIMARY KEY ("follower_user_id", "following_user_id");

ALTER TABLE ONLY "public"."language"
    ADD CONSTRAINT "language_pkey" PRIMARY KEY ("code");

ALTER TABLE ONLY "public"."local_product_tag"
    ADD CONSTRAINT "local_product_tag_pkey" PRIMARY KEY ("id_local_product", "id_tag");

ALTER TABLE ONLY "public"."local_products"
    ADD CONSTRAINT "local_products_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."local_products_translation"
    ADD CONSTRAINT "local_products_translation_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."local_products_translation"
    ADD CONSTRAINT "local_products_translation_unique" UNIQUE ("local_product_id", "lang_code");

ALTER TABLE ONLY "public"."old_province"
    ADD CONSTRAINT "old_province_pkey" PRIMARY KEY ("id_province");

ALTER TABLE ONLY "public"."province"
    ADD CONSTRAINT "province_name_key" UNIQUE ("name");

ALTER TABLE ONLY "public"."province"
    ADD CONSTRAINT "province_pkey" PRIMARY KEY ("id_province");

ALTER TABLE ONLY "public"."province_translation"
    ADD CONSTRAINT "province_translation_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."province_translation"
    ADD CONSTRAINT "province_translation_unique" UNIQUE ("province_id", "lang_code");

ALTER TABLE ONLY "public"."recommendation_cache"
    ADD CONSTRAINT "recommendation_cache_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."region"
    ADD CONSTRAINT "region_name_key" UNIQUE ("name");

ALTER TABLE ONLY "public"."region"
    ADD CONSTRAINT "region_pkey" PRIMARY KEY ("id_region");

ALTER TABLE ONLY "public"."region"
    ADD CONSTRAINT "region_region_code_key" UNIQUE ("region_code");

ALTER TABLE ONLY "public"."tag_content_type"
    ADD CONSTRAINT "tag_content_type_pkey" PRIMARY KEY ("id_tag", "content_type");

ALTER TABLE ONLY "public"."trip_interest_choice"
    ADD CONSTRAINT "trip_interest_choice_pkey" PRIMARY KEY ("id_trip_plan", "id_trip_interest_option");

ALTER TABLE ONLY "public"."trip_interest_option"
    ADD CONSTRAINT "trip_interest_option_option_code_key" UNIQUE ("option_code");

ALTER TABLE ONLY "public"."trip_interest_option"
    ADD CONSTRAINT "trip_interest_option_pkey" PRIMARY KEY ("id_trip_interest_option");

ALTER TABLE ONLY "public"."trip_interest_option_subcategory"
    ADD CONSTRAINT "trip_interest_option_subcategory_pkey" PRIMARY KEY ("id_trip_interest_option", "id_place_subcategory");

ALTER TABLE ONLY "public"."trip_interest_option_tag"
    ADD CONSTRAINT "trip_interest_option_tag_pkey" PRIMARY KEY ("id_trip_interest_option", "id_tag");

ALTER TABLE ONLY "public"."trip_plan"
    ADD CONSTRAINT "trip_plan_pkey" PRIMARY KEY ("id_trip_plan");

ALTER TABLE ONLY "public"."use_popular_app_category"
    ADD CONSTRAINT "use_popular_app_category_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."user_explore_event"
    ADD CONSTRAINT "user_explore_event_pkey" PRIMARY KEY ("id_event");

ALTER TABLE ONLY "public"."user_interest_tag"
    ADD CONSTRAINT "user_interest_tag_pkey" PRIMARY KEY ("id_user", "id_tag");

ALTER TABLE ONLY "public"."user_tag_preference"
    ADD CONSTRAINT "user_tag_preference_pkey" PRIMARY KEY ("id_user", "id_tag");

ALTER TABLE ONLY "public"."zone"
    ADD CONSTRAINT "zone_name_key" UNIQUE ("name");

ALTER TABLE ONLY "public"."zone"
    ADD CONSTRAINT "zone_pkey" PRIMARY KEY ("id_zone");

ALTER TABLE ONLY "public"."zone"
    ADD CONSTRAINT "zone_zone_code_key" UNIQUE ("zone_code");
