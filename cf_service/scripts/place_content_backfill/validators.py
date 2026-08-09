from __future__ import annotations

import csv
from collections import defaultdict
import re
import sqlite3
import tempfile
from pathlib import Path
from typing import Any, Callable, Iterable, Mapping

from .artifacts import ArtifactStore, _reject_secrets
from .constants import PROVINCE_NAMES
from .models import (
    BaselineRecord,
    Proposal,
    ReviewDecision,
    SourceSnapshot,
    ValidationResult,
)


MIN_SHORT_WORDS = 20
MAX_SHORT_WORDS = 45
MIN_LONG_WORDS = 90
MAX_LONG_WORDS = 160
DUPLICATE_NGRAM_SIZE = 5
DUPLICATE_THRESHOLD = 0.92

_PLACEHOLDER_RE = re.compile(r"\b(?:lorem ipsum|placeholder|tbd|todo|n/?a)\b", re.IGNORECASE)
_MARKUP_RE = re.compile(r"(?:<[^>]+>|```?|\[[^\]]+\]\([^\)]+\))")
_INSTRUCTION_RE = re.compile(
    r"(?:ignore previous instructions|system message|as an ai|developer message|"
    r"follow these instructions|do not reveal)",
    re.IGNORECASE,
)
_NUMERIC_RE = re.compile(r"(?<![A-Za-z0-9])\d+(?:[.,]\d+)?(?![A-Za-z0-9])")
_TOKEN_RE = re.compile(r"[\wÀ-ỹ]+", re.UNICODE)
_FORBIDDEN_LITERAL_TRANSLATIONS = {
    "Perfume River",
    "Fragrant River",
    "Incense River",
}
_CATEGORY_CONFLICTS = {
    "chùa": ("airport", "airfield", "bus station"),
    "pagoda": ("airport", "airfield", "bus station"),
    "sân bay": ("pagoda", "museum", "temple"),
    "airport": ("pagoda", "museum", "temple"),
}


def _normalized(text: str) -> str:
    return " ".join(text.casefold().split())


def _all_copy(proposal: Proposal) -> str:
    generated = proposal.generated
    return " ".join(
        (
            proposal.name_decision.en_name,
            generated.vi_short,
            generated.en_short,
            generated.vi_long,
            generated.en_long,
        )
    )


def _five_grams(text: str) -> set[str]:
    normalized = _normalized(text)
    if not normalized:
        return set()
    if len(normalized) < DUPLICATE_NGRAM_SIZE:
        return {normalized}
    return {
        normalized[index:index + DUPLICATE_NGRAM_SIZE]
        for index in range(len(normalized) - DUPLICATE_NGRAM_SIZE + 1)
    }


def _source_text(sources: SourceSnapshot) -> str:
    return " ".join(
        f"{fact.claim} {fact.value or ''}" for fact in sources.facts
    )


