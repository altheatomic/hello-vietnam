import json
import tempfile
import unittest
from pathlib import Path

from evaluation.ai_quality.contracts import load_jsonl, validate_cases


class JsonlContractTests(unittest.TestCase):
    def test_load_jsonl_preserves_line_number_for_diagnostics(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "cases.jsonl"
            path.write_text(
                json.dumps(
                    {
                        "id": "search-001",
                        "image_url": "https://example.test/banh-mi.jpg",
                        "expected_type": "food",
                        "accepted_names": ["Bánh mì"],
                    }
                )
                + "\n",
                encoding="utf-8",
            )

            cases = load_jsonl(path)

        self.assertEqual(cases[0]["_line"], 1)
        self.assertEqual(cases[0]["id"], "search-001")

    def test_validate_ai_search_rejects_duplicate_ids(self):
        cases = [
            {
                "id": "same",
                "image_url": "https://example.test/a.jpg",
                "expected_type": "food",
                "accepted_names": ["Phở"],
            },
            {
                "id": "same",
                "image_url": "https://example.test/b.jpg",
                "expected_type": "object",
                "accepted_names": ["Áo dài"],
            },
        ]

        with self.assertRaisesRegex(ValueError, "duplicate case id"):
            validate_cases("ai_search", cases)

    def test_validate_chat_requires_expected_action_field(self):
        with self.assertRaisesRegex(ValueError, "expected_action"):
            validate_cases(
                "ai_chat",
                [{"id": "chat-001", "prompt": "Open the planner"}],
            )

    def test_validate_translation_accepts_multiple_references(self):
        validate_cases(
            "translation",
            [
                {
                    "id": "translation-001",
                    "source_text": "Thank you",
                    "source_language_code": "en",
                    "target_language_code": "vi",
                    "target_language_name": "Vietnamese",
                    "references": ["Cảm ơn", "Xin cảm ơn"],
                }
            ],
        )

    def test_validate_tts_rejects_empty_text(self):
        with self.assertRaisesRegex(ValueError, "text"):
            validate_cases(
                "tts",
                [
                    {
                        "id": "tts-001",
                        "text": "",
                        "language_code": "vi",
                        "language_name": "Vietnamese",
                    }
                ],
            )


if __name__ == "__main__":
    unittest.main()
