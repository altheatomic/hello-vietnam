"""
services/module3_optimizer.py
Module 3 – Daily route optimizer.

Algorithm: Greedy nearest-neighbour init → Simulated Annealing refinement.
Distance cost: schedule-aware (travel + wait + violation penalty) via route_cost_with_schedule().
Greedy init still uses pure haversine distance (fast, directionally correct).
SA neighbour moves: swap + reverse-segment + insert.
"""

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


# ── SA neighbour moves ────────────────────────────────────────────────────────

def _move_swap(route):
    i, j = random.sample(range(len(route)), 2)
    new  = route.copy()
    new[i], new[j] = new[j], new[i]
    return new


def _move_reverse_segment(route):
    i, j = sorted(random.sample(range(len(route)), 2))
    return route[:i] + route[i:j + 1][::-1] + route[j + 1:]


def _move_insert(route):
    n = len(route)
    i = random.randrange(n)
    j = random.randrange(n - 1)
    if j >= i:
        j += 1
    new   = route.copy()
    place = new.pop(i)
    new.insert(j, place)
    return new


_MOVES = [_move_swap, _move_reverse_segment, _move_insert]


# ── Simulated Annealing ───────────────────────────────────────────────────────

def _simulated_annealing(cost_fn, initial_route,
                          T_initial=1.0, T_min=0.0001,
                          alpha=0.9, I_multiplier=12, seed=None):
    """
    cost_fn(route) → float  — must be pure (no side effects / dict mutations).
    Greedy init and SA moves only shuffle the list; cost_fn reads place dicts.
    """
    if seed is not None:
        random.seed(seed)

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
            new_route = random.choice(_MOVES)(current_route)
            new_cost  = cost_fn(new_route)
            delta     = new_cost - current_cost

            if delta < 0:
                current_route, current_cost = new_route, new_cost
                if current_cost < best_cost:
                    best_cost, best_route = current_cost, current_route.copy()
            elif random.random() < math.exp(-delta / T):
                current_route, current_cost = new_route, new_cost
        T *= alpha

    return best_route


# ── Public API ────────────────────────────────────────────────────────────────

def optimize_day_route(
    start: dict,
    places: list,
    sa_runs: int = 2,
) -> tuple[list, dict]:
    """
    Returns (best_route, schedule_result).

    schedule_result is the output of build_day_schedule() applied to
    best_route — it includes 'schedule', 'total_travel_minutes',
    'total_wait_minutes', 'violation_count'.

    Import is deferred (inside function) to avoid circular dependency:
      schedule_builder → (no imports from module3)
      module3_optimizer → schedule_builder
    """
    from services.schedule_builder import build_day_schedule, route_cost_with_schedule

    if not places:
        return [], build_day_schedule([], start)
    if len(places) == 1:
        return places, build_day_schedule(places, start)

    def cost_fn(route: list) -> float:
        return route_cost_with_schedule(route, start)

    initial_route = greedy_route(start, places)
    best_route    = initial_route
    best_cost     = cost_fn(initial_route)

    for seed in range(sa_runs):
        candidate = _simulated_annealing(
            cost_fn, initial_route,
            T_initial=1.0, T_min=0.0001, alpha=0.9,
            I_multiplier=12, seed=seed,
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
