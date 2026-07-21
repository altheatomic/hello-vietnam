"""
db/supabase_client.py
Supabase Python client for the trip-planning pipeline.

cf_retrain uses its own asyncpg pool (db/connection.py) — this client
is only for Module 1 / Module 2 / place / plan queries.

Required environment variables:
  SUPABASE_URL              – project REST URL
                              e.g. https://<project>.supabase.co
  SUPABASE_SERVICE_ROLE_KEY – service-role key (never expose in frontend)
"""

import os
from typing import Any, Callable

from supabase import Client, create_client


def get_supabase_client() -> Client:
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url:
        raise ValueError("Missing SUPABASE_URL env var")
    if not key:
        raise ValueError("Missing SUPABASE_SERVICE_ROLE_KEY env var")
    return create_client(url, key)


async def get_supabase():
    """FastAPI dependency – yields a supabase-py Client per request."""
    yield get_supabase_client()


def fetch_all_rows(
    build_query: Callable[[int, int], Any],
    page_size: int = 1000,
) -> list[dict]:
    """
    Paginate a Supabase-py query past PostgREST's default `max-rows` cap.

    `.limit(N)` for N greater than the project's configured max-rows
    (commonly 1000) is silently truncated server-side — the client never
    sees an error, it just gets fewer rows than asked for. This affected
    recommend_service.py's province-wide place fetch: `.limit(3000)`
    returned only 1000/5006 real rows.

    `build_query(start, end)` must return a fully-chained query builder
    with `.range(start, end)` applied (not yet `.execute()`d) — e.g.:

        fetch_all_rows(lambda start, end: (
            supabase.table("place_localized_en").select("id_place")
            .eq("status", "active").range(start, end)
        ))

    Keeps paging until a page returns fewer than `page_size` rows, so it
    scales correctly regardless of how large the table grows.
    """
    rows: list[dict] = []
    start = 0
    while True:
        end = start + page_size - 1
        response = build_query(start, end).execute()
        batch = response.data or []
        rows.extend(batch)
        if len(batch) < page_size:
            break
        start += page_size
    return rows
