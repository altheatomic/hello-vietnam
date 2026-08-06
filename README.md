# Hello Vietnam

Monorepo layout:

- `frontend/`: Flutter app for user and admin experiences
- `backend/`: Supabase functions, SQL, migrations, and backend support files
- `.vscode/`: shared launch configs for local development

Run from VS Code:

- `User`: launches `frontend/lib/main.dart` on web port `3000`
- `Admin`: launches `frontend/lib/main_admin.dart` on web port `3001`
- `User Mobile` / `Admin Mobile`: launch the Flutter app on a connected mobile device

Common paths:

- Flutter code: [frontend/lib](frontend/lib)
- Flutter config: [frontend/pubspec.yaml](frontend/pubspec.yaml)
- Supabase functions: [backend/supabase/functions](backend/supabase/functions)
- Database SQL: [backend/db](backend/db)

Data freshness operations are documented in
[docs/data-freshness-operations.md](docs/data-freshness-operations.md). The
hybrid workflow automatically checks due sources and dated events, keeps risky
changes in an admin review queue, and lets authenticated users report incorrect
hours, locations, closures, or ended events.
