from __future__ import annotations

import asyncio
from collections import defaultdict
import json
import re
from typing import Any, Iterable

import httpx

from ..models import BaselineRecord, SourceFact
from . import fetch_bytes


OSM_ENDPOINT = "https://overpass-api.de/api/interpreter"
MAX_OSM_RESPONSE_BYTES = 8 * 1024 * 1024
_OSM_ID_RE = re.compile(r"^osm:(node|way|relation):([0-9]+)$")


def parse_osm_identity(value: str) -> tuple[str, int]:
    match = _OSM_ID_RE.fullmatch(value.strip())
    if not match:
        raise ValueError("OSM identity must be osm:node|way|relation:<integer>")
    return match.group(1), int(match.group(2))


def build_osm_batches(
    identities: Iterable[str],
    *,
    max_ids: int = 100,
) -> list[tuple[str, tuple[int, ...]]]:
    if max_ids <= 0:
        raise ValueError("max_ids must be positive")
    grouped: dict[str, list[int]] = defaultdict(list)
    for identity in identities:
        kind, numeric_id = parse_osm_identity(identity)
        grouped[kind].append(numeric_id)
    batches: list[tuple[str, tuple[int, ...]]] = []
    for kind in ("node", "way", "relation"):
        ids = grouped.get(kind, [])
        for start in range(0, len(ids), max_ids):
            batches.append((kind, tuple(ids[start:start + max_ids])))
    return batches


def _overpass_query(kind: str, ids: tuple[int, ...]) -> str:
    joined = ",".join(str(value) for value in ids)
    return f"[out:json][timeout:25];{kind}(id:{joined});out tags center;"


def _fact_id(kind: str, numeric_id: int, tag_key: str) -> str:
    return f"osm:{kind}:{numeric_id}:{tag_key}"


async def _collect_batch(
    record: BaselineRecord,
    client: httpx.AsyncClient,
    kind: str,
    ids: tuple[int, ...],
    *,
    endpoint: str,
) -> tuple[list[SourceFact], list[str]]:
    query = _overpass_query(kind, ids)
    result = await fetch_bytes(
        client,
        "POST",
        endpoint,
        json_body={"data": query},
        max_bytes=MAX_OSM_RESPONSE_BYTES,
    )
    payload = json.loads(result.body.decode("utf-8"))
    facts: list[SourceFact] = []
    for element in payload.get("elements", []):
        element_kind = str(element.get("type") or kind)
        numeric_id = int(element.get("id"))
        tags = element.get("tags") or {}
        for tag_key, value in sorted(tags.items()):
            if value is None or not str(value).strip():
                continue
            facts.append(
                SourceFact(
                    fact_id=_fact_id(element_kind, numeric_id, str(tag_key)),
                    source_type="osm",
                    source_url=f"https://www.openstreetmap.org/{element_kind}/{numeric_id}",
                    claim=f"OSM {tag_key}: {value}",
                    confidence=0.95,
                    value=str(value),
                )
            )
    if not facts:
        return [], [f"osm-no-facts:{record.place_id}:{kind}"]
    return facts, []


async def collect_osm_facts(
    record: BaselineRecord,
    *,
    client: httpx.AsyncClient,
    source_ids: Iterable[str] | None = None,
    max_ids: int = 100,
    concurrency: int = 3,
    endpoint: str = OSM_ENDPOINT,
) -> tuple[list[SourceFact], list[str]]:
    identities = tuple(source_ids or ((record.source_place_id,) if record.source_place_id else ()))
    valid: list[str] = []
    warnings: list[str] = []
    for identity in identities:
        try:
            parse_osm_identity(identity)
        except (TypeError, ValueError):
            warnings.append(f"osm-invalid-identity:{record.place_id}")
            continue
        valid.append(identity)
    if not valid:
        return [], warnings or [f"osm-missing-identity:{record.place_id}"]
    if concurrency <= 0:
        raise ValueError("concurrency must be positive")
    batches = build_osm_batches(valid, max_ids=max_ids)
    semaphore = asyncio.Semaphore(concurrency)

    async def run(kind: str, ids: tuple[int, ...]):
        async with semaphore:
            return await _collect_batch(record, client, kind, ids, endpoint=endpoint)

    results = await asyncio.gather(*(run(kind, ids) for kind, ids in batches))
    facts: list[SourceFact] = []
    for batch_facts, batch_warnings in results:
        facts.extend(batch_facts)
        warnings.extend(batch_warnings)
    return facts, warnings
