"""
services/module1_algorithm.py
Pure-logic Module 1 functions — no DB access.

Planning pipeline uses:
  build_user_interest_state_from_rows()
  rank_places_by_tag_match()

Write pipeline (Phase 2) uses:
  build_onboarding_profile(), apply_behavior_event(),
  recompute_final_weights(), merge_user_interest_state()
"""

from __future__ import annotations

from copy import deepcopy
import re
from typing import Any


RAW_WEIGHT_CAP = 2.5

BEHAVIOR_LEARNING_RATE = 0.5
BEHAVIOR_SCORE_MIN = -10.0
BEHAVIOR_SCORE_MAX = 20.0

INITIAL_ONBOARDING_LAMBDA = 0.8
MIN_ONBOARDING_LAMBDA = 0.4
LAMBDA_DECAY_PER_BEHAVIOR = 0.02

PROFILE_INTEREST_ALPHA = 0.4
TRIP_INTEREST_BETA = 0.6

SCREEN_1_MAPPING: dict[str, list[tuple[str, float]]] = {
    "food": [("food", 1.0), ("local_cuisine", 0.5)],
    "culture": [("culture", 1.0), ("history", 0.5), ("heritage", 0.5)],
    "nature": [("nature", 1.0), ("outdoor", 0.5)],
    "relaxation": [("relaxation", 1.0), ("quiet", 0.5)],
    "adventure": [("adventure", 1.0), ("activity", 0.5)],
    "shopping": [("shopping", 1.0), ("local_market", 0.5)],
    "photography": [("photography", 1.0), ("scenic_view", 0.5)],
    "local life": [("local_experience", 1.0), ("traditional_craft", 0.5)],
}

SCREEN_2_MAPPING: dict[str, list[tuple[str, float]]] = {
    "solo": [("local_experience", 0.4), ("walking", 0.4)],
    "couple": [("scenic_view", 0.5), ("relaxation", 0.4), ("photography", 0.4)],
    "friends": [("activity", 0.5), ("amusement", 0.4), ("nightlife", 0.3)],
    "family": [("family_friendly", 0.6), ("park", 0.4), ("amusement", 0.4)],
    "seniors": [("relaxation", 0.5), ("quiet", 0.4), ("indoor", 0.3)],
    "business": [("quick_visit", 0.4), ("indoor", 0.3)],
}

SCREEN_4_MAPPING: dict[str, list[tuple[str, float]]] = {
    "street food": [("street_food", 1.2), ("local_cuisine", 0.8), ("food", 0.7)],
    "coffee": [("coffee", 1.2), ("relaxation", 0.6), ("indoor", 0.4)],
    "museums": [("museum", 1.2), ("culture", 0.7), ("indoor", 0.4)],
    "temples": [("religious_site", 1.2), ("culture", 0.7), ("heritage", 0.5)],
    "festivals": [("festival", 1.2), ("culture", 0.7), ("local_experience", 0.6)],
    "beaches": [("beach", 1.2), ("nature", 0.7), ("relaxation", 0.6), ("photography", 0.5)],
    "mountains": [("mountain", 1.2), ("nature", 0.7), ("adventure", 0.7), ("photography", 0.5)],
    "night markets": [("local_market", 1.2), ("street_food", 0.8), ("shopping", 0.7), ("nightlife", 0.5)],
    "workshops": [("traditional_craft", 1.2), ("local_experience", 0.8), ("culture", 0.6)],
    "handmade goods": [("souvenir", 1.2), ("local_product", 0.8), ("traditional_craft", 0.7), ("shopping", 0.6)],
    "scenic spots": [("scenic_view", 1.2), ("photography", 0.8), ("nature", 0.6)],
    "wellness": [("relaxation", 1.2), ("quiet", 0.6)],
}

BEHAVIOR_REWARD_MAP: dict[str, float] = {
    "view_detail": 1.0,
    "long_view": 1.5,
    "favorite": 3.0,
    "share": 3.0,
    "add_to_trip": 5.0,
    "check_in": 5.0,
    "high_rating": 5.0,
    "positive_rating": 3.0,
    "skip_repeated": -1.0,
    "remove_favorite": -3.0,
    "negative_rating": -3.0,
    "low_rating": -4.0,
}


