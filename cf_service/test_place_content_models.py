import unittest
from uuid import uuid4

from scripts.place_content_backfill.constants import APPROVED_PROVINCES, EXPECTED_TOTAL
from scripts.place_content_backfill.models import (
    BaselineRecord,
    GeneratedContent,
    NameDecision,
    Proposal,
    RunManifest,
    SourceFact,
)


class PlaceContentModelsTest(unittest.TestCase):
    def test_scope_has_exact_provinces_and_total(self):
        self.assertEqual(
            APPROVED_PROVINCES,
            {
                "094014a7-b8f6-481a-bbce-5ed6cdd457c5": 539,
                "b5f3ef5e-dc49-4482-88e3-a8048cb32639": 201,
                "3355c4a1-ccb1-46be-99e5-046d5f55b891": 235,
                "8f9d18e3-7e24-4e36-bf50-a3823c1f78df": 200,
                "49fa7ad8-b892-494d-a712-bb49802200c1": 358,
            },
        )
        self.assertEqual(EXPECTED_TOTAL, 1533)

    def test_models_are_immutable_and_forbid_unknown_fields(self):
        fact = SourceFact(
            fact_id="osm:node:1:name",
            source_type="osm",
            source_url="https://www.openstreetmap.org/node/1",
            claim="A named place",
            confidence=0.9,
        )
        self.assertEqual(fact.claim, "A named place")
        with self.assertRaises((TypeError, ValueError)):
            fact.claim = "changed"
        with self.assertRaises(ValueError):
            SourceFact(
                fact_id="fact-2",
                source_type="osm",
                source_url="https://example.com",
                claim="claim",
                confidence=0.9,
                unexpected="reject me",
            )

    def test_confidence_is_bounded(self):
        with self.assertRaises(ValueError):
            SourceFact(
                fact_id="fact-low",
                source_type="osm",
                source_url="https://example.com",
                claim="claim",
                confidence=-0.01,
            )
        with self.assertRaises(ValueError):
            SourceFact(
                fact_id="fact-high",
                source_type="osm",
                source_url="https://example.com",
                claim="claim",
                confidence=1.01,
            )

    def test_manifest_rejects_outside_scope_province(self):
        with self.assertRaises(ValueError):
            RunManifest(
                run_id="20260810-120000-abcdef12",
                province_ids=("00000000-0000-0000-0000-000000000000",),
                expected_total=1,
            )

    def test_models_round_trip_json_without_losing_unicode(self):
        baseline = BaselineRecord(
            place_id=str(uuid4()),
            province_id="b5f3ef5e-dc49-4482-88e3-a8048cb32639",
            status="active",
            vi_name="Chùa Thiên Mụ",
            vi_short_description="Ngôi chùa bên sông Hương.",
            vi_detailed_description=None,
            en_name="Thien Mu Pagoda",
            en_short_description="A pagoda beside the Hương River.",
            en_detailed_description=None,
            input_hash="hash-1",
            updated_at="2026-08-10T00:00:00+00:00",
        )
        generated = GeneratedContent(
            vi_short="Một điểm đến văn hóa bên sông Hương với không gian thanh tịnh.",
            en_short="A cultural destination beside the Hương River with a tranquil setting.",
            vi_long="Không gian này gắn với tên gọi Chùa Thiên Mụ và vị trí bên sông Hương. Nội dung giới thiệu chỉ dựa trên các dữ kiện đã được ghi nhận, không suy đoán thêm về lịch sử, thời gian hay trải nghiệm.",
            en_long="This place is identified as Chùa Thiên Mụ and located beside the Hương River. This description uses only recorded evidence and avoids adding unsupported claims about history, timing, or visitor experience.",
            fact_ids=("osm:node:1:name",),
        )
        self.assertIn("Hương", generated.en_short)
        self.assertEqual(baseline.model_dump(mode="json")["vi_name"], "Chùa Thiên Mụ")

    def test_proposal_round_trip_preserves_provider_repair_provenance(self):
        proposal = Proposal(
            place_id="place-1",
            province_id="b5f3ef5e-dc49-4482-88e3-a8048cb32639",
            baseline_input_hash="hash-1",
            name_decision=NameDecision(
                place_id="place-1",
                vi_name="Chùa Thiên Mụ",
                en_name="Thien Mu Pagoda",
                confidence=0.98,
                rule_id="generic:pagoda",
            ),
            generated=GeneratedContent(
                vi_short="Một điểm đến văn hóa bên sông Hương với không gian thanh tịnh.",
                en_short="A cultural destination beside the Hương River with a tranquil setting.",
                vi_long="Nội dung giới thiệu này chỉ sử dụng các dữ kiện đã được ghi nhận về địa điểm và không thêm suy đoán ngoài nguồn.",
                en_long="This description uses only recorded facts about the place and does not add unsupported assumptions beyond the sources.",
                fact_ids=("osm:node:1:name",),
            ),
            provider_models=("deepseek-v4-flash", "deepseek-v4-pro"),
            repair_used=True,
        )
        restored = Proposal.model_validate(proposal.model_dump(mode="json"))
        self.assertEqual(restored.provider_models, ("deepseek-v4-flash", "deepseek-v4-pro"))
        self.assertTrue(restored.repair_used)


if __name__ == "__main__":
    unittest.main()
