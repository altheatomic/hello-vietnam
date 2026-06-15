"""
Slot-based Diversity Selection for Module 1.

This module is intentionally kept separate from module1_algorithm.py
so the diversity step can be enabled, tested, or tuned independently.
"""

from __future__ import annotations

import math
import re
from collections import Counter, defaultdict
from copy import deepcopy
from typing import Any

from config import CANDIDATE_PER_DAY


MAX_TOP_K = 120
MIN_SCORE_FLOOR = 0.18
MIN_NON_RELATED_TOP_SCORE = 0.05
REPLACEMENT_RATIO = 0.85

PROFILE_RULES = {
    "narrow": {
        "subcategory_ratio": 0.28,
        "category_ratio": 0.70,
        "score_floor_ratio": 0.65,
        "day_cap_offset": 4,
    },
    "medium": {
        "subcategory_ratio": 0.22,
        "category_ratio": 0.55,
        "score_floor_ratio": 0.60,
        "day_cap_offset": 3,
    },
    "broad": {
        "subcategory_ratio": 0.18,
        "category_ratio": 0.45,
        "score_floor_ratio": 0.55,
        "day_cap_offset": 2,
    },
}

INTEREST_TO_GROUPS = {
    "coffee": {
        "place_categories": {"Ẩm thực"},
        "subcategories": {"Cà phê & Trà"},
    },
    "food": {
        "place_categories": {"Ẩm thực"},
        "subcategories": {
            "Quán ăn địa phương",
            "Ẩm thực đường phố",
            "Nhà hàng / Fine Dining",
        },
    },
    "street food": {
        "place_categories": {"Ẩm thực"},
        "subcategories": {
            "Ẩm thực đường phố",
            "Quán ăn địa phương",
        },
    },
    "culture": {
        "place_categories": {"Tham quan"},
        "subcategories": {
            "Di tích & Lịch sử",
            "Bảo tàng & Nghệ thuật",
            "Tâm linh & Tôn giáo",
        },
    },
    "temples": {
        "place_categories": {"Tham quan"},
        "subcategories": {"Tâm linh & Tôn giáo"},
    },
    "beaches": {
        "place_categories": {"Tham quan"},
        "subcategories": {"Biển & Đảo"},
    },
    "scenic spots": {
        "place_categories": {"Tham quan"},
        "subcategories": {
            "Biển & Đảo",
            "Thiên nhiên & Cảnh quan",
            "Hồ & Sông",
            "Công viên & Vườn",
            "Di tích & Lịch sử",
        },
    },
    "nature": {
        "place_categories": {"Tham quan"},
        "subcategories": {
            "Biển & Đảo",
            "Thiên nhiên & Cảnh quan",
            "Hồ & Sông",
            "Công viên & Vườn",
        },
    },
    "local life": {
        "place_categories": {"Mua sắm", "Local life", "Tham quan"},
        "subcategories": {
            "Chợ truyền thống",
            "Làng nghề & Trải nghiệm địa phương",
        },
    },
    "shopping": {
        "place_categories": {"Mua sắm"},
        "subcategories": {
            "Chợ truyền thống",
            "Làng nghề & Trải nghiệm địa phương",
        },
    },
    "museums": {
        "place_categories": {"Tham quan"},
        "subcategories": {"Bảo tàng & Nghệ thuật"},
    },
    "festivals": {
        "place_categories": {"Tham quan", "Local life"},
        "subcategories": {
            "Lễ hội & Sự kiện",
            "Làng nghề & Trải nghiệm địa phương",
        },
    },
    "mountains": {
        "place_categories": {"Tham quan"},
        "subcategories": {"Thiên nhiên & Cảnh quan"},
    },
    "night markets": {
        "place_categories": {"Ẩm thực", "Mua sắm"},
        "subcategories": {
            "Chợ truyền thống",
            "Ẩm thực đường phố",
        },
    },
    "workshops": {
        "place_categories": {"Mua sắm", "Local life"},
        "subcategories": {"Làng nghề & Trải nghiệm địa phương"},
    },
    "handmade goods": {
        "place_categories": {"Mua sắm", "Local life"},
        "subcategories": {
            "Làng nghề & Trải nghiệm địa phương",
            "Chợ truyền thống",
        },
    },
    "photography": {
        "place_categories": {"Tham quan"},
        "subcategories": {
            "Biển & Đảo",
            "Thiên nhiên & Cảnh quan",
            "Hồ & Sông",
            "Di tích & Lịch sử",
        },
    },
    "local cuisine": {
        "place_categories": {"Ẩm thực"},
        "subcategories": {
            "Quán ăn địa phương",
            "Ẩm thực đường phố",
        },
    },
}


def normalize_interest_key(value: str | None) -> str:
    if not value:
        return ""

    normalized = re.sub(r"[_\-]+", " ", value.strip().lower())
    return re.sub(r"\s+", " ", normalized)


def get_top_k_for_diversity(total_days: int) -> int:
    return min(max(int(total_days), 0) * CANDIDATE_PER_DAY, MAX_TOP_K)


