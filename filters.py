"""
Optional filtering and fallback logic.

Required filters are already handled in place_repository.py.
This file handles optional filters:
1. average_rating >= MIN_RATING
2. review_count >= MIN_REVIEW_COUNT
3. maximum_price <= budget limit, if available

Important thresholds:
- min_absolute_places = D * 3
  Absolute minimum number of places needed to create a basic itinerary.

- min_recommended_places = D * 4
  Recommended minimum number of places for a better itinerary.

- min_candidates_expected = D * 8
  Expected number of candidate places after filtering.
"""

from datetime import datetime, date

from config import (
    MIN_RATING,
    MIN_REVIEW_COUNT,
    MIN_PER_DAY,
    RECOMMENDED_PER_DAY,
    CANDIDATE_PER_DAY,
    BUDGET_LIMITS,
)


def parse_date(value: str | date) -> date:
    if isinstance(value, date):
        return value

    return datetime.strptime(value, "%Y-%m-%d").date()


def calculate_total_days(start_date: str | date, end_date: str | date) -> int:
    start = parse_date(start_date)
    end = parse_date(end_date)

    if end < start:
        raise ValueError("end_date must be greater than or equal to start_date")

    return (end - start).days + 1


def calculate_min_absolute_places(total_days: int) -> int:
    """
    Absolute minimum number of places to create a basic itinerary.

    Since MinPerDay = 3:
    MinAbsolutePlaces = D * 3
    """
    return total_days * MIN_PER_DAY


def calculate_min_recommended_places(total_days: int) -> int:
    """
    Recommended minimum number of places for a more stable itinerary.

    Since RecommendedPerDay = 4:
    MinRecommendedPlaces = D * 4
    """
    return total_days * RECOMMENDED_PER_DAY


def calculate_min_candidates(total_days: int) -> int:
    """
    Expected number of candidate places after filtering.

    Since CandidatePerDay = 8:
    MinCandidates = D * 8
    """
    return total_days * CANDIDATE_PER_DAY


def filter_by_rating_and_review(places: list[dict]) -> list[dict]:
    result = []

    for place in places:
        rating = place.get("average_rating")
        review_count = place.get("review_count") or 0

        # If rating is missing, keep the place.
        # Missing rating does not always mean the place is bad.
        if rating is not None and float(rating) < MIN_RATING:
            continue

        if int(review_count) < MIN_REVIEW_COUNT:
            continue

        result.append(place)

    return result


def filter_by_budget(places: list[dict], budget_level: str | None) -> list[dict]:
    if not budget_level:
        return places

    budget_max = BUDGET_LIMITS.get(budget_level)

    if budget_max is None:
        return places

    result = []

    for place in places:
        maximum_price = place.get("maximum_price")

        # If price is missing, keep the place.
        # Missing price does not always mean the place is over budget.
        if maximum_price is None:
            result.append(place)
            continue

        if float(maximum_price) <= budget_max:
            result.append(place)

    return result


def apply_optional_filters(places: list[dict], user_profile: dict) -> list[dict]:
    """
    Apply optional filters:
    - rating
    - review_count
    - budget
    """
    filtered = filter_by_rating_and_review(places)
    filtered = filter_by_budget(filtered, user_profile.get("budget_level"))

    return filtered


def get_candidate_pool_status(place_count: int, total_days: int) -> str:
    """
    Classify the quality of the candidate pool after filtering.
    """
    min_absolute_places = calculate_min_absolute_places(total_days)
    min_recommended_places = calculate_min_recommended_places(total_days)
    min_candidates = calculate_min_candidates(total_days)

    if place_count < min_absolute_places:
        return "not_enough"

    if place_count < min_recommended_places:
        return "minimum_only"

    if place_count < min_candidates:
        return "recommended_enough"

    return "ideal"


def filter_places_with_fallback(
    required_places: list[dict],
    user_profile: dict,
    total_days: int,
) -> tuple[list[dict], dict]:
    """
    Apply optional filters.
    If optional filtering returns fewer than D * 8 places,
    fallback to required-filter result.

    Returns:
    - final places after filtering/fallback
    - report for debugging
    """

    min_absolute_places = calculate_min_absolute_places(total_days)
    min_recommended_places = calculate_min_recommended_places(total_days)
    min_candidates = calculate_min_candidates(total_days)

    optional_places = apply_optional_filters(required_places, user_profile)

    optional_status = get_candidate_pool_status(
        place_count=len(optional_places),
        total_days=total_days,
    )

    required_status = get_candidate_pool_status(
        place_count=len(required_places),
        total_days=total_days,
    )

    report = {
        "required_filter_count": len(required_places),
        "optional_filter_count": len(optional_places),

        "min_absolute_places": min_absolute_places,
        "min_recommended_places": min_recommended_places,
        "min_candidates_expected": min_candidates,

        "optional_pool_status": optional_status,
        "required_pool_status": required_status,

        "fallback_used": False,

        "optional_enough_for_absolute_minimum": len(optional_places) >= min_absolute_places,
        "optional_enough_for_recommended_itinerary": len(optional_places) >= min_recommended_places,
        "optional_enough_for_candidate_pool": len(optional_places) >= min_candidates,

        "required_enough_for_absolute_minimum": len(required_places) >= min_absolute_places,
        "required_enough_for_recommended_itinerary": len(required_places) >= min_recommended_places,
        "required_enough_for_candidate_pool": len(required_places) >= min_candidates,
    }

    # Ideal case:
    # optional filters still return enough candidates, so use optional result.
    if len(optional_places) >= min_candidates:
        return optional_places, report

    # Fallback case:
    # optional filtering is too strict, so use required-filter result.
    report["fallback_used"] = True
    return required_places, report