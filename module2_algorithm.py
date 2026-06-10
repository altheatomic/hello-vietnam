"""
Module 2 algorithm:
- receive Top K candidate places from Module 1
- cluster them by geography with K-means
- choose primary places per day
- repair underfilled, overfilled, or overloaded days
"""

from __future__ import annotations

from collections import defaultdict
from copy import deepcopy
from datetime import timedelta
import math
from typing import Any

from sklearn.cluster import KMeans

from config import (
    CANDIDATE_PER_DAY,
    DEFAULT_PACE_LEVEL,
    DEFAULT_VISIT_DURATION_MINUTES,
    HIGH_RANK_TOP_PERCENT,
    KMEANS_N_INIT,
    KMEANS_RANDOM_STATE,
    MAX_VISIT_DURATION_MINUTES,
    PACE_DAY_RULES,
    REPAIR_DISTANCE_RHO,
    REPAIR_RELAXED_DISTANCE_RHO,
)
from filters import parse_date


DURATION_KEYWORD_RULES = [
    (("coffee", "cà phê", "cafe", "trà", "tea"), 60),
    (("quán ăn", "local food", "ăn uống", "street food"), 60),
    (("restaurant", "nhà hàng", "fine dining"), 90),
    (("market", "chợ"), 60),
    (("history", "historical", "di tích", "lịch sử", "heritage"), 90),
    (("museum", "bảo tàng", "nghệ thuật", "art"), 120),
    (("temple", "church", "religious", "tâm linh", "tôn giáo", "worship"), 60),
    (("park", "garden", "công viên", "vườn"), 90),
    (("beach", "island", "biển", "đảo"), 150),
    (("amusement", "theme park", "water park", "giải trí", "vui chơi"), 180),
    (("mountain", "forest", "national park", "núi", "rừng"), 240),
]


def get_pace_rule(pace_level: str | None) -> dict[str, int]:
    normalized = (pace_level or DEFAULT_PACE_LEVEL).strip().lower()
    return dict(PACE_DAY_RULES.get(normalized, PACE_DAY_RULES[DEFAULT_PACE_LEVEL]))