def normalize_choice_key(value: str | None) -> str:
    if not value:
        return ""
    normalized = re.sub(r"[_\-]+", " ", value.strip().lower())
    return re.sub(r"\s+", " ", normalized)


def normalize_weight_map(weight_map: dict[str, float]) -> dict[str, float]:
    total = sum(max(float(weight), 0.0) for weight in weight_map.values())
    if total <= 0:
        return {tag_code: 0.0 for tag_code in weight_map}
    return {
        tag_code: round(max(float(weight), 0.0) / total, 6)
        for tag_code, weight in weight_map.items()
    }


def collect_onboarding_raw_weights(
    travel_styles: list[str] | None,
    companion_style: str | None,
    topics: list[str] | None,
) -> dict[str, float]:
    raw_weights: dict[str, float] = {}
    for choice in travel_styles or []:
        for tag_code, raw_weight in SCREEN_1_MAPPING.get(normalize_choice_key(choice), []):
            raw_weights[tag_code] = raw_weights.get(tag_code, 0.0) + raw_weight
    for tag_code, raw_weight in SCREEN_2_MAPPING.get(normalize_choice_key(companion_style), []):
        raw_weights[tag_code] = raw_weights.get(tag_code, 0.0) + raw_weight
    for choice in topics or []:
        for tag_code, raw_weight in SCREEN_4_MAPPING.get(normalize_choice_key(choice), []):
            raw_weights[tag_code] = raw_weights.get(tag_code, 0.0) + raw_weight
    return raw_weights


def cap_raw_weights(raw_weights: dict[str, float], cap: float = RAW_WEIGHT_CAP) -> dict[str, float]:
    return {tag_code: round(min(float(weight), cap), 6) for tag_code, weight in raw_weights.items()}


def build_onboarding_profile(
    travel_styles: list[str] | None,
    companion_style: str | None,
    topics: list[str] | None,
) -> dict[str, dict[str, float]]:
    raw_weights = collect_onboarding_raw_weights(travel_styles, companion_style, topics)
    capped_raw_weights = cap_raw_weights(raw_weights)
    initial_weights = normalize_weight_map(capped_raw_weights)
    return {"raw_weights": capped_raw_weights, "initial_weights": initial_weights}


def build_user_interest_state(
    initial_weights: dict[str, float],
    tag_map: dict[str, dict] | None = None,
    source: str = "onboarding",
) -> dict[str, dict]:
    state: dict[str, dict] = {}
    for tag_code, initial_weight in initial_weights.items():
        tag_info = (tag_map or {}).get(tag_code) or {}
        state[tag_code] = {
            "tag_code": tag_code,
            "id_tag": tag_info.get("id_tag"),
            "initial_weight": round(float(initial_weight), 6),
            "behavior_score": 0.0,
            "behavior_weight": 0.0,
            "final_weight": round(float(initial_weight), 6),
            "positive_behavior_count": 0,
            "negative_behavior_count": 0,
            "behavior_count": 0,
            "source": source,
        }
    return state


def build_user_interest_state_from_rows(
    rows: list[dict],
    tag_map: dict[str, dict] | None = None,
    id_tag_map: dict[str, str] | None = None,
) -> dict[str, dict]:
    state: dict[str, dict] = {}
    for row in rows:
        tag_code = extract_tag_code(row, id_tag_map)
        if not tag_code:
            continue
        tag_info = (tag_map or {}).get(tag_code) or (row.get("tag") or {})
        state[tag_code] = {
            "tag_code": tag_code,
            "id_tag": row.get("id_tag") or tag_info.get("id_tag"),
            "initial_weight": round(float(row.get("initial_weight") or 0.0), 6),
            "behavior_score": round(float(row.get("behavior_score") or 0.0), 6),
            "behavior_weight": round(float(row.get("behavior_weight") or 0.0), 6),
            "final_weight": round(float(row.get("final_weight") or 0.0), 6),
            "positive_behavior_count": int(row.get("positive_behavior_count") or 0),
            "negative_behavior_count": int(row.get("negative_behavior_count") or 0),
            "behavior_count": int(row.get("behavior_count") or 0),
            "source": row.get("source") or "onboarding",
        }
    return state


