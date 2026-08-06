"""
test_module3_scheduling_rules.py
Qualitative evidence for schedule_builder.py's constraint-handling rules —
capstone report section 4.4.3 ("Minh chung kha nang xu ly rang buoc"),
same style as the earlier A/B opening-hour test (cost 45.0 vs 123.0).

No DB required — every place is a synthetic dict with just the fields
build_day_schedule()/route_cost_with_schedule() actually read:
  latitude, longitude, timespan (open "HH:MM"), timeclose (close "HH:MM"),
  estimated_duration_minutes.

Mechanisms under test (function names match schedule_builder.py exactly):
  1-5. Lunch break — now a SOFT constraint minimising deviation from
       [12:00, 13:30), not a hard block. At the step where a break becomes
       necessary, two candidate insertion points are evaluated — Option A
       (right after the current activity, before travel) and Option B
       (right before the next activity, after travel+buffer) — and whichever
       has lower deviation is chosen (ties -> Option A). See schedule_builder.py
       module docstring for the exact formula.
  3.   Closing-time violation — place kept in the itinerary (not dropped),
       cost +1000 exactly, warning recorded. (unchanged)
  4. Day-end cutoff (visitEnd > 20:00):
     4a. One place mid-route drops; the NEXT place's simulation must resume
         from the last actually-committed predecessor's state (time,
         position), not from the dropped place's (discarded) attempt.
         (unchanged)
     4b. ALL places drop -> fallback keeps exactly the first place, with a
         warning, instead of returning an empty day. (fixture duration
         increased from the old hard-block design — see inline comment)

Each check prints (test_case, input, expected, actual, PASS/FAIL) and the
script exits non-zero if any check fails.

Usage:
    python test_module3_scheduling_rules.py
"""

import math
import sys

from services.schedule_builder import (
    build_day_schedule,
    route_cost_with_schedule,
    _lunch_deviation_minutes,
)
from services.module3_optimizer import optimize_day_route

EARTH_RADIUS_KM = 6371.0
BASE_LAT, BASE_LON = 10.7769, 106.7009  # arbitrary anchor (Ho Chi Minh city center)


def _offset_lat(base_lat: float, distance_km: float) -> float:
    """Exact: for a pure-latitude (meridian) offset, haversine distance ==
    EARTH_RADIUS_KM * delta_lat_radians exactly (no small-angle approximation
    needed) — this is what lets the fixtures below hit exact travel-minute
    targets instead of relying on rounding luck."""
    return base_lat + math.degrees(distance_km / EARTH_RADIUS_KM)


def make_place(name: str, lat: float, lon: float, open_time: str | None,
               close_time: str | None, duration_minutes: int) -> dict:
    return {
        "id_place": name,
        "name": name,
        "latitude": lat,
        "longitude": lon,
        "timespan": open_time,
        "timeclose": close_time,
        "estimated_duration_minutes": duration_minutes,
    }


START_POINT = {"latitude": BASE_LAT, "longitude": BASE_LON}

results: list[dict] = []


def _record(test_case: str, input_desc: str, expected: str, actual: str, passed: bool) -> None:
    results.append({
        "test_case": test_case, "input": input_desc,
        "expected": expected, "actual": actual,
        "pass_fail": "PASS" if passed else "FAIL",
    })


# ── Test 1: deviation = 0 when the break lands entirely inside the window ──
def test_1_deviation_zero_when_fits() -> None:
    # A: idx0, opens 08:00, duration=210min -> ends 11:30 (before noon, no
    # trigger at A itself: 08:00+210=11:30 <= 12:00).
    a = make_place("A", BASE_LAT, BASE_LON, "08:00", "23:00", 210)
    # B: 7.5km away -> travel = round(7.5/30*60) = 15min exactly. From A's
    # 11:30: +15min travel +15min buffer (default) = 12:00 exactly ->
    # Option B start = 12:00 -> deviation(12:00) = 0 (break fits [12:00,13:30)
    # exactly). Option A start = 11:30 -> deviation(11:30) = 30. 0 < 30, so
    # Option B is chosen.
    b_lat = _offset_lat(BASE_LAT, 7.5)
    b = make_place("B", b_lat, BASE_LON, "08:00", "23:00", 60)

    result = build_day_schedule([a, b], start_point=START_POINT)
    schedule = result["schedule"]

    a_entry = next(e for e in schedule if e.get("id_place") == "A")
    lunch_entry = next(e for e in schedule if e.get("type") == "lunch_break")
    b_entry = next(e for e in schedule if e.get("id_place") == "B")

    actual = (f"A.end_time={a_entry['end_time']}, lunch=[{lunch_entry['start_time']}"
              f"-{lunch_entry['end_time']}] dev={lunch_entry['deviation_minutes']}, "
              f"B.start_time={b_entry['start_time']}, "
              f"total_deviation={result['lunch_deviation_minutes']}")
    expected = "A.end_time=11:30, lunch=[12:00-13:30] dev=0, B.start_time=13:30, total_deviation=0"
    passed = (
        a_entry["end_time"] == "11:30"
        and lunch_entry["start_time"] == "12:00"
        and lunch_entry["end_time"] == "13:30"
        and lunch_entry["deviation_minutes"] == 0
        and b_entry["start_time"] == "13:30"
        and result["lunch_deviation_minutes"] == 0
    )
    _record(
        "1. Lunch deviation — zero when break fits the window exactly",
        "A ends 11:30; travel(15min,7.5km)+buffer(15min) -> Option B arrival exactly 12:00",
        expected, actual, passed,
    )