def extract_place_subcategory(place: dict[str, Any]) -> str:
    if place.get("subcategory_name"):
        return str(place["subcategory_name"])

    subcategory = place.get("place_subcategory") or {}
    return str(subcategory.get("name") or "Unknown")


def extract_place_category(place: dict[str, Any]) -> str:
    if place.get("place_category"):
        return str(place["place_category"])

    subcategory = place.get("place_subcategory") or {}
    return str(subcategory.get("place_category") or "Unknown")


def sort_place_key(place: dict) -> tuple[float, float, int]:
    return (
        float(place.get("module1_score") or 0.0),
        float(place.get("average_rating") or 0.0),
        int(place.get("review_count") or 0),
    )


def normalize_ranked_places(ranked_places: list[dict]) -> list[dict]:
    normalized_places = []

    for place in ranked_places:
        normalized_place = deepcopy(place)
        normalized_place["module1_score"] = float(
            place.get("module1_score") or place.get("tag_match") or 0.0
        )
        normalized_place["subcategory_name"] = extract_place_subcategory(place)
        normalized_place["place_category"] = extract_place_category(place)
        normalized_place["diversity_reason"] = None
        normalized_place["allocated_subcategory_slot"] = None
        normalized_place["subcategory_slot_rank"] = None
        normalized_places.append(normalized_place)

    normalized_places.sort(key=sort_place_key, reverse=True)
    return normalized_places


def get_interest_groups(user_selected_interests: list[str]) -> dict[str, dict[str, set[str]]]:
    groups = {}

    for interest in user_selected_interests:
        key = normalize_interest_key(interest)
        if not key:
            continue

        groups[key] = INTEREST_TO_GROUPS.get(
            key,
            {
                "place_categories": set(),
                "subcategories": set(),
            },
        )

    return groups


def detect_user_profile(user_selected_interests: list[str]) -> tuple[str, dict]:
    interest_groups = get_interest_groups(user_selected_interests)

    related_place_categories = set()
    related_subcategories = set()

    for group in interest_groups.values():
        related_place_categories.update(group["place_categories"])
        related_subcategories.update(group["subcategories"])

    place_category_count = len(related_place_categories)

    if place_category_count <= 2:
        profile = "narrow"
    elif place_category_count == 3:
        profile = "medium"
    else:
        profile = "broad"

    return profile, {
        "profile": profile,
        "related_place_categories": sorted(related_place_categories),
        "related_subcategories": sorted(related_subcategories),
        "related_place_category_count": place_category_count,
        "related_subcategory_count": len(related_subcategories),
    }


def build_diversity_config(total_days: int, user_selected_interests: list[str]) -> dict:
    profile, profile_info = detect_user_profile(user_selected_interests)
    profile_rule = PROFILE_RULES[profile]
    top_k = get_top_k_for_diversity(total_days)
    day_based_cap = total_days + profile_rule["day_cap_offset"]

    max_per_subcategory = max(
        3,
        min(
            math.ceil(top_k * profile_rule["subcategory_ratio"]),
            day_based_cap,
        ),
    )
    max_per_place_category = math.ceil(top_k * profile_rule["category_ratio"])

    return {
        **profile_info,
        "top_k": top_k,
        "subcategory_ratio": profile_rule["subcategory_ratio"],
        "category_ratio": profile_rule["category_ratio"],
        "score_floor_ratio": profile_rule["score_floor_ratio"],
        "day_based_cap": day_based_cap,
        "max_per_subcategory": max_per_subcategory,
        "max_per_place_category": max_per_place_category,
        "relaxed_max_per_subcategory": max_per_subcategory + 1,
        "relaxed_max_per_place_category": max_per_place_category + 2,
        "min_slot_per_related_subcategory": 1,
        "non_related_top_score_min": MIN_NON_RELATED_TOP_SCORE,
    }


def compute_score_floor(ranked_places: list[dict], score_floor_ratio: float) -> float:
    if not ranked_places:
        return MIN_SCORE_FLOOR

    top1_score = float(ranked_places[0].get("module1_score") or 0.0)
    return round(max(MIN_SCORE_FLOOR, top1_score * score_floor_ratio), 6)


def count_by_key(places: list[dict], key: str) -> dict[str, int]:
    return dict(Counter(str(place.get(key) or "Unknown") for place in places))


def average_score(places: list[dict]) -> float:
    if not places:
        return 0.0

    return round(
        sum(float(place.get("module1_score") or 0.0) for place in places) / len(places),
        6,
    )


def place_matches_interest(place: dict, interest_group: dict[str, set[str]]) -> bool:
    return place.get("subcategory_name") in interest_group["subcategories"]


def build_interest_coverage_map(
    selected: list[dict],
    interest_groups: dict[str, dict[str, set[str]]],
) -> dict[str, bool]:
    coverage = {}

    for interest_key, group in interest_groups.items():
        coverage[interest_key] = any(
            place_matches_interest(place, group)
            for place in selected
        )

    return coverage


