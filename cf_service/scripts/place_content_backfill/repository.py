from __future__ import annotations

from collections import Counter, defaultdict
import hashlib
import json
from typing import Any, Iterable, Iterator, Mapping, Sequence

from .artifacts import ArtifactStore
from .constants import (
    APPROVED_PROVINCES,
    DEFAULT_PAGE_SIZE,
    DEFAULT_RELATED_BATCH_SIZE,
    EXPECTED_TOTAL,
    new_run_id,
)
from .models import BaselineRecord, RunManifest


class BaselineIntegrityError(ValueError):
    """Raised when the fixed baseline scope is incomplete or ambiguous."""


PLACE_FIELDS = (
    "id_place,id_province,id_place_subcategory,name,short_description,"
    "detailed_description,status,address,latitude,longitude,source,"
    "source_place_id,website,updated_at"
)
TRANSLATION_FIELDS = (
    "id,place_id,lang_code,name,description,detailed_description,updated_at"
)
FRESHNESS_FIELDS = (
    "id,content_id,content_type,source_type,source_url,source_external_id,"
    "valid_from,valid_until,last_checked_at,last_verified_at,source_hash,"
    "last_error,freshness_status,next_check_at,updated_at"
)
SUBCATEGORY_FIELDS = "id_place_subcategory,name,place_category,is_itinerary_eligible"
TAG_FIELDS = "id_place,id_tag,confidence"


def _as_mapping(record: BaselineRecord | Mapping[str, Any]) -> Mapping[str, Any]:
    if isinstance(record, BaselineRecord):
        return record.model_dump(mode="json")
    return record


def _first(record: Mapping[str, Any], *keys: str) -> Any:
    for key in keys:
        if key in record:
            return record[key]
    return None


def _canonical_hash(payload: Mapping[str, Any]) -> str:
    encoded = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _editable_content_payload(record: BaselineRecord | Mapping[str, Any]) -> dict[str, Any]:
    value = _as_mapping(record)
    return {
        "place_name": _first(value, "place_name", "vi_name", "name"),
        "place_short_description": _first(
            value, "place_short_description", "vi_short_description", "short_description"
        ),
        "place_detailed_description": _first(
            value, "place_detailed_description", "vi_detailed_description", "detailed_description"
        ),
        "vi_name": _first(value, "vi_name", "name"),
        "vi_description": _first(value, "vi_description", "vi_short_description", "description"),
        "vi_detailed_description": _first(value, "vi_detailed_description"),
        "en_name": _first(value, "en_name"),
        "en_description": _first(value, "en_short_description", "en_description"),
        "en_detailed_description": _first(value, "en_detailed_description"),
    }


def editable_hash(record: BaselineRecord | Mapping[str, Any]) -> str:
    """Hash editable content plus all timestamps used for concurrency checks."""

    value = _as_mapping(record)
    payload = {
        "content": _editable_content_payload(record),
        "place_updated_at": _first(value, "updated_at", "place_updated_at"),
        "vi_updated_at": _first(value, "translation_updated_at_vi", "vi_updated_at"),
        "en_updated_at": _first(value, "translation_updated_at_en", "en_updated_at"),
    }
    return _canonical_hash(payload)


def applied_content_hash(record: BaselineRecord | Mapping[str, Any]) -> str:
    """Hash exactly the nine editable content values, excluding timestamps."""

    return _canonical_hash(_editable_content_payload(record))


def _chunks(values: Sequence[str], size: int) -> Iterator[tuple[str, ...]]:
    if size <= 0:
        raise ValueError("batch size must be positive")
    for start in range(0, len(values), size):
        yield tuple(values[start:start + size])


