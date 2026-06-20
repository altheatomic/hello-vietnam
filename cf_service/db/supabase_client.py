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
