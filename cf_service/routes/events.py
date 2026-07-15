"""
routes/events.py
Implicit-signal event tracking for the CF pipeline.

POST /api/events/track
  Upserts one row per (id_user, id_place, event_type) in user_event_log.
  On repeated interaction: event_count += 1, last_at = now().
"""

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import Literal

from db.connection import get_db

router = APIRouter()


class TrackEventRequest(BaseModel):
    id_user:    str
    id_place:   str
    event_type: Literal["view_thumbnail", "view_detail", "view_all_photos", "share"]


@router.post("/api/events/track", status_code=200)
async def track_event(req: TrackEventRequest, conn=Depends(get_db)):
    await conn.execute("""
        INSERT INTO user_event_log (id_user, id_place, event_type, event_count, first_at, last_at)
        VALUES ($1, $2, $3, 1, now(), now())
        ON CONFLICT (id_user, id_place, event_type)
        DO UPDATE SET
            event_count = user_event_log.event_count + 1,
            last_at     = now()
    """, req.id_user, req.id_place, req.event_type)
    return {"status": "ok"}
