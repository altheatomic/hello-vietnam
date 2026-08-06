"""
test_performance_eval.py
End-to-end performance measurement for TripPlannerService.plan() — capstone
report section 4.3 (performance evaluation).

Calls the Python pipeline DIRECTLY (no HTTP/edge-function/tunnel hop), so
numbers reflect pure server-side compute + DB round-trip time — matching
the earlier perf audit's own methodology (avoids network/tunnel noise).

Requires a working .env (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY) — same
as running cf_service normally. Talks to the real database; every run
computes and DOES NOT save a plan (save_plan=False) so repeated runs don't
pollute the `plan`/`plan_component` tables.

Usage:
    python test_performance_eval.py
    python test_performance_eval.py --repeats 5 --out results.csv

Writes a CSV with one row per scenario:
    scenario, repeats_ok, repeats_failed, mean_total_ms, std_total_ms,
    mean_data_fetch_ms, mean_scoring_ms, mean_module2_ms, mean_module3_ms,
    mean_save_plan_ms
"""

import argparse
import asyncio
import csv
import datetime
import statistics
import sys
from dataclasses import dataclass, field

from db.supabase_client import get_supabase_client
from services.trip_planner import TripPlannerService

# ── Fixed test fixtures (real IDs, verified against the live DB) ─────────────

USER_ID = "dd16ba71-c26b-44dd-a3f4-61973f268822"          # control.blank (no history)
PROVINCE_HCM = "230e26ed-0118-4f62-96b5-ac0eb3ca1c1b"      # Hồ Chí Minh — 463 eligible places (large)
PROVINCE_SMALL = "15bd02b9-5895-4570-97c2-3fe929648345"    # Bạc Liêu — 18 eligible places (small)
INTEREST_CULTURE_HISTORY = "24e0f953-f3aa-4b69-9e91-2b3724c086d3"

START_DATE = datetime.date.today() + datetime.timedelta(days=7)

TIMING_GROUPS = [
    "data_fetch", "scoring", "module2_kmeans_repair", "module3_sa_schedule", "save_plan",
]


@dataclass
class ScenarioResult:
    name: str
    totals_ms: list = field(default_factory=list)
    groups_ms: dict = field(default_factory=lambda: {g: [] for g in TIMING_GROUPS})
    failures: int = 0


async def _run_once(
    supabase,
    id_province: str,
    n_days: int,
    interest_option_ids: list[str] | None,
) -> dict | None:
    svc = TripPlannerService(supabase)
    try:
        result = await svc.plan(
            id_user=USER_ID,
            id_province=id_province,
            n_days=n_days,
            start_at=START_DATE,
            sa_runs=2,
            save=False,
            interest_option_ids=interest_option_ids,
        )
    except Exception as exc:  # noqa: BLE001 — record and move on, this is a bench script
        print(f"    [FAIL] {exc}")
        return None
    return result.get("debug", {}).get("timing_ms")


async def _run_scenario(
    supabase,
    name: str,
    id_province: str,
    n_days: int,
    interest_option_ids: list[str] | None,
    repeats: int,
) -> ScenarioResult:
    result = ScenarioResult(name=name)
    print(f"[SCENARIO] {name} (n_days={n_days}, province={id_province}, "
          f"interest={interest_option_ids}) — {repeats} repeats")
    for i in range(repeats):
        timing = await _run_once(supabase, id_province, n_days, interest_option_ids)
        if timing is None:
            result.failures += 1
            continue
        result.totals_ms.append(timing["total"])
        for group in TIMING_GROUPS:
            result.groups_ms[group].append(timing.get(group, 0.0))
        print(f"    run {i + 1}/{repeats}: total={timing['total']}ms")
    return result


def _mean(values: list[float]) -> float:
    return round(statistics.mean(values), 1) if values else float("nan")


def _std(values: list[float]) -> float:
    return round(statistics.stdev(values), 1) if len(values) > 1 else 0.0


def _write_csv(results: list[ScenarioResult], out_path: str) -> None:
    header = (
        ["scenario", "repeats_ok", "repeats_failed", "mean_total_ms", "std_total_ms"]
        + [f"mean_{g}_ms" for g in TIMING_GROUPS]
    )
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        for r in results:
            row = [
                r.name,
                len(r.totals_ms),
                r.failures,
                _mean(r.totals_ms),
                _std(r.totals_ms),
            ] + [_mean(r.groups_ms[g]) for g in TIMING_GROUPS]
            writer.writerow(row)
    print(f"\nWrote {out_path}")


async def main(repeats: int, out_path: str) -> None:
    supabase = get_supabase_client()
    results: list[ScenarioResult] = []

    # ── 1. n_days sweep (same province, same interest) ───────────────────────
    # 10/15/20/30 added to stress-test larger itineraries (still Ho Chi Minh /
    # culture_history / sa_runs=2 / I_multiplier=12 — the latter is
    # module3_optimizer._simulated_annealing's default, unchanged here).
    # Run with `--repeats 3` for these larger values as specified.
    for n_days in (1, 2, 3, 5, 7, 10, 15, 20, 30):
        results.append(await _run_scenario(
            supabase,
            name=f"n_days={n_days}",
            id_province=PROVINCE_HCM,
            n_days=n_days,
            interest_option_ids=[INTEREST_CULTURE_HISTORY],
            repeats=repeats,
        ))

    # ── 2. interest_option_ids present vs absent (n_days=3, same province) ───
    results.append(await _run_scenario(
        supabase,
        name="interest=yes (n_days=3)",
        id_province=PROVINCE_HCM,
        n_days=3,
        interest_option_ids=[INTEREST_CULTURE_HISTORY],
        repeats=repeats,
    ))
    results.append(await _run_scenario(
        supabase,
        name="interest=no (n_days=3)",
        id_province=PROVINCE_HCM,
        n_days=3,
        interest_option_ids=None,
        repeats=repeats,
    ))

    # ── 3. large vs small candidate pool (n_days=3, no interest override) ────
    results.append(await _run_scenario(
        supabase,
        name="province=large (Ho Chi Minh, n_days=3)",
        id_province=PROVINCE_HCM,
        n_days=3,
        interest_option_ids=None,
        repeats=repeats,
    ))
    results.append(await _run_scenario(
        supabase,
        name="province=small (Bac Lieu, n_days=3)",
        id_province=PROVINCE_SMALL,
        n_days=3,
        interest_option_ids=None,
        repeats=repeats,
    ))

    _write_csv(results, out_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repeats", type=int, default=5, help="Repeats per scenario (default: 5)")
    parser.add_argument("--out", type=str, default="performance_eval_results.csv", help="CSV output path")
    args = parser.parse_args()

    if sys.platform == "win32":
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

    asyncio.run(main(args.repeats, args.out))
