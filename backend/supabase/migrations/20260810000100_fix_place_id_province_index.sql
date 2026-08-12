-- Perf audit (2026-08-10) found idx_place_old_province (see
-- 20260719000100_add_place_query_indexes.sql) covers a column the
-- pipeline no longer filters on. Since 20260806090200, every read path
-- (cf_service/db/place_repository.py fetch_places_required_filter /
-- fetch_places_near_point, routes/recommend.py) filters on
-- place.id_province + place.status, which has NO index — falling back to
-- a sequential scan on every single Plan Trip / Recommend request.
--
-- Composite index (not two separate single-column indexes): both columns
-- are always filtered together in these queries
-- (.eq("id_province", ...).eq("status", "active")), so one composite
-- index serves the actual query shape directly.
--
-- idx_place_old_province is left in place — unused by current code, but
-- removing it is a separate cleanup out of scope for this fix.

create index if not exists idx_place_id_province_status
  on place(id_province, status);
