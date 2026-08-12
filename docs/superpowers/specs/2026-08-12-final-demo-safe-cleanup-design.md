# Final Demo-Safe Repository Cleanup Design

**Date:** 2026-08-12

**Target branch:** `final`

**Starting point:** `check` at `033bb8d`

## Objective

Produce a smaller, easier-to-explain `final` branch that still supports the
complete Hello Vietnam demo. The branch must run the Flutter user app on
Android and Web, the Flutter admin app on Web, the Supabase backend, the
FastAPI recommendation service, the public trip-share site, and the data
freshness demo workflow.

The cleanup removes generated files, machine-specific settings, obsolete
archives, duplicate backend layouts, historical implementation documents, and
code proven unreachable. It does not change product behavior, API contracts,
database schema, or production data.

## Confirmed Scope

The owner selected the following constraints:

- Use an evidence-driven, two-pass cleanup instead of rebuilding the repository
  from an allowlist.
- Support Android for the user app.
- Support Web for both user and admin apps.
- Do not retain iOS or desktop platform scaffolding on `final`.
- Keep a minimal defense/demo evidence set rather than all historical plans and
  generated reports.
- Keep core tests and operational runbooks even though they are not runtime
  dependencies, because they are required to demonstrate that the cleaned
  branch is safe.

## Runtime and Operational Boundaries

The cleaned repository retains these independently testable units:

1. **Flutter application (`frontend`)**
   - User entry point: `frontend/lib/main.dart`
   - Admin entry point: `frontend/lib/main_admin.dart`
   - Supported platforms: `frontend/android` and `frontend/web`
   - Runtime assets declared by `frontend/pubspec.yaml`
   - Flutter unit and widget tests

2. **Supabase backend (`backend/supabase`)**
   - Edge Functions and their per-function `deno.json` files
   - The canonical migration history
   - SQL and Deno tests
   - `backend/package.json`, `backend/package-lock.json`, and `backend/deno.lock`

3. **FastAPI recommendation and trip-planning service (`cf_service`)**
   - `main.py`, routers, services, ML code, database access, and scheduled jobs
   - Docker/runtime configuration and `.env.example`
   - Core unit and regression tests
   - Place-content maintenance tooling that is still used operationally

4. **Data freshness demo tooling**
   - `scripts/data-freshness-demo.ps1`
   - The active crawler `backend/crawldata/crawl_seed_data_fixed_v3.py`
   - Its direct dependency `source_identity.py`, locked demo requirements,
     regression test, and cached fallback outputs used by the runbook

5. **Public trip sharing (`trip-share-web`)**
   - Static site files, redirects, association examples, and deployment README

6. **Minimal operational and defense evidence**
   - Root README and current operational/manual-test documents
   - This cleanup design and its implementation plan
   - One current architecture diagram
   - The consolidated AI quality assessment and the raw records it explicitly
     cites, so the assessment remains reproducible

## Cleanup Method

### Pass 1: Deterministic artifact and configuration removal

Pass 1 removes only items whose role is already established without relying on
runtime reachability inference.

