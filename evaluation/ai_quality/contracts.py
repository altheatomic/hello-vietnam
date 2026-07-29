from __future__ import annotations

import json
from collections.abc import Iterable
from pathlib import Path
from typing import Any


_REQUIRED_FIELDS = {
    "ai_search": (
        "id",
        "image_url",
        "expected_type",
        "accepted_names",
    ),
    "ai_chat": (
        "id",
        "prompt",
        "expected_action",
    ),
    "translation": (
        "id",
        "source_text",
        "source_language_code",
        "target_language_code",
        "target_language_name",
        "references",
    ),
    "tts": (
        "id",
        "text",
        "language_code",
        "language_name",
    ),
}


def load_jsonl(path: str | Path) -> list[dict[str, Any]]:
    cases: list[dict[str, Any]] = []
    source = Path(path)
    with source.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            try:
                value = json.loads(stripped)
            except json.JSONDecodeError as error:
                raise ValueError(
                    f"{source}:{line_number}: invalid JSON: {error.msg}"
                ) from error
            if not isinstance(value, dict):
                raise ValueError(
                    f"{source}:{line_number}: each JSONL row must be an object"
                )
            cases.append({**value, "_line": line_number})
    return cases


def validate_cases(feature: str, cases: Iterable[dict[str, Any]]) -> None:
    if feature not in _REQUIRED_FIELDS:
        raise ValueError(f"unsupported feature: {feature}")

    seen: set[str] = set()
    count = 0
    for case in cases:
        count += 1
        case_id = case.get("id")
        if not isinstance(case_id, str) or not case_id.strip():
            raise ValueError(f"{feature}: field 'id' must be a non-empty string")
        if case_id in seen:
            raise ValueError(f"{feature}: duplicate case id '{case_id}'")
        seen.add(case_id)

        for field in _REQUIRED_FIELDS[feature]:
            if field not in case:
                raise ValueError(
                    f"{feature}/{case_id}: missing required field '{field}'"
                )
        _validate_feature_case(feature, case)

    if count == 0:
        raise ValueError(f"{feature}: dataset cannot be empty")


def _validate_feature_case(feature: str, case: dict[str, Any]) -> None:
    case_id = str(case["id"])
    if feature == "ai_search":
        _require_non_empty_string(case, case_id, "image_url")
        if case["expected_type"] not in {"food", "object"}:
            raise ValueError(
                f"{feature}/{case_id}: expected_type must be food or object"
            )
        _require_non_empty_string_list(case, case_id, "accepted_names")
    elif feature == "ai_chat":
        _require_non_empty_string(case, case_id, "prompt")
        expected_action = case["expected_action"]
        if expected_action is not None and (
            not isinstance(expected_action, str) or not expected_action.strip()
        ):
            raise ValueError(
                f"{feature}/{case_id}: expected_action must be null or a string"
            )
        _require_optional_nested_string_lists(
            case, case_id, "required_fact_groups"
        )
        _require_optional_string_list(case, case_id, "forbidden_terms")
    elif feature == "translation":
        for field in (
            "source_text",
            "source_language_code",
            "target_language_code",
            "target_language_name",
        ):
            _require_non_empty_string(case, case_id, field)
        _require_non_empty_string_list(case, case_id, "references")
    elif feature == "tts":
        for field in ("text", "language_code", "language_name"):
            _require_non_empty_string(case, case_id, field)


def _require_non_empty_string(
    case: dict[str, Any], case_id: str, field: str
) -> None:
    value = case.get(field)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{case_id}: field '{field}' must be a non-empty string")


def _require_non_empty_string_list(
    case: dict[str, Any], case_id: str, field: str
) -> None:
    value = case.get(field)
    if (
        not isinstance(value, list)
        or not value
        or any(not isinstance(item, str) or not item.strip() for item in value)
    ):
        raise ValueError(
            f"{case_id}: field '{field}' must be a non-empty string list"
        )


def _require_optional_string_list(
    case: dict[str, Any], case_id: str, field: str
) -> None:
    if field not in case:
        return
    value = case[field]
    if not isinstance(value, list) or any(
        not isinstance(item, str) or not item.strip() for item in value
    ):
        raise ValueError(f"{case_id}: field '{field}' must be a string list")


def _require_optional_nested_string_lists(
    case: dict[str, Any], case_id: str, field: str
) -> None:
    if field not in case:
        return
    value = case[field]
    if (
        not isinstance(value, list)
        or any(
            not isinstance(group, list)
            or not group
            or any(
                not isinstance(item, str) or not item.strip() for item in group
            )
            for group in value
        )
    ):
        raise ValueError(
            f"{case_id}: field '{field}' must contain non-empty string lists"
        )
