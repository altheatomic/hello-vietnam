"""Deterministic, identity-preserving place-name normalization.

The Vietnamese name is the source-of-truth.  This module deliberately does
not transliterate proper names or ask a language model to choose a display
name; it only translates a small, reviewed set of generic type prefixes.
"""

from __future__ import annotations

import re
import unicodedata
from typing import Iterable

from .models import BaselineRecord, NameDecision, SourceFact, SourceSnapshot


# Longest first is important for names such as ``Nhà Thờ Giáo Xứ ...``.
GENERIC_PREFIXES: tuple[tuple[str, str], ...] = tuple(
    sorted(
        (
            ("Nhà Thờ Giáo Xứ", "Parish Church"),
            ("Nhà Thờ Họ Đạo", "Parish Church"),
            ("Nhà Thờ", "Church"),
            ("Bảo Tàng", "Museum"),
            ("Sân Bay", "Airport"),
            ("Nhà Ga", "Station"),
            ("Bến Xe", "Bus Station"),
            ("Công Viên", "Park"),
            ("Chùa", "Pagoda"),
            ("Đền", "Temple"),
            ("Chợ", "Market"),
            ("Cầu", "Bridge"),
            ("Sông", "River"),
            ("Hồ", "Lake"),
            ("Núi", "Mountain"),
            ("Bãi", "Beach"),
        ),
        key=lambda item: len(item[0]),
        reverse=True,
    )
)

_SUSPICIOUS_TRANSLATIONS = frozenset(
    {
        "perfume river",
        "forbidden river",
        "forbidden church",
        "forbidden pagoda",
        "interior surface",
    }
)
_BRAND_CONTEXT = re.compile(
    r"\b(?:food|restaurant|cafe|coffee|bar|brand|shop|store|hotel|resort|mall|market)\b",
    re.IGNORECASE,
)
_NATURE_CONTEXT = re.compile(
    r"\b(?:nature|natural|river|lake|mountain|beach|park|landscape|geography)\b",
    re.IGNORECASE,
)


def normalize_names(record: BaselineRecord, sources: SourceSnapshot) -> NameDecision:
    """Return an explainable display-name decision for one place.

    Source facts are evidence only.  A source snapshot for another place is a
    hard failure so that a resumed run cannot accidentally cross-wire names.
    """

    if sources.place_id != record.place_id:
        raise ValueError("source snapshot place_id does not match baseline")

    baseline_vi = _clean(record.name or record.vi.name or "")
    if not baseline_vi:
        # A missing Vietnamese name cannot be repaired safely by translation.
        return NameDecision(
            place_id=record.place_id,
            vietnamese_name="",
            english_name="",
            rule="missing_vietnamese_name",
            source="baseline",
            confidence=0.0,
            warnings=("missing Vietnamese source name",),
        )

    warnings: list[str] = []
    rejected: list[str] = []
    vietnamese_name = baseline_vi

    # name:vi is authoritative only when it identifies the same source name.
    for fact in _facts(sources.facts, "osm.name_vi"):
        candidate = _clean(fact.value)
        if _same_identity(candidate, baseline_vi):
            vietnamese_name = candidate
            break
        warnings.append("name:vi identity mismatch")

    external = _verified_external_name_candidates(sources.facts, baseline_vi, rejected)
    if external:
        candidate, source, rule = external[0]
        return NameDecision(
            place_id=record.place_id,
            vietnamese_name=vietnamese_name,
            english_name=candidate,
            rule=rule,
            source=source,
            confidence=0.93,
            warnings=tuple(warnings),
            rejected_alternatives=tuple(rejected),
        )

    generic = _generic_name(vietnamese_name, record)
    if generic is not None:
        english_name, rule = generic
        return NameDecision(
            place_id=record.place_id,
            vietnamese_name=vietnamese_name,
            english_name=english_name,
            rule=rule,
            source="deterministic_generic_type",
            confidence=0.96 if not warnings else 0.82,
            warnings=tuple(warnings),
            rejected_alternatives=tuple(rejected),
        )

    # No known generic type: retaining the proper name is safer than guessing.
    return NameDecision(
        place_id=record.place_id,
        vietnamese_name=vietnamese_name,
        english_name=vietnamese_name,
        rule="protected_proper_name",
        source="baseline",
        confidence=0.90 if not warnings else 0.82,
        warnings=tuple(warnings),
        rejected_alternatives=tuple(rejected),
    )


