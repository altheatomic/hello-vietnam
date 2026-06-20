"""
scripts/smoke_test.py
Smoke test for TripPlannerService — calls the full pipeline directly (no HTTP).

Usage:
  # From cf_service/ directory:
  python scripts/smoke_test.py [user_id] [province_id] [n_days] [start_date]

  # Example with args:
  python scripts/smoke_test.py <uuid> <uuid> 3 2026-07-01

  # Example with defaults (edit TEST_* constants below):
  python scripts/smoke_test.py

Requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env or environment.
"""

from __future__ import annotations

import asyncio
import datetime
import json
import os
import sys
import time

# Allow running from cf_service/ directory
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv()

# ── Hardcoded test defaults (override with CLI args) ──────────────────────────
TEST_USER_ID     = "00000000-0000-0000-0000-000000000001"   # replace with real user UUID
TEST_PROVINCE_ID = "00000000-0000-0000-0000-000000000002"   # replace with real province UUID
TEST_N_DAYS      = 3
TEST_START_DATE  = "2026-07-01"


def parse_args():
    args = sys.argv[1:]
    user_id     = args[0] if len(args) > 0 else TEST_USER_ID
    province_id = args[1] if len(args) > 1 else TEST_PROVINCE_ID
    n_days      = int(args[2]) if len(args) > 2 else TEST_N_DAYS
    start_date  = args[3] if len(args) > 3 else TEST_START_DATE
    return user_id, province_id, n_days, start_date


def banner(stage: str) -> None:
    print(f"\n{'=' * 70}")
    print(f"  [{stage}]")
    print(f"{'=' * 70}")


def pretty(obj, max_items: int = 3) -> str:
    if isinstance(obj, list):
        preview = obj[:max_items]
        suffix = f"  ... (+{len(obj) - max_items} more)" if len(obj) > max_items else ""
        return json.dumps(preview, ensure_ascii=False, indent=2, default=str) + suffix
    return json.dumps(obj, ensure_ascii=False, indent=2, default=str)


