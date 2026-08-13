# Admin Data Freshness English and Cron Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the admin Data Freshness experience to English and schedule its daily checker for 02:15 Vietnam time.

**Architecture:** Keep the UI change within the current Flutter presentation components and preserve all repository/domain contracts. Add an additive Supabase migration that reschedules the existing pg_cron job through `cron.schedule`, then align the operational documentation.

**Tech Stack:** Flutter/Dart widget tests, PostgreSQL/pg_cron, Supabase CLI migrations, pgTAP, Markdown.

## Global Constraints

- Admin Data Freshness user-facing copy must be English-only.
- Database enum values and API payloads must not change.
- `daily_cf_retrain` remains at 02:00 Vietnam time.
- `data-freshness-daily` moves to `15 19 * * *` UTC, equivalent to 02:15 Vietnam time.
- The cron job must continue to invoke `select public.invoke_data_freshness_cron()`.
- Do not directly update `cron.job`; use supported pg_cron functions.

---

### Task 1: English Admin Data Freshness UI

**Files:**
- Modify: `frontend/test/features/admin/presentation/admin_data_freshness_page_test.dart`
- Modify: `frontend/lib/features/admin/presentation/pages/admin_data_freshness_page.dart`
- Modify: `frontend/lib/features/admin/presentation/widgets/admin_data_freshness_widgets.dart`
- Modify: `frontend/lib/features/admin/presentation/widgets/freshness_report_detail_dialog.dart`

**Interfaces:**
- Consumes: Existing `AdminFreshness*` domain models and repository methods.
- Produces: The same widget/API interfaces with English presentation copy.

- [ ] **Step 1: Write failing widget expectations**

Assert `Pending review`, `Reports`, `Stale data`, `Run history`, `Refresh data`, overview labels, proposal actions, and English report-dialog labels. Assert representative Vietnamese strings are absent.

- [ ] **Step 2: Run the focused test and observe failure**

Run: `flutter test test/features/admin/presentation/admin_data_freshness_page_test.dart`

Expected: FAIL because the current widgets still render Vietnamese labels.

- [ ] **Step 3: Replace all Vietnamese presentation copy**

Use concise labels: `Pending review`, `Reports`, `Stale data`, `Run history`, `Refresh data`, `Auto-expired today`, `Failed runs`, `Approve`, `Keep active`, `Check again`, `View details`, `Report details`, `Edit item`, `Mark resolved`, `Close`, and `Retry`.

- [ ] **Step 4: Format and rerun the focused test**

Run: `dart format lib/features/admin/presentation/pages/admin_data_freshness_page.dart lib/features/admin/presentation/widgets/admin_data_freshness_widgets.dart lib/features/admin/presentation/widgets/freshness_report_detail_dialog.dart test/features/admin/presentation/admin_data_freshness_page_test.dart`

Run: `flutter test test/features/admin/presentation/admin_data_freshness_page_test.dart`

Expected: PASS.

### Task 2: Additive Cron Migration

**Files:**
- Create: Supabase CLI-generated migration `align_data_freshness_cron.sql` under `backend/supabase/migrations/` (the CLI assigns its timestamp prefix)
- Modify: `backend/supabase/tests/data_freshness_test.sql`

**Interfaces:**
- Consumes: `public.invoke_data_freshness_cron()` and the existing `data-freshness-daily` job name.
- Produces: pg_cron schedule `15 19 * * *` with the existing command.

- [ ] **Step 1: Add pgTAP expectations for the desired cron state**

Increase the plan count and assert `cron.job.schedule = '15 19 * * *'` and the command contains `invoke_data_freshness_cron()` for `jobname = 'data-freshness-daily'`.

- [ ] **Step 2: Verify the expectations differ from the existing migration state**

Run a repository search for the current schedule and confirm the original migration still specifies `15 2 * * *`.

Expected: The desired test expectation and current migration state differ.

- [ ] **Step 3: Generate and implement the migration**

Run: `npx --yes supabase@2.110.0 migration new align_data_freshness_cron --workdir backend`

The migration must call:

```sql
select cron.schedule(
  'data-freshness-daily',
  '15 19 * * *',
  $cron$select public.invoke_data_freshness_cron()$cron$
);
```

Wrap missing pg_cron support with the same warning behavior used by the original migration.

- [ ] **Step 4: Verify migration ordering and SQL content**

Run: `npx --yes supabase@2.110.0 migration list --local --workdir backend`

Run static assertions that the new migration contains the job name, new schedule, and unchanged command.

### Task 3: Documentation and Final Verification

**Files:**
- Modify: `docs/data-freshness-operations.md`
- Modify: `docs/data-freshness-demo-runbook.md`
- Modify: `docs/architecture-ai-data-freshness-defense-guide.md`

**Interfaces:**
- Consumes: The verified migration schedule.
- Produces: Consistent operator and defense guidance stating 02:15 Vietnam / 19:15 UTC.

- [ ] **Step 1: Replace every obsolete schedule reference**

Change `15 2 * * *`, `02:15 UTC`, and `09:15 Vietnam` references for this job to `15 19 * * *`, `19:15 UTC`, and `02:15 Vietnam` respectively.

- [ ] **Step 2: Run documentation and copy consistency scans**

Search the repository for the obsolete schedule and scan the three Data Freshness admin presentation files for Vietnamese characters/phrases.

- [ ] **Step 3: Run focused and neighboring verification**

Run the Data Freshness widget test, Flutter analyzer for the changed files, SQL whitespace checks, and `git diff --check`.

- [ ] **Step 4: Review the final diff**

Confirm no user-owned unrelated untracked files were staged or modified beyond the explicitly requested defense-guide schedule correction.
