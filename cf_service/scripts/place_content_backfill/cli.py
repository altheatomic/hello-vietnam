from __future__ import annotations

import argparse
import asyncio
import json
import os
from pathlib import Path
import sys
import tempfile
from typing import Any, Sequence

from .constants import (
    DEFAULT_COLLECT_WORKER_CHUNK_SIZE,
    DEFAULT_GENERATE_WORKER_CHUNK_SIZE,
    DEFAULT_VALIDATE_WORKER_CHUNK_SIZE,
    new_run_id,
)
from .artifacts import ArtifactStore, ChunkSupervisor, WorkerFailure
from .generator import (
    MAX_OUTPUT_TOKENS,
    BudgetCaps,
    BudgetExceeded,
    BudgetState,
    DeepSeekClient,
    estimate_generation_input_tokens,
    generate_worker,
)
from .naming import normalize_names
from .repository import audit_scope
from .models import (
    BaselineRecord,
    Proposal,
    ReviewDecision,
    RunManifest,
    SourceSnapshot,
    ValidationResult,
)
from .sources import collect_worker
from .validators import (
    find_near_duplicates_stream,
    import_review_csv,
    rebuild_review_artifacts,
    validate_edited_fields,
    validate_worker,
)


def _add_selectors(parser: argparse.ArgumentParser, *, run_required: bool = False) -> None:
    parser.add_argument("--run-id", required=run_required)
    parser.add_argument("--pilot", action="store_true")
    parser.add_argument("--place-id")
    parser.add_argument("--batch-id")
    parser.add_argument("--province-id")
    parser.add_argument("--all", dest="all_scope", action="store_true")


def _add_worker_options(parser: argparse.ArgumentParser, default: int) -> None:
    parser.add_argument("--worker-chunk-size", type=int, default=default)
    parser.add_argument(
        "--worker-place-ids",
        nargs="+",
        dest="worker_place_ids",
        help=argparse.SUPPRESS,
    )
    parser.add_argument("--worker-status-path", type=Path, help=argparse.SUPPRESS)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="place-content-backfill",
        description="Safe, resumable bilingual place-content backfill pipeline",
    )
    commands = parser.add_subparsers(dest="command", required=True)

    audit = commands.add_parser("audit", help="read-only scope audit")
    audit.add_argument("--scope", choices=("approved-five",), default="approved-five")
    _add_selectors(audit)

    collect = commands.add_parser("collect", help="collect identity-safe source facts")
    _add_selectors(collect, run_required=True)
    _add_worker_options(collect, DEFAULT_COLLECT_WORKER_CHUNK_SIZE)

    generate = commands.add_parser("generate", help="generate mocked/provider-gated copy proposals")
    _add_selectors(generate, run_required=True)
    _add_worker_options(generate, DEFAULT_GENERATE_WORKER_CHUNK_SIZE)
    generate.add_argument(
        "--confirm-provider",
        action="store_true",
        help="confirm an owner-approved real provider invocation",
    )

    validate = commands.add_parser("validate", help="validate proposals and prepare review")
    _add_selectors(validate, run_required=True)
    _add_worker_options(validate, DEFAULT_VALIDATE_WORKER_CHUNK_SIZE)

    review_import = commands.add_parser("review-import", help="append human review decisions")
    review_import.add_argument("--run-id", required=True)
    review_import.add_argument("--file", required=True, type=Path)

    apply = commands.add_parser("apply", help="apply explicitly approved content")
    _add_selectors(apply, run_required=True)
    apply.add_argument("--confirm", action="store_true")

    rollback = commands.add_parser("rollback", help="constrained rollback of applied content")
    _add_selectors(rollback, run_required=True)
    rollback.add_argument("--confirm", action="store_true")

    status = commands.add_parser("status", help="show bounded run status")
    _add_selectors(status, run_required=True)

    return parser


def _require_confirmation(parser: argparse.ArgumentParser, args: argparse.Namespace) -> None:
    if args.command in {"apply", "rollback"} and not args.confirm:
        parser.error(f"{args.command} requires --confirm")


