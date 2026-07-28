# Trip Duration Calendar Layout Design

## Problem

Trip Planner step 3 renders `DateRangeCalendar` through `PlannerStepScaffold` inside a `SliverToBoxAdapter`. The sliver gives the calendar unbounded vertical constraints, while the calendar currently contains an `Expanded` month list. Flutter cannot resolve that combination and throws a `RenderFlex` layout exception, leaving the step blank.

## Design

Keep `DateRangeCalendar` reusable in both of its existing layout contexts:

- With bounded height, retain the current `Expanded` plus independently scrollable month list.
- With unbounded height, make the outer column shrink-wrap and render a non-scrollable, shrink-wrapped month list so the parent sliver owns scrolling.

Use `LayoutBuilder` to select the layout from `constraints.hasBoundedHeight`. Do not change `PlannerStepScaffold` or the other planner steps.

## Testing

Add a widget test that places `DateRangeCalendar` inside `CustomScrollView` and `SliverToBoxAdapter`, pumps the frame, and asserts that Flutter reports no exception and the calendar content renders. Retain the existing bounded-height localization test.
