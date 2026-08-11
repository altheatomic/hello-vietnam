"""
routes/trip.py
FastAPI endpoints for trip planning and admin CF retrain.

Dependency injection:
  - Planning endpoints  → supabase-py client (sync, per-request)
  - CF retrain endpoint → asyncpg conn (kept for background job compatibility)
"""

import asyncio
import datetime
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from pydantic import BaseModel, model_validator
from typing import List, Optional

from db.connection import get_pool
from db.supabase_client import get_supabase
from services.trip_planner import NoTripCandidatesError, TripPlannerService

router = APIRouter()


# ── Request models ────────────────────────────────────────────────────────────

class TripPlanRequest(BaseModel):
    id_user:             str
    id_province:         Optional[str]       = None
    n_days:              int
    start_date:          Optional[str]       = None   # 'YYYY-MM-DD'; defaults to today
    sa_runs:             int                 = 2
    save_plan:           bool                = False
    interest_option_ids: Optional[List[str]] = None   # trip-level interest (UUIDs)
    target_lat:          Optional[float]     = None   # business-trip geocoord
    target_lng:          Optional[float]     = None
    include_lunch_break: bool                = True   # Step 5 wizard choice

    @model_validator(mode='after')
    def check_location(self):
        has_province = self.id_province is not None
        has_coords   = self.target_lat is not None and self.target_lng is not None
        if not has_province and not has_coords:
            raise ValueError(
                'Phải cung cấp id_province (leisure) hoặc '
                'target_lat + target_lng (business)'
            )
        if has_province and has_coords:
            raise ValueError(
                'Chỉ được cung cấp một trong hai: '
                'id_province hoặc target_lat+target_lng'
            )
        return self


class SavePlanRequest(BaseModel):
    id_user:      str
    custom_title: Optional[str] = None


class RenamePlanRequest(BaseModel):
    id_user:      str
    custom_title: str


class TripLifecycleRequest(BaseModel):
    id_user: str


class RescheduleTripRequest(BaseModel):
    id_user:       str
    new_start_at:  str   # 'YYYY-MM-DD'


# ── Trip planning ─────────────────────────────────────────────────────────────

@router.post("/api/trips/plan")
async def plan_trip(req: TripPlanRequest, supabase=Depends(get_supabase)):
    print(f"[DEBUG] plan request: {req.dict()}")
    start_at = (
        datetime.date.fromisoformat(req.start_date)
        if req.start_date
        else datetime.date.today()
    )

    svc = TripPlannerService(supabase)
    try:
        result = await svc.plan(
            id_user=req.id_user,
            id_province=req.id_province,
            n_days=req.n_days,
            start_at=start_at,
            sa_runs=req.sa_runs,
            save=req.save_plan,
            interest_option_ids=req.interest_option_ids,
            target_lat=req.target_lat,
            target_lng=req.target_lng,
            include_lunch_break=req.include_lunch_break,
        )
    except NoTripCandidatesError as exc:
        raise HTTPException(
            status_code=422,
            detail={"error_code": "no_candidates", "message": str(exc)},
        ) from exc
    # print(f"[DEBUG] response days count: {len(result.get('days', []))}")
    # print(f"[DEBUG] response: {result}")
    return result


_NEARBY_SUBCATEGORIES = [
    "Y tế / Bệnh viện",
    "Nhà thuốc",
    "Bến xe / Sân bay / Ga tàu",
    "Ngân hàng / ATM",
    "Trạm xăng",
    "Cơ quan hành chính",
    "Công an / Cảnh sát",
    "Trường học / Đại học",
]


@router.get("/api/places/nearby")
async def get_nearby_places(
    lat: float,
    lng: float,
    limit: int = 3,
    supabase=Depends(get_supabase),
):
    from db.place_repository import fetch_nearby_amenities
    places = await asyncio.to_thread(
        fetch_nearby_amenities, supabase, lat, lng, _NEARBY_SUBCATEGORIES, limit_per_category=limit
    )
    return {"places": places}


@router.get("/api/trips/plan/{id_plan}")
async def get_plan(id_plan: str, id_user: str, supabase=Depends(get_supabase)):
    from db.queries_plan import get_plan as _get_plan

    plan = await asyncio.to_thread(_get_plan, supabase, id_plan, id_user=id_user)
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found.")
    return plan


@router.get("/api/trips/plans")
async def list_plans(id_user: str, supabase=Depends(get_supabase)):
    from db.queries_plan import list_plans as _list_plans

    plans = await asyncio.to_thread(_list_plans, supabase, id_user)
    return {"plans": plans}


@router.post("/api/trips/{id_plan}/clone")
async def clone_trip(id_plan: str, req: SavePlanRequest, supabase=Depends(get_supabase)):
    from db.queries_plan import clone_plan

    result = await asyncio.to_thread(clone_plan, supabase, id_plan, req.id_user)
    if not result:
        raise HTTPException(status_code=404, detail="Plan not found.")
    return result


@router.post("/api/trips/{id_plan}/save")
async def save_trip(id_plan: str, req: SavePlanRequest, supabase=Depends(get_supabase)):
    from db.queries_plan import mark_plan_saved

    result = await asyncio.to_thread(
        mark_plan_saved, supabase, id_plan, req.id_user, req.custom_title
    )
    if not result:
        raise HTTPException(status_code=404, detail="Plan not found or not owned by user.")
    return result


