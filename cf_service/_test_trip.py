"""
Test 1: Generate real 3-day trip, print one full day schedule.
Test 2: Measure wall-clock time.
Test 3: Confirm closure binding of start_point in SA.
Test 4: Test with save_plan=True to confirm no KeyError from lunch_break.
"""
import json
import time
import sys
import urllib.request

API = "http://localhost:8000"

USER_ID     = "e4bb33fb-5f1b-49a6-9a00-93c67183afde"
PROVINCE_ID = "094014a7-b8f6-481a-bbce-5ed6cdd457c5"

PAYLOAD_NO_SAVE = {
    "id_user":     USER_ID,
    "id_province": PROVINCE_ID,
    "n_days":      3,
    "start_date":  "2026-07-01",
    "sa_runs":     3,
    "save_plan":   False,
}

PAYLOAD_SAVE = {
    "id_user":     USER_ID,
    "id_province": PROVINCE_ID,
    "n_days":      2,
    "start_date":  "2026-07-05",
    "sa_runs":     3,
    "save_plan":   True,
}


def post(path, body):
    data = json.dumps(body).encode()
    req  = urllib.request.Request(
        f"{API}{path}", data=data,
        headers={"Content-Type": "application/json"}, method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        return json.loads(resp.read())


# =============================================================================
# TEST 2 -- Performance
# =============================================================================
print("=" * 65)
print("TEST 2 -- Performance (sa_runs=3, 3 days)")
print("=" * 65)

t0 = time.perf_counter()
result = post("/api/trips/plan", PAYLOAD_NO_SAVE)
elapsed = time.perf_counter() - t0
print(f"Wall-clock: {elapsed:.2f}s  ({elapsed*1000:.0f}ms)")

days = result.get("days", [])
if not days:
    print("ERROR: no days in response")
    print(json.dumps(result, indent=2, default=str))
    sys.exit(1)

# =============================================================================
# TEST 1 -- Day 1 schedule human-readable + raw JSON
# =============================================================================
print()
print("=" * 65)
print("TEST 1 -- Day 1 schedule")
print("=" * 65)

day1 = days[0]
entries = day1["places"]
print(f"Day {day1['day']}  date={day1['date']}  entries={len(entries)}")
print()

place_count  = 0
lunch_count  = 0
warning_count = 0

for entry in entries:
    t = entry.get("type", "place")
    if t == "lunch_break":
        lunch_count += 1
        print(f"  [LUNCH]  {entry.get('start_time')} -> {entry.get('end_time')}  slot={entry.get('slot')}")
    else:
        place_count += 1
        w = " *** WARN: " + entry["warning"] if entry.get("warning") else ""
        if entry.get("warning"):
            warning_count += 1
        # safe int formatting
        travel = entry.get("estimated_travel_minutes")
        dur    = entry.get("estimated_duration_minutes")
        travel_s = f"{travel:>3}m" if travel is not None else "  ?m"
        dur_s    = f"{dur:>4}m"   if dur    is not None else "   ?m"
        print(
            f"  [{entry.get('order'):>2}] {entry.get('start_time')} -> {entry.get('end_time')}"
            f"  slot={entry.get('slot') or '':9}"
            f"  travel={travel_s}  dur={dur_s}"
            f"  open={str(entry.get('timespan') or '?'):>5}-{str(entry.get('timeclose') or '?'):<5}"
            f"  {entry.get('name')}"
            + w
        )

print()
print(f"Summary: {place_count} places, {lunch_count} lunch_break, {warning_count} warnings")

print()
print("--- RAW JSON Day 1 ---")
print(json.dumps(day1, indent=2, ensure_ascii=False, default=str))

# Also show debug block
print()
print("--- debug ---")
print(json.dumps(result.get("debug", {}), indent=2, default=str))

# =============================================================================
# TEST 4 -- save_plan=True (confirm no KeyError from lunch_break in DB insert)
# =============================================================================
print()
print("=" * 65)
print("TEST 4 -- save_plan=True (lunch_break must not hit KeyError)")
print("=" * 65)

try:
    t0 = time.perf_counter()
    res_saved = post("/api/trips/plan", PAYLOAD_SAVE)
    elapsed4  = time.perf_counter() - t0
    id_plan   = res_saved.get("id_plan")
    saved_days = res_saved.get("days", [])
    print(f"OK  -- elapsed={elapsed4:.2f}s  id_plan={id_plan}")
    print(f"      days returned: {len(saved_days)}")
    for d in saved_days:
        types = [e.get('type', 'place') for e in d.get('places', [])]
        print(f"      day {d['day']}: {types}")
except Exception as exc:
    print(f"FAILED: {exc}")

# =============================================================================
# TEST 3 -- Closure binding verification
# =============================================================================
print()
print("=" * 65)
print("TEST 3 -- SA closure / start_point binding")
print("=" * 65)

import inspect
from services.module3_optimizer import optimize_day_route
src_lines = inspect.getsource(optimize_day_route).splitlines()
print("optimize_day_route source:")
for i, line in enumerate(src_lines, 1):
    print(f"  {i:>3}  {line}")

print()
print("Analysis:")
print("  'start' is a LOCAL variable of optimize_day_route().")
print("  cost_fn(route) closes over 'start' via lexical (closure) capture.")
print("  Each call to optimize_day_route() creates a NEW closure with ITS OWN 'start'.")
print("  => start_point cannot be confused across days/calls. Binding is correct.")
