from __future__ import annotations

import ipaddress
import hashlib
import re
import socket
from typing import Callable
from urllib.parse import urljoin, urlparse

import httpx

from ..models import BaselineRecord, SourceFact
from . import fetch_bytes, ResponseLimitExceeded


MAX_OFFICIAL_SITE_BYTES = 1 * 1024 * 1024
_TITLE_RE = re.compile(r"<title[^>]*>(.*?)</title>", re.IGNORECASE | re.DOTALL)


def official_site_fact_id(url: str, baseline_input_hash: str) -> str:
    digest = hashlib.sha256(f"{url}\0{baseline_input_hash}".encode("utf-8")).hexdigest()[:16]
    return f"website:{digest}:title"


def _default_resolve_host(host: str) -> list[str]:
    return sorted(
        {
            str(result[4][0])
            for result in socket.getaddrinfo(host, None, type=socket.SOCK_STREAM)
        }
    )


def _is_unsafe_ip(value: str) -> bool:
    address = ipaddress.ip_address(value)
    return bool(
        address.is_private
        or address.is_loopback
        or address.is_link_local
        or address.is_reserved
        or address.is_unspecified
        or address.is_multicast
    )


def validate_public_http_url(
    url: str,
    *,
    resolve_host: Callable[[str], list[str]] = _default_resolve_host,
) -> str:
    parsed = urlparse(url)
    if parsed.scheme.lower() not in {"http", "https"}:
        raise ValueError("official site must use HTTP(S)")
    host = (parsed.hostname or "").rstrip(".").lower()
    if not host or host == "localhost" or host.endswith(".localhost"):
        raise ValueError("official site hostname is not public")
    try:
        addresses = [host] if _looks_like_ip(host) else resolve_host(host)
    except (OSError, ValueError) as exc:
        raise ValueError("official site hostname could not be resolved safely") from exc
    if not addresses:
        raise ValueError("official site hostname has no addresses")
    for address in addresses:
        try:
            if _is_unsafe_ip(address):
                raise ValueError("official site resolves to a private or local address")
        except ValueError as exc:
            if str(exc).startswith("official site"):
                raise
            raise ValueError("official site returned an invalid address") from exc
    return url


def _looks_like_ip(host: str) -> bool:
    try:
        ipaddress.ip_address(host)
        return True
    except ValueError:
        return False


async def collect_official_site(
    record: BaselineRecord,
    *,
    client: httpx.AsyncClient,
    enabled: bool = False,
    resolve_host: Callable[[str], list[str]] = _default_resolve_host,
) -> tuple[list[SourceFact], list[str]]:
    if not enabled:
        return [], [f"official-site-disabled:{record.place_id}"]
    if not record.website:
        return [], [f"official-site-missing:{record.place_id}"]
    current_url = validate_public_http_url(record.website, resolve_host=resolve_host)
    for _ in range(4):
        result = await fetch_bytes(
            client,
            "GET",
            current_url,
            max_bytes=MAX_OFFICIAL_SITE_BYTES,
        )
        if 300 <= result.status_code < 400:
            location = result.headers.get("location")
            if not location:
                raise ValueError("official site redirect has no Location")
            current_url = validate_public_http_url(
                urljoin(current_url, location),
                resolve_host=resolve_host,
            )
            continue
        content_type = result.headers.get("content-type", "").lower()
        if not content_type.startswith("text/html"):
            raise ValueError("official site response is not HTML")
        text = result.body.decode("utf-8", errors="replace")
        title_match = _TITLE_RE.search(text)
        title = " ".join(title_match.group(1).split()) if title_match else ""
        if not title:
            return [], [f"official-site-empty-title:{record.place_id}"]
        return [
            SourceFact(
                fact_id=official_site_fact_id(current_url, record.input_hash),
                source_type="official_site",
                source_url=current_url,
                claim=f"Official site title: {title}",
                confidence=0.8,
                value=title,
            )
        ], []
    raise ValueError("official site exceeded redirect limit")


__all__ = [
    "ResponseLimitExceeded",
    "collect_official_site",
    "official_site_fact_id",
    "validate_public_http_url",
]
