# Location Backend Module

This folder groups backend artifacts for user location preference.

## Related files

- Table migration:
  - `backend/supabase/migrations/20260528000100_add_user_location_preference.sql`
- Edge Function:
  - `backend/supabase/functions/users/location-preference/`

## Purpose

Store per-user location context (`gps`, `manual`, `map_pin`) for:

- nearby search
- regional culture/food recommendations
- personalized trip planning
- travel diary and location-driven features

