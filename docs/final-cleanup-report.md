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
- Backend lockfile install: PASS with `npm ci --ignore-scripts`; full Supabase
  CLI postinstall could not download its GitHub checksum because the environment
  reset the connection. Audit advisories did not increase.
- Deno configured directories: PASS for all 15 baseline directories.
- Deno `_shared`: PASS, 23 runtime tests.
- Deno `manage-uploaded-media`: unchanged baseline, 10 pass and the same 1
  named failure.
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

## Verification environment note

- `npm ci` with lifecycle scripts was retried twice; both attempts reached the
  Supabase CLI postinstall and failed only while fetching the GitHub checksum
  (`ECONNRESET`). The lockfile installation itself passed with scripts disabled;
  no dependency manifest was changed.

## Recovery

Every removed path remains on branch `check`. Recover one path without history
rewrite, for example, using
`git restore --source check -- frontend/guide.md`.

No database, deployment, secret, or production-data mutation was performed.
