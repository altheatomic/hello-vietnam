create table if not exists public.favorite_activity (
    id_user uuid not null references public.user_account(id_user) on delete cascade,
    id_activity uuid not null references public.activity(id) on delete cascade,
    created_at timestamp with time zone not null default now(),
    primary key (id_user, id_activity)
);

create table if not exists public.favorite_culture (
    id_user uuid not null references public.user_account(id_user) on delete cascade,
    id_culture uuid not null references public.culture(id) on delete cascade,
    created_at timestamp with time zone not null default now(),
    primary key (id_user, id_culture)
);

create table if not exists public.favorite_local_product (
    id_user uuid not null references public.user_account(id_user) on delete cascade,
    id_local_product uuid not null references public.local_products(id) on delete cascade,
    created_at timestamp with time zone not null default now(),
    primary key (id_user, id_local_product)
);

create index if not exists idx_favorite_activity_user_created_at
    on public.favorite_activity (id_user, created_at desc);

create index if not exists idx_favorite_culture_user_created_at
    on public.favorite_culture (id_user, created_at desc);

create index if not exists idx_favorite_local_product_user_created_at
    on public.favorite_local_product (id_user, created_at desc);

alter table if exists public.favorite_activity enable row level security;
alter table if exists public.favorite_culture enable row level security;
alter table if exists public.favorite_local_product enable row level security;

revoke all on table public.favorite_activity from anon, authenticated;
revoke all on table public.favorite_culture from anon, authenticated;
revoke all on table public.favorite_local_product from anon, authenticated;

comment on table public.favorite_activity is
  'User wishlist rows for activity entities.';

comment on table public.favorite_culture is
  'User wishlist rows for culture entities.';

comment on table public.favorite_local_product is
  'User wishlist rows for local product entities.';