| Category | Remove from `final` | Reason |
|---|---|---|
| Agent and machine settings | `.agents/`, `.claude/`, `.vscode/mcp.json`, `skills-lock.json` | They configure individual coding-agent/editor sessions and are not app dependencies. `.vscode/launch.json` remains for the demo. |
| Generated root platform files | `android/`, `ios/` | The actual Flutter project is under `frontend/`; these root folders contain generated caches and machine paths. |
| Unsupported Flutter platform | `frontend/ios/` | The confirmed `final` target is Android plus Web. |
| Archives and patch history | `codex_backup.patch`, `ui-patches/`, `backend/crawldata.zip` | Their applied content is already in Git history and the current source tree. |
| Duplicate Supabase layout | `supabase/`, `backend/supabase/supabase/.temp/linked-project.json` | `backend/supabase` is the canonical CLI root. The root layout contains one empty migration and one migration already represented in the canonical history. `.temp` is generated project-link state. |
| Historical planning documents | All existing `docs/superpowers/plans/` and `docs/superpowers/specs/` documents except this cleanup design and its implementation plan | The full history remains on `check`; `final` keeps only current maintenance evidence. |
| Historical report material | Old root architecture images, `report-assets/`, `Report.docx.md`, `muc-tieu-cot-loi-cua-app.md`, and the survey generator | These do not participate in build or demo execution. One current architecture diagram is retained in a stable documentation path. |
| Obsolete Flutter guidance | Boilerplate `frontend/README.md`, `frontend/guide.md`, and `frontend/images/` | The root README becomes the single setup guide; these images are documentation-only and are not declared Flutter assets. |
| Generated Python results | Root-level `cf_service` CSV, JSON export, stdout, and stderr outputs produced by audit/evaluation scripts | The scripts and core tests remain; generated run output does not belong in the source branch. |
| Manual one-off probes | `cf_service/_test_query.py`, `cf_service/_test_trip.py`, and `cf_service/test_cb_cf_demo.py` | They are interactive/network probes rather than deterministic tests. `test_cb_cf_demo.py` currently breaks test discovery because `requests` is not a `cf_service` dependency. |
| Legacy SQL snapshots | `backend/db/` | The canonical reproducible database history is `backend/supabase/migrations`; no runtime or retained operational file consumes these snapshots. |
| Placeholder backend docs | `backend/location/` and `backend/personalization/` | They contain README-only placeholders and no executable component. Current behavior is documented with the owning Edge Functions. |

The root `.gitignore` is updated with root-anchored patterns for generated or
unsupported directories. Ignore rules must not hide `frontend/android` or
`frontend/web`.

### Pass 2: Dependency-proven dead code removal

Pass 2 does not delete files merely because their names look old. A code or
asset file is removed only when all applicable checks below succeed:

1. It is not reachable by Dart `import`, `export`, or `part` edges from
   `main.dart`, `main_admin.dart`, or retained tests.
2. It is not declared directly or through a directory asset declaration in
   `frontend/pubspec.yaml`.
3. It is not registered as a Flutter route or referenced by a route name.
4. It is not imported by `cf_service/main.py`, its routers, jobs, scripts, or
   retained tests.
5. It is not an Edge Function entry point, shared module, migration, Deno
   configuration, or retained Deno/SQL test.
6. It is not referenced by the data freshness PowerShell script or a retained
   runbook.
7. A repository-wide exact-name search returns no meaningful consumer.

The initially proven empty Flutter candidates are:

- `frontend/web_entrypoint.dart`
- `frontend/lib/core/network/api_client.dart`
- `frontend/lib/core/utils/logger.dart`
- `frontend/lib/features/messages/presentation/chat_thread_page.dart`
- `frontend/lib/features/planner/presentation/trip_create_page.dart`
- `frontend/lib/features/planner/presentation/trip_detail_page.dart`
- `frontend/lib/features/profile/presentation/settings_page.dart`
- `frontend/assets/images/dishes/banh_mi.jpg`

Each is zero bytes and has no runtime or test consumer on the starting commit.
They are still removed as an isolated batch and followed by Flutter analysis
and tests.

The crawler is reduced only after checking the active script's imports and file
reads. The retained data-freshness crawler is self-contained except for
`source_identity.py`; historical food and place seed scripts, mapping exports,
and notes can therefore be removed. Cached `output/activity.*`,
`output/culture.*`, and `output/local_products.*` remain because the demo
runbook uses them when upstream sites rate-limit requests.

## Minimal Evidence Layout

The cleaned branch uses stable, descriptive paths:

```text
docs/
  architecture/
    system-architecture.svg
  evidence/
    ai-quality/
      assessment-report.md
      assessment-summary.json
      source-runs/
        ai-search-pilot.jsonl
        ai-services-final.jsonl
        ai-search-quota.jsonl
  superpowers/
    specs/2026-08-12-final-demo-safe-cleanup-design.md
    plans/2026-08-12-final-demo-safe-cleanup.md
```

