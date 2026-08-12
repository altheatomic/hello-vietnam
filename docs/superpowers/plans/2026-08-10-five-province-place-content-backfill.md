# Five-Province Place Content Backfill Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` to execute this plan task-by-task. Before editing, use `superpowers:using-git-worktrees` and work in a clean isolated worktree. Do not use subagents unless the active session explicitly permits them. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Normalize Vietnamese and English place names and short descriptions, add grounded bilingual long descriptions, and safely backfill exactly 1,533 places in Hồ Chí Minh, Huế, Hà Nội, Quảng Ninh, and Lâm Đồng.

**Architecture:** A resumable Python pipeline snapshots the fixed Supabase scope, collects identity-safe OSM/Wikimedia evidence, locks names with deterministic rules, asks DeepSeek only for bilingual copy, validates proposals, and persists immutable local artifacts. A lightweight supervisor runs bounded chunks in fresh child processes; each child flushes checkpoints, closes resources, and exits so macOS reclaims its entire address space before the next chunk. Database writes use guarded `asyncpg` batches with pre-apply and post-apply hashes. Code construction and mocked/local verification run unattended first; migration reconciliation, paid generation, human content review, deployment, apply, rollback, and rollout are explicit later gates.

**Tech Stack:** PostgreSQL 17/Supabase, Supabase CLI and pgTAP, Python 3.11, Pydantic 2.7, `httpx`, `asyncpg`, `supabase-py`, DeepSeek Chat Completions JSON Output, Flutter/Dart.

## Execution boundary

### Phase A — safe unattended work

Tasks 0–10 may run while the owner is away.

- The execution host is macOS with 16 GiB RAM. Run Python tests, Flutter tests/analyzer, and any Supabase tooling serially, never concurrently.
- Do not start Docker or a local Supabase stack during unattended Phase A. Run local pgTAP only when an already-running local stack is available; otherwise defer it.
- Supabase access is read-only: metadata, schema inspection, migration listing, counts, and advisors only.
- Do not run `supabase db pull`, `supabase db push`, `apply_migration`, remote DDL/DML, or any SQL that changes state.
- Do not call the real DeepSeek API. Provider tests must use `httpx.MockTransport`.
- Do not run pipeline `apply` or `rollback`, even against production-shaped credentials.
- Do not deploy the migration, service, app, or Edge Functions.
- Do not modify or commit changes that existed before the isolated worktree was created.
- If local Supabase replay is unavailable because the historical `place_translation` migration is absent, defer only the pgTAP execution; continue all code and mocked tests.

Task 11 is the unattended handoff report. After Task 11, stop. Tasks 12–14 require the owner to return and explicitly approve continuation.

### Verified production facts as of 2026-08-10

- PostgreSQL version is 17.6.
- The five-province scope contains exactly 1,533 places.
- All 1,533 places have one `vi` and one `en` translation.
- All 1,533 places have an OSM source ID shaped `osm:<node|way|relation>:<integer>`.
- All 1,533 `place.detailed_description` values are blank.
- The two inactive scoped rows are both in Lâm Đồng.
- `public.place_localized_en` does not currently use `security_invoker`.
- Remote migration history and repository migration files are not fully reconciled. The migration that created `place_translation` is absent locally.

## Global constraints

- Exact province UUIDs and counts:
  - Hồ Chí Minh: `094014a7-b8f6-481a-bbce-5ed6cdd457c5` — 539.
  - Huế: `b5f3ef5e-dc49-4482-88e3-a8048cb32639` — 201.
  - Hà Nội: `3355c4a1-ccb1-46be-99e5-046d5f55b891` — 235.
  - Quảng Ninh: `8f9d18e3-7e24-4e36-bf50-a3823c1f78df` — 200.
  - Lâm Đồng: `49fa7ad8-b892-494d-a712-bb49802200c1` — 358.
