# Calendar Current-Month Reveal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically reveal the current selectable month when Trip Planner step 3 opens.

**Architecture:** Give the target month a stable `GlobalKey` and reveal it once with `Scrollable.ensureVisible` after the first layout. Keep existing `firstDate` checks as the source of truth for disabling past dates.

**Tech Stack:** Flutter, Dart, flutter_test

## Global Constraints

- Past dates remain visible, dimmed, and non-interactive.
- Automatic scrolling runs only once per calendar instance.
- The behavior works in bounded and sliver-hosted calendar layouts.

---

### Task 1: Reveal the current month

**Files:**
- Modify: `frontend/lib/core/widgets/date_range_calendar.dart`
- Test: `frontend/test/core/widgets/date_range_calendar_test.dart`

**Interfaces:**
- Consumes: `DateRangeCalendar.firstDate` and the nearest ancestor `Scrollable`.
- Produces: one post-layout call to `Scrollable.ensureVisible` for the target month.

- [ ] **Step 1: Write the failing test**

Pump a sliver-hosted calendar with `firstDate: DateTime(2026, 7, 20)`, settle post-frame work, and assert the outer `Scrollable` position is greater than zero.

- [ ] **Step 2: Verify RED**

Run `flutter test test/core/widgets/date_range_calendar_test.dart` and expect the new scroll-position assertion to fail with an actual value of `0.0`.

- [ ] **Step 3: Implement the minimum behavior**

Store the initial visible date, attach a `GlobalKey` to its `_MonthCard`, and schedule one post-frame `Scrollable.ensureVisible` call after the keyed card is laid out.

- [ ] **Step 4: Verify GREEN**

Run `flutter test test/core/widgets/date_range_calendar_test.dart` and `flutter analyze`; expect all tests to pass and no analyzer issues.

- [ ] **Step 5: Verify Android behavior**

Hot reload the running app, reopen Trip Planner step 3, and confirm the current month is visible immediately while past dates remain disabled.
