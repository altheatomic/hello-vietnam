"""
routes/recommend.py
Personalized province recommendation endpoints.
"""

from fastapi import APIRouter, Depends

from db.supabase_client import get_supabase

router = APIRouter()


@router.get("/api/recommend/provinces")
async def get_recommended_provinces(
    # id_user is required because the recommend edge function always sends
    # it (see backend/supabase/functions/recommend/recommend_handler.ts) —
    # kept on the route so that call keeps working, even though the
    # province listing itself no longer computes anything per-user.
    id_user: str,
    limit: int = 20,
    supabase=Depends(get_supabase),
):
    from services.recommend_service import recommend_provinces
    results = recommend_provinces(supabase, limit=limit)
    return {"provinces": results}


@router.get("/api/recommend/province/{id_province}")
async def get_province_detail(
    id_province: str,
    id_user: str,
    limit: int = 20,
    supabase=Depends(get_supabase),
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
        fetch_active_tags,
        fetch_cf_scores_for_user,
        fetch_place_tags_for_places,
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
    cf_scores = fetch_cf_scores_for_user(supabase, id_user, place_ids)
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

    def _first_url(gallery_raw):
        for item in (gallery_raw or []):
            if isinstance(item, dict):
                url = item.get("url") or item.get("image_url") or ""
                if url:
                    return url
            elif isinstance(item, str) and item:
                return item
        return None

    top_places = []
    for p in ranked[:limit]:
        sub      = p.get("place_subcategory") or {}
        sub_name = sub.get("name", "") if isinstance(sub, dict) else ""
        top_places.append({
            "id_place":       str(p["id_place"]),
            "name":           p.get("name"),
            "address":        p.get("address"),
            "cover_image":    p.get("cover_image"),
            "gallery_url":    _first_url(p.get("gallery")),
            "average_rating": p.get("average_rating"),
            "review_count":   p.get("review_count"),
            "subcategory_name": sub_name,
            "tag_match":      round(float(p.get("tag_match") or 0), 4),
            "cf_score":       round(float(p.get("cf_score") or 0), 4),
            "final_score":    round(float(p.get("final_score") or 0), 4),
        })

    return {
        "id_province": id_province,
        "name":        prov_name,
        "avg_rating":  avg_rating,
        "place_count": len(places),
        "top_places":  top_places,
    }