def group_places_by_subcategory(
    ranked_places: list[dict],
) -> dict[str, list[dict]]:
    grouped: dict[str, list[dict]] = defaultdict(list)

    for place in ranked_places:
        grouped[place["subcategory_name"]].append(place)

    for places in grouped.values():
        places.sort(key=sort_place_key, reverse=True)

    return dict(grouped)


def build_subcategory_priority_scores(
    user_selected_interests: list[str],
) -> dict[str, float]:
    priority_scores: dict[str, float] = {}
    interest_groups = get_interest_groups(user_selected_interests)

    for group in interest_groups.values():
        for subcategory in group["subcategories"]:
            priority_scores[subcategory] = priority_scores.get(subcategory, 0.0) + 1.0

    return normalize_priority_scores(priority_scores)


def normalize_priority_scores(priority_scores: dict[str, float]) -> dict[str, float]:
    total = sum(max(float(score), 0.0) for score in priority_scores.values())

    if total <= 0:
        return {
            key: 0.0
            for key in priority_scores
        }

    return {
        key: round(max(float(score), 0.0) / total, 6)
        for key, score in priority_scores.items()
    }


def build_trip_interest_groups(
    trip_selected_options: list[dict],
    trip_option_subcategory_rows: list[dict],
) -> dict[str, dict[str, set[str]]]:
    option_map = {
        str(option.get("id_trip_interest_option")): option
        for option in trip_selected_options
        if option.get("id_trip_interest_option")
    }
    groups: dict[str, dict[str, set[str]]] = {}

    for row in trip_option_subcategory_rows:
        if not row.get("is_active", False):
            continue

        option_id = str(row.get("id_trip_interest_option") or "")
        option = option_map.get(option_id)

        if not option:
            continue

        subcategory = row.get("place_subcategory") or {}
        group_key = str(option.get("option_code") or option.get("display_name") or option_id)
        group = groups.setdefault(
            group_key,
            {
                "place_categories": set(),
                "subcategories": set(),
            },
        )
        subcategory_name = subcategory.get("name")
        place_category = subcategory.get("place_category")

        if subcategory_name:
            group["subcategories"].add(str(subcategory_name))
        if place_category:
            group["place_categories"].add(str(place_category))

    return groups


def build_trip_subcategory_priority_scores(
    trip_option_subcategory_rows: list[dict],
) -> dict[str, float]:
    priority_scores: dict[str, float] = {}

    for row in trip_option_subcategory_rows:
        if not row.get("is_active", False):
            continue

        subcategory = row.get("place_subcategory") or {}
        subcategory_name = subcategory.get("name")

        if not subcategory_name:
            continue

        priority_scores[str(subcategory_name)] = (
            priority_scores.get(str(subcategory_name), 0.0)
            + float(row.get("priority_weight") or 0.0)
        )

    return normalize_priority_scores(priority_scores)


def build_effective_subcategory_priority_scores(
    profile_priority_scores: dict[str, float],
    trip_priority_scores: dict[str, float],
    profile_alpha: float = 0.4,
    trip_beta: float = 0.6,
) -> dict[str, float]:
    if not trip_priority_scores:
        return dict(profile_priority_scores)

    effective_scores: dict[str, float] = {}

    for subcategory in set(profile_priority_scores) | set(trip_priority_scores):
        effective_scores[subcategory] = (
            profile_alpha * float(profile_priority_scores.get(subcategory) or 0.0)
            + trip_beta * float(trip_priority_scores.get(subcategory) or 0.0)
        )

    return normalize_priority_scores(effective_scores)


def get_subcategory_category(
    subcategory: str,
    places_by_subcategory: dict[str, list[dict]],
) -> str:
    places = places_by_subcategory.get(subcategory) or []
    if not places:
        return "Unknown"
    return str(places[0].get("place_category") or "Unknown")


def get_top_place(
    subcategory: str,
    places_by_subcategory: dict[str, list[dict]],
) -> dict | None:
    places = places_by_subcategory.get(subcategory) or []
    return places[0] if places else None


def get_next_place_for_slot(
    subcategory: str,
    places_by_subcategory: dict[str, list[dict]],
    slot_by_subcategory: dict[str, int],
) -> dict | None:
    places = places_by_subcategory.get(subcategory) or []
    current_slot = slot_by_subcategory.get(subcategory, 0)

    if current_slot >= len(places):
        return None

    return places[current_slot]


def can_allocate_slot(
    subcategory: str,
    places_by_subcategory: dict[str, list[dict]],
    slot_by_subcategory: dict[str, int],
    slot_by_place_category: Counter,
    max_per_subcategory: int | None,
    max_per_place_category: int | None,
) -> bool:
    places = places_by_subcategory.get(subcategory) or []
    if not places:
        return False

    current_slot = slot_by_subcategory.get(subcategory, 0)
    if current_slot >= len(places):
        return False

    if max_per_subcategory is not None and current_slot >= max_per_subcategory:
        return False

    category = get_subcategory_category(subcategory, places_by_subcategory)
    if (
        max_per_place_category is not None
        and slot_by_place_category[category] >= max_per_place_category
    ):
        return False

    return True


