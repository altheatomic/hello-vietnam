import unittest

from scripts.place_content_backfill.constants import APPROVED_PROVINCES
from scripts.place_content_backfill.models import (
    BaselineRecord,
    TranslationBaseline,
)
from scripts.place_content_backfill.repository import (
    editable_hash,
    fetch_baseline,
    verify_baseline_counts,
)


class _Response:
    def __init__(self, data):
        self.data = data


class _Query:
    def __init__(self, owner, table):
        self.owner = owner
        self.table = table
        self.start = 0
        self.end = 999

    def select(self, fields):
        self.owner.calls.append((self.table, "select", fields))
        return self

    def in_(self, field, values):
        self.owner.calls.append((self.table, "in", field, tuple(values)))
        return self

    def eq(self, field, value):
        self.owner.calls.append((self.table, "eq", field, value))
        return self

    def range(self, start, end):
        self.start, self.end = start, end
        self.owner.calls.append((self.table, "range", start, end))
        return self

    def execute(self):
        rows = self.owner.rows.get(self.table, [])
        return _Response(rows[self.start : self.end + 1])


class _Supabase:
    def __init__(self, rows):
        self.rows = rows
        self.calls = []

    def table(self, table):
        return _Query(self, table)


def _translation(place_id, lang_code, name):
    return {
        "id": f"{place_id}-{lang_code}",
        "place_id": place_id,
        "lang_code": lang_code,
        "name": name,
        "description": "Short description",
        "detailed_description": None,
        "created_at": "2026-01-01T00:00:00Z",
        "updated_at": "2026-01-01T00:00:00Z",
    }


class PlaceContentRepositoryTest(unittest.TestCase):
    def test_fetches_all_pages_and_applies_allowlist_filters(self):
        province_id = APPROVED_PROVINCES[0]
        places = [
            {
                "id_place": "p1",
                "id_province": province_id,
                "status": "active",
                "name": "Place 1",
                "short_description": "Short",
                "detailed_description": None,
                "address": "Address",
                "latitude": 10.0,
                "longitude": 106.0,
                "id_place_subcategory": "s1",
                "created_at": "2026-01-01T00:00:00Z",
                "updated_at": "2026-01-01T00:00:00Z",
            },
            {
                "id_place": "p2",
                "id_province": province_id,
                "status": "inactive",
                "name": "Place 2",
                "short_description": "Short",
                "detailed_description": None,
                "address": "Address",
                "latitude": 10.1,
                "longitude": 106.1,
                "id_place_subcategory": "s1",
                "created_at": "2026-01-01T00:00:00Z",
                "updated_at": "2026-01-01T00:00:00Z",
            },
        ]
        supabase = _Supabase(
            {
                "place": places,
                "place_translation": [
                    _translation("p1", "vi", "Địa điểm 1"),
                    _translation("p1", "en", "Place 1"),
                    _translation("p2", "vi", "Địa điểm 2"),
                    _translation("p2", "en", "Place 2"),
                ],
                "place_subcategory": [
                    {"id_place_subcategory": "s1", "name": "Museum", "place_category": "Culture"}
                ],
                "place_tag": [],
                "content_freshness": [],
            }
        )
        rows = fetch_baseline(supabase, province_ids=[province_id], page_size=1)
        self.assertEqual([row.place_id for row in rows], ["p1", "p2"])
        self.assertEqual(rows[0].en.name, "Place 1")
        place_calls = [call for call in supabase.calls if call[0] == "place"]
        self.assertTrue(any(call[1:3] == ("in", "id_province") for call in place_calls))
        self.assertGreaterEqual(sum(call[1] == "range" for call in place_calls), 2)

    def test_missing_translation_fails_closed(self):
        province_id = APPROVED_PROVINCES[0]
        supabase = _Supabase(
            {
                "place": [
                    {
                        "id_place": "p1",
                        "id_province": province_id,
                        "id_place_subcategory": None,
                    }
                ],
                "place_translation": [_translation("p1", "vi", "Tên")],
                "place_subcategory": [],
                "place_tag": [],
                "content_freshness": [],
            }
        )
        with self.assertRaises(ValueError):
            fetch_baseline(supabase, province_ids=[province_id])

    def test_count_verification_rejects_incomplete_scope(self):
        record = BaselineRecord(
            place_id="p1",
            province_id=APPROVED_PROVINCES[0],
            vi=TranslationBaseline(id="v", place_id="p1", lang_code="vi"),
            en=TranslationBaseline(id="e", place_id="p1", lang_code="en"),
        )
        with self.assertRaises(ValueError):
            verify_baseline_counts([record])

    def test_editable_hash_changes_for_each_editable_field(self):
        record = BaselineRecord(
            place_id="p1",
            province_id=APPROVED_PROVINCES[0],
            name="Name",
            short_description="Short",
            detailed_description="Detail",
            created_at="created",
            updated_at="updated",
            vi=TranslationBaseline(
                id="v",
                place_id="p1",
                lang_code="vi",
                name="Tên",
                description="Mô tả",
                detailed_description="Chi tiết",
                created_at="v-created",
                updated_at="v-updated",
            ),
            en=TranslationBaseline(
                id="e",
                place_id="p1",
                lang_code="en",
                name="Name",
                description="Description",
                detailed_description="Detail",
                created_at="e-created",
                updated_at="e-updated",
            ),
        )
        baseline = editable_hash(record)
        for field, value in (
            ("name", "Name 2"),
            ("short_description", "Short 2"),
            ("detailed_description", "Detail 2"),
        ):
            self.assertNotEqual(baseline, editable_hash(record.model_copy(update={field: value})))
        self.assertEqual(baseline, editable_hash(record))


if __name__ == "__main__":
    unittest.main()
