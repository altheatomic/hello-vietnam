import io
import os
import unittest
from contextlib import redirect_stdout
from datetime import datetime, timezone
from unittest.mock import AsyncMock, patch
from uuid import uuid4

from fastapi import BackgroundTasks, HTTPException
from pydantic import ValidationError

from main import _warn_if_cf_retrain_secret_missing
from routes.trip import (
    CfRetrainScheduleUpdate,
    CfRetrainTriggerRequest,
    _retrain_trigger_source,
    trigger_cf_retrain,
)
from services.cf_retrain_schedule import (
    DEFAULT_HOUR_UTC,
    DEFAULT_MINUTE_UTC,
    JOB_NAME,
    load_cf_retrain_schedule,
    next_run_time_utc,
    update_cf_retrain_schedule,
)


class _Acquire:
    def __init__(self, connection):
        self.connection = connection

    async def __aenter__(self):
        return self.connection

    async def __aexit__(self, exc_type, exc, traceback):
        return False


class _Transaction:
    def __init__(self):
        self.exited_with = None

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, traceback):
        self.exited_with = exc_type
        return False


class _Pool:
    def __init__(self, connection):
        self.connection = connection

    def acquire(self):
        return _Acquire(self.connection)


class _Connection:
    def __init__(self, row=None, job_id=42, error=None):
        self.row = row
        self.job_id = job_id
        self.error = error
        self.calls = []
        self.tx = _Transaction()

    def transaction(self):
        return self.tx

    async def fetchval(self, query, *args):
        self.calls.append(("fetchval", query, args))
        return self.job_id

    async def execute(self, query, *args):
        self.calls.append(("execute", query, args))
        if self.error is not None:
            raise self.error
        return "SELECT 1"

    async def fetchrow(self, query, *args):
        self.calls.append(("fetchrow", query, args))
        if self.error is not None:
            raise self.error
        return self.row


class CfRetrainScheduleTests(unittest.IsolatedAsyncioTestCase):
    def test_invalid_hour_is_rejected(self):
        with self.assertRaisesRegex(ValidationError, "hour_utc must be between 0 and 23"):
            CfRetrainScheduleUpdate(hour_utc=25, minute_utc=0)

    async def test_empty_config_uses_default(self):
        schedule = await load_cf_retrain_schedule(_Pool(_Connection(row=None)))
        self.assertEqual(schedule.hour_utc, DEFAULT_HOUR_UTC)
        self.assertEqual(schedule.minute_utc, DEFAULT_MINUTE_UTC)

    def test_next_run_rolls_to_tomorrow_after_scheduled_time(self):
        now = datetime(2026, 8, 11, 20, 0, tzinfo=timezone.utc)
        self.assertEqual(
            next_run_time_utc(19, 0, now=now),
            "2026-08-12T19:00:00+00:00",
        )

    async def test_update_alters_pg_cron_and_persists_in_one_transaction(self):
        updated_by = uuid4()
        row = {
            "hour_utc": 4,
            "minute_utc": 45,
            "updated_at": datetime.now(timezone.utc),
            "updated_by": updated_by,
        }
        connection = _Connection(row=row)

        result = await update_cf_retrain_schedule(
            _Pool(connection),
            hour_utc=4,
            minute_utc=45,
            updated_by=updated_by,
        )

        self.assertEqual((result.hour_utc, result.minute_utc), (4, 45))
        self.assertEqual(connection.calls[0][2], (JOB_NAME,))
        self.assertIn("cron.alter_job", connection.calls[1][1])
        self.assertEqual(connection.calls[1][2], (42, "45 4 * * *"))
        self.assertEqual(connection.calls[2][2], (4, 45, updated_by))
        self.assertIsNone(connection.tx.exited_with)

    async def test_update_fails_clearly_when_cron_job_is_missing(self):
        with self.assertRaisesRegex(RuntimeError, "is not registered"):
            await update_cf_retrain_schedule(
                _Pool(_Connection(job_id=None)),
                hour_utc=4,
                minute_utc=45,
                updated_by=uuid4(),
            )

    async def test_database_failure_rolls_back_transaction(self):
        connection = _Connection(error=OSError("database unavailable"))
        with self.assertRaisesRegex(OSError, "database unavailable"):
            await update_cf_retrain_schedule(
                _Pool(connection),
                hour_utc=4,
                minute_utc=45,
                updated_by=uuid4(),
            )
        self.assertIs(connection.tx.exited_with, OSError)

    async def test_database_read_error_is_not_treated_as_empty(self):
        with self.assertRaisesRegex(OSError, "database unavailable"):
            await load_cf_retrain_schedule(
                _Pool(_Connection(error=OSError("database unavailable")))
            )


class CfRetrainSecretTests(unittest.IsolatedAsyncioTestCase):
    def test_matching_header_is_pg_cron(self):
        with patch.dict(os.environ, {"CF_RETRAIN_SHARED_SECRET": "correct"}):
            source = _retrain_trigger_source(
                CfRetrainTriggerRequest(triggered_by="pg_cron"), "correct"
            )
        self.assertEqual(source, "pg_cron")

    def test_wrong_header_is_unauthorized(self):
        with patch.dict(os.environ, {"CF_RETRAIN_SHARED_SECRET": "correct"}):
            with self.assertRaises(HTTPException) as raised:
                _retrain_trigger_source(
                    CfRetrainTriggerRequest(triggered_by="pg_cron"), "wrong"
                )
        self.assertEqual(raised.exception.status_code, 401)

    def test_missing_header_keeps_admin_behavior(self):
        with patch.dict(os.environ, {"CF_RETRAIN_SHARED_SECRET": "correct"}):
            source = _retrain_trigger_source(None, None)
        self.assertEqual(source, "admin")

    def test_missing_env_disables_check_and_accepts_pg_cron(self):
        with patch.dict(os.environ, {}, clear=True):
            source = _retrain_trigger_source(
                CfRetrainTriggerRequest(triggered_by="pg_cron"), "anything"
            )
        self.assertEqual(source, "pg_cron")

    def test_missing_env_logs_startup_warning_once_when_called(self):
        output = io.StringIO()
        with patch.dict(os.environ, {}, clear=True), redirect_stdout(output):
            warned = _warn_if_cf_retrain_secret_missing()
        self.assertTrue(warned)
        self.assertIn('"event": "cf_retrain_secret_missing_startup"', output.getvalue())

    async def test_endpoint_queues_pg_cron_for_matching_header(self):
        tasks = BackgroundTasks()
        with (
            patch.dict(os.environ, {"CF_RETRAIN_SHARED_SECRET": "correct"}),
            patch("routes.trip.get_pool", new=AsyncMock(return_value=object())),
        ):
            response = await trigger_cf_retrain(
                tasks,
                CfRetrainTriggerRequest(triggered_by="pg_cron"),
                "correct",
            )
        self.assertEqual(response["status"], "queued")
        self.assertEqual(tasks.tasks[0].kwargs["triggered_by"], "pg_cron")

    async def test_endpoint_without_header_queues_admin(self):
        tasks = BackgroundTasks()
        with (
            patch.dict(os.environ, {"CF_RETRAIN_SHARED_SECRET": "correct"}),
            patch("routes.trip.get_pool", new=AsyncMock(return_value=object())),
        ):
            await trigger_cf_retrain(tasks, None, None)
        self.assertEqual(tasks.tasks[0].kwargs["triggered_by"], "admin")


if __name__ == "__main__":
    unittest.main()
