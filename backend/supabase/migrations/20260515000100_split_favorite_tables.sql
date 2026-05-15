-- Split polymorphic favorite table into 3 strongly-typed favorite tables.
-- This improves referential integrity and keeps each relation fully enforced
-- by native foreign keys.

create table if not exists public.favorite_food (
    id_user uuid not null references public.user_account(id_user) on delete cascade,
    id_food uuid not null references public.food(id_food) on delete cascade,
    created_at timestamp with time zone not null default now(),
    primary key (id_user, id_food)
);

create table if not exists public.favorite_place (
    id_user uuid not null references public.user_account(id_user) on delete cascade,
    id_place uuid not null references public.place(id_place) on delete cascade,
    created_at timestamp with time zone not null default now(),
    primary key (id_user, id_place)
);

do $$
begin
    if to_regclass('public.favorite_city') is null then
        if to_regclass('public.province') is not null then
            execute $sql$
                create table public.favorite_city (
                    id_user uuid not null references public.user_account(id_user) on delete cascade,
                    id_province uuid not null references public.province(id_province) on delete cascade,
                    created_at timestamp with time zone not null default now(),
                    primary key (id_user, id_province)
                )
            $sql$;
        elsif to_regclass('public.city_province') is not null then
            execute $sql$
                create table public.favorite_city (
                    id_user uuid not null references public.user_account(id_user) on delete cascade,
                    id_province uuid not null references public.city_province(id_city) on delete cascade,
                    created_at timestamp with time zone not null default now(),
                    primary key (id_user, id_province)
                )
            $sql$;
        else
            raise exception 'Cannot create favorite_city: neither public.province nor public.city_province exists.';
        end if;
    end if;
end
$$;

create index if not exists idx_favorite_food_user_created_at
    on public.favorite_food (id_user, created_at desc);

create index if not exists idx_favorite_place_user_created_at
    on public.favorite_place (id_user, created_at desc);

create index if not exists idx_favorite_city_user_created_at
    on public.favorite_city (id_user, created_at desc);

alter table if exists public.favorite_food enable row level security;
alter table if exists public.favorite_place enable row level security;
alter table if exists public.favorite_city enable row level security;

revoke all on table public.favorite_food from anon, authenticated;
revoke all on table public.favorite_place from anon, authenticated;
revoke all on table public.favorite_city from anon, authenticated;

do $$
begin
    if to_regclass('public.favorite') is not null then
        insert into public.favorite_food (id_user, id_food, created_at)
        select f.id_user, f.id_item, now()
        from public.favorite f
        join public.food fd on fd.id_food = f.id_item
        where lower(btrim(coalesce(f.type, ''))) = 'food'
        on conflict do nothing;

        insert into public.favorite_place (id_user, id_place, created_at)
        select f.id_user, f.id_item, now()
        from public.favorite f
        join public.place p on p.id_place = f.id_item
        where lower(btrim(coalesce(f.type, ''))) = 'place'
        on conflict do nothing;

        if to_regclass('public.province') is not null then
            insert into public.favorite_city (id_user, id_province, created_at)
            select f.id_user, f.id_item, now()
            from public.favorite f
            join public.province c on c.id_province = f.id_item
            where lower(btrim(coalesce(f.type, ''))) = 'city'
            on conflict do nothing;
        elsif to_regclass('public.city_province') is not null then
            insert into public.favorite_city (id_user, id_province, created_at)
            select f.id_user, f.id_item, now()
            from public.favorite f
            join public.city_province c on c.id_city = f.id_item
            where lower(btrim(coalesce(f.type, ''))) = 'city'
            on conflict do nothing;
        end if;
    end if;
end
$$;

comment on table public.favorite_food is
  'User wishlist rows for food entities.';

comment on table public.favorite_place is
  'User wishlist rows for place entities.';

comment on table public.favorite_city is
  'User wishlist rows for city/province entities.';

do $$
begin
    if to_regclass('public.favorite') is not null then
        execute $sql$
            comment on table public.favorite is
              'Deprecated polymorphic favorite table. Replaced by favorite_food/favorite_place/favorite_city.'
        $sql$;
    end if;
end
$$;
