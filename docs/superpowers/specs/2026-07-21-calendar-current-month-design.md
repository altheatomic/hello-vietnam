# Calendar Current-Month Reveal Design

## Goal

When Trip Planner step 3 opens, place the current month in the visible viewport so users do not need to scroll from January. Dates before `firstDate` remain visible but disabled, dimmed, and non-interactive.

## Design

`DateRangeCalendar` assigns a `GlobalKey` to the month containing `firstDate`, falling back to the initial selection or today. After the first completed layout, it calls `Scrollable.ensureVisible` once for that month. This works with both supported layouts: the calendar's internal list when height is bounded and the parent sliver when height is unbounded.

The reveal runs only once per calendar instance. Changing the displayed year later does not force another automatic scroll and does not interrupt user navigation.

## Testing

A widget test hosts the calendar in a sliver, supplies a fixed July `firstDate`, pumps through the post-frame callback, and verifies the outer scroll position moved away from zero. Existing tests continue to verify rendering and Vietnamese labels.