def build_user_interest_rows(
    id_user: str,
    initial_weights: dict[str, float],
    tag_map: dict[str, dict],
    source: str = "onboarding",
) -> tuple[list[dict], list[str]]:
    rows: list[dict] = []
    missing_tag_codes: list[str] = []
    for tag_code, initial_weight in initial_weights.items():
        tag = tag_map.get(tag_code)
        if not tag:
            missing_tag_codes.append(tag_code)
            continue
        rows.append({
            "id_user": id_user,
            "id_tag": tag["id_tag"],
            "initial_weight": round(float(initial_weight), 6),
            "behavior_score": 0.0,
            "behavior_weight": 0.0,
            "final_weight": round(float(initial_weight), 6),
            "positive_behavior_count": 0,
            "negative_behavior_count": 0,
            "behavior_count": 0,
            "source": source,
        })
    return rows, missing_tag_codes


def build_user_interest_rows_from_state(
    id_user: str,
    user_interest_state: dict[str, dict],
    source: str | None = None,
) -> tuple[list[dict], list[str]]:
    rows: list[dict] = []
    missing_tag_codes: list[str] = []
    for tag_code, info in user_interest_state.items():
        id_tag = info.get("id_tag")
        if not id_tag:
            missing_tag_codes.append(tag_code)
            continue
        rows.append({
            "id_user": id_user,
            "id_tag": id_tag,
            "initial_weight": round(float(info.get("initial_weight") or 0.0), 6),
            "behavior_score": round(float(info.get("behavior_score") or 0.0), 6),
            "behavior_weight": round(float(info.get("behavior_weight") or 0.0), 6),
            "final_weight": round(float(info.get("final_weight") or 0.0), 6),
            "positive_behavior_count": int(info.get("positive_behavior_count") or 0),
            "negative_behavior_count": int(info.get("negative_behavior_count") or 0),
            "behavior_count": int(info.get("behavior_count") or 0),
            "source": source or info.get("source") or "onboarding",
        })
    return rows, missing_tag_codes


def extract_tag_code(
    tag_row: dict[str, Any],
    id_tag_map: dict[str, str] | None = None,
) -> str | None:
    if tag_row.get("tag_code"):
        return tag_row["tag_code"]
    nested_tag = tag_row.get("tag") or {}
    if nested_tag.get("tag_code"):
        return nested_tag["tag_code"]
    # Fallback: resolve via {id_tag → tag_code} when row only carries UUID
    if id_tag_map:
        id_tag = str(tag_row.get("id_tag") or "")
        if id_tag:
            return id_tag_map.get(id_tag)
    return None


def extract_tag_id(tag_row: dict[str, Any]) -> str | None:
    if tag_row.get("id_tag"):
        return tag_row["id_tag"]
    nested_tag = tag_row.get("tag") or {}
    return nested_tag.get("id_tag")


def update_behavior_scores(
    user_interest_state: dict[str, dict],
    place_tag_rows: list[dict],
    reward: float,
    eta: float = BEHAVIOR_LEARNING_RATE,
) -> dict[str, dict]:
    for place_tag in place_tag_rows:
        tag_code = extract_tag_code(place_tag)
        if not tag_code:
            continue
        confidence_score = float(place_tag.get("confidence_score") or 0.0)
        delta = float(eta) * float(reward) * confidence_score
        current = user_interest_state.setdefault(tag_code, {
            "tag_code": tag_code,
            "id_tag": extract_tag_id(place_tag),
            "initial_weight": 0.0,
            "behavior_score": 0.0,
            "behavior_weight": 0.0,
            "final_weight": 0.0,
            "source": "behavior",
        })
        current["behavior_score"] = clamp_behavior_score(
            float(current.get("behavior_score") or 0.0) + delta
        )
    return user_interest_state


