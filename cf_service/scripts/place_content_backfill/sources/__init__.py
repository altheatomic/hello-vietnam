"""Grounded source adapters used by the place content pipeline."""

from __future__ import annotations

import re
from typing import Any, Iterable, Sequence

import httpx

from ..models import BaselineRecord, SourceFact, SourceSnapshot
from .osm import collect_osm_facts, parse_osm_id
from .website import extract_official_metadata
from .wikimedia import fetch_wikimedia_facts


_OSM_SOURCE_URL = re.compile(
    r"^https://www\.openstreetmap\.org/(node|way|relation)/([1-9][0-9]*)$"
)


async def collect_source_snapshot(
    record: BaselineRecord,
    client: httpx.AsyncClient,
    *,
    include_official_sites: bool = False,
    include_external_sources: bool = True,
) -> SourceSnapshot:
    """Collect corroborating facts without allowing source pages to write data."""

    return await _collect_snapshot(
        record,
        client,
        include_official_sites=include_official_sites,
        include_external_sources=include_external_sources,
    )


async def collect_source_snapshots(
    records: Sequence[BaselineRecord],
    client: httpx.AsyncClient,
    *,
    include_official_sites: bool = False,
    include_external_sources: bool = True,
    osm_batch_size: int = 100,
) -> list[SourceSnapshot]:
    """Collect snapshots while batching OSM identities into bounded requests."""

    if osm_batch_size < 1 or osm_batch_size > 100:
        raise ValueError("osm_batch_size must be between 1 and 100")

    record_identities: dict[str, str] = {}
    identities: list[str] = []
    if include_external_sources:
        seen: set[str] = set()
        for record in records:
            identity = record.source_place_id or record.freshness_source_external_id
            if not identity:
                continue
            try:
                parse_osm_id(identity)
            except ValueError:
                continue
            record_identities[record.place_id] = identity
            if identity not in seen:
                seen.add(identity)
                identities.append(identity)

    facts_by_identity: dict[str, list[SourceFact]] = {identity: [] for identity in identities}
    errors_by_identity: dict[str, str] = {}
    osm_failure: str | None = None
    if include_external_sources:
        for batch in _chunks(tuple(identities), osm_batch_size):
            if osm_failure is not None:
                errors_by_identity.update({identity: osm_failure for identity in batch})
                continue
            try:
                facts = await collect_osm_facts(client, batch)
            except (ValueError, httpx.HTTPError) as exc:
                message = f"osm source unavailable: {type(exc).__name__}"
                errors_by_identity.update({identity: message for identity in batch})
                # A complete batch failure proves the endpoint set is unavailable
                # for this run.  Do not multiply a long network timeout by every
                # remaining batch; snapshots will use the baseline fallback.
                osm_failure = message
                continue
            for fact in facts:
                identity = _identity_from_source_url(fact.source_url)
                if identity in facts_by_identity:
                    facts_by_identity[identity].append(fact)

    snapshots: list[SourceSnapshot] = []
    for record in records:
        identity = record_identities.get(record.place_id)
        snapshots.append(
            await _collect_snapshot(
                record,
                client,
                include_official_sites=include_official_sites,
                include_external_sources=include_external_sources,
                osm_facts=facts_by_identity.get(identity) if identity else None,
                osm_error=errors_by_identity.get(identity) if identity else None,
            )
        )
    return snapshots


async def _collect_snapshot(
    record: BaselineRecord,
    client: httpx.AsyncClient,
    *,
    include_official_sites: bool,
    include_external_sources: bool = True,
    osm_facts: list[SourceFact] | None = None,
    osm_error: str | None = None,
) -> SourceSnapshot:
    """Collect one snapshot, optionally using facts from a shared OSM batch."""

    facts: list[SourceFact] = list(osm_facts or [])
    warnings: list[str] = []
    if include_external_sources:
        osm_identity: str | None = None
        if osm_error:
            warnings.append(osm_error)
        elif osm_facts is None:
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

    # The existing database copy is an explicitly labelled fallback when
    # external sources are unavailable.  It gives the generator a bounded,
    # reviewable seed (especially the short description) without pretending
    # that it is a freshly verified external fact.
    baseline_facts = _baseline_facts(record)
    if baseline_facts:
        if not include_external_sources:
            warnings.append("external sources disabled; using baseline fields")
        elif not facts:
            warnings.append("external sources unavailable; using baseline fields")
        facts.extend(baseline_facts)

    return SourceSnapshot(
        place_id=record.place_id,
        facts=tuple(_deduplicate_facts(facts)),
        warnings=tuple(warnings),
    )


def _identity_from_source_url(source_url: str) -> str | None:
    match = _OSM_SOURCE_URL.fullmatch(source_url)
    if not match:
        return None
    return f"osm:{match.group(1)}:{match.group(2)}"


def _chunks(values: Sequence[str], size: int) -> Iterable[tuple[str, ...]]:
    for start in range(0, len(values), size):
        yield tuple(values[start : start + size])


def _deduplicate_facts(facts: list[SourceFact]) -> list[SourceFact]:
    seen: set[tuple[str, str, str]] = set()
    result: list[SourceFact] = []
    for fact in facts:
        key = (fact.fact_id, fact.value, fact.source_url)
        if key not in seen:
            seen.add(key)
            result.append(fact)
    return result


def _baseline_facts(record: BaselineRecord) -> list[SourceFact]:
    source_url = f"supabase://place/{record.place_id}"
    values = (
        ("baseline.short_description", record.short_description),
        ("baseline.description_vi", record.vi.description),
        ("baseline.description_en", record.en.description),
        ("baseline.address", record.address),
        (
            "baseline.category",
            " / ".join(
                value
                for value in (record.subcategory_category, record.subcategory_name)
                if value
            )
            or None,
        ),
    )
    return [
        SourceFact(
            fact_id=fact_id,
            value=str(value).strip(),
            source_url=source_url,
            source_kind="baseline",
        )
        for fact_id, value in values
        if value is not None and str(value).strip()
    ]


__all__ = ["collect_source_snapshot", "collect_source_snapshots"]
