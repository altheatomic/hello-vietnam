"""Supabase reads, baseline hashing, and guarded write primitives."""

from __future__ import annotations

import hashlib
import json
import secrets
from collections import Counter, defaultdict
from datetime import datetime, timezone
from dataclasses import dataclass
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


@dataclass(frozen=True)
class ApplyResult:
    batch_id: str
    applied_place_ids: tuple[str, ...]
    rollback_entries: tuple[dict[str, Any], ...]


async def apply_approved_batch(
    conn: Any,
    proposals: Sequence[Any],
    baselines: Mapping[str, BaselineRecord] | Sequence[BaselineRecord],
    *,
    artifact_store: ArtifactStore | None = None,
    batch_id: str | None = None,
    confirm: bool = False,
) -> ApplyResult:
    """Apply at most 50 approved proposals in one serializable transaction.

    All validation and baseline checks happen before opening the transaction.
    The transaction then locks the place and both translation rows, compares
    the live editable hash, and asserts exactly one update per row.
    """

    proposals = tuple(proposals)
    baseline_map = _baseline_mapping(baselines)
    _preflight_apply(proposals, baseline_map, confirm=confirm)
    current_batch_id = batch_id or f"batch-{secrets.token_hex(8)}"
    rollback_entries: list[dict[str, Any]] = []

    async with conn.transaction():
        for proposal in proposals:
            baseline = baseline_map[proposal.place_id]
            place, translations = await _lock_live_rows(conn, proposal.place_id)
            live = _live_hash_payload(place, translations)
            if editable_hash(live) != editable_hash(baseline):
                raise ValueError(f"baseline hash conflict for {proposal.place_id}")
            prior = _prior_values(place, translations)
            proposed = _proposed_values(proposal, baseline)
            _assert_update_one(
                await conn.execute(
                    """
                    UPDATE public.place
                       SET name = $1,
                           short_description = $2,
                           detailed_description = $3,
                           updated_at = now()
                     WHERE id_place = $4
                    """,
                    proposed["place"]["name"],
                    proposed["place"]["short_description"],
                    proposed["place"]["detailed_description"],
                    proposal.place_id,
                ),
                "place",
            )
            for lang_code in ("vi", "en"):
                values = proposed[lang_code]
                _assert_update_one(
                    await conn.execute(
                        """
                        UPDATE public.place_translation
                           SET name = $1,
                               description = $2,
                               detailed_description = $3,
                               updated_at = now()
                         WHERE place_id = $4 AND lang_code = $5
                        """,
                        values["name"],
                        values["description"],
                        values["detailed_description"],
                        proposal.place_id,
                        lang_code,
                    ),
                    f"{lang_code} translation",
                )
            rollback_entries.append(
                {
                    "batch_id": current_batch_id,
                    "place_id": proposal.place_id,
                    "province_id": baseline.province_id,
                    "baseline_hash": proposal.baseline_hash,
                    "applied_value_hash": _value_hash(proposed),
                    "prior": prior,
                    "applied": proposed,
                }
            )

    # Finalize artifacts only after commit.  The rollback payload is written
    # first so an operator can recover even if the second append is interrupted.
    if artifact_store is not None:
        for entry in rollback_entries:
            artifact_store.append("rollback", entry)
        for entry in rollback_entries:
            artifact_store.append(
                "applied",
                {
                    "batch_id": entry["batch_id"],
                    "place_id": entry["place_id"],
                    "province_id": entry["province_id"],
                    "baseline_hash": entry["baseline_hash"],
                    "applied_value_hash": entry["applied_value_hash"],
                },
            )
    return ApplyResult(
        batch_id=current_batch_id,
        applied_place_ids=tuple(entry["place_id"] for entry in rollback_entries),
        rollback_entries=tuple(rollback_entries),
    )


