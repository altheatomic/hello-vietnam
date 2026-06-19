"""
db/queries_plan.py
Save / load trip plan in plan + plan_component tables.
"""

import uuid
import datetime


async def save_plan(conn,
                    id_user:     str,
                    id_province: str,
                    n_days:      int,
                    start_at:    datetime.date,
                    days:        list) -> str:
    id_plan = str(uuid.uuid4())
    end_at  = start_at + datetime.timedelta(days=n_days - 1)

    await conn.execute("""
        INSERT INTO plan (id_plan, id_user, duration, start_at, end_at, city_province)
        VALUES ($1, $2, $3, $4, $5, $6)
    """, id_plan, id_user, str(n_days), start_at, end_at, id_province)

    rows = []
    for day in days:
        for place in day['places']:
            rows.append((
                str(uuid.uuid4()),
                id_plan,
                day['day'],
                place.get('slot'),
                place['id_place'],
                place['order'],
                place.get('slot'),
                place.get('estimated_travel_minutes'),
                place.get('cb_score'),
                place.get('cf_score'),
                place.get('final_score'),
            ))

    await conn.executemany("""
        INSERT INTO plan_component (
            id_component, id_plan, day, time_part,
            id_place, visit_order, slot,
            estimated_travel_minutes,
            cb_score, cf_score, final_score
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
    """, rows)

    return id_plan


async def get_plan(conn, id_plan: str) -> dict:
    plan_row = await conn.fetchrow("""
        SELECT id_plan, duration, start_at, end_at, city_province, created_at
        FROM plan WHERE id_plan = $1
    """, id_plan)

    if not plan_row:
        return {}

    component_rows = await conn.fetch("""
        SELECT
            pc.day, pc.slot, pc.visit_order,
            pc.estimated_travel_minutes,
            pc.cb_score, pc.cf_score, pc.final_score,
            p.id_place, p.name, p.latitude, p.longitude
        FROM plan_component pc
        JOIN place p ON pc.id_place = p.id_place
        WHERE pc.id_plan = $1
        ORDER BY pc.day, pc.visit_order
    """, id_plan)

    days_map: dict = {}
    for r in component_rows:
        d = r['day']
        days_map.setdefault(d, []).append(dict(r))

    return {
        'id_plan':       str(plan_row['id_plan']),
        'start_at':      str(plan_row['start_at'].date()),
        'end_at':        str(plan_row['end_at'].date()),
        'city_province': plan_row['city_province'],
        'created_at':    str(plan_row['created_at']),
        'days': [
            {'day': d, 'places': places}
            for d, places in sorted(days_map.items())
        ],
    }


async def list_plans(conn, id_user: str) -> list:
    rows = await conn.fetch("""
        SELECT id_plan, duration, start_at, end_at, city_province, created_at
        FROM plan
        WHERE id_user = $1
        ORDER BY created_at DESC
        LIMIT 50
    """, id_user)

    return [
        {
            'id_plan':       str(r['id_plan']),
            'duration':      r['duration'],
            'start_at':      str(r['start_at'].date()),
            'end_at':        str(r['end_at'].date()),
            'city_province': r['city_province'],
            'created_at':    str(r['created_at']),
        }
        for r in rows
    ]
