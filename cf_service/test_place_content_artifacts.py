import csv
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.place_content_backfill.artifacts import (
    ArtifactStore,
    SecretArtifactError,
)


class PlaceContentArtifactsTest(unittest.TestCase):
    def test_utf8_jsonl_append_iteration_and_resume(self):
        with tempfile.TemporaryDirectory() as tmp:
            store = ArtifactStore(Path(tmp), "20260810-120000-abcdef12")
            store.append_jsonl(
                "baseline",
                {"place_id": "place-1", "input_hash": "hash-1", "name": "Sông Hương"},
            )
            store.append_jsonl(
                "baseline",
                {"place_id": "place-2", "input_hash": "hash-2", "name": "Chùa Thiên Mụ"},
            )
            self.assertEqual(
                [row["name"] for row in store.iter_stream("baseline")],
                ["Sông Hương", "Chùa Thiên Mụ"],
            )
            self.assertEqual(
                store.completed_place_ids("baseline", input_hash="hash-1"),
                {"place-1"},
            )

    def test_manifest_replacement_is_atomic_and_fsynced(self):
        with tempfile.TemporaryDirectory() as tmp:
            store = ArtifactStore(Path(tmp), "20260810-120000-abcdef12")
            with patch("scripts.place_content_backfill.artifacts.os.replace", wraps=os.replace) as replace:
                with patch("scripts.place_content_backfill.artifacts.os.fsync", wraps=os.fsync) as fsync:
                    store.write_manifest({"run_id": "20260810-120000-abcdef12", "count": 2})
            self.assertTrue(replace.called)
            self.assertGreaterEqual(fsync.call_count, 2)
            manifest = json.loads(store.path("manifest").read_text(encoding="utf-8"))
            self.assertEqual(manifest["count"], 2)

    def test_review_csv_round_trip_is_streaming(self):
        with tempfile.TemporaryDirectory() as tmp:
            store = ArtifactStore(Path(tmp), "20260810-120000-abcdef12")
            rows = (
                {"place_id": "place-1", "current_name": "Sông Hương", "reviewer_decision": "approve"},
                {"place_id": "place-2", "current_name": "Chùa Thiên Mụ", "reviewer_decision": "edit"},
            )
            store.export_review_csv(
                rows,
                fieldnames=("current_name", "place_id", "reviewer_decision"),
            )
            imported = list(store.iter_review_csv())
            self.assertEqual(imported[0]["current_name"], "Sông Hương")
            self.assertEqual(imported[1]["reviewer_decision"], "edit")
            with store.path("needs-review").open(encoding="utf-8", newline="") as handle:
                self.assertEqual(next(csv.reader(handle)), ["current_name", "place_id", "reviewer_decision"])

    def test_recursive_secret_shaped_keys_and_values_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            store = ArtifactStore(Path(tmp), "20260810-120000-abcdef12")
            with self.assertRaises(SecretArtifactError):
                store.append_jsonl("sources", {"headers": {"Authorization": "Bearer secret"}})
            with self.assertRaises(SecretArtifactError):
                store.append_jsonl("sources", {"value": "SUPABASE_SERVICE_ROLE_KEY=not-placeholder"})


if __name__ == "__main__":
    unittest.main()