def _verified_external_name_candidates(
    facts: Iterable[SourceFact], baseline_vi: str, rejected: list[str]
) -> list[tuple[str, str, str]]:
    candidates: list[tuple[str, str, str]] = []
    # Official metadata is opt-in and its URL has already passed SSRF checks.
    for fact in facts:
        if fact.fact_id not in {"official.name", "osm.name_en", "wikidata.label_en"}:
            continue
        candidate = _clean(fact.value)
        if not candidate:
            continue
        if _is_suspicious(candidate):
            rejected.append(candidate)
            continue
        if fact.fact_id == "official.name":
            candidates.append((candidate, fact.source_kind or "official_site", "verified_external_name"))
            continue
        if _candidate_identity_safe(baseline_vi, candidate):
            candidates.append((candidate, fact.fact_id, "identity_safe_external_name"))
        else:
            rejected.append(candidate)
    # Prefer a verified official institution name over OSM/Wikidata labels.
    candidates.sort(key=lambda item: 0 if item[1] in {"official_site", "official"} else 1)
    return candidates


def _generic_name(name: str, record: BaselineRecord) -> tuple[str, str] | None:
    for vietnamese_type, english_type in GENERIC_PREFIXES:
        remainder = _remove_prefix(name, vietnamese_type)
        if remainder is None:
            continue
        if vietnamese_type in {"Sông", "Hồ", "Núi", "Bãi", "Công Viên"} and _brand_context(record):
            # A restaurant or product called ``Sông Tiền`` is a brand, not a
            # geographic feature.  Other generic types remain translatable.
            return None
        if not remainder:
            return None
        return f"{remainder} {english_type}", f"generic_prefix:{vietnamese_type.casefold()}"
    return None


def _brand_context(record: BaselineRecord) -> bool:
    values = (record.subcategory_category, record.subcategory_name, record.source)
    text = " ".join(value or "" for value in values)
    if _BRAND_CONTEXT.search(text):
        return True
    # An explicit natural/river classification overrides a vague source name.
    return bool(_BRAND_CONTEXT.search(text) and not _NATURE_CONTEXT.search(text))


def _candidate_identity_safe(vietnamese_name: str, candidate: str) -> bool:
    if _same_identity(vietnamese_name, candidate):
        return True
    vn_core = _core_tokens(vietnamese_name)
    en_core = _english_core_tokens(candidate)
    if not vn_core or not en_core:
        return False
    # Require every protected Vietnamese token (after generic prefix removal)
    # to survive in the candidate, allowing diacritic-free English spellings.
    return vn_core.issubset(en_core) or bool(vn_core & en_core and len(vn_core) == 1)


def _core_tokens(name: str) -> set[str]:
    for vietnamese_type, _ in GENERIC_PREFIXES:
        remainder = _remove_prefix(name, vietnamese_type)
        if remainder is not None:
            return {_fold_token(token) for token in _tokens(remainder) if token}
    return {_fold_token(token) for token in _tokens(name) if token}


def _english_core_tokens(name: str) -> set[str]:
    tokens = list(_tokens(name))
    suffixes = {
        "river",
        "pagoda",
        "market",
        "mountain",
        "church",
        "museum",
        "airport",
        "station",
        "beach",
        "park",
        "temple",
        "bridge",
        "lake",
    }
    if tokens and _fold(tokens[-1]) in suffixes:
        tokens.pop()
        if tokens and _fold(tokens[-1]) == "parish":
            tokens.pop()
    return {_fold_token(token) for token in tokens if token}


def _remove_prefix(value: str, prefix: str) -> str | None:
    if not _fold(value).startswith(_fold(prefix)):
        return None
    remainder = value[len(prefix) :]
    if remainder and not (remainder[0].isspace() or remainder[0] in "-–—:"):
        return None
    return remainder.strip(" \t-–—:")


def _facts(facts: Iterable[SourceFact], fact_id: str) -> tuple[SourceFact, ...]:
    return tuple(fact for fact in facts if fact.fact_id == fact_id)


def _is_suspicious(value: str) -> bool:
    folded = " ".join(value.casefold().split())
    return folded in _SUSPICIOUS_TRANSLATIONS or "perfume river" in folded


def _same_identity(left: str, right: str) -> bool:
    return _fold(" ".join(_tokens(left))) == _fold(" ".join(_tokens(right)))


def _clean(value: str) -> str:
    return " ".join(str(value).strip().split())


def _tokens(value: str) -> tuple[str, ...]:
    return tuple(re.findall(r"[\wÀ-ỹ]+(?:['’/-][\wÀ-ỹ]+)*", value, flags=re.UNICODE))


def _fold(value: str) -> str:
    return " ".join(unicodedata.normalize("NFC", value).casefold().split())


def _fold_token(value: str) -> str:
    # Keep letters and digits, but compare accents-insensitively for an
    # English source such as ``Huong River`` against ``Hương``.
    normalized = unicodedata.normalize("NFKD", value)
    return "".join(char for char in normalized if not unicodedata.combining(char)).casefold()


__all__ = ["GENERIC_PREFIXES", "normalize_names"]