def recompute_behavior_weights(user_interest_state: dict[str, dict]) -> dict[str, dict]:
    positive_scores = {
        tag_code: max(float(info.get("behavior_score") or 0.0), 0.0)
        for tag_code, info in user_interest_state.items()
    }
    total_positive_score = sum(positive_scores.values())
    for tag_code, info in user_interest_state.items():
        if total_positive_score <= 0:
            info["behavior_weight"] = 0.0
            continue
        info["behavior_weight"] = round(positive_scores[tag_code] / total_positive_score, 6)
    return user_interest_state


def calculate_behavior_lambda(behavior_count: int) -> float:
    return round(
        max(MIN_ONBOARDING_LAMBDA, INITIAL_ONBOARDING_LAMBDA - (LAMBDA_DECAY_PER_BEHAVIOR * max(behavior_count, 0))),
        6,
    )


def clamp_behavior_score(value: float) -> float:
    return round(min(BEHAVIOR_SCORE_MAX, max(BEHAVIOR_SCORE_MIN, float(value))), 6)


def extract_behavior_counters_from_state(user_interest_state: dict[str, dict]) -> tuple[int, int, int]:
    positive = negative = count = 0
    for info in user_interest_state.values():
        positive = max(positive, int(info.get("positive_behavior_count") or 0))
        negative = max(negative, int(info.get("negative_behavior_count") or 0))
        count = max(count, int(info.get("behavior_count") or 0))
    return positive, negative, count


def apply_behavior_counters_to_state(
    user_interest_state: dict[str, dict],
    positive_behavior_count: int,
    negative_behavior_count: int,
    behavior_count: int,
) -> dict[str, dict]:
    for info in user_interest_state.values():
        info["positive_behavior_count"] = max(int(positive_behavior_count), 0)
        info["negative_behavior_count"] = max(int(negative_behavior_count), 0)
        info["behavior_count"] = max(int(behavior_count), 0)
    return user_interest_state


def infer_behavior_count_from_state(user_interest_state: dict[str, dict]) -> int:
    lambda_candidates: list[float] = []
    has_behavior_signal = False
    for info in user_interest_state.values():
        initial_weight = float(info.get("initial_weight") or 0.0)
        behavior_weight = float(info.get("behavior_weight") or 0.0)
        final_weight = float(info.get("final_weight") or 0.0)
        behavior_score = float(info.get("behavior_score") or 0.0)
        if abs(behavior_score) > 1e-9:
            has_behavior_signal = True
        denominator = initial_weight - behavior_weight
        if abs(denominator) <= 1e-9:
            continue
        lambda_value = (final_weight - behavior_weight) / denominator
        if 0.0 <= lambda_value <= 1.0:
            lambda_candidates.append(lambda_value)
    if not lambda_candidates:
        return 1 if has_behavior_signal else 0
    average_lambda = sum(lambda_candidates) / len(lambda_candidates)
    clamped_lambda = min(INITIAL_ONBOARDING_LAMBDA, max(MIN_ONBOARDING_LAMBDA, average_lambda))
    inferred = round((INITIAL_ONBOARDING_LAMBDA - clamped_lambda) / LAMBDA_DECAY_PER_BEHAVIOR)
    return max(1, inferred) if has_behavior_signal else max(0, inferred)


def recompute_final_weights(user_interest_state: dict[str, dict], behavior_count: int) -> dict[str, dict]:
    lambda_value = calculate_behavior_lambda(behavior_count)
    raw_final_weights: dict[str, float] = {}
    for tag_code, info in user_interest_state.items():
        initial_weight = float(info.get("initial_weight") or 0.0)
        behavior_weight = float(info.get("behavior_weight") or 0.0)
        if behavior_count <= 0:
            raw_final_weights[tag_code] = initial_weight
        else:
            raw_final_weights[tag_code] = lambda_value * initial_weight + (1.0 - lambda_value) * behavior_weight
    normalized = normalize_weight_map(raw_final_weights)
    for tag_code, info in user_interest_state.items():
        info["final_weight"] = normalized.get(tag_code, 0.0)
    return user_interest_state