def allocate_slot(
    subcategory: str,
    reason: str,
    places_by_subcategory: dict[str, list[dict]],
    slot_by_subcategory: dict[str, int],
    slot_reasons_by_subcategory: dict[str, list[str]],
    slot_by_place_category: Counter,
    allocation_logs: list[dict],
) -> None:
    slot_by_subcategory[subcategory] = slot_by_subcategory.get(subcategory, 0) + 1
    slot_reasons_by_subcategory.setdefault(subcategory, []).append(reason)
    category = get_subcategory_category(subcategory, places_by_subcategory)
    slot_by_place_category[category] += 1

    next_place = places_by_subcategory[subcategory][slot_by_subcategory[subcategory] - 1]
    allocation_logs.append({
        "subcategory_name": subcategory,
        "place_category": category,
        "allocated_slot": slot_by_subcategory[subcategory],
        "module1_score": round(float(next_place.get("module1_score") or 0.0), 6),
        "reason": reason,
    })


def sort_subcategories_for_min_slots(
    subcategories: list[str],
    priority_scores: dict[str, float],
    places_by_subcategory: dict[str, list[dict]],
) -> list[str]:
    def key(subcategory: str) -> tuple[float, float, float, int]:
        top_place = get_top_place(subcategory, places_by_subcategory) or {}
        return (
            float(priority_scores.get(subcategory, 0.0)),
            float(top_place.get("module1_score") or 0.0),
            float(top_place.get("average_rating") or 0.0),
            int(top_place.get("review_count") or 0),
        )

    return sorted(subcategories, key=key, reverse=True)


def allocate_minimum_related_slots(
    config: dict,
    priority_scores: dict[str, float],
    places_by_subcategory: dict[str, list[dict]],
    slot_by_subcategory: dict[str, int],
    slot_reasons_by_subcategory: dict[str, list[str]],
    slot_by_place_category: Counter,
    allocation_logs: list[dict],
) -> tuple[list[str], list[str]]:
    related_subcategories = [
        subcategory
        for subcategory in priority_scores
        if places_by_subcategory.get(subcategory)
    ]
    ordered_subcategories = sort_subcategories_for_min_slots(
        subcategories=related_subcategories,
        priority_scores=priority_scores,
        places_by_subcategory=places_by_subcategory,
    )

    kept_subcategories = ordered_subcategories[:config["top_k"]]
    skipped_subcategories = ordered_subcategories[config["top_k"]:]

    for subcategory in kept_subcategories:
        if not can_allocate_slot(
            subcategory=subcategory,
            places_by_subcategory=places_by_subcategory,
            slot_by_subcategory=slot_by_subcategory,
            slot_by_place_category=slot_by_place_category,
            max_per_subcategory=config["max_per_subcategory"],
            max_per_place_category=config["max_per_place_category"],
        ):
            continue

        allocate_slot(
            subcategory=subcategory,
            reason="selected_by_related_min_slot",
            places_by_subcategory=places_by_subcategory,
            slot_by_subcategory=slot_by_subcategory,
            slot_reasons_by_subcategory=slot_reasons_by_subcategory,
            slot_by_place_category=slot_by_place_category,
            allocation_logs=allocation_logs,
        )

    return kept_subcategories, skipped_subcategories


def pick_best_related_subcategory_for_extra_slot(
    related_subcategories: list[str],
    priority_scores: dict[str, float],
    places_by_subcategory: dict[str, list[dict]],
    slot_by_subcategory: dict[str, int],
    slot_by_place_category: Counter,
    config: dict,
) -> str | None:
    candidates = []

    for subcategory in related_subcategories:
        if not can_allocate_slot(
            subcategory=subcategory,
            places_by_subcategory=places_by_subcategory,
            slot_by_subcategory=slot_by_subcategory,
            slot_by_place_category=slot_by_place_category,
            max_per_subcategory=config["max_per_subcategory"],
            max_per_place_category=config["max_per_place_category"],
        ):
            continue

        next_place = get_next_place_for_slot(
            subcategory=subcategory,
            places_by_subcategory=places_by_subcategory,
            slot_by_subcategory=slot_by_subcategory,
        )
        if not next_place:
            continue

        current_slot = slot_by_subcategory.get(subcategory, 0)
        candidates.append({
            "subcategory_name": subcategory,
            "priority_score": float(priority_scores.get(subcategory, 0.0)),
            "next_place_score": float(next_place.get("module1_score") or 0.0),
            "current_slot": current_slot,
            "average_rating": float(next_place.get("average_rating") or 0.0),
            "review_count": int(next_place.get("review_count") or 0),
        })

    if not candidates:
        return None

    candidates.sort(
        key=lambda item: (
            item["priority_score"],
            item["next_place_score"],
            -item["current_slot"],
            item["average_rating"],
            item["review_count"],
        ),
        reverse=True,
    )
    return str(candidates[0]["subcategory_name"])


