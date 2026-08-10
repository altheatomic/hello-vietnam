import unittest

from scripts.place_content_backfill.constants import APPROVED_PROVINCES
from scripts.place_content_backfill.models import (
    BaselineRecord,
    SourceFact,
    SourceSnapshot,
    TranslationBaseline,
)
from scripts.place_content_backfill.naming import normalize_names


def _record(name: str, *, category: str | None = None, subcategory: str | None = None) -> BaselineRecord:
    return BaselineRecord(
        place_id="place-1",
        province_id=APPROVED_PROVINCES[0],
        name=name,
        subcategory_category=category,
        subcategory_name=subcategory,
        vi=TranslationBaseline(id="vi-1", place_id="place-1", lang_code="vi", name=name),
        en=TranslationBaseline(id="en-1", place_id="place-1", lang_code="en", name=None),
    )


def _sources(*facts: SourceFact) -> SourceSnapshot:
    return SourceSnapshot(place_id="place-1", facts=tuple(facts))


class PlaceContentNamingTest(unittest.TestCase):
    def test_approved_regression_cases(self):
        cases = (
            ("Sông Hương", "Hương River"),
            ("Chùa Thiên Mụ", "Thiên Mụ Pagoda"),
            ("Chợ Bến Thành", "Bến Thành Market"),
            ("Núi Bà Đen", "Bà Đen Mountain"),
            ("Bánh Mì Phượng", "Bánh Mì Phượng"),
            ("Nhà Thờ Họ Đạo Cái Cấm", "Cái Cấm Parish Church"),
        )
        for vietnamese, english in cases:
            with self.subTest(vietnamese=vietnamese):
                decision = normalize_names(_record(vietnamese), _sources())
                self.assertEqual(decision.vietnamese_name, vietnamese)
                self.assertEqual(decision.english_name, english)

    def test_literal_translation_and_protected_tokens_are_rejected(self):
        river = normalize_names(_record("Sông Hương"), _sources())
        church = normalize_names(_record("Nhà Thờ Họ Đạo Cái Cấm"), _sources())
        personal = normalize_names(_record("Bề Bề Nội"), _sources())
        self.assertNotEqual(river.english_name, "Perfume River")
        self.assertNotIn("Forbidden", church.english_name)
        self.assertNotIn("Interior Surface", personal.english_name)

    def test_source_priority_rejects_bad_osm_english_and_accepts_verified_official_name(self):
        facts = _sources(
            SourceFact(fact_id="osm.name_vi", value="Sông Hương", source_url="https://www.openstreetmap.org/way/1", source_kind="osm"),
            SourceFact(fact_id="osm.name_en", value="Perfume River", source_url="https://www.openstreetmap.org/way/1", source_kind="osm"),
            SourceFact(fact_id="official.name", value="Huong River", source_url="https://example.com", source_kind="official_site"),
        )
        decision = normalize_names(_record("Sông Hương"), facts)
        self.assertEqual(decision.vietnamese_name, "Sông Hương")
        self.assertEqual(decision.english_name, "Huong River")
        self.assertIn("Perfume River", decision.rejected_alternatives)

    def test_longest_generic_match_and_context(self):
        church = normalize_names(_record("Nhà Thờ Giáo Xứ Tân Định"), _sources())
        museum = normalize_names(_record("Bảo Tàng Lịch Sử"), _sources())
        restaurant = normalize_names(_record("Sông Tiền", category="Food", subcategory="Restaurant"), _sources())
        river = normalize_names(_record("Sông Tiền", category="Nature", subcategory="River"), _sources())
        self.assertEqual(church.english_name, "Tân Định Parish Church")
        self.assertEqual(museum.english_name, "Lịch Sử Museum")
        self.assertEqual(restaurant.english_name, "Sông Tiền")
        self.assertEqual(river.english_name, "Tiền River")

    def test_unmatched_tokens_digits_acronyms_and_brands_survive(self):
        decision = normalize_names(_record("Bánh Mì Phượng 24/7"), _sources())
        self.assertEqual(decision.english_name, "Bánh Mì Phượng 24/7")
        branded = normalize_names(_record("VinFast", category="Transport"), _sources())
        self.assertEqual(branded.english_name, "VinFast")

    def test_name_vi_source_wins_when_identity_matches(self):
        sources = _sources(
            SourceFact(
                fact_id="osm.name_vi",
                value="Địa danh chính thức",
                source_url="https://www.openstreetmap.org/node/123",
                source_kind="osm",
            ),
        )
        decision = normalize_names(_record("Tên cũ"), sources)
        self.assertEqual(decision.vietnamese_name, "Tên cũ")
        self.assertIn("name:vi identity mismatch", decision.warnings)


if __name__ == "__main__":
    unittest.main()
