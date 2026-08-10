import unittest

from pydantic import ValidationError

from scripts.place_content_backfill.constants import (
    APPROVED_PROVINCES,
    EXPECTED_TOTAL,
    MAX_APPLY_BATCH_SIZE,
)
from scripts.place_content_backfill.models import GeneratedContent, RunManifest


class PlaceContentModelsTest(unittest.TestCase):
    def test_scope_is_exactly_the_five_provinces(self):
        self.assertEqual(
            set(APPROVED_PROVINCES),
            {
                "094014a7-b8f6-481a-bbce-5ed6cdd457c5",
                "b5f3ef5e-dc49-4482-88e3-a8048cb32639",
                "3355c4a1-ccb1-46be-99e5-046d5f55b891",
                "8f9d18e3-7e24-4e36-bf50-a3823c1f78df",
                "49fa7ad8-b892-494d-a712-bb49802200c1",
            },
        )
        self.assertEqual(EXPECTED_TOTAL, 1533)
        self.assertEqual(MAX_APPLY_BATCH_SIZE, 50)

    def test_generated_content_is_immutable_and_forbids_unknown_fields(self):
        content = GeneratedContent(
            short_description_vi="Mô tả ngắn đủ rõ.",
            detailed_description_vi="Mô tả dài có thông tin được kiểm chứng.",
            short_description_en="A concise description.",
            detailed_description_en="A grounded longer description.",
            used_fact_ids=["osm.type"],
            warnings=[],
            confidence=0.92,
        )
        with self.assertRaises(ValidationError):
            GeneratedContent(**{**content.model_dump(), "unexpected": True})
        with self.assertRaises(ValidationError):
            GeneratedContent(**{**content.model_dump(), "confidence": 1.1})
        with self.assertRaises((TypeError, ValidationError)):
            content.short_description_vi = "changed"

    def test_manifest_rejects_unknown_province(self):
        with self.assertRaises(ValueError):
            RunManifest.new(["not-an-approved-province"])

    def test_manifest_accepts_exact_scope(self):
        manifest = RunManifest.new(list(APPROVED_PROVINCES))
        self.assertEqual(manifest.expected_total, EXPECTED_TOTAL)
        self.assertEqual(set(manifest.province_ids), set(APPROVED_PROVINCES))


if __name__ == "__main__":
    unittest.main()
