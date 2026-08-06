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
from apscheduler.triggers.cron import CronTrigger
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

load_dotenv()  # picks up .env in cwd if present

from db.connection import close_pool
from jobs.cf_retrain import run_cf_retrain
from routes.trip import router as trip_router
from routes.events import router as events_router
from routes.recommend import router as recommend_router

EXECUTOR_MAX_WORKERS = 30

# Daily CF retrain time. Server runs python:3.11-slim in Docker with no TZ
# env var set, so the container clock is UTC — pinned explicitly below so
# behaviour doesn't depend on the host machine's local clock (e.g. local dev
# outside Docker). 19:00 UTC = 2:00 sáng Vietnam time (UTC+7).
CF_RETRAIN_HOUR_UTC = 19
CF_RETRAIN_MINUTE_UTC = 0


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

    scheduler = AsyncIOScheduler(timezone="UTC")
    scheduler.add_job(
        _run_scheduled_cf_retrain,
        trigger=CronTrigger(
            hour=CF_RETRAIN_HOUR_UTC, minute=CF_RETRAIN_MINUTE_UTC, timezone="UTC"
        ),
        id="daily_cf_retrain",
        replace_existing=True,
    )
    scheduler.start()
    app.state.scheduler = scheduler
    print(json.dumps({
        "event": "scheduler_started",
        "job": "daily_cf_retrain",
        "cron_utc": f"{CF_RETRAIN_HOUR_UTC:02d}:{CF_RETRAIN_MINUTE_UTC:02d}",
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

app.include_router(trip_router)
app.include_router(events_router)
app.include_router(recommend_router)


@app.get("/health")
async def health():
    return {"status": "ok"}
