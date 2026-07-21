"""
test_module2_rejection_eval.py
Module 2 candidate validation evaluation (M2-01, per
evaluation_module1_module2.md) — RejectionAccuracy for the 6 input classes
specified: valid / missing coords / out-of-range coords / not
itinerary-eligible / missing module1_score-but-has-tag_match / missing both.

No DB required — every candidate is a synthetic dict. Calls
prepare_module2_candidates() directly (services/module2_algorithm.py), NOT
the full build_module2_result() — this is the exact validate/reject
boundary under test (K-Means/Greedy Repair are irrelevant to M2-01 and
would just add noise/instability on a 6-item synthetic set), matching the
task's explicit "hàm validate/normalize cấp thấp hơn" allowance.

AUDIT FINDINGS (confirmed by reading services/module2_algorithm.py before
writing this script — reported here, NOT silently patched in production
code):

  1. module2_rejection_reason IS a real field, set for the two checks that
     actually exist: "invalid_coordinate" and "missing_module1_score". Not
     a silent-drop gap.

  2. Coordinate range validation EXISTS: is_valid_coordinate() checks both
     castability (float(lat)/float(lon)) AND range (-90<=lat<=90,
     -180<=lon<=180). lat=200 is correctly rejected as invalid_coordinate.
     (No gap here, contrary to what might be assumed without reading the
     code.)

  3. is_itinerary_eligible is NOT re-checked by Module 2 at all.
     normalize_module2_place() computes/stores an is_itinerary_eligible
     field (from place["place_subcategory"]["is_itinerary_eligible"], or a
     top-level place["is_itinerary_eligible"] fallback), but
     prepare_module2_candidates()'s reject loop never reads it. A place
     with is_itinerary_eligible=False that somehow reaches Module 2 is KEPT,
     not rejected — Module 2 fully trusts the upstream required_filter query
     (which already filters `place_subcategory.is_itinerary_eligible = True`
     at the DB level) and does not add a redundant re-check. This script
     confirms that behavior; it does not add the missing re-check.

  4. CONFIRMED SPEC GAP: normalize_module2_place() sets
     `np["module1_score"] = float(place.get("module1_score") or
     place.get("tag_match") or 0.0)` — this ALWAYS produces a float (0.0 at
     minimum), so `np.get("module1_score") is None` in
     prepare_module2_candidates() can NEVER be true. A place missing BOTH
     module1_score AND tag_match is therefore NOT rejected as the spec
     requires — it is silently kept with module1_score=0.0. This script
     demonstrates and reports this gap; it does NOT patch
     module2_algorithm.py to work around it.

Usage:
    python test_module2_rejection_eval.py
"""

from services.module2_algorithm import prepare_module2_candidates

TOTAL_DAYS = 1
PACE_LEVEL = "balanced"  # candidate_limit = 1 * CANDIDATE_PER_DAY(8) = 8, > our 6 test cases

results: list[dict] = []


def _place(
    id_place: str,
    latitude,
    longitude,
    module1_score=None,
    tag_match=None,
    is_itinerary_eligible: bool = True,
    estimated_duration_minutes: int = 90,
) -> dict:
    place = {
        "id_place": id_place,
        "name": id_place,
        "latitude": latitude,
        "longitude": longitude,
        "estimated_duration_minutes": estimated_duration_minutes,
        "average_rating": 4.5,
        "review_count": 10,
        "place_subcategory": {
            "name": "Test subcategory",
            "place_category": "Test category",
            "is_itinerary_eligible": is_itinerary_eligible,
        },
    }
    if module1_score is not None:
        place["module1_score"] = module1_score
    if tag_match is not None:
        place["tag_match"] = tag_match
    return place


def _record(test_case: str, input_summary: str, expected: str, actual: str, passed: bool) -> None:
    results.append({
        "test_case": test_case, "input_summary": input_summary,
        "expected": expected, "actual": actual,
        "pass_fail": "PASS" if passed else "FAIL",
    })


def _outcome(id_place: str, valid: list[dict], rejected: list[dict]) -> tuple[bool, str | None]:
    """Returns (kept, rejection_reason_or_None)."""
    for p in valid:
        if p["id_place"] == id_place:
            return True, None
    for p in rejected:
        if p["id_place"] == id_place:
            return False, p.get("module2_rejection_reason")
    raise AssertionError(f"{id_place} not found in either valid or rejected — should be impossible")


