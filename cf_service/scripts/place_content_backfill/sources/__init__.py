from __future__ import annotations

import asyncio
from dataclasses import dataclass
import hashlib
import json
from typing import Any, Iterable

import httpx

from ..artifacts import ArtifactStore
from ..constants import DEFAULT_HTTP_CONCURRENCY
from ..models import BaselineRecord, SourceFact, SourceSnapshot


IDENTIFYING_USER_AGENT = "hello-vietnam-place-content-backfill/1.0 (research; contact owner)"
DEFAULT_TIMEOUT = httpx.Timeout(connect=5.0, read=20.0, write=10.0, pool=5.0)
MAX_RETRIES = 3


@dataclass(frozen=True)
class FetchResult:
    status_code: int
    headers: dict[str, str]
    body: bytes
    url: str


class ResponseLimitExceeded(ValueError):
    """Raised before a response body can exceed its configured cap."""


class RetryExhausted(RuntimeError):
    """Raised after all bounded HTTP attempts fail."""


def request_cache_key(
    method: str,
    url: str,
    *,
    params: Any = None,
    body: Any = None,
    baseline_input_hash: str,
) -> str:
    payload = {
        "method": method.upper(),
        "url": url,
        "params": params,
        "body": body,
        "baseline_input_hash": baseline_input_hash,
    }
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def _retry_delay(response: httpx.Response | None, attempt: int, base: float) -> float:
    if response is not None:
        retry_after = response.headers.get("Retry-After")
        if retry_after:
            try:
                return max(0.0, min(float(retry_after), 30.0))
            except ValueError:
                pass
    return min(base * (2**attempt), 30.0)


async def fetch_bytes(
    client: httpx.AsyncClient,
    method: str,
    url: str,
    *,
    params: Any = None,
    json_body: Any = None,
    content: bytes | str | None = None,
    headers: dict[str, str] | None = None,
    max_bytes: int,
    retries: int = MAX_RETRIES,
    backoff_base: float = 0.25,
    sleep=asyncio.sleep,
) -> FetchResult:
    """Fetch with bounded retries and streamed body accounting."""

    request_headers = {"User-Agent": IDENTIFYING_USER_AGENT}
    request_headers.update(headers or {})
    last_error: Exception | None = None
    for attempt in range(retries):
        response: httpx.Response | None = None
        try:
            async with client.stream(
                method,
                url,
                params=params,
                json=json_body,
                content=content,
                headers=request_headers,
                follow_redirects=False,
            ) as response:
                if response.status_code == 429 or response.status_code >= 500:
                    if attempt + 1 < retries:
                        await sleep(_retry_delay(response, attempt, backoff_base))
                        continue
                    raise RetryExhausted(
                        f"HTTP {response.status_code} after {retries} attempts for {method} {url}"
                    )
                if response.status_code >= 400:
                    raise httpx.HTTPStatusError(
                        f"HTTP {response.status_code} for {method} {url}",
                        request=response.request,
                        response=response,
                    )
                content_length = response.headers.get("Content-Length")
                if content_length and content_length.isdigit() and int(content_length) > max_bytes:
                    raise ResponseLimitExceeded(f"response exceeds {max_bytes} bytes")
                chunks: list[bytes] = []
                received = 0
                async for chunk in response.aiter_bytes():
                    received += len(chunk)
                    if received > max_bytes:
                        raise ResponseLimitExceeded(f"response exceeds {max_bytes} bytes")
                    chunks.append(chunk)
                return FetchResult(
                    status_code=response.status_code,
                    headers=dict(response.headers),
                    body=b"".join(chunks),
                    url=str(response.url),
                )
        except ResponseLimitExceeded:
            raise
        except RetryExhausted:
            raise
        except (httpx.HTTPError, OSError) as exc:
            last_error = exc
            if attempt + 1 >= retries:
                break
            await sleep(_retry_delay(response, attempt, backoff_base))
    raise RetryExhausted(f"request failed after {retries} attempts for {method} {url}") from last_error


async def collect_source_snapshot(
    record: BaselineRecord,
    *,
    client: httpx.AsyncClient | None = None,
    wikimedia_links: Iterable[str] = (),
    official_site_enabled: bool = False,
    concurrency: int = DEFAULT_HTTP_CONCURRENCY,
) -> SourceSnapshot:
    """Collect bounded identity-safe evidence for one baseline record."""

    own_client = client is None
    if own_client:
        client = httpx.AsyncClient(timeout=DEFAULT_TIMEOUT, headers={"User-Agent": IDENTIFYING_USER_AGENT})
    facts: list[SourceFact] = []
    warnings: list[str] = []
    try:
        osm_facts, osm_warnings = await collect_osm_facts(
            record,
            client=client,
            concurrency=concurrency,
        )
        facts.extend(osm_facts)
        warnings.extend(osm_warnings)
        wiki_facts, wiki_warnings = await collect_wikimedia_facts(
            record,
            links=tuple(wikimedia_links),
            client=client,
        )
        facts.extend(wiki_facts)
        warnings.extend(wiki_warnings)
        site_facts, site_warnings = await collect_official_site(
            record,
            client=client,
            enabled=official_site_enabled,
        )
        facts.extend(site_facts)
        warnings.extend(site_warnings)
        return SourceSnapshot(
            place_id=record.place_id,
            baseline_input_hash=record.input_hash,
            facts=tuple(facts),
            warnings=tuple(warnings),
            sparse_source=not bool(facts),
        )
    finally:
        if own_client and client is not None:
            await client.aclose()


async def collect_worker(
    records: Iterable[BaselineRecord],
    artifact_store: ArtifactStore,
    *,
    client: httpx.AsyncClient | None = None,
    max_places: int = 50,
    concurrency: int = DEFAULT_HTTP_CONCURRENCY,
) -> int:
    """Process one bounded chunk and fsync each source snapshot immediately."""

    if max_places <= 0 or concurrency <= 0:
        raise ValueError("worker limits must be positive")
    queue: asyncio.Queue[BaselineRecord | None] = asyncio.Queue(maxsize=min(6, concurrency * 2))
    own_client = client is None
    active_client = client
    processed = 0

    async def producer() -> None:
        count = 0
        for item in records:
            count += 1
            if count > max_places:
                raise ValueError(f"collect worker received more than {max_places} places")
            await queue.put(item)
        await queue.put(None)

    async def consumer() -> int:
        count = 0
        while True:
            item = await queue.get()
            try:
                if item is None:
                    return count
                snapshot = await collect_source_snapshot(
                    item,
                    client=active_client,
                    concurrency=concurrency,
                )
                artifact_store.append_jsonl("sources", snapshot.model_dump(mode="json"))
                count += 1
            finally:
                queue.task_done()

    try:
        if own_client:
            active_client = httpx.AsyncClient(
                timeout=DEFAULT_TIMEOUT,
                headers={"User-Agent": IDENTIFYING_USER_AGENT},
            )
        producer_task = asyncio.create_task(producer())
        consumer_task = asyncio.create_task(consumer())
        await producer_task
        processed = await consumer_task
        return processed
    finally:
        if own_client and active_client is not None:
            await active_client.aclose()


# Import source modules after the shared HTTP primitives exist; the modules
# import fetch_bytes from this package.
from .osm import collect_osm_facts  # noqa: E402
from .website import collect_official_site  # noqa: E402
from .wikimedia import collect_wikimedia_facts  # noqa: E402
