-- Adds cover_image to old_province, backfilled from the province (admin CMS)
-- table, so recommend_service.py can read cover_image straight off
-- old_province instead of deriving it from the best-rated place per
-- province.
--
-- IMPORTANT — join key: old_province.id_province and province.id_province
-- are NOT guaranteed to be the same UUID. province.id_province was added by
-- `alter table province add column id_province uuid default
-- extensions.uuid_generate_v4()` in 20260620000100_admin_content_management.sql
-- — every pre-existing row got a freshly generated random UUID, and no
-- migration in this repo backfills it from old_province.id_province. Joining
-- on id_province equality is therefore unverified and likely to match zero
-- rows. This migration joins on name instead (trim + lower-cased).
--
-- Run the verification SELECT below FIRST and check the match count /
-- look for unmatched rows before trusting the UPDATE. Image quality of the
-- backfilled cover_image values is not in scope here — only wiring.

alter table if exists public.old_province
  add column if not exists cover_image text;

-- ── Verification — run first ────────────────────────────────────────────
-- select
--   op.id_province,
--   op.name        as old_province_name,
--   p.name         as province_name,
--   p.cover_image
-- from public.old_province op
-- left join public.province p
--   on lower(trim(p.name)) = lower(trim(op.name))
-- order by op.name;

-- ── Backfill ─────────────────────────────────────────────────────────────
update public.old_province op
set cover_image = p.cover_image
from public.province p
where lower(trim(p.name)) = lower(trim(op.name))
  and p.cover_image is not null;
