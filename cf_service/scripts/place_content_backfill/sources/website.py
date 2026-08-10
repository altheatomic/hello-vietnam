"""Bounded official-site metadata reader with SSRF protection."""

from __future__ import annotations

import ipaddress
import json
import socket
from dataclasses import dataclass
from html.parser import HTMLParser
from typing import Any
from urllib.parse import urljoin, urlparse

import httpx


MAX_BODY_BYTES = 1024 * 1024
MAX_REDIRECTS = 3


@dataclass(frozen=True)
class OfficialMetadata:
    final_url: str
    title: str | None = None
    description: str | None = None
    name: str | None = None
    kind: str | None = None
    address: str | None = None


def validate_official_url(url: str) -> str:
    parsed = urlparse(str(url).strip())
    if parsed.scheme not in {"http", "https"}:
        raise ValueError("official URL must use http or https")
    if parsed.username or parsed.password:
        raise ValueError("official URL must not contain credentials")
    host = (parsed.hostname or "").rstrip(".").lower()
    if not host or host in {"localhost", "localhost.localdomain"} or host.endswith(".local"):
        raise ValueError("private/local official host is not allowed")
    _assert_public_host(host)
    return parsed.geturl()


async def extract_official_metadata(
    url: str,
    client: httpx.AsyncClient,
    *,
    max_bytes: int = MAX_BODY_BYTES,
) -> OfficialMetadata:
    current = validate_official_url(url)
    for _ in range(MAX_REDIRECTS + 1):
        response = await client.get(
            current,
            follow_redirects=False,
            timeout=15,
            headers={"User-Agent": "hello-vietnam-place-content/1.0"},
        )
        if response.status_code in {301, 302, 303, 307, 308}:
            location = response.headers.get("location")
            if not location:
                raise ValueError("redirect without location")
            current = validate_official_url(urljoin(current, location))
            continue
        response.raise_for_status()
        content_type = response.headers.get("content-type", "").lower()
        if not content_type.startswith("text/html"):
            raise ValueError("official source is not HTML")
        body = response.content
        if len(body) > max_bytes:
            raise ValueError("official source exceeds size limit")
        return _parse_html(current, body)
    raise ValueError("too many official-site redirects")


class _MetadataParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.title: list[str] = []
        self.in_title = False
        self.description: str | None = None
        self.json_ld: list[str] = []
        self.in_json_ld = False

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = {key.lower(): value or "" for key, value in attrs}
        if tag.lower() == "title":
            self.in_title = True
        if tag.lower() == "meta" and attributes.get("name", "").lower() == "description":
            self.description = attributes.get("content", "").strip() or None
        if tag.lower() == "script" and attributes.get("type", "").lower() == "application/ld+json":
            self.in_json_ld = True

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() == "title":
            self.in_title = False
        if tag.lower() == "script":
            self.in_json_ld = False

    def handle_data(self, data: str) -> None:
        if self.in_title:
            self.title.append(data)
        if self.in_json_ld:
            self.json_ld.append(data)


def _parse_html(url: str, body: bytes) -> OfficialMetadata:
    parser = _MetadataParser()
    parser.feed(body.decode("utf-8", errors="replace"))
    title = " ".join("".join(parser.title).split()) or None
    name = description = kind = address = None
    for raw in parser.json_ld:
        try:
            value = json.loads(raw)
        except json.JSONDecodeError:
            continue
        candidates = value if isinstance(value, list) else [value]
        for item in candidates:
            if not isinstance(item, dict):
                continue
            name = name or _string_value(item.get("name"))
            kind = kind or _string_value(item.get("@type"))
            address_value = item.get("address")
            if isinstance(address_value, dict):
                address = address or _string_value(address_value.get("streetAddress"))
            else:
                address = address or _string_value(address_value)
    return OfficialMetadata(
        final_url=url,
        title=title,
        description=description or parser.description,
        name=name,
        kind=kind,
        address=address,
    )


def _assert_public_host(host: str) -> None:
    try:
        ip = ipaddress.ip_address(host)
    except ValueError:
        ip = None
    if ip is not None:
        if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved or ip.is_unspecified:
            raise ValueError("private/link-local official host is not allowed")
        return
    # Resolve hostnames and reject any private answer. DNS failures fail closed;
    # callers can keep the item in a sparse snapshot instead of fetching it.
    try:
        addresses = {
            info[4][0]
            for info in socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)
        }
    except socket.gaierror as exc:
        raise ValueError("official host cannot be resolved") from exc
    for address in addresses:
        parsed = ipaddress.ip_address(address)
        if parsed.is_private or parsed.is_loopback or parsed.is_link_local or parsed.is_reserved or parsed.is_unspecified:
            raise ValueError("official host resolves to a private address")


def _string_value(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, (dict, list)):
        return None
    text = str(value).strip()
    return text or None
