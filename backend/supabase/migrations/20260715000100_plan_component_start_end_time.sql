-- =============================================================================
-- Add start_time / end_time to plan_component
-- Fixes: save_plan()/get_plan() never persisted the per-place schedule times
-- computed by schedule_builder.build_day_schedule(), so any trip reloaded via
-- getPlan() (the default path after planTrip() with save_plan=true) lost
-- start_time and the Flutter UI fell back to a slot-based default time,
-- showing the same clock time for every place sharing a slot.
-- Text type matches the 'HH:MM' string format produced by
-- schedule_builder._fmt() and is consistent with sibling text columns
-- (time_part, slot) already on this table.
-- Safe to re-run: uses IF NOT EXISTS.
-- =============================================================================

alter table plan_component
  add column if not exists start_time text,
  add column if not exists end_time   text;
