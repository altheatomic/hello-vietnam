"""Regression tests for the per-worker Module 3 concurrency limiter."""

import asyncio
import os
import threading
import time
import unittest
from unittest.mock import patch

from fastapi import HTTPException

from routes.trip import TripPlanRequest, plan_trip
from services import trip_planner
from services.sa_concurrency import (
    ENV_NAME,
    SaConcurrencyLimiter,
    SaQueueTimeoutError,
    configure_sa_limiter_from_env,
)


class SaConcurrencyLimiterTests(unittest.IsolatedAsyncioTestCase):
    async def test_k1_two_sa_calls_never_overlap(self):
        limiter = SaConcurrencyLimiter(1)
        lock = threading.Lock()
        intervals = []

        def work(label):
            with lock:
                started = time.perf_counter()
            time.sleep(0.04)
            with lock:
                intervals.append((label, started, time.perf_counter()))
            return label

        results = await asyncio.gather(
            limiter.run(work, "first", queue_timeout_seconds=1, request_id="r1"),
            limiter.run(work, "second", queue_timeout_seconds=1, request_id="r2"),
        )
        self.assertEqual({result.value for result in results}, {"first", "second"})
        intervals.sort(key=lambda item: item[1])
        self.assertGreaterEqual(intervals[1][1], intervals[0][2])

    async def test_exception_releases_slot_and_next_request_runs(self):
        limiter = SaConcurrencyLimiter(1)

        def fail():
            raise ValueError("SA failed")

        with self.assertRaisesRegex(ValueError, "SA failed"):
            await limiter.run(fail, queue_timeout_seconds=1, request_id="bad")
        self.assertEqual(limiter.active_count, 0)
        result = await limiter.run(lambda: "ok", queue_timeout_seconds=1,
                                   request_id="next")
        self.assertEqual(result.value, "ok")

    async def test_cancel_does_not_release_until_thread_finishes(self):
        limiter = SaConcurrencyLimiter(1)
        started = threading.Event()
        finish = threading.Event()

        def work():
            started.set()
            finish.wait(timeout=2)

        task = asyncio.create_task(
            limiter.run(work, queue_timeout_seconds=1, request_id="cancelled")
        )
        await asyncio.to_thread(started.wait, 1)
        task.cancel()
        await asyncio.sleep(0.03)
        self.assertEqual(limiter.active_count, 1)
        with self.assertRaises(SaQueueTimeoutError):
            await limiter.run(lambda: None, queue_timeout_seconds=0.01,
                              request_id="blocked")
        finish.set()
        with self.assertRaises(asyncio.CancelledError):
            await task
        self.assertEqual(limiter.active_count, 0)

    async def test_days_remain_in_input_order(self):
        limiter = SaConcurrencyLimiter(1)
        day_clusters = [
            {"day": day, "centroid": (10.0 + day, 106.0),
             "places": [{"id_place": str(day)}]}
            for day in [1, 2, 3]
        ]

        def fake_optimize(_start, places, **_kwargs):
            day = int(places[0]["id_place"])
            return [day], {"schedule": [day]}

        with patch("services.trip_planner.get_sa_limiter", return_value=limiter), \
             patch("services.trip_planner.optimize_day_route", fake_optimize):
            results = await trip_planner._run_sa_stage(
                day_clusters, [], n_days=3, sa_runs=5,
                include_lunch_break=True,
            )
        self.assertEqual([entry["day_cluster"]["day"] for entry in results],
                         [1, 2, 3])
        self.assertEqual([entry["best_route"][0] for entry in results],
                         [1, 2, 3])

    async def test_goong_io_occurs_without_sa_slot(self):
        limiter = SaConcurrencyLimiter(1)
        await limiter.run(lambda: "route", queue_timeout_seconds=1,
                          request_id="goong")
        observed_active = None

        async def fake_goong_io():
            nonlocal observed_active
            observed_active = limiter.active_count
            await asyncio.sleep(0.01)

        await fake_goong_io()
        self.assertEqual(observed_active, 0)

    async def test_queue_timeout_has_explicit_error(self):
        limiter = SaConcurrencyLimiter(1)
        started = threading.Event()
        finish = threading.Event()

        def work():
            started.set()
            finish.wait(timeout=2)

        first = asyncio.create_task(
            limiter.run(work, queue_timeout_seconds=1, request_id="holder")
        )
        await asyncio.to_thread(started.wait, 1)
        with self.assertRaisesRegex(SaQueueTimeoutError,
                                    "planner busy, please retry"):
            await limiter.run(lambda: None, queue_timeout_seconds=0.01,
                              request_id="timeout")
        finish.set()
        await first

    async def test_route_maps_queue_timeout_to_http_503(self):
        class BusyPlanner:
            def __init__(self, _supabase):
                pass

            async def plan(self, **_kwargs):
                raise SaQueueTimeoutError("planner busy, please retry")

        req = TripPlanRequest(id_user="user", id_province="province", n_days=1)
        with patch("routes.trip.TripPlannerService", BusyPlanner):
            with self.assertRaises(HTTPException) as caught:
                await plan_trip(req, supabase=object())
        self.assertEqual(caught.exception.status_code, 503)
        self.assertEqual(caught.exception.detail, "planner busy, please retry")


class SaConcurrencyConfigurationTests(unittest.TestCase):
    def test_invalid_k_fails_configuration_with_clear_message(self):
        for invalid in ("0", "-2", "abc", "1.5"):
            with self.subTest(value=invalid), patch.dict(os.environ, {ENV_NAME: invalid}):
                with self.assertRaisesRegex(RuntimeError,
                                            "must be a positive integer"):
                    configure_sa_limiter_from_env()

    def test_missing_k_defaults_to_one(self):
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop(ENV_NAME, None)
            limiter = configure_sa_limiter_from_env()
        self.assertEqual(limiter.max_concurrency, 1)


if __name__ == "__main__":
    unittest.main()
