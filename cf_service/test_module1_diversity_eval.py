"""
test_module1_diversity_eval.py
Module 1 diversity evaluation (M1-06, per evaluation_module1_module2.md) —
compares Top-K ranked purely by score against Top-K after
apply_diversity_selection(), for capstone report section 4.4.

Metrics (formulas exactly as specified in M1-06):
  CategoryCoverage    = distinct categories in Top-K / distinct categories
                        present in the whole candidate pool
  SubcategoryCoverage = same, by subcategory
  ILD (Intra-List Diversity) = pairs with DIFFERENT subcategory in Top-K /
                        total pairs in Top-K (C(K,2))
  ScoreRetention      = mean(module1_score) after / mean(module1_score) before

Pass condition (per spec): ScoreRetention >= 0.90 AND coverage after >=
coverage before (both category and subcategory).

Audit confirmed before writing this script:
  - apply_diversity_selection(ranked_places, total_days, user_selected_interests,
    trip_selected_options=None, trip_option_subcategory_rows=None) -> dict
    with keys diversified_top_k/overflow_pool/low_score_pool/config/summary
    (services/module1_diversity.py).
  - "Top-K, ranked by score only, no diversity" = ranked_places[:K] — the
    ranked list rank_places_by_tag_match() returns is already fully sorted,
    so this is a plain slice, no extra sort needed.
  - K is NOT the P@K/R@K K=5/10/20 from test_module1_eval.py — it is
    apply_diversity_selection()'s own config["top_k"]
    (get_top_k_for_diversity(total_days) = min(total_days*CANDIDATE_PER_DAY,
    MAX_TOP_K)), read directly off the real diversity_result so "before" and
    "after" always compare the exact same K, with zero risk of drift from
    reimplementing that formula separately. total_days=7 is used as the
    reference scenario (same convention as test_module2_eval.py's
    MAX_N_DAYS_FOR_TOP_PLACES=7 -> top_k=56, matching the values already
    seen in module2_eval_results.csv).

Reuses test_module1_eval.py's fixtures and per-category CB-only ranking
construction directly (same 5 provinces, same 3 profiles/categories,
same synthetic "100% interest in category X" user_interest_state) — not
reimplemented, so both scripts are guaranteed consistent.

ADDITIONAL scenario (this script only, does not touch
services/module1_diversity.py or any Diversity Selection code): a "mixed"
profile per province — 60% weight on a primary category's tags, 20% each
on the other two categories' tags — to test the hypothesis that a low
ScoreRetention in the single-interest (100% one category) run is an
artifact of an unrealistically extreme test profile, not a real weakness
in the diversity algorithm. Only user_interest_state construction differs;
apply_diversity_selection() itself is called identically. Written to a
SEPARATE csv so the two scenarios can be compared side by side.

Requires a working .env (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY). Read-only.

Usage:
    python test_module1_diversity_eval.py
    python test_module1_diversity_eval.py --out module1_diversity_eval_results.csv --out-mixed module1_diversity_eval_mixed_results.csv
"""

import argparse
import csv

from dotenv import load_dotenv

load_dotenv()

from db.supabase_client import get_supabase_client
from services.module1_algorithm import build_user_interest_state, rank_places_by_tag_match
from services.module1_diversity import (
    apply_diversity_selection,
    extract_place_category,
    extract_place_subcategory,
)
from test_module1_eval import (
    CATEGORIES,
    _fetch_category_tag_map,
    _fetch_all_places_for_province,
    _fetch_place_tag_confidence,
    _lookup_province_ids,
    rank_for_category,
)
from services.module1_repository import attach_place_tags_to_places

TOTAL_DAYS_REFERENCE = 7  # reference scenario for K — see module docstring
MIXED_PRIMARY_WEIGHT = 0.6
MIXED_OTHER_WEIGHT = 0.2  # x2 other categories = 1.0 total


def _score(place: dict) -> float:
    return float(place.get("module1_score") or place.get("tag_match") or 0.0)


def _mean_score(places: list[dict]) -> float:
    if not places:
        return 0.0
    return sum(_score(p) for p in places) / len(places)


def _category_coverage(top_k: list[dict], pool_categories: set[str]) -> float:
    if not pool_categories:
        return float("nan")
    return len({extract_place_category(p) for p in top_k}) / len(pool_categories)


def _subcategory_coverage(top_k: list[dict], pool_subcategories: set[str]) -> float:
    if not pool_subcategories:
        return float("nan")
    return len({extract_place_subcategory(p) for p in top_k}) / len(pool_subcategories)