def _write_worker_status(path: Path | None, payload: dict[str, Any]) -> None:
    if path is None:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.tmp")
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
    with temporary.open("w", encoding="utf-8", newline="") as handle:
        handle.write(encoded)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)


def _artifact_root() -> Path:
    """Resolve the repository-level artifact directory from either CLI cwd."""

    current = Path.cwd().resolve()
    if current.name == "cf_service":
        return current.parent / ".artifacts/place-content"
    return current / ".artifacts/place-content"


def _load_selected_baseline(store: ArtifactStore, place_ids: set[str]):
    for row in store.iter_stream("baseline"):
        if str(row.get("place_id")) in place_ids:
            yield BaselineRecord.model_validate(row)


def _find_artifact_record(store: ArtifactStore, stream: str, place_id: str) -> dict[str, Any] | None:
    for row in store.iter_stream(stream):
        if str(row.get("place_id")) == place_id:
            return row
    return None


def _proposal_from_artifact(row: dict[str, Any]) -> Proposal:
    payload = row.get("proposal", row)
    return Proposal.model_validate(payload)


def _validate_review_edit_from_artifacts(
    store: ArtifactStore,
    place_id: str,
    edited_fields: dict[str, str],
) -> bool:
    baseline_row = _find_artifact_record(store, "baseline", place_id)
    source_row = _find_artifact_record(store, "sources", place_id)
    proposal_row = _find_artifact_record(store, "proposals", place_id)
    if baseline_row is None or source_row is None or proposal_row is None:
        return False
    return validate_edited_fields(
        _proposal_from_artifact(proposal_row),
        BaselineRecord.model_validate(baseline_row),
        SourceSnapshot.model_validate(source_row),
        edited_fields,
    )


def _run_collect(args: argparse.Namespace, parser: argparse.ArgumentParser) -> int:
    root = _artifact_root()
    store = ArtifactStore(root, args.run_id)
    if not store.path("baseline").exists():
        parser.error("collect requires a baseline.jsonl artifact for the run")
    if args.worker_place_ids is not None:
        if len(args.worker_place_ids) > args.worker_chunk_size:
            parser.error("worker place ID list exceeds --worker-chunk-size")
        selected = {str(place_id) for place_id in args.worker_place_ids}
        processed = asyncio.run(
            collect_worker(
                _load_selected_baseline(store, selected),
                store,
                max_places=args.worker_chunk_size,
            )
        )
        _write_worker_status(
            args.worker_status_path,
            {"command": "collect", "place_count": processed, "place_ids": sorted(selected)},
        )
        return 0
    place_ids = (
        str(row["place_id"])
        for row in store.iter_stream("baseline")
        if row.get("place_id")
    )
    completed = store.completed_place_ids("sources")
    supervisor = ChunkSupervisor(store)
    supervisor.run_serial(
        place_ids,
        args.worker_chunk_size,
        lambda chunk, status_path: (
            sys.executable,
            "-m",
            "scripts.place_content_backfill.cli",
            "collect",
            "--run-id",
            args.run_id,
            "--worker-chunk-size",
            str(args.worker_chunk_size),
            "--worker-status-path",
            str(status_path),
            "--worker-place-ids",
            *chunk,
        ),
        completed_ids=completed,
    )
    return 0


def _required_environment(name: str) -> str:
    value = os.environ.get(name)
    if value is None or not value.strip():
        raise ValueError(f"required runtime variable is missing: {name}")
    return value.strip()


def _provider_budget_from_environment() -> BudgetCaps:
    try:
        return BudgetCaps(
            max_requests=int(_required_environment("DEEPSEEK_MAX_REQUESTS")),
            max_input_tokens=int(_required_environment("DEEPSEEK_MAX_INPUT_TOKENS")),
            max_output_tokens=int(_required_environment("DEEPSEEK_MAX_OUTPUT_TOKENS")),
            max_estimated_cost_usd=float(
                _required_environment("DEEPSEEK_MAX_ESTIMATED_COST_USD")
            ),
            input_cost_per_million_usd=float(
                _required_environment("DEEPSEEK_INPUT_COST_PER_MILLION_USD")
            ),
            output_cost_per_million_usd=float(
                _required_environment("DEEPSEEK_OUTPUT_COST_PER_MILLION_USD")
            ),
        )
    except ValueError as exc:
        if str(exc).startswith("required runtime variable is missing:"):
            raise
        raise ValueError("DeepSeek runtime caps and prices must be numeric") from exc


