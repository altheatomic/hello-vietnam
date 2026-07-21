"""
test_module3_benchmark.py
Module 3 benchmark — Simulated Annealing (current: sa_runs=2, I_multiplier=12,
tuned in the earlier perf-optimization pass) vs. a Greedy Nearest-Neighbor-only
baseline (no SA refinement) — capstone report section 4.4.

Design (as specified):
  For each n in [4, 6, 8, 10, 12]:
    - Draw 10 random subsets of n real places from the same province (Ho Chi
      Minh — large enough candidate pool), restricted to places that actually
      have latitude/longitude/timespan/estimated_duration_minutes all present
      (a clean, comparable test bed — not a pipeline requirement, since
      route_cost_with_schedule() itself tolerates missing timespan/duration
      via defaults).
    - Baseline: greedy_route() only (no SA), scored with the same
      route_cost_with_schedule() the real pipeline uses. Deterministic —
      run once per subset.
    - SA: full optimize_day_route() (greedy init + SA), current tuned params
      (sa_runs=2, I_multiplier=12, hardcoded in module3_optimizer.py — this
      script does not override them, it measures the live pipeline). Run 10
      times per subset (SA has randomness) to get mean/std.
  Total: 5 x 10 = 50 baseline runs, 5 x 10 x 10 = 500 SA runs.

Also measures pure travel time (sum of haversine-based travel legs between
consecutive stops only — no wait/lunch/violation/drop penalty) for both,
per the report's "total travel distance/time" requirement.

Requires a working .env (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY). Read-only.

Usage:
    python test_module3_benchmark.py
    python test_module3_benchmark.py --out module3_benchmark_results.csv
"""

import argparse
import csv
import random
import statistics

from db.supabase_client import get_supabase_client
from db.place_repository import fetch_places_required_filter
from services.module3_optimizer import greedy_route, haversine_km, optimize_day_route
from services.schedule_builder import route_cost_with_schedule

PROVINCE_HCM = "230e26ed-0118-4f62-96b5-ac0eb3ca1c1b"  # Ho Chi Minh — large candidate pool
N_VALUES = [4, 6, 8, 10, 12]
DRAWS_PER_N = 10
SA_REPEATS_PER_DRAW = 10
AVG_SPEED_KMH = 30.0  # matches services/schedule_builder.py's _AVG_SPEED_KMH


def _derive_start_point(places: list[dict]) -> dict:
    avg_lat = sum(float(p["latitude"]) for p in places) / len(places)
    avg_lon = sum(float(p["longitude"]) for p in places) / len(places)
    return {"latitude": avg_lat, "longitude": avg_lon}


def _travel_minutes_only(route: list[dict], start: dict) -> float:
    """Sum of haversine-based travel legs between consecutive stops only —
    no wait/lunch/violation/drop penalty, per the report's 'pure travel
    time' requirement."""
    if not route:
        return 0.0
    total_km = haversine_km(
        start["latitude"], start["longitude"], route[0]["latitude"], route[0]["longitude"]
    )
    for i in range(len(route) - 1):
        total_km += haversine_km(
            route[i]["latitude"], route[i]["longitude"],
            route[i + 1]["latitude"], route[i + 1]["longitude"],
        )
    return total_km / AVG_SPEED_KMH * 60


def _has_complete_fields(place: dict) -> bool:
    return (
        place.get("latitude") is not None
        and place.get("longitude") is not None
        and place.get("timespan")
        and place.get("estimated_duration_minutes") is not None
    )


def fetch_benchmark_pool(supabase) -> list[dict]:
    places = fetch_places_required_filter(supabase, PROVINCE_HCM)
    complete = [p for p in places if _has_complete_fields(p)]
    print(f"[POOL] Ho Chi Minh: {len(places)} eligible places total, "
          f"{len(complete)} with complete lat/lng/timespan/duration fields")
    if len(complete) < max(N_VALUES):
        raise RuntimeError(
            f"Only {len(complete)} places have complete fields — need at least "
            f"{max(N_VALUES)} for the n=12 scenario. Relax the field-completeness "
            f"filter or pick a different province."
        )
    return complete