def merge_user_interest_state(
    initial_weights: dict[str, float],
    existing_rows: list[dict],
    tag_map: dict[str, dict] | None = None,
    behavior_count: int = 0,
    source: str = "onboarding",
) -> tuple[dict[str, dict], int]:
    existing_state = build_user_interest_state_from_rows(rows=existing_rows, tag_map=tag_map)
    ep, en, stored = extract_behavior_counters_from_state(existing_state)
    effective_behavior_count = max(int(behavior_count or 0), stored, infer_behavior_count_from_state(existing_state))
    merged_state: dict[str, dict] = {}
    for tag_code in sorted(set(existing_state) | set(initial_weights)):
        existing_info = existing_state.get(tag_code) or {}
        tag_info = (tag_map or {}).get(tag_code) or {}
        merged_state[tag_code] = {
            "tag_code": tag_code,
            "id_tag": existing_info.get("id_tag") or tag_info.get("id_tag"),
            "initial_weight": round(float(initial_weights.get(tag_code) or 0.0), 6),
            "behavior_score": round(float(existing_info.get("behavior_score") or 0.0), 6),
            "behavior_weight": round(float(existing_info.get("behavior_weight") or 0.0), 6),
            "final_weight": round(float(existing_info.get("final_weight") or 0.0), 6),
            "positive_behavior_count": int(existing_info.get("positive_behavior_count") or ep),
            "negative_behavior_count": int(existing_info.get("negative_behavior_count") or en),
            "behavior_count": int(existing_info.get("behavior_count") or effective_behavior_count),
            "source": existing_info.get("source") or source,
        }
    apply_behavior_counters_to_state(merged_state, ep, en, effective_behavior_count)
    recompute_behavior_weights(merged_state)
    recompute_final_weights(merged_state, effective_behavior_count)
    return merged_state, effective_behavior_count


def behavior_event_to_reward(behavior_event: str) -> float:
    key = normalize_choice_key(behavior_event).replace(" ", "_")
    if key not in BEHAVIOR_REWARD_MAP:
        raise ValueError(f"Unsupported behavior_event: {behavior_event}")
    return BEHAVIOR_REWARD_MAP[key]


def rating_to_behavior_event(rating: int | float) -> str | None:
    numeric_rating = float(rating)
    if numeric_rating >= 5:
        return "high_rating"
    if numeric_rating >= 4:
        return "positive_rating"
    if numeric_rating <= 1:
        return "low_rating"
    if numeric_rating <= 2:
        return "negative_rating"
    return None


def apply_behavior_event(
    user_interest_state: dict[str, dict],
    place_tag_rows: list[dict],
    behavior_event: str,
    behavior_count: int,
    eta: float = BEHAVIOR_LEARNING_RATE,
) -> tuple[dict[str, dict], int]:
    reward = behavior_event_to_reward(behavior_event)
    update_behavior_scores(user_interest_state, place_tag_rows, reward, eta)
    ep, en, current_count = extract_behavior_counters_from_state(user_interest_state)
    recompute_behavior_weights(user_interest_state)
    new_count = max(max(behavior_count, 0) + 1, current_count + 1)
    new_ep = ep + (1 if reward >= 0 else 0)
    new_en = en + (1 if reward < 0 else 0)
    apply_behavior_counters_to_state(user_interest_state, new_ep, new_en, new_count)
    recompute_final_weights(user_interest_state, new_count)
    return user_interest_state, new_count


