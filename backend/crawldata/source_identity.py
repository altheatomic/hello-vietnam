"""Stable identities shared by crawlers and the freshness checker.

The scraper is intentionally allowed to change its presentation fields on every
run, but the source identity must stay stable so an upsert updates one logical
content row instead of creating a new one.
"""

from __future__ import annotations

import uuid
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit


SOURCE_NAMESPACE = uuid.UUID("b179b2f4-f28e-5f19-ae6f-5d31eb4b7915")

# Stage-1 OSM seeding shipped before the shared freshness identity was added.
# Keep its namespace as a compatibility path so an existing place row is
# updated on the next crawl instead of being duplicated under a new UUID.
LEGACY_PLACE_NAMESPACE = uuid.UUID("9a73fa2d-48f2-4d14-8f32-8845154a6e9a")


def canonical_source_url(url: str) -> str:
    """Return a deterministic URL without tracking fragments or query keys."""

    value = str(url or "").strip()
    if not value:
        raise ValueError("source URL must not be empty")

    parsed = urlsplit(value)
    scheme = parsed.scheme.lower()
    hostname = (parsed.hostname or "").lower()
    if not scheme or not hostname:
        raise ValueError(f"source URL must be absolute: {url!r}")

    # Rebuild netloc without changing a meaningful port.  urlsplit exposes the
    # normalized hostname while preserving IPv6 brackets when necessary.
    host = f"[{hostname}]" if ":" in hostname and not hostname.startswith("[") else hostname
    if parsed.port is not None:
        host = f"{host}:{parsed.port}"
    if parsed.username or parsed.password:
        credentials = parsed.username or ""
        if parsed.password is not None:
            credentials += f":{parsed.password}"
        host = f"{credentials}@{host}"

    query_pairs = [
        (key, value)
        for key, value in parse_qsl(parsed.query, keep_blank_values=True)
        if not key.lower().startswith("utm_")
    ]
    query_pairs.sort()
    path = parsed.path or "/"
    if path != "/":
        path = path.rstrip("/")
    return urlunsplit((scheme, host, path, urlencode(query_pairs), ""))


def source_external_id(source_type: str, raw_id: str) -> str:
    """Prefix a provider-native identifier with its source type."""

    source = str(source_type or "").strip().lower()
    raw = str(raw_id or "").strip()
    if not source or not raw:
        raise ValueError("source_type and raw_id are required")
    if source in {"wikipedia", "wiki"}:
        source = "wikipedia"
        if raw.startswith(("http://", "https://")):
            raw = canonical_source_url(raw)
    return f"{source}:{raw}"


def deterministic_content_uuid(
    content_type: str, source_type: str, external_id: str
) -> str:
    """Build the UUID used as the canonical content primary key."""

    content = str(content_type or "").strip().lower()
    source = str(source_type or "").strip().lower()
    external = str(external_id or "").strip()
    if not content or not source or not external:
        raise ValueError("content_type, source_type, and external_id are required")
    token = f"{content}:{source}:{external}"
    return str(uuid.uuid5(SOURCE_NAMESPACE, token))


def legacy_place_uuid(source_type: str, external_id: str) -> str:
    """Return the UUID used by the original deterministic OSM seeder."""

    source = str(source_type or "").strip().lower()
    external = str(external_id or "").strip()
    if not source or not external:
        raise ValueError("source_type and external_id are required")
    return str(uuid.uuid5(LEGACY_PLACE_NAMESPACE, f"{source}:{external}"))
