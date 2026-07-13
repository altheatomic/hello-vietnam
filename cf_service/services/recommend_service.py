"""
services/recommend_service.py
Personalized province ranking for the Recommend feature.

Pipeline (single-pass, batched):
  1. Fetch all provinces from old_province
  2. Fetch ALL eligible places across all provinces in one query
  3. Batch-fetch place tags (chunked, already done in module1_repository)
  4. Build user interest state once (M1 setup)
  5. Per province: attach tags → rank_places_by_tag_match → avg CB score
  6. Batch-fetch CF scores for all place IDs → avg CF per province
  7. Blend CB + CF, sort descending, return top-N
"""

from __future__ import annotations

import math

from services.module1_algorithm import (
    build_user_interest_state_from_rows,
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

def _popularity_score(avg_rating: float, review_count: int) -> float:
    """
    Popularity score based on rating and review volume.
    Formula: rating x log(review_count + 1)
    """
    if not avg_rating or avg_rating <= 0:
        return 0.0
    return avg_rating * math.log(review_count + 1)


def _compute_alpha(cf_scores: dict, total_places: int) -> float:
    if total_places == 0:
        return 1.0
    coverage = len(cf_scores) / total_places
    if coverage == 0:   return 1.0
    if coverage < 0.10: return 0.7
    if coverage < 0.30: return 0.5
    return 0.3


def _extract_gallery_urls(gallery_raw: list) -> list[str]:
    urls: list[str] = []
    for item in gallery_raw:
        if isinstance(item, dict):
            url = item.get("url") or item.get("image_url") or ""
            if url:
                urls.append(url)
        elif isinstance(item, str) and item:
            urls.append(item)
    return urls


def recommend_provinces(supabase, id_user: str, limit: int = 20) -> list[dict]:
    # ── Step 1: All provinces ─────────────────────────────────────────────────
    prov_resp = supabase.table("old_province").select("id_province, name").execute()
    province_map: dict[str, str] = {
        str(p["id_province"]): p["name"]
        for p in (prov_resp.data or [])
    }
    if not province_map:
        return []

    # ── Step 2: All eligible places (single query) ────────────────────────────
    resp = (
        supabase
        .table("place_localized_en")
        .select(
            "id_place,old_province,name,cover_image,gallery,"
            "average_rating,review_count,"
            "place_subcategory!inner(name,place_category,is_itinerary_eligible)"
        )
        .eq("status", "active")
        .eq("place_subcategory.is_itinerary_eligible", True)
        .filter("latitude", "not.is", "null")
        .filter("longitude", "not.is", "null")
        .execute()
    )
    all_places = resp.data or []
    if not all_places:
        return []

    # Group by province
    by_province: dict[str, list[dict]] = {}
    for p in all_places:
        prov_id = str(p.get("old_province") or "")
        if prov_id and prov_id in province_map:
            by_province.setdefault(prov_id, []).append(p)

    # ── Step 3: User interest state (once) ───────────────────────────────────
    tags = fetch_active_tags(supabase)
    tag_map = build_tag_map(tags)
    id_tag_map = {
        str(t["id_tag"]): t["tag_code"]
        for t in tags
        if t.get("id_tag") and t.get("tag_code")
    }
    interest_rows = fetch_user_interest_tags(supabase, id_user)
    user_interest_state = build_user_interest_state_from_rows(
        interest_rows, tag_map, id_tag_map
    )
    is_cold_start = len(user_interest_state) == 0

    # Cold-start users have no CB/CF signal yet, so rank provinces by trending
    # place popularity instead of producing arbitrary zero-score ordering.
    if is_cold_start:
        results: list[dict] = []
        for prov_id, places in by_province.items():
            pop_scores = [
                _popularity_score(
                    float(p.get("average_rating") or 0.0),
                    int(p.get("review_count") or 0),
                )
                for p in places
            ]
            avg_pop = sum(pop_scores) / len(pop_scores)
            province_pop = avg_pop * math.log(len(places) + 1)

            top_place = max(
                places,
                key=lambda p: _popularity_score(
                    float(p.get("average_rating") or 0.0),
                    int(p.get("review_count") or 0),
                ),
            )
            gallery_urls = _extract_gallery_urls(top_place.get("gallery") or [])
            avg_rating = round(
                sum((p.get("average_rating") or 0.0) for p in places) / len(places), 1
            )

            results.append({
                "id_province":  prov_id,
                "name":         province_map[prov_id],
                "place_count":  len(places),
                "cover_image":  top_place.get("cover_image"),
                "gallery":      gallery_urls,
                "avg_rating":   avg_rating,
                "cb_score":     0.0,
                "cf_score":     0.0,
                "final_score":  province_pop,
                "fallback":     "trending",
            })

        max_score = max((r["final_score"] for r in results), default=0.0) or 1.0
        for r in results:
            r["final_score"] = round(r["final_score"] / max_score, 4)

        results.sort(key=lambda x: x["final_score"], reverse=True)
        return results[:limit]

    # ── Step 4: Batch-fetch place tags & CF scores for all places ─────────────
    all_place_ids = [str(p["id_place"]) for p in all_places]
    place_tag_rows = fetch_place_tags_for_places(supabase, all_place_ids)
    cf_scores_all = fetch_cf_scores_for_user(supabase, id_user, all_place_ids)

    # ── Step 5: Score each province ───────────────────────────────────────────
    results: list[dict] = []
    for prov_id, places in by_province.items():
        place_ids_set = {str(p["id_place"]) for p in places}

        enriched = attach_place_tags_to_places(places, place_tag_rows)
        ranked = rank_places_by_tag_match(
            enriched, user_interest_state,
            weight_field="final_weight",
            id_tag_map=id_tag_map,
        )

        avg_cb = sum(p.get("tag_match") or 0.0 for p in ranked) / len(ranked)

        cf_subset = {k: v for k, v in cf_scores_all.items() if k in place_ids_set}
        avg_cf = sum(cf_subset.values()) / len(cf_subset) if cf_subset else 0.0

        alpha = _compute_alpha(cf_subset, len(places))
        final_score = alpha * avg_cb + (1 - alpha) * avg_cf

        top = ranked[0] if ranked else {}
        cover = top.get("cover_image")
        gallery_urls = _extract_gallery_urls(top.get("gallery") or [])

        avg_rating = round(
            sum((p.get("average_rating") or 0.0) for p in places) / len(places), 1
        )

        results.append({
            "id_province":  prov_id,
            "name":         province_map[prov_id],
            "place_count":  len(places),
            "cover_image":  cover,
            "gallery":      gallery_urls,
            "avg_rating":   avg_rating,
            "cb_score":     round(avg_cb, 4),
            "cf_score":     round(avg_cf, 4),
            "final_score":  round(final_score, 4),
        })

    results.sort(key=lambda x: x["final_score"], reverse=True)
    return results[:limit]
