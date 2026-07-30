from __future__ import annotations

import math
from collections import defaultdict
from collections.abc import Iterable
from statistics import mean
from typing import Any

from .metrics import (
    character_f_score,
    classification_summary,
    expected_calibration_error,
    normalize_text,
    percentile,
    preserved_numbers,
    token_f1,
)


_AI_SEARCH_STRING_FIELDS = (
    "result_type",
    "detected_name",
    "subtitle",
    "summary",
    "location_hint",
    "category_text",
    "best_time",
    "note",
    "cultural_significance",
    "production_method",
    "alternative_names",
    "price_range",
)
_AI_SEARCH_ARRAY_FIELDS = (
    "primary_tags",
    "secondary_tags",
    "usage_bullets",
    "suggested_places",
)


def score_ai_search(
    case: dict[str, Any], record: dict[str, Any]
) -> dict[str, Any]:
    base = _base_score("ai_search", case, record)
    response = _response(record)
    schema_valid = _valid_ai_search_schema(response)
    predicted_type = _string(response.get("result_type"))
    expected_type = _string(case.get("expected_type"))
    detected_name = _string(response.get("detected_name")) or ""
    accepted_names = [
        name for name in case.get("accepted_names", []) if isinstance(name, str)
    ]
    name_similarity = max(
        (token_f1(detected_name, name) for name in accepted_names),
        default=0.0,
    )
    normalized_detected_name = normalize_text(detected_name)
    name_contained = any(
        normalized_name
        and (
            normalized_name in normalized_detected_name
            or normalized_detected_name in normalized_name
        )
        for normalized_name in (
            normalize_text(name) for name in accepted_names
        )
    )
    name_correct = bool(
        base["success"]
        and normalized_detected_name
        and (name_similarity >= 0.8 or name_contained)
    )
    type_correct = predicted_type == expected_type
    confidence = _number(response.get("confidence"))
    expected_db_id = _string(case.get("expected_db_id"))
    db_match = response.get("db_match")
    actual_db_id = (
        _string(db_match.get("id")) if isinstance(db_match, dict) else None
    )
    db_match_correct = (
        True
        if expected_type != "food" or expected_db_id is None
        else actual_db_id == expected_db_id
    )
    end_to_end_correct = bool(
        base["success"]
        and schema_valid
        and type_correct
        and name_correct
        and db_match_correct
    )
    return {
        **base,
        "expected_type": expected_type,
        "predicted_type": predicted_type,
        "detected_name": detected_name,
        "schema_valid": schema_valid,
        "type_correct": type_correct,
        "name_similarity": name_similarity,
        "name_correct": name_correct,
        "expected_db_id": expected_db_id,
        "actual_db_id": actual_db_id,
        "db_match_correct": db_match_correct,
        "confidence": confidence,
        "end_to_end_correct": end_to_end_correct,
        "human_name_judgment": None,
        "human_summary_usefulness": None,
        "human_pending": bool(base["success"]),
    }


def score_ai_chat(
    case: dict[str, Any], record: dict[str, Any]
) -> dict[str, Any]:
    base = _base_score("ai_chat", case, record)
    response = _response(record)
    assistant = _last_assistant_message(response.get("messages"))
    answer = _string(assistant.get("content")) if assistant else None
    action = assistant.get("action") if assistant else None
    actual_action = (
        _string(action.get("key")) if isinstance(action, dict) else None
    )
    expected_action = _string(case.get("expected_action"))
    action_correct = actual_action == expected_action

    normalized_answer = normalize_text(answer or "")
    fact_groups = case.get("required_fact_groups", [])
    matched_groups = sum(
        any(normalize_text(term) in normalized_answer for term in group)
        for group in fact_groups
    )
    fact_coverage = (
        matched_groups / len(fact_groups) if fact_groups else 1.0
    )
    forbidden_terms = case.get("forbidden_terms", [])
    contains_forbidden = any(
        normalize_text(term) in normalized_answer for term in forbidden_terms
    )
    automatic_pass = bool(
        base["success"]
        and answer
        and action_correct
        and fact_coverage == 1.0
        and not contains_forbidden
    )
    return {
        **base,
        "answer": answer or "",
        "expected_action": expected_action,
        "actual_action": actual_action,
        "action_correct": action_correct,
        "required_fact_coverage": fact_coverage,
        "contains_forbidden_term": contains_forbidden,
        "automatic_pass": automatic_pass,
        "human_factuality": None,
        "human_relevance": None,
        "human_groundedness": None,
        "human_pending": bool(base["success"]),
    }