def run_one_draw(pool: list[dict], n: int, draw_id: int) -> dict:
    rng = random.Random(n * 1000 + draw_id)  # reproducible across reruns
    subset = rng.sample(pool, n)
    start = _derive_start_point(subset)

    # ── Baseline: greedy only, deterministic, 1 run ───────────────────────────
    baseline_route = greedy_route(start, subset)
    baseline_cost = route_cost_with_schedule(baseline_route, start)
    baseline_travel_min = _travel_minutes_only(baseline_route, start)

    # ── SA: full optimize_day_route(), repeated for mean/std (SA is random) ──
    sa_costs = []
    sa_travel_mins = []
    for _ in range(SA_REPEATS_PER_DRAW):
        best_route, _schedule_result = optimize_day_route(start, subset)
        sa_costs.append(route_cost_with_schedule(best_route, start))
        sa_travel_mins.append(_travel_minutes_only(best_route, start))

    sa_mean_cost = statistics.mean(sa_costs)
    sa_std_cost = statistics.stdev(sa_costs) if len(sa_costs) > 1 else 0.0
    improvement_percent = (
        round(100 * (baseline_cost - sa_mean_cost) / baseline_cost, 2)
        if baseline_cost > 0 else float("nan")
    )

    return {
        "n": n,
        "draw_id": draw_id,
        "baseline_cost": round(baseline_cost, 2),
        "sa_mean_cost": round(sa_mean_cost, 2),
        "sa_std_cost": round(sa_std_cost, 2),
        "improvement_percent": improvement_percent,
        "baseline_travel_min": round(baseline_travel_min, 2),
        "sa_mean_travel_min": round(statistics.mean(sa_travel_mins), 2),
        "sa_std_travel_min": round(
            statistics.stdev(sa_travel_mins) if len(sa_travel_mins) > 1 else 0.0, 2
        ),
    }


def main(out_path: str) -> None:
    supabase = get_supabase_client()
    pool = fetch_benchmark_pool(supabase)

    rows = []
    for n in N_VALUES:
        print(f"\n[n={n}] {DRAWS_PER_N} draws x (1 baseline + {SA_REPEATS_PER_DRAW} SA runs)")
        for draw_id in range(DRAWS_PER_N):
            row = run_one_draw(pool, n, draw_id)
            rows.append(row)
            print(
                f"    draw {draw_id}: baseline={row['baseline_cost']} "
                f"sa_mean={row['sa_mean_cost']} (+-{row['sa_std_cost']}) "
                f"improvement={row['improvement_percent']}% "
                f"travel(baseline/sa)={row['baseline_travel_min']}/{row['sa_mean_travel_min']} min"
            )

    header = [
        "n", "draw_id", "baseline_cost", "sa_mean_cost", "sa_std_cost", "improvement_percent",
        "baseline_travel_min", "sa_mean_travel_min", "sa_std_travel_min",
    ]
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=header)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
    print(f"\nWrote {len(rows)} rows to {out_path} "
          f"({len(N_VALUES)} n-values x {DRAWS_PER_N} draws = "
          f"{len(N_VALUES) * DRAWS_PER_N} baseline runs, "
          f"{len(N_VALUES) * DRAWS_PER_N * SA_REPEATS_PER_DRAW} SA runs)")

    print("\n--- Summary (mean improvement_percent by n) ---")
    for n in N_VALUES:
        n_rows = [r for r in rows if r["n"] == n]
        mean_improvement = statistics.mean(r["improvement_percent"] for r in n_rows)
        print(f"n={n}: mean improvement = {round(mean_improvement, 2)}%")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=str, default="module3_benchmark_results.csv", help="CSV output path")
    args = parser.parse_args()
    main(args.out)
