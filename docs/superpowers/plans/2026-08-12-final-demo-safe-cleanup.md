# Final Demo-Safe Repository Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a minimal, demo-safe `final` branch that retains Android user, Web user/admin, Supabase, FastAPI, trip sharing, data freshness operations, core tests, and a compact evidence set.

**Architecture:** Perform an evidence-driven cleanup in reviewable batches. Remove deterministic artifacts first, then delete only dependency-proven dead code, running the owning subsystem's tests after every batch. Preserve `check` as the recovery source and make no product, API, schema, production-data, dependency-version, deployment, or secret changes.

**Tech Stack:** Flutter 3.38.9+/Dart 3.10.8+, Android Gradle, Supabase CLI 2.88.0, Supabase Edge Functions/Deno 2.9.4, PostgreSQL migrations, Python 3.11/FastAPI, PowerShell, static HTML/CSS/JavaScript, Git.

## Global Constraints

- Work only in `D:\Work\hello-vietnam\.worktrees\final` on branch `final`.
- Preserve branch `check` and the user's dirty checkout at `D:\Work\hello-vietnam` unchanged.
- Support Android for the user app and Web for both user and admin apps.
- Do not retain iOS or desktop platform scaffolding on `final`.
- Keep core tests, current operational runbooks, one current architecture diagram, and reproducible AI assessment evidence.
- Do not change product behavior, visual behavior, API contracts, database schema, production data, dependency versions, deployed resources, or secrets.
- Use explicit paths for deletions; never recursively delete the repository root or an unresolved variable.
- Never commit `.env`, Firebase configuration, Supabase `.temp`, service-role keys, database credentials, or machine-specific agent settings.
- Treat these as baseline debt, not cleanup regressions: two Flutter `info` diagnostics, two `npm audit` advisories, `_shared` Deno import-map type-check limitation, and the named `manage-uploaded-media` type/runtime failures recorded in the design.
- Every task ends with a focused commit and clean worktree.

## Target File Structure

```text
.vscode/launch.json
backend/crawldata/
backend/supabase/
backend/deno.lock
backend/package.json
backend/package-lock.json
cf_service/
docs/architecture/system-architecture.svg
docs/evidence/ai-quality/
docs/superpowers/plans/2026-08-12-final-demo-safe-cleanup.md
docs/superpowers/specs/2026-08-12-final-demo-safe-cleanup-design.md
evaluation/ai_quality/
frontend/android/
frontend/assets/
frontend/lib/
frontend/test/
frontend/web/
scripts/data-freshness-demo.ps1
trip-share-web/
.gitignore
README.md
```

---

### Task 1: Record the Immutable Baseline

**Files:**
- Create: `docs/final-cleanup-report.md`
- Reference: `docs/superpowers/specs/2026-08-12-final-demo-safe-cleanup-design.md`

**Interfaces:**
- Consumes: Baseline measured before cleanup and corrected in design commit `9e2c2e6`.
- Produces: A baseline report that Task 8 extends with final verification.

- [ ] **Step 1: Verify branch and worktree isolation**

```powershell
$root = (git rev-parse --show-toplevel).Trim()
$branch = (git branch --show-current).Trim()
if ($root -notlike '*\.worktrees\final' -and $root -notlike '*/.worktrees/final') {
  throw "Wrong worktree: $root"
}
if ($branch -ne 'final') { throw "Wrong branch: $branch" }
git status -sb
```

Expected: branch `final`, clean worktree.

- [ ] **Step 2: Prove the structural guard fails before deletion**

```powershell
$forbidden = @(
  '.agents', '.claude', '.vscode/mcp.json', 'android', 'ios',
  'frontend/ios', 'supabase', 'ui-patches', 'codex_backup.patch',
  'backend/crawldata.zip', 'report-assets'
)
$present = @($forbidden | Where-Object { Test-Path -LiteralPath $_ })
if ($present.Count -gt 0) { throw "Pre-cleanup paths: $($present -join ', ')" }
```

Expected: FAIL and list the current clutter.

- [ ] **Step 3: Create the baseline report**

Create `docs/final-cleanup-report.md` with exactly:

```markdown
# Final Branch Cleanup Report

## Scope

This report covers demo-safe cleanup of branch `final`, created from `check`
commit `033bb8d`. Branch `check` remains the complete recovery source.

Supported deliverables are Android user, Web user/admin, Supabase Edge
Functions and migrations, FastAPI trip/recommend service, trip-share web, and
the data-freshness demo workflow.

## Pre-cleanup baseline

- Flutter tests: 476 passed.
- Flutter analyzer: 2 existing `info` diagnostics; 0 warnings; 0 errors.
- FastAPI/CF tests: 126 passed after excluding interactive HTTP probe
  `test_cb_cf_demo.py`.
- Data-freshness crawler tests: 4 passed.
- AI evaluation framework tests: 31 passed.
- Deno: 15 of 17 configured test directories type-check and pass.
- Deno `_shared`: 23 runtime tests pass with the subscription-payment import
  map and `--no-check`.
- Deno `manage-uploaded-media`: 2 existing `BufferSource` type errors; runtime
  result is 10 passed and 1 existing named failure.
- Node install succeeds from lockfile; audit reports 1 moderate and 1 critical
  advisory.

## Baseline exclusions

Cleanup does not silently repair or hide the analyzer information messages,
dependency advisories, or documented Deno failures. Final verification must
show that none worsened.
```