def _budget_state_from_proposals(store: ArtifactStore) -> BudgetState:
    state = BudgetState()
    for row in store.iter_stream("proposals"):
        usage = row.get("usage")
        if not isinstance(usage, dict):
            raise ValueError("proposal artifact is missing provider usage")
        if not bool(row.get("cache_hit")):
            state.request_count += 1
        state.request_attempts += int(
            usage.get("request_attempts")
            if usage.get("request_attempts") is not None
            else (0 if bool(row.get("cache_hit")) else 1)
        )
        state.input_tokens += int(usage.get("prompt_tokens") or 0)
        state.output_tokens += int(usage.get("completion_tokens") or 0)
        state.estimated_cost_usd += float(usage.get("estimated_cost_usd") or 0.0)
    return state


def _budget_status(state: BudgetState) -> dict[str, int | float]:
    return {
        "request_count": state.request_count,
        "request_attempts": state.request_attempts,
        "input_tokens": state.input_tokens,
        "output_tokens": state.output_tokens,
        "estimated_cost_usd": state.estimated_cost_usd,
    }


def _failed_generation_worker_exists(store: ArtifactStore) -> bool:
    for path in sorted(store.run_dir.glob("worker-*.status.json")):
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return True
        if payload.get("command") == "generate" and payload.get("ok") is False:
            return True
    return False


def _load_manifest(store: ArtifactStore, run_id: str) -> RunManifest:
    path = store.path("manifest")
    if not path.exists():
        raise ValueError("generate requires manifest.json")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError("manifest.json is unreadable or invalid") from exc
    manifest = RunManifest.model_validate(payload)
    if manifest.run_id != run_id:
        raise ValueError("manifest run ID does not match --run-id")
    return manifest


def _selected_generation_place_ids(
    args: argparse.Namespace,
    parser: argparse.ArgumentParser,
    manifest: RunManifest,
    store: ArtifactStore,
) -> tuple[str, ...]:
    selected_flags = (
        bool(args.pilot),
        args.place_id is not None,
        args.batch_id is not None,
        args.province_id is not None,
        bool(args.all_scope),
    )
    if sum(selected_flags) != 1:
        parser.error("generate requires exactly one scope selector")
    manifest_ids = set(manifest.place_ids)
    if args.pilot:
        selected = tuple(manifest.pilot_place_ids)
        if len(selected) != 100 or len(set(selected)) != 100:
            parser.error("pilot generation requires exactly 100 unique manifest IDs")
    elif args.place_id is not None:
        selected = (str(args.place_id),)
    elif args.province_id is not None:
        if args.province_id not in manifest.province_ids:
            parser.error("province selector is outside the manifest")
        selected = tuple(
            str(row["place_id"])
            for row in store.iter_stream("baseline")
            if row.get("province_id") == args.province_id and row.get("place_id")
        )
    elif args.all_scope:
        selected = tuple(manifest.place_ids)
    else:
        parser.error("--batch-id is unavailable until a reviewed batch manifest exists")
    if not selected or not set(selected).issubset(manifest_ids):
        parser.error("generate selector contains IDs outside the manifest")
    return selected


def _baseline_input_hashes(
    store: ArtifactStore,
    selected_ids: set[str],
) -> dict[str, str]:
    hashes: dict[str, str] = {}
    for row in store.iter_stream("baseline"):
        place_id = str(row.get("place_id") or "")
        if place_id not in selected_ids:
            continue
        if place_id in hashes:
            raise ValueError(f"duplicate baseline record for place {place_id}")
        input_hash = str(row.get("input_hash") or "")
        if not input_hash:
            raise ValueError(f"baseline input hash is missing for place {place_id}")
        hashes[place_id] = input_hash
    if selected_ids.difference(hashes):
        raise ValueError("selected place IDs are absent from the baseline")
    return hashes