async def rollback_applied_batch(
    conn: Any,
    rollback_entries: Sequence[Mapping[str, Any]],
    *,
    artifact_store: ArtifactStore | None = None,
    confirm: bool = False,
    place_ids: Sequence[str] | None = None,
    batch_id: str | None = None,
    province_id: str | None = None,
    all_entries: bool = False,
    manifest: RunManifest | None = None,
) -> tuple[str, ...]:
    """Restore a selected applied set only when no later admin edit exists."""

    if not confirm:
        raise ValueError("rollback requires confirm=True")
    entries = tuple(dict(entry) for entry in rollback_entries)
    selectors = bool(place_ids or batch_id or province_id or all_entries)
    if not selectors:
        raise ValueError("rollback requires a place, batch, province, or all selector")
    selected_ids = {str(value) for value in place_ids or ()}
    selected: list[dict[str, Any]] = []
    for entry in entries:
        entry_place = str(entry.get("place_id") or "")
        entry_province = str(entry.get("province_id") or "")
        if manifest is not None and entry_province not in manifest.province_ids:
            raise ValueError(f"rollback entry outside manifest scope: {entry_place}")
        if selected_ids and entry_place not in selected_ids:
            continue
        if batch_id and str(entry.get("batch_id")) != batch_id:
            continue
        if province_id and entry_province != province_id:
            continue
        if not all_entries and not (selected_ids or batch_id or province_id):
            continue
        selected.append(entry)
    if not selected:
        raise ValueError("rollback selector matched no entries")

    async with conn.transaction():
        for entry in selected:
            place_id = str(entry.get("place_id") or "")
            place, translations = await _lock_live_rows(conn, place_id)
            current = _live_hash_payload(place, translations)
            if _value_hash(current) != str(entry.get("applied_value_hash")):
                raise ValueError(f"rollback refused because {place_id} changed after apply")
            prior = entry.get("prior")
            if not isinstance(prior, Mapping):
                raise ValueError(f"rollback payload is missing prior values for {place_id}")
            _assert_update_one(
                await conn.execute(
                    """
                    UPDATE public.place
                       SET name = $1,
                           short_description = $2,
                           detailed_description = $3,
                           updated_at = now()
                     WHERE id_place = $4
                    """,
                    prior["place"]["name"],
                    prior["place"]["short_description"],
                    prior["place"]["detailed_description"],
                    place_id,
                ),
                "place rollback",
            )
            for lang_code in ("vi", "en"):
                values = prior[lang_code]
                _assert_update_one(
                    await conn.execute(
                        """
                        UPDATE public.place_translation
                           SET name = $1,
                               description = $2,
                               detailed_description = $3,
                               updated_at = now()
                         WHERE place_id = $4 AND lang_code = $5
                        """,
                        values["name"],
                        values["description"],
                        values["detailed_description"],
                        place_id,
                        lang_code,
                    ),
                    f"{lang_code} translation rollback",
                )
    if artifact_store is not None:
        for entry in selected:
            artifact_store.append(
                "rollback",
                {
                    "action": "restored",
                    "batch_id": entry.get("batch_id"),
                    "place_id": entry.get("place_id"),
                    "province_id": entry.get("province_id"),
                    "applied_value_hash": entry.get("applied_value_hash"),
                },
            )
    return tuple(str(entry["place_id"]) for entry in selected)


# Alias kept explicit for callers that use the shorter operation name.
rollback_applied = rollback_applied_batch


def _preflight_apply(
    proposals: Sequence[Any],
    baselines: Mapping[str, BaselineRecord],
    *,
    confirm: bool,
) -> None:
    if not confirm:
        raise ValueError("apply requires confirm=True")
    if not proposals:
        raise ValueError("apply requires at least one proposal")
    if len(proposals) > 50:
        raise ValueError("one apply transaction may contain at most 50 places")
    place_ids = [str(proposal.place_id) for proposal in proposals]
    if len(place_ids) != len(set(place_ids)):
        raise ValueError("apply contains duplicate place IDs")
    for proposal in proposals:
        if proposal.reviewer_decision != "approve" or proposal.validation is None or not proposal.validation.valid:
            raise ValueError(f"proposal {proposal.place_id} is not validator-approved")
        baseline = baselines.get(proposal.place_id)
        if baseline is None:
            raise ValueError(f"missing baseline for {proposal.place_id}")
        if baseline.province_id not in APPROVED_PROVINCES or proposal.province_id != baseline.province_id:
            raise ValueError(f"proposal {proposal.place_id} is outside approved province scope")
        if proposal.baseline_hash != editable_hash(baseline):
            raise ValueError(f"proposal {proposal.place_id} baseline hash does not match manifest")


