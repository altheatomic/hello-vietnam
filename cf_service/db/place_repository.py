"""
db/place_repository.py
Fetch places from Supabase with required filters only.

Required filters (applied at DB level):
  - id_province matches
  - status = active
  - is_itinerary_eligible = true (via inner join)
  - latitude / longitude not null

Optional filters (rating, budget) are applied in services/filters.py.
"""

from typing import Any

from services.module3_optimizer import haversine_km
from services.ttl_cache import TtlCache


_PROVINCE_PLACES_CACHE = TtlCache[tuple[str, int], list[dict]](
    ttl_seconds=120,
    max_entries=128,
)

# Display names for subcategories shown to English-language users.
_SUBCATEGORY_EN: dict[str, str] = {
    "Y tế / Bệnh viện":          "Hospital / Clinic",
    "Nhà thuốc":                  "Pharmacy",
    "Ngân hàng / ATM":            "Bank / ATM",
    "Trạm xăng":                  "Gas Station",
    "Cơ quan hành chính":         "Government Office",
    "Công an / Cảnh sát":         "Police Station",
    "Trường học / Đại học":       "School / University",
    "Bến xe / Sân bay / Ga tàu": "Transport Hub",
}


def remove_freshness_ineligible_places(
    supabase: Any,
    places: list[dict],
) -> list[dict]:
    """Remove only freshness states that are unsafe for itinerary planning.

    A missing freshness row is retained for migration compatibility, and stale
    content remains usable with the warning rendered by the client. Metadata
    failures fail open so a rollout cannot blank the planner unexpectedly.
    """

    if not places:
        return places
    content_ids = [
        str(place.get("id_place"))
        for place in places
        if place.get("id_place") is not None
    ]
    if not content_ids:
        return places
    try:
        response = (
            supabase
            .table("content_freshness")
            .select("content_id,freshness_status")
            .eq("content_type", "place")
            .in_("content_id", content_ids)
            .execute()
        )
        blocked = {
            str(row.get("content_id"))
            for row in (response.data or [])
            if str(row.get("freshness_status", "")).lower()
            in {"needs_review", "expired"}
        }
        return [
            place
            for place in places
            if str(place.get("id_place")) not in blocked
        ]
    except Exception:
        return places


def fetch_nearby_amenities(
    supabase: Any,
    lat: float,
    lng: float,
    subcategory_names: list[str],
    limit_per_category: int = 3,
    radius_km: float = 15.0,
) -> list[dict]:
    response = (
        supabase
        .table("place_localized_en")
        .select(
            "id_place,name,latitude,longitude,"
            "place_subcategory!inner(name)"
        )
        .in_("place_subcategory.name", subcategory_names)
        .eq("status", "active")
        .filter("latitude", "not.is", "null")
        .filter("longitude", "not.is", "null")
        .limit(500)
        .execute()
    )
    rows = response.data or []

    # Compute distance, filter by radius, then group by subcategory.
    # limit_per_category is applied AFTER the radius filter.
    by_cat: dict[str, list] = {}
    for r in rows:
        dist = haversine_km(lat, lng, float(r["latitude"]), float(r["longitude"]))
        if dist > radius_km:
            continue
        sub_vi = (r.get("place_subcategory") or {}).get("name", "")
        sub_en = _SUBCATEGORY_EN.get(sub_vi, sub_vi)
        entry = {
            "id_place": str(r["id_place"]),
            "name": r["name"],
            "subcategory_name": sub_en,
            "latitude": r["latitude"],
            "longitude": r["longitude"],
            "distance_km": round(dist, 3),
            "estimated_minutes": round(dist / 30.0 * 60),
        }
        by_cat.setdefault(sub_vi, []).append(entry)

    result = []
    for sub in subcategory_names:
        places = sorted(by_cat.get(sub, []), key=lambda x: x["distance_km"])
        result.extend(places[:limit_per_category])
    return sorted(result, key=lambda x: x["distance_km"])


def fetch_places_near_point(
    supabase: Any,
    target_lat: float,
    target_lng: float,
    radius_km: float = 5.0,
    limit: int = 500,
) -> list[dict]:
    """Fetch itinerary-eligible places within radius_km of a lat/lng point.

    Uses a bounding-box pre-filter at DB level, then Haversine for exact distance.
    Auto-expands radius (5→10→15 km) if fewer than 24 candidates are found.
    """
    from math import cos, radians

    lat_delta = radius_km / 111.0
    lng_delta = radius_km / (111.0 * cos(radians(target_lat)))

    select_fields = (
        "id_place,id_place_subcategory,name,short_description,"
        "status,cover_image,gallery,address,phone,website,id_province,latitude,longitude,"
        "average_rating,review_count,minimum_price,maximum_price,"
        "estimated_duration_minutes,timespan,timeclose,"
        "place_subcategory!inner(name,place_category,is_itinerary_eligible)"
    )

    resp = (
        supabase
        .table("place_localized_en")
        .select(select_fields)
        .gte("latitude",  target_lat - lat_delta)
        .lte("latitude",  target_lat + lat_delta)
        .gte("longitude", target_lng - lng_delta)
        .lte("longitude", target_lng + lng_delta)
        .eq("status", "active")
        .eq("place_subcategory.is_itinerary_eligible", True)
        .filter("latitude",  "not.is", "null")
        .filter("longitude", "not.is", "null")
        .limit(limit)
        .execute()
    )
    candidates = resp.data or []
    candidates = remove_freshness_ineligible_places(supabase, candidates)

    within = [
        p for p in candidates
        if haversine_km(
            target_lat, target_lng,
            float(p["latitude"]), float(p["longitude"]),
        ) <= radius_km
    ]

    # Auto-expand if not enough candidates and radius is still small.
    if len(within) < 24 and radius_km < 15.0:
        return fetch_places_near_point(
            supabase, target_lat, target_lng,
            radius_km=min(radius_km * 2, 15.0),
            limit=limit,
        )

    return within[:limit]


def fetch_places_required_filter(
    supabase: Any,
    province_id: str,
    limit: int = 500,
) -> list[dict]:
    cache_key = (str(province_id), limit)
    cached = _PROVINCE_PLACES_CACHE.get(cache_key)
    if cached is not None:
        return cached

    select_fields = (
        "id_place,id_place_subcategory,name,short_description,"
        "status,cover_image,gallery,address,phone,website,id_province,latitude,longitude,"
        "average_rating,review_count,minimum_price,maximum_price,"
        "estimated_duration_minutes,timespan,timeclose,"
        "place_subcategory!inner(name,place_category,is_itinerary_eligible)"
    )

    response = (
        supabase
        .table("place_localized_en")
        .select(select_fields)
        .eq("id_province", province_id)
        .eq("status", "active")
        .eq("place_subcategory.is_itinerary_eligible", True)
        .filter("latitude", "not.is", "null")
        .filter("longitude", "not.is", "null")
        .limit(limit)
        .execute()
    )

    rows = remove_freshness_ineligible_places(supabase, response.data or [])
    _PROVINCE_PLACES_CACHE.set(cache_key, rows)
    return rows