def calculate_tag_match(
    user_interest_state: dict[str, dict],
    place_tag_rows: list[dict],
    weight_field: str = "final_weight",
    id_tag_map: dict[str, str] | None = None,
) -> tuple[float, list[dict]]:
    denominator = sum(
        max(float(info.get(weight_field) or 0.0), 0.0)
        for info in user_interest_state.values()
    )
    if denominator <= 0:
        return 0.0, []

    confidence_by_tag_code: dict[str, float] = {}
    for place_tag in place_tag_rows:
        tag_code = extract_tag_code(place_tag, id_tag_map)
        if not tag_code:
            continue
        confidence_score = float(place_tag.get("confidence_score") or 0.0)
        confidence_by_tag_code[tag_code] = max(confidence_by_tag_code.get(tag_code, 0.0), confidence_score)

    score = 0.0
    matched_tags: list[dict] = []
    for tag_code, info in user_interest_state.items():
        interest_weight = float(info.get(weight_field) or 0.0)
        confidence_score = confidence_by_tag_code.get(tag_code)
        if confidence_score is None:
            continue
        contribution = interest_weight * confidence_score
        score += contribution
        matched_tag = {
            "tag_code": tag_code,
            "interest_weight": round(interest_weight, 6),
            "confidence_score": round(confidence_score, 6),
            "contribution": round(contribution, 6),
        }
        if weight_field == "final_weight":
            matched_tag["final_weight"] = round(interest_weight, 6)
        elif weight_field == "effective_weight":
            matched_tag["effective_weight"] = round(interest_weight, 6)
        matched_tags.append(matched_tag)

    score = round(score / denominator, 6)
    matched_tags.sort(key=lambda item: item["contribution"], reverse=True)
    return score, matched_tags


def rank_places_by_tag_match(
    places: list[dict],
    user_interest_state: dict[str, dict],
    weight_field: str = "final_weight",
    id_tag_map: dict[str, str] | None = None,
) -> list[dict]:
    ranked_places: list[dict] = []
    for place in places:
        tag_match, matched_tags = calculate_tag_match(
            user_interest_state=user_interest_state,
            place_tag_rows=place.get("place_tag") or [],
            weight_field=weight_field,
            id_tag_map=id_tag_map,
        )
        ranked_place = dict(place)
        ranked_place["tag_match"] = tag_match
        ranked_place["module1_score"] = tag_match
        ranked_place["matched_user_tags"] = matched_tags
        ranked_places.append(ranked_place)

    ranked_places.sort(
        key=lambda place: (
            float(place.get("module1_score") or place.get("tag_match") or 0.0),
            float(place.get("average_rating") or 0.0),
            int(place.get("review_count") or 0),
        ),
        reverse=True,
    )
    return ranked_places


def build_trip_interest_profile(
    trip_interest_choice_rows: list[dict],
    trip_interest_option_tag_rows: list[dict],
    id_tag_map: dict[str, str] | None = None,
) -> dict[str, Any]:
    selected_option_map: dict[str, dict] = {}
    for row in trip_interest_choice_rows:
        option = row.get("trip_interest_option") or {}
        option_id = row.get("id_trip_interest_option") or option.get("id_trip_interest_option")
        if not option_id or not option.get("is_active", False):
            continue
        selected_option_map[str(option_id)] = {
            "id_trip_interest_option": option_id,
            "option_code": option.get("option_code"),
            "display_name": option.get("display_name"),
            "selection_order": row.get("selection_order"),
            "source": row.get("source"),
            "display_order": option.get("display_order"),
        }

    selected_options = sorted(
        selected_option_map.values(),
        key=lambda item: (
            item.get("selection_order") is None,
            int(item.get("selection_order") or 10_000),
            int(item.get("display_order") or 0),
            str(item.get("option_code") or ""),
        ),
    )

    raw_tag_weights: dict[str, float] = {}
    trip_tag_info_map: dict[str, dict[str, Any]] = {}
    option_tag_details: list[dict] = []

    for row in trip_interest_option_tag_rows:
        if not row.get("is_active", False):
            continue
        option_id = str(row.get("id_trip_interest_option") or "")
        option_info = selected_option_map.get(option_id)
        if not option_info:
            continue
        tag_code = extract_tag_code(row, id_tag_map)
        if not tag_code:
            continue
        raw_weight = float(row.get("raw_weight") or 0.0)
        raw_tag_weights[tag_code] = raw_tag_weights.get(tag_code, 0.0) + raw_weight
        trip_tag_info_map[tag_code] = {
            "id_tag": extract_tag_id(row),
            "tag_code": tag_code,
            "tag_name": (row.get("tag") or {}).get("tag_name"),
            "tag_group": (row.get("tag") or {}).get("tag_group"),
        }
        option_tag_details.append({
            "option_code": option_info.get("option_code"),
            "display_name": option_info.get("display_name"),
            "tag_code": tag_code,
            "weight_level": row.get("weight_level"),
            "raw_weight": round(raw_weight, 6),
        })

    normalized_tag_weights = normalize_weight_map(raw_tag_weights)
    return {
        "selected_options": selected_options,
        "selected_option_codes": [o.get("option_code") for o in selected_options if o.get("option_code")],
        "raw_tag_weights": {tc: round(rw, 6) for tc, rw in raw_tag_weights.items()},
        "normalized_tag_weights": normalized_tag_weights,
        "trip_tag_info_map": trip_tag_info_map,
        "option_tag_details": option_tag_details,
    }


