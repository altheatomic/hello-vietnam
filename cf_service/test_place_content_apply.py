import asyncio
import tempfile
import unittest
from pathlib import Path

from scripts.place_content_backfill.artifacts import ArtifactStore
from scripts.place_content_backfill.constants import APPROVED_PROVINCES
from scripts.place_content_backfill.models import (
    BaselineRecord,
    GeneratedContent,
    NameDecision,
    Proposal,
    ReviewDecision,
    RunManifest,
    SourceFact,
    SourceSnapshot,
)
from scripts.place_content_backfill.repository import (
    ApplyConflict,
    ApplyIntegrityError,
    ApplyItem,
    RollbackConflict,
    apply_approved_batch,
    editable_hash,
    recover_post_commit_artifacts,
    rollback_applied_batch,
    validate_apply_selection,
)


PROVINCE_ID = next(iter(APPROVED_PROVINCES))


def words(count: int, prefix: str) -> str:
    return " ".join(f"{prefix}{index}" for index in range(count))


def baseline() -> BaselineRecord:
    record = BaselineRecord(
        place_id="place-1",
        province_id=PROVINCE_ID,
        status="active",
        vi_name="Chùa Thiên Mụ",
        vi_short_description="Mô tả ngắn",
        input_hash="baseline-hash",
        en_name="Thiên Mụ Pagoda",
        en_short_description="Short description",
        subcategory_name="Chùa",
        subcategory_category="culture",
        updated_at="2026-08-10T00:00:00+00:00",
        translation_updated_at_vi="2026-08-10T00:00:00+00:00",
        translation_updated_at_en="2026-08-10T00:00:00+00:00",
    )
    return record.model_copy(update={"input_hash": editable_hash(record)})


def source_snapshot() -> SourceSnapshot:
    return SourceSnapshot(
        place_id="place-1",
        baseline_input_hash=baseline().input_hash,
        facts=(
            SourceFact(
                fact_id="fact-1",
                source_type="osm",
                source_url="https://www.openstreetmap.org/node/1",
                claim="A verified pagoda in Hồ Chí Minh",
                confidence=0.95,
            ),
        ),
    )


def proposal() -> Proposal:
    baseline_hash = baseline().input_hash
    return Proposal(
        place_id="place-1",
        province_id=PROVINCE_ID,
        baseline_input_hash=baseline_hash,
        name_decision=NameDecision(
            place_id="place-1",
            vi_name="Chùa Thiên Mụ",
            en_name="Thiên Mụ Pagoda",
            confidence=0.98,
            rule_id="generic:pagoda",
            protected_tokens=("Thiên", "Mụ"),
        ),
        generated=GeneratedContent(
            vi_short=words(20, "vi"),
            en_short=words(20, "en"),
            vi_long=words(90, "vilong"),
            en_long=words(90, "enlong"),
            fact_ids=("fact-1",),
        ),
    )


def apply_item() -> ApplyItem:
    return ApplyItem(
        proposal=proposal(),
        baseline=baseline(),
        source_snapshot=source_snapshot(),
        review_decision=ReviewDecision(place_id="place-1", decision="approve"),
    )


def live_place() -> dict:
    return {
        "id_place": "place-1",
        "id_province": PROVINCE_ID,
        "name": "Chùa Thiên Mụ",
        "short_description": "Mô tả ngắn",
        "detailed_description": None,
        "updated_at": "2026-08-10T00:00:00+00:00",
    }


def live_translations() -> list[dict]:
    return [
        {
            "id": "place-1-vi",
            "place_id": "place-1",
            "lang_code": "vi",
            "name": "Chùa Thiên Mụ",
            "description": "Mô tả ngắn",
            "detailed_description": None,
            "updated_at": "2026-08-10T00:00:00+00:00",
        },
        {
            "id": "place-1-en",
            "place_id": "place-1",
            "lang_code": "en",
            "name": "Thiên Mụ Pagoda",
            "description": "Short description",
            "detailed_description": None,
            "updated_at": "2026-08-10T00:00:00+00:00",
        },
    ]


class FakeTransaction:
    def __init__(self, connection):
        self.connection = connection

    async def __aenter__(self):
        self.connection.transaction_count += 1
        return self

    async def __aexit__(self, exc_type, exc_value, traceback):
        if exc_type is None:
            self.connection.commits += 1
        else:
            self.connection.rollbacks += 1
        return False