The assessment report and summary are copied without changing their claims.
Their relative source references are rewritten to the retained raw evidence
paths. Intermediate score tables, human-rating templates, smoke runs, and
duplicated generated reports are removed.

## README and Developer Experience

The root README becomes the single entry point and must document:

- the reduced repository layout;
- supported targets: Android user, Web user, and Web admin;
- VS Code launch profiles and equivalent Flutter commands;
- required external configuration files and environment variables without
  embedding secrets;
- FastAPI local/Docker startup;
- canonical Supabase working directory (`backend`);
- data freshness demo command;
- trip-share static deployment directory;
- validation commands used on `final`.

The committed `.vscode/launch.json` remains because it directly supports the
demo. `.vscode/mcp.json` is removed because it configures an optional personal
tool connection rather than the application.

## Baseline and Acceptance Criteria

The baseline was measured in the isolated `final` worktree before cleanup:

- Flutter: 476 tests pass.
- Flutter analyzer: two existing `info` diagnostics and no warning/error.
- FastAPI/CF service: 126 tests pass when the interactive
  `test_cb_cf_demo.py` probe is excluded.
- Crawler: 4 tests pass.
- AI evaluation framework: 31 tests pass.
- Deno: 15 of 17 per-function test directories type-check and pass on Deno
  2.9.4. `_shared` lacks its own import map but its 23 runtime tests pass when
  executed with the subscription-payment import map and `--no-check`.
  `manage-uploaded-media` has two existing Deno 2.9 `BufferSource` type
  incompatibilities; with type checking disabled, 10 of its 11 tests pass and
  the existing `retains the database relation when R2 cleanup fails so deletion
  can retry` test fails because the response status is `deleted` instead of
  `failed`.
- Node dependencies install from the lockfile; `npm audit` reports one moderate
  and one critical advisory on the starting commit.

Cleanup is accepted only if all of the following hold:

1. Flutter still reports all retained tests passing and introduces no analyzer
   warning/error. The two baseline `info` diagnostics may remain.
2. User Web and Admin Web build from their explicit entry points.
3. Android debug builds from `frontend/android`. Environment-specific Firebase
   configuration may be supplied locally for verification but is never
   committed.
4. All retained Python, crawler, and AI evaluation tests pass.
5. Every Deno test directory that passed at baseline still passes. `_shared`
   still passes 23 runtime tests with the explicit import map. The documented
   `manage-uploaded-media` type-check errors and its one named runtime-test
   failure may remain but cannot increase or change identity.
6. Supabase migration filenames remain ordered and unique, and no canonical
   migration is removed.
7. The trip-share static site has no missing local file reference.
8. A secret and machine-path scan finds no committed credentials, service-role
   keys, personal home paths, `.temp` link state, or agent permission files.
9. `git diff --check check...final` passes.
10. The final cleanup report lists every removed category, test result, known
    baseline issue, and recovery path.

## Error Handling and Rollback

Cleanup is committed in reviewable groups: generated/config files, platform
scope, backend consolidation, documentation/evidence, dead code, and final
README/verification. A failed verification stops the current group. The group
is corrected before proceeding; unrelated baseline failures are recorded rather
than silently fixed.

No force push, history rewrite, database mutation, secret update, or remote
deployment is part of this cleanup. Every deleted file remains available on
`check` and in Git history. Recovery is a normal `git restore --source check --
<path>` or a selective cherry-pick; destructive reset is unnecessary.

## Out of Scope

- Product feature changes or visual redesigns
- Database schema or production-data changes
- Dependency upgrades solely to clear advisories or Deno 2.9 diagnostics
- Supabase Function deployment, migration application, or secret changes
- FastAPI production deployment
- Rewriting the AI assessment to improve unfavorable metrics
- Removing core tests merely to reduce file count
