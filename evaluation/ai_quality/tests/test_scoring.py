import unittest

from evaluation.ai_quality.scoring import (
    aggregate_scores,
    score_ai_chat,
    score_ai_search,
    score_translation,
    score_tts,
)


def success_record(response, latency_ms=1200.0):
    return {
        "ok": True,
        "status_code": 200,
        "latency_ms": latency_ms,
        "response": response,
        "error": None,
    }


class AiSearchScoringTests(unittest.TestCase):
    def test_scores_type_name_database_match_and_schema(self):
        case = {
            "id": "search-001",
            "expected_type": "food",
            "accepted_names": ["Bánh mì", "Vietnamese sandwich"],
            "expected_db_id": "food-id",
        }
        record = success_record(
            {
                "result_type": "food",
                "confidence": 0.9,
                "detected_name": "Banh mi",
                "subtitle": "Vietnamese street food",
                "summary": "Vietnamese sandwich",
                "location_hint": "Vietnam",
                "category_text": "Food",
                "primary_tags": ["street food"],
                "secondary_tags": [],
                "best_time": "Morning",
                "note": "",
                "cultural_significance": "Popular everyday dish",
                "usage_bullets": ["Eat fresh"],
                "production_method": "Filled baguette",
                "alternative_names": "Vietnamese sandwich",
                "price_range": "20000-50000 VND",
                "suggested_places": ["Ho Chi Minh City"],
                "db_match": {"id": "food-id", "match_score": 1.0},
            }
        )

        score = score_ai_search(case, record)

        self.assertTrue(score["schema_valid"])
        self.assertTrue(score["type_correct"])
        self.assertTrue(score["name_correct"])
        self.assertTrue(score["db_match_correct"])
        self.assertTrue(score["end_to_end_correct"])
        self.assertEqual(score["confidence"], 0.9)

    def test_provider_error_is_retained_as_failed_case(self):
        score = score_ai_search(
            {
                "id": "search-002",
                "expected_type": "object",
                "accepted_names": ["Áo dài"],
            },
            {
                "ok": False,
                "status_code": 503,
                "latency_ms": 400.0,
                "response": {},
                "error": "provider unavailable",
            },
        )

        self.assertFalse(score["success"])
        self.assertFalse(score["name_correct"])
        self.assertFalse(score["end_to_end_correct"])
        self.assertEqual(score["error"], "provider unavailable")


    def test_accepts_expected_name_inside_descriptive_detected_name(self):
        case = {
            "id": "search-object-name",
            "expected_type": "object",
            "accepted_names": ["Áo dài"],
        }
        response = {
            "result_type": "object",
            "confidence": 0.95,
            "detected_name": "Áo dài with flamboyant flower pattern",
            "subtitle": "",
            "summary": "",
            "location_hint": "",
            "category_text": "",
            "primary_tags": [],
            "secondary_tags": [],
            "best_time": "",
            "note": "",
            "cultural_significance": "",
            "usage_bullets": [],
            "production_method": "",
            "alternative_names": "",
            "price_range": "",
            "suggested_places": [],
            "db_match": None,
        }

        score = score_ai_search(case, success_record(response))

        self.assertTrue(score["name_correct"])
        self.assertTrue(score["end_to_end_correct"])


class AiChatScoringTests(unittest.TestCase):
    def test_scores_action_and_required_fact_groups(self):
        case = {
            "id": "chat-001",
            "expected_action": "trip_planner",
            "required_fact_groups": [
                ["trip planner", "lịch trình"],
                ["days", "ngày"],
            ],
            "forbidden_terms": ["https://"],
        }
        record = success_record(
            {
                "messages": [
                    {"role": "user", "content": "Help me plan"},
                    {
                        "role": "assistant",
                        "content": "Use Trip Planner and choose the number of days.",
                        "action": {"key": "trip_planner", "payload": {}},
                    },
                ]
            }
        )

        score = score_ai_chat(case, record)

        self.assertEqual(score["answer"], "Use Trip Planner and choose the number of days.")
        self.assertTrue(score["action_correct"])
        self.assertEqual(score["required_fact_coverage"], 1.0)
        self.assertFalse(score["contains_forbidden_term"])
        self.assertTrue(score["automatic_pass"])
        self.assertIsNone(score["human_factuality"])


class TranslationScoringTests(unittest.TestCase):
    def test_uses_best_reference_and_checks_numbers(self):
        case = {
            "id": "translation-001",
            "source_text": "The ticket costs 250000 VND.",
            "references": [
                "Vé có giá 250000 VND.",
                "Giá vé là 250000 VND.",
            ],
        }
        score = score_translation(
            case,
            success_record(
                {
                    "translation": "Giá vé là 250000 VND.",
                    "detected_source_language_code": "en",
                }
            ),
        )

        self.assertEqual(score["token_f1"], 1.0)
        self.assertEqual(score["character_f_score"], 1.0)
        self.assertTrue(score["numbers_preserved"])
        self.assertIsNone(score["human_adequacy"])


class TtsScoringTests(unittest.TestCase):
    def test_scores_audio_url_and_reachability_without_inventing_mos(self):
        score = score_tts(
            {"id": "tts-001"},
            {
                **success_record({"audio_url": "https://audio.test/a.wav"}),
                "audio_reachable": True,
            },
        )

        self.assertTrue(score["audio_url_present"])
        self.assertTrue(score["audio_reachable"])
        self.assertTrue(score["automatic_pass"])
        self.assertIsNone(score["human_mos"])


class AggregateScoringTests(unittest.TestCase):
    def test_aggregates_latency_success_and_ai_search_calibration(self):
        rows = [
            {
                "feature": "ai_search",
                "success": True,
                "latency_ms": 100.0,
                "expected_type": "food",
                "predicted_type": "food",
                "end_to_end_correct": True,
                "confidence": 0.9,
                "human_pending": True,
            },
            {
                "feature": "ai_search",
                "success": True,
                "latency_ms": 300.0,
                "expected_type": "object",
                "predicted_type": "food",
                "end_to_end_correct": False,
                "confidence": 0.7,
                "human_pending": True,
            },
        ]

        summary = aggregate_scores(rows)["ai_search"]

        self.assertEqual(summary["cases"], 2)
        self.assertEqual(summary["success_rate"], 1.0)
        self.assertEqual(summary["latency_ms"]["p50"], 200.0)
        self.assertEqual(summary["classification"]["accuracy"], 0.5)
        self.assertAlmostEqual(summary["ece"], 0.4)
        self.assertEqual(summary["human_ratings_pending"], 2)


    def test_database_match_accuracy_only_uses_labeled_food_rows(self):
        rows = [
            {
                "feature": "ai_search",
                "success": True,
                "latency_ms": 100.0,
                "expected_type": "food",
                "predicted_type": "food",
                "expected_db_id": "food-1",
                "db_match_correct": False,
                "end_to_end_correct": False,
                "confidence": 0.9,
                "human_pending": True,
            },
            {
                "feature": "ai_search",
                "success": True,
                "latency_ms": 100.0,
                "expected_type": "object",
                "predicted_type": "object",
                "expected_db_id": None,
                "db_match_correct": True,
                "end_to_end_correct": True,
                "confidence": 0.9,
                "human_pending": True,
            },
        ]

        summary = aggregate_scores(rows)["ai_search"]

        self.assertEqual(summary["db_match_cases"], 1)
        self.assertEqual(summary["db_match_accuracy"], 0.0)


if __name__ == "__main__":
    unittest.main()
