"""Persistence and pg_cron updates for the daily CF retrain job."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any
from uuid import UUID


JOB_NAME = "daily_cf_retrain"
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


def next_run_time_utc(
    hour_utc: int,
    minute_utc: int,
    *,
    now: datetime | None = None,
) -> str:
    current = now or datetime.now(timezone.utc)
    if current.tzinfo is None:
        current = current.replace(tzinfo=timezone.utc)
    current = current.astimezone(timezone.utc)
    candidate = current.replace(
        hour=hour_utc,
        minute=minute_utc,
        second=0,
        microsecond=0,
    )
    if candidate <= current:
        candidate += timedelta(days=1)
    return candidate.isoformat()


async def update_cf_retrain_schedule(
    pool: Any,
    *,
    hour_utc: int,
    minute_utc: int,
    updated_by: UUID | None,
) -> CfRetrainSchedule:
    """Use the least-privilege database function to update cron and config."""
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            SELECT hour_utc, minute_utc, updated_at, updated_by
            FROM public.update_cf_retrain_schedule(
                $1::smallint,
                $2::smallint,
                $3::uuid
            )
            """,
            hour_utc,
            minute_utc,
            updated_by,
        )

    return schedule_from_row(row)