def allocate_related_priority_slots(
    config: dict,
    related_subcategories: list[str],
    priority_scores: dict[str, float],
    places_by_subcategory: dict[str, list[dict]],
    slot_by_subcategory: dict[str, int],
    slot_reasons_by_subcategory: dict[str, list[str]],
    slot_by_place_category: Counter,
    allocation_logs: list[dict],
) -> None:
    while sum(slot_by_subcategory.values()) < config["top_k"]:
        selected_subcategory = pick_best_related_subcategory_for_extra_slot(
            related_subcategories=related_subcategories,
            priority_scores=priority_scores,
            places_by_subcategory=places_by_subcategory,
            slot_by_subcategory=slot_by_subcategory,
            slot_by_place_category=slot_by_place_category,
            config=config,
        )

        if not selected_subcategory:
            break

        allocate_slot(
            subcategory=selected_subcategory,
            reason="selected_by_related_priority",
            places_by_subcategory=places_by_subcategory,
            slot_by_subcategory=slot_by_subcategory,
            slot_reasons_by_subcategory=slot_reasons_by_subcategory,
            slot_by_place_category=slot_by_place_category,
            allocation_logs=allocation_logs,
        )


def pick_best_non_related_subcategory(
    config: dict,
    related_subcategories: list[str],
    places_by_subcategory: dict[str, list[dict]],
    slot_by_subcategory: dict[str, int],
    slot_by_place_category: Counter,
) -> str | None:
    candidates = []

    for subcategory, places in places_by_subcategory.items():
        if subcategory in related_subcategories:
            continue

        top_place = places[0]
        if float(top_place.get("module1_score") or 0.0) < config["non_related_top_score_min"]:
            continue

        if not can_allocate_slot(
            subcategory=subcategory,
            places_by_subcategory=places_by_subcategory,
            slot_by_subcategory=slot_by_subcategory,
            slot_by_place_category=slot_by_place_category,
            max_per_subcategory=config["max_per_subcategory"],
            max_per_place_category=config["max_per_place_category"],
        ):
            continue

        next_place = get_next_place_for_slot(
            subcategory=subcategory,
            places_by_subcategory=places_by_subcategory,
            slot_by_subcategory=slot_by_subcategory,
        )
        if not next_place:
            continue

        candidates.append({
            "subcategory_name": subcategory,
            "next_place_score": float(next_place.get("module1_score") or 0.0),
            "average_rating": float(next_place.get("average_rating") or 0.0),
            "review_count": int(next_place.get("review_count") or 0),
        })

    if not candidates:
        return None

    candidates.sort(
        key=lambda item: (
            item["next_place_score"],
            item["average_rating"],
            item["review_count"],
        ),
        reverse=True,
    )
    return str(candidates[0]["subcategory_name"])


def allocate_non_related_high_score_slots(
    config: dict,
    related_subcategories: list[str],
    places_by_subcategory: dict[str, list[dict]],
    slot_by_subcategory: dict[str, int],
    slot_reasons_by_subcategory: dict[str, list[str]],
    slot_by_place_category: Counter,
    allocation_logs: list[dict],
) -> None:
    while sum(slot_by_subcategory.values()) < config["top_k"]:
        selected_subcategory = pick_best_non_related_subcategory(
            config=config,
            related_subcategories=related_subcategories,
            places_by_subcategory=places_by_subcategory,
            slot_by_subcategory=slot_by_subcategory,
            slot_by_place_category=slot_by_place_category,
        )

        if not selected_subcategory:
            break

        allocate_slot(
            subcategory=selected_subcategory,
            reason="selected_by_non_related_score",
            places_by_subcategory=places_by_subcategory,
            slot_by_subcategory=slot_by_subcategory,
            slot_reasons_by_subcategory=slot_reasons_by_subcategory,
            slot_by_place_category=slot_by_place_category,
            allocation_logs=allocation_logs,
        )


def allocate_refill_slots(
    config: dict,
    places_by_subcategory: dict[str, list[dict]],
    slot_by_subcategory: dict[str, int],
    slot_reasons_by_subcategory: dict[str, list[str]],
    slot_by_place_category: Counter,
    allocation_logs: list[dict],
) -> None:
    while sum(slot_by_subcategory.values()) < config["top_k"]:
        candidates = []

        for subcategory in places_by_subcategory:
            if not can_allocate_slot(
                subcategory=subcategory,
                places_by_subcategory=places_by_subcategory,
                slot_by_subcategory=slot_by_subcategory,
                slot_by_place_category=slot_by_place_category,
                max_per_subcategory=config["max_per_subcategory"],
                max_per_place_category=None,
            ):
                continue

            next_place = get_next_place_for_slot(
                subcategory=subcategory,
                places_by_subcategory=places_by_subcategory,
                slot_by_subcategory=slot_by_subcategory,
            )
            if not next_place:
                continue

            candidates.append({
                "subcategory_name": subcategory,
                "next_place_score": float(next_place.get("module1_score") or 0.0),
                "average_rating": float(next_place.get("average_rating") or 0.0),
                "review_count": int(next_place.get("review_count") or 0),
            })

        if not candidates:
            break

        candidates.sort(
            key=lambda item: (
                item["next_place_score"],
                item["average_rating"],
                item["review_count"],
            ),
            reverse=True,
        )

        allocate_slot(
            subcategory=str(candidates[0]["subcategory_name"]),
            reason="selected_by_slot_refill",
            places_by_subcategory=places_by_subcategory,
            slot_by_subcategory=slot_by_subcategory,
            slot_reasons_by_subcategory=slot_reasons_by_subcategory,
            slot_by_place_category=slot_by_place_category,
            allocation_logs=allocation_logs,
        )