def score_translation(
    case: dict[str, Any], record: dict[str, Any]
) -> dict[str, Any]:
    base = _base_score("translation", case, record)
    response = _response(record)
    translation = _string(response.get("translation")) or ""
    references = [
        reference
        for reference in case.get("references", [])
        if isinstance(reference, str)
    ]
    lexical_score = max(
        (token_f1(translation, reference) for reference in references),
        default=0.0,
    )
    character_score = max(
        (
            character_f_score(translation, reference)
            for reference in references
        ),
        default=0.0,
    )
    numbers_ok = preserved_numbers(
        _string(case.get("source_text")) or "", translation
    )
    automatic_pass = bool(
        base["success"]
        and translation
        and character_score >= 0.6
        and numbers_ok
    )
    return {
        **base,
        "translation": translation,
        "token_f1": lexical_score,
        "character_f_score": character_score,
        "numbers_preserved": numbers_ok,
        "automatic_pass": automatic_pass,
        "human_adequacy": None,
        "human_fluency": None,
        "human_pending": bool(base["success"]),
    }


def score_tts(case: dict[str, Any], record: dict[str, Any]) -> dict[str, Any]:
    base = _base_score("tts", case, record)
    response = _response(record)
    audio_url = _string(response.get("audio_url")) or ""
    audio_reachable = record.get("audio_reachable") is True
    automatic_pass = bool(base["success"] and audio_url and audio_reachable)
    return {
        **base,
        "audio_url": audio_url,
        "audio_url_present": bool(audio_url),
        "audio_reachable": audio_reachable,
        "automatic_pass": automatic_pass,
        "human_mos": None,
        "human_intelligibility": None,
        "human_pending": bool(base["success"]),
    }