def run_all() -> None:
    candidates = [
        _place("C1_valid", 10.7769, 106.7009, module1_score=0.8),
        _place("C2_missing_coords", None, None, module1_score=0.8),
        _place("C3_out_of_range_lat", 200.0, 106.7009, module1_score=0.8),
        _place("C4_not_itinerary_eligible", 10.7769, 106.7009, module1_score=0.8, is_itinerary_eligible=False),
        _place("C5_missing_score_has_tag_match", 10.7769, 106.7009, module1_score=None, tag_match=0.55),
        _place("C6_missing_both_score_and_tag_match", 10.7769, 106.7009, module1_score=None, tag_match=None),
    ]

    valid, rejected, _limits = prepare_module2_candidates(candidates, TOTAL_DAYS, PACE_LEVEL)

    # ── 1. Valid coordinates, all fields present — must be kept ──────────────
    kept, reason = _outcome("C1_valid", valid, rejected)
    _record(
        "1. Valid candidate (complete fields)",
        "lat=10.7769, lon=106.7009, module1_score=0.8, itinerary_eligible=True",
        "kept=True, reason=None",
        f"kept={kept}, reason={reason}",
        kept is True and reason is None,
    )

    # ── 2. Missing coordinates — must be rejected as invalid_coordinate ──────
    kept, reason = _outcome("C2_missing_coords", valid, rejected)
    _record(
        "2. Missing coordinates (lat/lon=None)",
        "lat=None, lon=None, module1_score=0.8",
        "kept=False, reason='invalid_coordinate'",
        f"kept={kept}, reason={reason}",
        kept is False and reason == "invalid_coordinate",
    )

    # ── 3. Out-of-range coordinates — must be rejected as invalid_coordinate ─
    kept, reason = _outcome("C3_out_of_range_lat", valid, rejected)
    _record(
        "3. Out-of-range coordinate (lat=200)",
        "lat=200.0 (outside [-90,90]), lon=106.7009, module1_score=0.8",
        "kept=False, reason='invalid_coordinate' (range check DOES exist in is_valid_coordinate())",
        f"kept={kept}, reason={reason}",
        kept is False and reason == "invalid_coordinate",
    )

    # ── 4. Not itinerary-eligible — Module 2 does NOT re-check this ──────────
    kept, reason = _outcome("C4_not_itinerary_eligible", valid, rejected)
    _record(
        "4. is_itinerary_eligible=False",
        "lat/lon valid, module1_score=0.8, place_subcategory.is_itinerary_eligible=False",
        "kept=True, reason=None (Module 2 relies entirely on the upstream "
        "required_filter query for this — it does NOT re-validate here; "
        "confirmed behavior, not a bug being newly reported)",
        f"kept={kept}, reason={reason}",
        kept is True and reason is None,
    )

    # ── 5. Missing module1_score, has tag_match — must fall back to tag_match
    kept, reason = _outcome("C5_missing_score_has_tag_match", valid, rejected)
    kept_place = next((p for p in valid if p["id_place"] == "C5_missing_score_has_tag_match"), None)
    fallback_score = kept_place["module1_score"] if kept_place else None
    _record(
        "5. Missing module1_score, has tag_match=0.55",
        "module1_score=None, tag_match=0.55",
        "kept=True, module1_score falls back to tag_match=0.55",
        f"kept={kept}, reason={reason}, module1_score={fallback_score}",
        kept is True and reason is None and fallback_score == 0.55,
    )

    # ── 6. Missing BOTH — spec says reject; CONFIRMED GAP: code keeps it ─────
    kept, reason = _outcome("C6_missing_both_score_and_tag_match", valid, rejected)
    kept_place = next((p for p in valid if p["id_place"] == "C6_missing_both_score_and_tag_match"), None)
    actual_score = kept_place["module1_score"] if kept_place else None
    spec_expected_kept = False  # per M2-01 spec: should be rejected
    _record(
        "6. Missing BOTH module1_score and tag_match",
        "module1_score=None, tag_match=None",
        "SPEC: kept=False (rejected, missing score entirely)",
        f"ACTUAL (confirmed code gap): kept={kept}, reason={reason}, "
        f"module1_score={actual_score} (defaulted to 0.0 by the `or 0.0` "
        f"fallback in normalize_module2_place(), so the `is None` reject "
        f"check in prepare_module2_candidates() can never fire)",
        kept == spec_expected_kept,  # intentionally checked against the SPEC, so this FAILS — documenting the real gap
    )


def print_report() -> None:
    col_widths = {"test_case": 42, "input_summary": 60, "expected": 60, "actual": 75, "pass_fail": 6}
    header = " | ".join(k.ljust(w) for k, w in col_widths.items())
    print(header)
    print("-" * len(header))
    for row in results:
        line = " | ".join(str(row[k]).ljust(w) for k, w in col_widths.items())
        print(line)

    n_correct = sum(1 for r in results if r["pass_fail"] == "PASS")
    total = len(results)
    rejection_accuracy = round(100 * n_correct / total, 1)
    print(f"\nRejectionAccuracy = {n_correct}/{total} = {rejection_accuracy}%")
    if n_correct < total:
        print(
            "\nNOTE: test case 6 is EXPECTED to show as a mismatch against the "
            "M2-01 spec ('missing both -> reject') — this is the confirmed real "
            "gap in normalize_module2_place()'s `or 0.0` fallback (see module "
            "docstring, finding #4), reported here rather than silently patched "
            "in production code."
        )


if __name__ == "__main__":
    run_all()
    print_report()