async def run_smoke_test(user_id: str, province_id: str, n_days: int, start_date: str) -> None:
    from db.supabase_client import get_supabase_client
    from db.place_repository import fetch_places_required_filter
    from services.filters import filter_places_with_fallback
    from services.module1_repository import (
        fetch_active_tags, build_tag_map,
        fetch_place_tags_for_places, attach_place_tags_to_places,
        fetch_user_interest_tags, fetch_already_rated_places,
        fetch_cf_scores_for_user, fetch_user_onboarding_choices,
        fetch_user_travel_profile,
    )
    from services.module1_algorithm import (
        build_user_interest_state_from_rows,
        rank_places_by_tag_match,
    )
    from services.module1_diversity import apply_diversity_selection
    from services.module2_algorithm import build_module2_result
    from services.trip_planner import TripPlannerService, _compute_alpha

    start_at = datetime.date.fromisoformat(start_date)
    end_date = start_at + datetime.timedelta(days=n_days - 1)

    print(f"\nSmoke test — TripPlannerService")
    print(f"  user_id     : {user_id}")
    print(f"  province_id : {province_id}")
    print(f"  n_days      : {n_days}")
    print(f"  start_date  : {start_date}  →  end_date: {end_date}")

    supabase = get_supabase_client()

    t0 = time.perf_counter()

    # ── [Filtering] ───────────────────────────────────────────────────────────
    banner("Filtering")
    required_places = fetch_places_required_filter(supabase, province_id)
    user_profile = fetch_user_travel_profile(supabase, user_id)
    filtered_places, filter_report = filter_places_with_fallback(
        required_places, user_profile or {}, n_days
    )
    print(f"Required filter : {filter_report['required_filter_count']} places")
    print(f"Optional filter : {filter_report['optional_filter_count']} places")
    print(f"Fallback used   : {filter_report['fallback_used']}")
    print(f"Pool status     : {filter_report['optional_pool_status']}")
    print(f"Final pool      : {len(filtered_places)} places")

    if not filtered_places:
        print("\nERROR: No places found for this province. Check province_id and DB data.")
        return

    # ── [Module 1 – TagMatch] ─────────────────────────────────────────────────
    banner("Module 1 – TagMatch")
    tags = fetch_active_tags(supabase)
    tag_map = build_tag_map(tags)
    id_tag_map = {
        str(tag["id_tag"]): tag["tag_code"]
        for tag in tags
        if tag.get("id_tag") and tag.get("tag_code")
    }
    place_ids = [str(p["id_place"]) for p in filtered_places]
    place_tag_rows = fetch_place_tags_for_places(supabase, place_ids)
    places_with_tags = attach_place_tags_to_places(filtered_places, place_tag_rows)
    interest_tag_rows = fetch_user_interest_tags(supabase, user_id)
    already_rated = fetch_already_rated_places(supabase, user_id)
    user_interest_state = build_user_interest_state_from_rows(interest_tag_rows, tag_map, id_tag_map)
    ranked = rank_places_by_tag_match(places_with_tags, user_interest_state, id_tag_map=id_tag_map)
    ranked = [p for p in ranked if str(p["id_place"]) not in already_rated]

    print(f"Active tags      : {len(tags)}")
    print(f"Interest tags    : {len(interest_tag_rows)}")
    print(f"Already rated    : {len(already_rated)}")
    print(f"Place tag rows   : {len(place_tag_rows)}")
    print(f"Ranked places    : {len(ranked)}")
    if ranked:
        top3 = [{"name": p.get("name"), "tag_match": p.get("tag_match")} for p in ranked[:3]]
        print(f"Top 3 by tag_match: {json.dumps(top3, ensure_ascii=False)}")

    # ══════════════════════════════════════════════════════════════════════════
    # DEBUG: Trace tag_match = 0.0 root cause
    # ══════════════════════════════════════════════════════════════════════════

    banner("DEBUG 1 — user_interest_state keys (tag_code → final_weight)")
    print(f"user_interest_state has {len(user_interest_state)} entries")
    if user_interest_state:
        sample = list(user_interest_state.items())[:5]
        for tc, info in sample:
            print(f"  key={repr(tc)}  final_weight={info.get('final_weight')}  id_tag={info.get('id_tag')}")
    else:
        print("  EMPTY — build_user_interest_state_from_rows() produced no entries")
        print(f"  Raw interest_tag_rows sample (first 2):")
        for row in interest_tag_rows[:2]:
            print(f"    row keys: {list(row.keys())}")
            print(f"    row['tag'] = {row.get('tag')}")
            print(f"    row.get('tag_code') = {row.get('tag_code')}")
            print(f"    row.get('id_tag')   = {row.get('id_tag')}")
            print(f"    row.get('final_weight') = {row.get('final_weight')}")

    banner("DEBUG 2 — place['place_tag'] for first place")
    if places_with_tags:
        sample_place = places_with_tags[0]
        ptags = sample_place.get("place_tag") or []
        print(f"  place: {sample_place.get('name')}")
        print(f"  place_tag count: {len(ptags)}")
        for pt in ptags[:3]:
            print(f"    pt keys: {list(pt.keys())}")
            print(f"    pt.get('tag_code')        = {repr(pt.get('tag_code'))}")
            print(f"    pt.get('tag')             = {pt.get('tag')}")
            print(f"    pt.get('confidence_score') = {pt.get('confidence_score')}")
            # Show what extract_tag_code() would return
            nested_tag = pt.get("tag") or {}
            resolved = pt.get("tag_code") or nested_tag.get("tag_code")
            print(f"    → extract_tag_code() result = {repr(resolved)}")
    else:
        print("  No places with tags.")

    banner("DEBUG 3 — cross-match: user_interest_state keys vs place_tag tag_codes")
    place_tag_codes_seen: set[str] = set()
    for pt in place_tag_rows:
        nested = (pt.get("tag") or {})
        resolved = pt.get("tag_code") or nested.get("tag_code")
        if resolved:
            place_tag_codes_seen.add(resolved)
    user_tag_codes = set(user_interest_state.keys())
    overlap = user_tag_codes & place_tag_codes_seen
    print(f"  user_interest_state tag_codes: {sorted(user_tag_codes)[:10]}")
    print(f"  place_tag tag_codes (sample):  {sorted(place_tag_codes_seen)[:10]}")
    print(f"  Overlap count: {len(overlap)}")
    print(f"  Overlapping tag_codes: {sorted(overlap)[:10]}")
    if not user_tag_codes:
        print("  ⚠ user_interest_state is EMPTY → no match possible")
    elif not place_tag_codes_seen:
        print("  ⚠ place_tag rows resolved 0 tag_codes → extract_tag_code() always returns None")
    elif not overlap:
        print("  ⚠ No overlap → tag_codes use different namespaces or formats")

    banner("DEBUG 4 — calculate_tag_match() internals (first ranked place)")
    from services.module1_algorithm import calculate_tag_match
    if ranked:
        test_place = ranked[0]
        ptags = test_place.get("place_tag") or []
        weight_field = "final_weight"
        print(f"  weight_field used: {repr(weight_field)}")
        denominator = sum(
            max(float(info.get(weight_field) or 0.0), 0.0)
            for info in user_interest_state.values()
        )
        print(f"  denominator (sum of final_weight): {denominator}")
        print(f"  place_tag rows for this place: {len(ptags)}")
        for pt in ptags[:3]:
            nested = (pt.get("tag") or {})
            tc = pt.get("tag_code") or nested.get("tag_code")
            print(f"    tag_code={repr(tc)}  confidence_score={pt.get('confidence_score')}  "
                  f"in user_state={tc in user_interest_state if tc else 'N/A'}")
        score, matched = calculate_tag_match(user_interest_state, ptags, weight_field, id_tag_map)
        print(f"  → tag_match score: {score}")
        print(f"  → matched_tags: {matched[:3]}")
    else:
        print("  No ranked places to test.")

    # ══════════════════════════════════════════════════════════════════════════

    # ── [CF Blending] ─────────────────────────────────────────────────────────
    banner("CF Blending")
    cf_scores = fetch_cf_scores_for_user(supabase, user_id, place_ids)
    alpha = _compute_alpha(cf_scores, len(filtered_places))
    coverage = round(len(cf_scores) / max(len(filtered_places), 1), 4)

    for place in ranked:
        tag_match = float(place.get("tag_match") or 0.0)
        cf = cf_scores.get(str(place["id_place"]), 0.0)
        place["cf_score"]    = round(cf, 6)
        place["alpha_used"]  = alpha
        place["final_score"] = round(alpha * tag_match + (1 - alpha) * cf, 6)
    ranked.sort(key=lambda p: -p["final_score"])

    print(f"CF scores found  : {len(cf_scores)}")
    print(f"CF coverage      : {coverage:.1%}")
    print(f"Alpha (CB weight): {alpha}")
    if ranked:
        top3 = [{"name": p.get("name"), "final_score": p.get("final_score")} for p in ranked[:3]]
        print(f"Top 3 by final_score: {json.dumps(top3, ensure_ascii=False)}")

    # ── [Diversity] ───────────────────────────────────────────────────────────
    banner("Diversity")
    onboarding_choices = fetch_user_onboarding_choices(supabase, user_id)
    user_selected_interests = [c["option_code"] for c in onboarding_choices if c.get("option_code")]
    diversity_result = apply_diversity_selection(ranked, n_days, user_selected_interests)
    top_places = diversity_result["diversified_top_k"]
    div_summary = diversity_result.get("summary", {})

    print(f"User interests   : {user_selected_interests}")
    print(f"Profile          : {diversity_result.get('config', {}).get('profile')}")
    print(f"Diversified top_k: {len(top_places)}")
    print(f"Overflow pool    : {len(diversity_result.get('overflow_pool', []))}")
    print(f"Coverage after   : {div_summary.get('coverage_after', {})}")

    # ── [Module 2 – Greedy Repair] ────────────────────────────────────────────
    banner("Module 2 – Greedy Repair")
    pace_level = (user_profile or {}).get("pace_level")
    m2_result = build_module2_result(
        top_places,
        start_date=str(start_at),
        end_date=str(end_date),
        pace_level=pace_level,
    )
    m2_summary = m2_result.get("summary", {})
    repair_logs = m2_result.get("repair_logs", [])

    print(f"Pace level       : {pace_level or 'balanced (default)'}")
    print(f"Day clusters     : {len(m2_result['day_clusters'])}")
    print(f"Selected main    : {m2_summary.get('selected_main_place_count')}")
    print(f"Backup           : {m2_summary.get('backup_place_count')}")
    print(f"Optional         : {m2_summary.get('optional_place_count')}")
    print(f"Repair actions   : {len(repair_logs)}")
    for dc in m2_result["day_clusters"]:
        warns = f"  WARN: {dc['warnings']}" if dc.get("warnings") else ""
        print(f"  Day {dc['day']} ({dc['date']}): {dc['place_count']} places, "
              f"{dc['total_duration_minutes']} min{warns}")

    # ── [Module 3 – full pipeline via TripPlannerService] ─────────────────────
    banner("Module 3 + Final JSON (via TripPlannerService)")
    svc = TripPlannerService(supabase)
    result = await svc.plan(
        id_user=user_id,
        id_province=province_id,
        n_days=n_days,
        start_at=start_at,
        sa_runs=3,
        save=False,   # don't persist during smoke test
    )

    elapsed = time.perf_counter() - t0

    print(f"\nid_plan (not saved): {result.get('id_plan')}")
    print(f"Days in result   : {len(result.get('days', []))}")
    for day in result.get("days", []):
        places_preview = [p.get("name") for p in day.get("places", [])]
        print(f"  Day {day['day']} ({day['date']}): {places_preview}")

    print(f"\nDebug info:")
    print(pretty(result.get("debug", {})))
    print(f"\nTotal elapsed: {elapsed:.2f}s")
    print("\nSmoke test PASSED.")


def main():
    user_id, province_id, n_days, start_date = parse_args()
    asyncio.run(run_smoke_test(user_id, province_id, n_days, start_date))


if __name__ == "__main__":
    main()
