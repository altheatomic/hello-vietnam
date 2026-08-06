import math
import statistics
import sys
import time
import tracemalloc
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from services.module2_algorithm import build_module2_result
from services.module3_optimizer import greedy_route, optimize_day_route
from services.schedule_builder import build_day_schedule


def make_place(i, lat, lng, score, duration=90):
    return {
        "id_place": f"p{i}",
        "name": f"Place {i}",
        "latitude": lat,
        "longitude": lng,
        "module1_score": score,
        "estimated_duration_minutes": duration,
        "average_rating": 4.2,
        "review_count": 100,
        "place_subcategory": {
            "name": "Cảnh quan",
            "place_category": "Tham quan",
            "is_itinerary_eligible": True,
        },
        "short_description": "",
        "is_itinerary_eligible": True,
    }


def make_top_places(n, days):
    places = []
    for i in range(n):
        angle = (i / max(1, n)) * 2 * math.pi
        lat = 16.0 + 0.02 * math.sin(angle)
        lng = 108.0 + 0.03 * math.cos(angle)
        score = 0.8 - (i % 10) * 0.01
        places.append(make_place(i, lat, lng, score))
    return places


def run_once(label, fn, *args, **kwargs):
    tracemalloc.start()
    t0 = time.perf_counter()
    result = fn(*args, **kwargs)
    dt = time.perf_counter() - t0
    current, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    return dt, peak, result


def summarize(samples):
    if not samples:
        return {"mean": 0.0, "median": 0.0, "p95": 0.0, "std": 0.0}
    sorted_samples = sorted(samples)
    p95_idx = max(0, min(len(sorted_samples) - 1, int(round(0.95 * (len(sorted_samples) - 1)))))
    return {
        "mean": statistics.mean(samples),
        "median": statistics.median(samples),
        "p95": sorted_samples[p95_idx],
        "std": statistics.pstdev(samples) if len(samples) > 1 else 0.0,
    }


def benchmark_case(n, days, runs=30):
    top_places = make_top_places(n, days)
    start_date = "2026-08-01"
    end_date = f"2026-08-{int(start_date[-2:]) + days - 1:02d}"

    warmup = 3
    for _ in range(warmup):
        build_module2_result(top_places, start_date, end_date, pace_level="balanced")

    m2_times = []
    m2_mem = []
    for _ in range(runs):
        dt, peak, _ = run_once("m2", build_module2_result, top_places, start_date, end_date, "balanced")
        m2_times.append(dt)
        m2_mem.append(peak)

    m2_result = build_module2_result(top_places, start_date, end_date, pace_level="balanced")
    day_clusters = m2_result["day_clusters"]
    route_places = day_clusters[0]["places"] if day_clusters else []

    greedy_times = []
    greedy_mem = []
    for _ in range(runs):
        start_point = {"latitude": 16.0, "longitude": 108.0}
        dt, peak, _ = run_once("greedy", greedy_route, start_point, route_places)
        greedy_times.append(dt)
        greedy_mem.append(peak)

    sa_times = []
    sa_mem = []
    for _ in range(runs):
        start_point = {"latitude": 16.0, "longitude": 108.0}
        dt, peak, _ = run_once("sa", optimize_day_route, start_point, route_places, sa_runs=2)
        sa_times.append(dt)
        sa_mem.append(peak)

    schedule_times = []
    schedule_mem = []
    for _ in range(runs):
        start_point = {"latitude": 16.0, "longitude": 108.0}
        best_route, _ = optimize_day_route(start_point, route_places, sa_runs=2)
        dt, peak, _ = run_once("schedule", build_day_schedule, best_route, start_point)
        schedule_times.append(dt)
        schedule_mem.append(peak)

    return {
        "n": n,
        "days": days,
        "module2": {"times": m2_times, "mem": m2_mem, "summary": summarize(m2_times)},
        "greedy": {"times": greedy_times, "mem": greedy_mem, "summary": summarize(greedy_times)},
        "sa": {"times": sa_times, "mem": sa_mem, "summary": summarize(sa_times)},
        "schedule": {"times": schedule_times, "mem": schedule_mem, "summary": summarize(schedule_times)},
    }


if __name__ == "__main__":
    sizes = [10, 20, 50, 100, 200]
    print("Trip planner CPU benchmark (synthetic data, no DB/network)")
    print("n | days | stage | median_ms | mean_ms | p95_ms | std_ms | peak_kb")
    for n in sizes:
        days = 2 if n <= 20 else 3 if n <= 100 else 4
        result = benchmark_case(n, days, runs=20)
        for stage in ["module2", "greedy", "sa", "schedule"]:
            summary = result[stage]["summary"]
            peak_kb = max(result[stage]["mem"]) / 1024.0 if result[stage]["mem"] else 0.0
            print(f"{result['n']} | {result['days']} | {stage} | {summary['median']*1000:.3f} | {summary['mean']*1000:.3f} | {summary['p95']*1000:.3f} | {summary['std']*1000:.3f} | {peak_kb:.1f}")
        print("-")