- Process all 1,533 scoped rows, including the two inactive Lâm Đồng rows; never change status.
- Add only `public.place_translation.detailed_description`; `place_translation.description` remains short-form.
- `place` is the Vietnamese source of truth; the `vi` translation mirrors its name, short description, and detailed description.
- Preserve Vietnamese proper-name tokens and diacritics in English display names. Translate only approved generic types: `Sông Hương` becomes `Hương River`, never `Perfume River`.
- DeepSeek never selects names and never writes to Supabase.
- Short copy is 20–45 whitespace-delimited Unicode words. Long copy is 90–160 words.
- Do not invent dates, history, prices, ratings, distances, schedules, awards, amenities, superlatives, or experiential claims not grounded in evidence.
- Sparse-source proposals and any naming confidence below `0.85` are review-only.
- Deterministic validation passing is necessary but not sufficient for sparse-source content.
- No generated proposal may apply until it has an explicit human `approve` decision or a human `edit` decision whose edited fields pass validation. This is the safe default for all 1,533 rows.
- Apply at most 50 places per transaction and require an unchanged baseline hash.
- Pipeline peak resident memory target is below 1.5 GiB on the 16 GiB Mac. Mainline code must stream JSONL, CSV, HTTP bodies, and database pages; it must not materialize all proposals, source bodies, or pairwise duplicate comparisons at once.
- Default limits are database page 500, related-ID batch 200, OSM batch 100, apply batch 50, HTTP concurrency 3, official-site body 1 MiB, Wikimedia response 2 MiB, and Overpass response 8 MiB. Exceeding a response cap produces a review warning instead of buffering more data.
- Long-running `collect`, `generate`, and `validate` commands use a supervisor/worker model with fresh processes. Defaults are 50 places per collect worker, 25 per generate worker, and 100 per validate worker. A worker must exit after one chunk; do not use a persistent `multiprocessing.Pool`.
- The supervisor may retain only run metadata, completed-ID indexes, and the next bounded ID chunk. It must not receive full records through stdout, a multiprocessing queue, or an in-memory result list. Workers communicate results through fsynced artifacts plus a small exit-status JSON file.
- Within a worker, async queues have `maxsize <= concurrency * 2`. After every record, drop record-local references; after every chunk, close HTTP clients, database connections, SQLite cursors/connections, temporary files, and executors in `finally` blocks. `gc.collect()` may run after cleanup for cyclic garbage, but correctness must rely on process exit rather than garbage collection.
- Never store or expose `DEEPSEEK_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `DATABASE_URL`, request authorization headers, or database passwords.
- Do not remediate unrelated image, rating, price, tag, RLS, migration, or Trip Planner issues.
- “Pilot must pass rollback” means non-pilot production rows cannot apply until the reviewed 100-row pilot has been applied, verified, rolled back, verified restored, and reapplied.

## File structure

**Database**

- Create: `backend/supabase/migrations/<cli-timestamp>_add_place_translation_detailed_description.sql`
- Create: `backend/supabase/tests/place_content_backfill_schema_test.sql`

**Pipeline**

- Create package: `cf_service/scripts/place_content_backfill/`
- Modules: `constants.py`, `models.py`, `artifacts.py`, `repository.py`, `naming.py`, `generator.py`, `validators.py`, `cli.py`
- Sources: `sources/osm.py`, `sources/wikimedia.py`, `sources/website.py`
- Prompt: `prompts/place_content_v1.md`

**Tests**

- Create: `cf_service/test_place_content_models.py`
- Create: `cf_service/test_place_content_artifacts.py`
- Create: `cf_service/test_place_content_repository.py`
- Create: `cf_service/test_place_content_sources.py`
- Create: `cf_service/test_place_content_naming.py`
- Create: `cf_service/test_place_content_generator.py`
- Create: `cf_service/test_place_content_validators.py`
- Create: `cf_service/test_place_content_apply.py`
- Create: `cf_service/test_place_content_memory.py`
- Create: `cf_service/test_recommend_place_detail.py`

**Recommend and operations**

- Modify: `cf_service/routes/recommend.py`
- Modify: `frontend/lib/features/recommend/data/recommend_repository.dart`
- Modify: `frontend/lib/features/recommend/presentation/recommended_place_detail_page.dart`
- Modify: `frontend/test/features/recommend/data/recommend_repository_test.dart`
- Create: `frontend/test/features/recommend/presentation/recommended_place_detail_page_test.dart`
- Modify: `.gitignore`
- Modify: `cf_service/.env.example`
- Create: `docs/place-content-backfill-runbook.md`

---

## Phase A — implementation and local/mocked verification

### Task 0: Isolate the work and record a read-only preflight

**Files:**
- Create: `docs/place-content-backfill-preflight.md`

**Interfaces:**
- Consumes: repository state and read-only Supabase metadata.
- Produces: a sanitized record of branch, CLI version, authoritative Supabase directory, schema facts, and known migration drift.

- [ ] **Step 1: Create or enter a clean worktree**

Use `superpowers:using-git-worktrees`. The new worktree must start from committed `HEAD`; do not carry the staged `.gitignore` or `.vscode/launch.json` changes from the owner’s current checkout.

- [ ] **Step 2: Verify tools without changing state**

Run from repository root:

```bash
git status --short --branch
npx --yes supabase --version
npx --yes supabase migration list --help
npx --yes supabase test db --help
python3 --version
flutter --version
```

Expected: clean worktree; Supabase CLI, Python 3.11+, and Flutter are available. Record actual versions.

- [ ] **Step 3: Identify the authoritative Supabase tree**

Treat `backend/supabase/` as authoritative because it contains the active migrations, functions, and pgTAP tests. Treat the root `supabase/` directory as legacy and do not edit it in this feature.

- [ ] **Step 4: Record migration drift without repairing it**

List local filenames and remote migration history using CLI or the Supabase plugin’s read-only migration tool. Record mismatches in `docs/place-content-backfill-preflight.md`. Do not run `db pull`, migration repair, or remote writes.

- [ ] **Step 5: Commit the sanitized preflight**

```bash
git add docs/place-content-backfill-preflight.md
git commit -m "docs: record place backfill preflight"
```

### Task 1: Add the translation detail schema contract

**Files:**
- Create: `backend/supabase/tests/place_content_backfill_schema_test.sql`
- Create: `backend/supabase/migrations/<cli-timestamp>_add_place_translation_detailed_description.sql`

**Interfaces:**
- Consumes: existing remote definitions of `place`, `place_translation`, and `place_localized_en` recorded in Task 0.
- Produces: nullable `place_translation.detailed_description` and a security-invoker English view with a final `detailed_description` column.

- [ ] **Step 1: Write the pgTAP contract**

The test must assert: translation detail column exists, type is `text`, it is nullable, the view exposes the field, the view has `security_invoker=true`, and the view retains one row per place.

- [ ] **Step 2: Create the migration path with the CLI**

Run from repository root:

```bash
npx --yes supabase migration new add_place_translation_detailed_description --workdir backend
```

Use the emitted path. Never invent or alter the timestamp.

- [ ] **Step 3: Implement the incremental migration**

The migration must:

```sql
alter table public.place_translation
  add column if not exists detailed_description text;

