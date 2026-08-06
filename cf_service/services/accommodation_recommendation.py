"""Accommodation-zone recommendation for the finalized Module 2 day clusters."""

from __future__ import annotations

import math
from typing import Any


DEFAULT_MIN_ZONE_SEPARATION_KM = 50.0
DEFAULT_MIN_COST_REDUCTION_RATIO = 0.35
DEFAULT_LONG_TRIP_MIN_DAYS = 5
DEFAULT_MIN_DAYS_PER_ZONE = 2
MEAN_DISTANCE_WEIGHT = 0.6
WORST_DAY_DISTANCE_WEIGHT = 0.4


def _valid_centroid(value: Any) -> bool:
    if not isinstance(value, (tuple, list)) or len(value) != 2:
        return False
    try:
        latitude, longitude = float(value[0]), float(value[1])
    except (TypeError, ValueError):
        return False
    return -90 <= latitude <= 90 and -180 <= longitude <= 180


def _haversine_km(first: tuple[float, float], second: tuple[float, float]) -> float:
    radius_km = 6371.0
    first_lat, second_lat = math.radians(first[0]), math.radians(second[0])
    delta_lat = math.radians(second[0] - first[0])
    delta_lng = math.radians(second[1] - first[1])
    a = (
        math.sin(delta_lat / 2) ** 2
        + math.cos(first_lat)
        * math.cos(second_lat)
        * math.sin(delta_lng / 2) ** 2
    )
    return radius_km * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _centroid(day: dict) -> tuple[float, float]:
    value = day["centroid"]
    return float(value[0]), float(value[1])


def _medoid(days: list[dict]) -> tuple[float, float]:
    candidates = [_centroid(day) for day in days]
    return min(
        candidates,
        key=lambda candidate: sum(
            _haversine_km(candidate, other) for other in candidates
        ),
    )


def _cost(day_distances: list[float]) -> float:
    if not day_distances:
        return 0.0
    return (
        MEAN_DISTANCE_WEIGHT * (sum(day_distances) / len(day_distances))
        + WORST_DAY_DISTANCE_WEIGHT * max(day_distances)
    )


def _zone(days: list[dict]) -> dict:
    center = _medoid(days)
    return {
        "zone_index": 0,
        "day_from": int(days[0]["day"]),
        "day_to": int(days[-1]["day"]),
        "latitude": round(center[0], 6),
        "longitude": round(center[1], 6),
        "google_maps_query": f"hotels near {center[0]:.6f},{center[1]:.6f}",
    }


def _build_single_zone_result(
    day_clusters: list[dict],
    *,
    min_zone_separation_km: float,
    min_cost_reduction_ratio: float,
) -> dict:
    zone = _zone(day_clusters)
    center = (zone["latitude"], zone["longitude"])
    distances = [_haversine_km(center, _centroid(day)) for day in day_clusters]
    single_cost = _cost(distances)
    zone["zone_index"] = 1
    return {
        "version": 1,
        "strategy": "single_zone",
        "zones": [zone],
        "evaluation": {
            "single_zone_cost_km": round(single_cost, 4),
            "selected_cost_km": round(single_cost, 4),
            "reduction_ratio": 0.0,
            "objective_weights": {
                "mean_distance": MEAN_DISTANCE_WEIGHT,
                "worst_day_distance": WORST_DAY_DISTANCE_WEIGHT,
            },
            "min_zone_separation_km": min_zone_separation_km,
            "min_cost_reduction_ratio": min_cost_reduction_ratio,
        },
    }


def _max_zones(total_days: int) -> int:
    if total_days <= 8:
        return 2
    if total_days <= 14:
        return 3
    return 4


def _partitions(
    days: list[dict], zone_count: int, min_days_per_zone: int
) -> list[list[list[dict]]]:
    result: list[list[list[dict]]] = []

    def visit(start: int, segments: list[list[dict]]) -> None:
        remaining_days = len(days) - start
        remaining_zones = zone_count - len(segments)
        if remaining_zones == 1:
            if remaining_days >= min_days_per_zone:
                result.append(segments + [days[start:]])
            return

        max_end = len(days) - min_days_per_zone * (remaining_zones - 1)
        for end in range(start + min_days_per_zone, max_end + 1):
            visit(end, segments + [days[start:end]])

    visit(0, [])
    return result


