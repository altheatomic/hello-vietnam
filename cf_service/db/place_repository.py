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
