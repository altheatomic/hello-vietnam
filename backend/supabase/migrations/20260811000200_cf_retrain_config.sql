create table public.cf_retrain_config (
    singleton_id smallint primary key,
    hour_utc     smallint not null,
    minute_utc   smallint not null,
    updated_at   timestamp with time zone not null default now(),
    updated_by   uuid null references public.user_account(id_user),
    constraint cf_retrain_config_singleton_check check (singleton_id = 1),
    constraint cf_retrain_config_hour_check check (hour_utc between 0 and 23),
    constraint cf_retrain_config_minute_check check (minute_utc between 0 and 59)
);

insert into public.cf_retrain_config (singleton_id, hour_utc, minute_utc)
values (1, 19, 0);

alter table public.cf_retrain_config enable row level security;
revoke all on table public.cf_retrain_config from anon, authenticated;

comment on table public.cf_retrain_config is
  'Singleton persisted UTC schedule for the cf_service daily_cf_retrain APScheduler job.';
