"""Regression test for accommodation recommendations on saved-plan reload."""

import unittest

from db.queries_plan import get_plan


class _Response:
    def __init__(self, data):
        self.data = data


class _Query:
    def __init__(self, table_name, rows):
        self.table_name = table_name
        self.rows = rows

    def select(self, *_args, **_kwargs):
        return self

    def eq(self, *_args, **_kwargs):
        return self

    def limit(self, *_args, **_kwargs):
        return self

    def order(self, *_args, **_kwargs):
        return self

    def in_(self, *_args, **_kwargs):
        return self

    def execute(self):
        return _Response(self.rows)


class _Supabase:
    def __init__(self, tables):
        self.tables = tables

    def table(self, table_name):
        return _Query(table_name, self.tables.get(table_name, []))


def _saved_plan_supabase():
    coordinates = [
        (21.02, 105.84),
        (21.03, 105.85),
        (21.04, 105.86),
        (20.85, 106.60),
        (20.86, 106.61),
        (20.87, 106.62),
        (20.88, 106.63),
    ]
    component_rows = []
    place_rows = []
    for day, (latitude, longitude) in enumerate(coordinates, start=1):
        place_id = f"place-{day}"
        component_rows.append({
            "day": day,
            "slot": "morning",
            "visit_order": 1,
            "start_time": "08:00",
            "end_time": "09:00",
            "estimated_travel_minutes": 10,
            "cb_score": 0.8,
            "cf_score": 0.7,
            "final_score": 0.75,
            "id_place": place_id,
        })
        place_rows.append({
            "id_place": place_id,
            "name": f"Place {day}",
            "latitude": latitude,
            "longitude": longitude,
            "cover_image": None,
            "gallery": [],
            "estimated_duration_minutes": 60,
            "minimum_price": None,
            "maximum_price": None,
            "timespan": None,
            "timeclose": None,
        })

    return _Supabase({
        "plan": [{
            "id_plan": "plan-1",
            "custom_title": "Test plan",
            "duration": "7",
            "start_at": "2026-08-01",
            "end_at": "2026-08-07",
            "city_province": "province-1",
            "created_at": "2026-08-01T00:00:00+00:00",
        }],
        "plan_component": component_rows,
        "place_localized_en": place_rows,
    })


class SavedPlanAccommodationTests(unittest.TestCase):
    def test_get_plan_includes_recommendation_for_saved_itinerary(self):
        result = get_plan(_saved_plan_supabase(), "plan-1", id_user="user-1")

        self.assertEqual(
            result["accommodation_recommendation"]["strategy"],
            "multi_zone",
        )
        self.assertEqual(
            [
                (zone["day_from"], zone["day_to"])
                for zone in result["accommodation_recommendation"]["zones"]
            ],
            [(1, 3), (4, 7)],
        )