- [ ] **Step 4: Validate and commit**

```powershell
git diff --check
git add -- docs/final-cleanup-report.md
git diff --cached --check
git commit -m "docs: record final cleanup baseline"
git status -sb
```

Expected: one documentation commit and clean worktree.

---

### Task 2: Remove Personal Configuration and Unsupported Platforms

**Files:**
- Delete: `.agents/**`, `.claude/**`, `.vscode/mcp.json`, `skills-lock.json`
- Delete: `android/**`, `ios/**`, `frontend/ios/**`
- Modify: `.gitignore`
- Preserve: `.vscode/launch.json`, `frontend/android/**`, `frontend/web/**`

**Interfaces:**
- Consumes: Confirmed Android user and Web user/admin scope.
- Produces: Only supported platform scaffolding and no personal agent configuration.

- [ ] **Step 1: Capture the exact tracked deletion set**

```powershell
$remove = @(git ls-files .agents .claude android ios frontend/ios)
$remove += '.vscode/mcp.json', 'skills-lock.json'
$remove = @($remove | Sort-Object -Unique)
$remove | ForEach-Object { Write-Output $_ }
if ($remove.Count -eq 0) { throw 'Expected personal/platform files were not found' }
```

Expected: no `.vscode/launch.json`, `frontend/android`, or `frontend/web` path.

- [ ] **Step 2: Delete only the captured paths**

Use `apply_patch` with one `*** Delete File:` entry per path from Step 1. Do not use a repository-wide wildcard deletion.

- [ ] **Step 3: Add precise ignore rules once**

```gitignore
# Final branch: unsupported root/platform scaffolding and personal tooling
/android/
/ios/
/frontend/ios/
/.agents/
/.claude/
/.vscode/mcp.json
/skills-lock.json
**/supabase/.temp/
backend/crawldata/.demo-venv/
```

- [ ] **Step 4: Verify structure and Flutter smoke tests**

```powershell
$required = @('.vscode/launch.json', 'frontend/android', 'frontend/web')
$missing = @($required | Where-Object { -not (Test-Path -LiteralPath $_) })
if ($missing.Count) { throw "Missing: $($missing -join ', ')" }
$forbidden = @('.agents', '.claude', '.vscode/mcp.json', 'android', 'ios', 'frontend/ios', 'skills-lock.json')
$present = @($forbidden | Where-Object {
  if (Test-Path -LiteralPath $_ -PathType Leaf) { $true }
  elseif (Test-Path -LiteralPath $_ -PathType Container) {
    @(Get-ChildItem -LiteralPath $_ -File -Force -Recurse).Count -gt 0
  } else { $false }
})
if ($present.Count) { throw "Still present: $($present -join ', ')" }

Push-Location frontend
try {
  flutter pub get --enforce-lockfile
  flutter analyze --no-fatal-infos
  flutter test test/app/admin_routes_test.dart test/widget_test.dart --reporter compact
} finally { Pop-Location }
```

Expected: supported paths exist, forbidden paths are absent, analyzer has no warning/error, selected tests pass.

- [ ] **Step 5: Commit**

```powershell
git add -- .gitignore .vscode frontend
git add -u -- .agents .claude android ios skills-lock.json
git diff --cached --check
git commit -m "chore: remove personal and unsupported platform files"
git status -sb
```

Expected: focused commit and clean worktree.

---

### Task 3: Consolidate Backend Layout and Retain the Active Crawler

**Files:**
- Delete: `supabase/**`, `backend/supabase/supabase/**`
- Delete: `backend/db/**`, `backend/location/**`, `backend/personalization/**`
- Delete: `backend/crawldata.zip`, `codex_backup.patch`, `ui-patches/**`
- Preserve: `backend/supabase/functions/**`, `backend/supabase/migrations/**`, `backend/supabase/tests/**`
- Preserve: active crawler, its identity module, requirements, test, and six cached output files

**Interfaces:**
- Consumes: Canonical Supabase root `backend/supabase` and `scripts/data-freshness-demo.ps1`.
- Produces: One Supabase layout and a self-contained crawler demo with cached fallback.

- [ ] **Step 1: Prove canonical migrations are complete**

```powershell
$canonical = @(Get-ChildItem backend/supabase/migrations -File -Filter '*.sql' | Sort-Object Name)
if ($canonical.Count -ne 72) { throw "Expected 72 migrations, found $($canonical.Count)" }
if (@($canonical | Where-Object Length -eq 0).Count) { throw 'Canonical migration is empty' }
$versions = $canonical | ForEach-Object {
  if ($_.BaseName -notmatch '^(\d{14})_') { throw "Invalid migration: $($_.Name)" }
  $matches[1]
}
$duplicates = @($versions | Group-Object | Where-Object Count -gt 1)
if ($duplicates.Count) { throw "Duplicate versions: $($duplicates.Name -join ', ')" }
```

Expected: 72 nonempty migrations with unique versions.

- [ ] **Step 2: Prove the active crawler does not consume legacy seed files**

