import unittest

from scripts.place_content_backfill.models import BaselineRecord, SourceFact, SourceSnapshot
from scripts.place_content_backfill.naming import normalize_names


CASES = [
    ("Sông Hương", "Hương River"),
    ("Chùa Thiên Mụ", "Thiên Mụ Pagoda"),
    ("Chợ Bến Thành", "Bến Thành Market"),
    ("Núi Bà Đen", "Bà Đen Mountain"),
    ("Bánh Mì Phượng", "Bánh Mì Phượng"),
    ("Nhà Thờ Họ Đạo Cái Cấm", "Cái Cấm Parish Church"),
]


def record(name: str, **overrides) -> BaselineRecord:
    values = {
        "place_id": "place-1",
        "province_id": "b5f3ef5e-dc49-4482-88e3-a8048cb32639",
        "status": "active",
        "vi_name": name,
        "vi_short_description": "Mô tả",
        "input_hash": "hash",
        "subcategory_name": "Culture",
        "subcategory_category": "culture",
    }
    values.update(overrides)
    return BaselineRecord(**values)


def snapshot(*facts: SourceFact) -> SourceSnapshot:
    return SourceSnapshot(
        place_id="place-1",
        baseline_input_hash="hash",
        facts=facts,
    )


class PlaceContentNamingTest(unittest.TestCase):
    def test_approved_regressions_preserve_proper_name_tokens(self):
        for vietnamese_name, expected_english_name in CASES:
            with self.subTest(vietnamese_name=vietnamese_name):
                decision = normalize_names(record(vietnamese_name), snapshot())
                self.assertEqual(decision.en_name, expected_english_name)
                self.assertGreaterEqual(decision.confidence, 0.85)
                self.assertFalse(decision.review_only)

    def test_longest_first_mapping_wins(self):
        decision = normalize_names(record("Nhà Thờ Giáo Xứ Cái Cấm"), snapshot())
        self.assertEqual(decision.en_name, "Cái Cấm Parish Church")
        self.assertNotIn("Parish Church Parish Church", decision.en_name)

    def test_prefix_match_is_case_insensitive_but_slices_original_unicode(self):
        decision = normalize_names(record("sÔNG Hương"), snapshot())
        self.assertEqual(decision.en_name, "Hương River")

    def test_brand_like_name_stays_unchanged_without_geographic_evidence(self):
        decision = normalize_names(
            record("Sông Xanh", subcategory_name="Nhà hàng", subcategory_category="food"),
            snapshot(),
        )
        self.assertEqual(decision.en_name, "Sông Xanh")
        self.assertTrue(decision.review_only)

    def test_geographic_brand_like_name_requires_corroborated_osm_type(self):
        evidence = SourceFact(
            fact_id="osm:node:1:natural",
            source_type="osm",
            source_url="https://www.openstreetmap.org/node/1",
            claim="natural=water",
            confidence=0.95,
            value="water",
        )
        decision = normalize_names(
            record("Sông Xanh", subcategory_name="Nhà hàng", subcategory_category="food"),
            snapshot(evidence),
        )
        self.assertEqual(decision.en_name, "Xanh River")
        self.assertFalse(decision.review_only)

    def test_unknown_generic_prefix_is_review_only(self):
        decision = normalize_names(record("Khu Du Lịch Bà Nà"), snapshot())
        self.assertEqual(decision.en_name, "Khu Du Lịch Bà Nà")
        self.assertTrue(decision.review_only)
        self.assertLess(decision.confidence, 0.85)

    def test_ambiguous_official_override_is_review_only(self):
        evidence = SourceFact(
            fact_id="official:1:name",
            source_type="official_site",
            source_url="https://example.org",
            claim="Official English name: Ba Na Hills",
            confidence=0.99,
            value="Ba Na Hills",
        )
        decision = normalize_names(record("Núi Bà Nà"), snapshot(evidence))
        self.assertEqual(decision.en_name, "Bà Nà Mountain")
        self.assertTrue(decision.review_only)
        self.assertIn("official", " ".join(decision.warnings).lower())


if __name__ == "__main__":
    unittest.main()
