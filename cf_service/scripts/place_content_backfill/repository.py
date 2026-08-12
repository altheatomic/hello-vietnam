from __future__ import annotations

from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
from typing import Any, Iterable, Iterator, Mapping, Sequence

from .artifacts import ArtifactStore
from .constants import (
    APPROVED_PROVINCES,
    DEFAULT_APPLY_BATCH_SIZE,
    DEFAULT_PAGE_SIZE,
    DEFAULT_RELATED_BATCH_SIZE,
    EXPECTED_TOTAL,
    new_run_id,
)
from .models import (
    BaselineRecord,
    Proposal,
    ReviewDecision,
    RunManifest,
    SourceSnapshot,
)


class BaselineIntegrityError(ValueError):
    """Raised when the fixed baseline scope is incomplete or ambiguous."""


class ApplyError(RuntimeError):
    """Base class for guarded apply and rollback failures."""


class ApplyConflict(ApplyError):
    """Raised when the live content no longer matches the baseline hash."""


class ApplyIntegrityError(ApplyError):
    """Raised when scope, review, or row cardinality safety checks fail."""


class RollbackConflict(ApplyError):
    """Raised when an administrator changed content after this run applied it."""


@dataclass(frozen=True)
class ApplyItem:
    """One explicitly reviewed proposal and its immutable concurrency baseline."""

    proposal: Proposal
    baseline: BaselineRecord
    source_snapshot: SourceSnapshot | None = None
    review_decision: ReviewDecision | None = None


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

PLACE_LOCK_SQL = """
SELECT id_place, id_province, name, short_description, detailed_description, updated_at
FROM public.place
WHERE id_place = $1
FOR UPDATE
"""
TRANSLATION_LOCK_SQL = """
SELECT id, place_id, lang_code, name, description, detailed_description, updated_at
FROM public.place_translation
WHERE place_id = $1 AND lang_code IN ('vi', 'en')
ORDER BY lang_code
FOR UPDATE
"""
PLACE_UPDATE_SQL = """
UPDATE public.place
SET name = $2, short_description = $3, detailed_description = $4
WHERE id_place = $1
RETURNING id_place, updated_at
"""
TRANSLATION_UPDATE_SQL = """
UPDATE public.place_translation
SET name = $2, description = $3, detailed_description = $4
WHERE place_id = $1 AND lang_code = $5
RETURNING id, place_id, lang_code, updated_at
"""


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _row_dict(row: Mapping[str, Any] | Any) -> dict[str, Any]:
    return dict(row)


def _translation_by_language(rows: Iterable[Mapping[str, Any]]) -> dict[str, dict[str, Any]]:
    translations: dict[str, dict[str, Any]] = {}
    for row in rows:
        value = _row_dict(row)
        language = str(value.get("lang_code") or "")
        if language in translations:
            raise ApplyIntegrityError(f"duplicate {language} translation")
        if language in {"vi", "en"}:
            translations[language] = value
    if set(translations) != {"vi", "en"}:
        raise ApplyIntegrityError("exactly one vi and one en translation are required")
    return translations


def _live_content_record(
    place: Mapping[str, Any],
    translations: Mapping[str, Mapping[str, Any]],
) -> dict[str, Any]:
    vi = translations["vi"]
    en = translations["en"]
    return {
        "place_id": str(place.get("id_place")),
        "province_id": str(place.get("id_province")),
        "vi_name": place.get("name"),
        "vi_short_description": place.get("short_description"),
        "vi_detailed_description": place.get("detailed_description"),
        "en_name": en.get("name"),
        "en_short_description": en.get("description"),
        "en_detailed_description": en.get("detailed_description"),
        "updated_at": place.get("updated_at"),
        "translation_updated_at_vi": vi.get("updated_at"),
        "translation_updated_at_en": en.get("updated_at"),
    }


def _proposal_content_record(item: ApplyItem) -> dict[str, Any]:
    generated = item.proposal.generated
    return {
        "place_id": item.proposal.place_id,
        "province_id": item.proposal.province_id,
        "vi_name": item.proposal.name_decision.vi_name,
        "vi_short_description": generated.vi_short,
        "vi_detailed_description": generated.vi_long,
        "en_name": item.proposal.name_decision.en_name,
        "en_short_description": generated.en_short,
        "en_detailed_description": generated.en_long,
        "updated_at": None,
        "translation_updated_at_vi": None,
        "translation_updated_at_en": None,
    }


