"""Command-line entry point with destructive-command confirmation gates."""

from __future__ import annotations

import argparse
import asyncio
import json
import os
from pathlib import Path
from typing import Sequence


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="place-content-backfill")
    commands = parser.add_subparsers(dest="command", required=True)

    audit = commands.add_parser("audit")
    audit.add_argument("--scope", default="approved-five")

    collect = commands.add_parser("collect")
    collect.add_argument("--run-id", required=True)
    collect.add_argument("--include-official-sites", action="store_true")
    collect.add_argument(
        "--baseline-only",
        action="store_true",
        help="skip external source requests and use current baseline fields as evidence",
    )

    generate = commands.add_parser("generate")
    generate.add_argument("--run-id", required=True)
    generate.add_argument("--max-requests", type=int)
    generate.add_argument("--max-input-tokens", type=int)
    generate.add_argument("--max-output-tokens", type=int)
    generate.add_argument("--max-estimated-cost-usd", type=float)

    validate = commands.add_parser("validate")
    validate.add_argument("--run-id", required=True)
    validate.add_argument("--review-csv")

    status = commands.add_parser("status")
    status.add_argument("--run-id", required=True)

    # Keep the command surface explicit; no positional SQL or arbitrary table
    # names are accepted from the operator.

    apply = commands.add_parser("apply")
    apply.add_argument("--run-id", required=True)
    apply.add_argument("--confirm", action="store_true")
    apply.add_argument("--pilot", action="store_true")

    rollback = commands.add_parser("rollback")
    rollback.add_argument("--run-id", required=True)
    rollback.add_argument("--confirm", action="store_true")
    rollback.add_argument("--pilot", action="store_true")
    rollback.add_argument("--place-id", action="append")
    rollback.add_argument("--province-id")
    rollback.add_argument("--batch-id")
    rollback.add_argument("--all", dest="all_entries", action="store_true")
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
    root = Path(
        os.environ.get(
            "PLACE_CONTENT_ARTIFACT_ROOT",
            str(Path.cwd() / ".artifacts" / "place-content"),
        )
    )
    from .artifacts import ArtifactStore

    store = ArtifactStore(root, args.run_id)
    if args.command == "collect":
        result = asyncio.run(
            _collect(
                store,
                include_official_sites=args.include_official_sites,
                include_external_sources=not args.baseline_only,
            )
        )
        print(json.dumps(result, separators=(",", ":")))
        return 0
    if args.command == "generate":
        result = asyncio.run(
            _generate(
                store,
                max_requests=args.max_requests,
                max_input_tokens=args.max_input_tokens,
                max_output_tokens=args.max_output_tokens,
                max_estimated_cost_usd=args.max_estimated_cost_usd,
            )
        )
        print(json.dumps(result, separators=(",", ":")))
        return 0
    if args.command == "validate":
        result = _validate(store, Path(args.review_csv) if args.review_csv else None)
        print(json.dumps(result, separators=(",", ":")))
        return 0
    if args.command == "status":
        print(json.dumps(_status(store), separators=(",", ":")))
        return 0
    if args.command == "apply":
        result = asyncio.run(_apply(store, pilot=args.pilot))
        print(json.dumps(result, separators=(",", ":")))
        return 0
    if args.command == "rollback":
        result = asyncio.run(
            _rollback(
                store,
                pilot=args.pilot,
                place_ids=args.place_id,
                province_id=args.province_id,
                batch_id=args.batch_id,
                all_entries=args.all_entries,
            )
        )
        print(json.dumps(result, separators=(",", ":")))
        return 0
    return 2


def _read_baseline(store):
    from .models import BaselineRecord

    return [BaselineRecord.model_validate(value) for value in store.read_all("baseline")]


def _read_sources(store):
    from .models import SourceSnapshot

    return [SourceSnapshot.model_validate(value) for value in store.read_all("sources")]


async def _collect(
    store,
    *,
    include_official_sites: bool,
    include_external_sources: bool = True,
) -> dict:
    import httpx

    from .sources import collect_source_snapshots

    records = _read_baseline(store)
    completed = store.completed_place_ids("sources")
    pending = [record for record in records if record.place_id not in completed]
    async with httpx.AsyncClient() as client:
        snapshots = await collect_source_snapshots(
            pending,
            client,
            include_official_sites=include_official_sites,
            include_external_sources=include_external_sources,
        )
        collected = len(snapshots)
        warnings = sum(len(snapshot.warnings) for snapshot in snapshots)
        for snapshot in snapshots:
            store.append("sources", snapshot)
    return {"run_id": store.run_id, "collected": collected, "warnings": warnings}


