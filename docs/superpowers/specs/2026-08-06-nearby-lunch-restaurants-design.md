# Nearby Lunch Restaurants via Google Maps

## Goal

Add a restaurant-discovery action to every itinerary day detail screen. The action is placed after the activity selected as the lunch anchor and opens Google Maps with a restaurant search centered on that activity's coordinates.

## Design

- `selectLunchAnchor` is a pure helper over `TripPlannerActivityData`.
- Lunch-break synthetic entries are ignored.
- The helper selects the last real activity whose scheduled start time is before 12:00.
- If a day has no activity before noon, it selects the first real activity so every non-empty itinerary day still exposes the action.
- `buildGoogleMapsSearchQueryUri` remains the single URL builder. The lunch action passes `restaurants near <latitude>,<longitude>, Vietnam`, so coordinates are the primary location source and cannot accidentally resolve to another province because of a name or address.
- Invalid or placeholder coordinates disable the action and show an explanatory message.
- No Supabase schema, backend endpoint, or additional dependency is required.

## Files

- Add `frontend/lib/features/planner/presentation/lunch_anchor_selector.dart`.
- Add `frontend/lib/features/planner/presentation/widgets/lunch_discovery_card.dart`.
- Modify `frontend/lib/features/planner/presentation/trip_day_detail_page.dart` to select the anchor, render the card after it, and invoke Google Maps.
- Add selector and widget tests; extend the existing Maps URL tests with coordinate-based restaurant search coverage.

## Error handling

The card is rendered for every day with at least one real activity. It is disabled when the selected activity has invalid coordinates. If `launchUrl` returns false, the detail page shows the existing Google Maps failure snackbar.

## Verification

Run the focused Maps and planner widget tests. Confirm the generated URL contains the lunch anchor's coordinates and that no card is rendered for an empty day.
