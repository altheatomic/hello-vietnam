"""
Supabase client setup.
Use this only in backend/testing code.
Do not expose SERVICE_ROLE_KEY in Flutter or frontend code.
"""

import os
from dotenv import load_dotenv
from supabase import create_client, Client


load_dotenv()


def get_supabase_client() -> Client:
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

    if not url:
        raise ValueError("Missing SUPABASE_URL in .env")

    if not key:
        raise ValueError("Missing SUPABASE_SERVICE_ROLE_KEY in .env")

    return create_client(url, key)
