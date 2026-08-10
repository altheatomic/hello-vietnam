"""Deterministic validation and human-review reconciliation for proposals."""

from __future__ import annotations

import csv
import re
import unicodedata
from difflib import SequenceMatcher
from pathlib import Path
from typing import Iterable, Mapping, Sequence

from .models import (
    BaselineRecord,
    GeneratedContent,
    Proposal,
    SourceFact,
    SourceSnapshot,
    ValidationResult,
)


_WORD = re.compile(r"[^\W_]+(?:['’/-][^\W_]+)*", re.UNICODE)
_NUMBER = re.compile(r"(?<![A-Za-z])\d+(?:[.,]\d+)?(?![A-Za-z])")
_MARKUP = re.compile(r"(?:<[^>]+>|```|\[[^\]]+\]\([^)]*\)|(?:^|\s)[*_#>`])")
_PLACEHOLDERS = re.compile(
    r"\b(?:hihi|lorem ipsum|placeholder|tbd|todo|test(?:ing)?|demo|sample text|n/?a|unknown)\b",
    re.IGNORECASE,
)
_INSTRUCTION = re.compile(
    r"\b(?:ignore previous|system message|developer message|assistant:|user:|return json|output only|prompt injection)\b",
    re.IGNORECASE,
)
_FORBIDDEN_LITERAL = re.compile(
    r"\b(?:perfume river|forbidden(?: river| church| pagoda)?|interior surface)\b",
    re.IGNORECASE,
)
_EN_GENERIC = frozenset(
    {
        "river",
        "pagoda",
        "market",
        "mountain",
        "church",
        "parish",
        "museum",
        "airport",
        "station",
        "bus",
        "beach",
        "park",
        "temple",
        "bridge",
        "lake",
    }
)
_VI_GENERIC = frozenset(
    {
        "sông",
        "chùa",
        "chợ",
        "núi",
        "nhà",
        "thờ",
        "họ",
        "đạo",
        "bảo",
        "tàng",
        "sân",
        "bay",
        "ga",
        "bến",
        "xe",
        "đền",
        "cầu",
        "hồ",
        "bãi",
        "công",
        "viên",
    }
)


def validate_proposal(
    proposal: Proposal,
    baseline: BaselineRecord,
    sources: SourceSnapshot,
) -> ValidationResult:
    """Validate a proposal without an LLM judge or database side effect."""

    errors: list[str] = []
    warnings: list[str] = list(sources.warnings)
    flags: list[str] = []
    if proposal.place_id != baseline.place_id or sources.place_id != baseline.place_id:
        errors.append("place identity mismatch")
        return ValidationResult(valid=False, errors=tuple(errors), warnings=tuple(warnings), flags=("identity",))
    content = proposal.content
    if content is None:
        errors.append("missing generated content")
        return ValidationResult(valid=False, errors=tuple(errors), warnings=tuple(warnings), flags=("missing_content",))

    _validate_names(proposal, baseline, errors, flags)
    _validate_content_shape(content, errors, flags)
    _validate_facts(proposal, content, sources, errors, flags)
    _validate_claims(content, sources, errors, flags)
    _validate_category_and_province(content, baseline, sources, errors, flags)
    if content.confidence < 0.85:
        errors.append("confidence below auto-apply threshold 0.85")
        flags.append("low_confidence")
    return ValidationResult(
        valid=not errors,
        errors=tuple(_unique(errors)),
        warnings=tuple(_unique(warnings)),
        flags=tuple(_unique(flags)),
    )


def find_near_duplicates(proposals: Sequence[Proposal]) -> dict[str, list[str]]:
    """Find deterministic near-duplicate generated descriptions.

    Similarity is a character 5-gram Jaccard score, with a sequence-ratio
    fallback for very short text.  Punctuation and address-only suffixes are
    ignored so an operator cannot bypass review with formatting changes.
    """

    duplicates: dict[str, set[str]] = {}
    for index, left in enumerate(proposals):
        for right in proposals[index + 1 :]:
            if left.place_id == right.place_id:
                continue
            if _proposal_similarity(left, right) >= 0.92:
                duplicates.setdefault(left.place_id, set()).add(right.place_id)
                duplicates.setdefault(right.place_id, set()).add(left.place_id)
    return {place_id: sorted(values) for place_id, values in sorted(duplicates.items())}