comment on column public.place_translation.detailed_description is
  'Localized long-form place description; description remains short-form.';
```

Recreate `public.place_localized_en` with its existing columns in their existing order, `security_invoker = true`, and append the new column at the end:

```sql
create or replace view public.place_localized_en
with (security_invoker = true)
as
select
  p.id_place,
  p.id_place_subcategory,
  p.status,
  p.old_province,
  p.latitude,
  p.longitude,
  p.estimated_duration_minutes,
  p.gallery,
  p.average_rating,
  p.review_count,
  p.cover_image,
  p.minimum_price,
  p.maximum_price,
  p.price_level,
  p.phone,
  p.website,
  p.timespan,
  p.timeclose,
  coalesce(pt.name, p.name) as name,
  coalesce(pt.description, p.short_description) as short_description,
  coalesce(pt.address, p.address) as address,
  p.id_province,
  coalesce(
    pt.detailed_description,
    p.detailed_description,
    pt.description,
    p.short_description
  ) as detailed_description
from public.place p
left join public.place_translation pt
  on pt.place_id = p.id_place and pt.lang_code = 'en';
```

- [ ] **Step 4: Perform unattended-safe checks**

```bash
git diff --check -- backend/supabase/migrations backend/supabase/tests/place_content_backfill_schema_test.sql
```

If local replay works without migration repair, run the pgTAP test locally. Otherwise record it as deferred in the handoff; do not pull or repair history.

- [ ] **Step 5: Commit**

```bash
git add backend/supabase/migrations backend/supabase/tests/place_content_backfill_schema_test.sql
git commit -m "feat: add localized place detail descriptions"
```

### Task 2: Define strict models, artifacts, and the complete CLI surface

**Files:**
- Create: `cf_service/scripts/place_content_backfill/{__init__,constants,models,artifacts,cli}.py`
- Create: `cf_service/test_place_content_models.py`
- Create: `cf_service/test_place_content_artifacts.py`

**Interfaces:**
- Produces: `APPROVED_PROVINCES`, `BaselineRecord`, `SourceFact`, `SourceSnapshot`, `NameDecision`, `GeneratedContent`, `Proposal`, `ValidationResult`, `RunManifest`, `ArtifactStore`, and `build_parser()`.

- [ ] **Step 1: Write failing model and scope tests**

Assert the exact UUID/count map, `EXPECTED_TOTAL == 1533`, immutable Pydantic models with `extra='forbid'`, confidence in `[0,1]`, and manifest rejection of any outside-scope UUID.

- [ ] **Step 2: Write failing artifact tests**

Test UTF-8 JSONL append/iteration/resume, atomic manifest replacement with `os.replace`, file flush plus `os.fsync`, completed-place detection, streaming review CSV round-trip, and recursive secret-shaped key/value rejection.

- [ ] **Step 3: Define the full CLI contract**

Commands:

```text
audit
collect
generate
validate
review-import --run-id RUN --file PATH
apply
rollback
status
```

Shared selectors are `--run-id`, `--pilot`, `--place-id`, `--batch-id`, `--province-id`, and `--all` where appropriate. `apply` and `rollback` require `--confirm`; missing confirmation exits code 2 before opening a DB connection.

Add `--worker-chunk-size` to `collect`, `generate`, and `validate`, with safe defaults 50, 25, and 100. The public command is the supervisor. Private worker entry points accept exactly one explicit list of scoped place IDs, process one chunk, write checkpoints, emit a small status file, and exit. Resume skips IDs already present with the exact input hash.

- [ ] **Step 4: Implement artifact streams**

Use `.artifacts/place-content/<run-id>/` with `manifest.json`, `baseline.jsonl`, `sources.jsonl`, `proposals.jsonl`, `approved.jsonl`, `needs-review.csv`, `review-decisions.jsonl`, `applied.jsonl`, and `rollback.jsonl`.

`ArtifactStore.iter_stream(stream)` must yield one decoded record at a time. `read_all()` may exist only as a test convenience and must not be called by `collect`, `generate`, `validate`, `review-import`, `apply`, `rollback`, or `status`. CSV import/export must use iterators rather than building a list of every proposal.

Add a `ChunkSupervisor` that launches workers with `subprocess.run()` serially, never `Popen` without an immediate wait and never `multiprocessing.Pool`. Do not capture worker stdout/stderr into unbounded memory; stream sanitized logs to the terminal and store only the bounded status JSON. On nonzero exit, stop with all prior fsynced checkpoints resumable.

- [ ] **Step 5: Run tests and commit**

```bash
(cd cf_service && python3 -m unittest test_place_content_models.py test_place_content_artifacts.py -v)
git add cf_service/scripts/place_content_backfill cf_service/test_place_content_models.py cf_service/test_place_content_artifacts.py
git commit -m "feat: scaffold safe place content pipeline"
```

### Task 3: Extract and hash the exact baseline

**Files:**
- Create: `cf_service/scripts/place_content_backfill/repository.py`
- Create: `cf_service/test_place_content_repository.py`
- Modify: `cf_service/scripts/place_content_backfill/cli.py`

**Interfaces:**
- Produces: `fetch_baseline()`, `verify_baseline_counts()`, `editable_hash()`, and the `audit` command.

- [ ] **Step 1: Write failing fake-client tests**

Prove pagination reads all pages; every query has an allowlisted province/content-ID filter; missing or duplicate `vi`/`en` rows fail; 1,532 rows fail; and editable changes alter the canonical hash.

- [ ] **Step 2: Implement filtered paginated reads**

Read places in pages of 500 and related translations, `content_freshness`, subcategory, and tags in ID batches of at most 200. Select only fields required by the baseline, identity, naming, evidence, and hashes; do not fetch gallery or image payloads. Write each completed baseline record to JSONL before requesting the next page. Require one place, one `vi`, and one `en` record per baseline.

- [ ] **Step 3: Separate hash purposes**

Implement:

```python
editable_hash(record)       # content plus concurrency timestamps before apply
applied_content_hash(record) # nine editable content values only after apply
```

Do not normalize stored text before hashing. The apply result must later store `UPDATE ... RETURNING` timestamps separately from `applied_content_hash`.

- [ ] **Step 4: Implement read-only audit**

`audit --scope approved-five` requires exact province counts, zero outside-scope rows, and run IDs shaped `YYYYMMDD-HHMMSS-<8 hex chars>`.

- [ ] **Step 5: Run tests and commit**

```bash
(cd cf_service && python3 -m unittest test_place_content_repository.py test_place_content_models.py test_place_content_artifacts.py -v)
git add cf_service/scripts/place_content_backfill cf_service/test_place_content_repository.py
git commit -m "feat: audit scoped place content baseline"
```

### Task 4: Collect identity-safe source facts

**Files:**
- Create: `cf_service/scripts/place_content_backfill/sources/{__init__,osm,wikimedia,website}.py`
- Create: `cf_service/test_place_content_sources.py`
- Modify: `cf_service/scripts/place_content_backfill/cli.py`

**Interfaces:**
- Produces: `collect_source_snapshot(record) -> SourceSnapshot` and resumable `sources.jsonl`.

- [ ] **Step 1: Write OSM identity and batching tests**

Accept only `osm:node:<int>`, `osm:way:<int>`, and `osm:relation:<int>`. Batch by kind with at most 100 IDs. Tests use `httpx.MockTransport` only.

- [ ] **Step 2: Write Wikimedia corroboration tests**

Accept explicit `Q[0-9]+` and `<language-code>:<page-title>` links. Reject name-only matching and any province/type/coordinate conflict.

- [ ] **Step 3: Write official-site SSRF tests**

Reject non-HTTP(S), localhost, private/link-local/loopback destinations, public-to-private redirects, non-HTML bodies, and bodies above 1 MiB. Official-site collection remains default-off.

- [ ] **Step 4: Implement bounded collection**

Use an identifying User-Agent, timeouts, three attempts, exponential backoff, `Retry-After`, concurrency 3, stable fact IDs, source URLs, and cache keys containing request parameters plus baseline input hash. Use `httpx.AsyncClient.stream()` and count received bytes before decoding. Cap official-site bodies at 1 MiB, Wikimedia responses at 2 MiB, and Overpass responses at 8 MiB.

Each collect worker handles at most 50 places, uses a bounded async queue of at most 6 items, writes each completed `SourceSnapshot` immediately, and closes the `AsyncClient` before exiting. It must not return collected snapshots to the supervisor.

- [ ] **Step 5: Treat sparse sources explicitly**

A missing or minimal source is a valid snapshot with `sparse_source=true` and warnings. It must never become auto-approved later.

- [ ] **Step 6: Run tests and commit**

```bash
(cd cf_service && python3 -m unittest test_place_content_sources.py test_place_content_repository.py -v)
git add cf_service/scripts/place_content_backfill cf_service/test_place_content_sources.py
git commit -m "feat: collect grounded place content sources"
```

### Task 5: Normalize names deterministically

**Files:**
- Create: `cf_service/scripts/place_content_backfill/naming.py`
- Create: `cf_service/test_place_content_naming.py`

**Interfaces:**
- Produces: `normalize_names(record, sources) -> NameDecision`.

- [ ] **Step 1: Write approved regression tests**

Include:

```python
CASES = [
    ("Sông Hương", "Hương River"),
    ("Chùa Thiên Mụ", "Thiên Mụ Pagoda"),
    ("Chợ Bến Thành", "Bến Thành Market"),
    ("Núi Bà Đen", "Bà Đen Mountain"),
    ("Bánh Mì Phượng", "Bánh Mì Phượng"),
    ("Nhà Thờ Họ Đạo Cái Cấm", "Cái Cấm Parish Church"),
]
```

- [ ] **Step 2: Define an exact longest-first mapping table**

At minimum cover `Nhà Thờ Giáo Xứ`, `Nhà Thờ Họ Đạo`, `Nhà Thờ`, `Bảo Tàng`, `Sân Bay`, `Nhà Ga`, `Bến Xe`, `Vịnh`, `Đảo`, `Hang`, `Thác`, `Chùa`, `Đền`, `Chợ`, `Cầu`, `Sông`, `Hồ`, `Núi`, `Bãi`, and `Công Viên`. Match case-insensitively but slice the original Unicode text so proper-name spelling is unchanged.

- [ ] **Step 3: Implement contextual and review-only behavior**

Generic-looking restaurant/brand names remain brands unless the subcategory and corroborated source type prove a geographic feature. Any uncovered generic prefix, protected-token loss, ambiguous official override, or confidence below `0.85` is review-only.

- [ ] **Step 4: Run tests and commit**

```bash
(cd cf_service && python3 -m unittest test_place_content_naming.py -v)
git add cf_service/scripts/place_content_backfill/naming.py cf_service/test_place_content_naming.py
git commit -m "feat: normalize place names without literal translation"
```

### Task 6: Generate grounded bilingual copy through a mocked DeepSeek client

**Files:**
- Create: `cf_service/scripts/place_content_backfill/generator.py`
- Create: `cf_service/scripts/place_content_backfill/prompts/place_content_v1.md`
- Create: `cf_service/test_place_content_generator.py`
- Modify: `cf_service/.env.example`

**Interfaces:**
- Produces: strict `GeneratedContent`, provider usage metadata, budget state, and `proposals.jsonl`.

- [ ] **Step 1: Write prompt and provider tests**

Assert locked names, fact IDs, explicit JSON output, exact word limits, unsupported-claim rules, sparse-source warnings, prompt-injection isolation, malformed/empty/truncated output handling, 429 retry handling, three-attempt exhaustion, and exact-hash cache hits.

- [ ] **Step 2: Write budget tests**

Refuse before exceeding request, input-token, output-token, or estimated-cost caps. Cost limiting requires owner-supplied input/output prices; never hardcode current provider pricing.

- [ ] **Step 3: Implement the client without making a real request**

Configure `https://api.deepseek.com/chat/completions`, temperature `0.2`, `max_tokens=1400`, and `response_format={"type":"json_object"}`. Require explicit API key and model at runtime. Phase A tests inject `httpx.MockTransport` and must prove zero real network requests.

