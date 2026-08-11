"""
cf_service/main.py
FastAPI entry point for the CF + trip-planner service.

Environment variables (put in .env or set externally):
  SUPABASE_URL              — Supabase project URL
                              e.g. https://<project>.supabase.co
  SUPABASE_SERVICE_ROLE_KEY — Supabase service role key (server-side only, never expose to frontend)
  DATABASE_URL              — asyncpg-compatible Supabase connection string (used only by CF retrain job)
                              e.g. postgresql://postgres:<password>@db.<project>.supabase.co:5432/postgres
  CF_RETRAIN_SHARED_SECRET  - optional shared secret used to authenticate
                              pg_cron calls to the retrain endpoint

Run locally:
  uvicorn main:app --reload --port 8000
"""

import asyncio
import json
import os
from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

load_dotenv()  # picks up .env in cwd if present

from db.connection import close_pool
from routes.trip import router as trip_router
from routes.events import router as events_router
from routes.recommend import router as recommend_router

EXECUTOR_MAX_WORKERS = 30


def _warn_if_cf_retrain_secret_missing() -> bool:
    if os.environ.get("CF_RETRAIN_SHARED_SECRET"):
        return False
    print(json.dumps({"event": "cf_retrain_secret_missing_startup"}))
    return True


@asynccontextmanager
async def lifespan(app: FastAPI):
    executor = ThreadPoolExecutor(max_workers=EXECUTOR_MAX_WORKERS)
    loop = asyncio.get_running_loop()
    loop.set_default_executor(executor)
    app.state.executor = executor

    _warn_if_cf_retrain_secret_missing()

    yield

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
