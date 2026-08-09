from __future__ import annotations

import json
import math
import re
from typing import Any, Iterable
from urllib.parse import quote

import httpx

from ..models import BaselineRecord, SourceFact
from . import fetch_bytes


MAX_WIKIMEDIA_RESPONSE_BYTES = 2 * 1024 * 1024
_QID_RE = re.compile(r"^Q[0-9]+$")
_PAGE_LINK_RE = re.compile(r"^([a-z]{2,3}):(.+)$", re.IGNORECASE)


def parse_wikimedia_link(value: str) -> tuple[str, str] | None:
    text = value.strip()
    if _QID_RE.fullmatch(text):
        return "wikidata", text
    match = _PAGE_LINK_RE.fullmatch(text)
    if match and match.group(2).strip() and "://" not in text:
        return "wikipedia", f"{match.group(1).lower()}:{match.group(2)}"
    return None


def _expected_type(record: BaselineRecord) -> str | None:
    category = " ".join(
        value for value in (record.subcategory_name, record.subcategory_category) if value
    ).lower()
    mapping = {
        "chùa": "pagoda",
        "pagoda": "pagoda",
        "sân bay": "airport",
        "airport": "airport",
        "bảo tàng": "museum",
        "museum": "museum",
        "chợ": "market",
        "market": "market",
    }
    for marker, expected in mapping.items():
        if marker in category:
            return expected
    return None


def validate_wikimedia_evidence(
    record: BaselineRecord,
    evidence: dict[str, Any],
    *,
    coordinate_tolerance_degrees: float = 0.5,
) -> tuple[bool, list[str]]:
    warnings: list[str] = []
    evidence_province = evidence.get("province_id")
    if evidence_province and str(evidence_province) != record.province_id:
        warnings.append("wikimedia-province-conflict")
    expected_type = _expected_type(record)
    actual_type = str(evidence.get("type") or "").lower()
    if expected_type and actual_type and expected_type not in actual_type:
        warnings.append("wikimedia-type-conflict")
    try:
        latitude = float(evidence["latitude"])
        longitude = float(evidence["longitude"])
        if record.latitude is not None and record.longitude is not None:
            if math.hypot(latitude - record.latitude, longitude - record.longitude) > coordinate_tolerance_degrees:
                warnings.append("wikimedia-coordinate-conflict")
    except (KeyError, TypeError, ValueError):
        pass
    return not warnings, warnings


def _request_url(link_kind: str, identifier: str) -> str:
    if link_kind == "wikidata":
        return f"https://www.wikidata.org/wiki/Special:EntityData/{identifier}.json"
    language, page_title = identifier.split(":", 1)
    return f"https://{language}.wikipedia.org/api/rest_v1/page/summary/{quote(page_title, safe='')}"


async def collect_wikimedia_facts(
    record: BaselineRecord,
    *,
    links: Iterable[str],
    client: httpx.AsyncClient,
) -> tuple[list[SourceFact], list[str]]:
    facts: list[SourceFact] = []
    warnings: list[str] = []
    for link in links:
        parsed = parse_wikimedia_link(link)
        if parsed is None:
            warnings.append(f"wikimedia-link-not-explicit:{record.place_id}")
            continue
        link_kind, identifier = parsed
        url = _request_url(link_kind, identifier)
        result = await fetch_bytes(client, "GET", url, max_bytes=MAX_WIKIMEDIA_RESPONSE_BYTES)
        payload = json.loads(result.body.decode("utf-8"))
        if link_kind == "wikidata" and "entities" in payload:
            payload = payload.get("entities", {}).get(identifier, {})
        accepted, evidence_warnings = validate_wikimedia_evidence(record, payload)
        if not accepted:
            warnings.extend(f"{warning}:{record.place_id}" for warning in evidence_warnings)
            continue
        extract = str(payload.get("extract") or payload.get("description") or "").strip()
        if not extract:
            warnings.append(f"wikimedia-empty-extract:{record.place_id}")
            continue
        facts.append(
            SourceFact(
                fact_id=f"wikimedia:{identifier}:extract",
                source_type="wikimedia",
                source_url=url,
                claim=extract,
                confidence=0.85,
                value=extract,
            )
        )
    return facts, warnings
