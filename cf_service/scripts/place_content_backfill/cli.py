"""Command-line entry point with destructive-command confirmation gates."""

from __future__ import annotations

import argparse
from typing import Sequence


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="place-content-backfill")
    commands = parser.add_subparsers(dest="command", required=True)

    audit = commands.add_parser("audit")
    audit.add_argument("--scope", default="approved-five")

    for name in ("collect", "generate", "validate", "status"):
        command = commands.add_parser(name)
        command.add_argument("--run-id", required=True)

    apply = commands.add_parser("apply")
    apply.add_argument("--run-id", required=True)
    apply.add_argument("--confirm", action="store_true")
    apply.add_argument("--pilot", action="store_true")

    rollback = commands.add_parser("rollback")
    rollback.add_argument("--run-id", required=True)
    rollback.add_argument("--confirm", action="store_true")
    rollback.add_argument("--pilot", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command in {"apply", "rollback"} and not args.confirm:
        parser.error(f"{args.command} requires --confirm")
    # Later tasks attach the database-backed handlers. Keeping this shell
    # side-effect free makes argument/safety tests independent of credentials.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
