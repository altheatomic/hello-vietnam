"""
db/queries_places.py
Database query functions for Module 1 (candidate selection).
"""


async def get_places_by_province(conn, id_province: str) -> list:
    rows = await conn.fetch("""
        SELECT
            p.id_place,
            p.name,
            p.latitude,
            p.longitude,
            p.price_level,
            p.average_rating,
            p.estimated_duration_minutes,
            p.minimum_price,
            p.maximum_price,
            ps.id_place_subcategory,
            ps.place_category   AS category,
            ps.name             AS subcategory_name
        FROM place p
        JOIN place_subcategory ps
          ON p.id_place_subcategory = ps.id_place_subcategory
        WHERE p.id_province   = $1
          AND p.status        = 'active'
          AND ps.is_itinerary_eligible = true
          AND p.latitude  IS NOT NULL
          AND p.longitude IS NOT NULL
    """, id_province)

    return [dict(r) for r in rows]


async def get_user_profile(conn, id_user: str) -> dict:
    travel_row = await conn.fetchrow("""
        SELECT companion_style, budget_level, pace_level
        FROM user_travel_profile
        WHERE id_user = $1
    """, id_user)

    hobby_rows = await conn.fetch("""
        SELECT ps.id_place_subcategory, ps.place_category, ps.name
        FROM hobby h
        JOIN place_subcategory ps
          ON h.id_subcategory = ps.id_place_subcategory
        WHERE h.id_user = $1
    """, id_user)

    tag_rows = await conn.fetch("""
        SELECT id_tag, final_weight
        FROM user_interest_tag
        WHERE id_user = $1
        ORDER BY final_weight DESC
        LIMIT 30
    """, id_user)

    return {
        'travel_profile': dict(travel_row) if travel_row else {},
        'hobbies':        [dict(r) for r in hobby_rows],
        'interest_tags':  [dict(r) for r in tag_rows],
    }


async def get_cf_scores_for_user(conn, id_user: str, id_province: str) -> dict:
    rows = await conn.fetch("""
        SELECT c.id_place, c.score
        FROM cf_score_cache c
        JOIN place p ON c.id_place = p.id_place
        WHERE c.id_user    = $1
          AND p.id_province = $2
    """, id_user, id_province)

    return {str(r['id_place']): float(r['score']) for r in rows}


async def get_place_tags(conn, place_ids: list) -> dict:
    if not place_ids:
        return {}

    rows = await conn.fetch("""
        SELECT id_place, id_tag, confidence_score
        FROM place_tag
        WHERE id_place = ANY($1::uuid[])
    """, place_ids)

    result: dict = {}
    for r in rows:
        pid = str(r['id_place'])
        result.setdefault(pid, []).append({
            'id_tag':     str(r['id_tag']),
            'confidence': float(r['confidence_score'] or 0),
        })
    return result


async def get_already_rated_places(conn, id_user: str) -> set:
    rows = await conn.fetch("""
        SELECT id_item
        FROM rate_item
        WHERE id_user   = $1
          AND item_type = 'place'
    """, id_user)

    return {str(r['id_item']) for r in rows}