def _baseline_mapping(
    baselines: Mapping[str, BaselineRecord] | Sequence[BaselineRecord],
) -> dict[str, BaselineRecord]:
    if isinstance(baselines, Mapping):
        return {str(key): value for key, value in baselines.items()}
    return {record.place_id: record for record in baselines}


async def _lock_live_rows(conn: Any, place_id: str) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    place = await conn.fetchrow(
        """
        SELECT id_place,id_province,name,short_description,detailed_description,created_at,updated_at
          FROM public.place
         WHERE id_place = $1
         FOR UPDATE
        """,
        place_id,
    )
    if not place:
        raise ValueError(f"place {place_id} was not found")
    translation_rows = await conn.fetch(
        """
        SELECT id,place_id,lang_code,name,description,detailed_description,created_at,updated_at
          FROM public.place_translation
         WHERE place_id = $1 AND lang_code IN ('vi','en')
         FOR UPDATE
        """,
        place_id,
    )
    translations: dict[str, dict[str, Any]] = {}
    for row in translation_rows or ():
        lang_code = str(row.get("lang_code"))
        if lang_code not in {"vi", "en"} or lang_code in translations:
            raise ValueError(f"place {place_id} must have exactly one vi and en translation")
        translations[lang_code] = dict(row)
    if set(translations) != {"vi", "en"}:
        raise ValueError(f"place {place_id} must have exactly one vi and en translation")
    return dict(place), translations


def _live_hash_payload(place: Mapping[str, Any], translations: Mapping[str, Mapping[str, Any]]) -> dict[str, Any]:
    return {
        "name": place.get("name"),
        "short_description": place.get("short_description"),
        "detailed_description": place.get("detailed_description"),
        "created_at": _string_or_none(place.get("created_at")),
        "updated_at": _string_or_none(place.get("updated_at")),
        "vi": dict(translations["vi"]),
        "en": dict(translations["en"]),
    }


def _prior_values(place: Mapping[str, Any], translations: Mapping[str, Mapping[str, Any]]) -> dict[str, dict[str, Any]]:
    return {
        "place": {
            "name": place.get("name"),
            "short_description": place.get("short_description"),
            "detailed_description": place.get("detailed_description"),
        },
        **{
            lang_code: {
                "name": translations[lang_code].get("name"),
                "description": translations[lang_code].get("description"),
                "detailed_description": translations[lang_code].get("detailed_description"),
            }
            for lang_code in ("vi", "en")
        },
    }


def _proposed_values(proposal: Any, baseline: BaselineRecord) -> dict[str, dict[str, Any]]:
    if proposal.content is None:
        raise ValueError(f"proposal {proposal.place_id} has no content")
    content = proposal.content
    return {
        "place": {
            "name": proposal.proposed_name_vi or baseline.vi.name or baseline.name,
            "short_description": content.short_description_vi,
            "detailed_description": content.detailed_description_vi,
        },
        "vi": {
            "name": proposal.proposed_name_vi or baseline.vi.name or baseline.name,
            "description": content.short_description_vi,
            "detailed_description": content.detailed_description_vi,
        },
        "en": {
            "name": proposal.proposed_name_en or baseline.en.name,
            "description": content.short_description_en,
            "detailed_description": content.detailed_description_en,
        },
    }


def _value_hash(values: Mapping[str, Any]) -> str:
    if "place" not in values:
        values = {
            "place": {
                "name": values.get("name"),
                "short_description": values.get("short_description"),
                "detailed_description": values.get("detailed_description"),
            },
            "vi": values["vi"],
            "en": values["en"],
        }
    place = values["place"]
    vi = values["vi"]
    en = values["en"]
    payload = {
        "place": {
            "name": place.get("name"),
            "short_description": place.get("short_description"),
            "detailed_description": place.get("detailed_description"),
        },
        "vi": {
            "name": vi.get("name"),
            "description": vi.get("description"),
            "detailed_description": vi.get("detailed_description"),
        },
        "en": {
            "name": en.get("name"),
            "description": en.get("description"),
            "detailed_description": en.get("detailed_description"),
        },
    }
    return hashlib.sha256(
        json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()


def _assert_update_one(result: Any, label: str) -> None:
    text = str(result)
    try:
        count = int(text.rsplit(" ", 1)[-1])
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{label} update returned an invalid result") from exc
    if count != 1:
        raise ValueError(f"{label} update affected {count} rows")


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