def _completed_generation_hashes(store: ArtifactStore) -> dict[str, str]:
    completed: dict[str, str] = {}
    for row in store.iter_stream("proposals"):
        proposal = row.get("proposal")
        proposal_payload = proposal if isinstance(proposal, dict) else {}
        place_id = str(row.get("place_id") or proposal_payload.get("place_id") or "")
        input_hash = str(
            row.get("baseline_input_hash")
            or proposal_payload.get("baseline_input_hash")
            or ""
        )
        if place_id and input_hash:
            completed[place_id] = input_hash
    return completed


def _ensure_generation_batch_fits_budget(
    store: ArtifactStore,
    pending_ids: tuple[str, ...],
    state: BudgetState,
    caps: BudgetCaps,
) -> None:
    estimated_input_tokens = sum(
        estimate_generation_input_tokens(record, snapshot, name_decision)
        for record, snapshot, name_decision in _load_generation_items(
            store,
            set(pending_ids),
        )
    )
    projected_requests = state.request_attempts + len(pending_ids)
    projected_input = state.input_tokens + estimated_input_tokens
    projected_output = state.output_tokens + len(pending_ids) * MAX_OUTPUT_TOKENS
    projected_cost = state.estimated_cost_usd + (
        estimated_input_tokens * float(caps.input_cost_per_million_usd)
        + len(pending_ids)
        * MAX_OUTPUT_TOKENS
        * float(caps.output_cost_per_million_usd)
    ) / 1_000_000
    if projected_requests > caps.max_requests:
        raise BudgetExceeded("pilot request cap is insufficient before generation")
    if projected_input > caps.max_input_tokens:
        raise BudgetExceeded("pilot input-token cap is insufficient before generation")
    if projected_output > caps.max_output_tokens:
        raise BudgetExceeded("pilot output-token cap is insufficient before generation")
    if projected_cost > caps.max_estimated_cost_usd:
        raise BudgetExceeded("pilot estimated-cost cap is insufficient before generation")


def _load_generation_items(store: ArtifactStore, place_ids: set[str]):
    selected_sources: dict[str, SourceSnapshot] = {}
    for row in store.iter_stream("sources"):
        place_id = str(row.get("place_id") or "")
        if place_id in place_ids:
            if place_id in selected_sources:
                raise ValueError(f"duplicate source snapshot for place {place_id}")
            selected_sources[place_id] = SourceSnapshot.model_validate(row)

    seen: set[str] = set()
    for row in store.iter_stream("baseline"):
        place_id = str(row.get("place_id") or "")
        if place_id not in place_ids:
            continue
        if place_id in seen:
            raise ValueError(f"duplicate baseline record for place {place_id}")
        seen.add(place_id)
        record = BaselineRecord.model_validate(row)
        snapshot = selected_sources.get(place_id)
        if snapshot is None:
            raise ValueError(f"missing source snapshot for place {place_id}")
        if snapshot.baseline_input_hash != record.input_hash:
            raise ValueError(f"source snapshot hash mismatch for place {place_id}")
        yield record, snapshot, normalize_names(record, snapshot)

    missing = place_ids.difference(seen)
    if missing:
        raise ValueError("worker place IDs are absent from the baseline")


async def _generate_selected_worker(
    store: ArtifactStore,
    place_ids: set[str],
    *,
    max_places: int,
    budget: BudgetCaps,
    budget_state: BudgetState,
) -> tuple[int, BudgetState]:
    async with DeepSeekClient(
        api_key=_required_environment("DEEPSEEK_API_KEY"),
        model=_required_environment("DEEPSEEK_CONTENT_MODEL"),
        budget=budget,
        budget_state=budget_state,
    ) as provider:
        count = await generate_worker(
            _load_generation_items(store, place_ids),
            store,
            provider,
            max_places=max_places,
        )
        return count, provider.state