def import_review_csv(
    path: Path,
    proposals: Sequence[Proposal],
    *,
    baselines: Mapping[str, BaselineRecord] | None = None,
    sources: Mapping[str, SourceSnapshot] | None = None,
) -> list[Proposal]:
    """Apply operator decisions from the exported CSV.

    ``edit`` rows must be revalidated with the matching immutable baseline and
    source snapshot.  Unknown decisions, duplicate IDs, or unknown places fail
    closed before returning any updated proposals.
    """

    by_id = {proposal.place_id: proposal for proposal in proposals}
    if len(by_id) != len(proposals):
        raise ValueError("proposal list contains duplicate place IDs")
    updated = dict(by_id)
    seen: set[str] = set()
    with Path(path).open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames or "place_id" not in reader.fieldnames:
            raise ValueError("review CSV must include place_id")
        for row in reader:
            place_id = str(row.get("place_id") or "").strip()
            decision = str(row.get("reviewer_decision") or "").strip().lower()
            if not place_id or place_id not in by_id:
                raise ValueError("review CSV contains unknown place_id")
            if place_id in seen:
                raise ValueError("review CSV contains duplicate place_id")
            if decision not in {"approve", "edit", "reject"}:
                raise ValueError("reviewer_decision must be approve, edit, or reject")
            seen.add(place_id)
            proposal = by_id[place_id]
            changes = {
                "reviewer_decision": decision,
                "reviewer_notes": (row.get("reviewer_notes") or "").strip() or None,
            }
            if decision == "edit":
                if baselines is None or sources is None or place_id not in baselines or place_id not in sources:
                    raise ValueError("edited rows require baseline and source snapshots for revalidation")
                content = proposal.content
                if content is None:
                    raise ValueError("edited row has no generated content")
                required = (
                    "short_description_vi",
                    "detailed_description_vi",
                    "short_description_en",
                    "detailed_description_en",
                )
                if any(not str(row.get(field) or "").strip() for field in required):
                    raise ValueError("edited row must contain all four descriptions")
                edited_content = content.model_copy(
                    update={field: str(row[field]).strip() for field in required}
                )
                changes.update(
                    {
                        "proposed_name_vi": str(row.get("proposed_name_vi") or proposal.proposed_name_vi or "").strip(),
                        "proposed_name_en": str(row.get("proposed_name_en") or proposal.proposed_name_en or "").strip(),
                        "content": edited_content,
                    }
                )
            candidate = proposal.model_copy(update=changes)
            if baselines is not None and sources is not None and place_id in baselines and place_id in sources:
                result = validate_proposal(candidate, baselines[place_id], sources[place_id])
                if not result.valid:
                    raise ValueError(f"review decision for {place_id} fails validation: {'; '.join(result.errors)}")
                candidate = candidate.model_copy(update={"validation": result})
            updated[place_id] = candidate
    return [updated[proposal.place_id] for proposal in proposals]


def _validate_names(proposal: Proposal, baseline: BaselineRecord, errors: list[str], flags: list[str]) -> None:
    proposed_vi = (proposal.proposed_name_vi or baseline.vi.name or baseline.name or "").strip()
    proposed_en = (proposal.proposed_name_en or baseline.en.name or "").strip()
    if not proposed_vi:
        errors.append("missing Vietnamese name")
        flags.append("name")
    elif _fold(proposed_vi) != _fold(baseline.name or baseline.vi.name or ""):
        errors.append("Vietnamese source name changed")
        flags.append("name")
    if not proposed_en:
        errors.append("missing English name")
        flags.append("name")
    if _FORBIDDEN_LITERAL.search(proposed_vi + " " + proposed_en):
        errors.append("forbidden literal translation in name")
        flags.append("name")
    if proposed_en and not _name_identity_overlap(baseline.name or baseline.vi.name or "", proposed_en):
        errors.append("English name disagrees with protected place identity")
        flags.append("name")
    if _protected_fragments(baseline.name or "") - _protected_fragments(proposed_vi):
        errors.append("protected Vietnamese digits/acronyms changed")
        flags.append("name")
    if _protected_fragments(baseline.en.name or "") - _protected_fragments(proposed_en):
        errors.append("protected English digits/acronyms changed")
        flags.append("name")


def _validate_content_shape(content: GeneratedContent, errors: list[str], flags: list[str]) -> None:
    for field, low, high in (
        ("short_description_vi", 20, 45),
        ("short_description_en", 20, 45),
        ("detailed_description_vi", 90, 160),
        ("detailed_description_en", 90, 160),
    ):
        value = getattr(content, field).strip()
        count = len(_WORD.findall(value))
        if not value or not low <= count <= high:
            errors.append(f"{field} must contain {low}-{high} words (got {count})")
            flags.append("word_count")
        if _MARKUP.search(value):
            errors.append(f"{field} contains Markdown or HTML")
            flags.append("markup")
        if _PLACEHOLDERS.search(value):
            errors.append(f"{field} contains placeholder text")
            flags.append("placeholder")
        if _INSTRUCTION.search(value):
            errors.append(f"{field} contains model/instruction text")
            flags.append("instruction")
        if _FORBIDDEN_LITERAL.search(value):
            errors.append(f"{field} contains forbidden literal translation")
            flags.append("literal_translation")


def _validate_facts(
    proposal: Proposal,
    content: GeneratedContent,
    sources: SourceSnapshot,
    errors: list[str],
    flags: list[str],
) -> None:
    known = {fact.fact_id for fact in sources.facts}
    used = set(content.used_fact_ids)
    if not used.issubset(known):
        errors.append("used_fact_ids contains an unknown source fact")
        flags.append("grounding")
    if not set(proposal.source_fact_ids).issubset(known):
        errors.append("proposal source_fact_ids contains an unknown source fact")
        flags.append("grounding")
    urls = {fact.source_url for fact in sources.facts if fact.fact_id in used}
    if proposal.source_urls and not set(proposal.source_urls).issubset(urls):
        errors.append("proposal source_urls are not backed by used facts")
        flags.append("grounding")


