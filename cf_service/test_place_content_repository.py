import unittest
from dataclasses import dataclass

from scripts.place_content_backfill.constants import APPROVED_PROVINCES, EXPECTED_TOTAL
from scripts.place_content_backfill.repository import (
    BaselineIntegrityError,
    applied_content_hash,
    editable_hash,
    fetch_baseline,
    verify_baseline_counts,
)


@dataclass
class Response:
    data: list[dict]


class FakeQuery:
    def __init__(self, client, table):
        self.client = client
        self.table = table
        self.filters = []
        self.range_args = None
        self.fields = None

    def select(self, fields):
        self.fields = fields
        return self

    def in_(self, field, values):
        self.filters.append(("in", field, tuple(values)))
        return self

    def eq(self, field, value):
        self.filters.append(("eq", field, value))
        return self

    def range(self, start, end):
        self.range_args = (start, end)
        return self

    def execute(self):
        self.client.queries.append(self)
        return Response(self.client.rows_for(self))


class FakeClient:
    def __init__(self, places, translations, freshness=None, subcategories=None, tags=None):
        self.places = places
        self.translations = translations
        self.freshness = freshness or []
        self.subcategories = subcategories or []
        self.tags = tags or []
        self.queries = []

    def table(self, table):
        return FakeQuery(self, table)

    def rows_for(self, query):
        if query.table == "place":
            province_filter = next(
                values for kind, field, values in query.filters
                if kind == "in" and field == "id_province"
            )
            rows = [row for row in self.places if row["id_province"] in province_filter]
            start, end = query.range_args
            return rows[start:end + 1]
        values = next(
            values for kind, field, values in query.filters if kind == "in"
        )
        if query.table == "place_translation":
            return [row for row in self.translations if row["place_id"] in values]
        if query.table == "content_freshness":
            return [row for row in self.freshness if row["content_id"] in values]
        if query.table == "place_subcategory":
            return [row for row in self.subcategories if row["id_place_subcategory"] in values]
        if query.table == "place_tag":
            return [row for row in self.tags if row["id_place"] in values]
        raise AssertionError(f"unexpected table {query.table}")


def place_row(place_id="place-1", province_id=None, subcategory_id="sub-1"):
    return {
        "id_place": place_id,
        "id_province": province_id or next(iter(APPROVED_PROVINCES)),
        "id_place_subcategory": subcategory_id,
        "name": "Tên tiếng Việt",
        "short_description": "Mô tả ngắn",
        "detailed_description": None,
        "status": "active",
        "address": "Địa chỉ",
        "latitude": 10.0,
        "longitude": 106.0,
        "source": "osm",
        "source_place_id": "osm:node:1",
        "website": None,
        "updated_at": "2026-08-10T00:00:00+00:00",
    }


def translations_for(place_id="place-1", include_en=True, include_vi=True):
    rows = []
    if include_vi:
        rows.append({
            "id": f"{place_id}-vi",
            "place_id": place_id,
            "lang_code": "vi",
            "name": "Tên tiếng Việt",
            "description": "Mô tả ngắn",
            "detailed_description": None,
            "updated_at": "2026-08-10T00:00:00+00:00",
        })
    if include_en:
        rows.append({
            "id": f"{place_id}-en",
            "place_id": place_id,
            "lang_code": "en",
            "name": "English Name",
            "description": "Short description",
            "detailed_description": None,
            "updated_at": "2026-08-10T00:00:00+00:00",
        })
    return rows


class PlaceContentRepositoryTest(unittest.TestCase):
    def test_fetch_baseline_reads_all_pages_and_batches_related_ids(self):
        places = [
            place_row(f"place-{i}", province_id=next(iter(APPROVED_PROVINCES)))
            for i in range(203)
        ]
        translations = [translation for i in range(203) for translation in translations_for(f"place-{i}")]
        client = FakeClient(
            places,
            translations,
            subcategories=[{"id_place_subcategory": "sub-1", "name": "Chùa", "place_category": "culture"}],
        )

        records = list(fetch_baseline(client, province_ids=tuple(APPROVED_PROVINCES)))

        self.assertEqual(len(records), 203)
        place_queries = [query for query in client.queries if query.table == "place"]
        self.assertEqual([query.range_args for query in place_queries], [(0, 499)])
        for query in client.queries:
            filter_fields = {entry[1] for entry in query.filters if entry[0] == "in"}
            if query.table == "place":
                self.assertIn("id_province", filter_fields)
            else:
                self.assertTrue(filter_fields.intersection({"place_id", "content_id", "id_place_subcategory", "id_place"}))
        related_queries = [query for query in client.queries if query.table != "place"]
        self.assertTrue(related_queries)
        self.assertLessEqual(
            max(len(entry[2]) for query in related_queries for entry in query.filters if entry[0] == "in"),
            200,
        )

    def test_missing_or_duplicate_language_rows_fail(self):
        place = place_row()
        missing_en = FakeClient([place], translations_for(include_en=False))
        with self.assertRaises(BaselineIntegrityError):
            list(fetch_baseline(missing_en, province_ids=(place["id_province"],)))

        duplicate_vi = FakeClient(
            [place],
            translations_for() + [dict(translations_for()[0], id="place-1-vi-duplicate")],
        )
        with self.assertRaises(BaselineIntegrityError):
            list(fetch_baseline(duplicate_vi, province_ids=(place["id_province"],)))

    def test_exact_scope_counts_reject_1532_rows(self):
        records = [
            {"place_id": f"place-{i}", "province_id": next(iter(APPROVED_PROVINCES))}
            for i in range(EXPECTED_TOTAL - 1)
        ]
        with self.assertRaises(BaselineIntegrityError):
            verify_baseline_counts(records)

    def test_editable_hash_includes_timestamps_and_content_hash_excludes_them(self):
        record = place_row()
        record.update(
            {
                "vi_name": "Tên tiếng Việt",
                "vi_short_description": "Mô tả ngắn",
                "vi_detailed_description": None,
                "en_name": "English Name",
                "en_short_description": "Short description",
                "en_detailed_description": None,
                "translation_updated_at_vi": "2026-08-10T00:00:00+00:00",
                "translation_updated_at_en": "2026-08-10T00:00:00+00:00",
            }
        )
        baseline_hash = editable_hash(record)
        content_hash = applied_content_hash(record)
        changed_timestamp = dict(record, updated_at="2026-08-11T00:00:00+00:00")
        changed_content = dict(record, vi_short_description="Mô tả đã thay đổi")
        self.assertNotEqual(baseline_hash, editable_hash(changed_timestamp))
        self.assertEqual(content_hash, applied_content_hash(changed_timestamp))
        self.assertNotEqual(content_hash, applied_content_hash(changed_content))


if __name__ == "__main__":
    unittest.main()