# ── Test 2: engine picks whichever option (A or B) has lower deviation ─────
def test_2_deviation_picks_lower_option() -> None:
    # A: idx0, opens 08:00, duration=120min -> ends 10:00.
    a = make_place("A", BASE_LAT, BASE_LON, "08:00", "23:00", 120)
    # B: 75km away -> travel = round(75/30*60) = 150min. From A's 10:00:
    # Option A start = 10:00 (before travel) -> deviation(10:00) = 720-600 = 120.
    # Option B start = 10:00+150min travel+15min buffer = 12:45 ->
    # deviation(12:45) = max(0,(765+90)-(810)) = 45. 45 < 120 -> Option B wins.
    b_lat = _offset_lat(BASE_LAT, 75)
    b = make_place("B", b_lat, BASE_LON, "08:00", "23:00", 60)

    # Directly verify the two candidate deviations with the real helper
    # (same one the engine uses internally) before checking engine output.
    import datetime
    dev_a = _lunch_deviation_minutes(datetime.time(10, 0), datetime.time(12, 0), 90)
    dev_b = _lunch_deviation_minutes(datetime.time(12, 45), datetime.time(12, 0), 90)

    result = build_day_schedule([a, b], start_point=START_POINT)
    schedule = result["schedule"]
    lunch_entry = next(e for e in schedule if e.get("type") == "lunch_break")

    actual = (f"dev_a={dev_a}, dev_b={dev_b}, chosen_start={lunch_entry['start_time']}, "
              f"chosen_dev={lunch_entry['deviation_minutes']}")
    expected = "dev_a=120, dev_b=45, chosen_start=12:45 (Option B, lower deviation), chosen_dev=45"
    passed = (
        dev_a == 120
        and dev_b == 45
        and lunch_entry["start_time"] == "12:45"
        and lunch_entry["deviation_minutes"] == 45
    )
    _record(
        "2. Lunch deviation — engine picks the lower-deviation option (A vs B)",
        "Option A (10:00) deviation=120 vs Option B (12:45) deviation=45 -> B should win",
        expected, actual, passed,
    )


# ── Test 3: cost delta == 3 x (deviation2 - deviation1), all else equal ────
def test_3_deviation_cost_contribution() -> None:
    # Two routes, same A->B pair (so travel/lunch_cost/violations/drops are
    # IDENTICAL) differing only in A's duration, which shifts B's arrival
    # time and therefore the chosen deviation. Isolates the deviation
    # penalty exactly, same isolation technique as the closing-violation
    # test below.
    #
    # B's own duration must be long enough to actually trigger the lunch
    # check on its own step (naive_visit_start + duration > 12:00) — kept
    # identical (200min) across both variants so it never affects cost
    # itself, only the trigger firing.
    #
    # Variant 1: A duration=60 (08:00-09:00). B same location as A (travel=0),
    # buffer=15 -> Option B start = 09:15 -> deviation(09:15) = 720-555 = 165
    # (Option A=09:00 -> deviation=180; B wins with 165).
    a1 = make_place("A", BASE_LAT, BASE_LON, "08:00", "23:00", 60)
    b1 = make_place("B", BASE_LAT, BASE_LON, "08:00", "23:00", 200)

    # Variant 2: A duration=200 (08:00-11:20). Option B start = 11:35 ->
    # deviation(11:35) = 720-695 = 25 (Option A=11:20 -> deviation=40; B wins
    # with 25).
    a2 = make_place("A", BASE_LAT, BASE_LON, "08:00", "23:00", 200)
    b2 = make_place("B", BASE_LAT, BASE_LON, "08:00", "23:00", 200)

    cost1 = route_cost_with_schedule([a1, b1], START_POINT)
    cost2 = route_cost_with_schedule([a2, b2], START_POINT)
    delta = cost1 - cost2

    expected_delta = 3 * (165 - 25)  # LUNCH_DEVIATION_PENALTY_PER_MIN=3
    actual = f"cost1={cost1}, cost2={cost2}, delta={delta}, expected_delta={expected_delta}"
    expected = f"delta == {expected_delta} (only lunch_deviation differs between variants)"
    passed = delta == expected_delta
    _record(
        "3. Lunch deviation — cost contribution isolated (delta == 3 x Ddeviation)",
        "Same A->B pair; only A's duration changes (60min vs 200min), shifting B's deviation from 165 to 25",
        expected, actual, passed,
    )