def _validate_claims(
    content: GeneratedContent,
    sources: SourceSnapshot,
    errors: list[str],
    flags: list[str],
) -> None:
    used = set(content.used_fact_ids)
    allowed_numbers = {
        _number_key(number)
        for fact in sources.facts
        if fact.fact_id in used
        for number in _NUMBER.findall(fact.value)
    }
    for field in (
        "short_description_vi",
        "detailed_description_vi",
        "short_description_en",
        "detailed_description_en",
    ):
        for number in _NUMBER.findall(getattr(content, field)):
            if _number_key(number) not in allowed_numbers:
                errors.append(f"numeric claim in {field} is not grounded in a used fact")
                flags.append("numeric_claim")


def _validate_category_and_province(
    content: GeneratedContent,
    baseline: BaselineRecord,
    sources: SourceSnapshot,
    errors: list[str],
    flags: list[str],
) -> None:
    text = " ".join(
        getattr(content, field)
        for field in (
            "short_description_vi",
            "detailed_description_vi",
            "short_description_en",
            "detailed_description_en",
        )
    )
    category = " ".join(
        value or "" for value in (baseline.subcategory_category, baseline.subcategory_name)
    ).casefold()
    # Only reject an explicit, source-backed category contradiction; generic
    # travel prose is otherwise allowed to mention neighbouring features.
    if any(term in category for term in ("restaurant", "food", "cafe")) and re.search(
        r"\b(?:museum|pagoda|church|river|lake|mountain)\b", text, re.IGNORECASE
    ) and not re.search(r"\b(?:restaurant|food|cafe|ẩm thực|quán)\b", text, re.IGNORECASE):
        errors.append("description category disagrees with baseline category")
        flags.append("category")
    province_facts = [
        fact.value for fact in sources.facts if "province" in fact.fact_id.casefold()
    ]
    if province_facts and not any(_fold(value) in _fold(text) for value in province_facts):
        # A source may intentionally omit the province in copy; only flag an
        # explicit different province token when one is present.
        others = [value for value in province_facts if _fold(value) not in _fold(text)]
        if others and any(_fold(value) in _fold(text) for value in others):
            errors.append("description province disagrees with source")
            flags.append("province")


def _proposal_similarity(left: Proposal, right: Proposal) -> float:
    left_text = _similarity_text(left)
    right_text = _similarity_text(right)
    if left_text == right_text:
        return 1.0
    left_grams = _grams(left_text)
    right_grams = _grams(right_text)
    if left_grams and right_grams:
        return len(left_grams & right_grams) / len(left_grams | right_grams)
    return SequenceMatcher(a=left_text, b=right_text).ratio()


def _similarity_text(proposal: Proposal) -> str:
    if proposal.content is None:
        return ""
    values = (
        proposal.content.short_description_vi,
        proposal.content.detailed_description_vi,
        proposal.content.short_description_en,
        proposal.content.detailed_description_en,
    )
    text = " ".join(values).casefold()
    # Address-only additions should not make two generated descriptions look
    # distinct.  The pattern is intentionally conservative.
    text = re.sub(r"\b(?:address|địa chỉ)\s*[:\-]?[^.!?]*[.!?]?", " ", text)
    text = re.sub(r"[^\w\s]", " ", text, flags=re.UNICODE)
    return " ".join(text.split())


def _grams(text: str, size: int = 5) -> set[str]:
    if len(text) < size:
        return set()
    return {text[index : index + size] for index in range(len(text) - size + 1)}


def _name_identity_overlap(vietnamese: str, english: str) -> bool:
    vi_tokens = {_fold_token(token) for token in _tokens(vietnamese)} - {
        _fold_token(token) for token in _VI_GENERIC
    }
    en_tokens = {_fold_token(token) for token in _tokens(english)} - {
        _fold_token(token) for token in _EN_GENERIC
    }
    if not vi_tokens or not en_tokens:
        return False
    return bool(vi_tokens & en_tokens)


def _protected_fragments(value: str) -> set[str]:
    numbers = {_number_key(number) for number in _NUMBER.findall(value)}
    acronyms = {
        token.casefold()
        for token in re.findall(r"\b[A-ZÀ-Ỹ]{2,}\b", value)
    }
    return numbers | acronyms


def _tokens(value: str) -> tuple[str, ...]:
    return tuple(_WORD.findall(value))


def _fold(value: str) -> str:
    return " ".join(unicodedata.normalize("NFC", value).casefold().split())


def _fold_token(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    return "".join(char for char in normalized if not unicodedata.combining(char)).casefold()


def _number_key(value: str) -> str:
    return value.replace(",", ".").rstrip("0").rstrip(".") or "0"


def _unique(values: Iterable[str]) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()
    for value in values:
        if value not in seen:
            seen.add(value)
            result.append(value)
    return result


__all__ = ["find_near_duplicates", "import_review_csv", "validate_proposal"]