```powershell
rg -n 'city_mapping|city_province_rows|food_type_mapping|food_type_rows|foods_standardized|hanoi_seed|stage1_seed_places|wiki_food_scraper|json_to_csv' `
  backend/crawldata/crawl_seed_data_fixed_v3.py `
  backend/crawldata/source_identity.py `
  scripts/data-freshness-demo.ps1 `
  docs/data-freshness-demo-runbook.md
```

Expected: no matches.

- [ ] **Step 3: Delete duplicate backend and archive paths**

Use `git ls-files` to enumerate and `apply_patch` to delete every tracked file under:

```text
supabase
backend/supabase/supabase
backend/db
backend/location
backend/personalization
ui-patches
```

Also delete `backend/crawldata.zip` and `codex_backup.patch` with `apply_patch`.

- [ ] **Step 4: Delete historical crawler files**

Use `apply_patch` on these exact paths:

```text
backend/crawldata/city_mapping.csv
backend/crawldata/city_province_rows.csv
backend/crawldata/food_import_new.csv
backend/crawldata/food_type_mapping.csv
backend/crawldata/food_type_rows.csv
backend/crawldata/foods.csv
backend/crawldata/foods_standardized.csv
backend/crawldata/hanoi_seed.json
backend/crawldata/json_to_csv.py
backend/crawldata/place_stage1_notes.md
backend/crawldata/stage1_seed_places.py
backend/crawldata/stage1_seed_places_patched.py
backend/crawldata/stage1_seed_places_patched_v2.py
backend/crawldata/wiki_food_scraper_new.py
```

- [ ] **Step 5: Re-run migration and retained-file guards**

```powershell
git diff --exit-code check -- backend/supabase/migrations
if ($LASTEXITCODE) { throw 'Canonical migrations changed' }
$expected = @(
  'backend/crawldata/crawl_seed_data_fixed_v3.py',
  'backend/crawldata/source_identity.py',
  'backend/crawldata/requirements-demo.txt',
  'backend/crawldata/test_source_identity.py',
  'backend/crawldata/output/activity.csv',
  'backend/crawldata/output/activity.json',
  'backend/crawldata/output/culture.csv',
  'backend/crawldata/output/culture.json',
  'backend/crawldata/output/local_products.csv',
  'backend/crawldata/output/local_products.json'
)
$missing = @($expected | Where-Object { -not (Test-Path -LiteralPath $_) })
if ($missing.Count) { throw "Missing crawler files: $($missing -join ', ')" }
```

Expected: migrations unchanged and all retained crawler paths exist.

- [ ] **Step 6: Build the ignored crawler environment and test it**

```powershell
python -m venv backend/crawldata/.demo-venv
& backend/crawldata/.demo-venv/Scripts/python.exe -m pip install -r backend/crawldata/requirements-demo.txt
& backend/crawldata/.demo-venv/Scripts/python.exe -m unittest discover -s backend/crawldata -p 'test_*.py' -v
Set-ExecutionPolicy -Scope Process Bypass
./scripts/data-freshness-demo.ps1 -Mode preflight
```

Expected: 4 tests pass; crawler dependencies and CLI report OK. An unset `SUPABASE_URL` only skips remote probes.

- [ ] **Step 7: Commit**

```powershell
git add -u -- supabase backend ui-patches codex_backup.patch
git diff --cached --check
git commit -m "chore: consolidate backend and crawler sources"
git status -sb
```

Expected: focused commit; ignored virtualenv is not staged.

---

### Task 4: Remove Generated FastAPI Results and Interactive Probes

**Files:**
- Delete: `cf_service/_test_query.py`, `cf_service/_test_trip.py`, `cf_service/test_cb_cf_demo.py`
- Delete: generated root-level CSV/JSON/stdout/stderr files listed below
- Preserve: `cf_service/scripts/**` and deterministic tests not listed below

**Interfaces:**
- Consumes: FastAPI composition in `cf_service/main.py` and locked requirements.
- Produces: Deterministic unittest discovery without generated output or one-off HTTP probes.

- [ ] **Step 1: Prove candidates have no runtime consumer**

```powershell
rg -n 'audit_cf_coverage_result|load_eval_results|module1_diversity_eval|module1_eval_results|module2_eval_results|module3_benchmark_results|performance_eval|trip_planner_audit_benchmark|province_descriptions_to_translate|_test_query|_test_trip|test_cb_cf_demo' `
  cf_service/main.py cf_service/routes cf_service/services cf_service/jobs cf_service/db cf_service/ml
