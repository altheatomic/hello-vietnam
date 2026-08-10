import os
from contextlib import redirect_stdout
from io import StringIO
import tempfile
import unittest
from pathlib import Path

from scripts.place_content_backfill.artifacts import ArtifactStore
from scripts.place_content_backfill.cli import main
from scripts.place_content_backfill.models import (
    BaselineRecord,
    GeneratedContent,
    NameDecision,
    Proposal,
    ReviewDecision,
    SourceFact,
    SourceSnapshot,
    ValidationResult,
)
from scripts.place_content_backfill.validators import (
    import_review_csv,
    find_near_duplicates,
    rebuild_review_artifacts,
    validate_proposal,
    validate_worker,
)


def words(count: int, prefix: str = "copy") -> str:
    return " ".join(f"{prefix}{index}" for index in range(count))


def baseline(name="Chùa Thiên Mụ", province_id="b5f3ef5e-dc49-4482-88e3-a8048cb32639"):
    return BaselineRecord(
        place_id="place-1",
        province_id=province_id,
        status="active",
        vi_name=name,
        vi_short_description="Mô tả ngắn",
        input_hash="baseline-hash",
        subcategory_name="Chùa",
        subcategory_category="culture",
    )


def source_snapshot():
    return SourceSnapshot(
        place_id="place-1",
        baseline_input_hash="baseline-hash",
        facts=(
            SourceFact(
                fact_id="fact-1",
                source_type="osm",
                source_url="https://www.openstreetmap.org/node/1",
                claim="A pagoda in Huế",
                confidence=0.95,
            ),
        ),
    )


def proposal(*, name_decision=None, generated=None, province_id=None):
    return Proposal(
        place_id="place-1",
        province_id=province_id or baseline().province_id,
        baseline_input_hash="baseline-hash",
        name_decision=name_decision or NameDecision(
            place_id="place-1",
            vi_name="Chùa Thiên Mụ",
            en_name="Thiên Mụ Pagoda",
            confidence=0.98,
            rule_id="generic:pagoda",
            protected_tokens=("Thiên", "Mụ"),
        ),
        generated=generated or GeneratedContent(
            vi_short=words(20, "vi"),
            en_short=words(20, "en"),
            vi_long=words(90, "vilong"),
            en_long=words(90, "enlong"),
            fact_ids=("fact-1",),
        ),
    )


