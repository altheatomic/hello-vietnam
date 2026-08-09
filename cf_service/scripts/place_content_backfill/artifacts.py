from __future__ import annotations

import csv
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
from typing import Any, Callable, Iterable, Iterator, Mapping, Sequence

from .constants import ARTIFACT_FILENAMES, REVIEW_CSV_FIELDS


class SecretArtifactError(ValueError):
    """Raised before a secret-shaped key or value can enter an artifact."""


class WorkerFailure(RuntimeError):
    """Raised when a bounded worker exits unsuccessfully."""


_SECRET_KEY_RE = re.compile(
    r"(?:api[_-]?key|authorization|service[_-]?role|database[_-]?url|"
    r"password|secret|private[_-]?key|access[_-]?token)",
    re.IGNORECASE,
)
_SECRET_VALUE_RE = re.compile(
    r"(?:DEEPSEEK_API_KEY|SUPABASE_SERVICE_ROLE_KEY|DATABASE_URL)\s*=|"
    r"^Bearer\s+\S+|postgres(?:ql)?://[^\s:]+:[^\s@]+@",
    re.IGNORECASE,
)


def _reject_secrets(value: Any, path: str = "artifact") -> None:
    if isinstance(value, Mapping):
        for key, child in value.items():
            key_text = str(key)
            if _SECRET_KEY_RE.search(key_text):
                raise SecretArtifactError(f"secret-shaped key refused at {path}.{key_text}")
            _reject_secrets(child, f"{path}.{key_text}")
        return
    if isinstance(value, (list, tuple, set)):
        for index, child in enumerate(value):
            _reject_secrets(child, f"{path}[{index}]")
        return
    if isinstance(value, str) and _SECRET_VALUE_RE.search(value.strip()):
        raise SecretArtifactError(f"secret-shaped value refused at {path}")


def _json_dump(value: Any) -> str:
    _reject_secrets(value)
    try:
        return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    except (TypeError, ValueError) as exc:
        raise ValueError(f"artifact value is not JSON serializable: {exc}") from exc


def _fsync_directory(directory: Path) -> None:
    flags = os.O_RDONLY
    if hasattr(os, "O_DIRECTORY"):
        flags |= os.O_DIRECTORY
    descriptor = os.open(str(directory), flags)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


class ArtifactStore:
    """Streaming, append-only artifact storage for one backfill run."""

    def __init__(self, root: str | Path, run_id: str) -> None:
        self.root = Path(root)
        self.run_dir = self.root / run_id
        self.run_dir.mkdir(parents=True, exist_ok=True)

    def path(self, stream: str) -> Path:
        try:
            filename = ARTIFACT_FILENAMES[stream]
        except KeyError as exc:
            raise ValueError(f"unknown artifact stream: {stream}") from exc
        return self.run_dir / filename

    def append_jsonl(self, stream: str, record: Mapping[str, Any]) -> None:
        if not ARTIFACT_FILENAMES[stream].endswith(".jsonl"):
            raise ValueError(f"stream is not JSONL: {stream}")
        line = _json_dump(dict(record)) + "\n"
        destination = self.path(stream)
        with destination.open("a", encoding="utf-8", newline="") as handle:
            handle.write(line)
            handle.flush()
            os.fsync(handle.fileno())

    def iter_stream(self, stream: str) -> Iterator[dict[str, Any]]:
        if not ARTIFACT_FILENAMES[stream].endswith(".jsonl"):
            raise ValueError(f"stream is not JSONL: {stream}")
        destination = self.path(stream)
        if not destination.exists():
            return
        with destination.open("r", encoding="utf-8") as handle:
            for line_number, line in enumerate(handle, start=1):
                if not line.strip():
                    continue
                try:
                    record = json.loads(line)
                except json.JSONDecodeError as exc:
                    raise ValueError(f"invalid JSONL at {destination}:{line_number}") from exc
                if not isinstance(record, dict):
                    raise ValueError(f"JSONL record is not an object at {destination}:{line_number}")
                yield record

    def read_all(self, stream: str) -> list[dict[str, Any]]:
        """Test convenience only; production commands must use iter_stream."""

        return list(self.iter_stream(stream))

    def completed_place_ids(self, stream: str, input_hash: str | None = None) -> set[str]:
        completed: set[str] = set()
        for record in self.iter_stream(stream):
            place_id = record.get("place_id")
            if not place_id:
                continue
            if input_hash is None or record.get("input_hash", record.get("baseline_input_hash")) == input_hash:
                completed.add(str(place_id))
        return completed

    def write_manifest(self, manifest: Mapping[str, Any] | Any) -> None:
        payload = manifest.model_dump(mode="json") if hasattr(manifest, "model_dump") else dict(manifest)
        encoded = _json_dump(payload) + "\n"
        self.run_dir.mkdir(parents=True, exist_ok=True)
        descriptor, temporary_name = tempfile.mkstemp(
            prefix=".manifest-", suffix=".tmp", dir=self.run_dir
        )
        temporary_path = Path(temporary_name)
        try:
            with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as handle:
                handle.write(encoded)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary_path, self.path("manifest"))
            _fsync_directory(self.run_dir)
        finally:
            temporary_path.unlink(missing_ok=True)

    def export_review_csv(
        self,
        rows: Iterable[Mapping[str, Any]],
        fieldnames: Sequence[str] = REVIEW_CSV_FIELDS,
    ) -> None:
        destination = self.path("needs-review")
        fields = tuple(fieldnames)
        with destination.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
            writer.writeheader()
            for row in rows:
                _reject_secrets(row)
                writer.writerow({field: row.get(field, "") for field in fields})
            handle.flush()
            os.fsync(handle.fileno())

    def iter_review_csv(self) -> Iterator[dict[str, str]]:
        destination = self.path("needs-review")
        if not destination.exists():
            return
        with destination.open("r", encoding="utf-8", newline="") as handle:
            reader = csv.DictReader(handle)
            for row in reader:
                _reject_secrets(row)
                yield dict(row)


class ChunkSupervisor:
    """Run bounded workers serially and retain only status metadata."""

    def __init__(self, artifact_store: ArtifactStore) -> None:
        self.artifact_store = artifact_store

    def run_serial(
        self,
        place_ids: Iterable[str],
        chunk_size: int,
        command_builder: Callable[[tuple[str, ...], Path], Sequence[str]],
        completed_ids: Iterable[str] = (),
    ) -> int:
        if chunk_size <= 0:
            raise ValueError("chunk_size must be positive")
        completed = set(completed_ids)
        pending_chunk: list[str] = []
        worker_index = 0
        launched = 0

        def launch(chunk: tuple[str, ...], index: int) -> None:
            nonlocal launched
            status_path = self.artifact_store.run_dir / f"worker-{index:05d}.status.json"
            command = list(command_builder(chunk, status_path))
            if not command:
                raise ValueError("worker command must not be empty")
            result = subprocess.run(command, check=False, stdout=None, stderr=None)
            if result.returncode != 0:
                raise WorkerFailure(
                    f"worker {index} exited with status {result.returncode}; "
                    "prior checkpoints remain resumable"
                )
            launched += 1

        for place_id in place_ids:
            if str(place_id) in completed:
                continue
            pending_chunk.append(str(place_id))
            if len(pending_chunk) == chunk_size:
                launch(tuple(pending_chunk), worker_index)
                worker_index += 1
                pending_chunk.clear()
        if pending_chunk:
            launch(tuple(pending_chunk), worker_index)
        return launched
