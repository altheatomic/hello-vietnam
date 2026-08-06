"""
test_module1_eval.py
Module 1 (Content-Based ranking) Precision@K / Recall@K / F1@K evaluation —
capstone report section 4.4, "Huong 1" design confirmed in the prior audit.

Ground truth: a place is "relevant" for category X if it has >=1 place_tag
row whose tag belongs to X's tag set (from trip_interest_option_tag,
is_active=true) with confidence_score >= 0.7.

Categories: culture_history, nature_outdoor, adventure.
`entertainment` is deliberately EXCLUDED — confirmed in the prior audit that
trip_interest_option_tag has ZERO active tag rows for it (a real config
gap, not a sample-size issue), so no ground truth can be derived for it at
all. Report it as N/A, not as a P/R score.

Ground truth re-confirmed AFTER the PostgREST pagination fix: each of the
5 chosen provinces has far fewer eligible places (max 463, Ho Chi Minh)
than the 500-row default of fetch_places_required_filter(), and this
script additionally fetches with fetch_all_rows() (page_size=1000) instead
of relying on that default, so truncation is not possible regardless of
how large any single province's place count grows in the future. The
fetched count is printed per province for a visual sanity check against
the previously-audited true totals (Ho Chi Minh 463, An Giang 275, Quang
Ninh 165, Vinh Long 192, Lam Dong 316).

IMPORTANT — why this does NOT call get_province_detail() verbatim:
get_province_detail() has no interest override parameter; its tag_match
ranking is driven entirely by the user's stored user_interest_tag rows.
control.blank has ZERO such rows by design (the whole point of a "no
history" control user) — calling get_province_detail() as-is would
therefore produce the SAME tag_match=0 ranking (tie-broken by rating) for
every category, making P@K/R@K meaningless (it would compare one
category-blind ranking against three different ground-truth sets).

To actually isolate "how well does CB rank places for interest category X,
with zero CF/behavioral signal", this script builds a synthetic
user_interest_state via build_user_interest_state() with initial_weight=1.0
on exactly category X's tags (the same construction module1_algorithm.py's
build_trip_interest_profile()/build_effective_interest_state() already use
for Plan Trip's per-option interest blending) and feeds it into the exact
same rank_places_by_tag_match() that get_province_detail() calls
internally. This is "the equivalent function" the task explicitly allowed
for, applied 3 times (once per category) instead of once with an empty
profile.

Requires a working .env (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY). Read-only.

Usage:
    python test_module1_eval.py
    python test_module1_eval.py --out module1_eval_results.csv
"""

import argparse
import csv

from db.supabase_client import fetch_all_rows, get_supabase_client
from services.module1_algorithm import build_user_interest_state, rank_places_by_tag_match
from services.module1_repository import attach_place_tags_to_places, fetch_place_tags_for_places

CONFIDENCE_THRESHOLD = 0.7
CATEGORIES = ["culture_history", "nature_outdoor", "adventure"]  # entertainment excluded — see docstring

# province.id_province (post-merger table) — verified via direct DB query;
# old_province.id_province ("230e26ed-...") is a different UUID space
# entirely (0% overlap, see old_province -> province migration).
PROVINCES = {"Ho Chi Minh": "094014a7-b8f6-481a-bbce-5ed6cdd457c5"}
_PROVINCE_NAMES_VI = {
    "An Giang":   "An Giang",
    "Quang Ninh": "Quảng Ninh",
    "Vinh Long":  "Vĩnh Long",
    "Lam Dong":   "Lâm Đồng",
}
# Previously-audited true totals, printed alongside the live fetch count as a
# sanity check (not used in any calculation). STALE as of the old_province ->
# province switch: province is the post-merger table (34 rows vs
# old_province's 63), so these boundaries — and therefore true place counts
# per province — have likely changed. Re-audit before trusting this
# comparison again.
_EXPECTED_TOTAL_ELIGIBLE = {
    "Ho Chi Minh": 463, "An Giang": 275, "Quang Ninh": 165,
    "Vinh Long": 192, "Lam Dong": 316,
}

K_VALUES_DEFAULT = [5, 10]
K_VALUES_HCM_EXTRA = [20]

_PLACE_SELECT_FIELDS = (
    "id_place,id_place_subcategory,name,average_rating,review_count,"
    "place_subcategory!inner(name,place_category,is_itinerary_eligible)"
)


