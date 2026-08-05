"""
routes/recommend.py
Personalized province recommendation endpoints.
"""

import asyncio

from fastapi import APIRouter, Depends

from db.supabase_client import get_supabase
from services.ttl_cache import TtlCache

router = APIRouter()
_PLACE_DETAIL_CACHE = TtlCache[str, dict](ttl_seconds=120, max_entries=512)


def _gallery_urls(gallery_raw):
    urls = []
    for item in (gallery_raw or []):
        if isinstance(item, dict):
            url = (
                item.get("url") or item.get("image_url") or item.get("path")
                or item.get("key") or item.get("src") or ""
            )
            if url:
                urls.append(url)
        elif isinstance(item, str) and item:
            urls.append(item)
    return urls


def _place_response(place: dict) -> dict:
    sub = place.get("place_subcategory") or {}
    gallery_urls = _gallery_urls(place.get("gallery"))
    return {
        "id_place": str(place["id_place"]),
        "name": place.get("name"),
        "short_description": place.get("short_description"),
        "address": place.get("address"),
        "estimated_duration_minutes": place.get("estimated_duration_minutes"),
        "minimum_price": place.get("minimum_price"),
        "maximum_price": place.get("maximum_price"),
        "phone": place.get("phone"),
        "website": place.get("website"),
        "timespan": place.get("timespan"),
        "timeclose": place.get("timeclose"),
        "cover_image": place.get("cover_image"),
        "gallery_url": gallery_urls[0] if gallery_urls else None,
        "gallery": gallery_urls,
        "average_rating": place.get("average_rating"),
        "review_count": place.get("review_count"),
        "subcategory_name": sub.get("name", "") if isinstance(sub, dict) else "",
        "tag_match": round(float(place.get("tag_match") or 0), 4),
        "cf_score": round(float(place.get("cf_score") or 0), 4),
        "final_score": round(float(place.get("final_score") or 0), 4),
    }


@router.get("/api/recommend/provinces")
async def get_recommended_provinces(
    # id_user is required because the recommend edge function always sends
    # it (see backend/supabase/functions/recommend/recommend_handler.ts) —
    # kept on the route so that call keeps working, even though the
    # province listing itself no longer computes anything per-user.
    id_user: str,
    limit: int = 100,
    supabase=Depends(get_supabase),
):
    from services.recommend_service import recommend_provinces
    results = await asyncio.to_thread(recommend_provinces, supabase, limit)
    return {"provinces": results}


@router.get("/api/recommend/province/{id_province}")
async def get_province_detail(
    id_province: str,
    id_user: str,
    limit: int = 20,
    supabase=Depends(get_supabase),
):
    return await asyncio.to_thread(
        _get_province_detail_sync, supabase, id_province, id_user, limit
    )


def _get_province_detail_sync(
    supabase,
    id_province: str,
    id_user: str,
    limit: int,
):
    from db.place_repository import fetch_places_required_filter
    from services.module1_algorithm import (
        build_user_interest_state_from_rows,
        compute_alpha,
        rank_places_by_tag_match,
    )
    from services.module1_repository import (
        attach_place_tags_to_places,
        build_tag_map,
        compute_cf_scores_from_factors,
        fetch_active_tags,
        fetch_place_factors,
        fetch_place_tags_for_places,
        fetch_user_factors,
        fetch_user_interest_tags,
    )

    # Province name
    prov_rows = (
        supabase.table("old_province")
        .select("name")
        .eq("id_province", id_province)
        .limit(1)
        .execute()
        .data or []
    )
    prov_name = prov_rows[0].get("name", "") if prov_rows else ""

    places = fetch_places_required_filter(supabase, id_province)
    if not places:
        return {
            "id_province": id_province,
            "name":        prov_name,
            "avg_rating":  0.0,
            "place_count": 0,
            "top_places":  [],
        }

    # Rank by user interest (M1)
    tags     = fetch_active_tags(supabase)
    tag_map  = build_tag_map(tags)
    id_tag_map = {
        str(t["id_tag"]): t["tag_code"]
        for t in tags
        if t.get("id_tag") and t.get("tag_code")
    }
    interest_rows      = fetch_user_interest_tags(supabase, id_user)
    user_interest_state = build_user_interest_state_from_rows(
        interest_rows, tag_map, id_tag_map
    )
    place_ids      = [str(p["id_place"]) for p in places]
    place_tag_rows = fetch_place_tags_for_places(supabase, place_ids)
    enriched       = attach_place_tags_to_places(places, place_tag_rows)
    ranked         = rank_places_by_tag_match(
        enriched, user_interest_state,
        weight_field="final_weight",
        id_tag_map=id_tag_map,
    )

    # ── CF blend (same pattern as trip_planner.py) ────────────────────────────
    # Reads cf_user_factors/cf_place_factors (dot-product at request time),
    # not cf_score_cache. {} on a user with no trained factors yet — same
    # fallback shape as the old cache-miss case, so compute_alpha()/.get(id,
    # 0.0) below behave unchanged.
    user_factors = fetch_user_factors(supabase, id_user)
    if user_factors is None:
        cf_scores = {}
    else:
        place_factors = fetch_place_factors(supabase, place_ids)
        cf_scores = compute_cf_scores_from_factors(user_factors, place_factors)
    alpha = compute_alpha(cf_scores, len(places))
    for place in ranked:
        tag_match = float(place.get("tag_match") or 0.0)
        cf = cf_scores.get(str(place["id_place"]), 0.0)
        place["cf_score"] = round(cf, 6)
        place["final_score"] = round(alpha * tag_match + (1 - alpha) * cf, 6)
    ranked.sort(key=lambda p: -p["final_score"])

    avg_rating = round(
        sum((p.get("average_rating") or 0.0) for p in places) / len(places), 1
    )

    top_places = []
    for p in ranked[:limit]:
        top_places.append(_place_response(p))

    return {
        "id_province": id_province,
        "name":        prov_name,
        "avg_rating":  avg_rating,
        "place_count": len(places),
        "top_places":  top_places,
    }


@router.get("/api/recommend/place/{id_place}")
async def get_recommended_place(id_place: str, supabase=Depends(get_supabase)):
    """Load one English-localized place directly, independent of top-20 rank."""
    return await asyncio.to_thread(_get_recommended_place_sync, supabase, id_place)


def _get_recommended_place_sync(supabase, id_place: str):
    cached = _PLACE_DETAIL_CACHE.get(id_place)
    if cached is not None:
        return cached
    rows = (
        supabase.table("place_localized_en")
        .select(
            "id_place,name,short_description,address,phone,website,"
            "cover_image,gallery,average_rating,review_count,"
            "estimated_duration_minutes,minimum_price,maximum_price,"
            "timespan,timeclose,place_subcategory(name)"
        )
        .eq("id_place", id_place)
        .limit(1)
        .execute()
        .data or []
    )
    if not rows:
        return {"place": None}
    result = {"place": _place_response(rows[0])}
    _PLACE_DETAIL_CACHE.set(id_place, result)
    return result
