"""
routes/trip.py
FastAPI endpoints for trip planning and admin CF retrain.

Dependency injection:
  - Planning endpoints  → supabase-py client (sync, per-request)
  - CF retrain endpoint → asyncpg conn (kept for background job compatibility)
"""

import datetime
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Optional

from db.connection import get_db
from db.supabase_client import get_supabase

router = APIRouter()


# ── Request models ────────────────────────────────────────────────────────────

class TripPlanRequest(BaseModel):
    id_user:             str
    id_province:         str
    n_days:              int
    start_date:          Optional[str]       = None   # 'YYYY-MM-DD'; defaults to today
    sa_runs:             int                 = 5
    save_plan:           bool                = False
    interest_option_ids: Optional[List[str]] = None   # trip-level interest (UUIDs)


class SavePlanRequest(BaseModel):
    id_user:      str
    custom_title: Optional[str] = None


# ── Trip planning ─────────────────────────────────────────────────────────────

@router.post("/api/trips/plan")
async def plan_trip(req: TripPlanRequest, supabase=Depends(get_supabase)):
    print(f"[DEBUG] plan request: {req.dict()}")
    from services.trip_planner import TripPlannerService

    start_at = (
        datetime.date.fromisoformat(req.start_date)
        if req.start_date
        else datetime.date.today()
    )

    svc = TripPlannerService(supabase)
    result = await svc.plan(
        id_user=req.id_user,
        id_province=req.id_province,
        n_days=req.n_days,
        start_at=start_at,
        sa_runs=req.sa_runs,
        save=req.save_plan,
        interest_option_ids=req.interest_option_ids,
    )
    # print(f"[DEBUG] response days count: {len(result.get('days', []))}")
    # print(f"[DEBUG] response: {result}")
    return result


@router.get("/api/trips/plan/{id_plan}")
async def get_plan(id_plan: str, id_user: str, supabase=Depends(get_supabase)):
    from db.queries_plan import get_plan as _get_plan

    plan = _get_plan(supabase, id_plan)
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found.")
    return plan


@router.get("/api/trips/plans")
async def list_plans(id_user: str, supabase=Depends(get_supabase)):
    from db.queries_plan import list_plans as _list_plans

    return {"plans": _list_plans(supabase, id_user)}


@router.post("/api/trips/{id_plan}/save")
async def save_trip(id_plan: str, req: SavePlanRequest, supabase=Depends(get_supabase)):
    from db.queries_plan import mark_plan_saved

    result = mark_plan_saved(supabase, id_plan, req.id_user, req.custom_title)
    if not result:
        raise HTTPException(status_code=404, detail="Plan not found or not owned by user.")
    return result


@router.get("/api/trips/saved")
async def get_saved_plans(id_user: str, supabase=Depends(get_supabase)):
    from db.queries_plan import fetch_saved_plans

    return {"plans": fetch_saved_plans(supabase, id_user)}


# ── Admin: CF retrain ─────────────────────────────────────────────────────────

@router.post("/admin/cf/retrain")
async def trigger_cf_retrain(background_tasks: BackgroundTasks):
    from jobs.cf_retrain import run_cf_retrain
    background_tasks.add_task(run_cf_retrain, triggered_by='admin')
    return {"status": "queued", "message": "CF re-train job started in background."}


@router.get("/admin/cf/retrain/logs")
async def get_retrain_logs(conn=Depends(get_db)):
    rows = await conn.fetch("""
        SELECT id_log, triggered_by, started_at, finished_at,
               status, rows_written, error_msg
        FROM cf_retrain_log
        ORDER BY started_at DESC
        LIMIT 20
    """)
    return [dict(r) for r in rows]