class FakeConnection:
    def __init__(self, *, translations=None):
        self.place = live_place()
        self.translations = translations if translations is not None else live_translations()
        self.transaction_count = 0
        self.commits = 0
        self.rollbacks = 0
        self.update_calls = []
        self.fail_on_update = False
        self.return_zero_on_update = False
        self.next_timestamp = "2026-08-10T01:00:00+00:00"

    def transaction(self):
        return FakeTransaction(self)

    async def fetch(self, query, *args):
        if "FROM public.place_translation" in query:
            return [dict(row) for row in self.translations]
        if "FROM public.place" in query:
            return [dict(self.place)]
        raise AssertionError(f"unexpected fetch query: {query}")

    async def fetchrow(self, query, *args):
        self.update_calls.append((query, args))
        if self.fail_on_update:
            raise RuntimeError("synthetic mid-batch failure")
        if self.return_zero_on_update:
            return None
        if "UPDATE public.place_translation" in query:
            place_id, name, description, detailed, lang_code = args
            for row in self.translations:
                if row["place_id"] == place_id and row["lang_code"] == lang_code:
                    row.update(name=name, description=description, detailed_description=detailed, updated_at=self.next_timestamp)
                    return dict(row)
            return None
        if "UPDATE public.place" in query:
            place_id, name, short_description, detailed_description = args
            if self.place["id_place"] != place_id:
                return None
            self.place.update(
                name=name,
                short_description=short_description,
                detailed_description=detailed_description,
                updated_at=self.next_timestamp,
            )
            return dict(self.place)
        raise AssertionError(f"unexpected fetchrow query: {query}")


