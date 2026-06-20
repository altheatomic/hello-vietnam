"""
db/connection.py
asyncpg connection pool — shared across request lifetime via FastAPI lifespan.
DATABASE_URL must be set as an environment variable (Supabase connection string).
"""

import os
import asyncpg

_pool: asyncpg.Pool | None = None


async def init_pool() -> None:
    global _pool
    _pool = await asyncpg.create_pool(
        dsn=os.environ["DATABASE_URL"],
        min_size=2,
        max_size=10,
        command_timeout=60,
    )


async def close_pool() -> None:
    global _pool
    if _pool:
        await _pool.close()
        _pool = None


def get_pool() -> asyncpg.Pool:
    """Return the shared pool — for background tasks that self-manage connections."""
    if _pool is None:
        raise RuntimeError("Connection pool not initialised. Call init_pool() at startup.")
    return _pool


async def get_db():
    """FastAPI dependency — yields a single connection from the pool."""
    if _pool is None:
        raise RuntimeError("Connection pool not initialised. Call init_pool() at startup.")
    async with _pool.acquire() as conn:
        yield conn
