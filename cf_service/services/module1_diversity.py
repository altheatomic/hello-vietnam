"""
services/module1_diversity.py
Slot-based diversity selection for Module 1.

Entry point: apply_diversity_selection()

Returns {diversified_top_k, overflow_pool, low_score_pool, config, summary}.
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
    "coffee": {"place_categories": {"Ẩm thực"}, "subcategories": {"Cà phê & Trà"}},
    "food": {
        "place_categories": {"Ẩm thực"},
        "subcategories": {"Quán ăn địa phương", "Ẩm thực đường phố", "Nhà hàng / Fine Dining"},
    },
    "street food": {
        "place_categories": {"Ẩm thực"},
        "subcategories": {"Ẩm thực đường phố", "Quán ăn địa phương"},
    },
    "culture": {
        "place_categories": {"Tham quan"},
        "subcategories": {"Di tích & Lịch sử", "Bảo tàng & Nghệ thuật", "Tâm linh & Tôn giáo"},
    },
    "temples": {"place_categories": {"Tham quan"}, "subcategories": {"Tâm linh & Tôn giáo"}},
    "beaches": {"place_categories": {"Tham quan"}, "subcategories": {"Biển & Đảo"}},
    "scenic spots": {
        "place_categories": {"Tham quan"},
        "subcategories": {"Biển & Đảo", "Thiên nhiên & Cảnh quan", "Hồ & Sông", "Công viên & Vườn", "Di tích & Lịch sử"},
    },
    "nature": {
        "place_categories": {"Tham quan"},
        "subcategories": {"Biển & Đảo", "Thiên nhiên & Cảnh quan", "Hồ & Sông", "Công viên & Vườn"},
    },
    "local life": {
        "place_categories": {"Mua sắm", "Local life", "Tham quan"},
        "subcategories": {"Chợ truyền thống", "Làng nghề & Trải nghiệm địa phương"},
    },
    "shopping": {
        "place_categories": {"Mua sắm"},
        "subcategories": {"Chợ truyền thống", "Làng nghề & Trải nghiệm địa phương"},
    },
    "museums": {"place_categories": {"Tham quan"}, "subcategories": {"Bảo tàng & Nghệ thuật"}},
    "festivals": {
        "place_categories": {"Tham quan", "Local life"},
        "subcategories": {"Lễ hội & Sự kiện", "Làng nghề & Trải nghiệm địa phương"},
    },
    "mountains": {"place_categories": {"Tham quan"}, "subcategories": {"Thiên nhiên & Cảnh quan"}},
    "night markets": {
        "place_categories": {"Ẩm thực", "Mua sắm"},
        "subcategories": {"Chợ truyền thống", "Ẩm thực đường phố"},
    },
    "workshops": {
        "place_categories": {"Mua sắm", "Local life"},
        "subcategories": {"Làng nghề & Trải nghiệm địa phương"},
    },
    "handmade goods": {
        "place_categories": {"Mua sắm", "Local life"},
        "subcategories": {"Làng nghề & Trải nghiệm địa phương", "Chợ truyền thống"},
    },
    "photography": {
        "place_categories": {"Tham quan"},
        "subcategories": {"Biển & Đảo", "Thiên nhiên & Cảnh quan", "Hồ & Sông", "Di tích & Lịch sử"},
    },
    "local cuisine": {
        "place_categories": {"Ẩm thực"},
        "subcategories": {"Quán ăn địa phương", "Ẩm thực đường phố"},
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
    normalized = []
    for place in ranked_places:
        np = deepcopy(place)
        np["module1_score"] = float(place.get("module1_score") or place.get("tag_match") or 0.0)
        np["subcategory_name"] = extract_place_subcategory(place)
        np["place_category"] = extract_place_category(place)
        np["diversity_reason"] = None
        np["allocated_subcategory_slot"] = None
        np["subcategory_slot_rank"] = None
        normalized.append(np)
    normalized.sort(key=sort_place_key, reverse=True)
    return normalized


def get_interest_groups(user_selected_interests: list[str]) -> dict[str, dict[str, set[str]]]:
    groups = {}
    for interest in user_selected_interests:
        key = normalize_interest_key(interest)
        if not key:
            continue
        groups[key] = INTEREST_TO_GROUPS.get(key, {"place_categories": set(), "subcategories": set()})
    return groups


def detect_user_profile(user_selected_interests: list[str]) -> tuple[str, dict]:
    interest_groups = get_interest_groups(user_selected_interests)
    related_place_categories: set[str] = set()
    related_subcategories: set[str] = set()
    for group in interest_groups.values():
        related_place_categories.update(group["place_categories"])
        related_subcategories.update(group["subcategories"])
    count = len(related_place_categories)
    profile = "narrow" if count <= 2 else ("medium" if count == 3 else "broad")
    return profile, {
        "profile": profile,
        "related_place_categories": sorted(related_place_categories),
        "related_subcategories": sorted(related_subcategories),
        "related_place_category_count": count,
        "related_subcategory_count": len(related_subcategories),
    }


def build_diversity_config(total_days: int, user_selected_interests: list[str]) -> dict:
    profile, profile_info = detect_user_profile(user_selected_interests)
    profile_rule = PROFILE_RULES[profile]
    top_k = get_top_k_for_diversity(total_days)
    day_based_cap = total_days + profile_rule["day_cap_offset"]
    max_per_subcategory = max(3, min(math.ceil(top_k * profile_rule["subcategory_ratio"]), day_based_cap))
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
    return round(sum(float(p.get("module1_score") or 0.0) for p in places) / len(places), 6)


def place_matches_interest(place: dict, interest_group: dict[str, set[str]]) -> bool:
    return place.get("subcategory_name") in interest_group["subcategories"]


def build_interest_coverage_map(selected: list[dict], interest_groups: dict[str, dict[str, set[str]]]) -> dict[str, bool]:
    return {key: any(place_matches_interest(p, g) for p in selected) for key, g in interest_groups.items()}


def group_places_by_subcategory(ranked_places: list[dict]) -> dict[str, list[dict]]:
    grouped: dict[str, list[dict]] = defaultdict(list)
    for place in ranked_places:
        grouped[place["subcategory_name"]].append(place)
    for places in grouped.values():
        places.sort(key=sort_place_key, reverse=True)
    return dict(grouped)


def build_subcategory_priority_scores(user_selected_interests: list[str]) -> dict[str, float]:
    priority_scores: dict[str, float] = {}
    interest_groups = get_interest_groups(user_selected_interests)
    for group in interest_groups.values():
        for subcategory in group["subcategories"]:
            priority_scores[subcategory] = priority_scores.get(subcategory, 0.0) + 1.0
    return normalize_priority_scores(priority_scores)


def normalize_priority_scores(priority_scores: dict[str, float]) -> dict[str, float]:
    total = sum(max(float(s), 0.0) for s in priority_scores.values())
    if total <= 0:
        return {k: 0.0 for k in priority_scores}
    return {k: round(max(float(s), 0.0) / total, 6) for k, s in priority_scores.items()}


def build_trip_interest_groups(
    trip_selected_options: list[dict],
    trip_option_subcategory_rows: list[dict],
) -> dict[str, dict[str, set[str]]]:
    option_map = {str(o.get("id_trip_interest_option")): o for o in trip_selected_options if o.get("id_trip_interest_option")}
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
        group = groups.setdefault(group_key, {"place_categories": set(), "subcategories": set()})
        if subcategory.get("name"):
            group["subcategories"].add(str(subcategory["name"]))
        if subcategory.get("place_category"):
            group["place_categories"].add(str(subcategory["place_category"]))
    return groups


def build_trip_subcategory_priority_scores(trip_option_subcategory_rows: list[dict]) -> dict[str, float]:
    priority_scores: dict[str, float] = {}
    for row in trip_option_subcategory_rows:
        if not row.get("is_active", False):
            continue
        subcategory = row.get("place_subcategory") or {}
        name = subcategory.get("name")
        if not name:
            continue
        priority_scores[str(name)] = priority_scores.get(str(name), 0.0) + float(row.get("priority_weight") or 0.0)
    return normalize_priority_scores(priority_scores)


def build_effective_subcategory_priority_scores(
    profile_priority_scores: dict[str, float],
    trip_priority_scores: dict[str, float],
    profile_alpha: float = 0.4,
    trip_beta: float = 0.6,
) -> dict[str, float]:
    if not trip_priority_scores:
        return dict(profile_priority_scores)
    effective: dict[str, float] = {}
    for subcategory in set(profile_priority_scores) | set(trip_priority_scores):
        effective[subcategory] = (
            profile_alpha * float(profile_priority_scores.get(subcategory) or 0.0)
            + trip_beta * float(trip_priority_scores.get(subcategory) or 0.0)
        )
    return normalize_priority_scores(effective)


def get_subcategory_category(subcategory: str, places_by_subcategory: dict[str, list[dict]]) -> str:
    places = places_by_subcategory.get(subcategory) or []
    return str(places[0].get("place_category") or "Unknown") if places else "Unknown"


def get_top_place(subcategory: str, places_by_subcategory: dict[str, list[dict]]) -> dict | None:
    places = places_by_subcategory.get(subcategory) or []
    return places[0] if places else None


def get_next_place_for_slot(subcategory: str, places_by_subcategory: dict, slot_by_subcategory: dict) -> dict | None:
    places = places_by_subcategory.get(subcategory) or []
    current_slot = slot_by_subcategory.get(subcategory, 0)
    return places[current_slot] if current_slot < len(places) else None


def can_allocate_slot(subcategory, places_by_subcategory, slot_by_subcategory, slot_by_place_category, max_per_subcategory, max_per_place_category) -> bool:
    places = places_by_subcategory.get(subcategory) or []
    if not places:
        return False
    current_slot = slot_by_subcategory.get(subcategory, 0)
    if current_slot >= len(places):
        return False
    if max_per_subcategory is not None and current_slot >= max_per_subcategory:
        return False
    category = get_subcategory_category(subcategory, places_by_subcategory)
    if max_per_place_category is not None and slot_by_place_category[category] >= max_per_place_category:
        return False
    return True


def allocate_slot(subcategory, reason, places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory, slot_by_place_category, allocation_logs) -> None:
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


def sort_subcategories_for_min_slots(subcategories, priority_scores, places_by_subcategory) -> list[str]:
    def key(subcategory: str):
        top_place = get_top_place(subcategory, places_by_subcategory) or {}
        return (
            float(priority_scores.get(subcategory, 0.0)),
            float(top_place.get("module1_score") or 0.0),
            float(top_place.get("average_rating") or 0.0),
            int(top_place.get("review_count") or 0),
        )
    return sorted(subcategories, key=key, reverse=True)


def allocate_minimum_related_slots(config, priority_scores, places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory, slot_by_place_category, allocation_logs):
    related = [s for s in priority_scores if places_by_subcategory.get(s)]
    ordered = sort_subcategories_for_min_slots(related, priority_scores, places_by_subcategory)
    kept = ordered[:config["top_k"]]
    skipped = ordered[config["top_k"]:]
    for subcategory in kept:
        if not can_allocate_slot(subcategory, places_by_subcategory, slot_by_subcategory, slot_by_place_category, config["max_per_subcategory"], config["max_per_place_category"]):
            continue
        allocate_slot(subcategory, "selected_by_related_min_slot", places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory, slot_by_place_category, allocation_logs)
    return kept, skipped


def pick_best_related_subcategory_for_extra_slot(related_subcategories, priority_scores, places_by_subcategory, slot_by_subcategory, slot_by_place_category, config):
    candidates = []
    for subcategory in related_subcategories:
        if not can_allocate_slot(subcategory, places_by_subcategory, slot_by_subcategory, slot_by_place_category, config["max_per_subcategory"], config["max_per_place_category"]):
            continue
        next_place = get_next_place_for_slot(subcategory, places_by_subcategory, slot_by_subcategory)
        if not next_place:
            continue
        candidates.append({
            "subcategory_name": subcategory,
            "priority_score": float(priority_scores.get(subcategory, 0.0)),
            "next_place_score": float(next_place.get("module1_score") or 0.0),
            "current_slot": slot_by_subcategory.get(subcategory, 0),
            "average_rating": float(next_place.get("average_rating") or 0.0),
            "review_count": int(next_place.get("review_count") or 0),
        })
    if not candidates:
        return None
    candidates.sort(key=lambda i: (i["priority_score"], i["next_place_score"], -i["current_slot"], i["average_rating"], i["review_count"]), reverse=True)
    return str(candidates[0]["subcategory_name"])


def allocate_related_priority_slots(config, related_subcategories, priority_scores, places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory, slot_by_place_category, allocation_logs):
    while sum(slot_by_subcategory.values()) < config["top_k"]:
        selected = pick_best_related_subcategory_for_extra_slot(related_subcategories, priority_scores, places_by_subcategory, slot_by_subcategory, slot_by_place_category, config)
        if not selected:
            break
        allocate_slot(selected, "selected_by_related_priority", places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory, slot_by_place_category, allocation_logs)


def pick_best_non_related_subcategory(config, related_subcategories, places_by_subcategory, slot_by_subcategory, slot_by_place_category):
    candidates = []
    for subcategory, places in places_by_subcategory.items():
        if subcategory in related_subcategories:
            continue
        if float(places[0].get("module1_score") or 0.0) < config["non_related_top_score_min"]:
            continue
        if not can_allocate_slot(subcategory, places_by_subcategory, slot_by_subcategory, slot_by_place_category, config["max_per_subcategory"], config["max_per_place_category"]):
            continue
        next_place = get_next_place_for_slot(subcategory, places_by_subcategory, slot_by_subcategory)
        if not next_place:
            continue
        candidates.append({"subcategory_name": subcategory, "next_place_score": float(next_place.get("module1_score") or 0.0), "average_rating": float(next_place.get("average_rating") or 0.0), "review_count": int(next_place.get("review_count") or 0)})
    if not candidates:
        return None
    candidates.sort(key=lambda i: (i["next_place_score"], i["average_rating"], i["review_count"]), reverse=True)
    return str(candidates[0]["subcategory_name"])


def allocate_non_related_high_score_slots(config, related_subcategories, places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory, slot_by_place_category, allocation_logs):
    while sum(slot_by_subcategory.values()) < config["top_k"]:
        selected = pick_best_non_related_subcategory(config, related_subcategories, places_by_subcategory, slot_by_subcategory, slot_by_place_category)
        if not selected:
            break
        allocate_slot(selected, "selected_by_non_related_score", places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory, slot_by_place_category, allocation_logs)


def allocate_refill_slots(config, places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory, slot_by_place_category, allocation_logs):
    while sum(slot_by_subcategory.values()) < config["top_k"]:
        candidates = []
        for subcategory in places_by_subcategory:
            if not can_allocate_slot(subcategory, places_by_subcategory, slot_by_subcategory, slot_by_place_category, config["max_per_subcategory"], None):
                continue
            next_place = get_next_place_for_slot(subcategory, places_by_subcategory, slot_by_subcategory)
            if not next_place:
                continue
            candidates.append({"subcategory_name": subcategory, "next_place_score": float(next_place.get("module1_score") or 0.0), "average_rating": float(next_place.get("average_rating") or 0.0), "review_count": int(next_place.get("review_count") or 0)})
        if not candidates:
            break
        candidates.sort(key=lambda i: (i["next_place_score"], i["average_rating"], i["review_count"]), reverse=True)
        allocate_slot(str(candidates[0]["subcategory_name"]), "selected_by_slot_refill", places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory, slot_by_place_category, allocation_logs)


def allocate_fallback_score_slots(config, places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory, slot_by_place_category, allocation_logs):
    while sum(slot_by_subcategory.values()) < config["top_k"]:
        candidates = []
        for subcategory in places_by_subcategory:
            next_place = get_next_place_for_slot(subcategory, places_by_subcategory, slot_by_subcategory)
            if not next_place:
                continue
            candidates.append({"subcategory_name": subcategory, "next_place_score": float(next_place.get("module1_score") or 0.0), "average_rating": float(next_place.get("average_rating") or 0.0), "review_count": int(next_place.get("review_count") or 0)})
        if not candidates:
            break
        candidates.sort(key=lambda i: (i["next_place_score"], i["average_rating"], i["review_count"]), reverse=True)
        allocate_slot(str(candidates[0]["subcategory_name"]), "selected_by_fallback_score", places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory, slot_by_place_category, allocation_logs)


def build_selected_places_from_slots(places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory) -> list[dict]:
    selected: list[dict] = []
    for subcategory, allocated_slot in slot_by_subcategory.items():
        places = places_by_subcategory.get(subcategory) or []
        reasons = slot_reasons_by_subcategory.get(subcategory) or []
        for index, place in enumerate(places[:allocated_slot], start=1):
            sp = dict(place)
            sp["allocated_subcategory_slot"] = allocated_slot
            sp["subcategory_slot_rank"] = index
            sp["diversity_reason"] = reasons[index - 1] if index - 1 < len(reasons) else "selected_by_subcategory_slot"
            selected.append(sp)
    selected.sort(key=sort_place_key, reverse=True)
    return selected


def build_quota_violations(places, max_per_subcategory, max_per_place_category):
    sc_counts = count_by_key(places, "subcategory_name")
    pc_counts = count_by_key(places, "place_category")
    return {
        "subcategory_violations": {k: {"count": c, "max_allowed": max_per_subcategory, "violation": c - max_per_subcategory} for k, c in sc_counts.items() if c > max_per_subcategory},
        "place_category_violations": {k: {"count": c, "max_allowed": max_per_place_category, "violation": c - max_per_place_category} for k, c in pc_counts.items() if c > max_per_place_category},
    }


def build_slot_by_place_category(slot_by_subcategory, places_by_subcategory) -> dict[str, int]:
    slot_by_category: Counter = Counter()
    for subcategory, allocated_slot in slot_by_subcategory.items():
        category = get_subcategory_category(subcategory, places_by_subcategory)
        slot_by_category[category] += allocated_slot
    return dict(slot_by_category)


def build_coverable_interest_map(places_by_subcategory, interest_groups) -> dict[str, bool]:
    return {key: any(places_by_subcategory.get(s) for s in group["subcategories"]) for key, group in interest_groups.items()}


def apply_diversity_selection(
    ranked_places: list[dict],
    total_days: int,
    user_selected_interests: list[str],
    trip_selected_options: list[dict] | None = None,
    trip_option_subcategory_rows: list[dict] | None = None,
) -> dict:
    normalized_places = normalize_ranked_places(ranked_places)
    config = build_diversity_config(total_days=total_days, user_selected_interests=user_selected_interests)
    profile_interest_groups = get_interest_groups(user_selected_interests)
    profile_priority_scores = build_subcategory_priority_scores(user_selected_interests)
    trip_interest_groups = build_trip_interest_groups(trip_selected_options or [], trip_option_subcategory_rows or [])
    trip_priority_scores = build_trip_subcategory_priority_scores(trip_option_subcategory_rows or [])
    has_trip_interest = bool(trip_priority_scores)
    interest_groups = trip_interest_groups if has_trip_interest else profile_interest_groups
    priority_scores = build_effective_subcategory_priority_scores(profile_priority_scores, trip_priority_scores)
    places_by_subcategory = group_places_by_subcategory(normalized_places)

    if has_trip_interest:
        related_subcategories = sorted(priority_scores.keys())
        related_place_categories = sorted({
            str((row.get("place_subcategory") or {}).get("place_category"))
            for row in (trip_option_subcategory_rows or [])
            if row.get("is_active", False) and (row.get("place_subcategory") or {}).get("place_category")
        })
        config["related_subcategories"] = related_subcategories
        config["related_subcategory_count"] = len(related_subcategories)
        config["related_place_categories"] = related_place_categories
        config["related_place_category_count"] = len(related_place_categories)

    config["priority_source"] = "trip_plus_profile" if has_trip_interest else "profile_only"
    before_top_k = normalized_places[:config["top_k"]]
    score_floor = compute_score_floor(normalized_places, config["score_floor_ratio"])

    slot_by_subcategory: dict[str, int] = {}
    slot_reasons_by_subcategory: dict[str, list[str]] = {}
    slot_by_place_category: Counter = Counter()
    allocation_logs: list[dict] = []

    related_subcategories, skipped_related = allocate_minimum_related_slots(config, priority_scores, places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory, slot_by_place_category, allocation_logs)
    allocate_related_priority_slots(config, related_subcategories, priority_scores, places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory, slot_by_place_category, allocation_logs)
    allocate_non_related_high_score_slots(config, related_subcategories, places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory, slot_by_place_category, allocation_logs)
    allocated_before_refill = sum(slot_by_subcategory.values())
    allocate_refill_slots(config, places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory, slot_by_place_category, allocation_logs)
    allocated_before_fallback = sum(slot_by_subcategory.values())
    allocate_fallback_score_slots(config, places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory, slot_by_place_category, allocation_logs)

    diversified_top_k = build_selected_places_from_slots(places_by_subcategory, slot_by_subcategory, slot_reasons_by_subcategory)[:config["top_k"]]
    selected_ids = {p.get("id_place") for p in diversified_top_k}
    overflow_pool = [p for p in normalized_places if p.get("id_place") not in selected_ids]
    low_score_pool = [p for p in normalized_places if float(p.get("module1_score") or 0.0) < score_floor]

    avg_score_before = average_score(before_top_k)
    avg_score_after = average_score(diversified_top_k)
    coverage_before = build_interest_coverage_map(before_top_k, interest_groups)
    coverage_after = build_interest_coverage_map(diversified_top_k, interest_groups)
    coverable_interest_map = build_coverable_interest_map(places_by_subcategory, interest_groups)
    missing_coverable = [k for k, coverable in coverable_interest_map.items() if coverable and not coverage_after.get(k, False)]
    strict_quota_violations = build_quota_violations(diversified_top_k, config["max_per_subcategory"], config["max_per_place_category"])
    slot_by_place_category_map = build_slot_by_place_category(slot_by_subcategory, places_by_subcategory)
    selected_count_by_subcategory = count_by_key(diversified_top_k, "subcategory_name")
    selected_count_by_place_category = count_by_key(diversified_top_k, "place_category")

    return {
        "diversified_top_k": diversified_top_k,
        "overflow_pool": overflow_pool,
        "low_score_pool": low_score_pool,
        "config": {
            **config,
            "score_floor": score_floor,
            "top1_score": round(float(normalized_places[0].get("module1_score") or 0.0), 6) if normalized_places else 0.0,
            "related_subcategories_in_pool": related_subcategories,
            "skipped_related_subcategories": skipped_related,
        },
        "summary": {
            "avg_score_before": avg_score_before,
            "avg_score_after": avg_score_after,
            "score_quality_ok": avg_score_after >= round(avg_score_before * 0.90, 6),
            "quota_quality_ok": not strict_quota_violations["subcategory_violations"] and not strict_quota_violations["place_category_violations"],
            "coverage_quality_ok": not missing_coverable,
            "slot_allocation_ok": all(selected_count_by_subcategory.get(s, 0) <= allocated for s, allocated in slot_by_subcategory.items()),
            "after_count_by_subcategory": selected_count_by_subcategory,
            "after_count_by_place_category": selected_count_by_place_category,
            "coverage_after": coverage_after,
            "missing_coverable_interests_after": missing_coverable,
            "strict_quota_violations": strict_quota_violations,
            "slot_by_subcategory": slot_by_subcategory,
            "slot_by_place_category": slot_by_place_category_map,
            "refilled_slots": max(allocated_before_fallback - allocated_before_refill, 0),
            "final_selected_count": len(diversified_top_k),
            "allocation_logs": allocation_logs,
        },
    }
