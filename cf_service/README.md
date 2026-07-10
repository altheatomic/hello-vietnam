# Hello Vietnam CF / Trip Planner Service

This FastAPI service runs the trip-planning and recommendation algorithm used by
the Supabase Edge Function `trip-planner`.

`CF_SERVICE_URL` must point to the public URL where this service is running.
For local testing, it can point to a tunnel URL such as ngrok or Cloudflare
Tunnel. For production, deploy this folder to a Python host such as Render,
Railway, Fly.io, Google Cloud Run, or another backend server.

## Required Environment Variables

```env
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
DATABASE_URL=postgresql://postgres:<password>@db.<project-ref>.supabase.co:5432/postgres
```

## Run Locally

From this folder:

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

Health check:

```bash
curl http://localhost:8000/health
```

If the service is only running locally but the Edge Function is deployed on
Supabase Cloud, expose it with a tunnel and set:

```bash
npx supabase secrets set CF_SERVICE_URL="https://<your-public-tunnel-url>"
npx supabase functions deploy trip-planner
```

Do not use `http://localhost:8000` as `CF_SERVICE_URL` for a deployed Supabase
Edge Function. In Supabase Cloud, `localhost` means the Edge Function runtime,
not your computer.
