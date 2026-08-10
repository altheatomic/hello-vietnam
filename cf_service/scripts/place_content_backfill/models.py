from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from .constants import APPROVED_PROVINCES, EXPECTED_TOTAL, RUN_ID_PATTERN


class ManifestScopeError(ValueError):
    """Raised when a run manifest names a province outside the allowlist."""


class ImmutableModel(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class SourceFact(ImmutableModel):
    fact_id: str
    source_type: str
    source_url: str
    claim: str
    confidence: float = Field(ge=0.0, le=1.0)
    value: str | None = None
    locale: str | None = None

    @field_validator("fact_id", "source_type", "source_url", "claim")
    @classmethod
    def require_text(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("source fact text fields must not be blank")
        return value


class SourceSnapshot(ImmutableModel):
    place_id: str
    baseline_input_hash: str
    facts: tuple[SourceFact, ...] = ()
    warnings: tuple[str, ...] = ()
    sparse_source: bool = False
    collected_at: str | None = None


class BaselineRecord(ImmutableModel):
    place_id: str
    province_id: str
    status: str
    vi_name: str
    vi_short_description: str | None = None
    vi_detailed_description: str | None = None
    en_name: str | None = None
    en_short_description: str | None = None
    en_detailed_description: str | None = None
    address: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    subcategory_id: str | None = None
    subcategory_name: str | None = None
    subcategory_category: str | None = None
    source: str | None = None
    source_place_id: str | None = None
    website: str | None = None
    input_hash: str
    updated_at: str | None = None
    translation_updated_at_vi: str | None = None
    translation_updated_at_en: str | None = None
    content_freshness: tuple[dict[str, Any], ...] = ()
    tags: tuple[dict[str, Any], ...] = ()

    @field_validator("place_id", "province_id", "status", "vi_name", "input_hash")
    @classmethod
    def require_nonblank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("baseline identity fields must not be blank")
        return value


class NameDecision(ImmutableModel):
    place_id: str
    vi_name: str
    en_name: str
    confidence: float = Field(ge=0.0, le=1.0)
    rule_id: str
    review_only: bool = False
    warnings: tuple[str, ...] = ()
    protected_tokens: tuple[str, ...] = ()


class GeneratedContent(ImmutableModel):
    vi_short: str
    en_short: str
    vi_long: str
    en_long: str
    fact_ids: tuple[str, ...] = ()
    warnings: tuple[str, ...] = ()
    model: str | None = None
    prompt_version: str | None = None


class Proposal(ImmutableModel):
    place_id: str
    province_id: str
    baseline_input_hash: str
    source_snapshot_hash: str | None = None
    name_decision: NameDecision
    generated: GeneratedContent
    sparse_source: bool = False
    review_only: bool = True
    provider_models: tuple[str, ...] = ()
    repair_used: bool = False
    proposal_hash: str | None = None


class ValidationResult(ImmutableModel):
    place_id: str
    proposal_hash: str | None = None
    passed: bool
    errors: tuple[str, ...] = ()
    warnings: tuple[str, ...] = ()
    review_only: bool = True
    near_duplicate_place_ids: tuple[str, ...] = ()


class ReviewDecision(ImmutableModel):
    place_id: str
    decision: str
    notes: str = ""
    edited_fields: dict[str, Any] = Field(default_factory=dict)

    @field_validator("decision")
    @classmethod
    def valid_decision(cls, value: str) -> str:
        if value not in {"approve", "edit", "reject"}:
            raise ValueError("decision must be approve, edit, or reject")
        return value


class RunManifest(ImmutableModel):
    run_id: str = Field(pattern=RUN_ID_PATTERN)
    province_ids: tuple[str, ...]
    place_ids: tuple[str, ...] = ()
    expected_total: int | None = Field(default=None, ge=0)
    scope_name: str = "approved-five"
    created_at: str | None = None
    pilot_place_ids: tuple[str, ...] = ()

    @model_validator(mode="after")
    def validate_scope(self) -> "RunManifest":
        outside = set(self.province_ids).difference(APPROVED_PROVINCES)
        if outside:
            raise ManifestScopeError(
                "manifest contains province IDs outside approved scope: "
                + ", ".join(sorted(outside))
            )
        if not self.province_ids:
            raise ManifestScopeError("manifest must contain at least one approved province")
        expected = self.expected_total
        if expected is None:
            expected = sum(APPROVED_PROVINCES[province_id] for province_id in self.province_ids)
            object.__setattr__(self, "expected_total", expected)
        if self.place_ids and any(not str(place_id).strip() for place_id in self.place_ids):
            raise ValueError("manifest place IDs must not be blank")
        return self

    @property
    def province_count(self) -> int:
        return sum(APPROVED_PROVINCES[province_id] for province_id in self.province_ids)
