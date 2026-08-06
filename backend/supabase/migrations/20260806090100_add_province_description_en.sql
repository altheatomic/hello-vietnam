-- Adds an English description column to province (post-merger table), so
-- Recommend can keep serving a translated description without a real-time
-- translation call after the switch from old_province -> province (see
-- cf_service/services/recommend_service.py, /scripts/translate_province_descriptions.py).
-- Mirrors old_province.description_en, added by
-- 20260724000100_add_old_province_description_en.sql for the same reason.
-- Populated once by scripts/translate_province_descriptions.py (adjusted to
-- target `province` — run manually after this migration is applied, not
-- automated here).
-- Safe to re-run: uses IF NOT EXISTS.

alter table if exists public.province
  add column if not exists description_en text;
