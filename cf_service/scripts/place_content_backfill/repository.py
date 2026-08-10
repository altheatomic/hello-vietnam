"""Supabase reads, baseline hashing, and guarded write primitives."""

from __future__ import annotations

import hashlib
import json
import secrets
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

from .constants import (
    APPROVED_PROVINCES,
    EXPECTED_TOTAL,
    PROVINCE_EXPECTED_COUNTS,
)
from .artifacts import ArtifactStore
from .models import (
    BaselineRecord,
    RunManifest,
    TranslationBaseline,
)


PLACE_SELECT = (
    "id_place,id_province,id_place_subcategory,status,name,short_description,"
    "detailed_description,address,latitude,longitude,source,source_place_id,"
    "wikidata,wikipedia,official_name,website,created_at,updated_at"
)
TRANSLATION_SELECT = (
    "id,place_id,lang_code,name,description,detailed_description,created_at,updated_at"
)
SUBCATEGORY_SELECT = "id_place_subcategory,name,place_category"
FRESHNESS_SELECT = (
    "content_id,source_type,source_url,source_external_id,availability_type,"
    "valid_from,valid_until,freshness_status,last_checked_at,last_verified_at,"
    "next_check_at,source_hash"
)
TAG_SELECT = "id_place,id_tag"


def _fetch_pages(
    supabase: Any,
    table: str,
    select: str,
    *,
    page_size: int,
    in_filters: Sequence[tuple[str, Sequence[str]]] = (),
    eq_filters: Sequence[tuple[str, Any]] = (),
) -> list[dict[str, Any]]:
    """Read every page while keeping scope predicates on every request."""

    rows: list[dict[str, Any]] = []
    start = 0
    while True:
        query = supabase.table(table).select(select)
        for field, values in in_filters:
            query = query.in_(field, list(values))
        for field, value in eq_filters:
            query = query.eq(field, value)
        response = query.range(start, start + page_size - 1).execute()
        page = list(response.data or [])
        rows.extend(page)
        if len(page) < page_size:
            return rows
        start += page_size


def fetch_baseline(
    supabase: Any,
    *,
    province_ids: Sequence[str] = APPROVED_PROVINCES,
    place_ids: Sequence[str] | None = None,
    page_size: int = 500,
    relation_batch_size: int = 500,
) -> list[BaselineRecord]:
    """Snapshot exactly the scoped places and their editable dependencies."""

    province_ids = tuple(str(value) for value in province_ids)
    unknown = sorted(set(province_ids) - set(APPROVED_PROVINCES))
    if unknown:
        raise ValueError(f"province outside approved scope: {unknown}")
    selected_place_ids = tuple(str(value) for value in place_ids or ())
    place_filters: list[tuple[str, Sequence[str]]] = [("id_province", province_ids)]
    if selected_place_ids:
        place_filters.append(("id_place", selected_place_ids))
    place_rows = _fetch_pages(
        supabase,
        "place",
        PLACE_SELECT,
        page_size=page_size,
        in_filters=place_filters,
    )
    ids = [str(row.get("id_place")) for row in place_rows if row.get("id_place")]
    if len(ids) != len(set(ids)):
        raise ValueError("place query returned duplicate IDs")
    if not ids:
        return []

    translations: list[dict[str, Any]] = []
    subcategories: list[dict[str, Any]] = []
    freshness: list[dict[str, Any]] = []
    tags: list[dict[str, Any]] = []
    for batch in _chunks(ids, relation_batch_size):
        translations.extend(
            _fetch_pages(
                supabase,
                "place_translation",
                TRANSLATION_SELECT,
                page_size=page_size,
                in_filters=[("place_id", batch)],
            )
        )
        subcategory_ids = [
            str(row["id_place_subcategory"])
            for row in place_rows
            if row.get("id_place") in batch and row.get("id_place_subcategory")
        ]
        if subcategory_ids:
            subcategories.extend(
                _fetch_pages(
                    supabase,
                    "place_subcategory",
                    SUBCATEGORY_SELECT,
                    page_size=page_size,
                    in_filters=[("id_place_subcategory", tuple(set(subcategory_ids)))],
                )
            )
        tags.extend(
            _fetch_pages(
                supabase,
                "place_tag",
                TAG_SELECT,
                page_size=page_size,
                in_filters=[("id_place", batch)],
            )
        )
        freshness.extend(
            _fetch_pages(
                supabase,
                "content_freshness",
                FRESHNESS_SELECT,
                page_size=page_size,
                in_filters=[("content_id", batch)],
                eq_filters=[("content_type", "place")],
            )
        )

    translation_map: dict[tuple[str, str], TranslationBaseline] = {}
    for raw in translations:
        place_id = str(raw.get("place_id"))
        lang_code = str(raw.get("lang_code"))
        if lang_code not in {"vi", "en"} or place_id not in ids:
            continue
        key = (place_id, lang_code)
        if key in translation_map:
            raise ValueError(f"duplicate {lang_code} translation for {place_id}")
        translation_map[key] = TranslationBaseline(
            id=str(raw.get("id")),
            place_id=place_id,
            lang_code=lang_code,
            name=raw.get("name"),
            description=raw.get("description"),
            detailed_description=raw.get("detailed_description"),
            created_at=_string_or_none(raw.get("created_at")),
            updated_at=_string_or_none(raw.get("updated_at")),
        )

    subcategory_map = {
        str(raw.get("id_place_subcategory")): raw for raw in subcategories
    }
    tag_map: dict[str, list[str]] = defaultdict(list)
    for raw in tags:
        place_id = str(raw.get("id_place"))
        tag_value = raw.get("tag_code") or raw.get("id_tag")
        if tag_value:
            tag_map[place_id].append(str(tag_value))
    freshness_map = {
        str(raw.get("content_id")): raw for raw in freshness if raw.get("content_id")
    }

    result: list[BaselineRecord] = []
    for raw in place_rows:
        place_id = str(raw.get("id_place"))
        province_id = str(raw.get("id_province"))
        if (place_id, "vi") not in translation_map or (place_id, "en") not in translation_map:
            raise ValueError(f"place {place_id} must have both vi and en translations")
        subcategory = subcategory_map.get(str(raw.get("id_place_subcategory")), {})
        fresh = freshness_map.get(place_id, {})
        result.append(
            BaselineRecord(
                place_id=place_id,
                province_id=province_id,
                status=raw.get("status"),
                name=raw.get("name"),
                short_description=raw.get("short_description"),
                detailed_description=raw.get("detailed_description"),
                address=raw.get("address"),
                latitude=_float_or_none(raw.get("latitude")),
                longitude=_float_or_none(raw.get("longitude")),
                source=raw.get("source"),
                source_place_id=raw.get("source_place_id"),
                wikidata=raw.get("wikidata"),
                wikipedia=raw.get("wikipedia"),
                official_name=raw.get("official_name"),
                website=raw.get("website"),
                freshness_source_type=fresh.get("source_type"),
                freshness_source_url=fresh.get("source_url"),
                freshness_source_external_id=fresh.get("source_external_id"),
                availability_type=fresh.get("availability_type"),
                valid_from=_string_or_none(fresh.get("valid_from")),
                valid_until=_string_or_none(fresh.get("valid_until")),
                subcategory_id=_string_or_none(raw.get("id_place_subcategory")),
                subcategory_name=subcategory.get("name"),
                subcategory_category=subcategory.get("place_category"),
                tags=tuple(sorted(set(tag_map.get(place_id, [])))),
                created_at=_string_or_none(raw.get("created_at")),
                updated_at=_string_or_none(raw.get("updated_at")),
                vi=translation_map[(place_id, "vi")],
                en=translation_map[(place_id, "en")],
            )
        )
    return result


