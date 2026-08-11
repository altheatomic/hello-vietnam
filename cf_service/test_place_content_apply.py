import asyncio
from datetime import datetime, timezone
import unittest

from scripts.place_content_backfill.constants import APPROVED_PROVINCES
from scripts.place_content_backfill.models import (
    BaselineRecord,
    GeneratedContent,
    Proposal,
    TranslationBaseline,
    ValidationResult,
)
from scripts.place_content_backfill.repository import (
    _live_hash_payload,
    apply_approved_batch,
    editable_hash,
    rollback_applied_batch,
)


def _words(prefix: str, count: int) -> str:
    return " ".join(f"{prefix}{index}" for index in range(count))


class _Artifact:
    def __init__(self):
        self.values = []

    def append(self, stream, value):
        self.values.append((stream, value))


class _Transaction:
    def __init__(self, owner):
        self.owner = owner

    async def __aenter__(self):
        self.owner.transaction_started = True
        return self

    async def __aexit__(self, exc_type, exc, tb):
        self.owner.rolled_back = exc is not None
        self.owner.committed = exc is None
        return False


class _Connection:
    def __init__(self, baseline, *, missing_translation=False, changed=False, fail_update=False):
        self.baseline = baseline
        self.place = {
            "id_place": baseline.place_id,
            "id_province": baseline.province_id,
            "name": baseline.name,
            "short_description": baseline.short_description,
            "detailed_description": baseline.detailed_description,
            "created_at": baseline.created_at,
            "updated_at": baseline.updated_at,
        }
        if changed:
            self.place["name"] = "Changed by admin"
        self.translations = [
            {
                "id": baseline.vi.id,
                "place_id": baseline.place_id,
                "lang_code": "vi",
                "name": baseline.vi.name,
                "description": baseline.vi.description,
                "detailed_description": baseline.vi.detailed_description,
                "created_at": baseline.vi.created_at,
                "updated_at": baseline.vi.updated_at,
            },
            {
                "id": baseline.en.id,
                "place_id": baseline.place_id,
                "lang_code": "en",
                "name": baseline.en.name,
                "description": baseline.en.description,
                "detailed_description": baseline.en.detailed_description,
                "created_at": baseline.en.created_at,
                "updated_at": baseline.en.updated_at,
            },
        ]
        if missing_translation:
            self.translations.pop()
        self.fail_update = fail_update
        self.transaction_started = False
        self.committed = False
        self.rolled_back = False
        self.execute_count = 0

    def transaction(self):
        return _Transaction(self)

    async def fetchrow(self, query, *args):
        if "FROM public.place" in query:
            return dict(self.place)
        raise AssertionError(f"unexpected fetchrow: {query}")

    async def fetch(self, query, *args):
        if "FROM public.place_translation" in query:
            return [dict(value) for value in self.translations]
        raise AssertionError(f"unexpected fetch: {query}")

    async def execute(self, query, *args):
        self.execute_count += 1
        if self.fail_update and self.execute_count == 3:
            raise RuntimeError("simulated final update failure")
        normalized = " ".join(query.split())
        if normalized.startswith("UPDATE public.place SET"):
            self.place.update({"name": args[0], "short_description": args[1], "detailed_description": args[2]})
        elif normalized.startswith("UPDATE public.place_translation SET"):
            name, description, detailed_description, place_id, lang_code = args
            for row in self.translations:
                if row["place_id"] == place_id and row["lang_code"] == lang_code:
                    row.update({"name": name, "description": description, "detailed_description": detailed_description})
                    break
        else:
            raise AssertionError(f"unexpected execute: {query}")
        return "UPDATE 1"


def _baseline() -> BaselineRecord:
    return BaselineRecord(
        place_id="place-1",
        province_id=APPROVED_PROVINCES[0],
        name="Sông Hương",
        short_description="Old place short",
        detailed_description="Old place detail",
        created_at="created",
        updated_at="updated",
        vi=TranslationBaseline(
            id="vi-1", place_id="place-1", lang_code="vi", name="Sông Hương",
            description="Old vi short", detailed_description="Old vi detail", created_at="v-created", updated_at="v-updated",
        ),
        en=TranslationBaseline(
            id="en-1", place_id="place-1", lang_code="en", name="Huong River",
            description="Old en short", detailed_description="Old en detail", created_at="e-created", updated_at="e-updated",
        ),
    )


def _proposal(baseline, *, decision="approve"):
    content = GeneratedContent(
        short_description_vi=_words("vi", 20),
        detailed_description_vi=_words("vdetail", 90),
        short_description_en=_words("en", 20),
        detailed_description_en=_words("edetail", 90),
        confidence=0.95,
    )
    return Proposal(
        place_id=baseline.place_id,
        province_id=baseline.province_id,
        baseline_hash=editable_hash(baseline),
        current_name_vi=baseline.vi.name,
        proposed_name_vi=baseline.vi.name,
        current_name_en=baseline.en.name,
        proposed_name_en=baseline.en.name,
        content=content,
        reviewer_decision=decision,
        validation=ValidationResult(valid=True),
    )


