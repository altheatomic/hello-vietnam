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
  - This check is done in elapsed minutes since day_start (a plain, never-
    wrapping int — see _minutes_to_cutoff()/_simulate_place_step()), NOT on
    the wall-clock datetime.time value. A route whose accumulated travel +
    wait + duration exceeds 24h would otherwise wrap a bare datetime.time
    back to an early-looking hour (e.g. 25:34 -> "01:34"), silently
    defeating a plain `visit_end > day_end` comparison — this can happen in
    practice for candidates spread across a geographically wide province
    (e.g. a post-merger province spanning 200+ km) combined with n_days=1,
    where Module 2's clustering is a no-op (cluster_count == 1) and does
    nothing to keep same-day candidates close together.
  - Dropped places are marked with "dropped": True and excluded from schedule.
  - current_time, current_elapsed and prev are NOT advanced for dropped
    places; the next place's travel is calculated from the last
    actually-visited predecessor.
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
    Wraps silently past 24h (e.g. 25:00 -> 01:00) — a bare datetime.time has
    no day component, so this alone can never distinguish "past midnight"
    from "same day". This is no longer a correctness hazard for the
    day-end cutoff: that check now runs on `elapsed_minutes` (plain int,
    counted from day_start, never wrapped — see _simulate_place_step()),
    never on a value that has been through this function.

    Two call sites remain:
      - Speculative, inside _simulate_place_step() (option_b_start, lunch_end,
        sim_current, visit_end): these CAN still wrap for a place whose true
        elapsed time is abnormally large. Harmless — the drop check that
        follows uses the never-wrapping elapsed_minutes twin instead, and a
        dropped place's wrapped datetime.time values are discarded, never
        written to output.
      - Output formatting, inside build_day_schedule() (right before writing
        place["start_time"]/["end_time"]): only reached for a place that
        already passed the elapsed-minutes drop check, i.e.
        elapsed_visit_end <= minutes_to(day_end) — always well under 1440
        for any sane day window — so this specific call is guaranteed not
        to wrap.
    Do not feed this a raw, unvalidated elapsed-minutes total for output
    without going through (or re-deriving) that same bound first.
    """
    base = datetime.datetime.combine(datetime.date.today(), t)
    return (base + datetime.timedelta(minutes=minutes)).time()


def _mins(t: datetime.time) -> int:
    return t.hour * 60 + t.minute


def _minutes_to_cutoff(day_start: datetime.time, day_end: datetime.time) -> int:
    """
    Minutes from day_start to day_end (e.g. 08:00 -> 20:00 = 720), computed
    once per call and used as the never-wrapping reference for the day-end
    drop check — see _simulate_place_step()'s `elapsed_minutes` and the
    module docstring's "Day-end cutoff rules". Wraps forward (+ 24h) only
    for the degenerate case of day_end <= day_start, which isn't a realistic
    config but keeps this a sane non-negative value regardless.
    """
    delta = _mins(day_end) - _mins(day_start)
    return delta if delta >= 0 else delta + 24 * 60


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
    current_elapsed: int,
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

    current_elapsed: minutes since day_start that `current` corresponds to,
    tracked as a plain int in lockstep with every addition also applied to
    `current` via _add() below — but NEVER wrapped (no modulo, no 24h
    rollover). This is the only value the day-end drop check may trust: a
    wrapped datetime.time (e.g. "07:34") can look "early" even after 30+
    hours have actually elapsed, but its int twin keeps counting past 1440
    with no ambiguity. See _minutes_to_cutoff() and the module docstring's
    "Day-end cutoff rules". The datetime.time values below remain exactly
    as before — still used for the lunch/opening-hour decisions and (once a
    place is confirmed NOT dropped) for output formatting; per the
    elapsed-vs-cutoff invariant enforced by both callers, current_elapsed
    for any place actually reaching this function is always
    <= minutes_to(day_end), which is always far under 1440 for any sane
    day window — so the datetime.time side of this function never wraps in
    practice for a place that ends up committed.

    Returns a dict with:
      sim_current      — clock after travel + buffer + lunch + wait + visit
      visit_start       — clock at which visit begins
      visit_end         — clock at which visit ends (= visit_start + duration)
      elapsed_visit_end  — visit_end's never-wrapping minutes-since-day_start
                           twin — the ONLY value the day-end cutoff check may
                           compare against minutes_to(day_end).
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
    elapsed_option_a_start = current_elapsed
    elapsed_option_b_start = current_elapsed + travel + step_buffer

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
        elapsed_chosen_start = elapsed_option_a_start if use_a else elapsed_option_b_start
        lunch_deviation = dev_a if use_a else dev_b
        lunch_end       = _add(chosen_start, lunch_dur)
        elapsed_lunch_end = elapsed_chosen_start + lunch_dur

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
            elapsed_sim_current = elapsed_lunch_end + travel + step_buffer
        else:
            # Order: travel → buffer → lunch → opening-wait → visit
            sim_current = lunch_end
            elapsed_sim_current = elapsed_lunch_end
    else:
        sim_current = option_b_start
        elapsed_sim_current = elapsed_option_b_start

    # Opening wait (after the lunch decision, whichever branch was taken)
    wait = 0
    if open_t and sim_current < open_t:
        wait        = _mins(open_t) - _mins(sim_current)
        sim_current = open_t
    elapsed_sim_current += wait   # mirrors the `sim_current = open_t` jump above

    # Visit
    visit_start = sim_current
    visit_end   = _add(visit_start, dur)
    elapsed_visit_start = elapsed_sim_current
    elapsed_visit_end   = elapsed_visit_start + dur

    return {
        "sim_current":   visit_end,   # clock after visit (before buffer)
        "visit_start":   visit_start,
        "visit_end":     visit_end,
        "elapsed_visit_start": elapsed_visit_start,
        "elapsed_visit_end":   elapsed_visit_end,
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
    travel_time_fn: Callable[[dict, dict], float] | None = None,
) -> float:
    """
    Evaluate a candidate route order for SA without mutating any place dict.

    Cost = total_travel_minutes
         + total_wait_minutes
         + violation_count       × 1000
         + dropped_count         × 1500
         + lunch_deviation_total × 3 (_LUNCH_DEVIATION_PENALTY_PER_MIN)

    travel_time_fn: optional override, defaults to None which falls back to
    the Haversine-based _travel_min() — i.e. calling this the old way (no
    new argument) is 100% unchanged behaviour, same as build_day_schedule()'s
    existing travel_time_fn parameter (see its docstring). Still must never
    be passed anything that calls out to a real API — this runs hundreds of
    times per SA optimisation run. module3_optimizer.optimize_day_route()
    passes a precomputed Haversine lookup here (same _travel_min() values,
    just computed once upfront instead of per call) — see
    _simulate_place_step()'s docstring for why a real API travel_time_fn
    (e.g. Goong) may only ever be passed to build_day_schedule(), never here.
    """
    if not route:
        return 0.0

    effective_travel_time_fn = travel_time_fn or _travel_min

    current         = day_start
    current_elapsed = 0   # minutes since day_start — never wraps, see _minutes_to_cutoff()
    minutes_to_cutoff = _minutes_to_cutoff(day_start, day_end)
    had_lunch  = False
    total_cost = 0.0
    prev       = start

    for idx, place in enumerate(route):
        step = _simulate_place_step(
            idx, place, current, current_elapsed, had_lunch, prev,
            lunch_start, lunch_dur, default_dur, buffer,
            travel_time_fn=effective_travel_time_fn,
        )

        # Drop check — compared on never-wrapping elapsed minutes, NOT on the
        # wall-clock visit_end (which can wrap past midnight and silently
        # defeat a plain `> day_end` comparison — see _add()'s docstring).
        if step["elapsed_visit_end"] > minutes_to_cutoff:
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

        current         = step["visit_end"]
        current_elapsed = step["elapsed_visit_end"]
        had_lunch       = step["sim_had_lunch"]
        prev            = place

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

    schedule        : list[dict]   = []
    current         : datetime.time = day_start
    current_elapsed : int          = 0   # minutes since day_start — never wraps
    minutes_to_cutoff : int        = _minutes_to_cutoff(day_start, day_end)
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
            idx, place, current, current_elapsed, had_lunch, prev,
            lunch_start, lunch_duration_minutes, default_duration_minutes, buffer_minutes,
            travel_time_fn=effective_travel_time_fn,
        )

        # ── Drop check ────────────────────────────────────────────────────────
        # Compared on never-wrapping elapsed minutes, NOT on the wall-clock
        # visit_end — a wall-clock comparison can wrap past midnight for
        # abnormally large cumulative travel (e.g. candidates spread across
        # a wide post-merger province) and silently defeat a plain
        # `visit_end > day_end` check. See _add()'s and
        # _minutes_to_cutoff()'s docstrings.
        if step["elapsed_visit_end"] > minutes_to_cutoff:
            overrun_hours = (step["elapsed_visit_end"] - minutes_to_cutoff) / 60
            place["dropped"]    = True
            place["type"]       = "place"
            place["start_time"] = None
            place["end_time"]   = None
            place["slot"]       = None
            place["warning"]    = (
                f"Dropped — projected visit would end {overrun_hours:.1f}h past "
                f"day cutoff {_fmt(day_end)} ({step['elapsed_visit_end']} elapsed "
                f"minutes since {_fmt(day_start)} vs a {minutes_to_cutoff}-minute day)"
            )
            place["estimated_travel_minutes"] = None
            dropped_count += 1
            schedule.append(place)   # include in schedule so caller can inspect/filter
            # current, current_elapsed, had_lunch, prev all stay as the last
            # committed state
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

        # Format wall-clock strings from elapsed_minutes (the single source
        # of truth), not from the parallel datetime.time values computed
        # above — this is the only place in this function allowed to feed
        # an elapsed-minutes total into _add(), and it is safe to do so
        # here specifically because the drop check above already proved
        # elapsed_visit_end <= minutes_to_cutoff (« 1440) for this place.
        visit_start_fmt = _add(day_start, step["elapsed_visit_start"])
        visit_end_fmt   = _add(day_start, step["elapsed_visit_end"])

        place["dropped"]    = False
        place["type"]       = "place"
        place["start_time"] = _fmt(visit_start_fmt)
        place["end_time"]   = _fmt(visit_end_fmt)
        place["slot"]       = _slot(visit_start_fmt)
        place["warning"]    = warning

        schedule.append(place)
        current         = step["visit_end"]
        current_elapsed = step["elapsed_visit_end"]
        prev            = place

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