```

Expected: no runtime imports or reads.

- [ ] **Step 2: Delete exact generated/probe files**

Use `apply_patch` to delete:

```text
cf_service/_test_query.py
cf_service/_test_trip.py
cf_service/test_cb_cf_demo.py
cf_service/audit_cf_coverage_result.csv
cf_service/load_eval_results.csv
cf_service/module1_diversity_eval_mixed_results.csv
cf_service/module1_diversity_eval_results.csv
cf_service/module1_eval_results.csv
cf_service/module2_eval_results.csv
cf_service/module3_benchmark_results.csv
cf_service/performance_eval_extended.csv
cf_service/performance_eval_results.csv
cf_service/province_descriptions_to_translate.json
cf_service/trip_planner_audit_benchmark.csv
cf_service/trip_planner_audit_benchmark.stderr.txt
cf_service/trip_planner_audit_benchmark.stdout.txt
```

- [ ] **Step 3: Build the ignored FastAPI environment**

```powershell
python -m venv cf_service/.venv
& cf_service/.venv/Scripts/python.exe -m pip install -r cf_service/requirements.txt
```

Expected: install succeeds without changing `requirements.txt`.

- [ ] **Step 4: Run compile and full test discovery**

```powershell
Push-Location cf_service
try {
  & .venv/Scripts/python.exe -m compileall -q .
  & .venv/Scripts/python.exe -m unittest discover -s . -p 'test_*.py' -v
} finally { Pop-Location }
```

Expected: 126 tests pass with no discovery import error.

- [ ] **Step 5: Assert generated output is no longer tracked**

```powershell
$remaining = @(git ls-files cf_service | Where-Object {
  $_ -match '(result.*\.csv$|benchmark.*\.(csv|stdout\.txt|stderr\.txt)$|province_descriptions_to_translate\.json$)'
})
if ($remaining.Count) { throw "Generated output remains: $($remaining -join ', ')" }
git diff --check
```

Expected: no generated output path remains tracked.

- [ ] **Step 6: Commit**

```powershell
git add -u -- cf_service
git diff --cached --check
git commit -m "chore: remove generated FastAPI evaluation artifacts"
git status -sb
```

Expected: focused commit and clean worktree.

---

### Task 5: Remove Dependency-Proven Flutter Dead Files

**Files:**
- Delete: `frontend/README.md`, `frontend/guide.md`, `frontend/images/**`
- Delete: `frontend/web_entrypoint.dart`
- Delete: seven zero-byte Dart placeholders and `frontend/assets/images/dishes/banh_mi.jpg`
- Preserve: all other Flutter source, declared assets, and tests

**Interfaces:**
- Consumes: `main.dart`, `main_admin.dart`, `pubspec.yaml`, routes, and retained tests.
- Produces: Android/Web Flutter source with no proven zero-byte placeholders.

- [ ] **Step 1: Re-prove candidates are empty and unreferenced**

```powershell
$dead = @(
  'frontend/web_entrypoint.dart',
  'frontend/lib/core/network/api_client.dart',
  'frontend/lib/core/utils/logger.dart',
  'frontend/lib/features/messages/presentation/chat_thread_page.dart',
  'frontend/lib/features/planner/presentation/trip_create_page.dart',
  'frontend/lib/features/planner/presentation/trip_detail_page.dart',
  'frontend/lib/features/profile/presentation/settings_page.dart',
  'frontend/assets/images/dishes/banh_mi.jpg'
)
foreach ($path in $dead) {
  if ((Get-Item -LiteralPath $path).Length -ne 0) { throw "Not empty: $path" }
  $leaf = Split-Path -Leaf $path
  $refs = @(rg -n --hidden -g '!**/.git/**' -g '!**/.dart_tool/**' -g '!**/build/**' -g "!**/$leaf" ([regex]::Escape($leaf)) frontend)
  if ($refs.Count) { throw "Referenced: $path`n$($refs -join "`n")" }
}
```

Expected: all eight candidates are empty and unreferenced.

- [ ] **Step 2: Delete only proven dead/documentation paths**

Use `apply_patch` to delete every path in `$dead`, `frontend/README.md`, `frontend/guide.md`, and every tracked file returned by:

```powershell
git ls-files frontend/images
```

- [ ] **Step 3: Analyze and run all Flutter tests**

```powershell
Push-Location frontend
try {
  flutter pub get --enforce-lockfile
  flutter analyze --no-fatal-infos
  flutter test --reporter compact
} finally { Pop-Location }
```

Expected: same two `info` diagnostics, no warning/error, 476 tests pass.

- [ ] **Step 4: Build every supported Flutter target**

```powershell
Push-Location frontend
try {
  flutter build web --target lib/main.dart
  if (-not (Test-Path build/web/main.dart.js)) { throw 'User Web output missing' }
  flutter build web --target lib/main_admin.dart
  if (-not (Test-Path build/web/main.dart.js)) { throw 'Admin Web output missing' }
  flutter build apk --debug --target lib/main.dart
  if (-not (Test-Path build/app/outputs/flutter-apk/app-debug.apk)) { throw 'APK missing' }
} finally { Pop-Location }
```

Expected: both Web builds and Android debug APK succeed; no Firebase configuration is staged.

- [ ] **Step 5: Commit**

```powershell
git add -u -- frontend
git diff --cached --check
git commit -m "chore: remove unused Flutter placeholders"
git status -sb
```

Expected: focused commit and clean worktree.

---

### Task 6: Curate Minimal Architecture and AI Evidence

**Files:**
- Move: `hello-vietnam-architecture-vi-v5.svg` to `docs/architecture/system-architecture.svg`
- Move: assessment report/summary and three raw source runs to `docs/evidence/ai-quality/**`
- Delete: old architecture/report artifacts, historical plans/specs, intermediate AI result runs
- Delete: `docs/place-content-backfill-phase-a-handoff.md`, `Report.docx.md`, `muc-tieu-cot-loi-cua-app.md`, survey generator

**Interfaces:**
- Consumes: V5 SVG and assessment source runs with measured line counts 54/54/20.
- Produces: Stable evidence paths whose references resolve.

- [ ] **Step 1: Validate source artifacts**

```powershell
[xml](Get-Content -Raw 'hello-vietnam-architecture-vi-v5.svg') | Out-Null
$sources = @(
  @{ Path='evaluation/ai_quality/results/pilot-20260729/raw.jsonl'; Lines=54 },
  @{ Path='evaluation/ai_quality/results/final-20260729/raw.jsonl'; Lines=54 },
  @{ Path='evaluation/ai_quality/results/ai-search-final-20260729/raw.jsonl'; Lines=20 }
)
foreach ($source in $sources) {
  $count = (Get-Content $source.Path | Measure-Object -Line).Lines
  if ($count -ne $source.Lines) { throw "Wrong line count: $($source.Path) = $count" }
}
Get-Content -Raw evaluation/ai_quality/results/assessment-20260729/summary.json | ConvertFrom-Json | Out-Null
```

Expected: SVG/JSON parse and line counts are 54, 54, 20.

- [ ] **Step 2: Move the six retained artifacts**

```powershell
New-Item -ItemType Directory -Force docs/architecture | Out-Null
New-Item -ItemType Directory -Force docs/evidence/ai-quality/source-runs | Out-Null
git mv -- hello-vietnam-architecture-vi-v5.svg docs/architecture/system-architecture.svg
git mv -- evaluation/ai_quality/results/assessment-20260729/report.md docs/evidence/ai-quality/assessment-report.md
git mv -- evaluation/ai_quality/results/assessment-20260729/summary.json docs/evidence/ai-quality/assessment-summary.json
git mv -- evaluation/ai_quality/results/pilot-20260729/raw.jsonl docs/evidence/ai-quality/source-runs/ai-search-pilot.jsonl
git mv -- evaluation/ai_quality/results/final-20260729/raw.jsonl docs/evidence/ai-quality/source-runs/ai-services-final.jsonl
git mv -- evaluation/ai_quality/results/ai-search-final-20260729/raw.jsonl docs/evidence/ai-quality/source-runs/ai-search-quota.jsonl
```

Expected: exactly six artifacts move to stable paths.

- [ ] **Step 3: Rewrite evidence references without changing claims**

Set `source_runs` in `assessment-summary.json` to:

```json
"source_runs": {
  "ai_search_food": "source-runs/ai-search-pilot.jsonl",
  "ai_chat_translation_tts": "source-runs/ai-services-final.jsonl",
  "quota_evidence": "source-runs/ai-search-quota.jsonl"
}
```

Replace the report's three source bullets with:

```markdown
- AI Search lượt sạch: `source-runs/ai-search-pilot.jsonl` (báo cáo này chỉ
  dùng 12 case `search-food-*`).
- Chat/Dịch/TTS lượt cuối: `source-runs/ai-services-final.jsonl`.
- Bằng chứng quota 429: `source-runs/ai-search-quota.jsonl`.
- Tóm tắt máy đọc: `assessment-summary.json`.
```

- [ ] **Step 4: Delete historical artifacts**

Retain only these under `docs/superpowers`:

```text
docs/superpowers/specs/2026-08-12-final-demo-safe-cleanup-design.md
docs/superpowers/plans/2026-08-12-final-demo-safe-cleanup.md
```

Enumerate with `git ls-files` and use `apply_patch` to delete every other file under `docs/superpowers`, `report-assets`, and `evaluation/ai_quality/results`. Also delete every remaining root path matched by `git ls-files 'hello-vietnam-architecture*'` and these exact files:

```text
docs/place-content-backfill-phase-a-handoff.md
Report.docx.md
muc-tieu-cot-loi-cua-app.md
tao_google_form_khao_sat_hellovietnam.gs
```

- [ ] **Step 5: Validate evidence graph and tests**

```powershell
[xml](Get-Content -Raw docs/architecture/system-architecture.svg) | Out-Null
$summary = Get-Content -Raw docs/evidence/ai-quality/assessment-summary.json | ConvertFrom-Json
foreach ($relative in $summary.source_runs.PSObject.Properties.Value) {
  $path = Join-Path docs/evidence/ai-quality $relative
  if (-not (Test-Path $path)) { throw "Missing evidence: $path" }
}
$counts = @{
  'docs/evidence/ai-quality/source-runs/ai-search-pilot.jsonl'=54
  'docs/evidence/ai-quality/source-runs/ai-services-final.jsonl'=54
  'docs/evidence/ai-quality/source-runs/ai-search-quota.jsonl'=20
}
foreach ($entry in $counts.GetEnumerator()) {
  if ((Get-Content $entry.Key | Measure-Object -Line).Lines -ne $entry.Value) {
    throw "Evidence count changed: $($entry.Key)"
  }
}
& cf_service/.venv/Scripts/python.exe -m unittest discover -s evaluation/ai_quality/tests -p 'test_*.py' -v
```

Expected: evidence parses/resolves and 31 evaluation tests pass.

- [ ] **Step 6: Commit**

```powershell
git add -- docs evaluation
git add -u -- report-assets Report.docx.md muc-tieu-cot-loi-cua-app.md tao_google_form_khao_sat_hellovietnam.gs
git diff --cached --check
git commit -m "docs: retain minimal demo evidence"
git status -sb
```

Expected: focused commit and clean worktree.

---

### Task 7: Make README, Launch Profiles, and Runbooks Portable

**Files:**
- Replace: `README.md`
- Modify: `.vscode/launch.json`
- Modify: `docs/ai-recognition-manual-test.md`, `docs/data-freshness-demo-runbook.md`, `docs/data-freshness-manual-test.md`
- Modify: `cf_service/README.md`, `backend/supabase/functions/reviews/README.md`
- Delete: `huongdan.md`

**Interfaces:**
- Consumes: Retained layout from Tasks 2-6.
- Produces: One authoritative setup guide, three launch profiles, no personal absolute paths.

- [ ] **Step 1: Replace root README with the authoritative guide**

Write these sections with the exact commands shown:

````markdown
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
````

- [ ] **Step 2: Remove unsupported Admin Mobile launch profile**

Retain only configuration names `Admin`, `User`, `User Mobile`. Retain compound `User + Admin` with `stopAll: true`. Delete the complete `Admin Mobile` object.

- [ ] **Step 3: Normalize retained absolute paths**

Apply these exact replacements:

```text
docs/ai-recognition-manual-test.md:
  "cd D:\Work\hello-vietnam\frontend" -> "cd frontend"

docs/data-freshness-demo-runbook.md:
  Use relative "cd backend\crawldata", "cd ..\..", and "cd frontend".

docs/data-freshness-manual-test.md:
  Use relative "cd frontend" and "cd backend\crawldata".

cf_service/README.md:
  "cd D:\Work\hello-vietnam\backend" -> "cd ..\backend"

backend/supabase/functions/reviews/README.md:
  Replace the personal Deno executable path with
  "deno test --config backend/supabase/functions/reviews/deno.json backend/supabase/functions/reviews".
```

Delete `huongdan.md` after its supported instructions exist in root README.

- [ ] **Step 4: Verify portability and launch JSON**

```powershell
$personal = @(git grep -n -I -E 'C:\\Users\\(Asus|Novem)|/Users/haku/|D:\\Work\\hello-vietnam' -- . `
  ':(exclude)docs/superpowers/specs/2026-08-12-final-demo-safe-cleanup-design.md' `
  ':(exclude)docs/superpowers/plans/2026-08-12-final-demo-safe-cleanup.md')
if ($personal.Count) { throw "Personal paths remain:`n$($personal -join "`n")" }
$launch = Get-Content -Raw .vscode/launch.json | ConvertFrom-Json
$names = @($launch.configurations.name | Sort-Object)
if (($names -join ',') -ne 'Admin,User,User Mobile') { throw "Launch profiles: $($names -join ', ')" }
```

Expected: no personal paths; exact launch profile set.

- [ ] **Step 5: Validate trip-share local references**

```powershell
$tripRoot = (Resolve-Path trip-share-web).Path
$html = Get-Content -Raw trip-share-web/index.html
$refs = [regex]::Matches($html, '(?:src|href)="([^"]+)"') |
  ForEach-Object { $_.Groups[1].Value } |
  Where-Object { $_ -notmatch '^(https?:|#|mailto:|tel:)' }
foreach ($ref in $refs) {
  $candidate = Join-Path $tripRoot ($ref.TrimStart('/').Split('?')[0])
  if (-not (Test-Path $candidate)) { throw "Missing trip-share reference: $ref" }
}
```

Expected: every local HTML reference exists.

- [ ] **Step 6: Smoke-test documented entry points and commit**

```powershell
Push-Location frontend
try {
  flutter analyze --no-fatal-infos
  flutter test test/app/admin_routes_test.dart test/widget_test.dart --reporter compact
} finally { Pop-Location }
& cf_service/.venv/Scripts/python.exe -c "import sys; sys.path.insert(0, 'cf_service'); from main import app; print(app.title)"

git add -- README.md .vscode/launch.json docs cf_service/README.md backend/supabase/functions/reviews/README.md
git add -u -- huongdan.md
git diff --cached --check
git commit -m "docs: document the final demo-safe workspace"
git status -sb
```

Expected: smoke tests pass, FastAPI title prints, focused commit, clean worktree.

---

### Task 8: Run Full Verification and Finalize the Report

**Files:**
- Modify: `docs/final-cleanup-report.md`
- Inspect: all retained runtime, test, operational, and evidence paths

**Interfaces:**
- Consumes: Tasks 1-7 and baseline thresholds.
- Produces: Verified, review-ready local `final` branch.

- [ ] **Step 1: Run full Flutter validation**

```powershell
Push-Location frontend
try {
  flutter pub get --enforce-lockfile
  flutter analyze --no-fatal-infos
  flutter test --reporter compact
  flutter build web --target lib/main.dart
  flutter build web --target lib/main_admin.dart
  flutter build apk --debug --target lib/main.dart
} finally { Pop-Location }
```

Expected: same two infos, 476 tests pass, user/admin Web and Android debug build.

- [ ] **Step 2: Run full Python validation**

```powershell
Push-Location cf_service
try {
  & .venv/Scripts/python.exe -m compileall -q .
  & .venv/Scripts/python.exe -m unittest discover -s . -p 'test_*.py' -v
} finally { Pop-Location }
& backend/crawldata/.demo-venv/Scripts/python.exe -m unittest discover -s backend/crawldata -p 'test_*.py' -v
& cf_service/.venv/Scripts/python.exe -m unittest discover -s evaluation/ai_quality/tests -p 'test_*.py' -v
Set-ExecutionPolicy -Scope Process Bypass
./scripts/data-freshness-demo.ps1 -Mode preflight
```

Expected: FastAPI 126, crawler 4, evaluation 31 pass; data-freshness dependencies and CLI report OK.

- [ ] **Step 3: Run configured Deno test directories**

```powershell
$root = Resolve-Path backend/supabase/functions
$dirs = Get-ChildItem $root -Recurse -File -Filter '*_test.ts' |
  ForEach-Object DirectoryName | Sort-Object -Unique |
  Where-Object { $_ -notlike '*\_shared' -and $_ -notlike '*\manage-uploaded-media' }
$failed = @()
foreach ($dir in $dirs) {
  Push-Location $dir
  try {
    deno test --quiet --no-lock --allow-env
    if ($LASTEXITCODE) { $failed += $dir }
  } finally { Pop-Location }
}
if ($failed.Count) { throw "Deno regressions: $($failed -join ', ')" }

$shared = Get-ChildItem backend/supabase/functions/_shared -File -Filter '*_test.ts' | Select-Object -ExpandProperty FullName
deno test --quiet --no-lock --no-check --allow-env --config backend/supabase/functions/subscription-payment/deno.json $shared
if ($LASTEXITCODE) { throw '_shared runtime tests regressed' }
```

Expected: all 15 baseline configured directories and 23 `_shared` tests pass.

- [ ] **Step 4: Confirm known manage-uploaded-media failure is identical**

```powershell
Push-Location backend/supabase/functions/manage-uploaded-media
try {
  $typeOutput = & deno test --quiet --no-lock --allow-env 2>&1
  $typeCode = $LASTEXITCODE
  $output = & deno test --quiet --no-lock --no-check --allow-env 2>&1
  $code = $LASTEXITCODE
} finally { Pop-Location }
$typeText = $typeOutput -join "`n"
if ($typeCode -eq 0) { throw 'Baseline type-check failure disappeared; review before documenting' }
if ($typeText -notmatch 'Found 2 errors' -or $typeText -notmatch 'BufferSource') {
  throw "Type-check failure changed`n$typeText"
}
$text = $output -join "`n"
if ($code -eq 0) { throw 'Baseline failure disappeared; review before documenting' }
if ($text -notmatch '10 passed \| 1 failed') { throw "Failure count changed`n$text" }
if ($text -notmatch 'retains the database relation when R2 cleanup fails so deletion can retry') {
  throw "Failure identity changed`n$text"
}
```

Expected: the same two `BufferSource` type errors and exactly the same single runtime failure.

- [ ] **Step 5: Verify Node dependencies, migrations, structure, static site, evidence, and hygiene**

```powershell
Push-Location backend
try {
  npm ci
  if ($LASTEXITCODE) { throw 'npm ci failed' }
  $auditText = (& npm audit --json 2>&1) -join "`n"
  $audit = $auditText | ConvertFrom-Json
} finally { Pop-Location }
$vulnerabilities = $audit.metadata.vulnerabilities
if ($vulnerabilities.low -gt 0 -or $vulnerabilities.high -gt 0 -or
    $vulnerabilities.moderate -gt 1 -or $vulnerabilities.critical -gt 1) {
  throw "npm audit regressed: $auditText"
}
git diff --exit-code check -- backend/package.json backend/package-lock.json backend/deno.lock
if ($LASTEXITCODE) { throw 'Backend dependency manifests changed' }

$migrations = @(Get-ChildItem backend/supabase/migrations -File -Filter '*.sql')
if ($migrations.Count -ne 72) { throw "Migration count: $($migrations.Count)" }
git diff --exit-code check -- backend/supabase/migrations
if ($LASTEXITCODE) { throw 'Migration content changed' }

$forbidden = @('.agents','.claude','.vscode/mcp.json','android','ios','frontend/ios','supabase','ui-patches','codex_backup.patch','backend/crawldata.zip','backend/db','report-assets','frontend/images')
$present = @($forbidden | Where-Object {
  if (Test-Path -LiteralPath $_ -PathType Leaf) { $true }
  elseif (Test-Path -LiteralPath $_ -PathType Container) {
    @(Get-ChildItem -LiteralPath $_ -File -Force -Recurse).Count -gt 0
  } else { $false }
})
if ($present.Count) { throw "Forbidden paths: $($present -join ', ')" }

[xml](Get-Content -Raw docs/architecture/system-architecture.svg) | Out-Null
$summary = Get-Content -Raw docs/evidence/ai-quality/assessment-summary.json | ConvertFrom-Json
foreach ($relative in $summary.source_runs.PSObject.Properties.Value) {
  if (-not (Test-Path (Join-Path docs/evidence/ai-quality $relative))) { throw "Broken evidence: $relative" }
}

$tripRoot = (Resolve-Path trip-share-web).Path
$html = Get-Content -Raw trip-share-web/index.html
$refs = [regex]::Matches($html, '(?:src|href)="([^"]+)"') |
  ForEach-Object { $_.Groups[1].Value } |
  Where-Object { $_ -notmatch '^(https?:|#|mailto:|tel:)' }
foreach ($ref in $refs) {
  $candidate = Join-Path $tripRoot ($ref.TrimStart('/').Split('?')[0])
  if (-not (Test-Path $candidate)) { throw "Missing trip-share reference: $ref" }
}
node --test trip-share-web/app.test.mjs
if ($LASTEXITCODE) { throw 'Trip-share tests failed' }

$sensitive = @(git ls-files | Where-Object {
  $_ -match '(^|/)(\.env|google-services\.json|GoogleService-Info\.plist|key\.properties)$' -or
  $_ -match '(^|/)\.temp/' -or $_ -match 'settings\.local\.json$'
} | Where-Object { $_ -ne 'cf_service/.env.example' })
if ($sensitive.Count) { throw "Sensitive tracked files: $($sensitive -join ', ')" }

$privateTokenHits = @(git grep -n -I -E `
  'AIza[0-9A-Za-z_-]{30,}|sk-[0-9A-Za-z_-]{20,}|sb_secret_[0-9A-Za-z_-]{20,}' -- .)
if ($privateTokenHits.Count) { throw "Possible private tokens:`n$($privateTokenHits -join "`n")" }

$jwtText = (git grep -h -I -E 'eyJhbGciOiJ[A-Za-z0-9_.-]{60,}' -- .) -join "`n"
$jwtTokens = [regex]::Matches($jwtText, 'eyJhbGciOiJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+') |
  ForEach-Object Value | Sort-Object -Unique
foreach ($token in $jwtTokens) {
  $payloadPart = $token.Split('.')[1].Replace('-', '+').Replace('_', '/')
  switch ($payloadPart.Length % 4) {
    2 { $payloadPart += '==' }
    3 { $payloadPart += '=' }
  }
  try {
    $payload = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payloadPart)) |
      ConvertFrom-Json
  } catch { throw 'Committed JWT could not be audited' }
  if ($payload.role -eq 'service_role') { throw 'Committed Supabase service-role JWT found' }
}