Each generate worker handles at most 25 places. Build and discard one rendered prompt and parsed response at a time, append the proposal and usage checkpoint immediately, and close the client before process exit. Never accumulate prompts or model responses for the entire chunk.

- [ ] **Step 4: Update environment documentation**

Add placeholder-only `DEEPSEEK_API_KEY`, `DEEPSEEK_CONTENT_MODEL`, `DEEPSEEK_INPUT_COST_PER_MILLION_USD`, and `DEEPSEEK_OUTPUT_COST_PER_MILLION_USD` entries.

- [ ] **Step 5: Run tests and commit**

```bash
(cd cf_service && python3 -m unittest test_place_content_generator.py test_place_content_models.py -v)
git add cf_service/scripts/place_content_backfill cf_service/test_place_content_generator.py cf_service/.env.example
git commit -m "feat: generate grounded bilingual place content"
```

### Task 7: Validate proposals and round-trip human review

**Files:**
- Create: `cf_service/scripts/place_content_backfill/validators.py`
- Create: `cf_service/test_place_content_validators.py`
- Modify: `cf_service/scripts/place_content_backfill/{artifacts,cli}.py`

**Interfaces:**
- Produces: `validate_proposal()`, `find_near_duplicates()`, `approved.jsonl`, `needs-review.csv`, and working `review-import`.

