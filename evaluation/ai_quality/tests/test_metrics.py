import math
import unittest

from evaluation.ai_quality.metrics import (
    character_f_score,
    classification_summary,
    expected_calibration_error,
    normalize_text,
    percentile,
    preserved_numbers,
    token_f1,
)


class NormalizeTextTests(unittest.TestCase):
    def test_removes_vietnamese_diacritics_and_punctuation(self):
        self.assertEqual(normalize_text("Bánh mì – Đà Nẵng!"), "banh mi da nang")


class SimilarityMetricTests(unittest.TestCase):
    def test_token_f1_uses_independent_precision_and_recall(self):
        self.assertAlmostEqual(token_f1("phở bò Hà Nội", "phở bò"), 2 / 3)

    def test_character_f_score_is_one_for_equivalent_vietnamese_text(self):
        self.assertEqual(character_f_score("Cảm ơn bạn", "cam on ban"), 1.0)

    def test_character_f_score_is_zero_when_either_side_is_empty(self):
        self.assertEqual(character_f_score("", "xin chao"), 0.0)


class ClassificationMetricTests(unittest.TestCase):
    def test_reports_accuracy_and_macro_f1(self):
        summary = classification_summary(
            expected=["food", "food", "object", "object"],
            predicted=["food", "object", "object", "object"],
            labels=["food", "object"],
        )

        self.assertEqual(summary["accuracy"], 0.75)
        self.assertAlmostEqual(summary["per_class"]["food"]["f1"], 2 / 3)
        self.assertAlmostEqual(summary["per_class"]["object"]["f1"], 0.8)
        self.assertAlmostEqual(summary["macro_f1"], (2 / 3 + 0.8) / 2)

    def test_missing_predictions_are_counted_as_wrong(self):
        summary = classification_summary(
            expected=["food", "object"],
            predicted=["food", None],
            labels=["food", "object"],
        )

        self.assertEqual(summary["accuracy"], 0.5)
        self.assertEqual(summary["per_class"]["object"]["recall"], 0.0)


class CalibrationAndLatencyMetricTests(unittest.TestCase):
    def test_expected_calibration_error_compares_confidence_to_accuracy(self):
        error = expected_calibration_error(
            confidences=[0.9, 0.6],
            correctness=[True, False],
            bins=2,
        )

        self.assertAlmostEqual(error, 0.25)

    def test_expected_calibration_error_clamps_confidence(self):
        error = expected_calibration_error(
            confidences=[1.4, -0.2],
            correctness=[True, False],
            bins=5,
        )

        self.assertEqual(error, 0.0)

    def test_percentile_uses_linear_interpolation(self):
        self.assertEqual(percentile([1.0, 2.0, 3.0, 4.0], 75), 3.25)

    def test_empty_percentile_is_nan(self):
        self.assertTrue(math.isnan(percentile([], 95)))


class PreservationMetricTests(unittest.TestCase):
    def test_preserved_numbers_requires_every_number(self):
        self.assertTrue(
            preserved_numbers(
                "The tour starts at 08:30 and costs 250000 VND.",
                "Chuyến đi bắt đầu lúc 08:30 và có giá 250000 VND.",
            )
        )
        self.assertFalse(
            preserved_numbers(
                "The tour starts at 08:30 and costs 250000 VND.",
                "Chuyến đi bắt đầu lúc 09:00 và có giá 250000 VND.",
            )
        )


    def test_preserved_numbers_accepts_locale_thousands_separators(self):
        self.assertTrue(
            preserved_numbers(
                "The ticket costs 50,000 VND.",
                "Vé có giá 50.000 VND.",
            )
        )
        self.assertTrue(
            preserved_numbers(
                "Giá phòng là 1.200.000 VND.",
                "The room costs 1,200,000 VND.",
            )
        )


if __name__ == "__main__":
    unittest.main()
