import asyncio
import json
import subprocess
import sys
import unittest
from unittest.mock import Mock

import httpx

from scripts.place_content_backfill.models import BaselineRecord
from scripts.place_content_backfill.sources.osm import (
    build_osm_batches,
    collect_osm_facts,
    parse_osm_identity,
)
from scripts.place_content_backfill.sources.website import (
    ResponseLimitExceeded,
    collect_official_site,
    official_site_fact_id,
    validate_public_http_url,
)
from scripts.place_content_backfill.sources.wikimedia import (
    collect_wikimedia_facts,
    parse_wikimedia_link,
    validate_wikimedia_evidence,
)


def record(**overrides):
    values = {
        "place_id": "place-1",
        "province_id": "b5f3ef5e-dc49-4482-88e3-a8048cb32639",
        "status": "active",
        "vi_name": "Chùa Thiên Mụ",
        "vi_short_description": "Mô tả ngắn",
        "input_hash": "baseline-hash",
        "source": "osm",
        "source_place_id": "osm:node:1",
        "latitude": 16.4536,
        "longitude": 107.5447,
        "subcategory_name": "Chùa",
        "subcategory_category": "culture",
        "website": "https://example.org/place",
    }
    values.update(overrides)
    return BaselineRecord(**values)


class PlaceContentSourcesTest(unittest.IsolatedAsyncioTestCase):
    def test_osm_identity_accepts_only_supported_kinds(self):
        self.assertEqual(parse_osm_identity("osm:node:123"), ("node", 123))
        self.assertEqual(parse_osm_identity("osm:way:456"), ("way", 456))
        self.assertEqual(parse_osm_identity("osm:relation:789"), ("relation", 789))
        with self.assertRaises(ValueError):
            parse_osm_identity("osm:area:123")
        with self.assertRaises(ValueError):
            parse_osm_identity("123")

    def test_osm_batches_by_kind_and_caps_each_batch_at_100(self):
        identities = [f"osm:node:{i}" for i in range(201)] + [f"osm:way:{i}" for i in range(3)]
        batches = list(build_osm_batches(identities, max_ids=100))
        self.assertEqual([len(batch[1]) for batch in batches], [100, 100, 1, 3])
        self.assertEqual([batch[0] for batch in batches], ["node", "node", "node", "way"])

    async def test_osm_mock_transport_collects_stable_fact_ids(self):
        async def handler(request: httpx.Request) -> httpx.Response:
            body = json.loads(request.content.decode("utf-8"))
            self.assertIn("node(id:1,2)", body["data"])
            return httpx.Response(
                200,
                json={
                    "elements": [
                        {"type": "node", "id": 1, "lat": 16.4, "lon": 107.5, "tags": {"name": "Thiên Mụ"}},
                        {"type": "node", "id": 2, "lat": 16.5, "lon": 107.6, "tags": {"name:en": "Thien Mu"}},
                    ]
                },
            )

        transport = httpx.MockTransport(handler)
        async with httpx.AsyncClient(transport=transport) as client:
            facts, warnings = await collect_osm_facts(
                record(),
                client=client,
                source_ids=("osm:node:1", "osm:node:2"),
                max_ids=100,
            )
        self.assertFalse(warnings)
        self.assertEqual(
            [fact.fact_id for fact in facts],
            ["osm:node:1:name", "osm:node:2:name:en"],
        )

    def test_wikimedia_links_require_explicit_identifiers(self):
        self.assertEqual(parse_wikimedia_link("Q12345"), ("wikidata", "Q12345"))
        self.assertEqual(parse_wikimedia_link("vi:Chùa_Thiên_Mụ"), ("wikipedia", "vi:Chùa_Thiên_Mụ"))
        self.assertIsNone(parse_wikimedia_link("Chùa Thiên Mụ"))
        self.assertIsNone(parse_wikimedia_link("https://example.org/not-wikimedia"))

    def test_wikimedia_corroboration_rejects_province_type_and_coordinate_conflicts(self):
        base = record()
        accepted, warnings = validate_wikimedia_evidence(
            base,
            {"province_id": base.province_id, "type": "pagoda", "latitude": 16.4537, "longitude": 107.5448},
        )
        self.assertTrue(accepted)
        self.assertFalse(warnings)
        for evidence in (
            {"province_id": "094014a7-b8f6-481a-bbce-5ed6cdd457c5"},
            {"type": "airport"},
            {"latitude": 21.0, "longitude": 105.0},
        ):
            accepted, warnings = validate_wikimedia_evidence(base, evidence)
            self.assertFalse(accepted)
            self.assertTrue(warnings)

    async def test_wikimedia_mock_transport_accepts_explicit_page_link(self):
        async def handler(request: httpx.Request) -> httpx.Response:
            self.assertIn("vi.wikipedia.org", str(request.url))
            return httpx.Response(
                200,
                json={
                    "title": "Chùa Thiên Mụ",
                    "province_id": "b5f3ef5e-dc49-4482-88e3-a8048cb32639",
                    "type": "pagoda",
                    "latitude": 16.4536,
                    "longitude": 107.5447,
                    "extract": "A corroborating description.",
                },
            )

        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            facts, warnings = await collect_wikimedia_facts(
                record(),
                links=("vi:Chùa_Thiên_Mụ",),
                client=client,
            )
        self.assertEqual(len(facts), 1)
        self.assertEqual(facts[0].source_type, "wikimedia")
        self.assertFalse(warnings)

    def test_official_site_url_validation_rejects_private_destinations(self):
        public_resolver = lambda host: ["93.184.216.34"]
        private_resolver = lambda host: ["192.168.1.10"]
        self.assertEqual(
            validate_public_http_url("https://example.org", resolve_host=public_resolver),
            "https://example.org",
        )
        for url in ("file:///tmp/a", "ftp://example.org", "http://localhost", "http://127.0.0.1"):
            with self.assertRaises(ValueError):
                validate_public_http_url(url, resolve_host=public_resolver)
        with self.assertRaises(ValueError):
            validate_public_http_url("https://example.org", resolve_host=private_resolver)

    async def test_official_site_rejects_redirects_non_html_and_body_over_cap(self):
        async def redirect_handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(302, headers={"Location": "http://127.0.0.1/private"})

        async with httpx.AsyncClient(transport=httpx.MockTransport(redirect_handler)) as client:
            with self.assertRaises(ValueError):
                await collect_official_site(
                    record(),
                    client=client,
                    enabled=True,
                    resolve_host=lambda host: ["93.184.216.34"] if host == "example.org" else ["127.0.0.1"],
                )

        async def non_html_handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(200, headers={"Content-Type": "application/json"}, content=b"{}")

        async with httpx.AsyncClient(transport=httpx.MockTransport(non_html_handler)) as client:
            with self.assertRaises(ValueError):
                await collect_official_site(
                    record(), client=client, enabled=True, resolve_host=lambda host: ["93.184.216.34"]
                )

        async def too_large_handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(200, headers={"Content-Type": "text/html"}, content=b"x" * (1024 * 1024 + 1))

        async with httpx.AsyncClient(transport=httpx.MockTransport(too_large_handler)) as client:
            with self.assertRaises(ResponseLimitExceeded):
                await collect_official_site(
                    record(), client=client, enabled=True, resolve_host=lambda host: ["93.184.216.34"]
                )

    async def test_official_site_is_default_off(self):
        handler = Mock(side_effect=AssertionError("network must not be called when disabled"))
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            facts, warnings = await collect_official_site(record(), client=client)
        self.assertFalse(facts)
        self.assertIn("disabled", " ".join(warnings))

    def test_official_site_fact_id_is_stable_across_worker_processes(self):
        source = (
            "from scripts.place_content_backfill.sources.website import official_site_fact_id;"
            "print(official_site_fact_id('https://example.org', 'baseline-hash'))"
        )
        first = subprocess.check_output([sys.executable, "-c", source], text=True).strip()
        second = subprocess.check_output([sys.executable, "-c", source], text=True).strip()
        self.assertEqual(first, second)


if __name__ == "__main__":
    unittest.main()
