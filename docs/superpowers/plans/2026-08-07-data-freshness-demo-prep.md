# Data Freshness Demo Preparation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare a repeatable next-day demo for manual crawler ingestion, freshness checking, and admin review without exposing secrets or changing production content unexpectedly.

**Architecture:** Reuse the existing Python crawler for manual ingestion, the deployed `data-freshness-check` Edge Function for source verification, and the existing `/admin/data-freshness` Flutter web page for review. Add only reproducibility documentation and a demo dependency manifest; keep the checker secret server-side and leave remote migration/secret/cron actions to the account owner.

**Tech Stack:** Python 3.11+, `requests`, `beautifulsoup4`, `python-dotenv`, `supabase-py`, Supabase Edge Functions, Supabase SQL/pg_cron, Flutter web, PowerShell.

## Global Constraints

- Run database fixtures only against local or staging, never production.
- Never commit or print `SUPABASE_SERVICE_ROLE_KEY`, `DATA_FRESHNESS_CHECK_SECRET`, access tokens, or personal data.
- Do not add a client-side call that exposes the checker secret.
- Preserve unrelated working-tree changes and stage only files created for this demo preparation.
- The demo must remain honest: manual crawler ingestion and automated freshness verification are separate flows; admin approval is required for risky changes.

---

### Task 1: Record the demo dependency contract

**Files:**
- Create: `backend/crawldata/requirements-demo.txt`
- Test: `backend/crawldata/crawl_seed_data_fixed_v3.py`

**Interfaces:**
- Consumes: Python imports used by the crawler scripts.
- Produces: A reproducible dependency list that can be installed into a local virtual environment.

- [x] **Step 1: Add the five runtime dependencies**

  Include one package per line: `requests`, `beautifulsoup4`, `lxml`, `python-dotenv`, and `supabase`.

- [x] **Step 2: Install into an isolated demo environment**

  Run from `backend/crawldata`:

  ```powershell
  py -3.11 -m venv .demo-venv
  .\.demo-venv\Scripts\python.exe -m pip install --upgrade pip
  .\.demo-venv\Scripts\python.exe -m pip install -r requirements-demo.txt
  ```

- [x] **Step 3: Verify imports without contacting a source**

  ```powershell
  .\.demo-venv\Scripts\python.exe -c "import requests, bs4, lxml, dotenv, supabase; print('crawler dependencies: ok')"
  ```

- [x] **Step 4: Verify the crawler CLI loads**

  ```powershell
  .\.demo-venv\Scripts\python.exe crawl_seed_data_fixed_v3.py --help
  ```

  Expected: help text containing `--mode`, `--limit`, and `--upsert`, with exit code 0.

### Task 2: Create the repeatable demo runbook

**Files:**
- Create: `docs/data-freshness-demo-runbook.md`
- Read: `docs/data-freshness-manual-test.md`
- Read: `docs/data-freshness-operations.md`

**Interfaces:**
- Consumes: Existing crawler CLI, staging Supabase project, admin account, and deployed Edge Functions.
- Produces: A short, time-boxed sequence with a manual ingestion proof, checker run proof, admin approval proof, and explicit owner-only steps.

- [x] **Step 1: Document environment checks**

  Include commands for starting the admin app at port 3001, opening `/admin/data-freshness`, checking the two Edge Function URLs with `OPTIONS`, and verifying that the Python dependency environment is active.

- [x] **Step 2: Document manual ingestion**

  Use `crawl_seed_data_fixed_v3.py --mode local_products --limit 5 --upsert` as the primary small demo job. Require the operator to run it once before presenting and retain the terminal output as a fallback.

- [x] **Step 3: Document freshness verification**

  Provide the PowerShell POST with `triggerType=admin`, the required `x-data-freshness-secret` header, and the expected `runId`, `selectedCount`, `checkedCount`, `failedCount`, and `status` fields.

- [x] **Step 4: Document admin review**

  Show Overview, Dữ liệu stale, Lịch sử chạy, and Chờ duyệt. Explain that the page-level “Kiểm tra ngay” currently reloads the page and that per-row “Kiểm tra lại” marks a row due for a later checker run.

- [x] **Step 5: Document the fallback**

  Include a staging-only SQL fixture for one stale row and one pending `possibly_closed` proposal, plus the SQL query that verifies the resulting run and content status.

### Task 3: Validate the demo paths locally

