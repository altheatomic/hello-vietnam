from __future__ import annotations

import argparse
import asyncio
import json
import os
from pathlib import Path
import sys
from typing import Any, Sequence

from .constants import (
    DEFAULT_COLLECT_WORKER_CHUNK_SIZE,
    DEFAULT_GENERATE_WORKER_CHUNK_SIZE,
    DEFAULT_VALIDATE_WORKER_CHUNK_SIZE,
    new_run_id,
)
from .artifacts import ArtifactStore, ChunkSupervisor
from .repository import audit_scope
from .models import BaselineRecord
from .sources import collect_worker


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


def _load_selected_baseline(store: ArtifactStore, place_ids: set[str]):
    for row in store.iter_stream("baseline"):
        if str(row.get("place_id")) in place_ids:
            yield BaselineRecord.model_validate(row)


def _run_collect(args: argparse.Namespace, parser: argparse.ArgumentParser) -> int:
    root = Path(".artifacts/place-content")
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
        store = ArtifactStore(Path(".artifacts/place-content"), run_id)
        audit_scope(client, artifact_store=store, run_id=run_id)
        return 0
    if args.command == "collect":
        return _run_collect(args, parser)
    # Task-specific command implementations are layered onto this safe parser
    # by later phases. Keeping this fallback side-effect free prevents a parser
    # smoke test from opening a database connection.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
