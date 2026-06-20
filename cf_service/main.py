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

from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI

load_dotenv()  # picks up .env in cwd if present

from db.connection import close_pool, init_pool
from routes.trip import router as trip_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    # TODO: uncomment khi có DATABASE_URL
    # await init_pool()
    yield
    # await close_pool()


app = FastAPI(
    title="Hello Vietnam – CF & Trip Planner Service",
    version="1.0.0",
    lifespan=lifespan,
)

app.include_router(trip_router)


@app.get("/health")
async def health():
    return {"status": "ok"}
