"""
test_module2_eval.py
Module 2 (K-Means + Greedy Repair) quality evaluation — capstone report
section 4.4.

Metrics (computed for BOTH initial_day_clusters [post K-Means, pre-repair]
and day_clusters [post Greedy Repair], in the same build_module2_result()
call):
  - compactness_ratio = mean intra-day distance-to-centroid / candidate
    pool's own distance-to-centroid. Lower is tighter clustering.
  - balance_error = mean absolute difference between each day's actual
    place count and PACE_DAY_RULES[pace_level]['target_per_day'].
  - repair_rate = fraction of days that have >=1 repair_logs entry.
  - action_breakdown = counts + percentage of each repair_logs['action'].

Design (confirmed in the 4.4 audit before writing this script):
  - Candidate ranking (CB + CF + diversity selection) is computed ONCE per
    province, using n_days=7 (the largest sweep value) so the resulting
    top_places list is large enough (get_top_k_for_diversity(7) places) to
    cover every smaller n_days in the sweep — build_module2_result() itself
    re-slices top_places down to n_days*CANDIDATE_PER_DAY candidates
    internally (see prepare_module2_candidates()), so reusing one superset
    list across all n_days/pace_level combinations for a given province is
    equivalent to recomputing per n_days, without re-running the CB/CF/DB
    pipeline 80 times.
  - The candidate pool used for compactness_ratio's denominator is
    reconstructed from initial_day_clusters + initial_backup_places (their
    union is exactly prepare_module2_candidates()'s candidate_places, since
    build_initial_day_clusters() partitions every candidate into one or the
    other at that stage) — no changes to module2_algorithm.py needed.

Requires a working .env (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY). Read-only
against place/tag/user tables; does not call save_plan, writes nothing.

Usage:
    python test_module2_eval.py
    python test_module2_eval.py --out module2_eval_results.csv
"""

import argparse
import csv
import datetime
from collections import Counter

from db.supabase_client import get_supabase_client
from services.filters import filter_places_with_fallback
from services.module1_algorithm import (
    build_user_interest_state_from_rows,
    compute_alpha,
    rank_places_by_tag_match,
)
from services.module1_diversity import apply_diversity_selection
from services.module1_repository import (
    attach_place_tags_to_places,
    build_tag_map,
    fetch_active_tags,
    fetch_already_rated_places,
    fetch_cf_scores_for_user,
    fetch_place_tags_for_places,
    fetch_user_interest_tags,
    fetch_user_onboarding_choices,
    fetch_user_travel_profile,
)
from services.module2_algorithm import (
    average_distance_to_centroid,
    build_module2_result,
    compute_centroid,
    get_pace_rule,
)
from db.place_repository import fetch_places_required_filter

# ── Fixed test fixtures (same as test_performance_eval.py, verified real IDs) ─
USER_ID = "dd16ba71-c26b-44dd-a3f4-61973f268822"  # control.blank (no history — CB-only ranking)
INTEREST_CULTURE_HISTORY = "24e0f953-f3aa-4b69-9e91-2b3724c086d3"

PROVINCES = {
    # province.id_province (post-merger table) — verified via direct DB
    # query; old_province.id_province ("230e26ed-...") is a different UUID
    # space entirely (0% overlap, see old_province -> province migration).
    "Ho Chi Minh": "094014a7-b8f6-481a-bbce-5ed6cdd457c5",
    "An Giang":    None,  # filled in by _lookup_province_ids()
    "Quang Ninh":  None,
    "Vinh Long":   None,
    "Lam Dong":    None,
}
_PROVINCE_NAMES_VI = {
    "An Giang":   "An Giang",
    "Quang Ninh": "Quảng Ninh",
    "Vinh Long":  "Vĩnh Long",
    "Lam Dong":   "Lâm Đồng",
}

N_DAYS_SWEEP = [2, 3, 5, 7]
PACE_LEVELS = ["easy", "balanced", "active", "packed"]
MAX_N_DAYS_FOR_TOP_PLACES = max(N_DAYS_SWEEP)  # 7 — superset size for diversity selection

REPAIR_ACTIONS = [
    "add_place_to_underfilled_day",
    "move_place_to_other_day",
    "move_place_to_backup",
    "move_high_rank_place_to_optional",
    "cannot_fill_underfilled_day",
]