async def _generate(
    store,
    *,
    max_requests: int | None,
    max_input_tokens: int | None,
    max_output_tokens: int | None,
    max_estimated_cost_usd: float | None,
) -> dict:
    from .generator import DeepSeekContentClient, GenerationBudget
    from .models import Proposal
    from .naming import normalize_names
    from .repository import editable_hash

    records = {record.place_id: record for record in _read_baseline(store)}
    source_map = {source.place_id: source for source in _read_sources(store)}
    completed = store.completed_place_ids("proposals")
    budget = GenerationBudget.from_env(
        max_requests=max_requests,
        max_input_tokens=max_input_tokens,
        max_output_tokens=max_output_tokens,
        max_estimated_cost_usd=max_estimated_cost_usd,
    )
    client = DeepSeekContentClient(budget=budget)
    generated = 0
    for place_id, record in records.items():
        if place_id in completed or place_id not in source_map:
            continue
        names = normalize_names(record, source_map[place_id])
        result = await client.generate(record, names, source_map[place_id], editable_hash(record))
        source_urls = tuple(
            fact.source_url
            for fact in source_map[place_id].facts
            if fact.fact_id in result.content.used_fact_ids
        )
        proposal = Proposal(
            place_id=place_id,
            province_id=record.province_id,
            baseline_hash=editable_hash(record),
            current_name_vi=record.vi.name or record.name,
            proposed_name_vi=names.vietnamese_name,
            current_name_en=record.en.name,
            proposed_name_en=names.english_name,
            content=result.content,
            source_fact_ids=result.content.used_fact_ids,
            source_urls=source_urls,
            provider_metadata=result.metadata,
        )
        store.append("proposals", proposal)
        generated += 1
    return {"run_id": store.run_id, "generated": generated, "requests": budget.requests_used}


def _validate(store, review_csv: Path | None) -> dict:
    from .models import Proposal
    from .validators import import_review_csv, validate_proposal

    records = {record.place_id: record for record in _read_baseline(store)}
    sources = {source.place_id: source for source in _read_sources(store)}
    proposals = [Proposal.model_validate(value) for value in store.read_all("proposals")]
    if review_csv is not None:
        proposals = import_review_csv(review_csv, proposals, baselines=records, sources=sources)
    approved = []
    needs_review = []
    for proposal in proposals:
        result = validate_proposal(proposal, records[proposal.place_id], sources[proposal.place_id])
        updated = proposal.model_copy(
            update={
                "validation": result,
                "reviewer_decision": "approve" if result.valid else proposal.reviewer_decision,
            }
        )
        if result.valid:
            approved.append(updated)
        else:
            needs_review.append(updated)
    for proposal in approved:
        store.append("approved", proposal)
    store.write_review_csv(needs_review)
    return {"run_id": store.run_id, "proposals": len(proposals), "approved": len(approved), "needs_review": len(needs_review)}


def _status(store) -> dict:
    manifest = store.read_manifest()
    return {
        "run_id": manifest.run_id,
        "status": manifest.status,
        "baseline": len(store.read_all("baseline")),
        "sources": len(store.read_all("sources")),
        "proposals": len(store.read_all("proposals")),
        "approved": len(store.read_all("approved")),
        "applied": len(store.read_all("applied")),
        "rollback_events": len(store.read_all("rollback")),
    }


async def _apply(store, *, pilot: bool) -> dict:
    import asyncpg

    from .models import Proposal
    from .repository import apply_approved_batch

    approved = [Proposal.model_validate(value) for value in store.read_all("approved")]
    if pilot:
        approved = approved[:100]
    if not approved:
        raise ValueError("no approved proposals to apply")
    records = {record.place_id: record for record in _read_baseline(store)}
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        raise ValueError("DATABASE_URL is required for apply")
    conn = await asyncpg.connect(database_url)
    batches = []
    try:
        for start in range(0, len(approved), 50):
            result = await apply_approved_batch(
                conn,
                approved[start : start + 50],
                records,
                artifact_store=store,
                confirm=True,
            )
            batches.append(result.batch_id)
    finally:
        await conn.close()
    return {"run_id": store.run_id, "applied": len(approved), "batches": batches, "pilot": pilot}


async def _rollback(store, *, pilot, place_ids, province_id, batch_id, all_entries):
    import asyncpg

    from .repository import rollback_applied_batch

    # The rollback stream also records post-restore audit events.  Only the
    # original entries carry a ``prior`` payload and are actionable.
    entries = [entry for entry in store.read_all("rollback") if "prior" in entry]
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        raise ValueError("DATABASE_URL is required for rollback")
    conn = await asyncpg.connect(database_url)
    try:
        restored = await rollback_applied_batch(
            conn,
            entries,
            artifact_store=store,
            confirm=True,
            place_ids=place_ids,
            province_id=province_id,
            batch_id=batch_id,
            all_entries=all_entries or pilot,
        )
    finally:
        await conn.close()
    return {"run_id": store.run_id, "restored": len(restored), "place_ids": list(restored)}


if __name__ == "__main__":
    raise SystemExit(main())
