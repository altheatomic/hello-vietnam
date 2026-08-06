"""Unit tests for Module 2 accommodation-zone recommendations."""

import unittest

from services.accommodation_recommendation import build_accommodation_recommendation
from services.module2_algorithm import build_module2_result


def _day(day: int, centroid):
    return {
        "day": day,
        "date": f"2026-08-{day:02d}",
        "centroid": centroid,
        "places": [],
    }


def _synthetic_places():
    return [
        {
            "id_place": f"place-{index}",
            "name": f"Place {index}",
            "latitude": 21.02 + (index % 3) * 0.01,
            "longitude": 105.84 + (index // 3) * 0.01,
            "module1_score": 1.0 - index * 0.01,
            "estimated_duration_minutes": 60,
            "average_rating": 4.5,
            "review_count": 100,
            "place_subcategory": {
                "name": "Museum",
                "is_itinerary_eligible": True,
                "place_category": "Culture",
            },
        }
        for index in range(12)
    ]


class AccommodationRecommendationTests(unittest.TestCase):
    def test_short_trip_always_returns_one_zone(self):
        result = build_accommodation_recommendation([
            _day(1, (21.02, 105.84)),
            _day(2, (21.03, 105.85)),
            _day(3, (21.04, 105.86)),
        ])

        self.assertEqual(result["strategy"], "single_zone")
        self.assertEqual(len(result["zones"]), 1)
        self.assertEqual(
            (result["zones"][0]["day_from"], result["zones"][0]["day_to"]),
            (1, 3),
        )

    def test_missing_day_centroid_returns_none_without_crashing(self):
        self.assertIsNone(build_accommodation_recommendation([
            _day(1, None),
            _day(2, (21.0, 105.8)),
        ]))

    def test_separated_seven_day_trip_returns_two_contiguous_zones(self):
        result = build_accommodation_recommendation([
            _day(1, (21.02, 105.84)),
            _day(2, (21.03, 105.85)),
            _day(3, (21.04, 105.86)),
            _day(4, (20.85, 106.60)),
            _day(5, (20.86, 106.61)),
            _day(6, (20.87, 106.62)),
            _day(7, (20.88, 106.63)),
        ])

        self.assertEqual(result["strategy"], "multi_zone")
        self.assertEqual(
            [(zone["day_from"], zone["day_to"]) for zone in result["zones"]],
            [(1, 3), (4, 7)],
        )

    def test_distance_under_threshold_keeps_one_zone(self):
        result = build_accommodation_recommendation([
            _day(1, (21.02, 105.84)),
            _day(2, (21.03, 105.85)),
            _day(3, (21.04, 105.86)),
            _day(4, (21.12, 106.20)),
            _day(5, (21.13, 106.21)),
        ])

        self.assertEqual(result["strategy"], "single_zone")

    def test_cost_reduction_under_threshold_keeps_one_zone(self):
        result = build_accommodation_recommendation(
            [
                _day(1, (21.02, 105.84)),
                _day(2, (21.03, 105.85)),
                _day(3, (21.04, 105.86)),
                _day(4, (20.85, 106.60)),
                _day(5, (20.86, 106.61)),
            ],
            min_zone_separation_km=1.0,
            min_cost_reduction_ratio=0.99,
        )

        self.assertEqual(result["strategy"], "single_zone")

    def test_module2_result_contains_accommodation_recommendation(self):
        result = build_module2_result(
            _synthetic_places(),
            "2026-08-01",
            "2026-08-03",
            "balanced",
        )

        self.assertIn("accommodation_recommendation", result)
