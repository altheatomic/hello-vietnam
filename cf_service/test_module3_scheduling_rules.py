"""
test_module3_scheduling_rules.py
Qualitative evidence for schedule_builder.py's constraint-handling rules —
capstone report section 4.4.3 ("Minh chung kha nang xu ly rang buoc"),
same style as the earlier A/B opening-hour test (cost 45.0 vs 123.0).

No DB required — every place is a synthetic dict with just the fields
build_day_schedule()/route_cost_with_schedule() actually read:
  latitude, longitude, timespan (open "HH:MM"), timeclose (close "HH:MM"),
  estimated_duration_minutes.

4 mechanisms under test (function names match schedule_builder.py exactly):
  1. Lunch break, case 1 — previous place ends AFTER 12:00 (noon-check #1,
     fires before travel/buffer).
  2. Lunch break, case 2 — previous place ends BEFORE 12:00, but travel+
     buffer push arrival INTO the lunch window (noon-check #2, the fix for
     the previously-known edge case) — must NOT double-count a fresh 90-min
     break, only finish out the window (fixed end at lunch_start+lunch_dur).
  3. Closing-time violation — place kept in the itinerary (not dropped),
     cost +1000 exactly, warning recorded.
  4. Day-end cutoff (visitEnd > 20:00):
     4a. One place mid-route drops; the NEXT place's simulation must resume
         from the last actually-committed predecessor's state (time,
         position), not from the dropped place's (discarded) attempt.
     4b. ALL places drop -> fallback keeps exactly the first place, with a
         warning, instead of returning an empty day.

Each check prints (test_case, input, expected, actual, PASS/FAIL) and the
script exits non-zero if any check fails.

Usage:
    python test_module3_scheduling_rules.py
"""

import math
import sys

from services.schedule_builder import build_day_schedule, route_cost_with_schedule

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


# ── Test 1: lunch break, case 1 (previous place ends AFTER 12:00) ───────────
def test_1_lunch_case1() -> None:
    # A: idx0, opens 08:00, ends 12:15 (duration=255 min from day_start 08:00).
    a = make_place("A", BASE_LAT, BASE_LON, "08:00", "23:00", 255)
    # B: same location as A (travel=0), so with buffer forced to 0 the only
    # time between A.end and B.start is the lunch break itself.
    b = make_place("B", BASE_LAT, BASE_LON, "08:00", "23:00", 60)

    result = build_day_schedule([a, b], start_point=START_POINT, buffer_minutes=0)
    schedule = result["schedule"]

    a_entry = next(e for e in schedule if e.get("id_place") == "A")
    lunch_entry = next(e for e in schedule if e.get("type") == "lunch_break")
    b_entry = next(e for e in schedule if e.get("id_place") == "B")

    actual = (f"A.end_time={a_entry['end_time']}, lunch=[{lunch_entry['start_time']}"
              f"-{lunch_entry['end_time']}], B.start_time={b_entry['start_time']}")
    expected = "A.end_time=12:15, lunch=[12:15-13:45], B.start_time=13:45"
    passed = (
        a_entry["end_time"] == "12:15"
        and lunch_entry["start_time"] == "12:15"
        and lunch_entry["end_time"] == "13:45"
        and b_entry["start_time"] == "13:45"
    )
    _record(
        "1. Lunch break — case 1 (prev ends after 12:00)",
        "A ends 12:15 (duration=255min from 08:00); buffer forced to 0 to isolate lunch mechanism",
        expected, actual, passed,
    )


# ── Test 2: lunch break, case 2 (travel pushes arrival into the window) ─────
def test_2_lunch_case2() -> None:
    # A: idx0, opens 08:00, ends 11:50 (duration=230 min from 08:00) — BEFORE
    # noon, so noon-check #1 does not fire.
    a = make_place("A", BASE_LAT, BASE_LON, "08:00", "23:00", 230)
    # B: exactly 27.5km away -> travel = round(27.5/30*60) = 55 min exactly.
    # 11:50 + 55min travel + 15min buffer (default) = 13:00 arrival, landing
    # inside the lunch window (12:00-13:30).
    b_lat = _offset_lat(BASE_LAT, 27.5)
    b = make_place("B", b_lat, BASE_LON, "08:00", "23:00", 60)

    result = build_day_schedule([a, b], start_point=START_POINT)
    schedule = result["schedule"]

    a_entry = next(e for e in schedule if e.get("id_place") == "A")
    lunch_entry = next(e for e in schedule if e.get("type") == "lunch_break")
    b_entry = next(e for e in schedule if e.get("id_place") == "B")

    actual = (f"A.end_time={a_entry['end_time']}, lunch=[{lunch_entry['start_time']}"
              f"-{lunch_entry['end_time']}], B.start_time={b_entry['start_time']}")
    # lunch_window_end is FIXED at lunch_start+90=13:30 regardless of arrival
    # time inside the window — this is the no-double-count guarantee: the
    # break only finishes out the window (13:00->13:30 = 30 min), it does not
    # add a fresh 90-minute break on top of the 13:00 arrival.
    expected = "A.end_time=11:50, lunch=[13:00-13:30] (30min, NOT a fresh 90min break), B.start_time=13:30"
    passed = (
        a_entry["end_time"] == "11:50"
        and lunch_entry["start_time"] == "13:00"
        and lunch_entry["end_time"] == "13:30"
        and b_entry["start_time"] == "13:30"
    )
    _record(
        "2. Lunch break — case 2 (travel pushes arrival into window)",
        "A ends 11:50 (before noon); travel(55min, 27.5km)+buffer(15min) -> arrival 13:00",
        expected, actual, passed,
    )


