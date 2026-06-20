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


def fetch_nearby_amenities(
    supabase: Any,
    lat: float,
    lng: float,
    subcategory_names: list[str],
    limit_per_category: int = 3,
) -> list[dict]:
    response = (
        supabase
        .table("place")
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

    # Compute distance and group by subcategory
    by_cat: dict[str, list] = {}
    for r in rows:
        sub = (r.get("place_subcategory") or {}).get("name", "")
        dist = haversine_km(lat, lng, r["latitude"], r["longitude"])
        entry = {
            "id_place": str(r["id_place"]),
            "name": r["name"],
            "subcategory_name": sub,
            "latitude": r["latitude"],
            "longitude": r["longitude"],
            "distance_km": round(dist, 3),
            "estimated_minutes": round(dist / 30.0 * 60),
        }
        by_cat.setdefault(sub, []).append(entry)

    result = []
    for sub in subcategory_names:
        places = sorted(by_cat.get(sub, []), key=lambda x: x["distance_km"])
        result.extend(places[:limit_per_category])
    return sorted(result, key=lambda x: x["distance_km"])


def fetch_places_required_filter(
    supabase: Any,
    province_id: str,
    limit: int = 500,
) -> list[dict]:
    select_fields = (
        "id_place,id_place_subcategory,name,short_description,"
        "detailed_description,status,cover_image,address,latitude,longitude,"
        "average_rating,review_count,minimum_price,maximum_price,"
        "estimated_duration_minutes,id_province,id_region,id_zone,"
        "place_subcategory!inner(name,place_category,is_itinerary_eligible)"
    )

    response = (
        supabase
        .table("place")
        .select(select_fields)
        .eq("old_province", province_id)
        .eq("status", "active")
        .eq("place_subcategory.is_itinerary_eligible", True)
        .filter("latitude", "not.is", "null")
        .filter("longitude", "not.is", "null")
        .limit(limit)
        .execute()
    )

    return response.data or []
