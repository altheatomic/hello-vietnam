"""
Shared asyncpg connection pool.

The core trip-planning endpoints use the Supabase REST client, so the service
should not fail startup just because direct Postgres connectivity is unavailable.
Direct DB connections are initialized lazily by endpoints/jobs that need them.
"""

import os

import asyncpg

_pool: asyncpg.Pool | None = None


async def init_pool() -> None:
    global _pool
    if _pool is not None:
        return

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL is not configured.")

    _pool = await asyncpg.create_pool(
        dsn=database_url,
        min_size=1,
        max_size=10,
        timeout=8,
        command_timeout=60,
    )


async def close_pool() -> None:
    global _pool
    if _pool:
        await _pool.close()
        _pool = None


async def get_pool() -> asyncpg.Pool:
    if _pool is None:
        await init_pool()
    return _pool


async def get_db():
    if _pool is None:
        await init_pool()
    async with _pool.acquire() as conn:
        yield conn
