"""
services/schedule_builder.py
Build a realistic time schedule for one day's ordered route.

Input : list of place dicts from Module 3 — already sorted by route order,
        already have estimated_travel_minutes (travel FROM previous stop).
Output: same places mutated in-place with start_time / end_time / slot /
        warning added, PLUS lunch_break dicts spliced in at the right
        position.  Returns the new (possibly longer) list.

Each output entry has a 'type' field: 'place' | 'lunch_break'.
"""

import datetime


_DEFAULT_DURATION = 60    # minutes — fallback when field is missing / 0
_SLOT_THRESHOLDS  = (
    (datetime.time(12, 0), "morning"),
    (datetime.time(17, 0), "afternoon"),
)


def _parse_hhmm(s: str | None) -> datetime.time | None:
    if not s:
        return None
    try:
        return datetime.datetime.strptime(s.strip()[:5], "%H:%M").time()
    except (ValueError, AttributeError):
        return None


def _add_minutes(t: datetime.time, minutes: int) -> datetime.time:
    base = datetime.datetime.combine(datetime.date.today(), t)
    return (base + datetime.timedelta(minutes=minutes)).time()


def _fmt(t: datetime.time) -> str:
    return t.strftime("%H:%M")


def _slot(t: datetime.time) -> str:
    for threshold, label in _SLOT_THRESHOLDS:
        if t < threshold:
            return label
    return "evening"


def build_day_schedule(
    places: list[dict],
    day_start: datetime.time            = datetime.time(8, 0),
    buffer_minutes: int                 = 15,
    default_duration_minutes: int       = _DEFAULT_DURATION,
    lunch_start: datetime.time          = datetime.time(12, 0),
    lunch_duration_minutes: int         = 90,
) -> list[dict]:
    """
    Assign start_time / end_time / slot / warning to each place and splice in
    a lunch_break when the schedule crosses 12:00.

    Returns: list that may include 'lunch_break' entries between places.
    """
    if not places:
        return []

    result:     list[dict] = []
    current:    datetime.time = day_start
    had_lunch:  bool = False

    for place in places:
        # ── Advance clock by travel time to this place ────────────────────────
        travel = int(place.get("estimated_travel_minutes") or 0)
        current = _add_minutes(current, travel)

        # ── Splice lunch break before this place if noon has passed ──────────
        if not had_lunch and current >= lunch_start:
            lunch_end = _add_minutes(lunch_start, lunch_duration_minutes)
            result.append({
                "type":       "lunch_break",
                "start_time": _fmt(lunch_start),
                "end_time":   _fmt(lunch_end),
                "slot":       "afternoon",
            })
            had_lunch = True
            if current < lunch_end:
                current = lunch_end

        # ── Schedule this place ───────────────────────────────────────────────
        duration = int(place.get("estimated_duration_minutes") or 0)
        if duration <= 0:
            duration = default_duration_minutes

        start = current
        end   = _add_minutes(start, duration)

        # Warning: visit may run past closing time
        warning: str | None = None
        close = _parse_hhmm(place.get("timeclose"))
        if close and end > close:
            warning = f"May close at {_fmt(close)} before visit ends"

        place["type"]       = "place"
        place["start_time"] = _fmt(start)
        place["end_time"]   = _fmt(end)
        place["slot"]       = _slot(start)
        place["warning"]    = warning

        result.append(place)

        # ── Advance clock: visit done + buffer (travel absorbed next loop) ────
        current = _add_minutes(end, buffer_minutes)

    return result