def _run_generate(args: argparse.Namespace, parser: argparse.ArgumentParser) -> int:
    if not args.confirm_provider:
        parser.error("generate requires --confirm-provider")

    store = ArtifactStore(_artifact_root(), args.run_id)
    if not store.path("baseline").exists() or not store.path("sources").exists():
        parser.error("generate requires baseline.jsonl and sources.jsonl artifacts")
    manifest = _load_manifest(store, args.run_id)

    if args.worker_place_ids is None:
        if _failed_generation_worker_exists(store):
            raise WorkerFailure(
                "a generation worker failed; reconcile its status before retrying"
            )
        selected_order = _selected_generation_place_ids(args, parser, manifest, store)
        selected_ids = set(selected_order)
        baseline_hashes = _baseline_input_hashes(store, selected_ids)
        completed_hashes = _completed_generation_hashes(store)
        pending = tuple(
            place_id
            for place_id in selected_order
            if completed_hashes.get(place_id) != baseline_hashes[place_id]
        )
        if not pending:
            return 0

        _required_environment("DEEPSEEK_API_KEY")
        _required_environment("DEEPSEEK_CONTENT_MODEL")
        budget = _provider_budget_from_environment()
        initial_state = _budget_state_from_proposals(store)
        _ensure_generation_batch_fits_budget(store, pending, initial_state, budget)

        supervisor = ChunkSupervisor(store)
        supervisor.run_serial(
            pending,
            args.worker_chunk_size,
            lambda chunk, status_path: (
                sys.executable,
                "-m",
                "scripts.place_content_backfill.cli",
                "generate",
                "--run-id",
                args.run_id,
                "--confirm-provider",
                "--worker-chunk-size",
                str(args.worker_chunk_size),
                "--worker-status-path",
                str(status_path),
                "--worker-place-ids",
                *chunk,
            ),
        )
        final_hashes = _completed_generation_hashes(store)
        incomplete = [
            place_id
            for place_id in selected_order
            if final_hashes.get(place_id) != baseline_hashes[place_id]
        ]
        if incomplete:
            raise WorkerFailure(
                "generation workers exited without checkpointing every selected place"
            )
        return 0

    if len(args.worker_place_ids) > args.worker_chunk_size:
        parser.error("worker place ID list exceeds --worker-chunk-size")
    if len(set(args.worker_place_ids)) != len(args.worker_place_ids):
        parser.error("worker place ID list contains duplicates")
    if not set(args.worker_place_ids).issubset(set(manifest.place_ids)):
        parser.error("worker place ID list is outside the manifest")
    budget = _provider_budget_from_environment()
    initial_state = _budget_state_from_proposals(store)
    selected = {str(place_id) for place_id in args.worker_place_ids}
    try:
        processed, final_state = asyncio.run(
            _generate_selected_worker(
                store,
                selected,
                max_places=args.worker_chunk_size,
                budget=budget,
                budget_state=initial_state,
            )
        )
    except Exception as exc:
        _write_worker_status(
            args.worker_status_path,
            {
                "command": "generate",
                "ok": False,
                "error_type": type(exc).__name__,
                "place_ids": sorted(selected),
                "budget": _budget_status(initial_state),
            },
        )
        raise
    _write_worker_status(
        args.worker_status_path,
        {
            "command": "generate",
            "ok": True,
            "place_count": processed,
            "place_ids": sorted(selected),
            "budget": _budget_status(final_state),
        },
    )
    return 0


def _latest_proposals(
    store: ArtifactStore,
    selected_ids: set[str],
) -> dict[str, Proposal]:
    proposals: dict[str, Proposal] = {}
    for row in store.iter_stream("proposals"):
        payload = row.get("proposal", row)
        if not isinstance(payload, dict):
            raise ValueError("proposal artifact payload is invalid")
        place_id = str(payload.get("place_id") or row.get("place_id") or "")
        if place_id in selected_ids:
            proposals[place_id] = Proposal.model_validate(payload)
    return proposals


