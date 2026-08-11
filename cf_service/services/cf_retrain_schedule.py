"""Persistence and live APScheduler updates for the daily CF retrain job."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any
from uuid import UUID

from apscheduler.triggers.cron import CronTrigger


JOB_ID = "daily_cf_retrain"
DEFAULT_HOUR_UTC = 19
DEFAULT_MINUTE_UTC = 0


@dataclass(frozen=True)
class CfRetrainSchedule:
    hour_utc: int
    minute_utc: int
    updated_at: Any = None
    updated_by: UUID | None = None


def schedule_from_row(row: Any) -> CfRetrainSchedule:
    if row is None:
        return CfRetrainSchedule(DEFAULT_HOUR_UTC, DEFAULT_MINUTE_UTC)
    return CfRetrainSchedule(
        hour_utc=row["hour_utc"],
        minute_utc=row["minute_utc"],
        updated_at=row["updated_at"],
        updated_by=row["updated_by"],
    )


def build_cf_retrain_trigger(hour_utc: int, minute_utc: int) -> CronTrigger:
    return CronTrigger(hour=hour_utc, minute=minute_utc, timezone="UTC")


async def load_cf_retrain_schedule(pool: Any) -> CfRetrainSchedule:
    """Load the singleton row; only a genuinely empty table uses defaults."""
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            SELECT hour_utc, minute_utc, updated_at, updated_by
            FROM public.cf_retrain_config
            WHERE singleton_id = 1
            """
        )
    return schedule_from_row(row)


def next_run_time_utc(scheduler: Any) -> str | None:
    job = scheduler.get_job(JOB_ID)
    if job is None or job.next_run_time is None:
        return None
    return job.next_run_time.isoformat()


async def update_cf_retrain_schedule(
    pool: Any,
    scheduler: Any,
    *,
    hour_utc: int,
    minute_utc: int,
    updated_by: UUID | None,
) -> CfRetrainSchedule:
    """Reschedule in memory and persist, restoring the old trigger on DB error."""
    job = scheduler.get_job(JOB_ID)
    if job is None:
        raise RuntimeError(f"Scheduler job {JOB_ID!r} is not registered.")

    old_trigger = job.trigger
    scheduler.reschedule_job(
        JOB_ID,
        trigger=build_cf_retrain_trigger(hour_utc, minute_utc),
    )

    try:
        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                INSERT INTO public.cf_retrain_config (
                    singleton_id, hour_utc, minute_utc, updated_at, updated_by
                )
                VALUES (1, $1, $2, NOW(), $3)
                ON CONFLICT (singleton_id) DO UPDATE
                SET hour_utc = EXCLUDED.hour_utc,
                    minute_utc = EXCLUDED.minute_utc,
                    updated_at = NOW(),
                    updated_by = EXCLUDED.updated_by
                RETURNING hour_utc, minute_utc, updated_at, updated_by
                """,
                hour_utc,
                minute_utc,
                updated_by,
            )
    except Exception as write_error:
        try:
            scheduler.reschedule_job(JOB_ID, trigger=old_trigger)
        except Exception as rollback_error:
            raise RuntimeError(
                "Failed to persist CF retrain schedule and failed to restore "
                f"the previous trigger: {rollback_error}"
            ) from write_error
        raise RuntimeError(
            "Failed to persist CF retrain schedule; the previous trigger was restored."
        ) from write_error

    return schedule_from_row(row)
