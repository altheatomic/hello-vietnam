"""
services/schedule_builder.py
Simulate a day's itinerary and compute schedule-aware route cost.

Two functions, two contracts:
  route_cost_with_schedule() — pure, no dict mutations, used inside SA loop
  build_day_schedule()       — mutates place dicts (adds travel/time fields),
                               called ONCE on the final best route

Opening-time rules:
  1. Add travel time → advance clock
  2. If place not yet open, wait (recorded as total_wait_minutes)
  3. If noon first crossed → splice lunch_break, advance clock past it
  4. Visit the place; if end_time > close_time → violation (+1000 penalty)
  5. Advance clock by buffer_minutes; next travel absorbed at step 1
"""

import datetime
import math

_AVG_SPEED_KMH    = 30.0
_DEFAULT_DURATION = 60
_EARTH_RADIUS_KM  = 6371.0
_VIOLATION_PENALTY = 1000

# Defaults shared by both functions
_DAY_START    = datetime.time(8,  0)
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


# ── Pure cost function — used inside SA, NO dict mutations ────────────────────

def route_cost_with_schedule(
    route: list[dict],
    start: dict,
    day_start:   datetime.time = _DAY_START,
    buffer:      int           = _BUFFER,
    default_dur: int           = _DEFAULT_DURATION,
    lunch_start: datetime.time = _LUNCH_START,
    lunch_dur:   int           = _LUNCH_DUR,
) -> float:
    """
    Evaluate a candidate route order for SA without mutating any place dict.
    Cost = total_travel_minutes + total_wait_minutes + violations × 1000
    """
    if not route:
        return 0.0

    current     = day_start
    had_lunch   = False
    total_cost  = 0.0
    prev        = start

    for idx, place in enumerate(route):
        # Skip travel for the first place — start_point is a derived centroid,
        # not a real departure point. From entry 2 onward, travel is between
        # two real places and is meaningful.
        if idx > 0:
            travel      = _travel_min(prev, place)
            current     = _add(current, travel)
            total_cost += travel

        # Lunch — check before opening-time wait (first natural break at noon)
        if not had_lunch and current >= lunch_start:
            had_lunch = True
            actual_lunch_start = current if current > lunch_start else lunch_start
            lunch_end = _add(actual_lunch_start, lunch_dur)
            total_cost += _mins(lunch_end) - _mins(current)
            current = lunch_end

        # Wait for opening
        open_t = _parse_hhmm(place.get("timespan"))
        if open_t and current < open_t:
            # Lunch during opening wait (arrived before noon, place opens after noon)
            if not had_lunch and _mins(open_t) > _mins(lunch_start):
                had_lunch = True
                actual_lunch_start = current if _mins(current) > _mins(lunch_start) else lunch_start
                lunch_end = _add(actual_lunch_start, lunch_dur)
                total_cost += _mins(lunch_end) - _mins(current)
                current = lunch_end
            if current < open_t:
                total_cost += _mins(open_t) - _mins(current)
                current = open_t

        # Visit
        dur = int(place.get("estimated_duration_minutes") or 0) or default_dur
        end = _add(current, dur)

        # Closing-time violation
        close_t = _parse_hhmm(place.get("timeclose"))
        if close_t and end > close_t:
            total_cost += _VIOLATION_PENALTY

        current = _add(end, buffer)
        prev    = place

    return total_cost


# ── Final schedule — mutates place dicts, called once on best route ───────────

def build_day_schedule(
    places: list[dict],
    start_point: dict,
    day_start:             datetime.time = _DAY_START,
    buffer_minutes:        int           = _BUFFER,
    default_duration_minutes: int        = _DEFAULT_DURATION,
    lunch_start:           datetime.time = _LUNCH_START,
    lunch_duration_minutes: int          = _LUNCH_DUR,
) -> dict:
    """
    Build the final time schedule for one day.

    Side effects: writes estimated_travel_minutes / start_time / end_time /
    slot / warning / type into each place dict.

    Returns:
        schedule              – chronological list of 'place' + 'lunch_break' entries
        total_travel_minutes  – sum of all inter-place travel legs
        total_wait_minutes    – sum of time spent waiting for places to open
        violation_count       – places where visit would end after closing time
    """
    if not places:
        return {
            "schedule": [], "total_travel_minutes": 0,
            "total_wait_minutes": 0, "violation_count": 0,
        }

    schedule     : list[dict]  = []
    current      : datetime.time = day_start
    had_lunch    : bool          = False
    total_travel : int           = 0
    total_wait   : int           = 0
    violations   : int           = 0
    prev                         = start_point

    for idx, place in enumerate(places):
        # ── Travel to this place ──────────────────────────────────────────────
        # First place: start_point is a centroid, not a real departure —
        # set travel = 0 so the day starts at day_start without distortion.
        # From the second place onward, both endpoints are real coordinates.
        if idx == 0:
            travel = 0
        else:
            travel = _travel_min(prev, place)
        place["estimated_travel_minutes"] = travel if travel > 0 else None
        if travel > 0:
            current = _add(current, travel)
        total_travel += travel

        # ── Splice lunch if already past noon after travel ───────────────────
        # Check BEFORE opening-time wait so lunch happens at the first natural
        # break (e.g. after Beach House ends at 12:17, not after waiting for the
        # next place to open at 15:00).
        if not had_lunch and current >= lunch_start:
            actual_lunch_start = current if current > lunch_start else lunch_start
            lunch_end = _add(actual_lunch_start, lunch_duration_minutes)
            schedule.append({
                "type":       "lunch_break",
                "start_time": _fmt(actual_lunch_start),
                "end_time":   _fmt(lunch_end),
                "slot":       "afternoon",
            })
            had_lunch = True
            current = lunch_end

        # ── Wait if not yet open ──────────────────────────────────────────────
        open_t = _parse_hhmm(place.get("timespan"))
        if open_t and current < open_t:
            # During this wait, noon might pass — handle lunch if it fits.
            if not had_lunch and _mins(open_t) > _mins(lunch_start):
                actual_lunch_start = current if _mins(current) > _mins(lunch_start) else lunch_start
                lunch_end = _add(actual_lunch_start, lunch_duration_minutes)
                schedule.append({
                    "type":       "lunch_break",
                    "start_time": _fmt(actual_lunch_start),
                    "end_time":   _fmt(lunch_end),
                    "slot":       "afternoon",
                })
                had_lunch = True
                current = lunch_end
            if current < open_t:
                wait = _mins(open_t) - _mins(current)
                total_wait += wait
                current = open_t

        # ── Visit this place ──────────────────────────────────────────────────
        dur   = int(place.get("estimated_duration_minutes") or 0) or default_duration_minutes
        start = current
        end   = _add(start, dur)

        warning: str | None = None
        close_t = _parse_hhmm(place.get("timeclose"))
        if close_t and end > close_t:
            warning = f"May close at {_fmt(close_t)} before visit ends"
            violations += 1

        place["type"]       = "place"
        place["start_time"] = _fmt(start)
        place["end_time"]   = _fmt(end)
        place["slot"]       = _slot(start)
        place["warning"]    = warning

        schedule.append(place)
        current = _add(end, buffer_minutes)
        prev    = place

    return {
        "schedule":             schedule,
        "total_travel_minutes": total_travel,
        "total_wait_minutes":   total_wait,
        "violation_count":      violations,
    }
