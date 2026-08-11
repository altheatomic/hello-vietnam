"""
cf_service/main.py
FastAPI entry point for the CF + trip-planner service.

Environment variables (put in .env or set externally):
  SUPABASE_URL              — Supabase project URL
                              e.g. https://<project>.supabase.co
  SUPABASE_SERVICE_ROLE_KEY — Supabase service role key (server-side only, never expose to frontend)
  DATABASE_URL              — asyncpg-compatible Supabase connection string (used only by CF retrain job)
                              e.g. postgresql://postgres:<password>@db.<project>.supabase.co:5432/postgres

Run locally:
  uvicorn main:app --reload --port 8000
"""

import asyncio
import json
from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

load_dotenv()  # picks up .env in cwd if present

from db.connection import close_pool
from db.connection import get_pool
from jobs.cf_retrain import run_cf_retrain
from routes.trip import router as trip_router
from routes.events import router as events_router
from routes.recommend import router as recommend_router
from services.cf_retrain_schedule import (
    JOB_ID,
    build_cf_retrain_trigger,
    load_cf_retrain_schedule,
)

EXECUTOR_MAX_WORKERS = 30

async def _run_scheduled_cf_retrain() -> None:
    print(json.dumps({"event": "cf_retrain_scheduled_start", "triggered_by": "scheduled_daily"}))
    result = await run_cf_retrain(triggered_by="scheduled_daily")
    print(json.dumps({"event": "cf_retrain_scheduled_end", **result}))


@asynccontextmanager
async def lifespan(app: FastAPI):
    executor = ThreadPoolExecutor(max_workers=EXECUTOR_MAX_WORKERS)
    loop = asyncio.get_running_loop()
    loop.set_default_executor(executor)
    app.state.executor = executor

    try:
        schedule = await load_cf_retrain_schedule(await get_pool())
    except Exception as exc:
        print(json.dumps({
            "event": "cf_retrain_schedule_load_failed",
            "error": str(exc),
        }))
        executor.shutdown(wait=False)
        await close_pool()
        raise RuntimeError(
            "Could not load the persisted CF retrain schedule; scheduler was not started."
        ) from exc

    scheduler = AsyncIOScheduler(timezone="UTC")
    scheduler.add_job(
        _run_scheduled_cf_retrain,
        trigger=build_cf_retrain_trigger(schedule.hour_utc, schedule.minute_utc),
        id=JOB_ID,
        replace_existing=True,
    )
    scheduler.start()
    app.state.scheduler = scheduler
    print(json.dumps({
        "event": "scheduler_started",
        "job": JOB_ID,
        "cron_utc": f"{schedule.hour_utc:02d}:{schedule.minute_utc:02d}",
    }))

    yield

    scheduler.shutdown()
    executor.shutdown(wait=True)
    await close_pool()


app = FastAPI(
    title="Hello Vietnam – CF & Trip Planner Service",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
# Added last so it wraps outermost (compresses after CORS headers are set).
# Perf audit (2026-08-10): plan()'s response can carry many places × several
# days of JSON — gzip typically cuts repetitive JSON payloads 60-80%,
# directly reducing transfer time on mobile networks. minimum_size=1000
# skips compressing tiny responses where the gzip overhead isn't worth it.
app.add_middleware(GZipMiddleware, minimum_size=1000)

app.include_router(trip_router)
app.include_router(events_router)
app.include_router(recommend_router)


@app.get("/health")
async def health():
    return {"status": "ok"}
