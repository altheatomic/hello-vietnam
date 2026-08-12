from __future__ import annotations

import re
from typing import Any, Iterable, Mapping

from .models import BaselineRecord, NameDecision, SourceFact, SourceSnapshot


# The order is deliberate: the longest approved generic prefix must be
# selected before a shorter prefix can consume the same name.
GENERIC_TYPE_MAPPINGS: tuple[tuple[str, str, str], ...] = (
    ("Nhà Thờ Giáo Xứ", "Parish Church", "parish-church"),
    ("Nhà Thờ Họ Đạo", "Parish Church", "parish-church"),
    ("Nhà Thờ", "Church", "church"),
    ("Bảo Tàng", "Museum", "museum"),
    ("Sân Bay", "Airport", "airport"),
    ("Nhà Ga", "Station", "station"),
    ("Bến Xe", "Bus Station", "bus-station"),
    ("Công Viên", "Park", "park"),
    ("Vịnh", "Bay", "bay"),
    ("Đảo", "Island", "island"),
    ("Hang", "Cave", "cave"),
    ("Thác", "Waterfall", "waterfall"),
    ("Chùa", "Pagoda", "pagoda"),
    ("Đền", "Temple", "temple"),
    ("Chợ", "Market", "market"),
    ("Cầu", "Bridge", "bridge"),
    ("Sông", "River", "river"),
    ("Hồ", "Lake", "lake"),
    ("Núi", "Mountain", "mountain"),
    ("Bãi", "Beach", "beach"),
)

UNKNOWN_GENERIC_PREFIXES: tuple[str, ...] = (
    "Khu Du Lịch",
    "Khu Di Tích",
    "Khu Bảo Tồn",
    "Làng",
    "Nhà Hàng",
    "Quán",
    "Cửa Hàng",
    "Trung Tâm",
    "Thánh Đường",
    "Lăng",
)

BRAND_MARKERS = (
    "restaurant",
    "food",
    "cafe",
    "brand",
    "shop",
    "nhà hàng",
    "quán",
    "ẩm thực",
)


def _prefix_match(name: str, prefix: str) -> re.Match[str] | None:
    return re.match(
        rf"^\s*{re.escape(prefix)}(?=\s|$)",
        name,
        flags=re.IGNORECASE,
    )


def _facts(sources: SourceSnapshot | Iterable[SourceFact | Mapping[str, Any]] | None) -> tuple[Any, ...]:
    if sources is None:
        return ()
    if isinstance(sources, SourceSnapshot):
        return sources.facts
    if isinstance(sources, Mapping):
        values = sources.get("facts", ())
        return tuple(values)
    return tuple(sources)


def _fact_value(fact: Any, key: str) -> Any:
    if isinstance(fact, Mapping):
        return fact.get(key)
    return getattr(fact, key, None)


def _protected_tokens(name: str, match_end: int) -> tuple[str, ...]:
    remainder = name[match_end:].strip()
    return tuple(re.findall(r"[\wÀ-ỹ]+", remainder, flags=re.UNICODE))


def _has_geographic_proof(facts: Iterable[Any], generic_kind: str) -> bool:
    markers = {
        "river": ("water", "river", "waterway", "stream"),
        "mountain": ("peak", "mountain", "natural=", "summit"),
        "lake": ("lake", "water", "natural=water"),
        "beach": ("beach", "coast", "shore"),
    }.get(generic_kind, (generic_kind,))
    for fact in facts:
        source_type = str(_fact_value(fact, "source_type") or "").lower()
        if source_type not in {"osm", "wikimedia"}:
            continue
        haystack = " ".join(
            str(_fact_value(fact, key) or "")
            for key in ("claim", "value")
        ).lower()
        if any(marker in haystack for marker in markers):
            return True
    return False


def _is_brand_like(record: BaselineRecord) -> bool:
    category = " ".join(
        value for value in (record.subcategory_name, record.subcategory_category) if value
    ).lower()
    return any(marker in category for marker in BRAND_MARKERS)


def _decision(
    record: BaselineRecord,
    en_name: str,
    *,
    confidence: float,
    rule_id: str,
    warnings: Iterable[str] = (),
    protected_tokens: Iterable[str] = (),
) -> NameDecision:
    warning_tuple = tuple(dict.fromkeys(warnings))
    tokens = tuple(protected_tokens)
    lowered = en_name.casefold()
    missing = [token for token in tokens if token.casefold() not in lowered]
    if missing:
        warning_tuple = tuple(
            dict.fromkeys((*warning_tuple, "protected-token-loss:" + ",".join(missing)))
        )
    review_only = confidence < 0.85 or bool(warning_tuple)
    return NameDecision(
        place_id=record.place_id,
        vi_name=record.vi_name,
        en_name=en_name,
        confidence=confidence,
        rule_id=rule_id,
        review_only=review_only,
        warnings=warning_tuple,
        protected_tokens=tokens,
    )


def normalize_names(
    record: BaselineRecord,
    sources: SourceSnapshot | Iterable[SourceFact | Mapping[str, Any]] | None,
) -> NameDecision:
    """Normalize a display name without asking a model to select names."""

    facts = _facts(sources)
    for prefix, suffix, rule_id in GENERIC_TYPE_MAPPINGS:
        match = _prefix_match(record.vi_name, prefix)
        if match is None:
            continue
        protected = _protected_tokens(record.vi_name, match.end())
        warnings: list[str] = []
        if _is_brand_like(record) and not _has_geographic_proof(facts, rule_id):
            return _decision(
                record,
                record.vi_name,
                confidence=0.70,
                rule_id="preserve-brand",
                warnings=("brand-like-generic-prefix",),
                protected_tokens=protected,
            )
        remainder = record.vi_name[match.end():].strip()
        english_name = f"{remainder} {suffix}".strip() if remainder else suffix
        for fact in facts:
            source_type = str(_fact_value(fact, "source_type") or "").lower()
            if source_type in {"official_site", "website"}:
                warnings.append("ambiguous-official-name-override")
        return _decision(
            record,
            english_name,
            confidence=0.98,
            rule_id=f"generic:{rule_id}",
            warnings=warnings,
            protected_tokens=protected,
        )

    for prefix in UNKNOWN_GENERIC_PREFIXES:
        match = _prefix_match(record.vi_name, prefix)
        if match is not None:
            return _decision(
                record,
                record.vi_name,
                confidence=0.60,
                rule_id="unknown-generic-prefix",
                warnings=(f"unknown-generic-prefix:{prefix}",),
                protected_tokens=_protected_tokens(record.vi_name, match.end()),
            )

    return _decision(
        record,
        record.vi_name,
        confidence=0.95,
        rule_id="preserve-proper-name",
    )


__all__ = ["GENERIC_TYPE_MAPPINGS", "normalize_names"]
