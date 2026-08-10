import unittest

from routes.recommend import _get_recommended_place_sync, _place_response


class _Response:
    def __init__(self, data):
        self.data = data


class _Query:
    def __init__(self, owner):
        self.owner = owner

    def select(self, fields):
        self.owner.selects.append(fields)
        return self

    def eq(self, field, value):
        self.owner.filters.append((field, value))
        return self

    def limit(self, value):
        return self

    def execute(self):
        return _Response(self.owner.rows)


class _Supabase:
    def __init__(self):
        self.selects = []
        self.filters = []
        self.rows = [
            {
                "id_place": "p1",
                "name": "Huong River",
                "short_description": "Short copy",
                "detailed_description": "Long copy",
                "place_subcategory": {"name": "River"},
            }
        ]

    def table(self, _name):
        return _Query(self)


class RecommendPlaceDetailTest(unittest.TestCase):
    def test_card_response_does_not_carry_long_copy(self):
        response = _place_response({"id_place": "p1", "name": "Huong River", "detailed_description": "Long"})
        self.assertNotIn("detailed_description", response)

    def test_detail_response_maps_long_copy_and_selects_it(self):
        supabase = _Supabase()
        result = _get_recommended_place_sync(supabase, "p1")
        self.assertEqual(result["place"]["detailed_description"], "Long copy")
        self.assertIn("detailed_description", supabase.selects[0])


if __name__ == "__main__":
    unittest.main()