# ── Test 4: at most one lunch break per day still holds (soft mechanism) ───
def test_4_at_most_one_lunch_still_holds() -> None:
    # A: idx0, 08:00-09:00 (no trigger).
    a = make_place("A", BASE_LAT, BASE_LON, "08:00", "23:00", 60)
    # B: same location, buffer=15 -> Option B start=09:15, duration=300min ->
    # naive check (09:15+300=615min from start... in absolute mins: 555+300=
    # 855 > 720) triggers the ONLY lunch break of the day. Ends up starting
    # its visit at 10:45 (see test 2/3 math), duration 300 -> ends 15:45.
    b = make_place("B", BASE_LAT, BASE_LON, "08:00", "23:00", 300)
    # C: same location, right after B (15:45) -> had_lunch is already True,
    # so no second break may be inserted even though C's own arrival is
    # nowhere near noon (irrelevant — guard fires purely on had_lunch).
    c = make_place("C", BASE_LAT, BASE_LON, "08:00", "23:00", 30)

    result = build_day_schedule([a, b, c], start_point=START_POINT)
    schedule = result["schedule"]
    lunch_entries = [e for e in schedule if e.get("type") == "lunch_break"]
    c_entry = next(e for e in schedule if e.get("id_place") == "C")

    actual = f"lunch_count={len(lunch_entries)}, C.dropped={c_entry['dropped']}"
    expected = "lunch_count=1, C.dropped=False"
    passed = len(lunch_entries) == 1 and c_entry["dropped"] is False
    _record(
        "4. At most one lunch break per day (soft mechanism, guard unchanged)",
        "A (no trigger), B (triggers the only break), C (had_lunch=True already, must not trigger a 2nd)",
        expected, actual, passed,
    )


# ── Test 5: SA prefers the route ordering with lower total deviation ───────
def test_5_sa_prefers_low_deviation_when_travel_equal() -> None:
    # P and Q sit on the same meridian as S, at 40km and 10km respectively ->
    # greedy nearest-neighbour picks Q first (nearer to S), giving the WORSE
    # ordering [Q, P] as the initial route — SA must flip it via a swap move
    # to reach the better ordering [P, Q].
    #
    # Travel cost is IDENTICAL for both orderings: a 2-place route only has
    # one edge (P<->Q, 30km -> 60min); idx==0's own leg from the start point
    # is never charged (see schedule_builder.py's "idx > 0 only" travel
    # rule). So the only thing that can differentiate cost([P,Q]) from
    # cost([Q,P]) is lunch deviation.
    p_lat = _offset_lat(BASE_LAT, 40)
    q_lat = _offset_lat(BASE_LAT, 10)
    p = make_place("P", p_lat, BASE_LON, "08:00", "23:00", 180)
    q = make_place("Q", q_lat, BASE_LON, "08:00", "23:00", 100)

    # Hand-computed costs for both fixed orderings (see module comments):
    #   [P, Q]: P ends 11:00; travel(60)+buffer(15) -> Option B=12:15,
    #           deviation=15 -> cost = 60(travel)+90(lunch_cost)+15*3 = 195
    #   [Q, P]: Q ends 09:40; travel(60)+buffer(15) -> Option B=10:55,
    #           deviation=65 -> cost = 60(travel)+90(lunch_cost)+65*3 = 345
    cost_pq = route_cost_with_schedule([p, q], START_POINT)
    cost_qp = route_cost_with_schedule([q, p], START_POINT)

    best_route, schedule_result = optimize_day_route(START_POINT, [p, q])
    best_order = [pl["id_place"] for pl in best_route]

    actual = (f"cost([P,Q])={cost_pq}, cost([Q,P])={cost_qp}, "
              f"SA best_order={best_order}, "
              f"final_deviation={schedule_result['lunch_deviation_minutes']}")
    expected = "cost([P,Q])=195, cost([Q,P])=345, SA best_order=['P', 'Q'], final_deviation=15"
    passed = (
        cost_pq == 195
        and cost_qp == 345
        and best_order == ["P", "Q"]
        and schedule_result["lunch_deviation_minutes"] == 15
    )
    _record(
        "5. Simulated Annealing prefers the lower-deviation ordering",
        "Greedy naively picks [Q,P] (Q nearer to start); SA must swap to [P,Q] (lower deviation) since travel cost ties",
        expected, actual, passed,
    )