def _preimage(
    item: ApplyItem,
    live: Mapping[str, Any],
) -> dict[str, Any]:
    target = _proposal_content_record(item)
    return {
        "event": "prepared",
        "batch_id": "",
        "place_id": item.proposal.place_id,
        "province_id": item.baseline.province_id,
        "baseline_input_hash": item.baseline.input_hash,
        "before": {
            key: live.get(key)
            for key in (
                "vi_name",
                "vi_short_description",
                "vi_detailed_description",
                "en_name",
                "en_short_description",
                "en_detailed_description",
            )
        },
        "target": {
            key: target.get(key)
            for key in (
                "vi_name",
                "vi_short_description",
                "vi_detailed_description",
                "en_name",
                "en_short_description",
                "en_detailed_description",
            )
        },
        "applied_content_hash": applied_content_hash(target),
        "prepared_at": _utc_now(),
    }


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
        default=_json_default,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _json_default(value: Any) -> str:
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc).isoformat()
    raise TypeError(f"Object of type {type(value).__name__} is not JSON serializable")


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


def _selector_key(selector: Mapping[str, Any]) -> tuple[str, Any]:
    allowed = {"place_id", "batch_id", "province_id", "pilot", "all"}
    unknown = set(selector).difference(allowed)
    if unknown:
        raise ValueError("unknown rollback selector: " + ", ".join(sorted(unknown)))
    active = [
        (key, value)
        for key, value in selector.items()
        if value is not None and value is not False and value != ""
    ]
    if len(active) != 1:
        raise ValueError("exactly one rollback selector is required")
    key, value = active[0]
    if key in {"pilot", "all"} and value is not True:
        raise ValueError(f"{key} selector must be true")
    return key, value


def _matches_selector(
    record: Mapping[str, Any],
    selector_key: str,
    selector_value: Any,
    manifest: RunManifest,
) -> bool:
    place_id = str(record.get("place_id") or "")
    if manifest.place_ids and place_id not in set(manifest.place_ids):
        return False
    if selector_key == "place_id":
        return place_id == str(selector_value)
    if selector_key == "batch_id":
        return str(record.get("batch_id") or "") == str(selector_value)
    if selector_key == "province_id":
        return str(record.get("province_id") or "") == str(selector_value)
    if selector_key == "pilot":
        return place_id in set(manifest.pilot_place_ids)
    return selector_key == "all"