def _lookup_province_ids(supabase) -> dict[str, str]:
    names = list(_PROVINCE_NAMES_VI.values())
    resp = supabase.table("province").select("id_province,name").in_("name", names).execute()
    by_name = {row["name"]: str(row["id_province"]) for row in (resp.data or [])}
    resolved = dict(PROVINCES)
    for key, vi_name in _PROVINCE_NAMES_VI.items():
        if vi_name not in by_name:
            raise ValueError(f"Could not resolve province '{vi_name}' in province table")
        resolved[key] = by_name[vi_name]
    return resolved


def _fetch_all_places_for_province(supabase, id_province: str) -> list[dict]:
    """Same filter as db/place_repository.py's fetch_places_required_filter(),
    but paginated via fetch_all_rows() instead of a single .limit(500) —
    re-confirms no truncation regardless of how large the province grows."""
    def build_query(start: int, end: int):
        return (
            supabase
            .table("place_localized_en")
            .select(_PLACE_SELECT_FIELDS)
            .eq("id_province", id_province)
            .eq("status", "active")
            .eq("place_subcategory.is_itinerary_eligible", True)
            .filter("latitude", "not.is", "null")
            .filter("longitude", "not.is", "null")
            .range(start, end)
        )
    return fetch_all_rows(build_query)


def _fetch_category_tag_map(supabase) -> dict[str, set[str]]:
    """tag_id (str) -> set of category codes, from active trip_interest_option_tag rows."""
    option_resp = (
        supabase.table("trip_interest_option")
        .select("id_trip_interest_option,option_code,is_active")
        .in_("option_code", CATEGORIES)
        .execute()
    )
    option_id_to_code = {
        str(o["id_trip_interest_option"]): o["option_code"] for o in (option_resp.data or [])
    }
    option_ids = list(option_id_to_code.keys())

    link_resp = (
        supabase.table("trip_interest_option_tag")
        .select("id_trip_interest_option,id_tag,is_active")
        .in_("id_trip_interest_option", option_ids)
        .execute()
    )
    tag_id_to_codes: dict[str, set[str]] = {}
    for row in (link_resp.data or []):
        if not row.get("is_active", False):
            continue
        code = option_id_to_code.get(str(row["id_trip_interest_option"]))
        if code:
            tag_id_to_codes.setdefault(str(row["id_tag"]), set()).add(code)
    return tag_id_to_codes


def _fetch_place_tag_confidence(supabase, place_ids: list[str], tag_ids: list[str]) -> list[dict]:
    """All place_tag rows (any confidence) for these places x these tags,
    chunked over place_ids (mirrors fetch_place_tags_for_places' own chunking)."""
    rows = []
    chunk_size = 200
    for i in range(0, len(place_ids), chunk_size):
        chunk = place_ids[i:i + chunk_size]
        resp = (
            supabase.table("place_tag")
            .select("id_place,id_tag,confidence_score")
            .in_("id_place", chunk)
            .in_("id_tag", tag_ids)
            .execute()
        )
        rows.extend(resp.data or [])
    return rows


def build_ground_truth(
    places: list[dict],
    tag_id_to_codes: dict[str, set[str]],
    place_tag_rows: list[dict],
) -> dict[str, set[str]]:
    """category -> set of relevant place_id (confidence_score >= threshold)."""
    place_id_set = {str(p["id_place"]) for p in places}
    relevant: dict[str, set[str]] = {cat: set() for cat in CATEGORIES}
    for row in place_tag_rows:
        conf = float(row.get("confidence_score") or 0)
        if conf < CONFIDENCE_THRESHOLD:
            continue
        pid = str(row["id_place"])
        if pid not in place_id_set:
            continue
        for cat in tag_id_to_codes.get(str(row["id_tag"]), set()):
            relevant[cat].add(pid)
    return relevant


