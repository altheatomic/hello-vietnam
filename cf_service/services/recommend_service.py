"""
services/recommend_service.py
Province listing for the Recommend feature.

Pipeline (no ML scoring — see routes/recommend.py::get_province_detail for
the CB+CF ranked flow used once the user taps into a specific province):
  1. Fetch all provinces from old_province (name, description_en,
     average_rating, review_count, cover_image — all real columns, nothing
     computed)
  2. Sort provinces by name with Vietnamese diacritics stripped (A-Z as
     shown on screen, not raw Vietnamese Unicode order)

place_count is currently always 0 — it used to be derived from a
place_localized_en query (best-rated place per province, for cover image +
place_count), which has been removed now that cover_image comes straight
from old_province. Re-add a place_count source separately if needed.
"""

from __future__ import annotations

import time  # TEMP — perf audit, remove after done

from services.ttl_cache import TtlCache


_PROVINCES_CACHE = TtlCache[int, list[dict]](ttl_seconds=600, max_entries=8)

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


def recommend_provinces(supabase, limit: int = 100) -> list[dict]:
    cached = _PROVINCES_CACHE.get(limit)
    if cached is not None:
        return cached

    # TEMP — perf audit, remove after done
    _t0 = time.perf_counter()

    # ── Step 1: All provinces — real columns, nothing computed ────────────────
    prov_resp = (
        supabase
        .table("old_province")
        .select(
            "id_province,name,description_en,average_rating,review_count,"
            "cover_image"
        )
        .execute()
    )
    province_map: dict[str, dict] = {
        str(p["id_province"]): p
        for p in (prov_resp.data or [])
    }
    if not province_map:
        return []

    # ── Step 2: Assemble + sort A-Z by diacritics-stripped name ────────────────
    results: list[dict] = []
    for prov_id, province in province_map.items():
        cover_image = province.get("cover_image")

        results.append({
            "id_province":  prov_id,
            "name":         province.get("name"),
            "description":  province.get("description_en"),
            "place_count":  0,
            "cover_image":  cover_image,
            "gallery":      [cover_image] if cover_image else [],
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
        f"provinces={len(results)}"
    )

    _PROVINCES_CACHE.set(limit, results)
    return results
