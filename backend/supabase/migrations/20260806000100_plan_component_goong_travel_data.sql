-- =============================================================================
-- Add car/bike travel time & distance columns to plan_component
-- Goong Distance Matrix integration: after Simulated Annealing (module3) picks
-- the final route for a day, we fetch real travel time/distance from Goong
-- (vehicle=bike, used to recompute the final start_time/end_time; vehicle=car,
-- display-only) for each edge of the route and persist both here at save_plan()
-- time, rather than recomputing on every view/share (see
-- cf_service/services/goong_client.py, trip_planner.py).
-- All 4 columns are nullable: the FIRST place of each day has no predecessor
-- within the day, so it carries no travel time/distance from a previous stop.
-- Safe to re-run: uses IF NOT EXISTS.
-- =============================================================================

alter table plan_component
  add column if not exists travel_time_car_seconds     int,
  add column if not exists travel_time_bike_seconds     int,
  add column if not exists travel_distance_car_meters   int,
  add column if not exists travel_distance_bike_meters  int;
