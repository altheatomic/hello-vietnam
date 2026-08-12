"""
jobs/cf_retrain.py
CF re-train pipeline – triggered by cron or admin endpoint.

Flow:
  1. Read events from DB
  2. Build interaction matrix A
  3. Train WALS → get U, V embeddings
  4. Compute top-500 CF scores per user
  5. Bulk upsert into cf_score_cache
  6. Bulk upsert raw U, V into cf_user_factors / cf_place_factors — runs
     alongside step 5 (not a replacement) so the runtime dot-product read
     path can be validated before cf_score_cache is retired.
  7. Write log to cf_retrain_log
"""

import uuid
import datetime
from db.connection import get_pool
from ml.matrix_a   import build_matrix_A
from ml.wals_model import train_wals, compute_cf_scores
from services.module1_repository import clear_cf_factor_caches


async def _load_events_from_db(conn) -> dict:
    fav_rows = await conn.fetch("SELECT id_user, id_place FROM favorite_place")
    favorites = [
        {'user_id': str(r['id_user']), 'place_id': str(r['id_place'])}
        for r in fav_rows
    ]

    rating_rows = await conn.fetch("""
        SELECT id_user, content_id AS place_id, rating
        FROM reviews
        WHERE content_type = 'place'
          AND status = 'published'
          AND rating IS NOT NULL
    """)
    ratings = [
        {'user_id': str(r['id_user']), 'place_id': str(r['place_id']), 'rating': r['rating']}
        for r in rating_rows
    ]

    view_rows = await conn.fetch("""
        SELECT id_user, id_place
        FROM user_event_log
        WHERE event_type = 'view_detail'
    """)
    views = [
        {'user_id': str(r['id_user']), 'place_id': str(r['id_place'])}
        for r in view_rows
    ]

    share_rows = await conn.fetch("""
        SELECT id_user, id_place
        FROM user_event_log
        WHERE event_type = 'share'
    """)
    shares = [
        {'user_id': str(r['id_user']), 'place_id': str(r['id_place'])}
        for r in share_rows
    ]

    print(
        f"[CF] events loaded — favorites={len(favorites)}, ratings={len(ratings)}, "
        f"views={len(views)}, shares={len(shares)}"
    )

    return {
        'favorites': favorites,
        'ratings':   ratings,
        'views':     views,
        'shares':    shares,
    }


async def _save_cf_scores(conn, scores: list) -> None:
    await conn.executemany("""
        INSERT INTO cf_score_cache (id_user, id_place, score, updated_at)
        VALUES ($1, $2, $3, NOW())
        ON CONFLICT (id_user, id_place)
        DO UPDATE SET score = EXCLUDED.score, updated_at = NOW()
    """, scores)


async def _save_user_factors(conn, user_ids: list, U) -> None:
    rows = [(uid, U[i].tolist()) for i, uid in enumerate(user_ids)]
    await conn.executemany("""
        INSERT INTO cf_user_factors (id_user, factors, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (id_user)
        DO UPDATE SET factors = EXCLUDED.factors, updated_at = NOW()
    """, rows)


async def _save_place_factors(conn, place_ids: list, V) -> None:
    rows = [(pid, V[j].tolist()) for j, pid in enumerate(place_ids)]
    await conn.executemany("""
        INSERT INTO cf_place_factors (id_place, factors, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (id_place)
        DO UPDATE SET factors = EXCLUDED.factors, updated_at = NOW()
    """, rows)


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
    pool = await get_pool()
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
            await _save_user_factors(conn, user_ids, U)
            await _save_place_factors(conn, place_ids, V)

            # New factors are now live in cf_user_factors/cf_place_factors —
            # drop the in-process caches so the next read (trip_planner.py /
            # routes/recommend.py) sees them immediately instead of serving
            # stale factors until the TTL safety net expires.
            clear_cf_factor_caches()

            users_trained  = len(user_ids)
            places_trained = len(place_ids)
            await _log_success(conn, log_id, users_trained + places_trained)

            return {
                'status': 'success',
                'rows_written': {
                    'users_trained': users_trained,
                    'places_trained': places_trained,
                },
                'cf_score_rows_written': len(scores),
                'error': None,
            }

        except Exception as e:
            await _log_failure(conn, log_id, str(e))
            return {
                'status': 'failed',
                'rows_written': {'users_trained': 0, 'places_trained': 0},
                'cf_score_rows_written': 0,
                'error': str(e),
            }
