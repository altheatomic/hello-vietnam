"""
services/schedule_builder.py
Simulate a day's itinerary and compute schedule-aware route cost.

Two functions, two contracts:
  route_cost_with_schedule() — pure, no dict mutations, used inside SA loop
  build_day_schedule()       — mutates place dicts (adds travel/time fields),
                               called ONCE on the final best route

Opening-time rules:
  1. (idx > 0 only) Add travel time → advance clock
  2. (idx > 0 only) Add buffer_minutes → advance clock
  3. Lunch break — SOFT constraint (minimised deviation, not a hard block):
     evaluated once per day (guarded by had_lunch), BEFORE the opening-wait
     check, using two candidate insertion points:
       Option A — right after the CURRENT activity ends, i.e. at `current`,
                  BEFORE travel to the next place.
       Option B — right before the NEXT activity's own flow begins, i.e.
                  after travel + buffer have already been added.
     (For idx == 0 there is no prior activity in this route, so travel =
     buffer = 0 and Option A/B collapse to the same instant.)
     Trigger: only fires on the first step where proceeding without a break
     would carry the (possibly wait-adjusted) visit past lunch_start —
     i.e. max(option_b_start, opening_time) + duration > 12:00. This defers
     the break until it is actually needed, instead of forcing it onto the
     first place of the day.
     deviation(break_start) = max(0, mins(12:00) - mins(break_start))
                             + max(0, mins(break_start) + 90 - mins(13:30))
     (0 if the 90-minute break lands entirely inside [12:00, 13:30);
     otherwise the number of minutes it protrudes outside the window.)
     Whichever option has the lower deviation is chosen (ties → Option A).
     The break always lasts a full lunch_dur (90 min) wherever it lands —
     unlike the old hard-block version, it is no longer truncated/anchored
     to a fixed 12:00-13:30 window.
  4. If place still not open after the lunch decision, wait for opening
     (recorded as total_wait_minutes).
  5. Visit the place; if end_time > close_time → violation (+1000 penalty)

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
from typing import Callable

_AVG_SPEED_KMH    = 30.0
_DEFAULT_DURATION = 60
_EARTH_RADIUS_KM  = 6371.0
_VIOLATION_PENALTY = 1000
_DROP_PENALTY      = 1500
_LUNCH_DEVIATION_PENALTY_PER_MIN = 3   # cost per minute the 90-min lunch break lands outside [12:00, 13:30)

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
    """
    Known limitation: wraps silently past 24h (returns a bare time-of-day,
    e.g. 25:00 -> 01:00), which can defeat the visit_end > day_end drop
    check for abnormally large `minutes`. Input duration is expected to
    stay sane — see the clamp on estimated_duration_minutes in
    services/module2_algorithm.py's estimate_duration_minutes()
    (MAX_SINGLE_PLACE_DURATION_MINUTES in config.py).
    """
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


def _lunch_deviation_minutes(
    break_start: datetime.time, lunch_start: datetime.time, lunch_dur: int
) -> int:
    """Minutes the [break_start, break_start+lunch_dur) interval protrudes
    outside the ideal [lunch_start, lunch_start+lunch_dur) window. 0 if it
    lands entirely inside."""
    bs = _mins(break_start)
    ls = _mins(lunch_start)
    early = max(0, ls - bs)
    late  = max(0, (bs + lunch_dur) - (ls + lunch_dur))
    return early + late


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
    travel_time_fn: Callable[[dict, dict], float] = _travel_min,
) -> dict:
    """
    Simulate one place visit without mutating anything.

    Order: [lunch decision] → travel → buffer (idx > 0 only) → opening-wait
    → visit, where the lunch break is spliced in at whichever of the two
    candidate points (Option A, before travel; Option B, after travel+buffer)
    minimises deviation from [12:00, 13:30) — see module docstring.

    travel_time_fn(prev, place) → minutes, defaults to Haversine-based
    _travel_min(). route_cost_with_schedule() (SA cost fn, called many times
    per optimisation run) always uses the Haversine default and must never
    be passed anything else. build_day_schedule() (called once on the final
    best route) is the only caller allowed to override this with a more
    accurate source (e.g. a pre-fetched Goong travel-time lookup), since
    real API calls per SA iteration would be far too slow/expensive.

    Returns a dict with:
      sim_current      — clock after travel + buffer + lunch + wait + visit
      visit_start       — clock at which visit begins
      visit_end         — clock at which visit ends (= visit_start + duration)
      sim_had_lunch     — whether lunch has been consumed after this step
      travel            — travel minutes (0 for idx == 0)
      wait              — wait minutes for opening
      lunch_entry       — lunch_break dict to splice, or None
      lunch_cost        — minutes of clock consumed by lunch (for cost fn)
      lunch_deviation   — minutes the chosen break protrudes outside
                           [12:00, 13:30); 0 if no break this step
    """
    sim_had_lunch   = had_lunch
    lunch_entry     = None
    lunch_cost      = 0
    lunch_deviation = 0

    travel      = travel_time_fn(prev, place) if idx > 0 else 0
    step_buffer = buffer if idx > 0 else 0
    dur         = int(place.get("estimated_duration_minutes") or 0) or default_dur
    open_t      = _parse_hhmm(place.get("timespan"))

    # Candidate lunch insertion points.
    option_a_start = current                               # right after current activity, before travel
    option_b_start = _add(current, travel + step_buffer)    # right after travel+buffer, before opening-wait

    lunch_needed = False
    if not sim_had_lunch:
        naive_arrival = _mins(option_b_start)
        naive_visit_start = max(naive_arrival, _mins(open_t)) if open_t else naive_arrival
        lunch_needed = (naive_visit_start + dur) > _mins(lunch_start)

    if lunch_needed:
        dev_a = _lunch_deviation_minutes(option_a_start, lunch_start, lunch_dur)
        dev_b = _lunch_deviation_minutes(option_b_start, lunch_start, lunch_dur)
        use_a = dev_a <= dev_b

        chosen_start    = option_a_start if use_a else option_b_start
        lunch_deviation = dev_a if use_a else dev_b
        lunch_end       = _add(chosen_start, lunch_dur)

        lunch_entry = {
            "type":             "lunch_break",
            "start_time":       _fmt(chosen_start),
            "end_time":         _fmt(lunch_end),
            "slot":             "afternoon",
            "deviation_minutes": lunch_deviation,
        }
        lunch_cost    = lunch_dur
        sim_had_lunch = True

        if use_a:
            # Order: lunch → travel → buffer → opening-wait → visit
            sim_current = _add(lunch_end, travel + step_buffer)
        else:
            # Order: travel → buffer → lunch → opening-wait → visit
            sim_current = lunch_end
    else:
        sim_current = option_b_start

    # Opening wait (after the lunch decision, whichever branch was taken)
    wait = 0
    if open_t and sim_current < open_t:
        wait        = _mins(open_t) - _mins(sim_current)
        sim_current = open_t

    # Visit
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
        "lunch_deviation": lunch_deviation,
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
         + violation_count       × 1000
         + dropped_count         × 1500
         + lunch_deviation_total × 3 (_LUNCH_DEVIATION_PENALTY_PER_MIN)

    Always uses the default Haversine travel_time_fn (_travel_min) — this
    runs hundreds of times per SA optimisation run, so it must never call
    out to a real API. See _simulate_place_step()'s docstring.
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
            travel_time_fn=_travel_min,
        )

        # Drop check — if visit would end after day_end, penalise and skip
        if step["visit_end"] > day_end:
            total_cost += _DROP_PENALTY
            # prev stays as the last actually-visited place
            continue

        # Commit cost
        total_cost += step["travel"] + step["wait"] + step["lunch_cost"]
        total_cost += step["lunch_deviation"] * _LUNCH_DEVIATION_PENALTY_PER_MIN

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
    travel_time_fn:           Callable[[dict, dict], float] | None = None,
) -> dict:
    """
    Build the final time schedule for one day.

    Side effects: writes estimated_travel_minutes / start_time / end_time /
    slot / warning / dropped / type into each place dict.

    travel_time_fn: optional override for the travel-time source, forwarded
    to _simulate_place_step(). Defaults to None, which falls back to the
    Haversine-based _travel_min() — i.e. calling build_day_schedule() the
    old way (no new argument) is 100% unchanged behaviour. Pass a lookup
    built from real routing data (e.g. Goong Distance Matrix, bike vehicle)
    to compute the final start_time/end_time from accurate travel times —
    this is safe here because, unlike route_cost_with_schedule(), this
    function runs exactly once, on the already-chosen best route.

    Returns:
        schedule              – chronological list of 'place' + 'lunch_break' entries
                                (includes dropped places marked with "dropped": True
                                 so the caller can filter them for API output)
        total_travel_minutes  – sum of all inter-place travel legs (dropped excluded)
        total_wait_minutes    – sum of time spent waiting for places to open (dropped excluded)
        violation_count       – places where visit would end after closing time
        dropped_count         – places cut because projected end_time > day_end
        lunch_deviation_minutes – minutes the lunch break landed outside [12:00, 13:30)
                                   (0 if it fit perfectly, or no lunch was needed)
    """
    if not places:
        return {
            "schedule": [], "total_travel_minutes": 0,
            "total_wait_minutes": 0, "violation_count": 0, "dropped_count": 0,
            "lunch_deviation_minutes": 0,
        }

    schedule      : list[dict]   = []
    current       : datetime.time = day_start
    had_lunch     : bool          = False
    total_travel  : int           = 0
    total_wait    : int           = 0
    violations    : int           = 0
    dropped_count : int           = 0
    lunch_deviation_minutes : int = 0
    prev                          = start_point
    effective_travel_time_fn      = travel_time_fn or _travel_min

    for idx, place in enumerate(places):
        step = _simulate_place_step(
            idx, place, current, had_lunch, prev,
            lunch_start, lunch_duration_minutes, default_duration_minutes, buffer_minutes,
            travel_time_fn=effective_travel_time_fn,
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
            lunch_deviation_minutes += step["lunch_deviation"]
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
        "lunch_deviation_minutes": lunch_deviation_minutes,
    }