def _latest_validations(store: ArtifactStore) -> dict[str, dict[str, Any]]:
    latest: dict[str, dict[str, Any]] = {}
    for row in store.iter_stream("validations"):
        place_id = str(row.get("place_id") or "")
        if place_id:
            latest[place_id] = row
    return latest


def _load_validation_items(
    store: ArtifactStore,
    selected_ids: set[str],
) -> list[tuple[Proposal, BaselineRecord, SourceSnapshot]]:
    proposals = _latest_proposals(store, selected_ids)
    baselines: dict[str, BaselineRecord] = {}
    for row in store.iter_stream("baseline"):
        place_id = str(row.get("place_id") or "")
        if place_id in selected_ids:
            baselines[place_id] = BaselineRecord.model_validate(row)
    sources: dict[str, SourceSnapshot] = {}
    for row in store.iter_stream("sources"):
        place_id = str(row.get("place_id") or "")
        if place_id in selected_ids:
            sources[place_id] = SourceSnapshot.model_validate(row)
    missing = selected_ids.difference(proposals) | selected_ids.difference(baselines) | selected_ids.difference(sources)
    if missing:
        raise ValueError("validation input is incomplete for selected places")
    return [
        (proposals[place_id], baselines[place_id], sources[place_id])
        for place_id in sorted(selected_ids)
    ]


def _rebuild_validation_outputs(store: ArtifactStore, selected_ids: set[str]) -> None:
    items = _load_validation_items(store, selected_ids)
    latest = _latest_validations(store)
    if selected_ids.difference(latest):
        raise ValueError("validation output is incomplete for selected places")
    proposals_by_id = {proposal.place_id: proposal for proposal, _, _ in items}
    with tempfile.TemporaryDirectory(prefix=".validation-", dir=store.run_dir) as directory:
        duplicate_map = find_near_duplicates_stream(
            (
                (
                    proposal.place_id,
                    " ".join(
                        (
                            proposal.name_decision.en_name,
                            proposal.generated.vi_short,
                            proposal.generated.en_short,
                            proposal.generated.vi_long,
                            proposal.generated.en_long,
                        )
                    ),
                )
                for proposal in proposals_by_id.values()
            ),
            sqlite_path=Path(directory) / "signatures.sqlite3",
        )
    validation_by_id: dict[str, Any] = {}
    for place_id in selected_ids:
        validation = ValidationResult.model_validate(latest[place_id])
        duplicates = duplicate_map.get(place_id, ())
        if duplicates:
            validation = validation.model_copy(
                update={
                    "passed": False,
                    "errors": tuple(
                        dict.fromkeys((*validation.errors, "near-duplicate-content"))
                    ),
                    "near_duplicate_place_ids": tuple(duplicates),
                }
            )
        validation_by_id[place_id] = validation
    decisions = (
        ReviewDecision.model_validate(row)
        for row in store.iter_stream("review-decisions")
    )
    rebuild_review_artifacts(
        store,
        (
            (proposal, validation_by_id[proposal.place_id], baseline, sources)
            for proposal, baseline, sources in items
        ),
        decisions=decisions,
    )