@router.patch("/api/trips/{id_plan}/title")
async def rename_trip(id_plan: str, req: RenamePlanRequest, supabase=Depends(get_supabase)):
    from db.queries_plan import DuplicateTripTitleError, rename_plan

    try:
        result = await asyncio.to_thread(
            rename_plan, supabase, id_plan, req.id_user, req.custom_title
        )
    except DuplicateTripTitleError as exc:
        raise HTTPException(
            status_code=409,
            detail={
                "error_code": "duplicate_trip_title",
                "message": "You already have a trip with this name.",
            },
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail={"error_code": "invalid_trip_title", "message": str(exc)},
        ) from exc

    if not result:
        raise HTTPException(status_code=404, detail="Plan not found or not owned by user.")
    return result


@router.get("/api/trips/saved")
async def get_saved_plans(id_user: str, supabase=Depends(get_supabase)):
    from db.queries_plan import fetch_saved_plans

    plans = await asyncio.to_thread(fetch_saved_plans, supabase, id_user)
    return {"plans": plans}


# ── Trip lifecycle (Trip Tracker) ───────────────────────────────────────────

@router.post("/api/trips/{id_plan}/reschedule")
async def reschedule_trip(
    id_plan: str, req: RescheduleTripRequest, supabase=Depends(get_supabase)
):
    from db.queries_plan import reschedule_plan

    new_start_at = datetime.date.fromisoformat(req.new_start_at)
    result = await asyncio.to_thread(
        reschedule_plan, supabase, id_plan, req.id_user, new_start_at
    )
    if not result:
        raise HTTPException(status_code=404, detail="Plan not found or not owned by user.")
    return result


@router.post("/api/trips/{id_plan}/complete")
async def complete_trip(
    id_plan: str, req: TripLifecycleRequest, supabase=Depends(get_supabase)
):
    from db.queries_plan import complete_plan

    result = await asyncio.to_thread(complete_plan, supabase, id_plan, req.id_user)
    if not result:
        raise HTTPException(status_code=404, detail="Plan not found or not owned by user.")
    return result


@router.get("/api/trips/overdue-check")
async def overdue_check(id_user: str, supabase=Depends(get_supabase)):
    from db.queries_plan import get_overdue_plans

    plans = await asyncio.to_thread(get_overdue_plans, supabase, id_user)

    def _enqueue_first_time_notifications():
        # Side effect deliberately kept out of get_overdue_plans() (which
        # stays a pure query reusable by a future pg_cron job): the first
        # time a plan is seen overdue, drop a real row into `notification`
        # (so it's reachable from the bell if the Home dialog is missed)
        # and mark it so we never enqueue a duplicate for the same plan.
        for plan in plans:
            if plan.get("overdue_notified_at"):
                continue
            id_plan = plan["id_plan"]
            province_name = plan.get("province_name") or "your destination"
            supabase.rpc("enqueue_user_notification", {
                "p_id_user": id_user,
                "p_notification_type": "trip",
                "p_title": "Have you completed your trip?",
                "p_body": f"Your trip to {province_name} was due to end a few days ago.",
                "p_icon": "calendar",
                "p_target": {
                    "kind": "tripOverdueCheck",
                    "entityId": id_plan,
                    # Snapshot at detection time so the notification's embedded
                    # trip card can render without an extra fetch per item —
                    # see Flutter's NotificationTarget.metadata (free-form,
                    # already round-tripped through payload_jsonb as-is).
                    "metadata": {
                        "customTitle": plan.get("custom_title") or "",
                        "startAt": plan.get("start_at") or "",
                        "endAt": plan.get("end_at") or "",
                    },
                },
                "p_is_push": True,
            }).execute()
            supabase.table("plan").update({
                "overdue_notified_at": datetime.datetime.utcnow().isoformat(),
            }).eq("id_plan", id_plan).eq("id_user", id_user).execute()

    if plans:
        await asyncio.to_thread(_enqueue_first_time_notifications)

    return {"plans": plans}


# ── Admin: CF retrain ─────────────────────────────────────────────────────────

@router.post("/admin/cf/retrain")
async def trigger_cf_retrain(background_tasks: BackgroundTasks):
    from jobs.cf_retrain import run_cf_retrain
    try:
        await get_pool()
    except Exception as exc:
        raise HTTPException(
            status_code=503, detail=f"CF retrain database unavailable: {exc}"
        ) from exc

    background_tasks.add_task(run_cf_retrain, triggered_by='admin')
    return {"status": "queued", "message": "CF re-train job started in background."}


@router.get("/admin/cf/retrain/logs")
async def get_retrain_logs():
    try:
        pool = await get_pool()
    except Exception as exc:
        raise HTTPException(
            status_code=503, detail=f"CF retrain database unavailable: {exc}"
        ) from exc

    try:
        async with pool.acquire() as conn:
            rows = await conn.fetch("""
                SELECT id_log, triggered_by, started_at, finished_at,
                       status, rows_written, error_msg
                FROM cf_retrain_log
                ORDER BY started_at DESC
                LIMIT 20
            """)
    except Exception as exc:
        raise HTTPException(
            status_code=500, detail=f"Failed to load retrain logs: {exc}"
        ) from exc

    return [dict(r) for r in rows]