- [ ] **Step 1: Write deterministic validator tests**

Reject empty/out-of-range copy, placeholders, protected-name loss, changed digits/acronyms/brands, forbidden literal translations, Markdown/HTML, instruction fragments, unreferenced numeric claims, province/category/name disagreement, and near-duplicates above character 5-gram similarity `0.92`.

- [ ] **Step 2: Enforce review-only conditions**

Regardless of other validation results, no generated proposal enters `approved.jsonl` without an explicit human approval record. Highlight `sparse_source`, naming confidence below `0.85`, identity warnings, unknown generic prefixes, and apparently ungrounded non-numeric factual claims prominently in the review CSV; these rows require individual inspection.

- [ ] **Step 3: Implement CSV export/import**

CSV fields include IDs, current/proposed names, four descriptions, flags, source URLs, `reviewer_decision`, and `reviewer_notes`. Accept only `approve`, `edit`, or `reject`. Edited fields must pass all deterministic validators again. Store imported decisions in append-only `review-decisions.jsonl`. Import and export one row at a time.

- [ ] **Step 4: Make validation reproducible**

`validate` rebuilds derived approved/review files from immutable proposals plus append-only decisions. `status` prints counts and budget only. Near-duplicate detection must process normalized 5-gram signatures in bounded chunks of 200 and spill compact signatures to a temporary SQLite database under the run artifact directory; do not construct a 1,533 × 1,533 in-memory matrix.

