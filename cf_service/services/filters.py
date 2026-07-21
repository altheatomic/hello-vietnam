"""
services/filters.py
Optional filtering and fallback logic.

Required filters are handled in db/place_repository.py.
This file handles optional filters:
  1. average_rating >= MIN_RATING
  2. review_count >= MIN_REVIEW_COUNT

Budget filtering is intentionally omitted.

Fallback: if optional filtering returns fewer than D*8 places,
fall back to the required-filter result (all eligible places).
"""

from datetime import datetime, date

from config import (
    MIN_RATING,
    MIN_REVIEW_COUNT,
    MIN_PER_DAY,
    RECOMMENDED_PER_DAY,
    CANDIDATE_PER_DAY,
)


def parse_date(value: str | date) -> date:
    if isinstance(value, date):
        return value
    return datetime.strptime(value, "%Y-%m-%d").date()


def calculate_total_days(start_date: str | date, end_date: str | date) -> int:
    start = parse_date(start_date)
    end = parse_date(end_date)
    if end < start:
        raise ValueError("end_date must be >= start_date")
    return (end - start).days + 1


def calculate_min_absolute_places(total_days: int) -> int:
    return total_days * MIN_PER_DAY


def calculate_min_recommended_places(total_days: int) -> int:
    return total_days * RECOMMENDED_PER_DAY


def calculate_min_candidates(total_days: int) -> int:
    return total_days * CANDIDATE_PER_DAY


def filter_by_rating_and_review(places: list[dict]) -> list[dict]:
    result = []
    for place in places:
        rating = place.get("average_rating")
        review_count = place.get("review_count") or 0
        if rating is not None and float(rating) < MIN_RATING:
            continue
        if int(review_count) < MIN_REVIEW_COUNT:
            continue
        result.append(place)
    return result


def apply_optional_filters(places: list[dict]) -> list[dict]:
    """Apply rating and review_count filters only. Budget filtering omitted."""
    return filter_by_rating_and_review(places)


def get_candidate_pool_status(place_count: int, total_days: int) -> str:
    min_absolute = calculate_min_absolute_places(total_days)
    min_recommended = calculate_min_recommended_places(total_days)
    min_candidates = calculate_min_candidates(total_days)

    if place_count < min_absolute:
        return "not_enough"
    if place_count < min_recommended:
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
    Apply optional filters (rating, review_count).
    Falls back to required_places if result < total_days * 8.

    user_profile is accepted for API compatibility but budget_level is
    not used for filtering.

    Returns (final_places, debug_report).
    """
    min_absolute = calculate_min_absolute_places(total_days)
    min_recommended = calculate_min_recommended_places(total_days)
    min_candidates = calculate_min_candidates(total_days)

    optional_places = apply_optional_filters(required_places)

    optional_status = get_candidate_pool_status(len(optional_places), total_days)
    required_status = get_candidate_pool_status(len(required_places), total_days)

    report = {
        "required_filter_count": len(required_places),
        "optional_filter_count": len(optional_places),
        "min_absolute_places": min_absolute,
        "min_recommended_places": min_recommended,
        "min_candidates_expected": min_candidates,
        "optional_pool_status": optional_status,
        "required_pool_status": required_status,
        "fallback_used": False,
        "optional_enough_for_candidate_pool": len(optional_places) >= min_candidates,
        "required_enough_for_absolute_minimum": len(required_places) >= min_absolute,
    }

    if len(optional_places) >= min_candidates:
        return optional_places, report

    report["fallback_used"] = True
    return required_places, report
