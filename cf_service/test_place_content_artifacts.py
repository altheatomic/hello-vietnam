import json
import tempfile
import unittest
from pathlib import Path

from scripts.place_content_backfill.artifacts import ArtifactStore
from scripts.place_content_backfill.models import Proposal, RunManifest
from scripts.place_content_backfill.constants import APPROVED_PROVINCES


class PlaceContentArtifactsTest(unittest.TestCase):
    def _manifest(self):
        return RunManifest.new(list(APPROVED_PROVINCES))

    def test_jsonl_append_read_and_resume(self):
        with tempfile.TemporaryDirectory() as directory:
            store = ArtifactStore(Path(directory), "run-1")
            store.append("baseline", {"place_id": "p1", "name": "Địa điểm"})
            store.append("baseline", {"place_id": "p2", "name": "Place 2"})
            self.assertEqual(store.read_all("baseline")[0]["name"], "Địa điểm")
            self.assertEqual(store.completed_place_ids("baseline"), {"p1", "p2"})

    def test_manifest_replacement_is_valid_json(self):
        with tempfile.TemporaryDirectory() as directory:
            store = ArtifactStore(Path(directory), "run-1")
            store.write_manifest(self._manifest())
            first = json.loads((store.path / "manifest.json").read_text(encoding="utf-8"))
            store.write_manifest(self._manifest().model_copy(update={"status": "collecting"}))
            second = json.loads((store.path / "manifest.json").read_text(encoding="utf-8"))
            self.assertNotEqual(first["status"], second["status"])

    def test_secret_shaped_payload_is_rejected_recursively(self):
        with tempfile.TemporaryDirectory() as directory:
            store = ArtifactStore(Path(directory), "run-1")
            with self.assertRaises(ValueError):
                store.append("sources", {"nested": {"DEEPSEEK_API_KEY": "secret"}})
            with self.assertRaises(ValueError):
                store.append("sources", {"url": "postgresql://user:password@example"})

    def test_review_csv_has_operator_columns(self):
        with tempfile.TemporaryDirectory() as directory:
            store = ArtifactStore(Path(directory), "run-1")
            proposal = Proposal(
                place_id="p1",
                province_id=APPROVED_PROVINCES[0],
                baseline_hash="hash",
                current_name_vi="Tên cũ",
                proposed_name_vi="Tên mới",
                current_name_en="Old name",
                proposed_name_en="New name",
            )
            path = store.write_review_csv([proposal])
            text = path.read_text(encoding="utf-8")
            self.assertIn("reviewer_decision", text)
            self.assertIn("p1", text)

    def test_replace_stream_is_idempotent_for_revalidation(self):
        with tempfile.TemporaryDirectory() as directory:
            store = ArtifactStore(Path(directory), "run-1")
            store.append("approved", {"place_id": "p1", "value": "old"})
            store.replace_stream("approved", [{"place_id": "p2", "value": "new"}])
            self.assertEqual(store.read_all("approved"), [{"place_id": "p2", "value": "new"}])


if __name__ == "__main__":
    unittest.main()