class PlaceContentApplyTest(unittest.TestCase):
    def test_live_datetime_hash_is_serializable(self):
        baseline = _baseline()
        place = {
            "name": baseline.name,
            "short_description": baseline.short_description,
            "detailed_description": baseline.detailed_description,
            "created_at": datetime(2026, 1, 1, tzinfo=timezone.utc),
            "updated_at": datetime(2026, 1, 2, tzinfo=timezone.utc),
        }
        translations = {
            "vi": {
                "name": baseline.vi.name,
                "description": baseline.vi.description,
                "detailed_description": baseline.vi.detailed_description,
                "created_at": datetime(2026, 1, 3, tzinfo=timezone.utc),
                "updated_at": datetime(2026, 1, 4, tzinfo=timezone.utc),
            },
            "en": {
                "name": baseline.en.name,
                "description": baseline.en.description,
                "detailed_description": baseline.en.detailed_description,
                "created_at": datetime(2026, 1, 5, tzinfo=timezone.utc),
                "updated_at": datetime(2026, 1, 6, tzinfo=timezone.utc),
            },
        }

        self.assertIsInstance(editable_hash(_live_hash_payload(place, translations)), str)

    def test_successful_apply_writes_nine_value_rollback_payload(self):
        async def run():
            baseline = _baseline()
            conn = _Connection(baseline)
            artifact = _Artifact()
            result = await apply_approved_batch(
                conn,
                [_proposal(baseline)],
                {baseline.place_id: baseline},
                artifact_store=artifact,
                confirm=True,
            )
            self.assertEqual(result.applied_place_ids, ("place-1",))
            self.assertTrue(conn.committed)
            rollback = [value for stream, value in artifact.values if stream == "rollback"][0]
            self.assertEqual(set(rollback["prior"]["place"]), {"name", "short_description", "detailed_description"})
            self.assertEqual(set(rollback["prior"]["vi"]), {"name", "description", "detailed_description"})
            self.assertEqual(set(rollback["prior"]["en"]), {"name", "description", "detailed_description"})

        asyncio.run(run())

    def test_safety_guards_happen_before_transaction(self):
        async def run():
            baseline = _baseline()
            conn = _Connection(baseline)
            with self.assertRaises(ValueError):
                await apply_approved_batch(conn, [_proposal(baseline)], {baseline.place_id: baseline}, confirm=False)
            self.assertFalse(conn.transaction_started)
            unapproved = _proposal(baseline, decision="reject")
            with self.assertRaises(ValueError):
                await apply_approved_batch(conn, [unapproved], {baseline.place_id: baseline}, confirm=True)
            self.assertFalse(conn.transaction_started)

        asyncio.run(run())

    def test_hash_conflict_missing_translation_and_update_failure_roll_back(self):
        async def run():
            baseline = _baseline()
            for conn in (_Connection(baseline, changed=True), _Connection(baseline, missing_translation=True), _Connection(baseline, fail_update=True)):
                artifact = _Artifact()
                with self.assertRaises(Exception):
                    await apply_approved_batch(conn, [_proposal(baseline)], {baseline.place_id: baseline}, artifact_store=artifact, confirm=True)
                self.assertTrue(conn.rolled_back)
                self.assertFalse(any(stream == "applied" for stream, _ in artifact.values))

        asyncio.run(run())

    def test_batch_size_and_rollback_preserve_later_edits(self):
        async def run():
            baseline = _baseline()
            conn = _Connection(baseline)
            artifact = _Artifact()
            applied = await apply_approved_batch(conn, [_proposal(baseline)], {baseline.place_id: baseline}, artifact_store=artifact, confirm=True)
            entry = [value for stream, value in artifact.values if stream == "rollback"][0]
            restored = await rollback_applied_batch(conn, [entry], artifact_store=artifact, confirm=True, all_entries=True)
            self.assertEqual(restored, ("place-1",))

            # A second apply followed by a later edit must be refused.
            conn = _Connection(baseline)
            artifact = _Artifact()
            await apply_approved_batch(conn, [_proposal(baseline)], {baseline.place_id: baseline}, artifact_store=artifact, confirm=True)
            entry = [value for stream, value in artifact.values if stream == "rollback"][0]
            conn.place["name"] = "Edited after apply"
            with self.assertRaises(ValueError):
                await rollback_applied_batch(conn, [entry], artifact_store=artifact, confirm=True, all_entries=True)

            too_many = [_proposal(baseline) for _ in range(51)]
            with self.assertRaises(ValueError):
                await apply_approved_batch(_Connection(baseline), too_many, {baseline.place_id: baseline}, confirm=True)

        asyncio.run(run())


if __name__ == "__main__":
    unittest.main()
