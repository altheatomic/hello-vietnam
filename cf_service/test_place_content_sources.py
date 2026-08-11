import asyncio
import unittest
from unittest.mock import patch

import httpx

from scripts.place_content_backfill.constants import APPROVED_PROVINCES
from scripts.place_content_backfill.models import BaselineRecord, TranslationBaseline
from scripts.place_content_backfill.sources import collect_source_snapshots
from scripts.place_content_backfill.sources.osm import parse_osm_id
from scripts.place_content_backfill.sources.osm import collect_osm_facts
from scripts.place_content_backfill.sources import osm as osm_source
from scripts.place_content_backfill.sources.website import (
    extract_official_metadata,
    validate_official_url,
)
from scripts.place_content_backfill.sources.wikimedia import (
    is_wikidata_id,
    parse_wikipedia_tag,
    article_identity_matches,
)


class PlaceContentSourcesTest(unittest.TestCase):
    def test_collect_source_snapshots_batches_osm_ids(self):
        def record(place_id, source_place_id):
            return BaselineRecord(
                place_id=place_id,
                province_id=APPROVED_PROVINCES[0],
                name=f"Place {place_id}",
                source="osm",
                source_place_id=source_place_id,
                vi=TranslationBaseline(
                    id=f"{place_id}-vi",
                    place_id=place_id,
                    lang_code="vi",
                    name=f"Place {place_id}",
                ),
                en=TranslationBaseline(
                    id=f"{place_id}-en",
                    place_id=place_id,
                    lang_code="en",
                    name=f"Place {place_id}",
                ),
            )

        records = [
            record("p1", "osm:node:1"),
            record("p2", "osm:way:2"),
            record("p3", "osm:relation:3"),
        ]

        async def run():
            calls = 0

            async def handler(request: httpx.Request) -> httpx.Response:
                nonlocal calls
                calls += 1
                return httpx.Response(
                    200,
                    json={
                        "elements": [
                            {"type": "node", "id": 1, "tags": {"name": "One"}},
                            {"type": "way", "id": 2, "tags": {"name": "Two"}},
                            {"type": "relation", "id": 3, "tags": {"name": "Three"}},
                        ]
                    },
                )

            async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
                snapshots = await collect_source_snapshots(records, client)
            self.assertEqual(calls, 1)
            self.assertEqual([snapshot.place_id for snapshot in snapshots], ["p1", "p2", "p3"])
            self.assertEqual([snapshot.facts[0].value for snapshot in snapshots], ["One", "Two", "Three"])

        asyncio.run(run())

    def test_collect_source_snapshots_records_batch_failure_as_warning(self):
        record = BaselineRecord(
            place_id="p1",
            province_id=APPROVED_PROVINCES[0],
            name="Place 1",
            source="osm",
            source_place_id="osm:node:1",
            vi=TranslationBaseline(id="p1-vi", place_id="p1", lang_code="vi"),
            en=TranslationBaseline(id="p1-en", place_id="p1", lang_code="en"),
        )

        async def run():
            async def handler(request: httpx.Request) -> httpx.Response:
                return httpx.Response(500, json={"error": "overloaded"})

            async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
                snapshots = await collect_source_snapshots([record], client)
            self.assertEqual(len(snapshots), 1)
            self.assertEqual(snapshots[0].facts, ())
            self.assertEqual(snapshots[0].warnings, ("osm source unavailable: HTTPStatusError",))

        asyncio.run(run())

    def test_parse_osm_identity(self):
        self.assertEqual(parse_osm_id("osm:node:123"), ("node", 123))
        self.assertEqual(parse_osm_id("osm:way:456"), ("way", 456))
        self.assertEqual(parse_osm_id("osm:relation:789"), ("relation", 789))
        with self.assertRaises(ValueError):
            parse_osm_id("osm:node:not-a-number")

    def test_wikimedia_identity_requires_explicit_shape(self):
        self.assertTrue(is_wikidata_id("Q123"))
        self.assertFalse(is_wikidata_id("123"))
        self.assertEqual(parse_wikipedia_tag("vi:Sông_Hương"), ("vi", "Sông_Hương"))
        self.assertIsNone(parse_wikipedia_tag("Sông Hương"))
        self.assertTrue(
            article_identity_matches(
                {"name": "Sông Hương", "province_id": "p", "category": "river", "latitude": 16.47, "longitude": 107.58},
                {"title": "Sông Hương", "province_id": "p", "category": "river", "latitude": 16.4701, "longitude": 107.5801},
            )
        )
        self.assertFalse(
            article_identity_matches(
                {"name": "Sông Hương", "province_id": "p", "category": "river", "latitude": 16.47, "longitude": 107.58},
                {"title": "Sông Hương", "province_id": "other", "category": "river", "latitude": 16.4701, "longitude": 107.5801},
            )
        )

    def test_official_url_rejects_ssrf_targets(self):
        for url in (
            "file:///etc/passwd",
            "http://localhost/admin",
            "http://127.0.0.1/admin",
            "http://10.0.0.1/metadata",
            "http://[::1]/admin",
        ):
            with self.assertRaises(ValueError):
                validate_official_url(url)
        self.assertEqual(validate_official_url("https://example.com/about"), "https://example.com/about")

    def test_official_metadata_rejects_non_html_and_oversized_bodies(self):
        async def run():
            async def handler(request: httpx.Request) -> httpx.Response:
                if request.url.path == "/json":
                    return httpx.Response(200, headers={"content-type": "application/json"}, json={"ok": True})
                return httpx.Response(200, headers={"content-type": "text/html"}, content=b"x" * (1024 * 1024 + 1))

            client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
            try:
                with self.assertRaises(ValueError):
                    await extract_official_metadata("https://example.com/json", client)
                with self.assertRaises(ValueError):
                    await extract_official_metadata("https://example.com/large", client)
            finally:
                await client.aclose()

        asyncio.run(run())

    def test_official_metadata_extracts_safe_html_fields(self):
        async def run():
            body = b"""
            <html><head><title>Huong River</title>
            <meta name='description' content='A river in Hue.'>
            <script type='application/ld+json'>{\"@type\":\"Place\",\"name\":\"Huong River\",\"address\":\"Hue\"}</script>
            </head><body></body></html>
            """

            async def handler(request: httpx.Request) -> httpx.Response:
                return httpx.Response(200, headers={"content-type": "text/html; charset=utf-8"}, content=body)

            client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
            try:
                result = await extract_official_metadata("https://example.com/about", client)
            finally:
                await client.aclose()
            self.assertEqual(result.title, "Huong River")
            self.assertEqual(result.description, "A river in Hue.")
            self.assertEqual(result.name, "Huong River")

        asyncio.run(run())

    def test_source_requests_retry_rate_limit_without_duplicate_data(self):
        async def run():
            calls = 0

            async def handler(request: httpx.Request) -> httpx.Response:
                nonlocal calls
                calls += 1
                if calls == 1:
                    return httpx.Response(429, headers={"retry-after": "0"})
                return httpx.Response(
                    200,
                    json={"elements": [{"type": "node", "id": 123, "tags": {"name": "Sông Hương"}}]},
                )

            async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
                facts = await collect_osm_facts(client, ["osm:node:123"])
            self.assertEqual(calls, 2)
            self.assertEqual([fact.fact_id for fact in facts], ["osm.name"])

        asyncio.run(run())

    def test_osm_collection_falls_back_after_transport_failure(self):
        async def run():
            seen_urls = []

            async def handler(request: httpx.Request) -> httpx.Response:
                seen_urls.append(str(request.url))
                if request.url.host == "primary.example":
                    raise httpx.ConnectError("primary unavailable", request=request)
                return httpx.Response(
                    200,
                    json={"elements": [{"type": "node", "id": 123, "tags": {"name": "Fallback"}}]},
                )

            async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
                with patch.object(
                    osm_source,
                    "OVERPASS_URLS",
                    (
                        "https://primary.example/api/interpreter",
                        "https://fallback.example/api/interpreter",
                    ),
                ):
                    facts = await collect_osm_facts(client, ["osm:node:123"])

            self.assertEqual(seen_urls[:3], ["https://primary.example/api/interpreter"] * 3)
            self.assertEqual(seen_urls[3:], ["https://fallback.example/api/interpreter"])
            self.assertEqual([fact.value for fact in facts], ["Fallback"])

        asyncio.run(run())


if __name__ == "__main__":
    unittest.main()
