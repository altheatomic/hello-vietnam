import unittest

from db.place_repository import remove_freshness_ineligible_places


class _Response:
    def __init__(self, data):
        self.data = data


class _Query:
    def __init__(self, rows):
        self.rows = rows

    def select(self, *_args, **_kwargs):
        return self

    def eq(self, *_args, **_kwargs):
        return self

    def in_(self, *_args, **_kwargs):
        return self

    def execute(self):
        return _Response(self.rows)


class _Supabase:
    def __init__(self, freshness_rows):
        self.freshness_rows = freshness_rows

    def table(self, name):
        self.last_table = name
        return _Query(self.freshness_rows)


class DataFreshnessEligibilityTest(unittest.TestCase):
    def test_removes_needs_review_and_expired_but_keeps_stale_and_missing(self):
        places = [
            {"id_place": "fresh"},
            {"id_place": "review"},
            {"id_place": "expired"},
            {"id_place": "stale"},
            {"id_place": "legacy"},
        ]
        supabase = _Supabase([
            {"content_id": "fresh", "freshness_status": "fresh"},
            {"content_id": "review", "freshness_status": "needs_review"},
            {"content_id": "expired", "freshness_status": "expired"},
            {"content_id": "stale", "freshness_status": "stale"},
        ])
        result = remove_freshness_ineligible_places(supabase, places)
        self.assertEqual(
            [place["id_place"] for place in result],
            ["fresh", "stale", "legacy"],
        )


if __name__ == "__main__":
    unittest.main()
