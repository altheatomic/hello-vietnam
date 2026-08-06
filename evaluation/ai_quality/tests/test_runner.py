from __future__ import annotations

import csv
import json
import tempfile
import unittest
from pathlib import Path

from evaluation.ai_quality.run_evaluation import (
    validate_locked_datasets,
    write_artifacts,
)


class LockedDatasetTests(unittest.TestCase):
    def test_all_locked_datasets_are_valid(self) -> None:
        counts = validate_locked_datasets()

        self.assertEqual(set(counts), {"ai_search", "ai_chat", "translation", "tts"})
        self.assertGreaterEqual(counts["ai_search"], 20)
        self.assertGreaterEqual(counts["ai_chat"], 12)
        self.assertGreaterEqual(counts["translation"], 12)
        self.assertGreaterEqual(counts["tts"], 6)


class ArtifactWritingTests(unittest.TestCase):
    def test_write_artifacts_is_deterministic_and_keeps_human_scores_pending(
        self,
    ) -> None:
        raw = [
            {
                "feature": "translation",
                "case": {
                    "id": "tr-1",
                    "source_text": "The ticket costs 20 USD.",
                    "source_language_code": "en",
                    "target_language_code": "vi",
                    "target_language_name": "Vietnamese",
                    "references": ["Vé có giá 20 USD."],
                },
                "record": {
                    "ok": True,
                    "status_code": 200,
                    "latency_ms": 120.0,
                    "response": {"translation": "Vé có giá 20 USD."},
                    "error": None,
                },
            }
        ]

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            summary = write_artifacts(output, raw)

            self.assertEqual(summary["translation"]["cases"], 1)
            self.assertEqual(summary["translation"]["automatic_pass_rate"], 1.0)
            self.assertTrue((output / "raw.jsonl").exists())
            self.assertTrue((output / "scores.csv").exists())
            self.assertTrue((output / "summary.json").exists())
            self.assertTrue((output / "report.md").exists())

            persisted = json.loads(
                (output / "summary.json").read_text(encoding="utf-8")
            )
            self.assertEqual(persisted, summary)

            with (output / "human_ratings.csv").open(
                "r", encoding="utf-8", newline=""
            ) as handle:
                rows = list(csv.DictReader(handle))
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["case_id"], "tr-1")
            self.assertEqual(rows[0]["human_adequacy"], "")

            report = (output / "report.md").read_text(encoding="utf-8")
            self.assertIn("Translation", report)
            self.assertIn("Chờ chấm thủ công", report)


if __name__ == "__main__":
    unittest.main()
