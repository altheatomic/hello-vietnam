"""Command-line entry point with destructive-command confirmation gates."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
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
    if args.command == "audit":
        if args.scope != "approved-five":
            parser.error("only --scope approved-five is supported")
        from db.supabase_client import get_supabase_client

        from .constants import APPROVED_PROVINCES, PROVINCE_EXPECTED_COUNTS
        from .repository import audit_scope

        root = Path(
            os.environ.get(
                "PLACE_CONTENT_ARTIFACT_ROOT",
                str(Path.cwd() / ".artifacts" / "place-content"),
            )
        )
        manifest, records = audit_scope(
            get_supabase_client(),
            str(root),
            province_ids=APPROVED_PROVINCES,
        )
        counts = {province_id: 0 for province_id in APPROVED_PROVINCES}
        for record in records:
            counts[record.province_id] += 1
        print(
            json.dumps(
                {
                    "run_id": manifest.run_id,
                    "total": len(records),
                    "province_counts": counts,
                    "expected_total": sum(PROVINCE_EXPECTED_COUNTS.values()),
                    "outside_scope": 0,
                },
                separators=(",", ":"),
            )
        )
        return 0
    # Later tasks attach the remaining handlers. Keeping those commands
    # side-effect free makes argument/safety tests independent of credentials.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