def _ild(top_k: list[dict]) -> float:
    n = len(top_k)
    if n < 2:
        return float("nan")
    subs = [extract_place_subcategory(p) for p in top_k]
    total_pairs = n * (n - 1) // 2
    diff_pairs = sum(1 for i in range(n) for j in range(i + 1, n) if subs[i] != subs[j])
    return diff_pairs / total_pairs


def rank_for_mixed_profile(
    enriched_places: list[dict],
    primary_category: str,
    tag_id_to_codes: dict[str, set[str]],
    tag_map: dict[str, dict],
    primary_weight: float = MIXED_PRIMARY_WEIGHT,
    other_weight: float = MIXED_OTHER_WEIGHT,
) -> list[dict]:
    """Same construction as test_module1_eval.rank_for_category(), except
    the synthetic user_interest_state blends all 3 categories instead of
    being 100% one category: primary_category gets `primary_weight` total
    weight mass, each of the other two categories gets `other_weight` —
    split evenly across each category's own tags, then summed per tag (a
    tag shared by 2 categories accumulates both contributions). Does NOT
    touch apply_diversity_selection() or any Diversity Selection code —
    only the interest-state input changes."""
    weight_by_category = {primary_category: primary_weight}
    for cat in CATEGORIES:
        if cat != primary_category:
            weight_by_category[cat] = other_weight

    tag_codes_by_category: dict[str, list[str]] = {cat: [] for cat in CATEGORIES}
    for tag_id, codes in tag_id_to_codes.items():
        tag_info = tag_map.get(tag_id)
        if not tag_info:
            continue
        for code in codes:
            if code in tag_codes_by_category:
                tag_codes_by_category[code].append(tag_info["tag_code"])

    initial_weights: dict[str, float] = {}
    for cat in CATEGORIES:
        tag_codes = tag_codes_by_category[cat]
        if not tag_codes:
            continue
        per_tag_weight = weight_by_category[cat] / len(tag_codes)
        for tag_code in tag_codes:
            initial_weights[tag_code] = initial_weights.get(tag_code, 0.0) + per_tag_weight

    user_interest_state = build_user_interest_state(
        initial_weights, tag_map={t["tag_code"]: t for t in tag_map.values()},
    )
    id_tag_map = {tag_id: tag_map[tag_id]["tag_code"] for tag_id in tag_map}
    return rank_places_by_tag_match(
        enriched_places, user_interest_state, weight_field="final_weight", id_tag_map=id_tag_map,
    )


def evaluate_one(province_name: str, category: str, ranked: list[dict]) -> dict:
    diversity_result = apply_diversity_selection(
        ranked, total_days=TOTAL_DAYS_REFERENCE, user_selected_interests=[category],
    )
    k = diversity_result["config"]["top_k"]

    before = ranked[:k]
    after = diversity_result["diversified_top_k"]

    pool_categories = {extract_place_category(p) for p in ranked}
    pool_subcategories = {extract_place_subcategory(p) for p in ranked}

    category_coverage_before = round(_category_coverage(before, pool_categories), 4)
    category_coverage_after = round(_category_coverage(after, pool_categories), 4)
    subcategory_coverage_before = round(_subcategory_coverage(before, pool_subcategories), 4)
    subcategory_coverage_after = round(_subcategory_coverage(after, pool_subcategories), 4)
    ild_before = round(_ild(before), 4)
    ild_after = round(_ild(after), 4)

    mean_before = _mean_score(before)
    mean_after = _mean_score(after)
    score_retention = round(mean_after / mean_before, 4) if mean_before > 0 else float("nan")

    score_retention_ok = (not (score_retention != score_retention)) and score_retention >= 0.90
    category_coverage_ok = category_coverage_after >= category_coverage_before
    subcategory_coverage_ok = subcategory_coverage_after >= subcategory_coverage_before
    passed = score_retention_ok and category_coverage_ok and subcategory_coverage_ok

    return {
        "province": province_name,
        "category": category,
        "k": k,
        "pool_size": len(ranked),
        "category_coverage_before": category_coverage_before,
        "category_coverage_after": category_coverage_after,
        "subcategory_coverage_before": subcategory_coverage_before,
        "subcategory_coverage_after": subcategory_coverage_after,
        "ild_before": ild_before,
        "ild_after": ild_after,
        "score_retention": score_retention,
        "pass_fail": "PASS" if passed else "FAIL",
    }


