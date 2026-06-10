"""
Run filtering test only.

This script does NOT calculate TagMatch or FinalRank.

Flow:
1. Receive test user profile.
2. Query `place` table by required filters.
3. Apply optional filters: rating, review_count, budget.
4. If optional filters return fewer than D * 8 places, fallback to required-filter result.
5. Print final filtered places.
"""

from supabase_client import get_supabase_client
from place_repository import fetch_places_required_filter
from filters import calculate_total_days, filter_places_with_fallback
from pipeline_input import get_pipeline_input
from module1_repository import fetch_user_onboarding_choices, fetch_user_travel_profile


def resolve_user_profile(
    input_user_profile: dict,
    db_travel_profile: dict | None,
    db_onboarding_choices: list[dict] | None = None,
) -> tuple[dict, dict]:
    user_profile = dict(input_user_profile)
    sources = {
        "travel_profile_source": "pipeline_input_fallback",
        "onboarding_choice_source": "pipeline_input_fallback",
    }

    if db_travel_profile:
        for key in ("companion_style", "budget_level", "pace_level"):
            db_value = db_travel_profile.get(key)
            if db_value is not None:
                user_profile[key] = db_value

        sources["travel_profile_source"] = "user_travel_profile"

    onboarding_values = build_onboarding_inputs_from_choices(db_onboarding_choices or [])
    if onboarding_values["travel_styles"]:
        user_profile["travel_styles"] = onboarding_values["travel_styles"]
        sources["onboarding_choice_source"] = "user_onboarding_choice"
    if onboarding_values["topics"]:
        user_profile["topics"] = onboarding_values["topics"]
        sources["onboarding_choice_source"] = "user_onboarding_choice"

    return user_profile, sources


def normalize_onboarding_option(option_code: str) -> str:
    normalized = str(option_code or "").strip().lower()
    aliases = {
        "local_discovery": "Local Life",
    }

    if normalized in aliases:
        return aliases[normalized]

    return " ".join(part.capitalize() for part in normalized.split("_"))


def build_onboarding_inputs_from_choices(choice_rows: list[dict]) -> dict[str, list[str]]:
    travel_styles: list[str] = []
    topics: list[str] = []

    for row in choice_rows:
        screen_code = str(row.get("screen_code") or "").strip().lower()
        option_code = str(row.get("option_code") or "").strip()

        if not option_code:
            continue

        normalized_value = normalize_onboarding_option(option_code)

        if screen_code == "trip_style":
            travel_styles.append(normalized_value)
        elif screen_code == "specific_interest":
            topics.append(normalized_value)

    return {
        "travel_styles": travel_styles,
        "topics": topics,
    }


def print_place(index: int, place: dict) -> None:
    print(f"{index}. {place.get('name')}")
    print(f"   id_place: {place.get('id_place')}")
    print(f"   status: {place.get('status')}")
    print(f"   province: {place.get('id_province')}")
    print(f"   latitude: {place.get('latitude')}")
    print(f"   longitude: {place.get('longitude')}")
    print(f"   rating: {place.get('average_rating')}")
    print(f"   review_count: {place.get('review_count')}")
    print(f"   min_price: {place.get('minimum_price')}")
    print(f"   max_price: {place.get('maximum_price')}")
    print(f"   subcategory: {place.get('place_subcategory')}")
    print()


def print_threshold_meaning() -> None:
    print("Threshold meaning:")
    print("  min_absolute_places = D * 3")
    print("    Absolute minimum number of places to create a basic itinerary.")
    print()
    print("  min_recommended_places = D * 4")
    print("    Recommended minimum number of places for a more stable itinerary.")
    print()
    print("  min_candidates_expected = D * 8")
    print("    Expected candidate pool size for Module 2 and later replacement.")
    print()


def print_pool_status_meaning() -> None:
    print("Candidate pool status meaning:")
    print("  not_enough")
    print("    The number of places is lower than D * 3. The system may not create a basic itinerary.")
    print()
    print("  minimum_only")
    print("    The number of places is between D * 3 and D * 4. The itinerary can run, but quality may be low.")
    print()
    print("  recommended_enough")
    print("    The number of places is at least D * 4 but lower than D * 8. The itinerary is usable, but backup is limited.")
    print()
    print("  ideal")
    print("    The number of places is at least D * 8. This is enough for candidate selection, clustering, and replacement.")
    print()


def main():
    supabase = get_supabase_client()
    pipeline_input = get_pipeline_input()
    input_user_profile = pipeline_input["user_profile"]
    run_settings = pipeline_input["run_settings"]
    db_travel_profile = fetch_user_travel_profile(
        supabase=supabase,
        user_id=input_user_profile["id_user"],
    )
    db_onboarding_choices = fetch_user_onboarding_choices(
        supabase=supabase,
        user_id=input_user_profile["id_user"],
    )
    user_profile, profile_sources = resolve_user_profile(
        input_user_profile=input_user_profile,
        db_travel_profile=db_travel_profile,
        db_onboarding_choices=db_onboarding_choices,
    )

    total_days = calculate_total_days(
        user_profile["start_date"],
        user_profile["end_date"],
    )

    print("=" * 80)
    print("MODULE 1 TEST: FILTERING ONLY")
    print("=" * 80)
    print(f"Travel profile source: {profile_sources['travel_profile_source']}")
    print(f"Onboarding choice source: {profile_sources['onboarding_choice_source']}")
    print(f"Province: {user_profile['id_province']}")
    print(f"Total days: {total_days}")
    print(f"Budget level: {user_profile.get('budget_level')}")
    print()

    print_threshold_meaning()
    print_pool_status_meaning()

    required_places = fetch_places_required_filter(
        supabase=supabase,
        province_id=user_profile["id_province"],
        limit=run_settings["place_fetch_limit"],
    )

    final_places, report = filter_places_with_fallback(
        required_places=required_places,
        user_profile=user_profile,
        total_days=total_days,
    )

    print("=" * 80)
    print("Filter report:")
    print("=" * 80)

    for key, value in report.items():
        print(f"  {key}: {value}")

    print()
    print(f"Final places returned after filtering: {len(final_places)}")
    print("-" * 80)

    for index, place in enumerate(final_places[:30], start=1):
        print_place(index, place)


if __name__ == "__main__":
    main()