def _validation_errors(
    proposal: Proposal,
    baseline: BaselineRecord,
    sources: SourceSnapshot,
) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = [
        *sources.warnings,
        *proposal.name_decision.warnings,
        *proposal.generated.warnings,
    ]
    if proposal.place_id != baseline.place_id:
        errors.append("place ID disagreement")
    if proposal.province_id != baseline.province_id:
        errors.append("province ID disagreement")
    if proposal.baseline_input_hash != baseline.input_hash:
        errors.append("baseline input hash disagreement")
    if sources.place_id != baseline.place_id:
        errors.append("source snapshot place ID disagreement")
    if sources.baseline_input_hash != baseline.input_hash:
        errors.append("source snapshot baseline hash disagreement")
    decision = proposal.name_decision
    if decision.place_id != baseline.place_id or decision.vi_name != baseline.vi_name:
        errors.append("locked Vietnamese name disagreement")
    if decision.confidence < 0.85:
        warnings.append("naming confidence below 0.85")
    if decision.review_only:
        warnings.append("naming decision requires review")
    if proposal.sparse_source or sources.sparse_source:
        warnings.append("sparse source requires review")
    if proposal.review_only:
        warnings.append("proposal is review-only")
    proposed_name = decision.en_name
    name_tokens = {_normalized(token) for token in _TOKEN_RE.findall(proposed_name)}
    for protected in decision.protected_tokens:
        if _normalized(protected) not in name_tokens:
            errors.append(f"protected token loss: {protected}")
    baseline_tokens = _TOKEN_RE.findall(baseline.vi_name)
    for token in baseline_tokens:
        if token.isdigit() or (len(token) >= 2 and token.isupper()):
            if _normalized(token) not in name_tokens:
                errors.append(f"changed digit/acronym/brand token: {token}")
    if decision.rule_id == "preserve-proper-name" and decision.en_name != baseline.vi_name:
        errors.append("brand/proper name was changed")

    for field_name, minimum, maximum in (
        ("vi_short", MIN_SHORT_WORDS, MAX_SHORT_WORDS),
        ("en_short", MIN_SHORT_WORDS, MAX_SHORT_WORDS),
        ("vi_long", MIN_LONG_WORDS, MAX_LONG_WORDS),
        ("en_long", MIN_LONG_WORDS, MAX_LONG_WORDS),
    ):
        value = getattr(proposal.generated, field_name)
        if not value or not value.strip():
            errors.append(f"{field_name} is empty")
            continue
        count = len(value.split())
        if count < minimum or count > maximum:
            errors.append(f"{field_name} word count outside {minimum}-{maximum}")
        if _PLACEHOLDER_RE.search(value):
            errors.append(f"{field_name} contains a placeholder")
        if _MARKUP_RE.search(value):
            errors.append(f"{field_name} contains Markdown or HTML")
        if _INSTRUCTION_RE.search(value):
            errors.append(f"{field_name} contains an instruction fragment")

    copy_text = _all_copy(proposal)
    for forbidden in _FORBIDDEN_LITERAL_TRANSLATIONS:
        if forbidden.casefold() in copy_text.casefold():
            errors.append(f"forbidden literal translation: {forbidden}")
    evidence = _source_text(sources)
    unsupported_numbers = set(_NUMERIC_RE.findall(copy_text)) - set(_NUMERIC_RE.findall(evidence))
    if unsupported_numbers:
        errors.append("unreferenced numeric claim")
    known_fact_ids = {fact.fact_id for fact in sources.facts}
    if not set(proposal.generated.fact_ids).issubset(known_fact_ids):
        errors.append("generated fact ID is not in source snapshot")

    copy_lower = copy_text.casefold()
    for province_id, province_name in PROVINCE_NAMES.items():
        if province_id != baseline.province_id and province_name.casefold() in copy_lower:
            errors.append("province disagreement")
    category_text = " ".join(
        value for value in (baseline.subcategory_name, baseline.subcategory_category) if value
    ).casefold()
    for marker, conflicts in _CATEGORY_CONFLICTS.items():
        if marker in category_text and any(conflict in copy_lower for conflict in conflicts):
            errors.append("category/name disagreement")
            break
    return list(dict.fromkeys(errors)), list(dict.fromkeys(warnings))


def validate_proposal(
    proposal: Proposal,
    baseline: BaselineRecord,
    sources: SourceSnapshot,
) -> ValidationResult:
    errors, warnings = _validation_errors(proposal, baseline, sources)
    return ValidationResult(
        place_id=proposal.place_id,
        proposal_hash=proposal.proposal_hash,
        passed=not errors,
        errors=tuple(errors),
        warnings=tuple(warnings),
        review_only=bool(warnings) or proposal.review_only,
    )


def validate_worker(
    items: Iterable[tuple[Proposal, BaselineRecord, SourceSnapshot]],
    artifact_store: ArtifactStore,
    *,
    max_places: int = 100,
) -> int:
    """Validate one bounded worker chunk and fsync each result immediately."""

    if max_places <= 0:
        raise ValueError("max_places must be positive")
    count = 0
    for proposal, baseline, sources in items:
        count += 1
        if count > max_places:
            raise ValueError(f"validate worker received more than {max_places} proposals")
        result = validate_proposal(proposal, baseline, sources)
        artifact_store.append_jsonl("validations", result.model_dump(mode="json"))
    return count


