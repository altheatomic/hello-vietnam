"""Strict immutable data contracts shared by every pipeline stage."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Literal, Sequence
from uuid import uuid4

from pydantic import BaseModel, ConfigDict, Field, model_validator

from .constants import (
    APPROVED_PROVINCES,
    EXPECTED_TOTAL,
    PROVINCE_EXPECTED_COUNTS,
    PROMPT_VERSION,
)


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class TranslationBaseline(StrictModel):
    id: str
    place_id: str
    lang_code: Literal["vi", "en"]
    name: str | None = None
    description: str | None = None
    detailed_description: str | None = None
    created_at: str | None = None
    updated_at: str | None = None


class BaselineRecord(StrictModel):
    place_id: str
    province_id: str
    status: str | None = None
    name: str | None = None
    short_description: str | None = None
    detailed_description: str | None = None
    address: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    source: str | None = None
    source_place_id: str | None = None
    wikidata: str | None = None
    wikipedia: str | None = None
    official_name: str | None = None
    website: str | None = None
    freshness_source_type: str | None = None
    freshness_source_url: str | None = None
    freshness_source_external_id: str | None = None
    availability_type: str | None = None
    valid_from: str | None = None
    valid_until: str | None = None
    subcategory_id: str | None = None
    subcategory_name: str | None = None
    subcategory_category: str | None = None
    tags: tuple[str, ...] = ()
    created_at: str | None = None
    updated_at: str | None = None
    vi: TranslationBaseline
    en: TranslationBaseline

    @model_validator(mode="after")
    def translations_match_place(self) -> "BaselineRecord":
        if self.vi.place_id != self.place_id or self.en.place_id != self.place_id:
            raise ValueError("translation place_id must match baseline place_id")
        return self


class SourceFact(StrictModel):
    fact_id: str
    value: str
    source_url: str
    source_kind: str = "unknown"
    confidence: float = Field(default=1.0, ge=0, le=1)


class SourceSnapshot(StrictModel):
    place_id: str
    facts: tuple[SourceFact, ...] = ()
    warnings: tuple[str, ...] = ()
    input_hash: str | None = None
    collected_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )


class NameDecision(StrictModel):
    place_id: str
    vietnamese_name: str
    english_name: str
    rule: str
    source: str
    confidence: float = Field(ge=0, le=1)
    warnings: tuple[str, ...] = ()
    rejected_alternatives: tuple[str, ...] = ()


class GeneratedContent(StrictModel):
    short_description_vi: str
    detailed_description_vi: str
    short_description_en: str
    detailed_description_en: str
    used_fact_ids: tuple[str, ...] = ()
    warnings: tuple[str, ...] = ()
    confidence: float = Field(ge=0, le=1)


class ValidationResult(StrictModel):
    valid: bool
    errors: tuple[str, ...] = ()
    warnings: tuple[str, ...] = ()
    flags: tuple[str, ...] = ()


class Proposal(StrictModel):
    place_id: str
    province_id: str
    baseline_hash: str
    current_name_vi: str | None = None
    proposed_name_vi: str | None = None
    current_name_en: str | None = None
    proposed_name_en: str | None = None
    content: GeneratedContent | None = None
    source_fact_ids: tuple[str, ...] = ()
    source_urls: tuple[str, ...] = ()
    validation: ValidationResult | None = None
    reviewer_decision: Literal["approve", "edit", "reject"] | None = None
    reviewer_notes: str | None = None


class RunManifest(StrictModel):
    run_id: str
    scope: str
    province_ids: tuple[str, ...]
    expected_counts: dict[str, int]
    expected_total: int
    prompt_version: str = PROMPT_VERSION
    status: str = "created"
    created_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    baseline_hash: str | None = None

    @classmethod
    def new(
        cls,
        province_ids: Sequence[str] | None = None,
        *,
        run_id: str | None = None,
        scope: str = "approved-five",
    ) -> "RunManifest":
        ids = tuple(province_ids or APPROVED_PROVINCES)
        unknown = sorted(set(ids) - set(APPROVED_PROVINCES))
        if unknown:
            raise ValueError(f"province outside approved scope: {unknown}")
        if len(ids) != len(set(ids)):
            raise ValueError("province scope contains duplicate IDs")
        expected_counts = {
            province_id: PROVINCE_EXPECTED_COUNTS[province_id]
            for province_id in ids
        }
        return cls(
            run_id=run_id or f"pending-{uuid4().hex[:8]}",
            scope=scope,
            province_ids=ids,
            expected_counts=expected_counts,
            expected_total=sum(expected_counts.values()),
        )


def model_to_jsonable(value: BaseModel | dict[str, Any]) -> dict[str, Any]:
    """Serialize a model without allowing arbitrary objects into artifacts."""

    if isinstance(value, BaseModel):
        return value.model_dump(mode="json")
    if not isinstance(value, dict):
        raise TypeError("artifact values must be Pydantic models or dictionaries")
    return value
