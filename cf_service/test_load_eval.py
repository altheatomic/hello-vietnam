"""
test_load_eval.py
Simple concurrent load test for POST /api/trips/plan — capstone report
section 4.3 (performance evaluation / load test).

Two independent measurement modes (run either or both):

  1. --mode direct  — hits cf_service directly at http://localhost:8000
                      (uvicorn must already be running locally). No network
                      hop beyond localhost — isolates pure server compute
                      + DB round-trip time.

  2. --mode edge     — hits the Supabase Edge Function
                      (SUPABASE_URL/functions/v1/trip-planner), which the
                      real Flutter app actually calls. This request path
                      goes through the Cloudflare Quick Tunnel (dev, no
                      SLA) to reach cf_service, so results here mix real
                      compute time with tunnel/network overhead — compare
                      against --mode direct numbers to see how much of the
                      total is the tunnel, not the server.

    Requires a real Supabase user access token for the test user (edge
    function validates the JWT — CF_SERVICE_URL is not exposed directly to
    clients). Get one by signing in as the test user in the app (or via
    `supabase.auth.sign_in_with_password` / the dashboard) and pass it with
    --auth-token. Without a token this mode is skipped, not faked.

Same payload for every request (1 province, 1 user, n_days=2, save_plan
false) — avoids confounding results with different candidate pools, and
never writes to plan/plan_component.

Usage:
    # Direct only (works out of the box, uvicorn running on :8000)
    python test_load_eval.py --mode direct

    # Edge function only (needs a real user JWT)
    python test_load_eval.py --mode edge --auth-token eyJ...

    # Both, for the compute-vs-tunnel comparison in the report
    python test_load_eval.py --mode both --auth-token eyJ...

Output: CSV with one row per (mode, concurrency_level):
    mode, concurrency_level, requests_sent, mean_ms, p95_ms, p99_ms, error_count
"""

import argparse
import asyncio
import csv
import os
import statistics
import time

import httpx
from dotenv import load_dotenv

load_dotenv()

# ── Fixed test fixtures (same as test_performance_eval.py, verified real IDs) ─
USER_ID = "dd16ba71-c26b-44dd-a3f4-61973f268822"       # control.blank (no history)
PROVINCE_HCM = "230e26ed-0118-4f62-96b5-ac0eb3ca1c1b"  # Hồ Chí Minh — same pool for every request
N_DAYS = 2

DIRECT_URL = "http://localhost:8000/api/trips/plan"


def _edge_function_url() -> str:
    supabase_url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    if not supabase_url:
        raise ValueError("SUPABASE_URL not set in .env — required for --mode edge")
    return f"{supabase_url}/functions/v1/trip-planner"


def _direct_payload() -> dict:
    return {
        "id_user": USER_ID,
        "id_province": PROVINCE_HCM,
        "n_days": N_DAYS,
        "sa_runs": 2,
        "save_plan": False,
    }


def _edge_payload() -> dict:
    return {
        "action": "planTrip",
        "idProvince": PROVINCE_HCM,
        "nDays": N_DAYS,
        "saRuns": 2,
        "savePlan": False,
    }


async def _send_one(client: httpx.AsyncClient, url: str, payload: dict, headers: dict) -> tuple[float, bool]:
    """Returns (elapsed_ms, ok). ok=False on timeout, connection error, or non-2xx."""
    t0 = time.perf_counter()
    try:
        resp = await client.post(url, json=payload, headers=headers, timeout=90.0)
        elapsed_ms = (time.perf_counter() - t0) * 1000
        return elapsed_ms, resp.status_code < 300
    except (httpx.TimeoutException, httpx.TransportError) as exc:
        elapsed_ms = (time.perf_counter() - t0) * 1000
        print(f"    [FAIL] {type(exc).__name__}: {exc}")
        return elapsed_ms, False


def _percentile(values: list[float], pct: float) -> float:
    if not values:
        return float("nan")
    if len(values) == 1:
        return round(values[0], 1)
    quantiles = statistics.quantiles(values, n=100, method="inclusive")
    return round(quantiles[int(pct) - 1], 1)


