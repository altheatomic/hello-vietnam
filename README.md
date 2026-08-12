# Hello Vietnam

Hello Vietnam is a Flutter travel application backed by Supabase Edge
Functions and a FastAPI recommendation/trip-planning service.

## Supported targets

- Android user: `frontend/lib/main.dart`
- Web user: `frontend/lib/main.dart`
- Web admin: `frontend/lib/main_admin.dart`

The `final` branch intentionally excludes iOS and desktop scaffolding. The
complete pre-cleanup history remains on `check`.

## Repository layout

- `frontend/`: Flutter source, Android/Web scaffolding, assets, tests
- `backend/supabase/`: canonical Edge Functions, migrations, SQL tests
- `backend/crawldata/`: active crawler and cached demo fallback
- `cf_service/`: FastAPI recommendation and trip-planning service
- `trip-share-web/`: public static trip viewer
- `scripts/`: repeatable demo scripts
- `docs/`: current runbooks, architecture, evidence, cleanup report
- `evaluation/ai_quality/`: reproducible AI evaluation code and datasets

## Flutter

```powershell
cd frontend
flutter pub get --enforce-lockfile
flutter run -d chrome --target lib/main.dart --web-port 3000
```

Web admin:

```powershell
cd frontend
flutter run -d chrome --target lib/main_admin.dart --web-port 3001
```

Android user:

```powershell
cd frontend
flutter run --target lib/main.dart
```

VS Code provides `User`, `Admin`, `User Mobile`, and `User + Admin`. Android
push notifications require local file
`frontend/android/app/google-services.json`; never commit it.

## FastAPI service

```powershell
cd cf_service
python -m venv .venv
./.venv/Scripts/python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
./.venv/Scripts/python.exe -m uvicorn main:app --reload --port 8000
```

Populate `.env` locally. Never put a service-role key or database password in
Flutter, Git, screenshots, or documentation.

## Supabase

The canonical Supabase working directory is `backend`:

```powershell
cd backend
npm ci
npx supabase migration list --linked
npx supabase functions deploy trip-planner
```

Database migrations are applied only during an explicitly approved deployment.

## Data freshness demo

```powershell
Set-ExecutionPolicy -Scope Process Bypass
./scripts/data-freshness-demo.ps1 -Mode preflight
./scripts/data-freshness-demo.ps1 -Mode crawler -Limit 5
./scripts/data-freshness-demo.ps1 -Mode checker -CheckerBatchSize 5 -SupabaseUrl $env:SUPABASE_URL
```

Checker mode also requires process variable `DATA_FRESHNESS_CHECK_SECRET`. The
script never prints it. See `docs/data-freshness-demo-runbook.md`.

## Trip sharing

`trip-share-web/` is a dependency-free Cloudflare Pages output directory. Set
its public Function URL in `trip-share-web/config.js`.

## Verification

```powershell
cd frontend
flutter analyze --no-fatal-infos
flutter test --reporter compact

cd ../cf_service
./.venv/Scripts/python.exe -m compileall -q .
./.venv/Scripts/python.exe -m unittest discover -s . -p 'test_*.py' -v
```

See `docs/final-cleanup-report.md` for all checks and known baseline debt.
