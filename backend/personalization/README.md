# Personalization Backend

This folder documents backend pieces used by the `Your Travel Taste` onboarding flow.

Database tables:

- `public.user_onboarding_choice`
- `public.user_travel_profile`

Edge Function:

- `travel-preferences`

Purpose:

- store screen 1 (`trip_style`) and screen 4 (`specific_interest`) as multi-select rows
- store screen 2 (`companion_style`) and screen 3 (`pace_level`) in the per-user travel profile
- keep `budget_level` aligned with the app's current default (`mid_range`) while the budget screen is hidden
