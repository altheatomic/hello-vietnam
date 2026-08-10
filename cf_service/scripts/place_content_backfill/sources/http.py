"""Bounded HTTP retry primitive shared by source adapters."""

from __future__ import annotations

import asyncio
from typing import Any

import httpx


async def request_with_retry(
    client: httpx.AsyncClient,
    method: str,
    url: str,
    *,
    attempts: int = 3,
    **kwargs: Any,
) -> httpx.Response:
    if attempts < 1:
        raise ValueError("attempts must be positive")
    last_error: Exception | None = None
    for attempt in range(1, attempts + 1):
        try:
            response = await client.request(method, url, **kwargs)
            if response.status_code not in {429, 500, 502, 503, 504}:
                return response
            if attempt == attempts:
                return response
            raw_delay = response.headers.get("retry-after")
            try:
                delay = min(2.0, max(0.0, float(raw_delay))) if raw_delay else 0.0
            except ValueError:
                delay = 0.0
            await asyncio.sleep(delay)
        except httpx.HTTPError as exc:
            last_error = exc
            if attempt == attempts:
                raise
            await asyncio.sleep(0)
    if last_error is not None:
        raise last_error
    raise RuntimeError("source request retry loop ended unexpectedly")


__all__ = ["request_with_retry"]
