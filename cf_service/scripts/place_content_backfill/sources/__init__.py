"""Grounded source adapters used by the place content pipeline."""

from __future__ import annotations

from typing import Any

import httpx

from ..models import BaselineRecord, SourceFact, SourceSnapshot
from .osm import collect_osm_facts, parse_osm_id
from .website import extract_official_metadata
from .wikimedia import fetch_wikimedia_facts


async def collect_source_snapshot(
    record: BaselineRecord,
    client: httpx.AsyncClient,
    *,
    include_official_sites: bool = False,
) -> SourceSnapshot:
    """Collect corroborating facts without allowing source pages to write data."""

    facts: list[SourceFact] = []
    warnings: list[str] = []
    osm_identity = record.source_place_id or record.freshness_source_external_id
    if osm_identity:
        try:
            parse_osm_id(osm_identity)
            facts.extend(await collect_osm_facts(client, [osm_identity]))
        except (ValueError, httpx.HTTPError) as exc:
            warnings.append(f"osm source unavailable: {type(exc).__name__}")

    try:
        facts.extend(
            await fetch_wikimedia_facts(
                client,
                record,
            )
        )
    except (ValueError, httpx.HTTPError) as exc:
        warnings.append(f"wikimedia source unavailable: {type(exc).__name__}")

    if include_official_sites:
        official_url = record.website or record.freshness_source_url
        if official_url:
            try:
                metadata = await extract_official_metadata(official_url, client)
                if metadata.title:
                    facts.append(
                        SourceFact(
                            fact_id="official.title",
                            value=metadata.title,
                            source_url=metadata.final_url,
                            source_kind="official_site",
                        )
                    )
                if metadata.description:
                    facts.append(
                        SourceFact(
                            fact_id="official.meta_description",
                            value=metadata.description,
                            source_url=metadata.final_url,
                            source_kind="official_site",
                        )
                    )
                if metadata.name:
                    facts.append(
                        SourceFact(
                            fact_id="official.name",
                            value=metadata.name,
                            source_url=metadata.final_url,
                            source_kind="official_site",
                        )
                    )
                if metadata.address:
                    facts.append(
                        SourceFact(
                            fact_id="official.address",
                            value=metadata.address,
                            source_url=metadata.final_url,
                            source_kind="official_site",
                        )
                    )
            except (ValueError, httpx.HTTPError) as exc:
                warnings.append(f"official source unavailable: {type(exc).__name__}")

    return SourceSnapshot(
        place_id=record.place_id,
        facts=tuple(_deduplicate_facts(facts)),
        warnings=tuple(warnings),
    )


def _deduplicate_facts(facts: list[SourceFact]) -> list[SourceFact]:
    seen: set[tuple[str, str, str]] = set()
    result: list[SourceFact] = []
    for fact in facts:
        key = (fact.fact_id, fact.value, fact.source_url)
        if key not in seen:
            seen.add(key)
            result.append(fact)
    return result


__all__ = ["collect_source_snapshot"]
