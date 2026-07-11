create table if not exists public.reviews (
    id_review uuid primary key default uuid_generate_v4(),
    id_user uuid not null references public.user_account(id_user) on delete cascade,
    content_type text not null,
    content_id uuid not null,
    rating int not null,
    comment text not null,
    status text not null default 'published',
    moderation_result text not null default 'clean',
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    constraint reviews_content_type_check
      check (content_type in ('activity', 'culture', 'food', 'local_product', 'place', 'province', 'old_province')),
    constraint reviews_rating_check check (rating between 1 and 5),
    constraint reviews_status_check check (status in ('published', 'blocked', 'deleted')),
    constraint reviews_moderation_result_check check (moderation_result in ('clean', 'banned', 'suspected')),
    constraint reviews_one_per_user_item unique (id_user, content_type, content_id)
);

create table if not exists public.rating_summary (
    content_type text not null,
    content_id uuid not null,
    average_rating numeric(3,2),
    review_count int not null default 0,
    rating_1_count int not null default 0,
    rating_2_count int not null default 0,
    rating_3_count int not null default 0,
    rating_4_count int not null default 0,
    rating_5_count int not null default 0,
    last_reviewed_at timestamp with time zone,
    primary key (content_type, content_id),
    constraint rating_summary_content_type_check
      check (content_type in ('activity', 'culture', 'food', 'local_product', 'place', 'province', 'old_province'))
);

create table if not exists public.moderation_keyword (
    id uuid primary key default uuid_generate_v4(),
    keyword text not null,
    normalized_keyword text not null,
    match_type text not null,
    severity text not null,
    language text not null default 'all',
    is_active boolean not null default true,
    note text,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    constraint moderation_keyword_match_type_check check (match_type in ('exact', 'contains', 'regex')),
    constraint moderation_keyword_severity_check check (severity in ('banned', 'suspected')),
    constraint moderation_keyword_language_check check (language in ('vi', 'en', 'all'))
);

create index if not exists reviews_content_lookup_idx
    on public.reviews (content_type, content_id, status, updated_at desc);

create index if not exists reviews_user_lookup_idx
    on public.reviews (id_user, content_type, content_id);

create index if not exists moderation_keyword_active_idx
    on public.moderation_keyword (is_active, severity, language);

create or replace function public.set_row_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists reviews_set_updated_at on public.reviews;
create trigger reviews_set_updated_at
before update on public.reviews
for each row
execute function public.set_row_updated_at();

drop trigger if exists moderation_keyword_set_updated_at on public.moderation_keyword;
create trigger moderation_keyword_set_updated_at
before update on public.moderation_keyword
for each row
execute function public.set_row_updated_at();