def verify_baseline_counts(
    records: Sequence[BaselineRecord],
    *,
    expected_counts: Mapping[str, int] = PROVINCE_EXPECTED_COUNTS,
) -> None:
    counts = Counter(record.province_id for record in records)
    unknown = sorted(set(counts) - set(expected_counts))
    if unknown:
        raise ValueError(f"baseline contains outside-scope provinces: {unknown}")
    expected_total = sum(expected_counts.values())
    if len(records) != expected_total:
        raise ValueError(f"expected {expected_total} places, received {len(records)}")
    mismatches = {
        province_id: (counts.get(province_id, 0), expected)
        for province_id, expected in expected_counts.items()
        if counts.get(province_id, 0) != expected
    }
    if mismatches:
        raise ValueError(f"province baseline counts mismatch: {mismatches}")
    if len({record.place_id for record in records}) != len(records):
        raise ValueError("baseline contains duplicate place IDs")


def editable_hash(record: BaselineRecord | Mapping[str, Any]) -> str:
    """Hash only fields that the backfill may edit, without text normalization."""

    data = record.model_dump(mode="json") if isinstance(record, BaselineRecord) else dict(record)

    def translation_payload(value: Mapping[str, Any] | None) -> dict[str, Any]:
        value = value or {}
        return {
            "name": value.get("name"),
            "description": value.get("description"),
            "detailed_description": value.get("detailed_description"),
            "created_at": value.get("created_at"),
            "updated_at": value.get("updated_at"),
        }

    payload = {
        "place": {
            "name": data.get("name"),
            "short_description": data.get("short_description"),
            "detailed_description": data.get("detailed_description"),
            "created_at": data.get("created_at"),
            "updated_at": data.get("updated_at"),
        },
        "vi": translation_payload(data.get("vi")),
        "en": translation_payload(data.get("en")),
    }
    encoded = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def baseline_hash(records: Iterable[BaselineRecord]) -> str:
    values = [
        {"place_id": record.place_id, "editable_hash": editable_hash(record)}
        for record in records
    ]
    encoded = json.dumps(sorted(values, key=lambda item: item["place_id"]), separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def create_manifest(records: Sequence[BaselineRecord], run_id: str | None = None) -> RunManifest:
    verify_baseline_counts(records)
    manifest = RunManifest.new(run_id=run_id or _new_run_id())
    return manifest.model_copy(update={"baseline_hash": baseline_hash(records)})


def audit_scope(
    supabase: Any,
    artifact_root: str,
    *,
    run_id: str | None = None,
    province_ids: Sequence[str] = APPROVED_PROVINCES,
) -> tuple[RunManifest, list[BaselineRecord]]:
    """Run the read-only audit and persist its immutable baseline snapshot."""

    records = fetch_baseline(supabase, province_ids=province_ids)
    verify_baseline_counts(records)
    manifest = create_manifest(records, run_id=run_id)
    manifest = manifest.model_copy(update={"status": "audited"})
    store = ArtifactStore(Path(artifact_root), manifest.run_id)
    store.write_manifest(manifest)
    for record in records:
        store.append("baseline", record)
    return manifest, records


def _chunks(values: Sequence[str], size: int) -> Iterable[tuple[str, ...]]:
    for start in range(0, len(values), size):
        yield tuple(values[start : start + size])


def _string_or_none(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.astimezone(timezone.utc).isoformat()
    return str(value)


def _float_or_none(value: Any) -> float | None:
    return None if value is None else float(value)


def _new_run_id() -> str:
    return f"{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')}-{secrets.token_hex(4)}"