_HEADER = [
    "province", "category", "k", "pool_size",
    "category_coverage_before", "category_coverage_after",
    "subcategory_coverage_before", "subcategory_coverage_after",
    "ild_before", "ild_after", "score_retention", "pass_fail",
]


def _write_csv(rows: list[dict], out_path: str) -> None:
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=_HEADER)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main(out_path: str, out_path_mixed: str) -> None:
    supabase = get_supabase_client()
    provinces = _lookup_province_ids(supabase)

    print("Resolving category -> tag map ...")
    tag_id_to_codes = _fetch_category_tag_map(supabase)
    all_tag_ids = list(tag_id_to_codes.keys())
    tag_meta_resp = supabase.table("tag").select("id_tag,tag_code").in_("id_tag", all_tag_ids).execute()
    tag_map = {str(t["id_tag"]): t for t in (tag_meta_resp.data or [])}

    rows: list[dict] = []
    rows_mixed: list[dict] = []

    for province_name, id_province in provinces.items():
        print(f"\n[PROVINCE] {province_name} ({id_province})")
        places = _fetch_all_places_for_province(supabase, id_province)
        place_ids = [str(p["id_place"]) for p in places]
        place_tag_rows = _fetch_place_tag_confidence(supabase, place_ids, all_tag_ids)
        enriched = attach_place_tags_to_places(places, place_tag_rows)
        print(f"    {len(places)} eligible places")

        for category in CATEGORIES:
            # ── Scenario A: single-interest (100% one category) ──────────────
            ranked = rank_for_category(enriched, category, tag_id_to_codes, tag_map)
            row = evaluate_one(province_name, category, ranked)
            rows.append(row)
            print(
                f"    [single] {category}: K={row['k']} "
                f"cat_cov={row['category_coverage_before']}->{row['category_coverage_after']} "
                f"subcat_cov={row['subcategory_coverage_before']}->{row['subcategory_coverage_after']} "
                f"ild={row['ild_before']}->{row['ild_after']} "
                f"score_retention={row['score_retention']} [{row['pass_fail']}]"
            )

            # ── Scenario B: mixed profile (60% primary + 20%/20% others) ──────
            ranked_mixed = rank_for_mixed_profile(enriched, category, tag_id_to_codes, tag_map)
            row_mixed = evaluate_one(province_name, category, ranked_mixed)
            rows_mixed.append(row_mixed)
            print(
                f"    [mixed]  {category}: K={row_mixed['k']} "
                f"score_retention={row_mixed['score_retention']} [{row_mixed['pass_fail']}]"
            )

    _write_csv(rows, out_path)
    _write_csv(rows_mixed, out_path_mixed)

    n_pass = sum(1 for r in rows if r["pass_fail"] == "PASS")
    n_pass_mixed = sum(1 for r in rows_mixed if r["pass_fail"] == "PASS")
    print(f"\nWrote {len(rows)} rows to {out_path} — {n_pass}/{len(rows)} PASS (single-interest)")
    print(f"Wrote {len(rows_mixed)} rows to {out_path_mixed} — {n_pass_mixed}/{len(rows_mixed)} PASS (mixed profile)")

    valid_single = [r["score_retention"] for r in rows if r["score_retention"] == r["score_retention"]]
    valid_mixed = [r["score_retention"] for r in rows_mixed if r["score_retention"] == r["score_retention"]]
    if valid_single and valid_mixed:
        mean_single = round(sum(valid_single) / len(valid_single), 4)
        mean_mixed = round(sum(valid_mixed) / len(valid_mixed), 4)
        print(f"\n--- ScoreRetention comparison ---")
        print(f"single-interest (100% one category): mean = {mean_single}")
        print(f"mixed profile (60/20/20):             mean = {mean_mixed}")
        print(
            f"Hypothesis {'CONFIRMED' if mean_mixed > mean_single else 'NOT confirmed'}: "
            f"mixed profile {'raises' if mean_mixed > mean_single else 'does not raise'} "
            f"ScoreRetention vs the single-interest scenario."
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=str, default="module1_diversity_eval_results.csv", help="CSV output path (single-interest scenario)")
    parser.add_argument("--out-mixed", type=str, default="module1_diversity_eval_mixed_results.csv", help="CSV output path (mixed-profile scenario)")
    args = parser.parse_args()
    main(args.out, args.out_mixed)
