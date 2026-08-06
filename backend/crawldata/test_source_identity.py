import unittest
import uuid

from source_identity import (
    canonical_source_url,
    deterministic_content_uuid,
    legacy_place_uuid,
    source_external_id,
)


class SourceIdentityTest(unittest.TestCase):
    def test_wikipedia_url_discards_fragment_and_tracking_query(self):
        self.assertEqual(
            canonical_source_url(
                "https://en.wikipedia.org/wiki/Hoi_An?utm_source=x#History"
            ),
            "https://en.wikipedia.org/wiki/Hoi_An",
        )

    def test_same_identity_produces_same_uuid(self):
        external_id = source_external_id(
            "wikipedia", "https://en.wikipedia.org/wiki/Hoi_An"
        )
        first = deterministic_content_uuid("activity", "wikipedia", external_id)
        second = deterministic_content_uuid("activity", "wikipedia", external_id)
        self.assertEqual(first, second)

    def test_content_types_have_distinct_uuid_namespaces(self):
        external_id = source_external_id(
            "wikipedia", "https://en.wikipedia.org/wiki/Hoi_An"
        )
        self.assertNotEqual(
            deterministic_content_uuid("activity", "wikipedia", external_id),
            deterministic_content_uuid("culture", "wikipedia", external_id),
        )

    def test_legacy_place_seed_uuid_remains_compatible(self):
        expected = str(
            uuid.uuid5(
                uuid.UUID("9a73fa2d-48f2-4d14-8f32-8845154a6e9a"),
                "osm:osm:node:123",
            )
        )
        self.assertEqual(legacy_place_uuid("osm", "osm:node:123"), expected)


if __name__ == "__main__":
    unittest.main()
