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
    """Atomically alter the pg_cron job and persist the display config."""
    cron_expression = f"{minute_utc} {hour_utc} * * *"

    async with pool.acquire() as conn:
        async with conn.transaction():
            job_id = await conn.fetchval(
                """
                SELECT jobid
                FROM cron.job
                WHERE jobname = $1
                  AND username = current_user
                ORDER BY jobid DESC
                LIMIT 1
                FOR UPDATE
                """,
                JOB_NAME,
            )
            if job_id is None:
                raise RuntimeError(f"pg_cron job {JOB_NAME!r} is not registered.")

            await conn.execute(
                "SELECT cron.alter_job(job_id := $1, schedule := $2)",
                job_id,
                cron_expression,
            )
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

    return schedule_from_row(row)
