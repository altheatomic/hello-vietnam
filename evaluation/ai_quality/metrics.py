from __future__ import annotations

import math
import re
import unicodedata
from collections import Counter
from collections.abc import Iterable, Sequence


_NON_ALPHANUMERIC = re.compile(r"[^a-z0-9]+")
_NUMBER = re.compile(r"\d+(?:[.,]\d+)*")


def normalize_text(value: str) -> str:
    """Normalize Vietnamese text for deterministic lexical comparison."""
    decomposed = unicodedata.normalize("NFD", value.strip().lower())
    without_marks = "".join(
        character
        for character in decomposed
        if unicodedata.category(character) != "Mn"
    )
    without_marks = without_marks.replace("đ", "d")
    return _NON_ALPHANUMERIC.sub(" ", without_marks).strip()


def token_f1(candidate: str, reference: str) -> float:
    """Return multiset token F1 after accent-insensitive normalization."""
    candidate_tokens = normalize_text(candidate).split()
    reference_tokens = normalize_text(reference).split()
    if not candidate_tokens or not reference_tokens:
        return 0.0

    overlap = sum(
        (Counter(candidate_tokens) & Counter(reference_tokens)).values()
    )
    precision = overlap / len(candidate_tokens)
    recall = overlap / len(reference_tokens)
    return _harmonic_mean(precision, recall)


def character_f_score(candidate: str, reference: str, n: int = 3) -> float:
    """Return a small dependency-free chrF-style n-gram F-score."""
    if n < 1:
        raise ValueError("n must be at least 1")
    candidate_text = normalize_text(candidate).replace(" ", "")
    reference_text = normalize_text(reference).replace(" ", "")
    if not candidate_text or not reference_text:
        return 0.0

    candidate_ngrams = _ngrams(candidate_text, n)
    reference_ngrams = _ngrams(reference_text, n)
    overlap = sum((candidate_ngrams & reference_ngrams).values())
    precision = overlap / sum(candidate_ngrams.values())
    recall = overlap / sum(reference_ngrams.values())
    return _harmonic_mean(precision, recall)


def classification_summary(
    expected: Sequence[str],
    predicted: Sequence[str | None],
    labels: Sequence[str],
) -> dict[str, object]:
    """Compute accuracy plus per-class precision, recall, and F1."""
    if len(expected) != len(predicted):
        raise ValueError("expected and predicted must have the same length")
    if not labels:
        raise ValueError("labels cannot be empty")

    per_class: dict[str, dict[str, float | int]] = {}
    for label in labels:
        true_positive = sum(
            actual == label and guess == label
            for actual, guess in zip(expected, predicted)
        )
        false_positive = sum(
            actual != label and guess == label
            for actual, guess in zip(expected, predicted)
        )
        false_negative = sum(
            actual == label and guess != label
            for actual, guess in zip(expected, predicted)
        )
        precision_value = _safe_divide(
            true_positive, true_positive + false_positive
        )
        recall_value = _safe_divide(
            true_positive, true_positive + false_negative
        )
        per_class[label] = {
            "support": sum(actual == label for actual in expected),
            "precision": precision_value,
            "recall": recall_value,
            "f1": _harmonic_mean(precision_value, recall_value),
        }

    correct = sum(
        actual == guess for actual, guess in zip(expected, predicted)
    )
    macro_f1 = sum(
        float(metrics["f1"]) for metrics in per_class.values()
    ) / len(labels)
    return {
        "count": len(expected),
        "accuracy": _safe_divide(correct, len(expected)),
        "macro_f1": macro_f1,
        "per_class": per_class,
    }


def expected_calibration_error(
    confidences: Sequence[float],
    correctness: Sequence[bool | int],
    bins: int = 10,
) -> float:
    """Compare binned confidence with empirical accuracy."""
    if len(confidences) != len(correctness):
        raise ValueError("confidences and correctness must have the same length")
    if bins < 1:
        raise ValueError("bins must be at least 1")
    if not confidences:
        return math.nan

    grouped: list[list[tuple[float, float]]] = [[] for _ in range(bins)]
    for raw_confidence, is_correct in zip(confidences, correctness):
        confidence = min(1.0, max(0.0, float(raw_confidence)))
        index = min(int(confidence * bins), bins - 1)
        grouped[index].append((confidence, 1.0 if is_correct else 0.0))

    total = len(confidences)
    error = 0.0
    for group in grouped:
        if not group:
            continue
        mean_confidence = sum(item[0] for item in group) / len(group)
        mean_accuracy = sum(item[1] for item in group) / len(group)
        error += len(group) / total * abs(mean_accuracy - mean_confidence)
    return error


def percentile(values: Iterable[float], percentage: float) -> float:
    """Return a linearly interpolated percentile."""
    ordered = sorted(float(value) for value in values)
    if not ordered:
        return math.nan
    if not 0 <= percentage <= 100:
        raise ValueError("percentage must be between 0 and 100")
    if len(ordered) == 1:
        return ordered[0]

    position = (len(ordered) - 1) * percentage / 100
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    fraction = position - lower
    return ordered[lower] + (ordered[upper] - ordered[lower]) * fraction


def preserved_numbers(source: str, candidate: str) -> bool:
    """Return true when numeric values survive locale-specific formatting."""
    source_numbers = Counter(
        _canonical_number(value) for value in _NUMBER.findall(source)
    )
    candidate_numbers = Counter(
        _canonical_number(value) for value in _NUMBER.findall(candidate)
    )
    return all(
        candidate_numbers[number] >= count
        for number, count in source_numbers.items()
    )


def _canonical_number(value: str) -> str:
    if re.fullmatch(r"\d{1,3}(?:[.,]\d{3})+", value):
        return value.replace(",", "").replace(".", "")
    return value


def _ngrams(value: str, n: int) -> Counter[str]:
    if len(value) < n:
        return Counter({value: 1})
    return Counter(value[index : index + n] for index in range(len(value) - n + 1))


def _safe_divide(numerator: int | float, denominator: int | float) -> float:
    return float(numerator) / denominator if denominator else 0.0


def _harmonic_mean(left: float, right: float) -> float:
    return 2 * left * right / (left + right) if left + right else 0.0