class PlaceContentApplyTest(unittest.TestCase):
    def manifest(self, *, place_ids=("place-1",)):
        return RunManifest(
            run_id="20260810-120000-abcdef12",
            province_ids=(PROVINCE_ID,),
            place_ids=place_ids,
            expected_total=APPROVED_PROVINCES[PROVINCE_ID],
        )

    def test_cli_confirmation_gate_exits_before_connection_creation(self):
        from scripts.place_content_backfill.cli import main

        with self.assertRaises(SystemExit) as raised:
            main(["apply", "--run-id", "20260810-120000-abcdef12", "--all"])
        self.assertEqual(raised.exception.code, 2)

    def test_apply_success_writes_recovery_and_applied_artifacts(self):
        async def scenario():
            connection = FakeConnection()
            with tempfile.TemporaryDirectory() as tmp:
                store = ArtifactStore(Path(tmp), "20260810-120000-abcdef12")
                result = await apply_approved_batch(
                    connection,
                    (apply_item(),),
                    store,
                    manifest=self.manifest(),
                    batch_id="batch-1",
                    approved_place_ids={"place-1"},
                )
                self.assertEqual(result["applied"], 1)
                self.assertEqual(connection.commits, 1)
                self.assertEqual(len(list(store.iter_stream("rollback"))), 1)
                self.assertEqual(len(list(store.iter_stream("applied"))), 1)
                self.assertEqual(len(connection.update_calls), 3)

        asyncio.run(scenario())

    def test_apply_refuses_baseline_conflict_before_update(self):
        async def scenario():
            connection = FakeConnection()
            connection.place["short_description"] = "changed by admin"
            with tempfile.TemporaryDirectory() as tmp:
                with self.assertRaises(ApplyConflict):
                    await apply_approved_batch(
                        connection,
                        (apply_item(),),
                        ArtifactStore(Path(tmp), "20260810-120000-abcdef12"),
                        manifest=self.manifest(),
                        batch_id="batch-1",
                        approved_place_ids={"place-1"},
                    )
            self.assertEqual(connection.update_calls, [])
            self.assertEqual(connection.rollbacks, 1)

        asyncio.run(scenario())

    def test_apply_refuses_missing_or_duplicate_translation(self):
        for translations in (live_translations()[:1], live_translations() + [dict(live_translations()[0], id="duplicate")]):
            async def scenario(translations=translations):
                connection = FakeConnection(translations=translations)
                with tempfile.TemporaryDirectory() as tmp:
                    with self.assertRaises(ApplyIntegrityError):
                        await apply_approved_batch(
                            connection,
                            (apply_item(),),
                            ArtifactStore(Path(tmp), "20260810-120000-abcdef12"),
                            manifest=self.manifest(),
                            batch_id="batch-1",
                            approved_place_ids={"place-1"},
                        )
                self.assertEqual(connection.update_calls, [])
            asyncio.run(scenario())

    def test_apply_mid_batch_exception_rolls_back_and_leaves_no_applied_record(self):
        async def scenario():
            connection = FakeConnection()
            connection.fail_on_update = True
            with tempfile.TemporaryDirectory() as tmp:
                store = ArtifactStore(Path(tmp), "20260810-120000-abcdef12")
                with self.assertRaises(RuntimeError):
                    await apply_approved_batch(
                        connection,
                        (apply_item(),),
                        store,
                        manifest=self.manifest(),
                        batch_id="batch-1",
                        approved_place_ids={"place-1"},
                    )
                self.assertEqual(list(store.iter_stream("applied")), [])
                self.assertEqual(len(list(store.iter_stream("rollback"))), 1)
                self.assertEqual(connection.rollbacks, 1)

        asyncio.run(scenario())

    def test_apply_zero_row_update_rolls_back(self):
        async def scenario():
            connection = FakeConnection()
            connection.return_zero_on_update = True
            with tempfile.TemporaryDirectory() as tmp:
                store = ArtifactStore(Path(tmp), "20260810-120000-abcdef12")
                with self.assertRaises(ApplyIntegrityError):
                    await apply_approved_batch(
                        connection,
                        (apply_item(),),
                        store,
                        manifest=self.manifest(),
                        batch_id="batch-1",
                        approved_place_ids={"place-1"},
                    )
                self.assertEqual(connection.rollbacks, 1)
                self.assertEqual(list(store.iter_stream("applied")), [])

        asyncio.run(scenario())

    def test_recovery_reconciles_commit_when_applied_marker_append_fails(self):
        class FailingAppliedStore(ArtifactStore):
            def __init__(self, root, run_id):
                super().__init__(root, run_id)
                self.failed = False

            def append_jsonl(self, stream, record):
                if stream == "applied" and not self.failed:
                    self.failed = True
                    raise OSError("synthetic post-commit artifact failure")
                return super().append_jsonl(stream, record)

        async def scenario():
            connection = FakeConnection()
            with tempfile.TemporaryDirectory() as tmp:
                store = FailingAppliedStore(Path(tmp), "20260810-120000-abcdef12")
                with self.assertRaises(OSError):
                    await apply_approved_batch(
                        connection,
                        (apply_item(),),
                        store,
                        manifest=self.manifest(),
                        batch_id="batch-1",
                        approved_place_ids={"place-1"},
                    )
                self.assertEqual(connection.commits, 1)
                recovery = await recover_post_commit_artifacts(
                    connection,
                    store,
                    batch_id="batch-1",
                )
                self.assertEqual(recovery, {"recovered": 1, "unresolved": 0})
                self.assertEqual(len(list(store.iter_stream("applied"))), 1)

        asyncio.run(scenario())

    def test_apply_rejects_batch_of_51_before_transaction(self):
        async def scenario():
            connection = FakeConnection()
            with tempfile.TemporaryDirectory() as tmp:
                with self.assertRaises(ApplyIntegrityError):
                    await apply_approved_batch(
                        connection,
                        (apply_item() for _ in range(51)),
                        ArtifactStore(Path(tmp), "20260810-120000-abcdef12"),
                        manifest=self.manifest(),
                        batch_id="batch-1",
                        approved_place_ids={"place-1"},
                    )
            self.assertEqual(connection.transaction_count, 0)

        asyncio.run(scenario())

    def test_rollback_refuses_later_admin_edit(self):
        async def scenario():
            connection = FakeConnection()
            with tempfile.TemporaryDirectory() as tmp:
                store = ArtifactStore(Path(tmp), "20260810-120000-abcdef12")
                await apply_approved_batch(
                    connection,
                    (apply_item(),),
                    store,
                    manifest=self.manifest(),
                    batch_id="batch-1",
                    approved_place_ids={"place-1"},
                )
                connection.place["short_description"] = "later admin edit"
                with self.assertRaises(RollbackConflict):
                    await rollback_applied_batch(
                        connection,
                        store,
                        manifest=self.manifest(),
                        selector={"batch_id": "batch-1"},
                    )

        asyncio.run(scenario())

    def test_selection_rejects_unresolved_rejected_outside_scope_and_unknown_selector(self):
        item = apply_item()
        with self.assertRaises(ApplyIntegrityError):
            validate_apply_selection(self.manifest(), (item,), approved_place_ids=set())
        rejected = ApplyItem(
            proposal=item.proposal,
            baseline=item.baseline,
            source_snapshot=item.source_snapshot,
            review_decision=ReviewDecision(place_id="place-1", decision="reject"),
        )
        with self.assertRaises(ApplyIntegrityError):
            validate_apply_selection(self.manifest(), (rejected,), approved_place_ids={"place-1"})
        outside = item.baseline.model_copy(update={"province_id": "outside"})
        with self.assertRaises(ApplyIntegrityError):
            validate_apply_selection(
                self.manifest(),
                (ApplyItem(item.proposal, outside, item.source_snapshot, item.review_decision),),
                approved_place_ids={"place-1"},
            )
        with self.assertRaises(ValueError):
            validate_apply_selection(
                self.manifest(),
                (item,),
                approved_place_ids={"place-1"},
                selector={"unknown": "value"},
            )


if __name__ == "__main__":
    unittest.main()