def build_module2_limits(total_days: int, pace_level: str | None) -> dict[str, int]:
    pace_rule = get_pace_rule(pace_level)

    return {
        "candidate_limit": total_days * CANDIDATE_PER_DAY,
        "target_per_day": pace_rule["target_per_day"],
        "min_per_day": pace_rule["min_per_day"],
        "max_per_day": pace_rule["max_per_day"],
        "target_total_places": total_days * pace_rule["target_per_day"],
        "min_total_places": total_days * pace_rule["min_per_day"],
        "max_total_places": total_days * pace_rule["max_per_day"],
        "max_visit_duration_minutes": MAX_VISIT_DURATION_MINUTES,
    }


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    radius_km = 6371.0

    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (
        math.sin(delta_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return radius_km * c


def is_valid_coordinate(latitude: Any, longitude: Any) -> bool:
    try:
        lat = float(latitude)
        lon = float(longitude)
    except (TypeError, ValueError):
        return False

    return -90 <= lat <= 90 and -180 <= lon <= 180


def extract_subcategory_name(place: dict) -> str:
    subcategory = place.get("place_subcategory") or {}
    return str(subcategory.get("name") or "")


def extract_is_itinerary_eligible(place: dict) -> bool:
    subcategory = place.get("place_subcategory") or {}
    return subcategory.get("is_itinerary_eligible") is True


def estimate_duration_minutes(place: dict) -> int:
    duration = place.get("estimated_duration_minutes")

    try:
        if duration is not None and int(duration) > 0:
            return int(duration)
    except (TypeError, ValueError):
        pass

    search_text = " ".join(
        part.lower()
        for part in [
            extract_subcategory_name(place),
            str((place.get("place_subcategory") or {}).get("place_category") or ""),
            str(place.get("name") or ""),
            str(place.get("short_description") or ""),
        ]
        if part
    )

    for keywords, fallback_duration in DURATION_KEYWORD_RULES:
        if any(keyword in search_text for keyword in keywords):
            return fallback_duration

    return DEFAULT_VISIT_DURATION_MINUTES


def compute_high_rank_threshold(places: list[dict]) -> float:
    if not places:
        return 0.0

    sorted_scores = sorted(
        (float(place.get("module1_score") or 0.0) for place in places),
        reverse=True,
    )
    top_count = max(1, math.ceil(len(sorted_scores) * HIGH_RANK_TOP_PERCENT))
    return sorted_scores[top_count - 1]


def normalize_module2_place(place: dict) -> dict:
    normalized_place = dict(place)
    normalized_place["module1_score"] = float(
        place.get("module1_score") or place.get("tag_match") or 0.0
    )
    normalized_place["estimated_duration_minutes"] = estimate_duration_minutes(place)
    normalized_place["subcategory_name"] = extract_subcategory_name(place)
    normalized_place["is_itinerary_eligible"] = extract_is_itinerary_eligible(place)
    normalized_place["cluster_label"] = None
    return normalized_place


def prepare_module2_candidates(
    top_places: list[dict],
    total_days: int,
    pace_level: str | None,
) -> tuple[list[dict], list[dict], dict]:
    limits = build_module2_limits(total_days=total_days, pace_level=pace_level)
    candidate_places = top_places[:limits["candidate_limit"]]

    valid_candidates: list[dict] = []
    rejected_candidates: list[dict] = []

    for place in candidate_places:
        normalized_place = normalize_module2_place(place)

        if not is_valid_coordinate(
            normalized_place.get("latitude"),
            normalized_place.get("longitude"),
        ):
            normalized_place["module2_rejection_reason"] = "invalid_coordinate"
            rejected_candidates.append(normalized_place)
            continue

        if normalized_place.get("is_itinerary_eligible") is not True:
            normalized_place["module2_rejection_reason"] = "not_itinerary_eligible"
            rejected_candidates.append(normalized_place)
            continue

        if normalized_place.get("module1_score") is None:
            normalized_place["module2_rejection_reason"] = "missing_module1_score"
            rejected_candidates.append(normalized_place)
            continue

        valid_candidates.append(normalized_place)

    return valid_candidates, rejected_candidates, limits


def sort_cluster_labels(clustered_places: list[dict]) -> list[int]:
    cluster_centroids: dict[int, tuple[float, float]] = {}

    for label in sorted({int(place["cluster_label"]) for place in clustered_places}):
        members = [place for place in clustered_places if int(place["cluster_label"]) == label]
        avg_lat = sum(float(place["latitude"]) for place in members) / len(members)
        avg_lon = sum(float(place["longitude"]) for place in members) / len(members)
        cluster_centroids[label] = (avg_lat, avg_lon)

    return sorted(
        cluster_centroids.keys(),
        key=lambda label: (cluster_centroids[label][0], cluster_centroids[label][1]),
    )


def cluster_places_by_day(
    candidate_places: list[dict],
    total_days: int,
) -> tuple[list[dict], list[dict]]:
    if not candidate_places:
        return [], []

    cluster_count = min(max(total_days, 1), len(candidate_places))
    coordinates = [
        [float(place["latitude"]), float(place["longitude"])]
        for place in candidate_places
    ]

    if cluster_count == 1:
        labels = [0] * len(candidate_places)
    else:
        kmeans = KMeans(
            n_clusters=cluster_count,
            random_state=KMEANS_RANDOM_STATE,
            n_init=KMEANS_N_INIT,
        )
        labels = kmeans.fit_predict(coordinates).tolist()

    clustered_places = []

    for place, label in zip(candidate_places, labels):
        clustered_place = dict(place)
        clustered_place["cluster_label"] = int(label)
        clustered_places.append(clustered_place)

    sorted_labels = sort_cluster_labels(clustered_places)
    label_to_day_index = {label: index for index, label in enumerate(sorted_labels)}

    for place in clustered_places:
        place["day_index"] = label_to_day_index[int(place["cluster_label"])]

    return clustered_places, sorted_labels


def compute_centroid(places: list[dict]) -> tuple[float, float] | None:
    if not places:
        return None

    return (
        sum(float(place["latitude"]) for place in places) / len(places),
        sum(float(place["longitude"]) for place in places) / len(places),
    )


def average_distance_to_centroid(places: list[dict], centroid: tuple[float, float] | None) -> float:
    if not places or centroid is None:
        return 0.0

    distances = [
        haversine_km(
            float(place["latitude"]),
            float(place["longitude"]),
            centroid[0],
            centroid[1],
        )
        for place in places
    ]

    return sum(distances) / len(distances)


def build_initial_day_clusters(
    clustered_places: list[dict],
    sorted_labels: list[int],
    total_days: int,
    start_date: str,
    limits: dict,
) -> tuple[list[dict], list[dict]]:
    grouped_places: dict[int, list[dict]] = defaultdict(list)

    for place in clustered_places:
        grouped_places[int(place["day_index"])].append(place)

    start = parse_date(start_date)
    day_clusters: list[dict] = []
    backup_places: list[dict] = []

    for day_index in range(total_days):
        cluster_places = grouped_places.get(day_index, [])
        cluster_places.sort(
            key=lambda place: (
                float(place.get("module1_score") or 0.0),
                float(place.get("average_rating") or 0.0),
                int(place.get("review_count") or 0),
            ),
            reverse=True,
        )

        primary_places = cluster_places[:limits["target_per_day"]]
        backup_places.extend(cluster_places[limits["target_per_day"]:])

        centroid = compute_centroid(cluster_places)
        total_duration_minutes = sum(
            int(place.get("estimated_duration_minutes") or 0)
            for place in primary_places
        )
        day_clusters.append({
            "day": day_index + 1,
            "date": (start + timedelta(days=day_index)).isoformat(),
            "cluster_label": sorted_labels[day_index] if day_index < len(sorted_labels) else None,
            "places": primary_places,
            "centroid": centroid,
            "place_count": len(primary_places),
            "total_duration_minutes": total_duration_minutes,
            "warnings": [],
        })

    return day_clusters, backup_places


def day_total_duration(day_cluster: dict) -> int:
    return sum(
        int(place.get("estimated_duration_minutes") or 0)
        for place in day_cluster["places"]
    )


def day_is_valid(day_cluster: dict, limits: dict, min_per_day_override: int | None = None) -> bool:
    min_per_day = (
        min_per_day_override
        if min_per_day_override is not None
        else limits["min_per_day"]
    )

    place_count = len(day_cluster["places"])
    return (
        min_per_day <= place_count <= limits["max_per_day"]
        and day_total_duration(day_cluster) <= limits["max_visit_duration_minutes"]
    )


def recompute_day_centroid(day_cluster: dict) -> None:
    day_cluster["centroid"] = compute_centroid(day_cluster["places"])


def place_distance_to_day(place: dict, day_cluster: dict) -> float:
    centroid = day_cluster.get("centroid")

    if centroid is None:
        return 0.0

    return haversine_km(
        float(place["latitude"]),
        float(place["longitude"]),
        centroid[0],
        centroid[1],
    )


def compute_add_score(place: dict, day_cluster: dict, limits: dict) -> float:
    module1_score = float(place.get("module1_score") or 0.0)
    distance_km = place_distance_to_day(place, day_cluster)
    duration_minutes = int(place.get("estimated_duration_minutes") or 0)
    projected_duration = day_total_duration(day_cluster) + duration_minutes
    duration_penalty = max(
        projected_duration - limits["max_visit_duration_minutes"],
        0,
    ) / 60.0

    return round((10 * module1_score) - distance_km - duration_penalty, 6)


def build_add_reason(
    place: dict,
    day_cluster: dict,
    limits: dict,
    distance_rho: float,
) -> dict:
    distance_km = round(place_distance_to_day(place, day_cluster), 3)
    projected_duration = (
        day_total_duration(day_cluster)
        + int(place.get("estimated_duration_minutes") or 0)
    )
    return {
        "underfilled_day": day_cluster["day"],
        "current_place_count": len(day_cluster["places"]),
        "required_min_per_day": limits["min_per_day"],
        "selected_add_score": compute_add_score(place, day_cluster, limits),
        "module1_score": round(float(place.get("module1_score") or 0.0), 6),
        "distance_to_day_centroid_km": distance_km,
        "estimated_duration_minutes": int(place.get("estimated_duration_minutes") or 0),
        "projected_day_duration_minutes": projected_duration,
        "distance_rho_used": distance_rho,
    }


def compute_move_score(place: dict, day_cluster: dict) -> float:
    module1_score = float(place.get("module1_score") or 0.0)
    distance_km = place_distance_to_day(place, day_cluster)
    duration_hours = int(place.get("estimated_duration_minutes") or 0) / 60.0
    return round(distance_km + duration_hours - (10 * module1_score), 6)


def build_move_reason(
    place: dict,
    day_cluster: dict,
    limits: dict,
) -> dict:
    current_duration = day_total_duration(day_cluster)
    return {
        "source_day": day_cluster["day"],
        "current_place_count": len(day_cluster["places"]),
        "max_per_day": limits["max_per_day"],
        "current_day_duration_minutes": current_duration,
        "max_visit_duration_minutes": limits["max_visit_duration_minutes"],
        "selected_move_score": compute_move_score(place, day_cluster),
        "module1_score": round(float(place.get("module1_score") or 0.0), 6),
        "distance_to_day_centroid_km": round(place_distance_to_day(place, day_cluster), 3),
        "estimated_duration_minutes": int(place.get("estimated_duration_minutes") or 0),
        "trigger": (
            "overfilled_and_overloaded"
            if len(day_cluster["places"]) > limits["max_per_day"]
            and current_duration > limits["max_visit_duration_minutes"]
            else "overfilled"
            if len(day_cluster["places"]) > limits["max_per_day"]
            else "overloaded"
        ),
    }


def can_add_place_to_day(
    place: dict,
    day_cluster: dict,
    limits: dict,
    distance_rho: float,
) -> bool:
    if len(day_cluster["places"]) >= limits["max_per_day"]:
        return False

    if day_total_duration(day_cluster) + int(place.get("estimated_duration_minutes") or 0) > limits["max_visit_duration_minutes"]:
        return False

    centroid = day_cluster.get("centroid")

    if centroid is None:
        return True

    avg_distance = average_distance_to_centroid(day_cluster["places"], centroid)
    max_allowed_distance = max(avg_distance * distance_rho, 3.0)
    return place_distance_to_day(place, day_cluster) <= max_allowed_distance


def move_place_to_day(
    place: dict,
    source_places: list[dict],
    target_day: dict,
    source_day: dict | None = None,
) -> None:
    if place in source_places:
        source_places.remove(place)
    if source_day is not None:
        recompute_day_centroid(source_day)
    target_day["places"].append(place)
    recompute_day_centroid(target_day)


def try_fill_underfilled_days(
    day_clusters: list[dict],
    backup_places: list[dict],
    limits: dict,
    repair_logs: list[dict],
) -> bool:
    changed = False

    for distance_rho in (REPAIR_DISTANCE_RHO, REPAIR_RELAXED_DISTANCE_RHO):
        for day_cluster in day_clusters:
            while len(day_cluster["places"]) < limits["min_per_day"]:
                candidate_sources: list[tuple[dict, list[dict], dict | None]] = [
                    (place, backup_places, None) for place in backup_places
                ]

                for other_day in day_clusters:
                    if other_day is day_cluster or len(other_day["places"]) <= limits["min_per_day"]:
                        continue

                    for place in other_day["places"]:
                        candidate_sources.append((place, other_day["places"], other_day))

                viable_candidates = [
                    (place, source_places, source_day)
                    for place, source_places, source_day in candidate_sources
                    if can_add_place_to_day(
                        place=place,
                        day_cluster=day_cluster,
                        limits=limits,
                        distance_rho=distance_rho,
                    )
                ]

                if not viable_candidates:
                    repair_logs.append({
                        "action": "cannot_fill_underfilled_day",
                        "day": day_cluster["day"],
                        "reason": {
                            "current_place_count": len(day_cluster["places"]),
                            "required_min_per_day": limits["min_per_day"],
                            "available_backup_places": len(backup_places),
                            "distance_rho_used": distance_rho,
                        },
                    })
                    break

                best_place, source_places, source_day = max(
                    viable_candidates,
                    key=lambda item: compute_add_score(
                        place=item[0],
                        day_cluster=day_cluster,
                        limits=limits,
                    ),
                )

                move_place_to_day(
                    place=best_place,
                    source_places=source_places,
                    target_day=day_cluster,
                    source_day=source_day,
                )
                repair_logs.append({
                    "action": "add_place_to_underfilled_day",
                    "day": day_cluster["day"],
                    "place_name": best_place.get("name"),
                    "id_place": best_place.get("id_place"),
                    "source": (
                        f"day_{source_day['day']}"
                        if source_day is not None
                        else "backup_places"
                    ),
                    "reason": build_add_reason(
                        place=best_place,
                        day_cluster=day_cluster,
                        limits=limits,
                        distance_rho=distance_rho,
                    ),
                })
                changed = True

    return changed


def place_is_high_rank(place: dict, high_rank_threshold: float) -> bool:
    return float(place.get("module1_score") or 0.0) >= high_rank_threshold


def find_best_target_day_for_move(
    place: dict,
    source_day: dict,
    day_clusters: list[dict],
    limits: dict,
) -> dict | None:
    candidate_days = [
        day_cluster
        for day_cluster in day_clusters
        if day_cluster is not source_day
        and can_add_place_to_day(
            place=place,
            day_cluster=day_cluster,
            limits=limits,
            distance_rho=REPAIR_DISTANCE_RHO,
        )
    ]

    if not candidate_days:
        return None

    return max(
        candidate_days,
        key=lambda day_cluster: compute_add_score(
            place=place,
            day_cluster=day_cluster,
            limits=limits,
        ),
    )


def try_fix_overfilled_or_overloaded_days(
    day_clusters: list[dict],
    backup_places: list[dict],
    optional_places: list[dict],
    limits: dict,
    high_rank_threshold: float,
    repair_logs: list[dict],
) -> bool:
    changed = False

    for day_cluster in day_clusters:
        while (
            len(day_cluster["places"]) > limits["max_per_day"]
            or day_total_duration(day_cluster) > limits["max_visit_duration_minutes"]
        ):
            if not day_cluster["places"]:
                break

            move_candidates = sorted(
                day_cluster["places"],
                key=lambda place: compute_move_score(place, day_cluster),
                reverse=True,
            )
            place_to_move = move_candidates[0]
            move_reason = build_move_reason(
                place=place_to_move,
                day_cluster=day_cluster,
                limits=limits,
            )
            target_day = find_best_target_day_for_move(
                place=place_to_move,
                source_day=day_cluster,
                day_clusters=day_clusters,
                limits=limits,
            )

            day_cluster["places"].remove(place_to_move)
            recompute_day_centroid(day_cluster)

            if target_day is not None:
                target_day["places"].append(place_to_move)
                recompute_day_centroid(target_day)
                repair_logs.append({
                    "action": "move_place_to_other_day",
                    "day": day_cluster["day"],
                    "target_day": target_day["day"],
                    "place_name": place_to_move.get("name"),
                    "id_place": place_to_move.get("id_place"),
                    "reason": {
                        **move_reason,
                        "target_day_add_score": compute_add_score(
                            place_to_move,
                            target_day,
                            limits,
                        ),
                    },
                })
            elif place_is_high_rank(place_to_move, high_rank_threshold):
                optional_places.append(place_to_move)
                repair_logs.append({
                    "action": "move_high_rank_place_to_optional",
                    "day": day_cluster["day"],
                    "place_name": place_to_move.get("name"),
                    "id_place": place_to_move.get("id_place"),
                    "reason": {
                        **move_reason,
                        "high_rank_threshold": round(high_rank_threshold, 6),
                        "why_optional": "high_rank_place_could_not_fit_any_other_day",
                    },
                })
            else:
                backup_places.append(place_to_move)
                repair_logs.append({
                    "action": "move_place_to_backup",
                    "day": day_cluster["day"],
                    "place_name": place_to_move.get("name"),
                    "id_place": place_to_move.get("id_place"),
                    "reason": {
                        **move_reason,
                        "why_backup": "place_could_not_fit_any_other_day_and_was_not_high_rank",
                    },
                })

            changed = True

    return changed


def add_day_warnings(day_clusters: list[dict], limits: dict) -> None:
    relaxed_min = max(limits["min_per_day"] - 1, 2)

    for day_cluster in day_clusters:
        day_cluster["warnings"] = []

        if len(day_cluster["places"]) < limits["min_per_day"]:
            if len(day_cluster["places"]) >= relaxed_min:
                day_cluster["warnings"].append(
                    f"below_min_per_day_kept_with_relaxed_min={relaxed_min}"
                )
            else:
                day_cluster["warnings"].append("not_enough_places_even_after_repair")

        if len(day_cluster["places"]) > limits["max_per_day"]:
            day_cluster["warnings"].append("exceeds_max_per_day_after_repair")

        if day_total_duration(day_cluster) > limits["max_visit_duration_minutes"]:
            day_cluster["warnings"].append("exceeds_max_visit_duration_after_repair")


def deduplicate_places(places: list[dict]) -> list[dict]:
    seen_place_ids: set[str] = set()
    result: list[dict] = []

    for place in places:
        place_id = str(place.get("id_place") or "")

        if not place_id or place_id in seen_place_ids:
            continue

        seen_place_ids.add(place_id)
        result.append(place)

    return result


def build_module2_result(
    top_places: list[dict],
    start_date: str,
    end_date: str,
    pace_level: str | None,
) -> dict:
    total_days = (parse_date(end_date) - parse_date(start_date)).days + 1

    candidate_places, rejected_places, limits = prepare_module2_candidates(
        top_places=top_places,
        total_days=total_days,
        pace_level=pace_level,
    )

    if not candidate_places:
        return {
            "day_clusters": [],
            "backup_places": [],
            "optional_places": [],
            "rejected_places": rejected_places,
            "limits": limits,
            "summary": {
                "total_days": total_days,
                "candidate_count": 0,
                "selected_main_place_count": 0,
                "backup_place_count": 0,
                "optional_place_count": 0,
                "rejected_place_count": len(rejected_places),
            },
        }

    clustered_places, sorted_labels = cluster_places_by_day(
        candidate_places=candidate_places,
        total_days=total_days,
    )
    day_clusters, backup_places = build_initial_day_clusters(
        clustered_places=clustered_places,
        sorted_labels=sorted_labels,
        total_days=total_days,
        start_date=start_date,
        limits=limits,
    )
    initial_day_clusters = deepcopy(day_clusters)
    initial_backup_places = deepcopy(backup_places)

    high_rank_threshold = compute_high_rank_threshold(candidate_places)
    optional_places: list[dict] = []
    repair_logs: list[dict] = []

    max_iterations = 10

    for _ in range(max_iterations):
        changed = False

        changed = (
            try_fill_underfilled_days(
                day_clusters=day_clusters,
                backup_places=backup_places,
                limits=limits,
                repair_logs=repair_logs,
            )
            or changed
        )
        changed = (
            try_fix_overfilled_or_overloaded_days(
                day_clusters=day_clusters,
                backup_places=backup_places,
                optional_places=optional_places,
                limits=limits,
                high_rank_threshold=high_rank_threshold,
                repair_logs=repair_logs,
            )
            or changed
        )

        if not changed:
            break

    add_day_warnings(day_clusters, limits)

    for day_cluster in day_clusters:
        day_cluster["places"].sort(
            key=lambda place: float(place.get("module1_score") or 0.0),
            reverse=True,
        )
        day_cluster["total_duration_minutes"] = day_total_duration(day_cluster)
        day_cluster["place_count"] = len(day_cluster["places"])

    backup_places = deduplicate_places(sorted(
        backup_places,
        key=lambda place: float(place.get("module1_score") or 0.0),
        reverse=True,
    ))
    optional_places = deduplicate_places(sorted(
        optional_places,
        key=lambda place: float(place.get("module1_score") or 0.0),
        reverse=True,
    ))

    return {
        "day_clusters": day_clusters,
        "initial_day_clusters": initial_day_clusters,
        "backup_places": backup_places,
        "initial_backup_places": initial_backup_places,
        "optional_places": optional_places,
        "rejected_places": rejected_places,
        "repair_logs": repair_logs,
        "limits": {
            **limits,
            "high_rank_threshold": round(high_rank_threshold, 6),
        },
        "summary": {
            "total_days": total_days,
            "candidate_count": len(candidate_places),
            "selected_main_place_count": sum(len(day["places"]) for day in day_clusters),
            "backup_place_count": len(backup_places),
            "optional_place_count": len(optional_places),
            "rejected_place_count": len(rejected_places),
            "repair_action_count": len(repair_logs),
        },
    }
