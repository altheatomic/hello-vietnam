"""Per-process concurrency control for CPU-bound Module 3 SA work."""

from __future__ import annotations

import asyncio
import json
import os
import time
from dataclasses import dataclass
from typing import Callable, Generic, TypeVar

T = TypeVar("T")
ENV_NAME = "SA_MAX_CONCURRENCY_PER_WORKER"
DEFAULT_MAX_CONCURRENCY = 1


class SaQueueTimeoutError(RuntimeError):
    """Raised when Module 3 cannot obtain capacity within its queue budget."""


def parse_max_concurrency(raw_value: str | None) -> int:
    value = str(DEFAULT_MAX_CONCURRENCY) if raw_value is None else raw_value
    try:
        parsed = int(value)
    except (TypeError, ValueError) as exc:
        raise RuntimeError(f"{ENV_NAME} must be a positive integer; got {value!r}") from exc
    if parsed <= 0:
        raise RuntimeError(f"{ENV_NAME} must be a positive integer; got {value!r}")
    return parsed


@dataclass(frozen=True)
class SaRunResult(Generic[T]):
    value: T
    queue_wait_ms: float


class SaConcurrencyLimiter:
    """Limits concurrent SA threads inside one Uvicorn worker process."""

    def __init__(self, max_concurrency: int):
        if max_concurrency <= 0:
            raise ValueError("max_concurrency must be positive")
        self.max_concurrency = max_concurrency
        self._semaphore = asyncio.Semaphore(max_concurrency)
        self._active = 0

    @property
    def active_count(self) -> int:
        return self._active

    def log_startup(self) -> None:
        print(json.dumps({"event": "sa_limiter_startup", "worker_pid": os.getpid(),
                          "sa_max_concurrency_per_worker": self.max_concurrency},
                         separators=(",", ":")))

    async def run(self, func: Callable[..., T], *args,
                  queue_timeout_seconds: float, request_id: str,
                  **kwargs) -> SaRunResult[T]:
        wait_started = time.perf_counter()
        try:
            await asyncio.wait_for(self._semaphore.acquire(),
                                   timeout=max(0.0, queue_timeout_seconds))
        except asyncio.TimeoutError as exc:
            wait_ms = round((time.perf_counter() - wait_started) * 1000, 1)
            self._log("sa_queue_timeout", request_id, wait_ms)
            raise SaQueueTimeoutError("planner busy, please retry") from exc

        wait_ms = round((time.perf_counter() - wait_started) * 1000, 1)
        self._active += 1
        self._log("sa_slot_acquired", request_id, wait_ms)

        async def _run_and_release() -> T:
            try:
                return await asyncio.to_thread(func, *args, **kwargs)
            finally:
                self._active -= 1
                self._semaphore.release()
                self._log("sa_slot_released", request_id)

        # This child task owns the acquired slot. Shielding it is essential:
        # cancelling to_thread does not stop its already-running OS thread.
        owner_task = asyncio.create_task(_run_and_release())
        try:
            value = await asyncio.shield(owner_task)
        except asyncio.CancelledError:
            try:
                await asyncio.shield(owner_task)
            except asyncio.CancelledError:
                while not owner_task.done():
                    await asyncio.sleep(0)
            except Exception:
                pass
            if owner_task.done() and not owner_task.cancelled():
                try:
                    owner_task.result()
                except Exception:
                    pass
            raise
        return SaRunResult(value=value, queue_wait_ms=wait_ms)

    def _log(self, event: str, request_id: str,
             queue_wait_ms: float | None = None) -> None:
        payload = {"event": event, "request_id": request_id,
                   "active_sa_count": self._active,
                   "configured_k": self.max_concurrency,
                   "worker_pid": os.getpid()}
        if queue_wait_ms is not None:
            payload["sa_queue_wait_ms"] = queue_wait_ms
        print(json.dumps(payload, separators=(",", ":")))


_limiter: SaConcurrencyLimiter | None = None


def configure_sa_limiter_from_env() -> SaConcurrencyLimiter:
    """Configure once per worker; invalid values deliberately fail startup."""
    global _limiter
    _limiter = SaConcurrencyLimiter(parse_max_concurrency(os.environ.get(ENV_NAME)))
    _limiter.log_startup()
    return _limiter


def get_sa_limiter() -> SaConcurrencyLimiter:
    global _limiter
    if _limiter is None:
        _limiter = SaConcurrencyLimiter(parse_max_concurrency(os.environ.get(ENV_NAME)))
    return _limiter