def find_near_duplicates(
    texts: Mapping[str, str],
    *,
    threshold: float = DUPLICATE_THRESHOLD,
    chunk_size: int = 200,
    sqlite_path: str | Path | None = None,
) -> dict[str, tuple[str, ...]]:
    """Find similar text via a temporary SQLite gram index, never a matrix."""

    if not 0 < threshold <= 1:
        raise ValueError("threshold must be in (0, 1]")
    if chunk_size <= 0:
        raise ValueError("chunk_size must be positive")
    temporary_directory: tempfile.TemporaryDirectory[str] | None = None
    if sqlite_path is None:
        temporary_directory = tempfile.TemporaryDirectory(prefix="place-content-duplicates-")
        database_path = Path(temporary_directory.name) / "signatures.sqlite3"
    else:
        database_path = Path(sqlite_path)
        database_path.parent.mkdir(parents=True, exist_ok=True)
    result: dict[str, set[str]] = defaultdict(set)
    try:
        connection = sqlite3.connect(database_path)
        try:
            connection.execute("create table grams(place_id text not null, gram text not null, primary key(place_id, gram))")
            connection.execute("create index grams_by_gram on grams(gram)")
            connection.execute("create table gram_counts(place_id text primary key, count integer not null)")
            ids = list(texts.keys())
            for start in range(0, len(ids), chunk_size):
                rows = []
                counts = []
                for place_id in ids[start:start + chunk_size]:
                    grams = _five_grams(texts[place_id])
                    rows.extend((place_id, gram) for gram in grams)
                    counts.append((place_id, len(grams)))
                connection.executemany("insert into grams(place_id, gram) values (?, ?)", rows)
                connection.executemany("insert into gram_counts(place_id, count) values (?, ?)", counts)
                connection.commit()
            for place_id in ids:
                grams = [row[0] for row in connection.execute("select gram from grams where place_id = ?", (place_id,))]
                if not grams:
                    continue
                common_by_candidate: dict[str, int] = defaultdict(int)
                for start in range(0, len(grams), chunk_size):
                    placeholders = ",".join("?" for _ in grams[start:start + chunk_size])
                    query = (
                        "select place_id, count(*) from grams "
                        f"where gram in ({placeholders}) and place_id <> ? group by place_id"
                    )
                    params = [*grams[start:start + chunk_size], place_id]
                    for candidate, common in connection.execute(query, params):
                        common_by_candidate[candidate] += int(common)
                own_count = len(grams)
                for candidate, common in common_by_candidate.items():
                    other_count = connection.execute(
                        "select count from gram_counts where place_id = ?", (candidate,)
                    ).fetchone()[0]
                    union = own_count + other_count - common
                    similarity = common / union if union else 0.0
                    if similarity >= threshold:
                        result[place_id].add(candidate)
                        result[candidate].add(place_id)
        finally:
            connection.close()
    finally:
        if temporary_directory is not None:
            temporary_directory.cleanup()
    return {place_id: tuple(sorted(values)) for place_id, values in result.items()}


class ReviewImportError(ValueError):
    pass


def validate_edited_fields(
    proposal: Proposal,
    baseline: BaselineRecord,
    sources: SourceSnapshot,
    edited_fields: Mapping[str, str],
) -> bool:
    """Apply reviewer edits to an immutable proposal and rerun all validators."""

    generated_updates: dict[str, str] = {}
    name_updates: dict[str, str] = {}
    field_map = {
        "proposed_vi_name": (name_updates, "vi_name"),
        "proposed_en_name": (name_updates, "en_name"),
        "proposed_vi_description": (generated_updates, "vi_short"),
        "proposed_en_description": (generated_updates, "en_short"),
        "proposed_vi_detailed_description": (generated_updates, "vi_long"),
        "proposed_en_detailed_description": (generated_updates, "en_long"),
    }
    for field_name, value in edited_fields.items():
        target = field_map.get(field_name)
        if target is None:
            return False
        if not isinstance(value, str) or not value.strip():
            return False
        destination, destination_name = target
        destination[destination_name] = value
    edited_proposal = proposal.model_copy(
        update={
            "name_decision": proposal.name_decision.model_copy(update=name_updates),
            "generated": proposal.generated.model_copy(update=generated_updates),
        }
    )
    return validate_proposal(edited_proposal, baseline, sources).passed


