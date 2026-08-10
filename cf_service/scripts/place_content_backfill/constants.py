from __future__ import annotations

from datetime import datetime, timezone
import re
import secrets


APPROVED_PROVINCES: dict[str, int] = {
    "094014a7-b8f6-481a-bbce-5ed6cdd457c5": 539,  # Hồ Chí Minh
    "b5f3ef5e-dc49-4482-88e3-a8048cb32639": 201,  # Huế
    "3355c4a1-ccb1-46be-99e5-046d5f55b891": 235,  # Hà Nội
    "8f9d18e3-7e24-4e36-bf50-a3823c1f78df": 200,  # Quảng Ninh
    "49fa7ad8-b892-494d-a712-bb49802200c1": 358,  # Lâm Đồng
}

PROVINCE_NAMES: dict[str, str] = {
    "094014a7-b8f6-481a-bbce-5ed6cdd457c5": "Hồ Chí Minh",
    "b5f3ef5e-dc49-4482-88e3-a8048cb32639": "Huế",
    "3355c4a1-ccb1-46be-99e5-046d5f55b891": "Hà Nội",
    "8f9d18e3-7e24-4e36-bf50-a3823c1f78df": "Quảng Ninh",
    "49fa7ad8-b892-494d-a712-bb49802200c1": "Lâm Đồng",
}

EXPECTED_TOTAL = sum(APPROVED_PROVINCES.values())
RUN_ID_PATTERN = r"^\d{8}-\d{6}-[0-9a-f]{8}$"
RUN_ID_RE = re.compile(RUN_ID_PATTERN)

DEFAULT_PAGE_SIZE = 500
DEFAULT_RELATED_BATCH_SIZE = 200
DEFAULT_OSM_BATCH_SIZE = 100
DEFAULT_APPLY_BATCH_SIZE = 50
DEFAULT_HTTP_CONCURRENCY = 3
DEFAULT_COLLECT_WORKER_CHUNK_SIZE = 50
DEFAULT_GENERATE_WORKER_CHUNK_SIZE = 25
DEFAULT_VALIDATE_WORKER_CHUNK_SIZE = 100

ARTIFACT_FILENAMES: dict[str, str] = {
    "manifest": "manifest.json",
    "baseline": "baseline.jsonl",
    "sources": "sources.jsonl",
    "proposals": "proposals.jsonl",
    "generation-budget": "generation-budget.jsonl",
    "validations": "validations.jsonl",
    "approved": "approved.jsonl",
    "needs-review": "needs-review.csv",
    "review-decisions": "review-decisions.jsonl",
    "applied": "applied.jsonl",
    "rollback": "rollback.jsonl",
}

REVIEW_CSV_FIELDS: tuple[str, ...] = (
    "place_id",
    "province_id",
    "current_vi_name",
    "proposed_vi_name",
    "current_en_name",
    "proposed_en_name",
    "current_vi_description",
    "proposed_vi_description",
    "current_en_description",
    "proposed_en_description",
    "current_vi_detailed_description",
    "proposed_vi_detailed_description",
    "current_en_detailed_description",
    "proposed_en_detailed_description",
    "flags",
    "source_urls",
    "reviewer_decision",
    "reviewer_notes",
)


def new_run_id(now: datetime | None = None) -> str:
    """Return a timestamped, non-secret run identifier."""

    moment = now or datetime.now(timezone.utc)
    return f"{moment:%Y%m%d-%H%M%S}-{secrets.token_hex(4)}"
