# Trip Duration Calendar Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Trip Planner step 3 render its date-range calendar without layout exceptions.

**Architecture:** `DateRangeCalendar` will detect whether its parent supplies bounded vertical space. It will preserve the internal scrolling layout when bounded and switch to shrink-wrapped content when hosted by a sliver.

**Tech Stack:** Flutter, Dart, flutter_test

## Global Constraints

- Preserve existing bounded-height behavior and localization.
- Let the parent scroll view own scrolling under unbounded vertical constraints.
- Do not change the layout contract of other planner steps.

---

### Task 1: Adaptive calendar layout

**Files:**
- Modify: `frontend/lib/core/widgets/date_range_calendar.dart:145-239`
- Test: `frontend/test/core/widgets/date_range_calendar_test.dart`

**Interfaces:**
- Consumes: `BoxConstraints.hasBoundedHeight` from `LayoutBuilder`.
- Produces: a `DateRangeCalendar` that renders under bounded and unbounded vertical constraints.

- [ ] **Step 1: Write the failing test**

Add a test that pumps the calendar in a `SliverToBoxAdapter`, then checks `tester.takeException()` is null and visible calendar labels exist.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/date_range_calendar_test.dart`

Expected: FAIL with a `RenderFlex` complaint about non-zero flex under unbounded height.

- [ ] **Step 3: Write minimal implementation**

Wrap the calendar body in `LayoutBuilder`. Build the shared month list once. Under bounded height, place it in `Expanded`; under unbounded height, set the column to `MainAxisSize.min` and configure the list with `shrinkWrap: true` and `NeverScrollableScrollPhysics`.

- [ ] **Step 4: Run verification**

Run:

```bash
flutter test test/core/widgets/date_range_calendar_test.dart
flutter analyze
```

Expected: all tests pass and analyzer reports no issues.

- [ ] **Step 5: Verify on Android**

Hot reload the active Flutter session and navigate to Trip Planner step 3. Confirm no new layout exception appears in runtime logs.