def _run_validate(args: argparse.Namespace, parser: argparse.ArgumentParser) -> int:
    store = ArtifactStore(_artifact_root(), args.run_id)
    if not store.path("baseline").exists() or not store.path("sources").exists():
        parser.error("validate requires baseline.jsonl and sources.jsonl artifacts")
    manifest = _load_manifest(store, args.run_id)

    if args.worker_place_ids is not None:
        if len(args.worker_place_ids) > args.worker_chunk_size:
            parser.error("worker place ID list exceeds --worker-chunk-size")
        if len(set(args.worker_place_ids)) != len(args.worker_place_ids):
            parser.error("worker place ID list contains duplicates")
        selected = set(args.worker_place_ids)
        if not selected.issubset(set(manifest.place_ids)):
            parser.error("worker place ID list is outside the manifest")
        count = validate_worker(
            _load_validation_items(store, selected),
            store,
            max_places=args.worker_chunk_size,
        )
        _rebuild_validation_outputs(store, selected)
        _write_worker_status(
            args.worker_status_path,
            {
                "command": "validate",
                "place_count": count,
                "place_ids": sorted(selected),
            },
        )
        return 0

    selected_order = _selected_generation_place_ids(args, parser, manifest, store)
    selected = set(selected_order)
    proposals = _latest_proposals(store, selected)
    if selected.difference(proposals):
        parser.error("validate requires proposals for every selected place")
    latest_validation = _latest_validations(store)
    pending = tuple(
        place_id
        for place_id in selected_order
        if latest_validation.get(place_id, {}).get("proposal_hash")
        != proposals[place_id].proposal_hash
    )
    if pending:
        supervisor = ChunkSupervisor(store)
        supervisor.run_serial(
            pending,
            args.worker_chunk_size,
            lambda chunk, status_path: (
                sys.executable,
                "-m",
                "scripts.place_content_backfill.cli",
                "validate",
                "--run-id",
                args.run_id,
                "--worker-chunk-size",
                str(args.worker_chunk_size),
                "--worker-status-path",
                str(status_path),
                "--worker-place-ids",
                *chunk,
            ),
        )
    _rebuild_validation_outputs(store, selected)
    return 0


def _run_status(args: argparse.Namespace, parser: argparse.ArgumentParser) -> int:
    store = ArtifactStore(_artifact_root(), args.run_id)
    manifest = _load_manifest(store, args.run_id)

    def count_stream(stream: str) -> int:
        return sum(1 for _ in store.iter_stream(stream))

    review_count = sum(1 for _ in store.iter_review_csv())
    budget = _budget_state_from_proposals(store)
    print(f"run_id={manifest.run_id}")
    print(f"scope={manifest.scope_name}")
    print(f"expected_total={manifest.expected_total}")
    print(f"baseline={count_stream('baseline')}")
    print(f"sources={count_stream('sources')}")
    print(f"proposals={count_stream('proposals')}")
    print(f"validations={count_stream('validations')}")
    print(f"approved={count_stream('approved')}")
    print(f"review_rows={review_count}")
    print(f"review_decisions={count_stream('review-decisions')}")
    print(f"request_count={budget.request_count}")
    print(f"request_attempts={budget.request_attempts}")
    print(f"input_tokens={budget.input_tokens}")
    print(f"output_tokens={budget.output_tokens}")
    print(f"estimated_cost_usd={budget.estimated_cost_usd:.8f}")
    return 0


def main(argv: Sequence[str] | None = None, *, client: Any | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    _require_confirmation(parser, args)
    if getattr(args, "worker_chunk_size", 1) <= 0:
        parser.error("--worker-chunk-size must be positive")
    if args.command == "audit":
        if client is None:
            parser.error("audit requires an explicitly injected read-only Supabase client")
        run_id = args.run_id or new_run_id()
        store = ArtifactStore(_artifact_root(), run_id)
        audit_scope(client, artifact_store=store, run_id=run_id)
        return 0
    if args.command == "collect":
        return _run_collect(args, parser)
    if args.command == "generate":
        return _run_generate(args, parser)
    if args.command == "validate":
        return _run_validate(args, parser)
    if args.command == "status":
        return _run_status(args, parser)
    if args.command == "review-import":
        store = ArtifactStore(_artifact_root(), args.run_id)
        import_review_csv(
            store,
            args.file,
            validate_edit=lambda place_id, fields: _validate_review_edit_from_artifacts(
                store,
                place_id,
                dict(fields),
            ),
        )
        return 0
    if args.command in {"apply", "rollback"}:
        parser.error(
            f"{args.command} is owner-approved only; Phase A does not create a database connection"
        )
    # Task-specific command implementations are layered onto this safe parser
    # by later phases. Keeping this fallback side-effect free prevents a parser
    # smoke test from opening a database connection.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
