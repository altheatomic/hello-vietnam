"""
services/module3_optimizer.py
Module 3 – Daily route optimizer.

Algorithm: Greedy nearest-neighbour init → Simulated Annealing refinement.
Distance cost: schedule-aware (travel + wait + violation penalty) via route_cost_with_schedule().
Greedy init still uses pure haversine distance (fast, directionally correct).
SA neighbour moves: swap + reverse-segment + insert.
"""

import hashlib
import math
import random

EARTH_RADIUS_KM = 6371.0


# ── Distance ──────────────────────────────────────────────────────────────────

def haversine_km(lat1, lon1, lat2, lon2) -> float:
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi       = math.radians(lat2 - lat1)
    dlambda    = math.radians(lon2 - lon1)
    a = (math.sin(dphi / 2) ** 2
         + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2)
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(a))


def _dist(a: dict, b: dict) -> float:
    return haversine_km(a['latitude'], a['longitude'], b['latitude'], b['longitude'])


# ── Pure distance cost (kept for reference / unit tests) ──────────────────────

def route_cost(start: dict, route: list) -> float:
    if not route:
        return 0.0
    total = _dist(start, route[0])
    for i in range(len(route) - 1):
        total += _dist(route[i], route[i + 1])
    return total


# ── Greedy init (pure distance — fast, directionally correct) ─────────────────

def greedy_route(start: dict, places: list) -> list:
    unvisited = places.copy()
    route, current = [], start
    while unvisited:
        nearest = min(unvisited, key=lambda p: _dist(current, p))
        route.append(nearest)
        unvisited.remove(nearest)
        current = nearest
    return route


# ── Precomputed Haversine lookup for the SA cost_fn hot path ──────────────────
#
# route_cost_with_schedule() (schedule_builder.py) is called ~I_multiplier(12)
# × n × ~87 temperature steps × sa_runs times per optimize_day_route() call,
# and each call previously re-derived every travel leg's minutes from scratch
# via _travel_min() -> _hav_km() (sin/cos/asin/sqrt). Precomputing every
# pairwise leg ONCE per optimize_day_route() call (O(n²) upfront, trivial for
# realistic day sizes) and serving the hot path from a dict lookup removes
# that repeated trig cost without touching SA's logic (cooling schedule, move
# types, cost formula) at all — only WHERE the minutes value comes from.

def _build_travel_time_lookup(
    start: dict, places: list, travel_min_fn
) -> dict[tuple[int, int], float]:
    """
    Precompute travel_min_fn(a, b) for every ordered pair drawn from
    {start} ∪ places — ONCE, before the sa_runs loop (see
    optimize_day_route()), not once per _simulated_annealing() restart.

    Keyed by (id(a), id(b)) — Python object IDENTITY, not id_place — since
    `start` is a centroid dict with no id_place (see trip_planner.py's
    _start_point_for_day()) while `places` entries do have one; identity
    works uniformly for both and needs no sentinel/placeholder key. Safe
    within the scope of a single optimize_day_route() call: every object in
    `all_points` stays alive (referenced by the `places`/`start` locals the
    caller holds for the whole call) for exactly as long as this lookup is
    used, and SA's neighbour moves (_move_swap/_move_reverse_segment/
    _move_insert) only ever reorder the route list — they never copy or
    recreate the place dicts — so the very same objects (same id()) recur
    across every candidate route this run evaluates.

    Values are travel_min_fn(a, b) itself (typically _travel_min from
    schedule_builder.py) — memoized, not reimplemented — so a lookup hit is
    guaranteed to equal what calling travel_min_fn(a, b) directly would have
    returned, no risk of the two computations drifting apart.
    """
    all_points = [start] + list(places)
    lookup: dict[tuple[int, int], float] = {}
    for a in all_points:
        for b in all_points:
            if a is b:
                continue
            lookup[(id(a), id(b))] = travel_min_fn(a, b)
    return lookup


def _make_lookup_travel_time_fn(lookup: dict[tuple[int, int], float]):
    """
    travel_time_fn for route_cost_with_schedule()'s SA hot path — O(1) dict
    lookup instead of _travel_min()'s trig calls. Same shape/contract as
    schedule_builder._travel_min() (a plain (prev, place) -> minutes
    callable), so it's a drop-in — mirrors trip_planner.py's
    _build_goong_travel_time_fn() pattern exactly (a lookup-backed
    travel_time_fn injected into the schedule/cost function), just serving
    precomputed Haversine values instead of Goong ones.
    """
    def travel_time_fn(prev: dict, place: dict) -> float:
        return lookup[(id(prev), id(place))]

    return travel_time_fn


# ── SA neighbour moves ────────────────────────────────────────────────────────

def _move_swap(route, rng: random.Random):
    i, j = rng.sample(range(len(route)), 2)
    new  = route.copy()
    new[i], new[j] = new[j], new[i]
    return new


def _move_reverse_segment(route, rng: random.Random):
    i, j = sorted(rng.sample(range(len(route)), 2))
    return route[:i] + route[i:j + 1][::-1] + route[j + 1:]


def _move_insert(route, rng: random.Random):
    n = len(route)
    i = rng.randrange(n)
    j = rng.randrange(n - 1)
    if j >= i:
        j += 1
    new   = route.copy()
    place = new.pop(i)
    new.insert(j, place)
    return new


_MOVES = [_move_swap, _move_reverse_segment, _move_insert]


# ── Simulated Annealing ───────────────────────────────────────────────────────