def import_review_csv(
    store: ArtifactStore,
    csv_path: str | Path,
    *,
    validate_edit: Callable[[str, Mapping[str, str]], bool] | None = None,
) -> int:
    """Append one validated human decision at a time."""

    count = 0
    with Path(csv_path).open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            _reject_secrets(row)
            place_id = str(row.get("place_id") or "").strip()
            decision = str(row.get("reviewer_decision") or "").strip().lower()
            if not place_id or decision not in {"approve", "edit", "reject"}:
                raise ReviewImportError("each review row needs a place_id and approve/edit/reject decision")
            edited_fields = {
                key: value
                for key, value in row.items()
                if key.startswith("proposed_") and value not in (None, "")
            }
            unknown_edit_fields = set(edited_fields).difference(
                {
                    "proposed_vi_name",
                    "proposed_en_name",
                    "proposed_vi_description",
                    "proposed_en_description",
                    "proposed_vi_detailed_description",
                    "proposed_en_detailed_description",
                }
            )
            if unknown_edit_fields:
                raise ReviewImportError(
                    "edited fields are not part of the place content contract: "
                    + ", ".join(sorted(unknown_edit_fields))
                )
            if decision == "edit":
                if validate_edit is None or not validate_edit(place_id, edited_fields):
                    raise ReviewImportError(f"edited fields failed deterministic validation for {place_id}")
            review = ReviewDecision(
                place_id=place_id,
                decision=decision,
                notes=str(row.get("reviewer_notes") or ""),
                edited_fields=edited_fields,
            )
            store.append_jsonl("review-decisions", review.model_dump(mode="json"))
            count += 1
    return count


def _review_row(
    proposal: Proposal,
    validation: ValidationResult,
    baseline: BaselineRecord,
    sources: SourceSnapshot | None = None,
) -> dict[str, Any]:
    generated = proposal.generated
    return {
        "place_id": proposal.place_id,
        "province_id": proposal.province_id,
        "current_vi_name": baseline.vi_name,
        "proposed_vi_name": proposal.name_decision.vi_name,
        "current_en_name": baseline.en_name or "",
        "proposed_en_name": proposal.name_decision.en_name,
        "current_vi_description": baseline.vi_short_description or "",
        "proposed_vi_description": generated.vi_short,
        "current_en_description": baseline.en_short_description or "",
        "proposed_en_description": generated.en_short,
        "current_vi_detailed_description": baseline.vi_detailed_description or "",
        "proposed_vi_detailed_description": generated.vi_long,
        "current_en_detailed_description": baseline.en_detailed_description or "",
        "proposed_en_detailed_description": generated.en_long,
        "flags": "; ".join((*validation.errors, *validation.warnings)),
        "source_urls": "; ".join(
            fact.source_url for fact in (sources.facts if sources is not None else ())
        ),
        "reviewer_decision": "",
        "reviewer_notes": "",
    }


def rebuild_review_artifacts(
    store: ArtifactStore,
    items: Iterable[
        tuple[Proposal, ValidationResult, BaselineRecord]
        | tuple[Proposal, ValidationResult, BaselineRecord, SourceSnapshot]
    ],
    *,
    decisions: Iterable[ReviewDecision],
) -> dict[str, int]:
    """Rebuild derived review outputs from immutable proposals and decisions."""

    decision_by_place = {decision.place_id: decision for decision in decisions}
    counts = {"approved": 0, "needs_review": 0, "rejected": 0}
    def derived_rows() -> Iterable[tuple[dict[str, Any] | None, dict[str, Any] | None]]:
        for item in items:
            proposal, validation, baseline = item[:3]
            sources = item[3] if len(item) == 4 else None
            decision = decision_by_place.get(proposal.place_id)
            if decision is not None and decision.decision == "reject":
                counts["rejected"] += 1
                yield None, _review_row(
                    proposal,
                    validation,
                    baseline,
                    sources,
                ) | {"flags": "rejected by reviewer"}
                continue
            if decision is not None and decision.decision == "approve" and validation.passed:
                counts["approved"] += 1
                yield proposal.model_dump(mode="json"), None
                continue
            if decision is not None and decision.decision == "edit":
                # Edits are revalidated by the caller before this derived merge.
                # Keeping them in review when that proof is absent is the safe default.
                counts["needs_review"] += 1
                yield None, _review_row(
                    proposal,
                    validation,
                    baseline,
                    sources,
                ) | {"flags": "edited fields require revalidation"}
                continue
            counts["needs_review"] += 1
            yield None, _review_row(proposal, validation, baseline, sources)

    store.replace_derived_outputs(derived_rows())
    return counts


__all__ = [
    "find_near_duplicates",
    "import_review_csv",
    "rebuild_review_artifacts",
    "validate_edited_fields",
    "validate_proposal",
    "validate_worker",
]