def _build_multi_zone_result(
    segments: list[list[dict]],
    *,
    single_zone_cost: float,
    min_zone_separation_km: float,
    min_cost_reduction_ratio: float,
) -> dict | None:
    centers = [_medoid(segment) for segment in segments]
    separations = [
        _haversine_km(centers[index], centers[index + 1])
        for index in range(len(centers) - 1)
    ]
    if any(separation < min_zone_separation_km for separation in separations):
        return None

    daily_distances = [
        _haversine_km(center, _centroid(day))
        for center, segment in zip(centers, segments)
        for day in segment
    ]
    selected_cost = _cost(daily_distances)
    reduction_ratio = (
        (single_zone_cost - selected_cost) / single_zone_cost
        if single_zone_cost > 0
        else 0.0
    )
    if reduction_ratio < min_cost_reduction_ratio:
        return None

    zones = []
    for index, segment in enumerate(segments, start=1):
        zone = _zone(segment)
        zone["zone_index"] = index
        zones.append(zone)

    return {
        "version": 1,
        "strategy": "multi_zone",
        "zones": zones,
        "evaluation": {
            "single_zone_cost_km": round(single_zone_cost, 4),
            "selected_cost_km": round(selected_cost, 4),
            "reduction_ratio": round(reduction_ratio, 4),
            "objective_weights": {
                "mean_distance": MEAN_DISTANCE_WEIGHT,
                "worst_day_distance": WORST_DAY_DISTANCE_WEIGHT,
            },
            "min_zone_separation_km": min_zone_separation_km,
            "min_cost_reduction_ratio": min_cost_reduction_ratio,
        },
    }


def build_accommodation_recommendation(
    day_clusters: list[dict],
    *,
    min_zone_separation_km: float = DEFAULT_MIN_ZONE_SEPARATION_KM,
    min_cost_reduction_ratio: float = DEFAULT_MIN_COST_REDUCTION_RATIO,
    long_trip_min_days: int = DEFAULT_LONG_TRIP_MIN_DAYS,
    min_days_per_zone: int = DEFAULT_MIN_DAYS_PER_ZONE,
) -> dict | None:
    """Build a recommendation from finalized Module 2 day clusters."""
    if not day_clusters or any(not _valid_centroid(day.get("centroid")) for day in day_clusters):
        return None

    single_result = _build_single_zone_result(
        day_clusters,
        min_zone_separation_km=min_zone_separation_km,
        min_cost_reduction_ratio=min_cost_reduction_ratio,
    )
    if len(day_clusters) < long_trip_min_days:
        return single_result

    single_cost = single_result["evaluation"]["single_zone_cost_km"]
    best_multi: dict | None = None
    for zone_count in range(2, _max_zones(len(day_clusters)) + 1):
        for segments in _partitions(day_clusters, zone_count, min_days_per_zone):
            candidate = _build_multi_zone_result(
                segments,
                single_zone_cost=single_cost,
                min_zone_separation_km=min_zone_separation_km,
                min_cost_reduction_ratio=min_cost_reduction_ratio,
            )
            if candidate is None:
                continue
            if best_multi is None or candidate["evaluation"]["selected_cost_km"] < best_multi["evaluation"]["selected_cost_km"]:
                best_multi = candidate

    return best_multi or single_result


def build_accommodation_recommendation_from_itinerary_days(
    days: list[dict],
    **kwargs: Any,
) -> dict | None:
    """Rebuild a recommendation from places returned by a saved plan."""
    day_clusters: list[dict] = []
    for day in days:
        coordinates = []
        for place in day.get("places") or []:
            if _valid_centroid((place.get("latitude"), place.get("longitude"))):
                coordinates.append((float(place["latitude"]), float(place["longitude"])))
        centroid = (
            (
                sum(latitude for latitude, _ in coordinates) / len(coordinates),
                sum(longitude for _, longitude in coordinates) / len(coordinates),
            )
            if coordinates
            else None
        )
        day_clusters.append({"day": day.get("day"), "centroid": centroid})

    return build_accommodation_recommendation(day_clusters, **kwargs)