def rank_for_category(
    enriched_places: list[dict],
    category: str,
    tag_id_to_codes: dict[str, set[str]],
    tag_map: dict[str, dict],
) -> list[dict]:
    """CB-only ranking as if the user's entire interest profile were 100%
    category X (see module docstring for why control.blank's real, empty
    profile can't be used directly)."""
    category_tag_ids = [tid for tid, codes in tag_id_to_codes.items() if category in codes]
    category_tag_codes = [tag_map[tid]["tag_code"] for tid in category_tag_ids if tid in tag_map]
    initial_weights = {code: 1.0 for code in category_tag_codes}
    user_interest_state = build_user_interest_state(initial_weights, tag_map={
        t["tag_code"]: t for t in tag_map.values()
    })
    id_tag_map = {tid: tag_map[tid]["tag_code"] for tid in tag_map}
    return rank_places_by_tag_match(
        enriched_places, user_interest_state, weight_field="final_weight", id_tag_map=id_tag_map,
    )


def precision_recall_f1(top_k_ids: list[str], relevant_ids: set[str], k: int) -> tuple[float, float, float]:
    hits = len(set(top_k_ids) & relevant_ids)
    precision = hits / k if k > 0 else float("nan")
    recall = hits / len(relevant_ids) if relevant_ids else float("nan")
    if precision + recall > 0 and not (precision != precision or recall != recall):  # not NaN
        f1 = 2 * precision * recall / (precision + recall)
    else:
        f1 = float("nan")
    return round(precision, 4), round(recall, 4), round(f1, 4)


def main(out_path: str) -> None:
    supabase = get_supabase_client()
    provinces = _lookup_province_ids(supabase)

    print("Resolving tag(config, all categories) ...")
    tag_id_to_codes = _fetch_category_tag_map(supabase)
    all_tag_ids = list(tag_id_to_codes.keys())
    for cat in CATEGORIES:
        n_tags = sum(1 for codes in tag_id_to_codes.values() if cat in codes)
        print(f"    {cat}: {n_tags} tag(s) mapped")
    if not all_tag_ids:
        raise RuntimeError("No active trip_interest_option_tag rows found for any category — aborting.")

    tag_meta_resp = supabase.table("tag").select("id_tag,tag_code").in_("id_tag", all_tag_ids).execute()
    tag_map = {str(t["id_tag"]): t for t in (tag_meta_resp.data or [])}

    rows: list[dict] = []

    for province_name, id_province in provinces.items():
        print(f"\n[PROVINCE] {province_name} ({id_province})")
        places = _fetch_all_places_for_province(supabase, id_province)
        expected = _EXPECTED_TOTAL_ELIGIBLE.get(province_name)
        print(f"    fetched {len(places)} eligible places "
              f"(previously-audited true total: {expected}) "
              f"{'OK' if expected is None or len(places) == expected else 'MISMATCH — investigate'}")

        place_ids = [str(p["id_place"]) for p in places]
        place_tag_rows = _fetch_place_tag_confidence(supabase, place_ids, all_tag_ids)
        enriched = attach_place_tags_to_places(places, place_tag_rows)

        ground_truth = build_ground_truth(places, tag_id_to_codes, place_tag_rows)
        for cat in CATEGORIES:
            print(f"    ground_truth[{cat}] = {len(ground_truth[cat])} relevant place(s)")

        k_values = K_VALUES_DEFAULT + (K_VALUES_HCM_EXTRA if province_name == "Ho Chi Minh" else [])

        for category in CATEGORIES:
            relevant_ids = ground_truth[category]
            ranked = rank_for_category(enriched, category, tag_id_to_codes, tag_map)
            ranked_ids = [str(p["id_place"]) for p in ranked]

            for k in k_values:
                top_k_ids = ranked_ids[:k]
                precision, recall, f1 = precision_recall_f1(top_k_ids, relevant_ids, k)
                rows.append({
                    "province": province_name,
                    "category": category,
                    "k": k,
                    "relevant_total": len(relevant_ids),
                    "candidate_pool_size": len(places),
                    "precision": precision,
                    "recall": recall,
                    "f1": f1,
                })
                print(f"      {category} K={k}: P={precision} R={recall} F1={f1} "
                      f"(relevant_total={len(relevant_ids)})")

    header = ["province", "category", "k", "relevant_total", "candidate_pool_size", "precision", "recall", "f1"]
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=header)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
    print(f"\nWrote {len(rows)} rows to {out_path}")
    print("\nNOTE for the report: 'entertainment' is intentionally absent — "
          "trip_interest_option_tag has zero active tag rows for it (config "
          "gap, not a sample-size issue). Report it as N/A, not a P/R score of 0.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=str, default="module1_eval_results.csv", help="CSV output path")
    args = parser.parse_args()
    main(args.out)
