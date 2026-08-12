import unittest

from routes.recommend import (
    _get_recommended_place_sync,
    _place_detail_response,
    _place_response,
)


class Response:
    def __init__(self, data):
        self.data = data


class FakeQuery:
    def __init__(self, rows):
        self.rows = rows
        self.fields = ""
        self.filters = []

    def select(self, fields):
        self.fields = fields
        return self

    def eq(self, field, value):
        self.filters.append((field, value))
        return self

    def limit(self, value):
        return self

    def execute(self):
        return Response(self.rows)


class FakeSupabase:
    def __init__(self, rows):
        self.query = FakeQuery(rows)

    def table(self, table):
        self.table_name = table
        return self.query


class RecommendPlaceDetailTest(unittest.TestCase):
    def row(self):
        return {
            "id_place": "place-detail-1",
            "name": "Thiên Mụ Pagoda",
            "short_description": "A short description.",
            "detailed_description": "A grounded long description for the individual detail page.",
            "address": "Huế",
            "place_subcategory": {"name": "Pagoda"},
        }

    def test_card_response_does_not_expose_detailed_description(self):
        response = _place_response(self.row())
        self.assertNotIn("detailed_description", response)

    def test_detail_response_exposes_detailed_description(self):
        response = _place_detail_response(self.row())
        self.assertEqual(
            response["detailed_description"],
            "A grounded long description for the individual detail page.",
        )

    def test_detail_query_selects_long_description_but_card_shape_stays_isolated(self):
        supabase = FakeSupabase([self.row()])
        result = _get_recommended_place_sync(supabase, "place-detail-1")
        self.assertEqual(
            result["place"]["detailed_description"],
            "A grounded long description for the individual detail page.",
        )
        self.assertIn("detailed_description", supabase.query.fields)
        self.assertNotIn("detailed_description", _place_response(self.row()))


if __name__ == "__main__":
    unittest.main()