def validate_apply_selection(
    manifest: RunManifest,
    items: Iterable[ApplyItem],
    *,
    approved_place_ids: Iterable[str],
    selector: Mapping[str, Any] | None = None,
    max_batch_size: int = DEFAULT_APPLY_BATCH_SIZE,
) -> tuple[ApplyItem, ...]:
    """Validate review, scope, and bounded-batch gates before a DB transaction."""

    if max_batch_size <= 0:
        raise ValueError("max_batch_size must be positive")
    selected = tuple(items)
    if len(selected) > max_batch_size:
        raise ApplyIntegrityError(
            f"apply batch contains {len(selected)} places; maximum is {max_batch_size}"
        )
    approved = {str(place_id) for place_id in approved_place_ids}
    manifest_places = set(manifest.place_ids)
    selector_parts = _selector_key(selector) if selector is not None else None
    for item in selected:
        proposal = item.proposal
        baseline = item.baseline
        decision = item.review_decision
        if decision is None or decision.place_id != proposal.place_id:
            raise ApplyIntegrityError(f"unresolved review for {proposal.place_id}")
        if decision.decision not in {"approve", "edit"}:
            raise ApplyIntegrityError(f"proposal is not approved: {proposal.place_id}")
        if proposal.place_id not in approved:
            raise ApplyIntegrityError(f"proposal lacks an explicit approval record: {proposal.place_id}")
        if proposal.place_id != baseline.place_id:
            raise ApplyIntegrityError(f"proposal/baseline place mismatch: {proposal.place_id}")
        if proposal.province_id != baseline.province_id:
            raise ApplyIntegrityError(f"proposal/baseline province mismatch: {proposal.place_id}")
        if proposal.baseline_input_hash != baseline.input_hash:
            raise ApplyConflict(f"proposal baseline hash mismatch: {proposal.place_id}")
        if baseline.province_id not in manifest.province_ids:
            raise ApplyIntegrityError(f"outside-manifest province: {baseline.province_id}")
        if manifest_places and proposal.place_id not in manifest_places:
            raise ApplyIntegrityError(f"place is outside the run manifest: {proposal.place_id}")
        if selector_parts is not None and not _matches_selector(
            {"place_id": proposal.place_id, "province_id": baseline.province_id},
            selector_parts[0],
            selector_parts[1],
            manifest,
        ):
            raise ApplyIntegrityError(f"place does not match selector: {proposal.place_id}")
        if item.source_snapshot is not None:
            from .validators import validate_proposal

            validation = validate_proposal(proposal, baseline, item.source_snapshot)
            if not validation.passed:
                raise ApplyIntegrityError(
                    f"proposal failed deterministic validation: {proposal.place_id}"
                )
            if decision.decision == "edit":
                from .validators import validate_edited_fields

                if not validate_edited_fields(
                    proposal,
                    baseline,
                    item.source_snapshot,
                    {str(key): str(value) for key, value in decision.edited_fields.items()},
                ):
                    raise ApplyIntegrityError(
                        f"edited proposal failed deterministic revalidation: {proposal.place_id}"
                    )
        elif decision.decision == "edit":
            raise ApplyIntegrityError(
                f"edited proposal needs a revalidation snapshot: {proposal.place_id}"
            )
    return selected


async def _locked_live_record(connection: Any, place_id: str) -> dict[str, Any]:
    place_rows = await connection.fetch(PLACE_LOCK_SQL, place_id)
    if len(place_rows) != 1:
        raise ApplyIntegrityError(
            f"expected exactly one place row for {place_id}, got {len(place_rows)}"
        )
    translation_rows = await connection.fetch(TRANSLATION_LOCK_SQL, place_id)
    translations = _translation_by_language(translation_rows)
    return _live_content_record(_row_dict(place_rows[0]), translations)


async def _write_content_updates(
    connection: Any,
    place_id: str,
    values: Mapping[str, Any],
) -> dict[str, str | None]:
    place_returned = await connection.fetchrow(
        PLACE_UPDATE_SQL,
        place_id,
        values.get("vi_name"),
        values.get("vi_short_description"),
        values.get("vi_detailed_description"),
    )
    if place_returned is None or str(place_returned.get("id_place")) != place_id:
        raise ApplyIntegrityError(f"place update affected zero rows: {place_id}")
    timestamps: dict[str, str | None] = {
        "place_updated_at": place_returned.get("updated_at"),
    }
    for language in ("vi", "en"):
        translation_returned = await connection.fetchrow(
            TRANSLATION_UPDATE_SQL,
            place_id,
            values.get(f"{language}_name"),
            values.get(f"{language}_short_description"),
            values.get(f"{language}_detailed_description"),
            language,
        )
        if (
            translation_returned is None
            or str(translation_returned.get("place_id")) != place_id
            or str(translation_returned.get("lang_code")) != language
        ):
            raise ApplyIntegrityError(
                f"{language} translation update affected zero rows: {place_id}"
            )
        timestamps[f"translation_updated_at_{language}"] = translation_returned.get("updated_at")
    return timestamps


