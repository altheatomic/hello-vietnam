"""Small process-local TTL cache for shared, non-user-specific read data."""

from __future__ import annotations

import copy
import threading
import time
from collections import OrderedDict
from typing import Generic, Hashable, TypeVar


K = TypeVar("K", bound=Hashable)
V = TypeVar("V")


class TtlCache(Generic[K, V]):
    """Thread-safe bounded cache that isolates mutable values with deep copies."""

    def __init__(self, ttl_seconds: float, max_entries: int = 128):
        self._ttl_seconds = ttl_seconds
        self._max_entries = max_entries
        self._values: OrderedDict[K, tuple[float, V]] = OrderedDict()
        self._lock = threading.Lock()

    def get(self, key: K) -> V | None:
        now = time.monotonic()
        with self._lock:
            cached = self._values.get(key)
            if cached is None:
                return None
            expires_at, value = cached
            if expires_at <= now:
                self._values.pop(key, None)
                return None
            self._values.move_to_end(key)
            return copy.deepcopy(value)

    def set(self, key: K, value: V) -> None:
        with self._lock:
            self._values[key] = (
                time.monotonic() + self._ttl_seconds,
                copy.deepcopy(value),
            )
            self._values.move_to_end(key)
            while len(self._values) > self._max_entries:
                self._values.popitem(last=False)

    def clear(self) -> None:
        """Drop every cached entry. For explicit invalidation-on-write
        (cache-aside pattern) — e.g. cf_retrain.py clearing the CF factor
        caches once a retrain finishes, instead of waiting out the TTL."""
        with self._lock:
            self._values.clear()