def aggregate_scores(
    rows: Iterable[dict[str, Any]]
) -> dict[str, dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        grouped[str(row["feature"])].append(row)

    output: dict[str, dict[str, Any]] = {}
    for feature, feature_rows in sorted(grouped.items()):
        latencies = [
            float(row["latency_ms"])
            for row in feature_rows
            if isinstance(row.get("latency_ms"), (int, float))
        ]
        summary: dict[str, Any] = {
            "cases": len(feature_rows),
            "success_rate": _average_boolean(feature_rows, "success"),
            "error_count": sum(not bool(row.get("success")) for row in feature_rows),
            "latency_ms": {
                "mean": mean(latencies) if latencies else math.nan,
                "p50": percentile(latencies, 50),
                "p95": percentile(latencies, 95),
                "p99": percentile(latencies, 99),
            },
            "human_ratings_pending": sum(
                row.get("human_pending") is True for row in feature_rows
            ),
        }
        if feature == "ai_search":
            db_match_rows = [
                row
                for row in feature_rows
                if isinstance(row.get("expected_db_id"), str)
                and bool(str(row["expected_db_id"]).strip())
            ]
            expected = [
                str(row.get("expected_type") or "") for row in feature_rows
            ]
            predicted = [
                _string(row.get("predicted_type")) for row in feature_rows
            ]
            summary.update(
                {
                    "schema_valid_rate": _average_boolean(
                        feature_rows, "schema_valid"
                    ),
                    "name_accuracy": _average_boolean(
                        feature_rows, "name_correct"
                    ),
                    "db_match_cases": len(db_match_rows),
                    "db_match_accuracy": _average_boolean(
                        db_match_rows, "db_match_correct"
                    ),
                    "end_to_end_accuracy": _average_boolean(
                        feature_rows, "end_to_end_correct"
                    ),
                    "classification": classification_summary(
                        expected, predicted, ["food", "object"]
                    ),
                    "ece": expected_calibration_error(
                        [
                            float(row["confidence"])
                            for row in feature_rows
                            if isinstance(row.get("confidence"), (int, float))
                        ],
                        [
                            bool(row.get("end_to_end_correct"))
                            for row in feature_rows
                            if isinstance(row.get("confidence"), (int, float))
                        ],
                    ),
                }
            )
        elif feature == "ai_chat":
            summary.update(
                {
                    "action_accuracy": _average_boolean(
                        feature_rows, "action_correct"
                    ),
                    "required_fact_coverage": _average_number(
                        feature_rows, "required_fact_coverage"
                    ),
                    "automatic_pass_rate": _average_boolean(
                        feature_rows, "automatic_pass"
                    ),
                }
            )
        elif feature == "translation":
            summary.update(
                {
                    "mean_token_f1": _average_number(feature_rows, "token_f1"),
                    "mean_character_f_score": _average_number(
                        feature_rows, "character_f_score"
                    ),
                    "number_preservation_rate": _average_boolean(
                        feature_rows, "numbers_preserved"
                    ),
                    "automatic_pass_rate": _average_boolean(
                        feature_rows, "automatic_pass"
                    ),
                }
            )
        elif feature == "tts":
            summary.update(
                {
                    "audio_url_rate": _average_boolean(
                        feature_rows, "audio_url_present"
                    ),
                    "audio_reachable_rate": _average_boolean(
                        feature_rows, "audio_reachable"
                    ),
                    "automatic_pass_rate": _average_boolean(
                        feature_rows, "automatic_pass"
                    ),
                }
            )
        output[feature] = summary
    return output


def _base_score(
    feature: str, case: dict[str, Any], record: dict[str, Any]
) -> dict[str, Any]:
    return {
        "feature": feature,
        "case_id": str(case.get("id") or ""),
        "success": record.get("ok") is True,
        "status_code": record.get("status_code"),
        "latency_ms": record.get("latency_ms"),
        "error": record.get("error"),
    }


def _response(record: dict[str, Any]) -> dict[str, Any]:
    value = record.get("response")
    return value if isinstance(value, dict) else {}


def _valid_ai_search_schema(response: dict[str, Any]) -> bool:
    if not all(isinstance(response.get(field), str) for field in _AI_SEARCH_STRING_FIELDS):
        return False
    if not isinstance(response.get("confidence"), (int, float)):
        return False
    return all(
        isinstance(response.get(field), list)
        and all(isinstance(item, str) for item in response[field])
        for field in _AI_SEARCH_ARRAY_FIELDS
    )


def _last_assistant_message(value: Any) -> dict[str, Any] | None:
    if not isinstance(value, list):
        return None
    for item in reversed(value):
        if isinstance(item, dict) and item.get("role") == "assistant":
            return item
    return None


def _average_boolean(rows: list[dict[str, Any]], key: str) -> float:
    return sum(bool(row.get(key)) for row in rows) / len(rows) if rows else math.nan


def _average_number(rows: list[dict[str, Any]], key: str) -> float:
    values = [
        float(row[key])
        for row in rows
        if isinstance(row.get(key), (int, float))
    ]
    return mean(values) if values else math.nan


def _string(value: Any) -> str | None:
    return value.strip() if isinstance(value, str) and value.strip() else None


def _number(value: Any) -> float | None:
    if not isinstance(value, (int, float)):
        return None
    return min(1.0, max(0.0, float(value)))