def _fetch_related(
    client: Any,
    table: str,
    fields: str,
    filter_field: str,
    ids: Sequence[str],
    *,
    batch_size: int,
    extra_filters: Sequence[tuple[str, str, Any]] = (),
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for id_batch in _chunks(ids, batch_size):
        query = client.table(table).select(fields).in_(filter_field, list(id_batch))
        for method, field, value in extra_filters:
            query = getattr(query, method)(field, value)
        response = query.execute()
        rows.extend(response.data or [])
    return rows


def _translation_index(rows: Iterable[Mapping[str, Any]]) -> dict[str, dict[str, Mapping[str, Any]]]:
    index: dict[str, dict[str, Mapping[str, Any]]] = defaultdict(dict)
    for row in rows:
        place_id = str(row.get("place_id", ""))
        lang_code = str(row.get("lang_code", ""))
        if not place_id or lang_code not in {"vi", "en"}:
            continue
        if lang_code in index[place_id]:
            raise BaselineIntegrityError(
                f"duplicate {lang_code} translation for place {place_id}"
            )
        index[place_id][lang_code] = row
    return index


def _build_record(
    place: Mapping[str, Any],
    translations: Mapping[str, Mapping[str, Any]],
    freshness: Sequence[Mapping[str, Any]],
    subcategory: Mapping[str, Any] | None,
    tags: Sequence[Mapping[str, Any]],
) -> BaselineRecord:
    place_id = str(place["id_place"])
    vi = translations.get("vi")
    en = translations.get("en")
    if vi is None or en is None:
        missing = ", ".join(lang for lang, row in (("vi", vi), ("en", en)) if row is None)
        raise BaselineIntegrityError(f"missing {missing} translation for place {place_id}")

    payload: dict[str, Any] = {
        "place_id": place_id,
        "province_id": str(place["id_province"]),
        "status": str(place.get("status") or ""),
        # `place` is the Vietnamese source of truth; the vi row is checked for
        # cardinality and contributes its concurrency timestamp.
        "vi_name": place.get("name") or vi.get("name") or "",
        "vi_short_description": place.get("short_description") or vi.get("description"),
        "vi_detailed_description": place.get("detailed_description"),
        "en_name": en.get("name"),
        "en_short_description": en.get("description"),
        "en_detailed_description": en.get("detailed_description"),
        "address": place.get("address"),
        "latitude": place.get("latitude"),
        "longitude": place.get("longitude"),
        "subcategory_id": str(place["id_place_subcategory"])
        if place.get("id_place_subcategory")
        else None,
        "subcategory_name": subcategory.get("name") if subcategory else None,
        "subcategory_category": subcategory.get("place_category") if subcategory else None,
        "source": place.get("source"),
        "source_place_id": place.get("source_place_id"),
        "website": place.get("website"),
        "updated_at": place.get("updated_at"),
        "translation_updated_at_vi": vi.get("updated_at"),
        "translation_updated_at_en": en.get("updated_at"),
        "content_freshness": tuple(dict(row) for row in freshness),
        "tags": tuple(dict(row) for row in tags),
    }
    payload["input_hash"] = editable_hash(payload)
    return BaselineRecord(**payload)


def fetch_baseline(
    client: Any,
    *,
    province_ids: Sequence[str] = tuple(APPROVED_PROVINCES),
    page_size: int = DEFAULT_PAGE_SIZE,
    related_batch_size: int = DEFAULT_RELATED_BATCH_SIZE,
    artifact_store: ArtifactStore | None = None,
) -> Iterator[BaselineRecord]:
    """Stream the fixed scope, batching all related reads and translations."""

    requested = tuple(str(province_id) for province_id in province_ids)
    outside = set(requested).difference(APPROVED_PROVINCES)
    if outside:
        raise BaselineIntegrityError(
            "baseline request contains outside-scope provinces: " + ", ".join(sorted(outside))
        )
    if not requested:
        raise BaselineIntegrityError("baseline request must contain a province allowlist")
    if page_size <= 0 or related_batch_size <= 0:
        raise ValueError("page and related batch sizes must be positive")

    start = 0
    seen_place_ids: set[str] = set()
    while True:
        response = (
            client.table("place")
            .select(PLACE_FIELDS)
            .in_("id_province", list(requested))
            .range(start, start + page_size - 1)
            .execute()
        )
        page = list(response.data or [])
        if not page:
            break
        page_ids = [str(row["id_place"]) for row in page]
        if len(page_ids) != len(set(page_ids)):
            raise BaselineIntegrityError("duplicate place ID inside baseline page")
        if seen_place_ids.intersection(page_ids):
            raise BaselineIntegrityError("duplicate place ID across baseline pages")
        seen_place_ids.update(page_ids)

        translation_rows = _fetch_related(
            client,
            "place_translation",
            TRANSLATION_FIELDS,
            "place_id",
            page_ids,
            batch_size=related_batch_size,
        )
        translation_by_place = _translation_index(translation_rows)
        freshness_rows = _fetch_related(
            client,
            "content_freshness",
            FRESHNESS_FIELDS,
            "content_id",
            page_ids,
            batch_size=related_batch_size,
            extra_filters=(("eq", "content_type", "place"),),
        )
        freshness_by_place: dict[str, list[Mapping[str, Any]]] = defaultdict(list)
        for row in freshness_rows:
            freshness_by_place[str(row.get("content_id"))].append(row)

        subcategory_ids = [
            str(row["id_place_subcategory"])
            for row in page
            if row.get("id_place_subcategory")
        ]
        subcategory_rows = _fetch_related(
            client,
            "place_subcategory",
            SUBCATEGORY_FIELDS,
            "id_place_subcategory",
            list(dict.fromkeys(subcategory_ids)),
            batch_size=related_batch_size,
        )
        subcategory_by_id = {
            str(row["id_place_subcategory"]): row for row in subcategory_rows
        }
        tag_rows = _fetch_related(
            client,
            "place_tag",
            TAG_FIELDS,
            "id_place",
            page_ids,
            batch_size=related_batch_size,
        )
        tags_by_place: dict[str, list[Mapping[str, Any]]] = defaultdict(list)
        for row in tag_rows:
            tags_by_place[str(row.get("id_place"))].append(row)

        for place in page:
            place_id = str(place["id_place"])
            record = _build_record(
                place,
                translation_by_place.get(place_id, {}),
                freshness_by_place.get(place_id, []),
                subcategory_by_id.get(str(place.get("id_place_subcategory"))),
                tags_by_place.get(place_id, []),
            )
            if artifact_store is not None:
                artifact_store.append_jsonl("baseline", record.model_dump(mode="json"))
            yield record

        if len(page) < page_size:
            break
        start += page_size


def verify_baseline_counts(
    records: Iterable[BaselineRecord | Mapping[str, Any]],
    expected_counts: Mapping[str, int] = APPROVED_PROVINCES,
) -> dict[str, int]:
    """Require exactly the allowlisted province counts and no outside rows."""

    counts: Counter[str] = Counter()
    seen_place_ids: set[str] = set()
    allowed = set(expected_counts)
    for record in records:
        value = _as_mapping(record)
        province_id = str(value.get("province_id", ""))
        place_id = str(value.get("place_id", ""))
        if province_id not in allowed:
            raise BaselineIntegrityError(f"outside-scope province row: {province_id}")
        if not place_id or place_id in seen_place_ids:
            raise BaselineIntegrityError(f"missing or duplicate place ID: {place_id}")
        seen_place_ids.add(place_id)
        counts[province_id] += 1
    actual = dict(counts)
    expected = dict(expected_counts)
    if actual != expected or sum(actual.values()) != sum(expected.values()):
        raise BaselineIntegrityError(
            f"baseline counts mismatch: expected={expected}, actual={actual}"
        )
    return actual


def audit_scope(
    client: Any,
    *,
    artifact_store: ArtifactStore | None = None,
    run_id: str | None = None,
) -> RunManifest:
    """Read-only audit that streams the fixed scope into optional artifacts."""

    manifest_id = run_id or new_run_id()
    records = fetch_baseline(client, artifact_store=artifact_store)
    # Counters and IDs are bounded by the exact scope, not full records.
    counts: Counter[str] = Counter()
    place_ids: list[str] = []
    for record in records:
        counts[record.province_id] += 1
        place_ids.append(record.place_id)
    if (
        dict(counts) != dict(APPROVED_PROVINCES)
        or sum(counts.values()) != EXPECTED_TOTAL
        or len(place_ids) != len(set(place_ids))
    ):
        raise BaselineIntegrityError(f"baseline counts mismatch during audit: {dict(counts)}")
    manifest = RunManifest(
        run_id=manifest_id,
        province_ids=tuple(APPROVED_PROVINCES),
        place_ids=tuple(place_ids),
        expected_total=EXPECTED_TOTAL,
    )
    if artifact_store is not None:
        artifact_store.write_manifest(manifest)
    return manifest
