-- Migration: extend use_popular_app for full guide support + add category management table.

-- ── 1. Extend the existing use_popular_app table ──────────────────────────────

alter table public.use_popular_app
  add column if not exists category_id  text,
  add column if not exists package_name text,
  add column if not exists store_url    text,
  add column if not exists is_active    boolean not null default true,
  add column if not exists display_order int     not null default 0,
  add column if not exists platform     text    not null default 'Both',
  add column if not exists created_at   timestamp with time zone default now();

-- Backfill category_id from the legacy "type" column (already lowercase strings).
update public.use_popular_app
set category_id = lower(type)
where category_id is null and type is not null;

-- ── 2. Category management table ─────────────────────────────────────────────

create table if not exists public.use_popular_app_category (
  id          text primary key,
  label       text not null,
  color_index int  not null default 0,
  created_at  timestamp with time zone default now()
);

-- Default categories (match defaultAppCategories in popular_app_guide.dart).
insert into public.use_popular_app_category (id, label, color_index) values
  ('transport', 'Transport', 0),
  ('chat',      'Chat',      1),
  ('payment',   'Payment',   2),
  ('delivery',  'Delivery',  3),
  ('other',     'Other',     4)
on conflict (id) do nothing;

-- ── 3. Seed 6 real Vietnamese apps (runs only when table has no seeded rows) ──

do $$
begin
  if not exists (
    select 1 from public.use_popular_app where package_name is not null limit 1
  ) then

    insert into public.use_popular_app
      (name, type, category_id, package_name, store_url,
       url_image, url_video, description, guide,
       is_active, display_order, platform)
    values

      -- 1. Zalo — Chat
      ('Zalo', 'chat', 'chat', 'com.zing.zalo',
       'https://play.google.com/store/apps/details?id=com.zing.zalo',
       'https://picsum.photos/seed/zalo/80/80', null,
       'Vietnam''s most popular messaging app — chat, voice/video calls, and news feed.',
       '1. Download Zalo and enter your phone number.' || chr(10) ||
       '2. Verify with the OTP sent via SMS.' || chr(10) ||
       '3. Allow contacts permission so Zalo can sync friends.' || chr(10) ||
       '4. Tap the chat icon to start a conversation.' || chr(10) ||
       '5. Use "Official Accounts" to follow brands and news.',
       true, 1, 'Both'),

      -- 2. MoMo — Payment
      ('MoMo', 'payment', 'payment', 'vn.momo.standalone',
       'https://play.google.com/store/apps/details?id=vn.momo.standalone',
       'https://picsum.photos/seed/momo/80/80', null,
       'Vietnam''s leading e-wallet — pay bills, top up phones, and transfer money instantly.',
       '1. Download MoMo and register with your phone number.' || chr(10) ||
       '2. Link your bank account or top up via ATM.' || chr(10) ||
       '3. Scan QR codes at stores to pay.' || chr(10) ||
       '4. Use "Send Money" to transfer to any MoMo user for free.' || chr(10) ||
       '5. Pay electricity, water, and internet bills in the "Utilities" tab.',
       true, 2, 'Both'),

      -- 3. Grab — Transport
      ('Grab', 'transport', 'transport', 'com.grabtaxi.passenger',
       'https://play.google.com/store/apps/details?id=com.grabtaxi.passenger',
       'https://picsum.photos/seed/grab/80/80', null,
       'Book motorbike taxis, cars, and tuk-tuks; order food and send parcels — all in one app.',
       '1. Download Grab from the Play Store or App Store.' || chr(10) ||
       '2. Register with your Vietnamese phone number.' || chr(10) ||
       '3. Tap "Transport" to book a GrabBike or GrabCar.' || chr(10) ||
       '4. Enter your destination and confirm the fare.' || chr(10) ||
       '5. Track your driver in real time on the map.',
       true, 3, 'Both'),

      -- 4. Shopee — Delivery / E-commerce
      ('Shopee', 'delivery', 'delivery', 'com.shopee.vn',
       'https://play.google.com/store/apps/details?id=com.shopee.vn',
       'https://picsum.photos/seed/shopee/80/80', null,
       'Southeast Asia''s largest e-commerce platform — shop, compare prices, and get fast delivery.',
       '1. Download Shopee and create a free account.' || chr(10) ||
       '2. Browse by category or search for products.' || chr(10) ||
       '3. Check seller ratings and product reviews before buying.' || chr(10) ||
       '4. Apply vouchers at checkout for extra savings.' || chr(10) ||
       '5. Track your order live after payment.',
       true, 4, 'Both'),

      -- 5. Be — Transport (local VN alternative to Grab)
      ('Be', 'transport', 'transport', 'com.be.driver',
       'https://play.google.com/store/apps/details?id=com.be.driver',
       'https://picsum.photos/seed/be-app/80/80', null,
       'Vietnam-born ride-hailing app with competitive fares and no surge pricing.',
       '1. Install Be from the store.' || chr(10) ||
       '2. Sign up with your phone number — no email needed.' || chr(10) ||
       '3. Choose beBike (motorbike) or beCar.' || chr(10) ||
       '4. Pin your pickup and drop-off on the map.' || chr(10) ||
       '5. Pay by cash or BeWallet.',
       true, 5, 'Android'),

      -- 6. TikTok — Other (entertainment / social)
      ('TikTok', 'other', 'other', 'com.zhiliaoapp.musically',
       'https://play.google.com/store/apps/details?id=com.zhiliaoapp.musically',
       'https://picsum.photos/seed/tiktok/80/80', null,
       'Short-video platform hugely popular with Vietnamese youth for local trends and entertainment.',
       '1. Download TikTok and create a free account.' || chr(10) ||
       '2. Browse the "For You" feed — it personalises to your interests.' || chr(10) ||
       '3. Follow Vietnamese creators to see local content.' || chr(10) ||
       '4. Use the Discover tab to search trending topics.',
       true, 6, 'Both');

  end if;
end $$;

-- ── 4. Row-Level Security (add to match Food / User patterns) ────────────────
-- Public read, admin write (adjust service_role policy to your setup).

alter table public.use_popular_app          enable row level security;
alter table public.use_popular_app_category enable row level security;

-- Allow anyone to read (user app needs unauthenticated access).
do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'use_popular_app' and policyname = 'allow_public_read'
  ) then
    execute 'create policy allow_public_read on public.use_popular_app
             for select using (true)';
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'use_popular_app_category' and policyname = 'allow_public_read'
  ) then
    execute 'create policy allow_public_read on public.use_popular_app_category
             for select using (true)';
  end if;
end $$;

-- Admin write: authenticated users whose role = 'admin' in user_account.
-- Adjust the sub-select to match your auth setup (service role key bypasses RLS entirely).
do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'use_popular_app' and policyname = 'allow_admin_write'
  ) then
    execute $pol$
      create policy allow_admin_write on public.use_popular_app
      for all using (
        exists (
          select 1 from public.user_account
          where id_user = auth.uid()::uuid and role = 'admin'
        )
      )
    $pol$;
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'use_popular_app_category' and policyname = 'allow_admin_write'
  ) then
    execute $pol$
      create policy allow_admin_write on public.use_popular_app_category
      for all using (
        exists (
          select 1 from public.user_account
          where id_user = auth.uid()::uuid and role = 'admin'
        )
      )
    $pol$;
  end if;
end $$;
