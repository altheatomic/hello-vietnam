"""Crash-safe, secret-free JSONL checkpoint artifacts."""

from __future__ import annotations

import csv
import json
import os
import re
import tempfile
from pathlib import Path
from typing import Any

from pydantic import BaseModel

from .constants import ARTIFACT_STREAMS, SECRET_KEY_MARKERS
from .models import Proposal, RunManifest, model_to_jsonable


_POSTGRES_URL = re.compile(r"\b(?:postgres(?:ql)?|postgresql\+\w+)://", re.I)
_BEARER = re.compile(r"\bbearer\s+[A-Za-z0-9._~+/=-]+", re.I)


class ArtifactStore:
    def __init__(self, root: Path, run_id: str) -> None:
        self.root = Path(root)
        self.run_id = run_id
        self.path = self.root / run_id
        self.path.mkdir(parents=True, exist_ok=True)

    def write_manifest(self, manifest: RunManifest) -> None:
        self._reject_secrets(manifest.model_dump(mode="json"))
        self._atomic_write_json(self.path / "manifest.json", manifest.model_dump(mode="json"))

    def read_manifest(self) -> RunManifest:
        with (self.path / "manifest.json").open("r", encoding="utf-8") as handle:
            return RunManifest.model_validate(json.load(handle))

    def append(self, stream: str, value: BaseModel | dict[str, Any]) -> None:
        filename = self._stream_filename(stream)
        payload = model_to_jsonable(value)
        self._reject_secrets(payload)
        line = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        target = self.path / filename
        with target.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(line + "\n")
            handle.flush()
            os.fsync(handle.fileno())

    def replace_stream(self, stream: str, values: list[BaseModel | dict[str, Any]]) -> None:
        """Atomically replace a checkpoint stream during deterministic revalidation."""

        filename = self._stream_filename(stream)
        target = self.path / filename
        temporary = self._temporary_path(target)
        try:
            with temporary.open("w", encoding="utf-8", newline="\n") as handle:
                for value in values:
                    payload = model_to_jsonable(value)
                    self._reject_secrets(payload)
                    line = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
                    handle.write(line + "\n")
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, target)
        finally:
            if temporary.exists():
                temporary.unlink()

    def read_all(self, stream: str) -> list[dict[str, Any]]:
        target = self.path / self._stream_filename(stream)
        if not target.exists():
            return []
        values: list[dict[str, Any]] = []
        with target.open("r", encoding="utf-8") as handle:
            for line_number, line in enumerate(handle, start=1):
                if not line.strip():
                    continue
                try:
                    value = json.loads(line)
                except json.JSONDecodeError as exc:
                    raise ValueError(f"invalid {stream}.jsonl line {line_number}") from exc
                if not isinstance(value, dict):
                    raise ValueError(f"{stream}.jsonl line {line_number} is not an object")
                values.append(value)
        return values

    def completed_place_ids(self, stream: str) -> set[str]:
        result: set[str] = set()
        for value in self.read_all(stream):
            place_id = value.get("place_id") or value.get("id_place")
            if place_id:
                result.add(str(place_id))
        return result

    def write_review_csv(self, proposals: list[Proposal]) -> Path:
        target = self.path / "needs-review.csv"
        fieldnames = [
            "place_id",
            "province_id",
            "current_name_vi",
            "proposed_name_vi",
            "current_name_en",
            "proposed_name_en",
            "short_description_vi",
            "detailed_description_vi",
            "short_description_en",
            "detailed_description_en",
            "validation_flags",
            "source_urls",
            "reviewer_decision",
            "reviewer_notes",
        ]
        temporary = self._temporary_path(target)
        try:
            with temporary.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(handle, fieldnames=fieldnames)
                writer.writeheader()
                for proposal in proposals:
                    content = proposal.content
                    validation = proposal.validation
                    writer.writerow(
                        {
                            "place_id": proposal.place_id,
                            "province_id": proposal.province_id,
                            "current_name_vi": proposal.current_name_vi or "",
                            "proposed_name_vi": proposal.proposed_name_vi or "",
                            "current_name_en": proposal.current_name_en or "",
                            "proposed_name_en": proposal.proposed_name_en or "",
                            "short_description_vi": content.short_description_vi if content else "",
                            "detailed_description_vi": content.detailed_description_vi if content else "",
                            "short_description_en": content.short_description_en if content else "",
                            "detailed_description_en": content.detailed_description_en if content else "",
                            "validation_flags": ";".join(validation.flags if validation else ()),
                            "source_urls": ";".join(proposal.source_urls),
                            "reviewer_decision": proposal.reviewer_decision or "",
                            "reviewer_notes": proposal.reviewer_notes or "",
                        }
                    )
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, target)
        finally:
            if temporary.exists():
                temporary.unlink()
        return target

    def _stream_filename(self, stream: str) -> str:
        if stream not in ARTIFACT_STREAMS:
            raise ValueError(f"unknown artifact stream: {stream}")
        return f"{stream}.jsonl"

    def _atomic_write_json(self, target: Path, payload: Any) -> None:
        temporary = self._temporary_path(target)
        try:
            with temporary.open("w", encoding="utf-8", newline="\n") as handle:
                json.dump(payload, handle, ensure_ascii=False, sort_keys=True, indent=2)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, target)
        finally:
            if temporary.exists():
                temporary.unlink()

    def _temporary_path(self, target: Path) -> Path:
        descriptor, name = tempfile.mkstemp(prefix=f".{target.name}.", dir=self.path)
        os.close(descriptor)
        return Path(name)

    @classmethod
    def _reject_secrets(cls, value: Any, path: str = "root") -> None:
        if isinstance(value, dict):
            for key, nested in value.items():
                normalized = re.sub(r"[^a-z0-9]", "", str(key).lower())
                if any(marker.replace("_", "") in normalized for marker in SECRET_KEY_MARKERS):
                    raise ValueError(f"secret-shaped artifact field: {path}.{key}")
                cls._reject_secrets(nested, f"{path}.{key}")
            return
        if isinstance(value, (list, tuple)):
            for index, nested in enumerate(value):
                cls._reject_secrets(nested, f"{path}[{index}]")
            return
        if isinstance(value, str):
            if _POSTGRES_URL.search(value) or _BEARER.search(value):
                raise ValueError(f"secret-shaped artifact value: {path}")
            for environment_name in (
                "DEEPSEEK_API_KEY",
                "SUPABASE_SERVICE_ROLE_KEY",
                "DATABASE_URL",
            ):
                secret = os.environ.get(environment_name)
                if secret and len(secret) > 8 and secret in value:
                    raise ValueError(f"environment secret found in artifact: {path}")
