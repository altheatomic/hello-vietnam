from __future__ import annotations

import argparse
from pathlib import Path
from typing import Sequence

from .constants import (
    DEFAULT_COLLECT_WORKER_CHUNK_SIZE,
    DEFAULT_GENERATE_WORKER_CHUNK_SIZE,
    DEFAULT_VALIDATE_WORKER_CHUNK_SIZE,
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


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    _require_confirmation(parser, args)
    if getattr(args, "worker_chunk_size", 1) <= 0:
        parser.error("--worker-chunk-size must be positive")
    # Task-specific command implementations are layered onto this safe parser
    # by later phases. Keeping this fallback side-effect free prevents a parser
    # smoke test from opening a database connection.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