def build_effective_interest_state(
    user_interest_state: dict[str, dict],
    trip_weight_map: dict[str, float],
    trip_tag_info_map: dict[str, dict[str, Any]] | None = None,
    alpha: float = PROFILE_INTEREST_ALPHA,
    beta: float = TRIP_INTEREST_BETA,
) -> dict[str, Any]:
    effective_interest_state = deepcopy(user_interest_state)
    if not trip_weight_map:
        effective_weight_map = {
            tc: round(float(info.get("final_weight") or 0.0), 6)
            for tc, info in effective_interest_state.items()
        }
        for tc, info in effective_interest_state.items():
            info["user_final_weight"] = round(float(info.get("final_weight") or 0.0), 6)
            info["trip_weight"] = 0.0
            info["effective_weight"] = effective_weight_map[tc]
        return {"effective_interest_state": effective_interest_state, "effective_weight_map": effective_weight_map, "alpha": 1.0, "beta": 0.0}

    all_tag_codes = set(effective_interest_state) | set(trip_weight_map)
    raw_effective_weight_map: dict[str, float] = {}
    for tag_code in all_tag_codes:
        info = effective_interest_state.get(tag_code)
        if not info:
            tag_info = (trip_tag_info_map or {}).get(tag_code) or {}
            info = {
                "tag_code": tag_code, "id_tag": tag_info.get("id_tag"),
                "initial_weight": 0.0, "behavior_score": 0.0, "behavior_weight": 0.0,
                "final_weight": 0.0, "positive_behavior_count": 0,
                "negative_behavior_count": 0, "behavior_count": 0, "source": "trip_interest",
            }
            effective_interest_state[tag_code] = info
        user_final_weight = float(info.get("final_weight") or 0.0)
        trip_weight = float(trip_weight_map.get(tag_code) or 0.0)
        raw_effective_weight_map[tag_code] = alpha * user_final_weight + beta * trip_weight
        info["user_final_weight"] = round(user_final_weight, 6)
        info["trip_weight"] = round(trip_weight, 6)

    effective_weight_map = normalize_weight_map(raw_effective_weight_map)
    for tc, info in effective_interest_state.items():
        info["effective_weight"] = effective_weight_map.get(tc, 0.0)
    return {
        "effective_interest_state": effective_interest_state,
        "effective_weight_map": effective_weight_map,
        "alpha": round(alpha, 6),
        "beta": round(beta, 6),
    }


def compute_alpha(cf_scores: dict, total_places: int) -> float:
    """
    Dynamic CB/CF blend weight based on CF coverage for this candidate set.
    Coverage = % of candidate places with a POSITIVE predicted CF affinity
    (cf_score > 0.5, the sigmoid midpoint / U·V=0) — not merely "has a score
    at all". cf_scores is expected to be dict[id_place, float].
    Shared by recommend_service.py, trip_planner.py, and routes/recommend.py.
    """
    if total_places == 0:
        return 1.0
    coverage = len([s for s in cf_scores.values() if s > 0.5]) / total_places
    if coverage == 0:   return 1.0
    if coverage < 0.10: return 0.7
    if coverage < 0.30: return 0.5
    return 0.3


def select_top_k_after_tag_match(
    ranked_places: list[dict],
    total_days: int,
    candidates_per_day: int,
) -> tuple[list[dict], int]:
    top_k = max(int(total_days), 0) * max(int(candidates_per_day), 0)
    if top_k <= 0:
        return [], 0
    return ranked_places[:top_k], top_k