def allocate_fallback_score_slots(
    config: dict,
    places_by_subcategory: dict[str, list[dict]],
    slot_by_subcategory: dict[str, int],
    slot_reasons_by_subcategory: dict[str, list[str]],
    slot_by_place_category: Counter,
    allocation_logs: list[dict],
) -> None:
    while sum(slot_by_subcategory.values()) < config["top_k"]:
        candidates = []

        for subcategory in places_by_subcategory:
            next_place = get_next_place_for_slot(
                subcategory=subcategory,
                places_by_subcategory=places_by_subcategory,
                slot_by_subcategory=slot_by_subcategory,
            )
            if not next_place:
                continue

            candidates.append({
                "subcategory_name": subcategory,
                "next_place_score": float(next_place.get("module1_score") or 0.0),
                "average_rating": float(next_place.get("average_rating") or 0.0),
                "review_count": int(next_place.get("review_count") or 0),
            })

        if not candidates:
            break

        candidates.sort(
            key=lambda item: (
                item["next_place_score"],
                item["average_rating"],
                item["review_count"],
            ),
            reverse=True,
        )

        allocate_slot(
            subcategory=str(candidates[0]["subcategory_name"]),
            reason="selected_by_fallback_score",
            places_by_subcategory=places_by_subcategory,
            slot_by_subcategory=slot_by_subcategory,
            slot_reasons_by_subcategory=slot_reasons_by_subcategory,
            slot_by_place_category=slot_by_place_category,
            allocation_logs=allocation_logs,
        )


def build_selected_places_from_slots(
    places_by_subcategory: dict[str, list[dict]],
    slot_by_subcategory: dict[str, int],
    slot_reasons_by_subcategory: dict[str, list[str]],
) -> list[dict]:
    selected: list[dict] = []

    for subcategory, allocated_slot in slot_by_subcategory.items():
        places = places_by_subcategory.get(subcategory) or []
        reasons = slot_reasons_by_subcategory.get(subcategory) or []

        for index, place in enumerate(places[:allocated_slot], start=1):
            selected_place = dict(place)
            selected_place["allocated_subcategory_slot"] = allocated_slot
            selected_place["subcategory_slot_rank"] = index
            selected_place["diversity_reason"] = (
                reasons[index - 1]
                if index - 1 < len(reasons)
                else "selected_by_subcategory_slot"
            )
            selected.append(selected_place)

    selected.sort(key=sort_place_key, reverse=True)
    return selected


def build_quota_violations(
    places: list[dict],
    max_per_subcategory: int,
    max_per_place_category: int,
) -> dict[str, dict[str, dict[str, int]]]:
    subcategory_counts = count_by_key(places, "subcategory_name")
    place_category_counts = count_by_key(places, "place_category")

    subcategory_violations = {
        key: {
            "count": count,
            "max_allowed": max_per_subcategory,
            "violation": count - max_per_subcategory,
        }
        for key, count in subcategory_counts.items()
        if count > max_per_subcategory
    }
    place_category_violations = {
        key: {
            "count": count,
            "max_allowed": max_per_place_category,
            "violation": count - max_per_place_category,
        }
        for key, count in place_category_counts.items()
        if count > max_per_place_category
    }

    return {
        "subcategory_violations": subcategory_violations,
        "place_category_violations": place_category_violations,
    }


def build_slot_by_place_category(
    slot_by_subcategory: dict[str, int],
    places_by_subcategory: dict[str, list[dict]],
) -> dict[str, int]:
    slot_by_category: Counter = Counter()

    for subcategory, allocated_slot in slot_by_subcategory.items():
        category = get_subcategory_category(subcategory, places_by_subcategory)
        slot_by_category[category] += allocated_slot

    return dict(slot_by_category)


def build_coverable_interest_map(
    places_by_subcategory: dict[str, list[dict]],
    interest_groups: dict[str, dict[str, set[str]]],
) -> dict[str, bool]:
    coverage = {}

    for interest_key, group in interest_groups.items():
        coverage[interest_key] = any(
            places_by_subcategory.get(subcategory)
            for subcategory in group["subcategories"]
        )

    return coverage