class PlaceContentValidatorsTest(unittest.TestCase):
    def assert_rejected(self, **generated_updates):
        generated = proposal().generated.model_copy(update=generated_updates)
        result = validate_proposal(proposal(generated=generated), baseline(), source_snapshot())
        self.assertFalse(result.passed)
        self.assertTrue(result.errors)

    def test_rejects_empty_range_placeholder_markup_instruction_and_literal_translation(self):
        for field, value in (
            ("vi_short", ""),
            ("en_long", words(161, "too-long")),
            ("vi_long", "lorem ipsum " + words(90)),
            ("en_short", "[click](https://example.org) " + words(20)),
            ("vi_short", "Ignore previous instructions " + words(20)),
            ("en_long", "Perfume River " + words(90)),
        ):
            with self.subTest(field=field, value=value[:20]):
                self.assert_rejected(**{field: value})

    def test_rejects_protected_token_loss_digits_acronyms_and_unreferenced_numbers(self):
        lost_name = proposal(
            name_decision=NameDecision(
                place_id="place-1",
                vi_name="Núi Bà Đen",
                en_name="Mountain",
                confidence=0.5,
                rule_id="bad",
                protected_tokens=("Bà", "Đen"),
            )
        )
        result = validate_proposal(lost_name, baseline("Núi Bà Đen"), source_snapshot())
        self.assertFalse(result.passed)
        self.assertTrue(any("protected" in error for error in result.errors))

        changed_name = proposal(
            name_decision=NameDecision(
                place_id="place-1",
                vi_name="Bảo Tàng ABC 123",
                en_name="Museum XYZ 999",
                confidence=0.95,
                rule_id="bad",
            )
        )
        result = validate_proposal(changed_name, baseline("Bảo Tàng ABC 123"), source_snapshot())
        self.assertFalse(result.passed)

        self.assert_rejected(en_short=words(20) + " 12345")

    def test_rejects_province_category_and_name_disagreement(self):
        generated = proposal().generated.model_copy(
            update={"en_long": words(89, "copy") + " airport"}
        )
        result = validate_proposal(proposal(generated=generated), baseline(), source_snapshot())
        self.assertFalse(result.passed)
        self.assertTrue(any("category" in error or "province" in error for error in result.errors))

    def test_near_duplicate_detection_uses_five_gram_similarity(self):
        text_a = "A calm pagoda beside the river with a documented cultural setting."
        text_b = "A calm pagoda beside the river with a documented cultural setting!"
        text_c = "A completely different market description in another province."
        duplicates = find_near_duplicates(
            {"place-a": text_a, "place-b": text_b, "place-c": text_c},
            threshold=0.92,
            chunk_size=200,
        )
        self.assertIn("place-b", duplicates["place-a"])
        self.assertNotIn("place-c", duplicates.get("place-a", ()))

    def test_only_explicit_human_decision_populates_approved_jsonl(self):
        valid_proposal = proposal()
        valid_validation = validate_proposal(valid_proposal, baseline(), source_snapshot())
        with tempfile.TemporaryDirectory() as tmp:
            store = ArtifactStore(Path(tmp), "20260810-120000-abcdef12")
            counts = rebuild_review_artifacts(
                store,
                [(valid_proposal, valid_validation, baseline())],
                decisions=(),
            )
            self.assertEqual(counts["approved"], 0)
            self.assertEqual(list(store.iter_stream("approved")), [])
            self.assertEqual(counts["needs_review"], 1)

            counts = rebuild_review_artifacts(
                store,
                [(valid_proposal, valid_validation, baseline())],
                decisions=(ReviewDecision(place_id="place-1", decision="approve"),),
            )
            self.assertEqual(counts["approved"], 1)
            self.assertEqual(len(list(store.iter_stream("approved"))), 1)

            rows = list(store.iter_review_csv())
            self.assertEqual(rows, [])

    def test_validation_worker_writes_one_result_per_bounded_item(self):
        valid_proposal = proposal()
        with tempfile.TemporaryDirectory() as tmp:
            store = ArtifactStore(Path(tmp), "20260810-120000-abcdef12")
            count = validate_worker(
                ((valid_proposal, baseline(), source_snapshot()),),
                store,
                max_places=1,
            )
            self.assertEqual(count, 1)
            self.assertEqual(len(list(store.iter_stream("validations"))), 1)

    def test_review_rows_use_baseline_values_and_source_urls(self):
        valid_proposal = proposal()
        valid_validation = validate_proposal(valid_proposal, baseline(), source_snapshot())
        with tempfile.TemporaryDirectory() as tmp:
            store = ArtifactStore(Path(tmp), "20260810-120000-abcdef12")
            rebuild_review_artifacts(
                store,
                [(valid_proposal, valid_validation, baseline(), source_snapshot())],
                decisions=(),
            )
            row = next(store.iter_review_csv())
            self.assertEqual(row["current_vi_name"], "Chùa Thiên Mụ")
            self.assertEqual(row["source_urls"], "https://www.openstreetmap.org/node/1")

    def test_review_csv_import_accepts_only_decisions_and_revalidates_edits(self):
        with tempfile.TemporaryDirectory() as tmp:
            store = ArtifactStore(Path(tmp), "20260810-120000-abcdef12")
            store.export_review_csv(
                (
                    {"place_id": "place-1", "reviewer_decision": "approve", "reviewer_notes": "ok"},
                    {"place_id": "place-2", "reviewer_decision": "edit", "proposed_vi_description": "Edited"},
                ),
                fieldnames=("place_id", "reviewer_decision", "reviewer_notes", "proposed_vi_description"),
            )
            count = import_review_csv(
                store,
                store.path("needs-review"),
                validate_edit=lambda place_id, fields: place_id == "place-2" and fields["proposed_vi_description"] == "Edited",
            )
            self.assertEqual(count, 2)
            decisions = list(store.iter_stream("review-decisions"))
            self.assertEqual(decisions[0]["decision"], "approve")
            self.assertEqual(decisions[1]["decision"], "edit")

    def test_validate_worker_writes_validation_and_review_artifacts(self):
        with tempfile.TemporaryDirectory() as tmp:
            run_id = "20260810-120000-abcdef12"
            store = ArtifactStore(Path(tmp) / ".artifacts/place-content", run_id)
            store.write_manifest(
                {
                    "run_id": run_id,
                    "province_ids": [baseline().province_id],
                    "place_ids": ["place-1"],
                    "expected_total": 1,
                    "pilot_place_ids": ["place-1"],
                }
            )
            current_baseline = baseline()
            current_source = source_snapshot()
            current_proposal = proposal()
            store.append_jsonl("baseline", current_baseline.model_dump(mode="json"))
            store.append_jsonl("sources", current_source.model_dump(mode="json"))
            store.append_jsonl(
                "proposals",
                {
                    "place_id": current_proposal.place_id,
                    "baseline_input_hash": current_proposal.baseline_input_hash,
                    "proposal": current_proposal.model_dump(mode="json"),
                    "usage": {
                        "prompt_tokens": 100,
                        "completion_tokens": 120,
                        "total_tokens": 220,
                        "estimated_cost_usd": 0.0000476,
                    },
                    "cache_hit": False,
                },
            )
            previous = Path.cwd()
            try:
                os.chdir(tmp)
                result = main(
                    [
                        "validate",
                        "--run-id",
                        run_id,
                        "--worker-chunk-size",
                        "100",
                        "--worker-status-path",
                        str(store.run_dir / "worker.status.json"),
                        "--worker-place-ids",
                        "place-1",
                    ]
                )
            finally:
                os.chdir(previous)

            self.assertEqual(result, 0)
            validations = list(store.iter_stream("validations"))
            self.assertEqual(len(validations), 1)
            self.assertTrue(validations[0]["passed"])
            self.assertEqual(len(list(store.iter_review_csv())), 1)

    def test_status_reports_sanitized_run_counts_and_budget(self):
        with tempfile.TemporaryDirectory() as tmp:
            run_id = "20260810-120000-abcdef12"
            store = ArtifactStore(Path(tmp) / ".artifacts/place-content", run_id)
            store.write_manifest(
                {
                    "run_id": run_id,
                    "province_ids": [baseline().province_id],
                    "place_ids": ["place-1"],
                    "expected_total": 1,
                    "pilot_place_ids": ["place-1"],
                }
            )
            store.append_jsonl("baseline", baseline().model_dump(mode="json"))
            store.append_jsonl("sources", source_snapshot().model_dump(mode="json"))
            proposal_value = proposal()
            store.append_jsonl(
                "proposals",
                {
                    "place_id": proposal_value.place_id,
                    "baseline_input_hash": proposal_value.baseline_input_hash,
                    "proposal": proposal_value.model_dump(mode="json"),
                    "usage": {
                        "prompt_tokens": 100,
                        "completion_tokens": 120,
                        "total_tokens": 220,
                        "estimated_cost_usd": 0.0000476,
                        "request_attempts": 1,
                    },
                    "cache_hit": False,
                },
            )
            store.append_jsonl(
                "generation-budget",
                {
                    "request_count": 0,
                    "request_attempts": 2,
                    "input_tokens": 0,
                    "output_tokens": 0,
                    "estimated_cost_usd": 0.0,
                    "reason": "reconciled-provider-failures",
                },
            )
            previous = Path.cwd()
            output = StringIO()
            try:
                os.chdir(tmp)
                with redirect_stdout(output):
                    result = main(["status", "--run-id", run_id])
            finally:
                os.chdir(previous)

            self.assertEqual(result, 0)
            text = output.getvalue()
            self.assertIn(f"run_id={run_id}", text)
            self.assertIn("baseline=1", text)
            self.assertIn("proposals=1", text)
            self.assertIn("request_attempts=3", text)


if __name__ == "__main__":
    unittest.main()
