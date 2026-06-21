"""
jobs/cf_retrain.py
CF re-train pipeline – triggered by cron or admin endpoint.

Flow:
  1. Read events from DB
  2. Build interaction matrix A
  3. Train WALS → get U, V embeddings
  4. Compute top-500 CF scores per user
  5. Bulk upsert into cf_score_cache
  6. Write log to cf_retrain_log
"""

import uuid
import datetime
from db.connection import get_pool
from ml.matrix_a   import build_matrix_A
from ml.wals_model import train_wals, compute_cf_scores


async def _load_events_from_db(conn) -> dict:
    rating_rows = await conn.fetch("""
        SELECT id_user, id_item AS place_id, rating
        FROM rate_item
        WHERE item_type = 'place'
          AND rating IS NOT NULL
    """)
    ratings = [
        {'user_id': str(r['id_user']), 'place_id': str(r['place_id']), 'rating': r['rating']}
        for r in rating_rows
    ]

    fav_rows = await conn.fetch("SELECT id_user, id_place FROM favorite_place")
    favorites = [
        {'user_id': str(r['id_user']), 'place_id': str(r['id_place'])}
        for r in fav_rows
    ]

    plan_rows = await conn.fetch("""
        SELECT pc.id_place, p.id_user
        FROM plan_component pc
        JOIN plan p ON pc.id_plan = p.id_plan
        WHERE pc.id_place IS NOT NULL
    """)
    plans = [
        {'user_id': str(r['id_user']), 'place_id': str(r['id_place'])}
        for r in plan_rows
    ]

    review_rows = await conn.fetch("""
        SELECT id_user, id_item AS place_id
        FROM rate_item
        WHERE item_type = 'place'
          AND review IS NOT NULL
          AND review != ''
    """)
    reviews = [
        {'user_id': str(r['id_user']), 'place_id': str(r['place_id'])}
        for r in review_rows
    ]

    event_rows = await conn.fetch("""
        SELECT id_user, id_place AS place_id, event_type
        FROM user_event_log
    """)
    view_thumbnails = [
        {'user_id': str(r['id_user']), 'place_id': str(r['place_id'])}
        for r in event_rows if r['event_type'] == 'view_thumbnail'
    ]
    view_details = [
        {'user_id': str(r['id_user']), 'place_id': str(r['place_id'])}
        for r in event_rows if r['event_type'] == 'view_detail'
    ]
    view_all_photos = [
        {'user_id': str(r['id_user']), 'place_id': str(r['place_id'])}
        for r in event_rows if r['event_type'] == 'view_all_photos'
    ]
    shares = [
        {'user_id': str(r['id_user']), 'place_id': str(r['place_id'])}
        for r in event_rows if r['event_type'] == 'share'
    ]

    print(
        f"[CF] events loaded — ratings={len(ratings)}, favorites={len(favorites)}, "
        f"plans={len(plans)}, reviews={len(reviews)}, "
        f"view_thumbnail={len(view_thumbnails)}, view_detail={len(view_details)}, "
        f"view_all_photos={len(view_all_photos)}, share={len(shares)}"
    )

    return {
        'view_thumbnails':  view_thumbnails,
        'view_details':     view_details,
        'view_all_photos':  view_all_photos,
        'favorites':        favorites,
        'plans':            plans,
        'shares':           shares,
        'ratings':          ratings,
        'reviews':          reviews,
    }


async def _save_cf_scores(conn, scores: list) -> None:
    await conn.executemany("""
        INSERT INTO cf_score_cache (id_user, id_place, score, updated_at)
        VALUES ($1, $2, $3, NOW())
        ON CONFLICT (id_user, id_place)
        DO UPDATE SET score = EXCLUDED.score, updated_at = NOW()
    """, scores)


async def _log_start(conn, triggered_by: str) -> str:
    log_id = str(uuid.uuid4())
    await conn.execute("""
        INSERT INTO cf_retrain_log (id_log, triggered_by, status, started_at)
        VALUES ($1, $2, 'running', NOW())
    """, log_id, triggered_by)
    return log_id


async def _log_success(conn, log_id: str, rows_written: int) -> None:
    await conn.execute("""
        UPDATE cf_retrain_log
        SET status = 'success', finished_at = NOW(), rows_written = $2
        WHERE id_log = $1
    """, log_id, rows_written)


async def _log_failure(conn, log_id: str, error: str) -> None:
    await conn.execute("""
        UPDATE cf_retrain_log
        SET status = 'failed', finished_at = NOW(), error_msg = $2
        WHERE id_log = $1
    """, log_id, error)


async def run_cf_retrain(triggered_by: str = 'cron') -> dict:
    pool = get_pool()
    async with pool.acquire() as conn:
        log_id = await _log_start(conn, triggered_by)

        try:
            events = await _load_events_from_db(conn)
            A, user_ids, place_ids = build_matrix_A(events)

            if len(user_ids) == 0 or len(place_ids) == 0:
                raise ValueError("No events found – cannot train model.")

            U, V    = train_wals(A)
            scores  = compute_cf_scores(U, V, user_ids, place_ids, A, top_k=500)

            await _save_cf_scores(conn, scores)
            await _log_success(conn, log_id, len(scores))

            return {'status': 'success', 'rows_written': len(scores), 'error': None}

        except Exception as e:
            await _log_failure(conn, log_id, str(e))
            return {'status': 'failed', 'rows_written': 0, 'error': str(e)}