Each validate worker handles at most 100 proposals and writes validation rows immediately. The supervisor performs only the final streaming merge of validation decisions and SQLite-backed duplicate flags; it must not load all proposals or approvals.

- [ ] **Step 5: Run tests and commit**

```bash
(cd cf_service && python3 -m unittest test_place_content_validators.py test_place_content_artifacts.py -v)
git add cf_service/scripts/place_content_backfill cf_service/test_place_content_validators.py
git commit -m "feat: validate and review generated place content"
```

### Task 8: Implement guarded apply and rollback without connecting to production

**Files:**
- Modify: `cf_service/scripts/place_content_backfill/{repository,cli}.py`
- Create: `cf_service/test_place_content_apply.py`

**Interfaces:**
- Produces: `apply_approved_batch()`, constrained rollback, recovery artifacts, and fake-transaction coverage.

- [ ] **Step 1: Write CLI safety tests**

Missing confirmation, batch size 51, outside-scope province, unresolved review, rejected proposal, and unknown selector must exit before connection creation.

- [ ] **Step 2: Write fake asyncpg transaction tests**

Cover success, baseline conflict, missing/duplicate translation, zero-row update, mid-batch exception, post-commit artifact recovery, and rollback refusal after later admin edits.

- [ ] **Step 3: Implement apply concurrency checks**

Lock one place plus exactly one `vi` and `en` translation; compare `editable_hash`; update nine values with parameterized SQL; collect `UPDATE ... RETURNING` timestamps; calculate `applied_content_hash`; and commit no more than 50 places per transaction.

- [ ] **Step 4: Implement crash-recoverable artifacts**

Fsync the pre-image rollback payload before commit. After commit, atomically append rollback/applied state. Recovery compares live nine-field hashes with stored `applied_content_hash`, not the original baseline timestamp hash.

- [ ] **Step 5: Implement constrained rollback**

Support exactly one of `--place-id`, `--batch-id`, `--province-id`, `--pilot`, or `--all`. Limit every selector by the manifest. Restore only when the live applied-content hash still matches, preserving later admin edits.

- [ ] **Step 6: Run mocked tests and commit**

```bash
(cd cf_service && python3 -m unittest test_place_content_apply.py test_place_content_repository.py -v)
git add cf_service/scripts/place_content_backfill cf_service/test_place_content_apply.py
git commit -m "feat: apply reversible place content batches"
```

### Task 9: Expose long descriptions only through Recommend detail

**Files:**
- Modify: `cf_service/routes/recommend.py`
- Create: `cf_service/test_recommend_place_detail.py`
- Modify: `frontend/lib/features/recommend/data/recommend_repository.dart`
- Modify: `frontend/lib/features/recommend/presentation/recommended_place_detail_page.dart`
- Modify/Create targeted Flutter tests.