# ── Test 6: closing-time violation (kept, +1000 cost, warning) — unchanged ─
def test_6_closing_violation() -> None:
    # Opens 08:00, closes 10:00, but duration (150min) pushes visit_end to
    # 10:30 -> violates timeclose.
    a_violating = make_place("A", BASE_LAT, BASE_LON, "08:00", "10:00", 150)
    # Same place, but with a late close time -> no violation, isolates the
    # +1000 penalty (every other cost component is identical: same route,
    # same start, same duration, so travel/wait/lunch_cost cancel out).
    a_clean = make_place("A", BASE_LAT, BASE_LON, "08:00", "23:00", 150)

    schedule_result = build_day_schedule([dict(a_violating)], start_point=START_POINT)
    a_entry = schedule_result["schedule"][0]

    cost_violating = route_cost_with_schedule([a_violating], START_POINT)
    cost_clean = route_cost_with_schedule([a_clean], START_POINT)
    delta = cost_violating - cost_clean

    actual = (f"dropped={a_entry['dropped']}, warning={a_entry['warning']!r}, "
              f"cost_delta={delta}")
    expected = "dropped=False, warning='May close at 10:00 before visit ends', cost_delta=1000"
    passed = (
        a_entry["dropped"] is False
        and a_entry["warning"] == "May close at 10:00 before visit ends"
        and delta == 1000
        and schedule_result["violation_count"] == 1
    )
    _record(
        "6. Closing-time violation (visitEnd > closeTime)",
        "opens 08:00, closes 10:00, duration=150min -> visit_end=10:30 (30min past close)",
        expected, actual, passed,
    )


# ── Test 7: mid-route drop, next place resumes from last committed state ───
def test_7_drop_mid_route_state_carryover() -> None:
    # A: idx0, ends 09:00 (duration=60min from 08:00) — deliberately BEFORE
    # noon so the lunch mechanism (tests 1-5) cannot confound this test:
    # idx==0 never triggers lunch here since 08:00+60=09:00 is nowhere near
    # noon, keeping had_lunch False when A commits and isolating pure
    # travel/position carryover as the only thing under test.
    a = make_place("A", BASE_LAT, BASE_LON, "08:00", "23:00", 60)
    # B: 200km from A -> travel=400min. From A's 09:00: +400min travel +15min
    # buffer (default) = 09:00+415min = 15:55 -> lunch triggers here too
    # (naive check: 955min+300min duration > 720), but B still ends up
    # dropped regardless (see below) because even after a 90-min break the
    # projected end blows past day_end. Numbers are chosen to land strictly
    # between 20:00 and 24:00 (not wrap past midnight) — see the wraparound
    # caveat in _add()'s docstring.
    b_lat = _offset_lat(BASE_LAT, 200)
    b = make_place("B", b_lat, BASE_LON, "08:00", "23:00", 300)
    # C: only 5km from A (travel=10min). If C's simulation correctly resumes
    # from A (09:00, A's location) rather than from B's discarded attempt:
    #   09:00 + 10min travel + 15min buffer = 09:25 arrival, +60min visit
    #   -> visit_end = 10:25, well under 20:00 -> NOT dropped. Also confirms
    #   C is the one that ends up carrying the day's only lunch break instead
    #   of B, since B's attempt (including its own lunch trigger) is fully
    #   discarded on drop.
    c_lat = _offset_lat(BASE_LAT, 5)
    c = make_place("C", c_lat, BASE_LON, "08:00", "23:00", 60)

    result = build_day_schedule([a, b, c], start_point=START_POINT)
    schedule = result["schedule"]
    a_entry = next(e for e in schedule if e.get("id_place") == "A")
    b_entry = next(e for e in schedule if e.get("id_place") == "B")
    c_entry = next(e for e in schedule if e.get("id_place") == "C")

    actual = (f"A.dropped={a_entry['dropped']}, end={a_entry.get('end_time')}; "
              f"B.dropped={b_entry['dropped']}; "
              f"C.dropped={c_entry['dropped']}, start={c_entry.get('start_time')}, "
              f"end={c_entry.get('end_time')}")
    expected = "A kept (end=09:00); B dropped; C kept (start=09:25, end=10:25) — proves C resumed from A, not from B's discarded attempt"
    passed = (
        a_entry["dropped"] is False and a_entry["end_time"] == "09:00"
        and b_entry["dropped"] is True
        and c_entry["dropped"] is False
        and c_entry["start_time"] == "09:25"
        and c_entry["end_time"] == "10:25"
    )
    _record(
        "7. Mid-route drop — state carryover to next place",
        "A ends 09:00; B is 200km away (forces drop); C is only 5km from A, duration=60min",
        expected, actual, passed,
    )


