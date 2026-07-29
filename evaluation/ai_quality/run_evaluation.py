from __future__ import annotations

import argparse
import base64
import csv
import json
import math
import os
import re
import sys
import time
import uuid
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from .contracts import load_jsonl, validate_cases
from .scoring import (
    aggregate_scores,
    score_ai_chat,
    score_ai_search,
    score_translation,
    score_tts,
)
from .supabase_client import SupabaseEvaluationClient, load_env_file


FEATURES = ("ai_search", "ai_chat", "translation", "tts")
PACKAGE_DIR = Path(__file__).resolve().parent
DATASET_DIR = PACKAGE_DIR / "datasets"
DEFAULT_ENV_FILE = Path("cf_service/.env")
DEFAULT_DART_ENV = Path("frontend/lib/core/config/env.dart")
HUMAN_FIELDS = (
    "human_name_judgment",
    "human_summary_usefulness",
    "human_factuality",
    "human_relevance",
    "human_groundedness",
    "human_adequacy",
    "human_fluency",
    "human_mos",
    "human_intelligibility",
)
SCORERS = {
    "ai_search": score_ai_search,
    "ai_chat": score_ai_chat,
    "translation": score_translation,
    "tts": score_tts,
}


def dataset_paths(dataset_dir: str | Path = DATASET_DIR) -> dict[str, Path]:
    root = Path(dataset_dir)
    return {feature: root / f"{feature}.jsonl" for feature in FEATURES}


def validate_locked_datasets(
    dataset_dir: str | Path = DATASET_DIR,
) -> dict[str, int]:
    counts: dict[str, int] = {}
    for feature, path in dataset_paths(dataset_dir).items():
        cases = load_jsonl(path)
        validate_cases(feature, cases)
        counts[feature] = len(cases)
    return counts


