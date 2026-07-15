"""
services/schedule_builder.py
Simulate a day's itinerary and compute schedule-aware route cost.

Two functions, two contracts:
  route_cost_with_schedule() — pure, no dict mutations, used inside SA loop
  build_day_schedule()       — mutates place dicts (adds travel/time fields),
                               called ONCE on the final best route

Opening-time rules (per place, idx > 0):
  1. Check noon AT current_time (= previous place's raw end_time) BEFORE doing
     anything else for this place → splice lunch_break here if not yet taken
  2. Add travel time → advance clock
  3. Add buffer_minutes → advance clock
  4. If place not yet open, wait (recorded as total_wait_minutes)
  5. Visit the place; if end_time > close_time → violation (+1000 penalty)
  (idx == 0: no travel/buffer/noon-check precede the first place)

Day-end cutoff rules (day_end, default 20:00):
  - After computing a place's projected end_time (post travel + wait + duration),
    if end_time > day_end the place is DROPPED.
  - Dropped places are marked with "dropped": True and excluded from schedule.
  - current_time and prev are NOT advanced for dropped places; the next place's
    travel is calculated from the last actually-visited predecessor.
  - Edge case: if ALL places are dropped, the first place is force-kept with a
    warning rather than returning an empty day.
"""

import datetime
import math

_AVG_SPEED_KMH    = 30.0
_DEFAULT_DURATION = 60
_EARTH_RADIUS_KM  = 6371.0
_VIOLATION_PENALTY = 1000
_DROP_PENALTY      = 1500

# Defaults shared by both functions
_DAY_START    = datetime.time(8,  0)
_DAY_END      = datetime.time(20, 0)
_BUFFER       = 15
_LUNCH_START  = datetime.time(12, 0)
_LUNCH_DUR    = 90


# ── Tiny helpers ──────────────────────────────────────────────────────────────

def _hav_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dl / 2) ** 2
    return 2 * _EARTH_RADIUS_KM * math.asin(math.sqrt(a))


def _travel_min(a: dict, b: dict) -> int:
    km = _hav_km(
        float(a["latitude"]),  float(a["longitude"]),
        float(b["latitude"]),  float(b["longitude"]),
    )
    return round(km / _AVG_SPEED_KMH * 60)


def _parse_hhmm(s) -> datetime.time | None:
    if not s:
        return None
    try:
        return datetime.datetime.strptime(str(s).strip()[:5], "%H:%M").time()
    except (ValueError, AttributeError):
        return None


def _add(t: datetime.time, minutes: int) -> datetime.time:
    base = datetime.datetime.combine(datetime.date.today(), t)
    return (base + datetime.timedelta(minutes=minutes)).time()


def _mins(t: datetime.time) -> int:
    return t.hour * 60 + t.minute


def _fmt(t: datetime.time) -> str:
    return t.strftime("%H:%M")


def _slot(t: datetime.time) -> str:
    if t < datetime.time(12, 0):
        return "morning"
    if t < datetime.time(17, 0):
        return "afternoon"
    return "evening"


# ── Shared speculative step — used by both functions ──────────────────────────