**Interfaces:**
- Produces: detail-only API `detailed_description`, Dart `detailedDescription`, and long/short/fallback presentation behavior.

- [ ] **Step 1: Write Python response isolation tests**

Create a dedicated `_place_detail_response()` or conditionally map the field only when selected. Assert province/card/Trip Planner payloads do not contain `detailed_description`; the individual detail query and response do.

- [ ] **Step 2: Write Dart mapping and widget tests**

Test nullable mapping, long-copy preference, blank long-copy fallback to short copy, and final fallback to subcategory/address.

- [ ] **Step 3: Fix the detail loading path**

`RecommendedPlaceDetailPage._load()` must always call `RecommendRepository().getPlaceById(widget.idPlace)` for full detail data. It must not return a top-list/card object merely because the place appears in the province’s top list.

- [ ] **Step 4: Document cache behavior**

The runbook must account for `_PLACE_DETAIL_CACHE` TTL during post-apply verification by clearing/redeploying the service or waiting longer than the configured TTL.

- [ ] **Step 5: Run tests and commit**

```bash
(cd cf_service && python3 -m unittest test_recommend_place_detail.py -v)
(cd frontend && flutter test test/features/recommend/data/recommend_repository_test.dart test/features/recommend/presentation/recommended_place_detail_page_test.dart)
(cd frontend && flutter analyze)
git add cf_service/routes/recommend.py cf_service/test_recommend_place_detail.py frontend/lib/features/recommend frontend/test/features/recommend
git commit -m "feat: show detailed place descriptions"
```

### Task 10: Add the operator runbook and artifact hygiene

**Files:**
- Modify: `.gitignore`
- Create: `docs/place-content-backfill-runbook.md`

**Interfaces:**
- Produces: owner-run commands for migration reconciliation, secrets, pilot review, rollout, recovery, and evidence.

- [ ] **Step 1: Ignore artifacts without overwriting existing rules**

Append `.artifacts/place-content/` only if absent. In the isolated worktree, confirm the diff contains no unrelated `.gitignore` changes.

- [ ] **Step 2: Use repository-relative, cross-platform commands**

Commands must run from repository root with `(cd cf_service && ...)`, `(cd frontend && ...)`, and `npx supabase --workdir backend ...`. Do not hardcode `D:\Work\...` or another machine-specific absolute path.

- [ ] **Step 3: Document owner-supplied secrets and budgets**

Use macOS `zsh` commands as the primary examples and PowerShell only as an optional Windows appendix. Use `python3`, repository-relative paths, and quoted paths where needed. Show no real values. State that secrets must not be committed, logged, stored in artifacts, or shown in screenshots.

- [ ] **Step 4: Document pilot and rollout gates**

Include the exact `review-import` syntax, deterministic 20-per-province pilot selection, apply/rollback/reapply commands, cache TTL handling, stop conditions, province order, and expected counts.

- [ ] **Step 5: Commit**

```bash
git diff --check -- .gitignore docs/place-content-backfill-runbook.md
git add .gitignore docs/place-content-backfill-runbook.md
git commit -m "docs: add place content backfill runbook"
```

### Task 11: Produce the unattended handoff and stop

**Files:**
- Create: `docs/place-content-backfill-phase-a-handoff.md`

**Interfaces:**
- Consumes: Tasks 0–10.
- Produces: a sanitized owner review packet. No deployment or external mutation.

- [ ] **Step 1: Run all unattended-safe tests**

```bash
(cd cf_service && python3 -m unittest test_place_content_models.py test_place_content_artifacts.py test_place_content_repository.py test_place_content_sources.py test_place_content_naming.py test_place_content_generator.py test_place_content_validators.py test_place_content_apply.py test_recommend_place_detail.py -v)
(cd frontend && flutter test test/features/recommend/data/recommend_repository_test.dart test/features/recommend/presentation/recommended_place_detail_page_test.dart)
(cd frontend && flutter analyze)
git diff --check
```

Run these commands serially in the displayed order. Do not use background jobs, `xargs -P`, parallel test runners, or simultaneous terminals. Run local pgTAP only if an already-running local stack can replay without pulling or repairing remote history; do not start Docker during Phase A.

- [ ] **Step 2: Run the 1,533-record memory regression**

Create `cf_service/test_place_content_memory.py` using synthetic fixed-size records. It must stream 1,533 baseline/source/proposal/review rows through artifact iteration and chunked duplicate indexing. It must also run at least three sequential synthetic worker chunks and prove each worker is a new PID, prior workers have exited, the supervisor retains no full-record results, and resume skips completed IDs. Use Python `tracemalloc` and assert peak traced Python allocation stays below 256 MiB. Run on macOS with:

```bash
(cd cf_service && /usr/bin/time -l python3 -m unittest test_place_content_memory.py -v)
```

