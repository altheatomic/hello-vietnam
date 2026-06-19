"""
routes/trip.py
FastAPI endpoints for trip planning and admin CF retrain.
"""

import datetime
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional

from db.connection import get_db

router = APIRouter()


# ── Request models ────────────────────────────────────────────────────────────

class TripPlanRequest(BaseModel):
    id_user:     str
    id_province: str
    n_days:      int
    start_date:  Optional[str] = None   # 'YYYY-MM-DD'; defaults to today
    top_n:       int  = 40
    sa_runs:     int  = 5
    save_plan:   bool = True


# ── Trip planning ─────────────────────────────────────────────────────────────

@router.post("/api/trips/plan")
async def plan_trip(req: TripPlanRequest, conn=Depends(get_db)):
    from services.trip_planner import TripPlannerService

    start_at = (
        datetime.date.fromisoformat(req.start_date)
        if req.start_date
        else datetime.date.today()
    )

    svc    = TripPlannerService(conn)
    result = await svc.plan(
        id_user     = req.id_user,
        id_province = req.id_province,
        n_days      = req.n_days,
        start_at    = start_at,
        top_n       = req.top_n,
        sa_runs     = req.sa_runs,
        save        = req.save_plan,
    )
    return result


@router.get("/api/trips/plan/{id_plan}")
async def get_plan(id_plan: str, id_user: str, conn=Depends(get_db)):
    from db.queries_plan import get_plan as _get_plan

    plan = await _get_plan(conn, id_plan)
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found.")
    return plan


@router.get("/api/trips/plans")
async def list_plans(id_user: str, conn=Depends(get_db)):
    from db.queries_plan import list_plans as _list_plans

    return {"plans": await _list_plans(conn, id_user)}


# ── Admin: CF retrain ─────────────────────────────────────────────────────────

@router.post("/admin/cf/retrain")
async def trigger_cf_retrain(background_tasks: BackgroundTasks,
                              conn=Depends(get_db)):
    from jobs.cf_retrain import run_cf_retrain
    background_tasks.add_task(run_cf_retrain, conn, triggered_by='admin')
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
