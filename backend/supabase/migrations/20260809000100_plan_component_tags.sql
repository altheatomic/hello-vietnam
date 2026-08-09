-- =============================================================================
-- Add tags to plan_component
-- Same class of bug as start_time/end_time (20260715000300) and the Goong
-- travel columns (20260806000100): _format_place() (cf_service/services/
-- trip_planner.py) computes a "tags" field (real tag_name list for the
-- place, filtered/capped by _extract_place_tag_names()) at plan() request
-- time, but save_plan() never persisted it — so any trip reloaded via
-- get_plan() (the default path after planTrip() with save_plan=true) or
-- copied via clone_plan() lost its tags, even though a freshly-generated
-- trip showed them correctly.
-- text[] (not jsonb): the value is already a flat list of tag_name strings —
-- confidence_score/tag_code filtering already happened in
-- _extract_place_tag_names() before this point, so no nested structure needs
-- to survive into storage. Nullable, no default — consistent with the 4
-- Goong columns.
-- Safe to re-run: uses IF NOT EXISTS.
-- =============================================================================

alter table plan_component
  add column if not exists tags text[];