async def _run_concurrency_level(
    mode: str,
    url: str,
    payload: dict,
    headers: dict,
    concurrency: int,
    batches: int,
) -> dict:
    """
    Sends `batches` waves of `concurrency` fully-concurrent requests each
    (so total samples = concurrency * batches — enough to compute p95/p99
    meaningfully even at concurrency=1).
    """
    print(f"[{mode}] concurrency={concurrency}: {batches} batches of {concurrency} "
          f"concurrent request(s) each")
    all_latencies: list[float] = []
    error_count = 0

    async with httpx.AsyncClient() as client:
        for b in range(batches):
            tasks = [
                _send_one(client, url, payload, headers)
                for _ in range(concurrency)
            ]
            results = await asyncio.gather(*tasks)
            for elapsed_ms, ok in results:
                all_latencies.append(elapsed_ms)
                if not ok:
                    error_count += 1
            print(f"    batch {b + 1}/{batches} done")

    return {
        "mode": mode,
        "concurrency_level": concurrency,
        "requests_sent": len(all_latencies),
        "mean_ms": round(statistics.mean(all_latencies), 1) if all_latencies else float("nan"),
        "p95_ms": _percentile(all_latencies, 95),
        "p99_ms": _percentile(all_latencies, 99),
        "error_count": error_count,
    }


async def run_mode(mode: str, auth_token: str | None, concurrency_levels: list[int], batches: int) -> list[dict]:
    if mode == "direct":
        url = DIRECT_URL
        payload = _direct_payload()
        headers = {}
    elif mode == "edge":
        if not auth_token:
            print("[edge] Skipped — no --auth-token supplied (edge function requires "
                  "a real Supabase user JWT; see script docstring for how to get one).")
            return []
        url = _edge_function_url()
        payload = _edge_payload()
        headers = {"Authorization": f"Bearer {auth_token}"}
    else:
        raise ValueError(f"Unknown mode: {mode}")

    rows = []
    for concurrency in concurrency_levels:
        rows.append(await _run_concurrency_level(mode, url, payload, headers, concurrency, batches))
    return rows


def _write_csv(rows: list[dict], out_path: str) -> None:
    header = ["mode", "concurrency_level", "requests_sent", "mean_ms", "p95_ms", "p99_ms", "error_count"]
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=header)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
    print(f"\nWrote {out_path}")


async def main(args: argparse.Namespace) -> None:
    concurrency_levels = [int(c) for c in args.concurrency.split(",")]
    all_rows: list[dict] = []

    modes = ["direct", "edge"] if args.mode == "both" else [args.mode]
    for mode in modes:
        all_rows.extend(await run_mode(mode, args.auth_token, concurrency_levels, args.batches))

    if not all_rows:
        print("No results collected (edge mode likely skipped without --auth-token).")
        return

    _write_csv(all_rows, args.out)

    print("\n--- Summary ---")
    for row in all_rows:
        print(
            f"{row['mode']:>7} conc={row['concurrency_level']:<3} "
            f"mean={row['mean_ms']:>8}ms p95={row['p95_ms']:>8}ms "
            f"p99={row['p99_ms']:>8}ms errors={row['error_count']}"
        )

    if args.mode == "both" and any(r["mode"] == "edge" for r in all_rows):
        print(
            "\nNOTE for the report: 'edge' mode goes through the Cloudflare Quick "
            "Tunnel (dev, no SLA) between the Edge Function and cf_service — the "
            "gap between 'direct' and 'edge' mean_ms at the same concurrency level "
            "is network/tunnel overhead, not server compute time. Do not present "
            "'edge' numbers as production-representative without this caveat."
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--mode", choices=["direct", "edge", "both"], default="direct",
                         help="direct=localhost:8000 only, edge=Supabase Edge Function/tunnel only, both=run and compare (default: direct)")
    parser.add_argument("--auth-token", type=str, default=None,
                         help="Supabase user JWT for USER_ID, required for --mode edge/both")
    parser.add_argument("--concurrency", type=str, default="1,5,10",
                         help="Comma-separated concurrency levels (default: 1,5,10)")
    parser.add_argument("--batches", type=int, default=5,
                         help="Waves per concurrency level, for p95/p99 sample size (default: 5)")
    parser.add_argument("--out", type=str, default="load_eval_results.csv", help="CSV output path")
    args = parser.parse_args()

    asyncio.run(main(args))
