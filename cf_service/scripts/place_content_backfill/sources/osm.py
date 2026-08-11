"""Small, allowlisted OpenStreetMap/Overpass adapter."""

from __future__ import annotations

import re
from typing import Any, Iterable, Sequence

import httpx

from ..models import SourceFact
from .http import request_with_retry


# Public Overpass instances are used in a fixed order.  Keeping this list
# allowlisted avoids turning the source adapter into an arbitrary URL proxy,
# while still allowing a transient outage on the primary instance to recover.
OVERPASS_URLS = (
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
)
# Backwards-compatible alias for callers that only need the primary endpoint.
OVERPASS_URL = OVERPASS_URLS[0]
_OVERPASS_RETRYABLE_STATUS_CODES = {429, 500, 502, 503, 504}
ALLOWED_TAGS = (
    "name",
    "name:vi",
    "name:en",
    "official_name",
    "alt_name",
    "wikidata",
    "wikipedia",
    "description",
    "description:vi",
    "description:en",
    "tourism",
    "amenity",
    "historic",
    "natural",
    "leisure",
    "shop",
    "cuisine",
    "brand",
    "operator",
    "website",
    "contact:website",
    "opening_hours",
)
_OSM_ID = re.compile(r"^osm:(node|way|relation):([1-9][0-9]*)$")


def parse_osm_id(value: str) -> tuple[str, int]:
    match = _OSM_ID.fullmatch(str(value).strip())
    if not match:
        raise ValueError(f"invalid OSM identity: {value}")
    return match.group(1), int(match.group(2))


def build_overpass_query(osm_ids: Sequence[str]) -> str:
    if len(osm_ids) > 100:
        raise ValueError("an Overpass request may contain at most 100 IDs")
    selectors: list[str] = []
    for raw in osm_ids:
        kind, osm_id = parse_osm_id(raw)
        selectors.append(f"{kind}({osm_id});")
    return "[out:json][timeout:30];(" + "".join(selectors) + ");out tags;"


async def collect_osm_facts(
    client: httpx.AsyncClient,
    osm_ids: Sequence[str],
) -> list[SourceFact]:
    facts: list[SourceFact] = []
    for batch in _chunks(tuple(osm_ids), 100):
        query = build_overpass_query(batch)
        last_error: Exception | None = None
        for endpoint in OVERPASS_URLS:
            try:
                response = await request_with_retry(
                    client,
                    "POST",
                    endpoint,
                    data={"data": query},
                    timeout=30,
                    headers={"User-Agent": "hello-vietnam-place-content/1.0"},
                )
                response.raise_for_status()
                facts.extend(extract_osm_facts(response.json()))
                break
            except httpx.HTTPStatusError as exc:
                if exc.response.status_code not in _OVERPASS_RETRYABLE_STATUS_CODES:
                    raise
                last_error = exc
            except httpx.TransportError as exc:
                last_error = exc
        else:
            if last_error is not None:
                raise last_error
            raise RuntimeError("no Overpass endpoints configured")
    return facts


def extract_osm_facts(payload: dict[str, Any]) -> list[SourceFact]:
    facts: list[SourceFact] = []
    for element in payload.get("elements", []):
        kind = str(element.get("type", ""))
        osm_id = element.get("id")
        if kind not in {"node", "way", "relation"} or not isinstance(osm_id, int):
            continue
        source_url = f"https://www.openstreetmap.org/{kind}/{osm_id}"
        tags = element.get("tags") or {}
        for tag in ALLOWED_TAGS:
            value = tags.get(tag)
            if value is None or not str(value).strip():
                continue
            fact_id = "osm." + tag.replace(":", "_")
            facts.append(
                SourceFact(
                    fact_id=fact_id,
                    value=str(value).strip(),
                    source_url=source_url,
                    source_kind="osm",
                )
            )
    return facts


def _chunks(values: Sequence[str], size: int) -> Iterable[tuple[str, ...]]:
    for start in range(0, len(values), size):
        yield tuple(values[start : start + size])
