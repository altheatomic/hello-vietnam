-- Perf audit (planTrip pipeline) found no index on either filter column
-- used by db/place_repository.py fetch_places_required_filter():
--   .eq("old_province", province_id)
--   .eq("place_subcategory.is_itinerary_eligible", True)
-- Both queries were falling back to sequential scans. Safe to re-run
-- (IF NOT EXISTS).

create index if not exists idx_place_old_province
  on place(old_province);

create index if not exists idx_place_subcategory_eligible
  on place_subcategory(is_itinerary_eligible);
