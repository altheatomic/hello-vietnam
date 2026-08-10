import asyncio
import unittest

import httpx

from scripts.place_content_backfill.models import BaselineRecord, TranslationBaseline
from scripts.place_content_backfill.sources.osm import parse_osm_id
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


if __name__ == "__main__":
    unittest.main()
