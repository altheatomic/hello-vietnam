import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import tracemalloc
import unittest

from scripts.place_content_backfill.artifacts import ArtifactStore, ChunkSupervisor
from scripts.place_content_backfill.validators import find_near_duplicates_stream


RECORD_COUNT = 1533


def _fixed_text(index: int) -> str:
    token = f"{index:04d}{(index * 7919) % 100000:05d}"
    return " ".join(
        (
            f"place{token}",
            f"province{(index * 17) % 997:03d}",
            f"feature{(index * 31) % 991:03d}",
            f"evidence{(index * 43) % 983:03d}",
            f"locale{(index * 59) % 977:03d}",
            f"source{(index * 71) % 971:03d}",
        )
    )


class PlaceContentMemoryTest(unittest.TestCase):
    def test_1533_record_streaming_and_fresh_worker_regression(self):
        tracemalloc.start()
        try:
            with tempfile.TemporaryDirectory(prefix="place-content-memory-") as tmp:
                store = ArtifactStore(Path(tmp), "20260810-120000-abcdef12")
                for index in range(RECORD_COUNT):
                    place_id = f"place-{index:04d}"
                    text = _fixed_text(index)
                    store.append_jsonl(
                        "baseline",
                        {
                            "place_id": place_id,
                            "province_id": f"province-{index % 5}",
                            "input_hash": f"baseline-{index:04d}",
                            "fixed_payload": text,
                        },
                    )
                    store.append_jsonl(
                        "sources",
                        {
                            "place_id": place_id,
                            "baseline_input_hash": f"baseline-{index:04d}",
                            "facts": [{"fact_id": f"fact-{index:04d}", "claim": text}],
                        },
                    )
                    store.append_jsonl(
                        "proposals",
                        {
                            "place_id": place_id,
                            "proposal_hash": f"proposal-{index:04d}",
                            "en_long": text,
                        },
                    )

                self.assertEqual(
                    sum(1 for _ in store.iter_stream("baseline")),
                    RECORD_COUNT,
                )
                self.assertEqual(
                    sum(1 for _ in store.iter_stream("sources")),
                    RECORD_COUNT,
                )
                self.assertEqual(
                    sum(1 for _ in store.iter_stream("proposals")),
                    RECORD_COUNT,
                )

                store.export_review_csv(
                    (
                        {
                            "place_id": f"place-{index:04d}",
                            "province_id": f"province-{index % 5}",
                            "proposed_en_description": _fixed_text(index),
                            "reviewer_decision": "",
                        }
                        for index in range(RECORD_COUNT)
                    ),
                    fieldnames=(
                        "place_id",
                        "province_id",
                        "proposed_en_description",
                        "reviewer_decision",
                    ),
                )
                self.assertEqual(
                    sum(1 for _ in store.iter_review_csv()),
                    RECORD_COUNT,
                )

                duplicate_ids = find_near_duplicates_stream(
                    (
                        (row["place_id"], row["en_long"])
                        for row in store.iter_stream("proposals")
                    ),
                    threshold=0.92,
                    chunk_size=200,
                    sqlite_path=store.run_dir / "duplicate-signatures.sqlite3",
                )
                self.assertEqual(duplicate_ids, {})

                worker_code = (
                    "import json, os, pathlib, sys\n"
                    "status = pathlib.Path(sys.argv[1])\n"
                    "ids = sys.argv[2:]\n"
                    "status.write_text(json.dumps({'pid': os.getpid(), 'place_ids': ids, 'finished': True}) + '\\n', encoding='utf-8')\n"
                )
                place_ids = (f"place-{index:04d}" for index in range(6))
                supervisor = ChunkSupervisor(store)
                launched = supervisor.run_serial(
                    place_ids,
                    2,
                    lambda chunk, status_path: (
                        sys.executable,
                        "-c",
                        worker_code,
                        str(status_path),
                        *chunk,
                    ),
                )
                self.assertEqual(launched, 3)
                statuses = [
                    json.loads(path.read_text(encoding="utf-8"))
                    for path in sorted(store.run_dir.glob("worker-*.status.json"))
                ]
                self.assertEqual(len(statuses), 3)
                self.assertEqual(len({status["pid"] for status in statuses}), 3)
                self.assertTrue(all(status["finished"] for status in statuses))
                for status in statuses:
                    if os.name == "nt":
                        self.assertGreater(status["pid"], 0)
                    else:
                        with self.assertRaises(ProcessLookupError):
                            os.kill(status["pid"], 0)
                self.assertFalse(hasattr(supervisor, "results"))
                self.assertIs(supervisor.artifact_store, store)

                launched_on_resume = supervisor.run_serial(
                    (f"place-{index:04d}" for index in range(6)),
                    2,
                    lambda chunk, status_path: (
                        sys.executable,
                        "-c",
                        worker_code,
                        str(status_path),
                        *chunk,
                    ),
                    completed_ids={f"place-{index:04d}" for index in range(6)},
                )
                self.assertEqual(launched_on_resume, 0)
                self.assertEqual(
                    [
                        json.loads(path.read_text(encoding="utf-8"))["pid"]
                        for path in sorted(store.run_dir.glob("worker-*.status.json"))
                    ],
                    [status["pid"] for status in statuses],
                )

            _, peak_bytes = tracemalloc.get_traced_memory()
            self.assertLess(
                peak_bytes,
                256 * 1024 * 1024,
                f"peak traced allocation exceeded 256 MiB: {peak_bytes}",
            )
        finally:
            tracemalloc.stop()


if __name__ == "__main__":
    unittest.main()
