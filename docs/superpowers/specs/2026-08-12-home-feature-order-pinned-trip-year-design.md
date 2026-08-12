# Home Feature Order and Pinned Trip Year Design

## Context

The Home quick-action grid currently presents its eight features in an order
that places Trip Planner first and Recommend and Explore on the second row. The
desired order prioritizes destination discovery before itinerary creation.

The Leisure and Business Trip Planner flows both reach `TripDurationPage` and
use the shared `DateRangeCalendar`. That calendar is rendered inside the
planner scaffold's outer `CustomScrollView`. In this unbounded layout, its year
navigation row is part of the same content as the summary, one-day toggle, and
month cards, so the year controls scroll away with the months.

## Goals

1. Display Home quick actions in this exact row-major order:
   `Recommend`, `Explore`, `Trip Planner`, `Forum`, `Translate`, `AI Search`,
   `Send Report`, `Popular Apps`.
2. Keep only the year navigation row pinned at the top of the Trip Planner's
   date-selection viewport while month content scrolls.
3. Apply the calendar behavior consistently to Leisure and Business trips.
4. Preserve all existing routes, icons, localization, date selection rules,
   one-day mode, and visual styling.

## Considered Approaches

### 1. Reuse the planner scaffold's sticky body header

Extract the existing year navigation UI into a reusable public widget. Let
`TripDurationPage` own the visible year, place the year widget in
`PlannerStepScaffold.stickyBodyHeader`, and render `DateRangeCalendar` without
its internal year row. The calendar receives the controlled year and rebuilds
its month cards when the year changes.

This is the selected approach. It uses the scaffold's existing pinned-header
mechanism, keeps the summary and one-day toggle in normal scroll content, and
avoids nested scrolling or duplicated visuals.

### 2. Overlay the year selector above the calendar

A `Stack` could place the year controls over the scrolling calendar. This is a
smaller structural change, but it requires manual padding and offset handling,
can obscure content at different screen sizes, and complicates accessibility
and hit testing. This approach is rejected.

### 3. Rewrite the calendar as a sliver collection

The calendar could expose a pinned year sliver followed by summary, toggle,
and month slivers. This would provide direct scroll composition, but it would
substantially expand the shared calendar API for one pinned row and increase
regression risk for other consumers such as the start-date picker sheet. This
approach is rejected.

## Home Quick-Action Ordering

`homeFeatures` remains the single source of truth for Home quick actions. Only
the order of its existing `FeatureItem` entries changes. The grid continues to
render four columns in row-major order, producing:

- First row: Recommend, Explore, Trip Planner, Forum.
- Second row: Translate, AI Search, Send Report, Popular Apps.

No feature is added or removed. Each item retains its current title, icon, and
route, including the saved-trip badge behavior attached to Trip Planner.

## Calendar Architecture and Behavior

The current private year row is extracted as a reusable year navigation widget
that accepts the displayed year and previous/next callbacks. Its styling and
left/right controls remain unchanged.

`DateRangeCalendar` gains a controlled visible-year input and an option to hide
its internal year navigation. When the controlled year changes, the calendar
updates the 12 rendered month cards while retaining the selected start/end
dates and one-day mode. Existing consumers keep the internal year row by
default, so the start-date picker sheet and any standalone bounded calendar do
not change behavior.

`TripDurationPage` initializes its visible year from the current selectable
date. It passes the extracted navigation widget to
`PlannerStepScaffold.stickyBodyHeader` and configures `DateRangeCalendar` to use
that year without rendering a duplicate row. The sticky header pins only after
it reaches the top of the planner's scroll viewport, following standard pinned
sliver behavior.

The range summary, `1-Day Trip` toggle, and every month card remain below the
sticky header and continue scrolling. Changing year updates the months but does
not clear a previously selected range. Existing minimum-date checks continue
to disable dates before `firstDate`.

Both Leisure and Business routes already converge on `TripDurationPage`, so no
trip-type-specific branch or duplicated calendar implementation is required.

## Error Handling and Compatibility

- The year navigation remains deterministic and local; it performs no network
  or storage operation.
- The shared calendar's default constructor behavior remains backward
  compatible for callers that do not request an external pinned header.
- Date selection callbacks and range calculations do not change.
- Localization continues to use the existing `AppStrings` mappings.
- Light and dark themes reuse the existing year-control colors and surfaces.

## Testing and Acceptance Criteria

Tests are written before implementation and verify:

1. `homeFeatures` exposes exactly the requested eight-item order and preserves
   the expected routes.
2. `TripDurationPage` renders one year navigation row and one shared
   `DateRangeCalendar` for a Leisure wizard.
3. The same calendar structure is present for a Business wizard.
4. Scrolling the month content moves the summary, one-day toggle, and month
   cards while the year navigation row keeps the same vertical position.
5. Tapping previous or next year updates the displayed year and rendered month
   dates without clearing the selected range.
6. Existing date-range, one-day mode, minimum-date, localization, and unbounded
   layout tests continue to pass.

The focused Home and calendar widget tests must pass, followed by Flutter
analysis of the changed files. No backend, database, route, or deployment
change is part of this work.
