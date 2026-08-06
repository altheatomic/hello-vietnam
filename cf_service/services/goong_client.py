"""
services/goong_client.py
Async client for Goong Distance Matrix API (https://rsapi.goong.io/DistanceMatrix).

Only used AFTER Simulated Annealing has already picked the final route for a
day (see module3_optimizer.py / trip_planner.py) — never inside the SA cost
loop, which stays on Haversine (schedule_builder._travel_min) for speed.
Vehicles supported: "car" and "bike" only (Goong's docs do not clearly
confirm a "walk" vehicle value, so it is intentionally not offered here).

── Why path-diagonal batching instead of per-edge calls ──────────────────────
Goong bills by REQUEST COUNT, not by the number of matrix elements returned,
so for an N-point route (N-1 sequential edges) we issue ONE request per
vehicle with origins = points[:-1] and destinations = points[1:] (both length
N-1), then read only the diagonal element rows[i]["elements"][i] — the
(i-th origin, i-th destination) pair, which is exactly edge (points[i],
points[i+1]). The other (N-1)^2 - (N-1) off-diagonal elements are unused
matrix noise, not billed separately, so this reduces N-1 calls to 1 call.

── Why timeout + status="ERROR" instead of raising ────────────────────────────
A slow/unreachable Goong endpoint must never take down trip planning — the
caller (trip_planner.py, in a later change) is expected to fall back to the
Haversine-based schedule for any edge marked "ERROR". Keeping the failure
mode a plain returned value (not an exception) makes that fallback trivial
and keeps this module's contract simple: it always returns a list of the
right length, never raises for network/API-level failures.
"""

import asyncio
import os

import httpx

_GOONG_DISTANCE_MATRIX_URL = "https://rsapi.goong.io/DistanceMatrix"
_REQUEST_TIMEOUT_SECONDS = 5.0
_VEHICLES = ("car", "bike")


def _format_point(point: dict) -> str:
    return f"{point['latitude']},{point['longitude']}"


def _error_matrix(n_edges: int) -> list[dict]:
    return [
        {"distance_meters": None, "duration_seconds": None, "status": "ERROR"}
        for _ in range(n_edges)
    ]


async def fetch_travel_matrix(points: list[dict], vehicle: str) -> list[dict]:
    """
    Fetch travel time/distance for each sequential edge of a route.

    points: route points IN ORDER, length N (each needs 'latitude'/'longitude').
    vehicle: "car" or "bike".

    Returns a list of length N-1 (edge i = points[i] -> points[i+1]), each:
        {"distance_meters": int | None, "duration_seconds": int | None,
         "status": "OK" | "ERROR" | <goong element status>}

    Never raises — network errors, timeouts, and Goong-level {"error": ...}
    responses all resolve to a full-length list of status="ERROR" entries so
    the caller can fall back to Haversine per-edge without special-casing
    exceptions.
    """
    if vehicle not in _VEHICLES:
        raise ValueError(f"Unsupported vehicle {vehicle!r}; expected one of {_VEHICLES}")

    n_edges = len(points) - 1
    if n_edges <= 0:
        return []

    api_key = os.environ.get("GOONG_API_KEY")
    if not api_key:
        # Config problem, not a transient failure — still degrade gracefully
        # rather than crashing the whole planning pipeline.
        return _error_matrix(n_edges)

    origins = points[:-1]
    destinations = points[1:]
    params = {
        "origins": "|".join(_format_point(p) for p in origins),
        "destinations": "|".join(_format_point(p) for p in destinations),
        "vehicle": vehicle,
        "api_key": api_key,
    }

    try:
        async with httpx.AsyncClient(timeout=_REQUEST_TIMEOUT_SECONDS) as client:
            resp = await client.get(_GOONG_DISTANCE_MATRIX_URL, params=params)
        data = resp.json()
    except (httpx.HTTPError, ValueError) as exc:
        print(f"[goong_client] fetch_travel_matrix vehicle={vehicle} failed: {exc!r}")
        return _error_matrix(n_edges)

    if "error" in data:
        print(f"[goong_client] Goong returned error: {data['error']}")
        return _error_matrix(n_edges)

    rows = data.get("rows") or []
    result = []
    for i in range(n_edges):
        try:
            element = rows[i]["elements"][i]
        except (IndexError, KeyError, TypeError):
            result.append({"distance_meters": None, "duration_seconds": None, "status": "ERROR"})
            continue

        status = element.get("status")
        if status != "OK":
            result.append({"distance_meters": None, "duration_seconds": None, "status": status or "ERROR"})
            continue

        try:
            result.append({
                "distance_meters": element["distance"]["value"],
                "duration_seconds": element["duration"]["value"],
                "status": "OK",
            })
        except (KeyError, TypeError):
            result.append({"distance_meters": None, "duration_seconds": None, "status": "ERROR"})

    return result


async def fetch_travel_matrix_both_vehicles(points: list[dict]) -> dict:
    """
    Fetch car + bike travel matrices for the same route, concurrently.

    Returns {"car": [...], "bike": [...]} — each value is the list produced
    by fetch_travel_matrix() (length len(points)-1, same shape/edge order).
    """
    car_result, bike_result = await asyncio.gather(
        fetch_travel_matrix(points, "car"),
        fetch_travel_matrix(points, "bike"),
    )
    return {"car": car_result, "bike": bike_result}