def _simulate_place_step(
    idx: int,
    place: dict,
    current: datetime.time,
    had_lunch: bool,
    prev: dict,
    lunch_start: datetime.time,
    lunch_dur: int,
    default_dur: int,
    buffer: int,
) -> dict:
    """
    Simulate one place visit without mutating anything.

    Order (idx > 0): noon-check at raw current_time → travel → buffer →
    opening-wait → visit. The noon-check fires BEFORE travel/buffer so lunch
    lands right when the previous place finished, not after arriving at this one.

    Returns a dict with:
      sim_current    — clock after travel + buffer + lunch + wait + visit
      visit_start    — clock at which visit begins
      visit_end      — clock at which visit ends (= visit_start + duration)
      sim_had_lunch  — whether lunch has been consumed after this step
      travel         — travel minutes (0 for idx == 0)
      wait           — wait minutes for opening
      lunch_entry    — lunch_break dict to splice, or None
      lunch_cost     — minutes of clock consumed by lunch (for cost fn)
    """
    sim_current   = current
    sim_had_lunch = had_lunch
    travel        = 0
    wait          = 0
    lunch_entry   = None
    lunch_cost    = 0

    if idx > 0:
        # 1. Noon check — right at the moment the previous place finished,
        #    before travelling/buffering toward this one.
        if not sim_had_lunch and sim_current >= lunch_start:
            actual_ls   = sim_current if sim_current > lunch_start else lunch_start
            lunch_end   = _add(actual_ls, lunch_dur)
            lunch_cost  = _mins(lunch_end) - _mins(sim_current)
            lunch_entry = {
                "type":       "lunch_break",
                "start_time": _fmt(actual_ls),
                "end_time":   _fmt(lunch_end),
                "slot":       "afternoon",
            }
            sim_had_lunch = True
            sim_current   = lunch_end

        # 2. Travel
        travel      = _travel_min(prev, place)
        sim_current = _add(sim_current, travel)

        # 3. Buffer
        sim_current = _add(sim_current, buffer)

        # 3.5. Second noon check — catches the case where the previous place
        #      finished before noon (so check 1 didn't fire) but travel +
        #      buffer pushes arrival at this place into the lunch window.
        #      lunch_end is fixed at lunch_start + lunch_dur (not sim_current
        #      + lunch_dur) so a late arrival inside the window doesn't tack
        #      on a fresh full-length break — it just finishes out the window.
        lunch_window_end = _add(lunch_start, lunch_dur)
        if (
            not sim_had_lunch
            and lunch_start <= sim_current < lunch_window_end
        ):
            lunch_cost  = _mins(lunch_window_end) - _mins(sim_current)
            lunch_entry = {
                "type":       "lunch_break",
                "start_time": _fmt(sim_current),
                "end_time":   _fmt(lunch_window_end),
                "slot":       "afternoon",
            }
            sim_had_lunch = True
            sim_current   = lunch_window_end

    # 4. Opening wait
    open_t = _parse_hhmm(place.get("timespan"))
    if open_t and sim_current < open_t:
        # If noon falls during the wait, take lunch first
        if not sim_had_lunch and _mins(open_t) > _mins(lunch_start):
            actual_ls   = lunch_start if _mins(sim_current) <= _mins(lunch_start) else sim_current
            lunch_end   = _add(actual_ls, lunch_dur)
            lunch_cost  = _mins(lunch_end) - _mins(sim_current)
            lunch_entry = {
                "type":       "lunch_break",
                "start_time": _fmt(actual_ls),
                "end_time":   _fmt(lunch_end),
                "slot":       "afternoon",
            }
            sim_had_lunch = True
            sim_current   = lunch_end
        if sim_current < open_t:
            wait        = _mins(open_t) - _mins(sim_current)
            sim_current = open_t

    # Visit
    dur         = int(place.get("estimated_duration_minutes") or 0) or default_dur
    visit_start = sim_current
    visit_end   = _add(visit_start, dur)

    return {
        "sim_current":   visit_end,   # clock after visit (before buffer)
        "visit_start":   visit_start,
        "visit_end":     visit_end,
        "sim_had_lunch": sim_had_lunch,
        "travel":        travel,
        "wait":          wait,
        "lunch_entry":   lunch_entry,
        "lunch_cost":    lunch_cost,
    }


# ── Pure cost function — used inside SA, NO dict mutations ────────────────────

def route_cost_with_schedule(
    route: list[dict],
    start: dict,
    day_start:   datetime.time = _DAY_START,
    buffer:      int           = _BUFFER,
    default_dur: int           = _DEFAULT_DURATION,
    lunch_start: datetime.time = _LUNCH_START,
    lunch_dur:   int           = _LUNCH_DUR,
    day_end:     datetime.time = _DAY_END,
) -> float:
    """
    Evaluate a candidate route order for SA without mutating any place dict.

    Cost = total_travel_minutes
         + total_wait_minutes
         + violation_count  × 1000
         + dropped_count    × 1500
    """
    if not route:
        return 0.0

    current    = day_start
    had_lunch  = False
    total_cost = 0.0
    prev       = start

    for idx, place in enumerate(route):
        step = _simulate_place_step(
            idx, place, current, had_lunch, prev,
            lunch_start, lunch_dur, default_dur, buffer,
        )

        # Drop check — if visit would end after day_end, penalise and skip
        if step["visit_end"] > day_end:
            total_cost += _DROP_PENALTY
            # prev stays as the last actually-visited place
            continue

        # Commit cost
        total_cost += step["travel"] + step["wait"] + step["lunch_cost"]

        # Closing-time violation
        close_t = _parse_hhmm(place.get("timeclose"))
        if close_t and step["visit_end"] > close_t:
            total_cost += _VIOLATION_PENALTY

        current   = step["visit_end"]
        had_lunch = step["sim_had_lunch"]
        prev      = place

    return total_cost


