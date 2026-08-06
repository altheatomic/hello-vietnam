"""
test_goong_travel_data_int_cast.py
Regression test for the Render production bug:

    postgrest.exceptions.APIError: {'code': '22P02', ...,
    'message': 'invalid input syntax for type integer: "9.2"'}

Root cause: Goong Distance Matrix's duration.value / distance.value are NOT
guaranteed JSON integers despite the docs implying so — real responses (only
exercised once GOONG_API_KEY was live on Render) returned floats for some
edges. goong_client.py passes .value through unchanged, _attach_travel_data()
in trip_planner.py copies it unchanged into the place dict, and save_plan()
in db/queries_plan.py used to insert it unchanged into `int` Postgres columns
-> 22P02. Fixed via db.queries_plan._to_pg_int() (round-then-int, not a bare
truncating int()) applied to all 4 travel_time_*/travel_distance_* fields
right before the insert.

No DB required — supabase client is mocked; we only assert on the payload
save_plan() builds for `.table("plan_component").insert(...)`.

Usage:
    python test_goong_travel_data_int_cast.py
"""

import datetime
import sys
from unittest.mock import MagicMock

from db.queries_plan import _to_pg_int, save_plan

FAILURES = 0


def check(label, actual, expected):
    global FAILURES
    ok = actual == expected
    if not ok:
        FAILURES += 1
    print(f"{label:60s} actual={actual!r} expected={expected!r} {'PASS' if ok else 'FAIL'}")


# ── 1. _to_pg_int() unit cases ────────────────────────────────────────────────

check("_to_pg_int(9.2) — exact reported bug value", _to_pg_int(9.2), 9)
check("_to_pg_int(9.6) — rounds up, not truncates", _to_pg_int(9.6), 10)
check("_to_pg_int(600) — already-int passthrough", _to_pg_int(600), 600)
check("_to_pg_int(None) — missing edge stays None", _to_pg_int(None), None)

# ── 2. End-to-end: save_plan() insert payload never contains a float ─────────

days = [{
    "day": 1,
    "places": [
        {
            "type": "place", "order": 1, "id_place": "11111111-1111-1111-1111-111111111111",
            "slot": "morning", "start_time": "08:00", "end_time": "09:00",
            "estimated_travel_minutes": None,
            # first place of the day: genuinely no travel data upstream
            "tag_match": 0.5, "cf_score": 0.1, "final_score": 0.4,
        },
        {
            "type": "place", "order": 2, "id_place": "22222222-2222-2222-2222-222222222222",
            "slot": "morning", "start_time": "09:10", "end_time": "10:00",
            "estimated_travel_minutes": 5,
            "travel_time_car_seconds": 9.2,        # <- exact reported bug value
            "travel_time_bike_seconds": 552.0,
            "travel_distance_car_meters": 1500.0,
            "travel_distance_bike_meters": 1500.6,
            "tag_match": 0.5, "cf_score": 0.1, "final_score": 0.4,
        },
    ],
}]

fake_supabase = MagicMock()
fake_supabase.rpc.return_value.execute.return_value.data = [
    {"id_plan": "33333333-3333-3333-3333-333333333333", "custom_title": "Test Trip"}
]

save_plan(fake_supabase, "user1", "prov1", 1, datetime.date(2026, 8, 6), days, None)

inserted_rows = fake_supabase.table.return_value.insert.call_args[0][0]
travel_fields = (
    "travel_time_car_seconds", "travel_time_bike_seconds",
    "travel_distance_car_meters", "travel_distance_bike_meters",
)
for row in inserted_rows:
    for field in travel_fields:
        value = row[field]
        is_valid = value is None or isinstance(value, int)
        check(f"row[{row['id_place'][:8]}][{field}] is int or None", is_valid, True)

check("row2.travel_time_car_seconds == 9 (from 9.2)",
      next(r for r in inserted_rows if r["id_place"].startswith("22"))["travel_time_car_seconds"], 9)

if FAILURES:
    print(f"\n{FAILURES} check(s) FAILED")
    sys.exit(1)
print("\nALL PASSED")