$personal = @(git grep -n -I -E 'C:\\Users\\(Asus|Novem)|/Users/haku/' -- . `
  ':(exclude)docs/superpowers/specs/2026-08-12-final-demo-safe-cleanup-design.md' `
  ':(exclude)docs/superpowers/plans/2026-08-12-final-demo-safe-cleanup.md')
if ($personal.Count) { throw "Personal paths:`n$($personal -join "`n")" }
git diff --check check...HEAD
```

Expected: locked Node install succeeds without increased advisories; 72 migrations and dependency manifests are unchanged; trip-share tests and references pass; no forbidden/sensitive paths remain; evidence and Git diff are valid.

- [ ] **Step 6: Append final results to cleanup report**

Append exactly:

```markdown

## Removed categories

- Personal coding-agent and MCP configuration
- Generated root platforms and unsupported Flutter iOS scaffolding
- Duplicate Supabase layout and project-link state
- Legacy SQL snapshots, patch archives, compressed crawler copy
- Historical crawler seeds not consumed by the active demo
- Generated FastAPI output and interactive probes
- Empty unreferenced Flutter placeholders and documentation-only images
- Historical plans, report assets, and intermediate AI runs

## Final verification

- Flutter analyzer: PASS with the same 2 baseline `info` diagnostics.
- Flutter tests: PASS, 476 tests.
- User Web build: PASS.
- Admin Web build: PASS.
- Android user debug build: PASS.
- FastAPI/CF tests: PASS, 126 tests.
- Data-freshness crawler tests: PASS, 4 tests.
- Data-freshness demo preflight: PASS.
- AI evaluation framework tests: PASS, 31 tests.
- Backend lockfile install: PASS; audit advisories did not increase.
- Deno configured directories: PASS for all 15 baseline directories.
- Deno `_shared`: PASS, 23 runtime tests.
- Deno `manage-uploaded-media`: unchanged baseline, 10 pass and the same 1 named failure.
- Canonical Supabase migrations: PASS, 72 unchanged files.
- Trip-share tests and local references: PASS.
- Evidence graph: PASS.
- Sensitive-file, personal-path, and Git whitespace checks: PASS.

## Known baseline debt

- Two Flutter analyzer information messages remain; no warnings or errors.
- `npm audit` remains at one moderate and one critical advisory because upgrades
  are outside cleanup scope.
- The documented Deno 2.9 `BufferSource` errors remain.
- The documented retry-status test remains the same single runtime failure.

## Recovery

Every removed path remains on branch `check`. Recover one path without history
rewrite, for example, using
`git restore --source check -- frontend/guide.md`.

No database, deployment, secret, or production-data mutation was performed.
```

- [ ] **Step 7: Commit report and audit final branch**

```powershell
git add -- docs/final-cleanup-report.md
git diff --cached --check
git commit -m "chore: verify final demo-safe repository"
git status -sb
git log --oneline --decorate check..final
git diff --stat check...final
git diff --check check...final
```

Expected: clean worktree, reviewable commits, no whitespace errors.

- [ ] **Step 8: Stop before publication**

Report the final commit, deletion summary, verification, baseline debt, and this exact optional command:

```powershell
git push -u origin final
```

Do not push until the owner explicitly asks to publish `final`.