# ── Final schedule — mutates place dicts, called once on best route ───────────

def build_day_schedule(
    places: list[dict],
    start_point: dict,
    day_start:                datetime.time = _DAY_START,
    buffer_minutes:           int           = _BUFFER,
    default_duration_minutes: int           = _DEFAULT_DURATION,
    lunch_start:              datetime.time = _LUNCH_START,
    lunch_duration_minutes:   int           = _LUNCH_DUR,
    day_end:                  datetime.time = _DAY_END,
) -> dict:
    """
    Build the final time schedule for one day.

    Side effects: writes estimated_travel_minutes / start_time / end_time /
    slot / warning / dropped / type into each place dict.

    Returns:
        schedule              – chronological list of 'place' + 'lunch_break' entries
                                (includes dropped places marked with "dropped": True
                                 so the caller can filter them for API output)
        total_travel_minutes  – sum of all inter-place travel legs (dropped excluded)
        total_wait_minutes    – sum of time spent waiting for places to open (dropped excluded)
        violation_count       – places where visit would end after closing time
        dropped_count         – places cut because projected end_time > day_end
    """
    if not places:
        return {
            "schedule": [], "total_travel_minutes": 0,
            "total_wait_minutes": 0, "violation_count": 0, "dropped_count": 0,
        }

    schedule      : list[dict]   = []
    current       : datetime.time = day_start
    had_lunch     : bool          = False
    total_travel  : int           = 0
    total_wait    : int           = 0
    violations    : int           = 0
    dropped_count : int           = 0
    prev                          = start_point

    for idx, place in enumerate(places):
        step = _simulate_place_step(
            idx, place, current, had_lunch, prev,
            lunch_start, lunch_duration_minutes, default_duration_minutes, buffer_minutes,
        )

        # ── Drop check ────────────────────────────────────────────────────────
        if step["visit_end"] > day_end:
            place["dropped"]    = True
            place["type"]       = "place"
            place["start_time"] = None
            place["end_time"]   = None
            place["slot"]       = None
            place["warning"]    = f"Dropped — projected end {_fmt(step['visit_end'])} exceeds day cutoff {_fmt(day_end)}"
            place["estimated_travel_minutes"] = None
            dropped_count += 1
            schedule.append(place)   # include in schedule so caller can inspect/filter
            # current, had_lunch, prev all stay as the last committed state
            continue

        # ── Commit ────────────────────────────────────────────────────────────
        # Splice lunch if this step triggered one
        if step["lunch_entry"]:
            schedule.append(step["lunch_entry"])
        had_lunch = step["sim_had_lunch"]

        # Travel + wait stats
        place["estimated_travel_minutes"] = step["travel"] if step["travel"] > 0 else None
        total_travel += step["travel"]
        total_wait   += step["wait"]

        # Closing-time violation
        warning = None
        close_t = _parse_hhmm(place.get("timeclose"))
        if close_t and step["visit_end"] > close_t:
            warning = f"May close at {_fmt(close_t)} before visit ends"
            violations += 1

        place["dropped"]    = False
        place["type"]       = "place"
        place["start_time"] = _fmt(step["visit_start"])
        place["end_time"]   = _fmt(step["visit_end"])
        place["slot"]       = _slot(step["visit_start"])
        place["warning"]    = warning

        schedule.append(place)
        current = step["visit_end"]
        prev    = place

    # ── Edge case: ALL places dropped — force-keep the first ─────────────────
    has_real_place = any(
        e.get("type") == "place" and not e.get("dropped") for e in schedule
    )
    if not has_real_place and places:
        p   = places[0]
        dur = int(p.get("estimated_duration_minutes") or 0) or default_duration_minutes
        p["dropped"]    = False
        p["type"]       = "place"
        p["estimated_travel_minutes"] = None
        p["start_time"] = _fmt(day_start)
        p["end_time"]   = _fmt(_add(day_start, dur))
        p["slot"]       = _slot(day_start)
        p["warning"]    = (
            "Kept despite exceeding day_end — no other places fit the schedule"
        )
        # Remove the earlier dropped entry for this place and replace it
        schedule = [e for e in schedule if e is not p]
        schedule.insert(0, p)
        dropped_count -= 1

    return {
        "schedule":             schedule,
        "total_travel_minutes": total_travel,
        "total_wait_minutes":   total_wait,
        "violation_count":      violations,
        "dropped_count":        dropped_count,
    }
