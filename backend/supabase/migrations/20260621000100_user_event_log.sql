-- User implicit-signal event log for CF pipeline.
-- Aggregated per (user, place, event_type) to avoid unbounded row growth.

create table if not exists user_event_log (
    id_user    uuid not null references user_account(id_user) on delete cascade,
    id_place   uuid not null references place(id_place) on delete cascade,
    event_type text not null,   -- view_thumbnail | view_detail | view_all_photos | share
    event_count int  not null default 1,
    first_at   timestamp with time zone not null default now(),
    last_at    timestamp with time zone not null default now(),
    primary key (id_user, id_place, event_type)
);

create index if not exists idx_uel_user      on user_event_log(id_user);
create index if not exists idx_uel_event_type on user_event_log(event_type);