async def apply_approved_batch(
    connection: Any,
    items: Iterable[ApplyItem],
    artifact_store: ArtifactStore,
    *,
    manifest: RunManifest,
    batch_id: str,
    approved_place_ids: Iterable[str],
    max_batch_size: int = DEFAULT_APPLY_BATCH_SIZE,
) -> dict[str, int | str]:
    """Apply one reviewed batch using injected asyncpg-compatible connection state."""

    if not batch_id.strip():
        raise ValueError("batch_id must not be blank")
    selected = validate_apply_selection(
        manifest,
        items,
        approved_place_ids=approved_place_ids,
        max_batch_size=max_batch_size,
    )
    prepared: list[dict[str, Any]] = []
    async with connection.transaction():
        for item in selected:
            live = await _locked_live_record(connection, item.proposal.place_id)
            if editable_hash(live) != item.baseline.input_hash:
                raise ApplyConflict(f"baseline hash conflict: {item.proposal.place_id}")
            preimage = _preimage(item, live)
            preimage["batch_id"] = batch_id
            artifact_store.append_jsonl("rollback", preimage)
            prepared.append(preimage)
        for item, preimage in zip(selected, prepared):
            target = dict(preimage["target"])
            timestamps = await _write_content_updates(
                connection,
                item.proposal.place_id,
                target,
            )
            preimage["returned_timestamps"] = timestamps
    for preimage in prepared:
        artifact_store.append_jsonl(
            "applied",
            {
                **preimage,
                "event": "applied",
                "applied_at": _utc_now(),
            },
        )
    return {"batch_id": batch_id, "applied": len(prepared)}


async def recover_post_commit_artifacts(
    connection: Any,
    artifact_store: ArtifactStore,
    *,
    batch_id: str,
) -> dict[str, int]:
    """Recover applied markers after a commit succeeded but artifact append failed."""

    applied_ids = {
        str(row.get("place_id"))
        for row in artifact_store.iter_stream("applied")
        if str(row.get("batch_id")) == batch_id
    }
    recovered = 0
    unresolved = 0
    for preimage in artifact_store.iter_stream("rollback"):
        if (
            preimage.get("event") != "prepared"
            or str(preimage.get("batch_id")) != batch_id
            or str(preimage.get("place_id")) in applied_ids
        ):
            continue
        live = await _locked_live_record(connection, str(preimage["place_id"]))
        if applied_content_hash(live) != preimage.get("applied_content_hash"):
            unresolved += 1
            continue
        artifact_store.append_jsonl(
            "applied",
            {
                **preimage,
                "event": "recovered",
                "applied_at": _utc_now(),
            },
        )
        recovered += 1
    return {"recovered": recovered, "unresolved": unresolved}


async def rollback_applied_batch(
    connection: Any,
    artifact_store: ArtifactStore,
    *,
    manifest: RunManifest,
    selector: Mapping[str, Any],
    max_batch_size: int = DEFAULT_APPLY_BATCH_SIZE,
) -> dict[str, int | str]:
    """Restore selected rows only when their live content hash is unchanged."""

    selector_key, selector_value = _selector_key(selector)
    applied = [
        row
        for row in artifact_store.iter_stream("applied")
        if row.get("event") in {"applied", "recovered"}
        and _matches_selector(row, selector_key, selector_value, manifest)
    ]
    if not applied:
        raise ApplyIntegrityError("rollback selector matched no applied rows in the manifest")
    if max_batch_size <= 0:
        raise ValueError("max_batch_size must be positive")
    restored = 0
    for start in range(0, len(applied), max_batch_size):
        chunk = applied[start:start + max_batch_size]
        async with connection.transaction():
            for applied_record in chunk:
                place_id = str(applied_record["place_id"])
                live = await _locked_live_record(connection, place_id)
                if applied_content_hash(live) != applied_record.get("applied_content_hash"):
                    raise RollbackConflict(
                        f"refusing rollback after later admin edit: {place_id}"
                    )
                before = applied_record.get("before")
                if not isinstance(before, Mapping):
                    raise ApplyIntegrityError(f"rollback pre-image missing: {place_id}")
                await _write_content_updates(connection, place_id, before)
        for applied_record in chunk:
            artifact_store.append_jsonl(
                "rollback",
                {
                    "event": "rolled_back",
                    "batch_id": applied_record.get("batch_id"),
                    "place_id": applied_record.get("place_id"),
                    "province_id": applied_record.get("province_id"),
                    "restored_content_hash": applied_content_hash(before),
                    "rolled_back_at": _utc_now(),
                },
            )
            restored += 1
    return {"restored": restored, "selector": selector_key}


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