Expected: test passes; record `maximum resident set size` in the handoff. If RSS reaches 1.5 GiB or the process swaps heavily, stop and report rather than increasing the cap.

- [ ] **Step 3: Run secret and artifact checks**

Confirm no `.artifacts/place-content/` files are tracked and no known secret variable contains a non-placeholder value in the diff. Do not print environment values.

- [ ] **Step 4: Write the handoff**

Record commits, tests, deferred pgTAP status, migration drift summary, files changed, open review questions, and the exact commands proposed for Phase B. Do not include database URLs, API keys, generated content, or raw user data.

- [ ] **Step 5: Commit the handoff**

```bash
git add docs/place-content-backfill-phase-a-handoff.md
git commit -m "docs: hand off place backfill phase a"
```

- [ ] **Step 6: Hard stop**

Do not begin Task 12. Report that Phase A is ready for owner review.

---

## Review Gate — owner must return

Before continuing, the owner reviews:

- the isolated branch/worktree diff and commits;
- `docs/place-content-backfill-preflight.md` migration drift;
- the generated incremental migration and view definition;
- all Phase A test output and any deferred pgTAP result;
- the runbook commands, DeepSeek model, per-million-token prices, and caps;
- the human review policy for sparse and non-sparse proposals;
- the exact production project and deployment workflow.

Continuation requires an explicit owner instruction. Supabase write tools, production credentials, and real provider requests remain unauthorized until then.

## Phase B — owner-approved reconciliation and pilot

### Task 12: Reconcile migration history and deploy schema/code

- [ ] Compare local and remote migration histories and choose a reviewed reconciliation strategy.
- [ ] If `db pull` is chosen, inspect the complete generated diff before committing; it must describe existing remote objects only.
- [ ] Prove a fresh local replay creates `place_translation` and `place_localized_en` before the new migration runs.
- [ ] Run the new pgTAP test locally.
- [ ] Review the linked migration dry-run through the project’s normal workflow.
- [ ] Deploy only the reviewed migration and Recommend code/app changes.
- [ ] Run pgTAP in the intended environment plus Supabase security and performance advisors.
- [ ] Report unrelated pre-existing findings without broadening this feature.

### Task 13: Generate, review, apply, roll back, and reapply the 100-row pilot

- [ ] Run `audit` and require exact 1,533 and province counts.
- [ ] Select deterministically exactly 20 rows per province; persist pilot IDs in the manifest.
- [ ] Collect sources and call DeepSeek with owner-approved model/request/token/cost caps.
- [ ] Validate and export `needs-review.csv`.
- [ ] Human-review all 100 rows, not only validator failures.
- [ ] Import decisions with `review-import`; revalidate edits.
- [ ] Require 100 approved pilot rows. A rejected row must be corrected and re-reviewed; rejection cannot coexist with the expected 100-row apply count.
- [ ] Apply in batches of at most 50; verify exactly 100 places and 200 translations.
- [ ] Clear/wait out the detail cache and verify two pilot places per province plus one non-pilot fallback.
- [ ] Roll back the pilot and prove exact restoration.
- [ ] Reapply the same approved pilot and repeat database/UI checks.
- [ ] Record sanitized pilot evidence and stop for owner approval of full rollout.

## Phase C — owner-approved rollout

### Task 14: Roll out all five provinces with per-province gates

- [ ] Generate remaining proposals in resumable owner-capped chunks.
- [ ] Human-review every remaining proposal. Each row needs an explicit `approve` or validator-passing `edit`; no unresolved or rejected row may be counted as complete.
- [ ] Apply and verify in order: Huế 201, Hà Nội 235, Quảng Ninh 200, Lâm Đồng 358, Hồ Chí Minh 539.
- [ ] After Lâm Đồng, confirm its two inactive rows remain inactive.
- [ ] After each province, verify database counts, both translations, UI detail behavior, Trip Planner payload/performance, applied artifacts, and rollback readiness before continuing.
- [ ] Final completeness must be exactly 1,533 valid place/vi/en detailed descriptions, zero missing translations, zero placeholders, and zero outside-scope changes from this run.
- [ ] Repeat pgTAP, all targeted Python/Flutter tests, `flutter analyze`, and Supabase advisors.
- [ ] Record final reviewed counts, provider/model, prompt version, token totals, cost estimate, source coverage, advisor outcome, and rollback artifact path without committing artifacts or secrets.

## Current documentation references

- [DeepSeek JSON Output](https://api-docs.deepseek.com/guides/json_mode/)
- [DeepSeek Chat Completions](https://api-docs.deepseek.com/api/create-chat-completion)
- [MediaWiki page content API](https://www.mediawiki.org/wiki/API:Get_the_contents_of_a_page/en)
- [Supabase database migrations](https://supabase.com/docs/guides/deployment/database-migrations)
- [Supabase API security](https://supabase.com/docs/guides/api/securing-your-api)
- [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security)
