"""Temporary script to get real user/province IDs for testing."""
import asyncio
import asyncpg
import os
from dotenv import load_dotenv

load_dotenv()

async def main():
    conn = await asyncpg.connect(os.environ["DATABASE_URL"])

    # User account columns
    cols = await conn.fetch(
        "SELECT column_name FROM information_schema.columns "
        "WHERE table_name = 'user_account' ORDER BY ordinal_position LIMIT 15"
    )
    print("user_account cols:", [r["column_name"] for r in cols])

    # Users that have a travel profile
    users = await conn.fetch(
        "SELECT u.id_user FROM user_account u "
        "JOIN user_travel_profile utp ON utp.id_user = u.id_user "
        "LIMIT 5"
    )
    print("Users with travel profile:", [str(r["id_user"]) for r in users])

    # Top provinces by eligible place count
    provinces = await conn.fetch(
        "SELECT p.old_province, COUNT(*) AS cnt "
        "FROM place p "
        "JOIN place_subcategory ps ON ps.id_place_subcategory = p.id_place_subcategory "
        "WHERE p.status = 'active' AND ps.is_itinerary_eligible = true "
        "  AND p.latitude IS NOT NULL AND p.longitude IS NOT NULL "
        "GROUP BY p.old_province ORDER BY cnt DESC LIMIT 5"
    )
    print("Top provinces:", [(r["old_province"], r["cnt"]) for r in provinces])

    await conn.close()

asyncio.run(main())
