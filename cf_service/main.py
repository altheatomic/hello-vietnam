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
from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

load_dotenv()  # picks up .env in cwd if present

from db.connection import close_pool
from routes.trip import router as trip_router
from routes.events import router as events_router
from routes.recommend import router as recommend_router

EXECUTOR_MAX_WORKERS = 30


@asynccontextmanager
async def lifespan(app: FastAPI):
    executor = ThreadPoolExecutor(max_workers=EXECUTOR_MAX_WORKERS)
    loop = asyncio.get_running_loop()
    loop.set_default_executor(executor)
    app.state.executor = executor
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

app.include_router(trip_router)
app.include_router(events_router)
app.include_router(recommend_router)


@app.get("/health")
async def health():
    return {"status": "ok"}