def _lookup_province_ids(supabase) -> dict[str, str]:
    """Resolve the 4 provinces not already hardcoded, by Vietnamese name."""
    names = list(_PROVINCE_NAMES_VI.values())
    resp = supabase.table("province").select("id_province,name").in_("name", names).execute()
    by_name = {row["name"]: str(row["id_province"]) for row in (resp.data or [])}
    resolved = dict(PROVINCES)
    for key, vi_name in _PROVINCE_NAMES_VI.items():
        if vi_name not in by_name:
            raise ValueError(f"Could not resolve province '{vi_name}' in province table")
        resolved[key] = by_name[vi_name]
    return resolved


def compute_top_places(supabase, id_province: str) -> list[dict]:
    """
    Replicates trip_planner.py's pipeline up through diversity selection
    (CB rank -> CF blend -> diversity), sized for MAX_N_DAYS_FOR_TOP_PLACES
    so the result is reusable across every smaller n_days in the sweep.
    """
    required_places = fetch_places_required_filter(supabase, id_province)
    user_profile = fetch_user_travel_profile(supabase, USER_ID)
    filtered_places, _ = filter_places_with_fallback(
        required_places, user_profile or {}, MAX_N_DAYS_FOR_TOP_PLACES
    )

    tags = fetch_active_tags(supabase)
    tag_map = build_tag_map(tags)
    id_tag_map = {
        str(t["id_tag"]): t["tag_code"] for t in tags if t.get("id_tag") and t.get("tag_code")
    }

    place_ids = [str(p["id_place"]) for p in filtered_places]
    place_tag_rows = fetch_place_tags_for_places(supabase, place_ids)
    places_with_tags = attach_place_tags_to_places(filtered_places, place_tag_rows)

    interest_tag_rows = fetch_user_interest_tags(supabase, USER_ID)
    already_rated = fetch_already_rated_places(supabase, USER_ID)
    user_interest_state = build_user_interest_state_from_rows(interest_tag_rows, tag_map, id_tag_map)

    ranked = rank_places_by_tag_match(
        places_with_tags, user_interest_state, weight_field="final_weight", id_tag_map=id_tag_map,
    )
    ranked = [p for p in ranked if str(p["id_place"]) not in already_rated]

    cf_scores = fetch_cf_scores_for_user(supabase, USER_ID, place_ids)
    alpha = compute_alpha(cf_scores, len(filtered_places))
    for place in ranked:
        tag_match = float(place.get("tag_match") or 0.0)
        cf = cf_scores.get(str(place["id_place"]), 0.0)
        place["cf_score"] = round(cf, 6)
        place["final_score"] = round(alpha * tag_match + (1 - alpha) * cf, 6)
    ranked.sort(key=lambda p: -p["final_score"])

    onboarding_choices = fetch_user_onboarding_choices(supabase, USER_ID)
    user_selected_interests = [c["option_code"] for c in onboarding_choices if c.get("option_code")]
    # Not exercising trip-level interest_option_ids override here — Module 2
    # only consumes the ranked place list + module1_score, independent of
    # which interest source produced it.
    diversity_result = apply_diversity_selection(
        ranked, MAX_N_DAYS_FOR_TOP_PLACES, user_selected_interests,
    )
    return diversity_result["diversified_top_k"]


def _reconstruct_candidate_pool(m2_result: dict) -> list[dict]:
    """initial_day_clusters + initial_backup_places == prepare_module2_candidates()'s
    candidate_places (every candidate is partitioned into exactly one of the two
    at build_initial_day_clusters() time) — reconstructed without touching
    module2_algorithm.py's return contract."""
    pool: list[dict] = []
    for day in m2_result["initial_day_clusters"]:
        pool.extend(day["places"])
    pool.extend(m2_result["initial_backup_places"])
    return pool


def _mean_intra_day_distance(day_clusters: list[dict]) -> float:
    distances = []
    for day in day_clusters:
        places = day["places"]
        if not places:
            continue
        centroid = day.get("centroid") or compute_centroid(places)
        distances.append(average_distance_to_centroid(places, centroid))
    return sum(distances) / len(distances) if distances else 0.0


