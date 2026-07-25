# Trip Planner Vietnamese Localization Design

## Goal

Localize the complete Trip Planner flow so every user-facing button and action label is displayed in Vietnamese when the application language is Vietnamese, while preserving the existing English interface when English is selected.

## Scope

The change covers the complete Trip Planner journey:

- Trip type selection
- Leisure destination selection
- Business location entry
- Travel date selection
- Interest selection
- Budget selection
- Generated itinerary result
- Day detail and directions
- Map and nearby-place actions
- Saved trips, filters, itinerary progress, reopening, and replanning
- Dialog actions, loading states, empty-state actions, and navigation buttons within these screens

The task is limited to localization. It does not change navigation, trip-generation logic, data persistence, maps, or visual layout.

## Localization Approach

Use the existing `AppStrings` localization mechanism:

1. Wrap Trip Planner button labels and other action text with `context.l10n.ui(...)`, or use an existing typed `AppStrings` getter where one already exists.
2. Add missing English-to-Vietnamese entries to `AppStrings._viText`.
3. Keep the English string as the lookup key and fallback value, so English behavior remains unchanged.
4. Avoid hardcoded Vietnamese text in presentation widgets because that would break language switching.

Representative mappings include:

| English | Vietnamese |
| --- | --- |
| Back | Quay lại |
| Next | Tiếp tục |
| Generate | Tạo lịch trình |
| Generating... | Đang tạo lịch trình... |
| Save | Lưu |
| Saving... | Đang lưu... |
| Share | Chia sẻ |
| Cancel | Hủy |
| Saved Trips | Chuyến đi đã lưu |
| Get Directions | Chỉ đường |
| Create Trip on Google Maps | Tạo chuyến đi trên Google Maps |
| Open itinerary | Mở lịch trình |
| Plan again | Lên lịch lại |

All other Trip Planner action labels discovered during implementation will follow the same pattern.

## Component Changes

`PlannerStepScaffold` will localize its shared Back and Next controls, progress text, and any provided action label at render time. Individual Trip Planner screens will localize screen-specific buttons, cards that act as choices, dialog actions, loading labels, map actions, saved-trip filters, and empty-state calls to action.

The existing uncommitted work in `app_language.dart` belongs to the user and must be preserved. Localization entries will be added with a minimal patch without rewriting unrelated sections.

## Behavior and Error Handling

Button enabled/disabled rules and callbacks remain unchanged. Error messages and status labels encountered in the Trip Planner flow will also use the same localization lookup when they are user-facing, ensuring the flow does not switch back to English after an action fails or begins loading.

If a translation key is absent, the current `ui` method safely falls back to English. Tests will prevent known Trip Planner keys from silently relying on that fallback in Vietnamese mode.

## Testing

Implementation will follow test-driven development:

1. Add localization tests asserting representative and newly added Trip Planner mappings in Vietnamese and their unchanged English values.
2. Add or extend widget tests for shared planner navigation controls and selected screen-specific actions under Vietnamese locale.
3. Run the focused localization and planner tests.
4. Run `flutter analyze` for the affected frontend code and broader relevant tests when practical.

## Success Criteria

- Every button and actionable label in the complete Trip Planner flow is Vietnamese in Vietnamese mode.
- English mode retains the current English labels.
- Language switching uses the existing app-wide localization controller.
- No Trip Planner navigation, generation, saving, sharing, or map behavior changes.
- Focused tests and static analysis pass.