def write_artifacts(
    output_dir: str | Path,
    raw_rows: list[dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    destination = Path(output_dir)
    destination.mkdir(parents=True, exist_ok=True)

    scores: list[dict[str, Any]] = []
    for item in raw_rows:
        feature = str(item["feature"])
        scorer = SCORERS[feature]
        scores.append(scorer(item["case"], item["record"]))

    summary = _json_safe(aggregate_scores(scores))
    _write_jsonl(destination / "raw.jsonl", raw_rows)
    _write_csv(destination / "scores.csv", scores)
    (destination / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (destination / "report.md").write_text(
        _render_report(summary),
        encoding="utf-8",
    )
    _write_human_ratings(destination / "human_ratings.csv", scores)
    return summary


def run_live_evaluation(
    *,
    features: list[str],
    limit: int | None,
    env_file: str | Path,
    output_dir: str | Path,
    provision_user: bool,
    access_token: str | None,
    delay_seconds: float = 0.0,
) -> dict[str, dict[str, Any]]:
    client = _build_client(env_file)
    cases_by_feature: dict[str, list[dict[str, Any]]] = {}
    for feature in features:
        cases = load_jsonl(dataset_paths()[feature])
        validate_cases(feature, cases)
        cases_by_feature[feature] = cases[:limit] if limit else cases

    if provision_user:
        with client.ephemeral_user() as user:
            raw_rows = _execute_all(
                client,
                cases_by_feature,
                user.access_token,
                delay_seconds=delay_seconds,
            )
    else:
        token = access_token or os.environ.get("AI_EVAL_ACCESS_TOKEN")
        if not token:
            raise ValueError(
                "Provide --provision-user or AI_EVAL_ACCESS_TOKEN."
            )
        raw_rows = _execute_all(
            client,
            cases_by_feature,
            token,
            delay_seconds=delay_seconds,
        )
    return write_artifacts(output_dir, raw_rows)


def _execute_all(
    client: SupabaseEvaluationClient,
    cases_by_feature: dict[str, list[dict[str, Any]]],
    access_token: str,
    *,
    delay_seconds: float = 0.0,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for feature in FEATURES:
        for case in cases_by_feature.get(feature, []):
            print(f"[{feature}] {case['id']}", flush=True)
            try:
                record = _execute_case(
                    client, feature, case, access_token
                )
            except Exception as error:
                record = {
                    "ok": False,
                    "status_code": None,
                    "latency_ms": None,
                    "response": {},
                    "error": type(error).__name__,
                }
            rows.append(
                {
                    "feature": feature,
                    "case": _strip_internal_fields(case),
                    "record": record,
                }
            )
            if delay_seconds > 0:
                time.sleep(delay_seconds)
    return rows


def _execute_case(
    client: SupabaseEvaluationClient,
    feature: str,
    case: dict[str, Any],
    access_token: str,
) -> dict[str, Any]:
    if feature == "ai_search":
        image = client.download_image(str(case["image_url"]))
        payload = {
            "imageBase64": base64.b64encode(image.data).decode("ascii"),
            "mimeType": image.mime_type,
            "fileName": image.filename,
        }
        return client.invoke("ai-search", payload, access_token=access_token)
    if feature == "ai_chat":
        return client.invoke(
            "ai-chat",
            {
                "action": "send_message",
                "conversation_id": None,
                "request_id": str(uuid.uuid4()),
                "content": case["prompt"],
            },
            access_token=access_token,
        )
    if feature == "translation":
        return client.invoke(
            "translate",
            {
                "action": "translate",
                "text": case["source_text"],
                "sourceLanguageCode": case["source_language_code"],
                "targetLanguageCode": case["target_language_code"],
                "targetLanguageName": case["target_language_name"],
            },
            access_token=access_token,
        )
    if feature == "tts":
        record = client.invoke(
            "translate",
            {
                "action": "tts",
                "text": case["text"],
                "languageCode": case["language_code"],
                "languageName": case["language_name"],
            },
            access_token=access_token,
        )
        response = record.get("response")
        audio_url = (
            response.get("audio_url") if isinstance(response, dict) else None
        )
        record["audio_reachable"] = (
            client.is_url_reachable(audio_url)
            if isinstance(audio_url, str) and audio_url
            else False
        )
        return record
    raise ValueError(f"Unsupported feature: {feature}")


def _build_client(env_file: str | Path) -> SupabaseEvaluationClient:
    file_values = load_env_file(env_file)
    base_url = os.environ.get("SUPABASE_URL") or file_values.get("SUPABASE_URL")
    service_key = (
        os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        or file_values.get("SUPABASE_SERVICE_ROLE_KEY")
    )
    anon_key = (
        os.environ.get("SUPABASE_ANON_KEY")
        or file_values.get("SUPABASE_ANON_KEY")
        or _read_dart_anon_key(DEFAULT_DART_ENV)
    )
    if not base_url or not service_key or not anon_key:
        raise ValueError(
            "Missing SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, or anon key."
        )
    return SupabaseEvaluationClient(
        base_url,
        anon_key=anon_key,
        service_role_key=service_key,
        timeout_seconds=90.0,
    )


def _read_dart_anon_key(path: str | Path) -> str | None:
    source = Path(path)
    if not source.exists():
        return None
    text = source.read_text(encoding="utf-8")
    match = re.search(
        r"supabaseAnonKey\s*=\s*[\"']([^\"']+)[\"']",
        text,
        flags=re.MULTILINE,
    )
    return match.group(1) if match else None


def _strip_internal_fields(case: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in case.items() if not key.startswith("_")}


def _write_jsonl(path: Path, rows: list[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")


def _write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    fields = sorted({key for row in rows for key in row})
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    key: _csv_value(row.get(key))
                    for key in fields
                }
            )


def _write_human_ratings(
    path: Path, scores: list[dict[str, Any]]
) -> None:
    fields = (
        "feature",
        "case_id",
        "model_output",
        *HUMAN_FIELDS,
        "notes",
    )
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for score in scores:
            writer.writerow(
                {
                    "feature": score["feature"],
                    "case_id": score["case_id"],
                    "model_output": _model_output(score),
                    **{
                        field: _csv_value(score.get(field))
                        for field in HUMAN_FIELDS
                    },
                    "notes": "",
                }
            )


def _model_output(score: dict[str, Any]) -> str:
    for key in ("answer", "translation", "detected_name", "audio_url"):
        value = score.get(key)
        if isinstance(value, str) and value:
            return value
    return str(score.get("error") or "")


def _csv_value(value: Any) -> Any:
    if value is None:
        return ""
    if isinstance(value, (dict, list, tuple)):
        return json.dumps(value, ensure_ascii=False, sort_keys=True)
    if isinstance(value, float) and math.isnan(value):
        return ""
    return value


def _json_safe(value: Any) -> Any:
    if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
        return None
    if isinstance(value, dict):
        return {key: _json_safe(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_json_safe(item) for item in value]
    return value


def _render_report(summary: dict[str, dict[str, Any]]) -> str:
    titles = {
        "ai_search": "AI Search (Gemini)",
        "ai_chat": "AI Chat (DeepSeek)",
        "translation": "Translation (DeepSeek)",
        "tts": "TTS (VBee)",
    }
    lines = [
        "# Đánh giá chất lượng các tính năng AI",
        "",
        f"Thời điểm tổng hợp: {datetime.now(UTC).isoformat()}",
        "",
        "Điểm tự động bên dưới được tính từ bộ dữ liệu khóa. Các tiêu chí "
        "factuality, relevance, fluency và độ tự nhiên của giọng nói vẫn "
        "được đánh dấu **Chờ chấm thủ công**.",
        "",
        "| Tính năng | Số mẫu | Thành công | P50 | P95 | Chờ chấm thủ công |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for feature in FEATURES:
        if feature not in summary:
            continue
        row = summary[feature]
        latency = row["latency_ms"]
        lines.append(
            f"| {titles[feature]} | {row['cases']} | "
            f"{_percent(row['success_rate'])} | "
            f"{_milliseconds(latency['p50'])} | "
            f"{_milliseconds(latency['p95'])} | "
            f"{row['human_ratings_pending']} |"
        )

    for feature in FEATURES:
        if feature not in summary:
            continue
        row = summary[feature]
        lines.extend(["", f"## {titles[feature]}", ""])
        if feature == "ai_search":
            lines.extend(
                [
                    f"- Đúng loại ảnh: {_percent(row['classification']['accuracy'])}",
                    f"- Đúng tên: {_percent(row['name_accuracy'])}",
                    f"- Ghép đúng dữ liệu món ăn ({row['db_match_cases']} mẫu): "
                    f"{_percent(row['db_match_accuracy'])}",
                    f"- Đúng đầu-cuối: {_percent(row['end_to_end_accuracy'])}",
                    f"- ECE của confidence: {_decimal(row['ece'])}",
                ]
            )
        elif feature == "ai_chat":
            lines.extend(
                [
                    f"- Đúng hành động điều hướng: {_percent(row['action_accuracy'])}",
                    f"- Bao phủ dữ kiện bắt buộc: {_percent(row['required_fact_coverage'])}",
                    f"- Tỷ lệ đạt tự động: {_percent(row['automatic_pass_rate'])}",
                ]
            )
        elif feature == "translation":
            lines.extend(
                [
                    f"- Token F1 trung bình: {_decimal(row['mean_token_f1'])}",
                    f"- chrF trung bình: {_decimal(row['mean_character_f_score'])}",
                    f"- Bảo toàn số: {_percent(row['number_preservation_rate'])}",
                    f"- Tỷ lệ đạt tự động: {_percent(row['automatic_pass_rate'])}",
                ]
            )
        elif feature == "tts":
            lines.extend(
                [
                    f"- Có audio URL: {_percent(row['audio_url_rate'])}",
                    f"- Audio truy cập được: {_percent(row['audio_reachable_rate'])}",
                    f"- Tỷ lệ đạt tự động: {_percent(row['automatic_pass_rate'])}",
                ]
            )
    lines.extend(
        [
            "",
            "## Cách hoàn tất đánh giá con người",
            "",
            "Mở `human_ratings.csv`, cho ít nhất 3 người chấm độc lập theo "
            "thang 1–5. Báo cáo trung bình, độ lệch chuẩn và mức đồng thuận; "
            "không gộp ô trống vào điểm trung bình.",
            "",
        ]
    )
    return "\n".join(lines)


def _percent(value: Any) -> str:
    return "N/A" if value is None else f"{float(value) * 100:.1f}%"


def _decimal(value: Any) -> str:
    return "N/A" if value is None else f"{float(value):.3f}"


def _milliseconds(value: Any) -> str:
    return "N/A" if value is None else f"{float(value):.0f} ms"


def _default_run_dir() -> Path:
    run_id = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    return PACKAGE_DIR / "results" / run_id


def _parse_features(raw: str) -> list[str]:
    selected = [item.strip() for item in raw.split(",") if item.strip()]
    unknown = sorted(set(selected) - set(FEATURES))
    if unknown:
        raise ValueError(f"Unsupported feature(s): {', '.join(unknown)}")
    return selected


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Evaluate HelloVietnam AI")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("validate")

    run_parser = subparsers.add_parser("run")
    run_parser.add_argument(
        "--features", default=",".join(FEATURES)
    )
    run_parser.add_argument("--limit", type=int)
    run_parser.add_argument("--env-file", default=str(DEFAULT_ENV_FILE))
    run_parser.add_argument("--output-dir")
    run_parser.add_argument("--provision-user", action="store_true")
    run_parser.add_argument(
        "--delay-seconds",
        type=float,
        default=0.0,
        help="Pause between cases to respect provider rate limits.",
    )

    summarize_parser = subparsers.add_parser("summarize")
    summarize_parser.add_argument("--run-dir", required=True)

    args = parser.parse_args(argv)
    try:
        if args.command == "validate":
            counts = validate_locked_datasets()
            print(json.dumps(counts, ensure_ascii=False, indent=2))
            return 0
        if args.command == "run":
            destination = Path(args.output_dir) if args.output_dir else _default_run_dir()
            summary = run_live_evaluation(
                features=_parse_features(args.features),
                limit=args.limit,
                env_file=args.env_file,
                output_dir=destination,
                provision_user=args.provision_user,
                access_token=None,
                delay_seconds=max(0.0, args.delay_seconds),
            )
            print(f"Artifacts: {destination.resolve()}")
            print(json.dumps(summary, ensure_ascii=False, indent=2))
            return 0
        if args.command == "summarize":
            run_dir = Path(args.run_dir)
            raw_rows = load_jsonl(run_dir / "raw.jsonl")
            for row in raw_rows:
                row.pop("_line", None)
            summary = write_artifacts(run_dir, raw_rows)
            print(json.dumps(summary, ensure_ascii=False, indent=2))
            return 0
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Evaluation failed: {error}", file=sys.stderr)
        return 1
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
