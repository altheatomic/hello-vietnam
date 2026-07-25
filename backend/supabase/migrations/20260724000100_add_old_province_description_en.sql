-- Adds an English description column to old_province so the Recommend
-- feature can serve a translated description without a real-time
-- translation call. Populated once by
-- cf_service/scripts/translate_province_descriptions.py.

alter table if exists public.old_province
  add column if not exists description_en text;