def _balance_error(day_clusters: list[dict], target_per_day: int) -> float:
    if not day_clusters:
        return 0.0
    errors = [abs(len(day["places"]) - target_per_day) for day in day_clusters]
    return sum(errors) / len(errors)


def _repair_rate(day_clusters: list[dict], repair_logs: list[dict]) -> float:
    if not day_clusters:
        return 0.0
    days_with_repairs = {log["day"] for log in repair_logs if "day" in log}
    return len(days_with_repairs) / len(day_clusters)


def _action_breakdown(repair_logs: list[dict]) -> dict[str, float]:
    total = len(repair_logs)
    counts = Counter(log.get("action") for log in repair_logs)
    breakdown = {}
    for action in REPAIR_ACTIONS:
        count = counts.get(action, 0)
        breakdown[f"{action}_count"] = count
        breakdown[f"{action}_pct"] = round(100 * count / total, 1) if total else 0.0
    return breakdown


def evaluate_one_run(top_places: list[dict], n_days: int, pace_level: str) -> dict:
    start_date = "2026-08-01"
    end_date = (
        datetime.date.fromisoformat(start_date) + datetime.timedelta(days=n_days - 1)
    ).isoformat()

    m2_result = build_module2_result(
        top_places, start_date=start_date, end_date=end_date, pace_level=pace_level,
    )

    pool = _reconstruct_candidate_pool(m2_result)
    pool_centroid = compute_centroid(pool)
    pool_avg_dist = average_distance_to_centroid(pool, pool_centroid) if pool else 0.0

    target_per_day = get_pace_rule(pace_level)["target_per_day"]

    intra_before = _mean_intra_day_distance(m2_result["initial_day_clusters"])
    intra_after = _mean_intra_day_distance(m2_result["day_clusters"])
    compactness_before = round(intra_before / pool_avg_dist, 4) if pool_avg_dist > 0 else float("nan")
    compactness_after = round(intra_after / pool_avg_dist, 4) if pool_avg_dist > 0 else float("nan")

    balance_before = round(_balance_error(m2_result["initial_day_clusters"], target_per_day), 3)
    balance_after = round(_balance_error(m2_result["day_clusters"], target_per_day), 3)

    repair_rate = round(_repair_rate(m2_result["day_clusters"], m2_result["repair_logs"]), 3)
    action_breakdown = _action_breakdown(m2_result["repair_logs"])

    row = {
        "n_days": n_days,
        "pace_level": pace_level,
        "candidate_pool_size": len(pool),
        "compactness_before": compactness_before,
        "compactness_after": compactness_after,
        "balance_before": balance_before,
        "balance_after": balance_after,
        "repair_rate": repair_rate,
        "repair_action_total": len(m2_result["repair_logs"]),
    }
    row.update(action_breakdown)
    return row


def main(out_path: str) -> None:
    supabase = get_supabase_client()
    provinces = _lookup_province_ids(supabase)

    rows: list[dict] = []
    for province_name, id_province in provinces.items():
        print(f"[PROVINCE] {province_name} ({id_province}) — computing top_places once "
              f"(n_days={MAX_N_DAYS_FOR_TOP_PLACES} superset)...")
        top_places = compute_top_places(supabase, id_province)
        print(f"    top_places size = {len(top_places)}")

        for n_days in N_DAYS_SWEEP:
            for pace_level in PACE_LEVELS:
                print(f"    n_days={n_days} pace={pace_level} ...")
                row = evaluate_one_run(top_places, n_days, pace_level)
                row_with_context = {"province": province_name, **row}
                rows.append(row_with_context)

    header = (
        ["province", "n_days", "pace_level", "candidate_pool_size",
         "compactness_before", "compactness_after",
         "balance_before", "balance_after",
         "repair_rate", "repair_action_total"]
        + [f"{a}_count" for a in REPAIR_ACTIONS]
        + [f"{a}_pct" for a in REPAIR_ACTIONS]
    )
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=header)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)

    print(f"\nWrote {len(rows)} rows to {out_path} "
          f"({len(provinces)} provinces x {len(N_DAYS_SWEEP)} n_days x {len(PACE_LEVELS)} pace_levels)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=str, default="module2_eval_results.csv", help="CSV output path")
    args = parser.parse_args()
    main(args.out)
