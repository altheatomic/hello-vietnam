import unittest
from datetime import datetime, timezone
from uuid import uuid4

from pydantic import ValidationError
from routes.trip import CfRetrainScheduleUpdate

from services.cf_retrain_schedule import (
    DEFAULT_HOUR_UTC,
    DEFAULT_MINUTE_UTC,
    JOB_ID,
    build_cf_retrain_trigger,
    load_cf_retrain_schedule,
    update_cf_retrain_schedule,
)


class _Acquire:
    def __init__(self, connection):
        self.connection = connection

    async def __aenter__(self):
        return self.connection

    async def __aexit__(self, exc_type, exc, traceback):
        return False


class _Pool:
    def __init__(self, connection):
        self.connection = connection

    def acquire(self):
        return _Acquire(self.connection)


class _Connection:
    def __init__(self, row=None, error=None):
        self.row = row
        self.error = error
        self.calls = []

    async def fetchrow(self, query, *args):
        self.calls.append((query, args))
        if self.error is not None:
            raise self.error
        return self.row


class _Job:
    def __init__(self, trigger):
        self.trigger = trigger
        self.next_run_time = datetime(2026, 8, 12, 4, 45, tzinfo=timezone.utc)


class _Scheduler:
    def __init__(self, trigger):
        self.job = _Job(trigger)
        self.triggers = []

    def get_job(self, job_id):
        return self.job if job_id == JOB_ID else None

    def reschedule_job(self, job_id, trigger):
        assert job_id == JOB_ID
        self.job.trigger = trigger
        self.triggers.append(trigger)
        return self.job


class CfRetrainScheduleTests(unittest.IsolatedAsyncioTestCase):
    def test_invalid_hour_is_rejected(self):
        with self.assertRaisesRegex(ValidationError, "hour_utc must be between 0 and 23"):
            CfRetrainScheduleUpdate(hour_utc=25, minute_utc=0)

    async def test_empty_config_uses_default(self):
        schedule = await load_cf_retrain_schedule(_Pool(_Connection(row=None)))
        self.assertEqual(schedule.hour_utc, DEFAULT_HOUR_UTC)
        self.assertEqual(schedule.minute_utc, DEFAULT_MINUTE_UTC)

    async def test_persisted_config_builds_restart_trigger(self):
        row = {
            "hour_utc": 4,
            "minute_utc": 45,
            "updated_at": datetime.now(timezone.utc),
            "updated_by": uuid4(),
        }
        schedule = await load_cf_retrain_schedule(_Pool(_Connection(row=row)))
        trigger = build_cf_retrain_trigger(schedule.hour_utc, schedule.minute_utc)
        self.assertEqual(str(trigger.fields[5]), "4")
        self.assertEqual(str(trigger.fields[6]), "45")

    async def test_update_reschedules_and_persists(self):
        old_trigger = build_cf_retrain_trigger(19, 0)
        scheduler = _Scheduler(old_trigger)
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
            scheduler,
            hour_utc=4,
            minute_utc=45,
            updated_by=updated_by,
        )

        self.assertEqual((result.hour_utc, result.minute_utc), (4, 45))
        self.assertEqual(str(scheduler.job.trigger.fields[5]), "4")
        self.assertEqual(str(scheduler.job.trigger.fields[6]), "45")
        self.assertEqual(connection.calls[0][1], (4, 45, updated_by))

    async def test_database_failure_restores_previous_trigger(self):
        old_trigger = build_cf_retrain_trigger(19, 0)
        scheduler = _Scheduler(old_trigger)

        with self.assertRaisesRegex(RuntimeError, "previous trigger was restored"):
            await update_cf_retrain_schedule(
                _Pool(_Connection(error=OSError("database unavailable"))),
                scheduler,
                hour_utc=4,
                minute_utc=45,
                updated_by=uuid4(),
            )

        self.assertIs(scheduler.job.trigger, old_trigger)
        self.assertEqual(len(scheduler.triggers), 2)

    async def test_database_read_error_is_not_treated_as_empty(self):
        with self.assertRaisesRegex(OSError, "database unavailable"):
            await load_cf_retrain_schedule(
                _Pool(_Connection(error=OSError("database unavailable")))
            )


if __name__ == "__main__":
    unittest.main()