def apply_diversity_selection(
    ranked_places: list[dict],
    total_days: int,
    user_selected_interests: list[str],
    trip_selected_options: list[dict] | None = None,
    trip_option_subcategory_rows: list[dict] | None = None,
) -> dict:
    normalized_places = normalize_ranked_places(ranked_places)
    config = build_diversity_config(
        total_days=total_days,
        user_selected_interests=user_selected_interests,
    )
    profile_interest_groups = get_interest_groups(user_selected_interests)
    profile_priority_scores = build_subcategory_priority_scores(user_selected_interests)
    trip_interest_groups = build_trip_interest_groups(
        trip_selected_options=trip_selected_options or [],
        trip_option_subcategory_rows=trip_option_subcategory_rows or [],
    )
    trip_priority_scores = build_trip_subcategory_priority_scores(
        trip_option_subcategory_rows=trip_option_subcategory_rows or [],
    )
    has_trip_interest = bool(trip_priority_scores)
    interest_groups = trip_interest_groups if has_trip_interest else profile_interest_groups
    priority_scores = build_effective_subcategory_priority_scores(
        profile_priority_scores=profile_priority_scores,
        trip_priority_scores=trip_priority_scores,
    )
    places_by_subcategory = group_places_by_subcategory(normalized_places)
    if has_trip_interest:
        related_subcategories = sorted(priority_scores.keys())
        related_place_categories = sorted({
            str((row.get("place_subcategory") or {}).get("place_category"))
            for row in (trip_option_subcategory_rows or [])
            if row.get("is_active", False)
            and (row.get("place_subcategory") or {}).get("place_category")
        })
        config["related_subcategories"] = related_subcategories
        config["related_subcategory_count"] = len(related_subcategories)
        config["related_place_categories"] = related_place_categories
        config["related_place_category_count"] = len(related_place_categories)
    config["priority_source"] = "trip_plus_profile" if has_trip_interest else "profile_only"
    before_top_k = normalized_places[:config["top_k"]]
    score_floor = compute_score_floor(
        ranked_places=normalized_places,
        score_floor_ratio=config["score_floor_ratio"],
    )

    slot_by_subcategory: dict[str, int] = {}
    slot_reasons_by_subcategory: dict[str, list[str]] = {}
    slot_by_place_category: Counter = Counter()
    allocation_logs: list[dict] = []

    related_subcategories, skipped_related_subcategories = allocate_minimum_related_slots(
        config=config,
        priority_scores=priority_scores,
        places_by_subcategory=places_by_subcategory,
        slot_by_subcategory=slot_by_subcategory,
        slot_reasons_by_subcategory=slot_reasons_by_subcategory,
        slot_by_place_category=slot_by_place_category,
        allocation_logs=allocation_logs,
    )

    allocate_related_priority_slots(
        config=config,
        related_subcategories=related_subcategories,
        priority_scores=priority_scores,
        places_by_subcategory=places_by_subcategory,
        slot_by_subcategory=slot_by_subcategory,
        slot_reasons_by_subcategory=slot_reasons_by_subcategory,
        slot_by_place_category=slot_by_place_category,
        allocation_logs=allocation_logs,
    )

    allocate_non_related_high_score_slots(
        config=config,
        related_subcategories=related_subcategories,
        places_by_subcategory=places_by_subcategory,
        slot_by_subcategory=slot_by_subcategory,
        slot_reasons_by_subcategory=slot_reasons_by_subcategory,
        slot_by_place_category=slot_by_place_category,
        allocation_logs=allocation_logs,
    )

    allocated_before_refill = sum(slot_by_subcategory.values())

    allocate_refill_slots(
        config=config,
        places_by_subcategory=places_by_subcategory,
        slot_by_subcategory=slot_by_subcategory,
        slot_reasons_by_subcategory=slot_reasons_by_subcategory,
        slot_by_place_category=slot_by_place_category,
        allocation_logs=allocation_logs,
    )

    allocated_before_fallback = sum(slot_by_subcategory.values())

    allocate_fallback_score_slots(
        config=config,
        places_by_subcategory=places_by_subcategory,
        slot_by_subcategory=slot_by_subcategory,
        slot_reasons_by_subcategory=slot_reasons_by_subcategory,
        slot_by_place_category=slot_by_place_category,
        allocation_logs=allocation_logs,
    )

    diversified_top_k = build_selected_places_from_slots(
        places_by_subcategory=places_by_subcategory,
        slot_by_subcategory=slot_by_subcategory,
        slot_reasons_by_subcategory=slot_reasons_by_subcategory,
    )[:config["top_k"]]

    selected_ids = {place.get("id_place") for place in diversified_top_k}
    overflow_pool = [
        place
        for place in normalized_places
        if place.get("id_place") not in selected_ids
    ]
    low_score_pool = [
        place
        for place in normalized_places
        if float(place.get("module1_score") or 0.0) < score_floor
    ]

    avg_score_before = average_score(before_top_k)
    avg_score_after = average_score(diversified_top_k)
    score_quality_ok = avg_score_after >= round(avg_score_before * 0.90, 6)
    coverage_before = build_interest_coverage_map(before_top_k, interest_groups)
    coverage_after = build_interest_coverage_map(diversified_top_k, interest_groups)
    coverable_interest_map = build_coverable_interest_map(
        places_by_subcategory=places_by_subcategory,
        interest_groups=interest_groups,
    )
    missing_coverable_interests_after = [
        interest_key
        for interest_key, is_coverable in coverable_interest_map.items()
        if is_coverable and not coverage_after.get(interest_key, False)
    ]
    coverage_quality_ok = not missing_coverable_interests_after

    strict_quota_violations = build_quota_violations(
        places=diversified_top_k,
        max_per_subcategory=config["max_per_subcategory"],
        max_per_place_category=config["max_per_place_category"],
    )
    relaxed_quota_violations = {
        "subcategory_violations": {},
        "place_category_violations": {},
    }
    quota_quality_ok = (
        not strict_quota_violations["subcategory_violations"]
        and not strict_quota_violations["place_category_violations"]
    )

    slot_by_place_category_map = build_slot_by_place_category(
        slot_by_subcategory=slot_by_subcategory,
        places_by_subcategory=places_by_subcategory,
    )
    selected_count_by_subcategory = count_by_key(diversified_top_k, "subcategory_name")
    selected_count_by_place_category = count_by_key(diversified_top_k, "place_category")
    slot_allocation_ok = all(
        selected_count_by_subcategory.get(subcategory, 0) <= allocated_slot
        for subcategory, allocated_slot in slot_by_subcategory.items()
    )

    coverage_additions = [
        {
            "place_name": place.get("name"),
            "module1_score": round(float(place.get("module1_score") or 0.0), 6),
            "subcategory_name": place.get("subcategory_name"),
            "diversity_reason": place.get("diversity_reason"),
        }
        for place in diversified_top_k
        if place.get("diversity_reason") == "selected_by_related_min_slot"
    ]
    fill_logs = [
        log
        for log in allocation_logs
        if log["reason"] != "selected_by_related_min_slot"
    ]

    return {
        "diversified_top_k": diversified_top_k,
        "overflow_pool": overflow_pool,
        "low_score_pool": low_score_pool,
        "config": {
            **config,
            "score_floor": score_floor,
            "top1_score": round(float(normalized_places[0].get("module1_score") or 0.0), 6)
            if normalized_places
            else 0.0,
            "selected_trip_interest_options": [
                option.get("option_code") or option.get("display_name")
                for option in (trip_selected_options or [])
                if option.get("option_code") or option.get("display_name")
            ],
            "related_subcategories_in_pool": related_subcategories,
            "skipped_related_subcategories": skipped_related_subcategories,
        },
        "summary": {
            "avg_score_before": avg_score_before,
            "avg_score_after": avg_score_after,
            "avg_score_after_min_expected": round(avg_score_before * 0.90, 6),
            "score_quality_ok": score_quality_ok,
            "quota_quality_ok": quota_quality_ok,
            "coverage_quality_ok": coverage_quality_ok,
            "slot_allocation_ok": slot_allocation_ok,
            "global_baseline_count_by_subcategory": count_by_key(before_top_k, "subcategory_name"),
            "global_baseline_count_by_place_category": count_by_key(before_top_k, "place_category"),
            "after_count_by_subcategory": selected_count_by_subcategory,
            "after_count_by_place_category": selected_count_by_place_category,
            "global_baseline_coverage": coverage_before,
            "coverage_after": coverage_after,
            "coverable_interest_map": coverable_interest_map,
            "missing_coverable_interests_after": missing_coverable_interests_after,
            "strict_quota_violations": strict_quota_violations,
            "relaxed_quota_violations": relaxed_quota_violations,
            "slot_by_subcategory": slot_by_subcategory,
            "slot_by_place_category": slot_by_place_category_map,
            "profile_priority_by_subcategory": {
                subcategory: round(score, 6)
                for subcategory, score in profile_priority_scores.items()
            },
            "trip_priority_by_subcategory": {
                subcategory: round(score, 6)
                for subcategory, score in trip_priority_scores.items()
            },
            "priority_by_subcategory": {
                subcategory: round(score, 6)
                for subcategory, score in priority_scores.items()
            },
            "related_subcategories": related_subcategories,
            "unused_slots": max(config["top_k"] - len(diversified_top_k), 0),
            "refilled_slots": max(
                allocated_before_fallback - allocated_before_refill,
                0,
            ),
            "final_selected_count": len(diversified_top_k),
            "allocation_logs": allocation_logs,
            "replacements": [],
            "coverage_additions": coverage_additions,
            "fill_logs": fill_logs,
            "selected_places_by_subcategory": {
                subcategory: [
                    {
                        "place_name": place.get("name"),
                        "module1_score": round(float(place.get("module1_score") or 0.0), 6),
                        "subcategory_slot_rank": place.get("subcategory_slot_rank"),
                        "diversity_reason": place.get("diversity_reason"),
                    }
                    for place in diversified_top_k
                    if place.get("subcategory_name") == subcategory
                ]
                for subcategory in sorted(selected_count_by_subcategory.keys())
            },
        },
    }