**Files:**
- Test: `backend/crawldata/crawl_seed_data_fixed_v3.py`
- Test: `backend/supabase/functions/data-freshness-check/index.ts`
- Test: `frontend/lib/features/admin/presentation/pages/admin_data_freshness_page.dart`

**Interfaces:**
- Consumes: Installed demo environment and existing deployed function URLs.
- Produces: Evidence of which steps work automatically and a list of owner-only blockers.

- [x] **Step 1: Run crawler help and a no-upsert crawl**

  Run a small crawl without `--upsert` first and confirm JSON/CSV output is created under `backend/crawldata/output`. Use `--upsert` only after staging credentials are intentionally provided.

- [x] **Step 2: Probe deployed functions without secrets**

  Send `OPTIONS` requests to `data-freshness` and `data-freshness-check`; record HTTP 200 as deployment evidence without sending a secret.

- [x] **Step 3: Verify admin route registration**

  Confirm both admin routers resolve `/admin/data-freshness` to `AdminDataFreshnessPage` and the repository calls the authenticated `data-freshness` function.

- [ ] **Step 4: Verify remote schedule only with owner access**

  The owner runs:

  ```sql
  select jobname, schedule, active
  from cron.job
  where jobname = 'data-freshness-daily';
  ```

  The owner also confirms Vault and Edge Function secrets match. Without these checks, report the schedule as configured in code but not verified live.

### Task 4: Handoff owner-only actions

**Files:**
- Modify: `docs/data-freshness-demo-runbook.md`

**Interfaces:**
- Consumes: Results from Tasks 1–3.
- Produces: A compact wake-up checklist with commands that require the user's Supabase secrets, admin login, or staging database access.

- [x] **Step 1: List secret setup**

  Identify `DATA_FRESHNESS_CHECK_SECRET`, Vault `data_freshness_check_secret`, `SUPABASE_URL`, and `SUPABASE_SERVICE_ROLE_KEY` as owner-only values.

- [x] **Step 2: List staging fixture execution**

  Make clear that SQL fixtures must run in local/staging and must not run in production.

- [x] **Step 3: List presentation order**

  Keep the live walkthrough under seven minutes and include terminal-output/screenshots as a network fallback.

- [x] **Step 4: Commit only preparation artifacts**

  ```powershell
  git add backend/crawldata/requirements-demo.txt docs/data-freshness-demo-runbook.md docs/data-freshness-manual-test.md scripts/data-freshness-demo.ps1 docs/superpowers/plans/2026-08-07-data-freshness-demo-prep.md
  git diff --cached --check
  git commit -m "docs: prepare data freshness demo"
  ```

### Task 5: Add a repeatable local preflight helper

**Files:**
- Create: `scripts/data-freshness-demo.ps1`

**Interfaces:**
- Consumes: The isolated crawler environment, optional `SUPABASE_URL`, and the
  process-only `DATA_FRESHNESS_CHECK_SECRET` for an explicit checker trigger.
- Produces: Reachability/dependency checks, a temp-directory crawler dry run, or
  a sanitized checker summary without exposing secrets.

- [x] **Step 1: Verify crawler dependencies and CLI**

  `-Mode preflight` imports all dependencies and validates `--mode`/`--upsert`.

- [x] **Step 2: Probe deployed functions without credentials**

  When `-SupabaseUrl` or `SUPABASE_URL` is present, preflight sends `OPTIONS`
  requests to both functions.

- [x] **Step 3: Keep crawler output isolated**

  `-Mode crawler` writes to the Windows temp directory and warns when a source
  returns zero rows; it never overwrites tracked `backend/crawldata/output`.

- [x] **Step 4: Gate checker execution on the owner secret**

  `-Mode checker` requires the process environment secret, prints only the
  response summary, and exits with code `2` when the secret is absent.

## Verification checklist

- `requirements-demo.txt` contains all imports required by the selected crawler.
- The isolated Python environment imports all five dependencies.
- `crawl_seed_data_fixed_v3.py --help` exits 0.
- The no-upsert crawl produces output without modifying Supabase.
- `scripts/data-freshness-demo.ps1 -Mode preflight` exits 0 when the local
  environment is ready.
- The helper's crawler mode writes to a temp directory and preserves tracked
  output files.
- Both deployed freshness functions respond to `OPTIONS`.
- Admin route and repository references are present.
- No secret appears in tracked files, command output captured in docs, or screenshots.
- Remote cron and secret parity are explicitly marked owner-only until queried.
