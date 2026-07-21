# Hello Vietnam CF / Trip Planner Service

This FastAPI service runs the trip-planning and recommendation algorithm used by
the Supabase Edge Function `trip-planner`.

`CF_SERVICE_URL` must point to the public URL where this service is running.
For local testing, it can point to a tunnel URL such as ngrok or Cloudflare
Tunnel. For production, deploy this folder to a Python host such as Render,
Railway, Fly.io, Google Cloud Run, or another backend server.

## Request Flow

```text
Flutter app -> Supabase Edge Function trip-planner -> cf_service -> Supabase DB
```

The Edge Function keeps the frontend simple and authenticated. This service keeps
the Python/ML dependencies out of Supabase Edge Functions.

## Required Environment Variables

Copy `.env.example` to `.env` for local development:

```env
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
DATABASE_URL=postgresql://postgres:<password>@db.<project-ref>.supabase.co:5432/postgres
```

`SUPABASE_SERVICE_ROLE_KEY` and `DATABASE_URL` are server-only secrets. Never put
them in Flutter or any client-side config.

## Run Locally

From this folder:

```bat
copy .env.example .env
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

Health check:

```bash
curl http://localhost:8000/health
```

Expected response:

```json
{"status":"ok"}
```

If the service is only running locally but the Edge Function is deployed on
Supabase Cloud, expose it with a tunnel and set:

```bat
npx supabase secrets set CF_SERVICE_URL="https://<your-public-tunnel-url>"
npx supabase functions deploy trip-planner
```

Do not use `http://localhost:8000` as `CF_SERVICE_URL` for a deployed Supabase
Edge Function. In Supabase Cloud, `localhost` means the Edge Function runtime,
not your computer.

## Docker

Build and run:

```bat
docker build -t hello-vietnam-cf-service .
docker run --env-file .env -p 8000:8000 hello-vietnam-cf-service
```

Then check:

```bat
curl http://localhost:8000/health
```

## Deploy

Any Python host that supports Docker or `uvicorn` can run this service.

Recommended simple path for the project:

1. Deploy this `cf_service` folder to Render, Railway, Fly.io, Cloud Run, or a VPS.
2. Add the three required environment variables in that host's dashboard.
3. Copy the public service URL, for example `https://hello-vietnam-trip.onrender.com`.
4. Set it in Supabase:

```bat
cd D:\Work\hello-vietnam\backend
npx supabase secrets set CF_SERVICE_URL="https://hello-vietnam-trip.onrender.com"
npx supabase functions deploy trip-planner
```

## Common Checks

- `CF_SERVICE_URL/health` must return `{"status":"ok"}`.
- `CF_SERVICE_URL` must not end with `/api/trips`; use only the base URL.
- If Trip Planner fails only after deploy, confirm the service host can connect
  to Supabase using `DATABASE_URL`.
- If Supabase Edge Function returns a fetch/network error, confirm
  `CF_SERVICE_URL` is public and not `localhost`.