# ── Test 3: closing-time violation (kept, +1000 cost, warning) ──────────────
def test_3_closing_violation() -> None:
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
        "3. Closing-time violation (visitEnd > closeTime)",
        "opens 08:00, closes 10:00, duration=150min -> visit_end=10:30 (30min past close)",
        expected, actual, passed,
    )


# ── Test 4a: mid-route drop, next place resumes from last committed state ──
def test_4a_drop_mid_route_state_carryover() -> None:
    # A: idx0, ends 09:00 (duration=60min from 08:00) — deliberately BEFORE
    # noon so the lunch mechanism (tests 1/2) cannot confound this test:
    # idx==0 never runs the noon-check block at all (see module docstring),
    # so had_lunch is False the instant A commits regardless of A's own end
    # time; keeping A's end before noon guarantees B's and C's own steps
    # don't independently trigger a fresh lunch insertion either, isolating
    # pure travel/position carryover as the only thing under test here.
    a = make_place("A", BASE_LAT, BASE_LON, "08:00", "23:00", 60)
    # B: 200km from A -> travel=400min. From A's 09:00: +400min travel +15min
    # buffer (default) + 300min duration = 09:00 + 715min = 20:55 -> past
    # day_end (20:00) -> DROPPED. Numbers are chosen to land strictly between
    # 20:00 and 24:00 (not wrap past midnight): _add() returns a bare
    # datetime.time with no date component, so a visit_end that wraps past
    # midnight would come back as an "early" time-of-day (e.g. 02:00) that
    # compares as LESS than day_end=20:00 — silently defeating the drop
    # check instead of triggering it. B's location is deliberately far from
    # both A and C so a bug that carried over B's (discarded) position/time
    # into C's simulation would be easy to detect (C would then also blow
    # past 20:00, which it must NOT).
    b_lat = _offset_lat(BASE_LAT, 200)
    b = make_place("B", b_lat, BASE_LON, "08:00", "23:00", 300)
    # C: only 5km from A (travel=10min). If C's simulation correctly resumes
    # from A (09:00, A's location) rather than from B's discarded attempt:
    #   09:00 + 10min travel + 15min buffer = 09:25 arrival, +60min visit
    #   -> visit_end = 10:25, well under 20:00 -> NOT dropped.
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
        "4a. Mid-route drop — state carryover to next place",
        "A ends 09:00; B is 200km away (forces drop); C is only 5km from A, duration=60min",
        expected, actual, passed,
    )


# ── Test 4b: all places drop -> fallback keeps the first ────────────────────
def test_4b_all_drop_fallback() -> None:
    # Every place independently simulated from day_start=08:00 (since a drop
    # at idx0 never advances current/prev, idx1/idx2 are ALSO simulated
    # fresh from 08:00) with duration=800min -> 08:00+800min=21:20, past
    # 20:00 for every single one.
    a = make_place("A", BASE_LAT, BASE_LON, "08:00", "23:00", 800)
    b = make_place("B", BASE_LAT, BASE_LON, "08:00", "23:00", 800)
    c = make_place("C", BASE_LAT, BASE_LON, "08:00", "23:00", 800)

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
        "4b. All places drop — fallback keeps first",
        "A, B, C all duration=800min (13h20) from 08:00 -> every one individually exceeds day_end=20:00",
        expected, actual, passed,
    )


def print_report() -> bool:
    all_passed = True
    col_widths = {"test_case": 45, "input": 65, "expected": 70, "actual": 70, "pass_fail": 6}
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
    test_1_lunch_case1()
    test_2_lunch_case2()
    test_3_closing_violation()
    test_4a_drop_mid_route_state_carryover()
    test_4b_all_drop_fallback()

    ok = print_report()
    print(f"\n{'ALL PASSED' if ok else 'SOME FAILED'} ({sum(1 for r in results if r['pass_fail'] == 'PASS')}/{len(results)})")
    sys.exit(0 if ok else 1)
