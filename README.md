# HelloVietnam Monorepo

This repository is split into separate frontend and backend workspaces.

## Structure

- `frontend/`: Flutter application
- `backend/`: Supabase backend, schema, functions, and backend docs
- `docs/legacy-extracts/`: archived extracted text files kept for reference only

## Common workflows

Frontend:

```powershell
cd frontend
flutter pub get
flutter run
```

Backend:

```powershell
cd backend/supabase
supabase start
```

## Notes

- Git stays at the repository root.
- Flutter IDE launch configs at the repo root should target files under `frontend/`.
