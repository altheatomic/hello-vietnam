"""Reproducible, network-free benchmark for the trip-planner algorithm stages.

This intentionally does not benchmark Supabase or the Edge Function.  It measures
the CPU path that starts after candidate scoring/diversity has produced top_places.
"""

from __future__ import annotations

import argparse
import csv
import gc
import math
import random
import statistics
import sys
import time
import tracemalloc
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from services.module2_algorithm import (  # noqa: E402
    add_day_warnings,
    build_initial_day_clusters,
    build_module2_result,
    cluster_places_by_day,
    compute_high_rank_threshold,
    prepare_module2_candidates,
    try_fill_underfilled_days,
    try_fix_overfilled_or_overloaded_days,
)
from services.module3_optimizer import greedy_route, optimize_day_route  # noqa: E402
from services.schedule_builder import build_day_schedule  # noqa: E402


def make_places(n: int, seed: int = 42) -> list[dict]:
    rng = random.Random(seed)
    places = []
    for i in range(n):
        angle = 2 * math.pi * i / max(n, 1)
        places.append(
            {
                "id_place": f"p{i}",
                "name": f"Place {i}",
                "latitude": 16.0 + 0.08 * math.sin(angle) + rng.uniform(-0.002, 0.002),
                "longitude": 108.0 + 0.10 * math.cos(angle) + rng.uniform(-0.002, 0.002),
                "module1_score": 1.0 - i / max(n, 1),
                "estimated_duration_minutes": 60 + 30 * (i % 3),
                "average_rating": 3.5 + 1.5 * rng.random(),
                "review_count": 10 + i,
                "timespan": "08:00",
                "timeclose": "20:00",
                "place_subcategory": {
                    "name": "Cảnh quan",
                    "place_category": "Tham quan",
                    "is_itinerary_eligible": True,
                },
                "is_itinerary_eligible": True,
            }
        )
    return places


def percentile95(values: list[float]) -> float:
    ordered = sorted(values)
    return ordered[math.ceil(0.95 * len(ordered)) - 1]


def measure(fn, runs: int, warmups: int) -> tuple[dict[str, float], object]:
    for _ in range(warmups):
        fn()
    times_ms: list[float] = []
    peaks_kib: list[float] = []
    result = None
    for _ in range(runs):
        gc.collect()
        tracemalloc.start()
        started = time.perf_counter_ns()
        result = fn()
        elapsed_ms = (time.perf_counter_ns() - started) / 1_000_000
        _, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        times_ms.append(elapsed_ms)
        peaks_kib.append(peak / 1024)
    return {
        "median_ms": statistics.median(times_ms),
        "mean_ms": statistics.mean(times_ms),
        "p95_ms": percentile95(times_ms),
        "std_ms": statistics.pstdev(times_ms),
        "peak_kib": max(peaks_kib),
    }, result


def repair_only(prepared: tuple, start_date: str) -> dict:
    candidates, _, limits, clustered, labels, days = prepared
    day_clusters, backup = build_initial_day_clusters(
        clustered, labels, days, start_date, limits
    )
    optional: list[dict] = []
    logs: list[dict] = []
    threshold = compute_high_rank_threshold(candidates)
    for _ in range(10):
        changed = try_fill_underfilled_days(day_clusters, backup, limits, logs)
        changed = try_fix_overfilled_or_overloaded_days(
            day_clusters, backup, optional, limits, threshold, logs
        ) or changed
        if not changed:
            break
    add_day_warnings(day_clusters, limits)
    return {"day_clusters": day_clusters, "repair_logs": logs}


def benchmark_case(n: int, days: int, runs: int, warmups: int) -> list[dict]:
    places = make_places(n)
    start_date = "2026-08-01"
    end_date = f"2026-08-{days:02d}"

    rows: list[dict] = []

    def record(stage: str, fn):
        stats, result = measure(fn, runs, warmups)
        rows.append({"n": n, "days": days, "stage": stage, **stats})
        return result

    prep = record(
        "prepare",
        lambda: prepare_module2_candidates(places, days, "balanced"),
    )
    candidates, _, limits = prep
    clustered_result = record(
        "kmeans",
        lambda: cluster_places_by_day(candidates, days),
    )
    clustered, labels = clustered_result
    prepared = (candidates, None, limits, clustered, labels, days)
    repaired = record("greedy_repair", lambda: repair_only(prepared, start_date))

    start = {"latitude": 16.0, "longitude": 108.0}
    route_places = repaired["day_clusters"][0]["places"]
    route = record("greedy_nn", lambda: greedy_route(start, route_places))
    best_route, _ = record(
        "simulated_annealing",
        lambda: optimize_day_route(start, route_places, sa_runs=2),
    )
    record("detailed_schedule", lambda: build_day_schedule([dict(p) for p in best_route], start))

    def cpu_pipeline():
        m2 = build_module2_result(places, start_date, end_date, "balanced")
        current = start
        schedules = []
        for day in m2["day_clusters"]:
            best, schedule = optimize_day_route(current, day["places"], sa_runs=2)
            schedules.append(schedule)
            if best:
                current = best[-1]
        return schedules

    record("total_cpu_pipeline", cpu_pipeline)
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sizes", default="10,20,50,100,200")
    parser.add_argument("--runs", type=int, default=30)
    parser.add_argument("--warmups", type=int, default=3)
    parser.add_argument("--output", default=str(ROOT / "trip_planner_audit_benchmark.csv"))
    args = parser.parse_args()
    if args.runs < 30:
        parser.error("--runs must be at least 30")

    all_rows = []
    for n in (int(value) for value in args.sizes.split(",")):
        # Candidate capacity is 8/day in production; this keeps every n observable.
        days = max(1, math.ceil(n / 8))
        all_rows.extend(benchmark_case(n, days, args.runs, args.warmups))

    output = Path(args.output)
    with output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=all_rows[0].keys())
        writer.writeheader()
        writer.writerows(all_rows)

    print(f"Wrote {len(all_rows)} rows to {output}")
    for row in all_rows:
        print(
            f"n={row['n']:>3} d={row['days']:>2} {row['stage']:<20} "
            f"median={row['median_ms']:>9.3f} ms p95={row['p95_ms']:>9.3f} ms "
            f"peak={row['peak_kib']:>9.1f} KiB"
        )


if __name__ == "__main__":
    main()