# ── Test 8: all places drop -> fallback keeps the first ────────────────────
def test_8_all_drop_fallback() -> None:
    # duration=700min (not 500min as under the old hard-block design): the
    # old mechanism stretched the lunch break to fill however long it took
    # to reach 13:30 (e.g. 08:00 -> 13:30 = 330min in the old test), which
    # is exactly the hard-block behaviour this redesign removes. The new
    # break is always a fixed 90 minutes, so a shorter forced delay
    # (08:00-09:30) means a much larger duration is needed to still push
    # every place's visit past day_end=20:00.
    #
    # Every place is independently simulated from day_start=08:00 (a drop at
    # idx0 never advances current/prev, so idx1/idx2 are ALSO simulated
    # fresh from 08:00). At idx0, Option A == Option B == 08:00 (no prior
    # travel leg), deviation(08:00)=240 either way -> lunch=08:00-09:30,
    # visit starts 09:30, ends 09:30+700min=21:10, past 20:00 for all three.
    # (duration kept < 870min so 09:30+duration stays under 24:00 and does
    # not wrap past midnight — see _add()'s docstring.)
    a = make_place("A", BASE_LAT, BASE_LON, "08:00", "23:00", 700)
    b = make_place("B", BASE_LAT, BASE_LON, "08:00", "23:00", 700)
    c = make_place("C", BASE_LAT, BASE_LON, "08:00", "23:00", 700)

    result = build_day_schedule([a, b, c], start_point=START_POINT)
    schedule = [e for e in result["schedule"] if e.get("type") == "place"]
    kept = [e for e in schedule if not e["dropped"]]

    actual = (f"kept={[e['id_place'] for e in kept]}, "
              f"dropped_count={result['dropped_count']}, "
              f"warning={kept[0]['warning'] if kept else None!r}")
    expected = "kept=['A'], dropped_count=2, warning='Kept despite exceeding day_end — no other places fit the schedule'"
    passed = (
        len(kept) == 1
        and kept[0]["id_place"] == "A"
        and result["dropped_count"] == 2
        and kept[0]["warning"] == "Kept despite exceeding day_end — no other places fit the schedule"
    )
    _record(
        "8. All places drop — fallback keeps first",
        "A, B, C all duration=700min; break (fixed 90min, 08:00-09:30) delays start to 09:30 -> 09:30+700min=21:10, past day_end=20:00 for all three",
        expected, actual, passed,
    )


def print_report() -> bool:
    all_passed = True
    col_widths = {"test_case": 55, "input": 65, "expected": 70, "actual": 70, "pass_fail": 6}
    header = " | ".join(k.ljust(w) for k, w in col_widths.items())
    print(header)
    print("-" * len(header))
    for row in results:
        line = " | ".join(str(row[k]).ljust(w) for k, w in col_widths.items())
        print(line)
        if row["pass_fail"] == "FAIL":
            all_passed = False
    return all_passed


if __name__ == "__main__":
    test_1_deviation_zero_when_fits()
    test_2_deviation_picks_lower_option()
    test_3_deviation_cost_contribution()
    test_4_at_most_one_lunch_still_holds()
    test_5_sa_prefers_low_deviation_when_travel_equal()
    test_6_closing_violation()
    test_7_drop_mid_route_state_carryover()
    test_8_all_drop_fallback()

    ok = print_report()
    print(f"\n{'ALL PASSED' if ok else 'SOME FAILED'} ({sum(1 for r in results if r['pass_fail'] == 'PASS')}/{len(results)})")
    sys.exit(0 if ok else 1)
