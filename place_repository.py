"""
Repository layer for fetching places directly from Supabase.

This file only handles REQUIRED FILTERS at database query level:
1. Same province
2. status = active
3. latitude is not null
4. longitude is not null
"""

from typing import Any


def fetch_places_required_filter(
    supabase: Any,
    province_id: str,
    limit: int = 500,
) -> list[dict]:
    """
    Fetch places by required filters.

    Required filters:
    - id_province = province_id
    - status = active
    - latitude is not null
    - longitude is not null
    """

    response = (
        supabase
        .table("place")
        .select(
            """
            id_place,
            id_place_subcategory,
            name,
            short_description,
            detailed_description,
            status,
            cover_image,
            address,
            latitude,
            longitude,
            average_rating,
            review_count,
            minimum_price,
            maximum_price,
            estimated_duration_minutes,
            id_province,
            id_region,
            id_zone,
            place_subcategory!inner (
                id_place_subcategory,
                name,
                place_category,
                is_itinerary_eligible
            )
            """
        )
        .eq("id_province", province_id)
        .eq("status", "active")
        .eq("place_subcategory.is_itinerary_eligible", True)
        .filter("latitude", "not.is", "null")
        .filter("longitude", "not.is", "null")
        .limit(limit)
        .execute()
    )

    return response.data or []