def _simulated_annealing(cost_fn, initial_route, rng: random.Random,
                          T_initial=1.0, T_min=0.0001,
                          alpha=0.9, I_multiplier=12):
    """
    cost_fn(route) → float  — must be pure (no side effects / dict mutations).
    Greedy init and SA moves only shuffle the list; cost_fn reads place dicts.

    rng: a random.Random instance, created once by the caller (see
    optimize_day_route()) and reused across all sa_runs restarts — NOT
    reseeded here. This keeps each restart's exploration genuinely different
    (the shared instance's internal state keeps advancing call to call)
    while still making the overall optimize_day_route() call reproducible
    for identical input, since rng's starting state is deterministic.
    """
    n = len(initial_route)
    if n <= 1:
        return initial_route

    current_route = initial_route.copy()
    current_cost  = cost_fn(current_route)
    best_route    = current_route.copy()
    best_cost     = current_cost
    T, I          = T_initial, I_multiplier * n

    while T > T_min:
        for _ in range(I):
            new_route = rng.choice(_MOVES)(current_route, rng)
            new_cost  = cost_fn(new_route)
            delta     = new_cost - current_cost

            if delta < 0:
                current_route, current_cost = new_route, new_cost
                if current_cost < best_cost:
                    best_cost, best_route = current_cost, current_route.copy()
            elif rng.random() < math.exp(-delta / T):
                current_route, current_cost = new_route, new_cost
        T *= alpha

    return best_route


# ── Public API ────────────────────────────────────────────────────────────────

def derive_seed(start: dict, places: list) -> int:
    """
    Deterministic seed from the actual optimization input — changes
    naturally whenever the place set or start point changes, so two
    different days/trips/users don't silently replay the same random
    exploration just because they happen to share a place count.

    Order-independent (sorted place IDs) so Module 2's clustering order
    doesn't affect the derived seed. Uses hashlib, NOT the built-in hash() —
    hash() on strings is randomized per-process by PYTHONHASHSEED unless
    explicitly disabled, which would silently break reproducibility across
    worker restarts/redeploys.
    """
    place_ids_sorted = sorted(str(p.get("id_place", "")) for p in places)
    seed_material = (
        f"{start.get('latitude', 0):.4f},{start.get('longitude', 0):.4f}|"
        + ",".join(place_ids_sorted)
    )
    return int(hashlib.sha256(seed_material.encode()).hexdigest(), 16) % (2**32)


def optimize_day_route(
    start: dict,
    places: list,
    sa_runs: int = 2,
    seed_override: int | None = None,
) -> tuple[list, dict]:
    """
    Returns (best_route, schedule_result).

    schedule_result is the output of build_day_schedule() applied to
    best_route — it includes 'schedule', 'total_travel_minutes',
    'total_wait_minutes', 'violation_count'.

    seed_override: optional explicit seed, mainly for callers that
    deliberately want a DIFFERENT result per call with the same (start,
    places) — e.g. test_module3_benchmark.py measuring variance across
    repeated SA runs. Production (trip_planner.py) doesn't pass this, so it
    gets the default: a seed derived from (start, places) via derive_seed(),
    making the same trip/day input always produce the same route.

    A single random.Random instance is created ONCE here, before the
    sa_runs loop, and reused (not reseeded) across every restart — so the
    sa_runs restarts still explore genuinely different neighbourhoods of the
    search space (multi-restart diversity is preserved), while the overall
    result is reproducible for identical input.

    Import is deferred (inside function) to avoid circular dependency:
      schedule_builder → (no imports from module3)
      module3_optimizer → schedule_builder

    Quick win #3 (perf audit, 2026-08-10): cost_fn draws its travel minutes
    from a Haversine lookup precomputed ONCE here (_build_travel_time_lookup,
    using schedule_builder's own _travel_min so the memoized values are
    guaranteed identical to computing them inline), instead of route_cost_
    with_schedule() re-deriving every leg via trig calls on every single
    cost_fn invocation. Pure perf change — SA's cooling schedule, move types,
    and cost formula are all untouched; only where the distance number comes
    from changed.
    """
    from services.schedule_builder import build_day_schedule, route_cost_with_schedule, _travel_min

    if not places:
        return [], build_day_schedule([], start)
    if len(places) == 1:
        return places, build_day_schedule(places, start)

    travel_time_lookup = _build_travel_time_lookup(start, places, _travel_min)
    haversine_travel_time_fn = _make_lookup_travel_time_fn(travel_time_lookup)

    def cost_fn(route: list) -> float:
        return route_cost_with_schedule(route, start, travel_time_fn=haversine_travel_time_fn)

    base_seed = seed_override if seed_override is not None else derive_seed(start, places)
    rng = random.Random(base_seed)

    initial_route = greedy_route(start, places)
    best_route    = initial_route
    best_cost     = cost_fn(initial_route)

    for _ in range(sa_runs):
        candidate = _simulated_annealing(
            cost_fn, initial_route, rng,
            T_initial=1.0, T_min=0.0001, alpha=0.9,
            I_multiplier=12,
        )
        cost = cost_fn(candidate)
        if cost < best_cost:
            best_cost, best_route = cost, candidate

    schedule_result = build_day_schedule(best_route, start_point=start)
    return best_route, schedule_result


def estimate_travel_minutes(route: list, start: dict,
                            avg_speed_kmh: float = 30.0) -> list:
    """Kept for backwards compatibility — build_day_schedule now fills this."""
    prev = start
    for place in route:
        km      = _dist(prev, place)
        minutes = round((km / avg_speed_kmh) * 60)
        place['estimated_travel_minutes'] = minutes
        prev = place
    return route
