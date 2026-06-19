"""
services/trip_planner.py
TripPlannerService – orchestrates Module 1 → 2 → 3 and formats the response.
"""

import datetime
from db.queries_places import (
    get_places_by_province,
    get_user_profile,
    get_cf_scores_for_user,
    get_place_tags,
    get_already_rated_places,
)
from db.queries_plan import save_plan

from services.module1_candidate import select_candidates
from services.module2_clustering import cluster_into_days
from services.module3_optimizer  import optimize_day_route, estimate_travel_minutes


class TripPlannerService:

    def __init__(self, conn):
        self.conn = conn

    async def plan(self,
                   id_user:     str,
                   id_province: str,
                   n_days:      int,
                   start_at:    datetime.date,
                   top_n:       int  = 40,
                   sa_runs:     int  = 5,
                   save:        bool = True) -> dict:

        conn = self.conn

        # ── Module 1: Candidate selection ────────────────────────────────────
        places        = await get_places_by_province(conn, id_province)
        user_profile  = await get_user_profile(conn, id_user)
        cf_map        = await get_cf_scores_for_user(conn, id_user, id_province)
        already_rated = await get_already_rated_places(conn, id_user)

        place_ids_all = [str(p['id_place']) for p in places]
        place_tags    = await get_place_tags(conn, place_ids_all)

        candidates = select_candidates(
            places        = places,
            user_profile  = user_profile,
            place_tags    = place_tags,
            cf_map        = cf_map,
            already_rated = already_rated,
            top_n         = top_n,
        )

        # ── Module 2: Cluster into days ───────────────────────────────────────
        clusters = cluster_into_days(candidates, n_days)

        # ── Module 3: Optimise each day's route ───────────────────────────────
        start_point = _derive_start_point(candidates)
        days        = []

        for day_number in range(1, n_days + 1):
            day_places = clusters.get(day_number, [])

            optimized = optimize_day_route(start_point, day_places, sa_runs=sa_runs)
            optimized = estimate_travel_minutes(optimized, start_point)

            days.append({
                'day':    day_number,
                'date':   str(start_at + datetime.timedelta(days=day_number - 1)),
                'places': [_format_place(p, order=i + 1)
                           for i, p in enumerate(optimized)],
            })

            if optimized:
                start_point = optimized[-1]

        # ── Persist ───────────────────────────────────────────────────────────
        id_plan = None
        if save and days:
            id_plan = await save_plan(conn, id_user, id_province,
                                      n_days, start_at, days)

        return {'id_plan': id_plan, 'days': days}


def _derive_start_point(candidates: list) -> dict:
    if not candidates:
        return {'latitude': 16.0, 'longitude': 108.0}
    avg_lat = sum(p['latitude']  for p in candidates) / len(candidates)
    avg_lon = sum(p['longitude'] for p in candidates) / len(candidates)
    return {'latitude': avg_lat, 'longitude': avg_lon}


def _format_place(place: dict, order: int) -> dict:
    return {
        'order':                    order,
        'id_place':                 str(place['id_place']),
        'name':                     place.get('name'),
        'slot':                     place.get('slot'),
        'latitude':                 place.get('latitude'),
        'longitude':                place.get('longitude'),
        'estimated_travel_minutes': place.get('estimated_travel_minutes'),
        'cb_score':                 place.get('cb_score'),
        'cf_score':                 place.get('cf_score'),
        'final_score':              place.get('final_score'),
    }
