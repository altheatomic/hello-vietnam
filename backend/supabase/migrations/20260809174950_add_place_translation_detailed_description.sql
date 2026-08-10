alter table public.place_translation
  add column if not exists detailed_description text;
comment on column public.place_translation.detailed_description is
  'Localized long-form place description; description remains short-form.';
create or replace view public.place_localized_en
with (security_invoker = true)
as
select
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
  coalesce(pt.name, p.name) as name,
  coalesce(pt.description, p.short_description) as short_description,
  coalesce(pt.address, p.address) as address,
  p.id_province,
  coalesce(
    pt.detailed_description,
    p.detailed_description,
    pt.description,
    p.short_description
  ) as detailed_description
from public.place p
left join public.place_translation pt
  on pt.place_id = p.id_place and pt.lang_code = 'en';
