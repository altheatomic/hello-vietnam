# travel-preferences

Persists and retrieves the `Your Travel Taste` onboarding answers.

- deployed name: `travel-preferences`
- endpoint: `/functions/v1/travel-preferences`

Actions:

- `saveTravelPreferences`
- `getTravelPreferences`
- `clearTravelPreferences`

`saveTravelPreferences` payload:

```json
{
  "action": "saveTravelPreferences",
  "preferences": {
    "travelStyles": ["food", "culture"],
    "companions": ["friends"],
    "budgetLevel": "moderate",
    "pace": "balanced",
    "topics": ["streetFood", "coffee", "museums"],
    "completedAt": "2026-06-10T09:30:00.000Z"
  }
}
```

Database mapping:

- `trip_style` and `specific_interest` rows go to `user_onboarding_choice`
- `companion_style`, `budget_level`, `pace_level` go to `user_travel_profile`
