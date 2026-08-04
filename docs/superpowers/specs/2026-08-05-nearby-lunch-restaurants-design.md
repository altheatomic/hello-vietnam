# Nearby Lunch Restaurants Design

## Status

Approved in conversation on 2026-08-05.

## Objective

Add one lunch discovery action to every non-empty day in the detailed itinerary screen. The action appears immediately after the scheduled place selected as the day's lunch anchor. Tapping it opens Google Maps and searches for all nearby restaurants around that place's coordinates.

The feature is limited to the detailed day screen. It does not appear on the itinerary summary screen and does not add a restaurant to the generated itinerary.

## Product decisions

- Use a universal Google Maps search URL rather than Google Places API.
- Do not require a Google Maps API key or backend request.
- Search for all nearby restaurants; do not filter by cuisine or user food preferences.
- Every scheduled place is expected to have valid latitude and longitude.
- Use `11:30-13:00` as the lunch window.
- Show exactly one lunch discovery card for every non-empty itinerary day, whether or not the backend returned a `lunch_break` entry.
- If no place occurs before 13:00, use the first scheduled place of the day as the fallback anchor.

## Current system context

The planning response already contains ordered places with `start_time`, `end_time`, latitude, and longitude. It may also contain a synthetic `lunch_break` entry.

`trip_result_page.dart` converts response places to `TripPlannerActivityData`. The conversion currently retains the start time and coordinates but discards the place end time. `trip_day_detail_page.dart` currently removes `lunch_break` entries before rendering activity cards. `maps_launcher.dart` already opens Google Maps externally through `url_launcher`.

The implementation should preserve these existing boundaries and add focused units for lunch-anchor selection, lunch-card rendering, and restaurant-map launching.

## Lunch-anchor selection

Implement the selection as a deterministic pure function over the ordered real places for one day. Synthetic `lunch_break` entries are excluded from anchor candidates.

Selection priority:

1. Among places whose valid `end_time` is within `11:30-13:00`, select the place with the latest end time.
2. If none qualify, among places whose valid `end_time` is before `11:30`, select the place with the latest end time.
3. If no place can be selected by end time, among places with a valid `start_time` before `13:00`, select the place with the latest start time.
4. If no place starts before `13:00`, select the first real place in itinerary order.
5. If the day contains no real places, return no anchor and do not render the lunch discovery card.

Boundary values `11:30` and `13:00` are included in the lunch window. Invalid or absent time strings are ignored for the corresponding comparison and may still reach the itinerary-order fallback.

The selector must return the identity or index of an existing place; it must not reorder or mutate the activity list.

## Data model

Add nullable `endTime` data to `TripPlannerActivityData` and preserve it through:

- construction from `TripPlanPlace`;
- `toJson`;
- `fromJson`.

Deserialization must remain compatible with previously serialized activity data where `endTime` is absent.

No backend response or database schema change is required.

## Detailed-day UI

Render all real place cards in their existing itinerary order. Insert one `LunchDiscoveryCard` immediately after the selected anchor card.

The card contains:

- a restaurant icon;
- title: `Ăn gì gần đây?`;
- lunch-window label: `11:30-13:00`;
- supporting text containing the anchor place name, for example `Khám phá quán ăn và nhà hàng quanh Bảo tàng Đà Nẵng`;
- a primary action: `Xem quán ăn trên Google Maps`;
- an external-navigation visual cue.

Use a light warm yellow/orange surface to distinguish the lunch decision from itinerary places. Reuse the application's rounded-card language and blue gradient for the primary action so the component remains visually consistent with the current detailed-day screen.

The discovery card is an action affordance, not an itinerary activity. It does not increase the activity or place count.

Existing synthetic `lunch_break` entries remain hidden. They must not cause a second card or change anchor selection; the same deterministic selection runs for every day.

All new user-facing strings must be added to the existing localization mechanism, including Vietnamese and English values.

## Google Maps integration

Add a focused launcher function with an interface equivalent to:

```text
openNearbyRestaurants(latitude, longitude)
```

It builds a universal Google Maps search URL using `Uri` parameter encoding:

```text
https://www.google.com/maps/search/?api=1&query=restaurants near <latitude>,<longitude>
```

Open the URL using `LaunchMode.externalApplication`. The operating system may open the Google Maps app or a capable browser. This integration does not fetch, rank, or store restaurant data inside Hello Vietnam.

The launcher should expose whether opening succeeded so the presentation layer can provide feedback without containing URL-construction logic.

## Error handling

- Treat non-finite coordinates and the placeholder pair `0,0` as invalid.
- If the anchor has invalid coordinates, keep the card visible but disable its action and show a localized explanation.
- If external launch fails or throws, show a localized Snackbar: `Không thể mở Google Maps. Vui lòng thử lại.`
- Do not crash or remove existing itinerary content because restaurant search failed.
- An empty day renders no lunch discovery card.

Although valid coordinates are an itinerary invariant, the UI guard protects mock data, stale serialized data, and malformed responses.

## Component boundaries

- Lunch-anchor selector: owns only time parsing and deterministic anchor selection.
- Lunch discovery card: owns only presentation and tap forwarding.
- Maps launcher: owns URL creation and external application launching.
- Detailed day page: composes the ordered cards, inserts the lunch card, and displays launch errors.

These units must not depend on Module 1, Module 2, Module 3, Supabase, or Google Places API.

## Testing

### Unit tests

- Select the latest place ending inside `11:30-13:00`.
- Include places ending exactly at `11:30` and `13:00`.
- Fall back to the latest place ending before `11:30`.
- Fall back to the latest valid start time before `13:00` when end times are absent or unusable.
- Fall back to the first place when all places start at or after `13:00`.
- Return no anchor for an empty real-place list.
- Ignore one or multiple synthetic `lunch_break` entries.
- Handle malformed and missing time values without throwing.
- Build a Google Maps URL containing `api=1` and an encoded restaurant query with the expected coordinates.
- Reject invalid coordinates.

### Widget tests

- Render exactly one discovery card on every non-empty detailed day.
- Insert the card immediately after the selected anchor.
- Do not count the card as an activity.
- Do not render duplicate cards when a backend `lunch_break` exists.
- Forward the anchor coordinates when the action is tapped.
- Show localized error feedback when Maps cannot be launched.
- Render no discovery card for an empty day.

### Regression checks

- Existing place cards and `Get Directions` actions retain their order and behavior.
- `Create Trip on Google Maps` continues to exclude synthetic lunch entries and builds the existing day route correctly.
- Itinerary summary cards remain unchanged.
- `TripPlannerActivityData` can deserialize data that predates the nullable `endTime` field.

## Out of scope

- Displaying restaurant results inside the app.
- Google Places API integration, API keys, quotas, billing, or caching.
- Cuisine filtering and personalization.
- Automatically inserting a chosen restaurant into the itinerary.
- Changing itinerary generation or lunch scheduling in the backend.
- Changing the summary screen.

## Acceptance criteria

The feature is complete when every non-empty detailed itinerary day displays exactly one nearby-restaurant action after the correctly selected lunch anchor, the action opens a Google Maps restaurant search around that anchor's coordinates, all selection and fallback rules are covered by tests, and existing itinerary navigation continues to work.
