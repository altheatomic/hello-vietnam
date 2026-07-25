"""
services/recommend_service.py
Province listing for the Recommend feature.

Pipeline (no ML scoring — see routes/recommend.py::get_province_detail for
the CB+CF ranked flow used once the user taps into a specific province):
  1. Fetch all provinces from old_province (name, description_en,
     average_rating, review_count — all real columns, nothing computed)
  2. Fetch eligible places (for cover image + place_count only), sorted by
     rating so the first place seen per province is its best-rated one
  3. Sort provinces by name with Vietnamese diacritics stripped (A-Z as
     shown on screen, not raw Vietnamese Unicode order)
"""

from __future__ import annotations

import time  # TEMP — perf audit, remove after done

from db.supabase_client import fetch_all_rows

# Mirrors frontend/lib/core/utils/vietnamese_text_utils.dart
# (_vietnameseDiacriticReplacements) character-for-character, so provinces
# sort in the same order they're displayed in (diacritics stripped).
_VIETNAMESE_DIACRITIC_REPLACEMENTS: dict[str, str] = {
    "à": "a", "á": "a", "ạ": "a", "ả": "a", "ã": "a",
    "â": "a", "ầ": "a", "ấ": "a", "ậ": "a", "ẩ": "a", "ẫ": "a",
    "ă": "a", "ằ": "a", "ắ": "a", "ặ": "a", "ẳ": "a", "ẵ": "a",
    "è": "e", "é": "e", "ẹ": "e", "ẻ": "e", "ẽ": "e",
    "ê": "e", "ề": "e", "ế": "e", "ệ": "e", "ể": "e", "ễ": "e",
    "ì": "i", "í": "i", "ị": "i", "ỉ": "i", "ĩ": "i",
    "ò": "o", "ó": "o", "ọ": "o", "ỏ": "o", "õ": "o",
    "ô": "o", "ồ": "o", "ố": "o", "ộ": "o", "ổ": "o", "ỗ": "o",
    "ơ": "o", "ờ": "o", "ớ": "o", "ợ": "o", "ở": "o", "ỡ": "o",
    "ù": "u", "ú": "u", "ụ": "u", "ủ": "u", "ũ": "u",
    "ư": "u", "ừ": "u", "ứ": "u", "ự": "u", "ử": "u", "ữ": "u",
    "ỳ": "y", "ý": "y", "ỵ": "y", "ỷ": "y", "ỹ": "y",
    "đ": "d",
    "À": "A", "Á": "A", "Ạ": "A", "Ả": "A", "Ã": "A",
    "Â": "A", "Ầ": "A", "Ấ": "A", "Ậ": "A", "Ẩ": "A", "Ẫ": "A",
    "Ă": "A", "Ằ": "A", "Ắ": "A", "Ặ": "A", "Ẳ": "A", "Ẵ": "A",
    "È": "E", "É": "E", "Ẹ": "E", "Ẻ": "E", "Ẽ": "E",
    "Ê": "E", "Ề": "E", "Ế": "E", "Ệ": "E", "Ể": "E", "Ễ": "E",
    "Ì": "I", "Í": "I", "Ị": "I", "Ỉ": "I", "Ĩ": "I",
    "Ò": "O", "Ó": "O", "Ọ": "O", "Ỏ": "O", "Õ": "O",
    "Ô": "O", "Ồ": "O", "Ố": "O", "Ộ": "O", "Ổ": "O", "Ỗ": "O",
    "Ơ": "O", "Ờ": "O", "Ớ": "O", "Ợ": "O", "Ở": "O", "Ỡ": "O",
    "Ù": "U", "Ú": "U", "Ụ": "U", "Ủ": "U", "Ũ": "U",
    "Ư": "U", "Ừ": "U", "Ứ": "U", "Ự": "U", "Ử": "U", "Ữ": "U",
    "Ỳ": "Y", "Ý": "Y", "Ỵ": "Y", "Ỷ": "Y", "Ỹ": "Y",
    "Đ": "D",
}


def remove_vietnamese_diacritics(text: str) -> str:
    """Removes precomposed Vietnamese diacritics, matching the frontend's
    removeVietnameseDiacritics() character-for-character (no Unicode
    normalization — 'Đ' is not decomposable via NFD, so it needs the
    explicit map above)."""
    return "".join(_VIETNAMESE_DIACRITIC_REPLACEMENTS.get(ch, ch) for ch in text)


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


def recommend_provinces(supabase, limit: int = 20) -> list[dict]:
    # TEMP — perf audit, remove after done
    _t0 = time.perf_counter()

    # ── Step 1: All provinces — real columns, nothing computed ────────────────
    prov_resp = (
        supabase
        .table("old_province")
        .select("id_province,name,description_en,average_rating,review_count")
        .execute()
    )
    province_map: dict[str, dict] = {
        str(p["id_province"]): p
        for p in (prov_resp.data or [])
    }
    if not province_map:
        return []

    # ── Step 2: Eligible places, sorted best-first, for cover image + count ───
    def _build_places_query(start: int, end: int):
        return (
            supabase
            .table("place_localized_en")
            .select(
                "id_place,old_province,cover_image,gallery,"
                "average_rating,review_count,"
                "place_subcategory!inner(is_itinerary_eligible)"
            )
            .eq("status", "active")
            .eq("place_subcategory.is_itinerary_eligible", True)
            .filter("latitude", "not.is", "null")
            .filter("longitude", "not.is", "null")
            .order("average_rating", desc=True)
            .order("review_count", desc=True)
            .range(start, end)
        )

    all_places = fetch_all_rows(_build_places_query)

    # Places are fetched best-rated-first, so the first place seen per
    # province is already its highest-rated (tie-broken by review_count).
    place_count: dict[str, int] = {}
    cover_by_province: dict[str, dict] = {}
    for p in all_places:
        prov_id = str(p.get("old_province") or "")
        if not prov_id or prov_id not in province_map:
            continue
        place_count[prov_id] = place_count.get(prov_id, 0) + 1
        if prov_id not in cover_by_province:
            cover_by_province[prov_id] = p

    # ── Step 3: Assemble + sort A-Z by diacritics-stripped name ────────────────
    results: list[dict] = []
    for prov_id, province in province_map.items():
        top_place = cover_by_province.get(prov_id, {})
        gallery_urls = _extract_gallery_urls(top_place.get("gallery") or [])

        results.append({
            "id_province":  prov_id,
            "name":         province.get("name"),
            "description":  province.get("description_en"),
            "place_count":  place_count.get(prov_id, 0),
            "cover_image":  top_place.get("cover_image"),
            "gallery":      gallery_urls,
            "avg_rating":   province.get("average_rating") or 0.0,
            "review_count": province.get("review_count") or 0,
        })

    results.sort(
        key=lambda r: remove_vietnamese_diacritics(r["name"] or "").lower()
    )

    # TEMP — perf audit, remove after done
    elapsed_ms = round((time.perf_counter() - _t0) * 1000, 1)
    print(
        f"[TIMING] recommend_provinces: elapsed={elapsed_ms}ms "
        f"total_places={len(all_places)} provinces={len(results)}"
    )

    return results[:limit]
