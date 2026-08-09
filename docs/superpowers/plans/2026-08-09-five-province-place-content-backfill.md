# Five-Province Place Content Backfill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Normalize Vietnamese/English names and descriptions, then fill long-form descriptions for exactly 1,533 places in Hồ Chí Minh, Huế, Hà Nội, Quảng Ninh, and Lâm Đồng.

**Architecture:** A resumable Python pipeline snapshots the scoped Supabase rows, enriches them from verified OSM/Wikimedia/official-site sources, locks names with deterministic rules, asks DeepSeek only to write grounded bilingual copy, validates every proposal, and applies approved batches atomically through `asyncpg`. Local JSONL artifacts provide checkpoints and exact rollback without adding a database audit table; Recommend exposes long copy only on its detail endpoint.

**Tech Stack:** PostgreSQL 17/Supabase, Supabase CLI and pgTAP, Python 3.11, Pydantic 2.7, `httpx`, `asyncpg`, `supabase-py`, DeepSeek Chat Completions JSON Output, Flutter/Dart.

## Global Constraints

- Scope is exactly these province UUIDs:
  - Hồ Chí Minh: `094014a7-b8f6-481a-bbce-5ed6cdd457c5` — 539 rows.
  - Huế: `b5f3ef5e-dc49-4482-88e3-a8048cb32639` — 201 rows.
  - Hà Nội: `3355c4a1-ccb1-46be-99e5-046d5f55b891` — 235 rows.
  - Quảng Ninh: `8f9d18e3-7e24-4e36-bf50-a3823c1f78df` — 200 rows.
  - Lâm Đồng: `49fa7ad8-b892-494d-a712-bb49802200c1` — 358 rows.
- Process all 1,533 scoped rows, including two inactive Lâm Đồng rows; never change their status.
- Add only `public.place_translation.detailed_description`; `place_translation.description` remains the localized short description.
- `place` remains Vietnamese source of truth; the `vi` translation mirrors it.
- English display names preserve proper-name tokens/diacritics and translate only generic types: `Sông Hương` → `Hương River`, never `Perfume River`.
- DeepSeek never selects names and never writes directly to Supabase.
- Short copy is 20–45 words; long copy is 90–160 words.
- Do not invent dates, history, prices, ratings, distances, schedules, awards, amenities, or superlatives.
- Auto-apply only rows passing every deterministic validator; export all others for review.
- Apply at most 50 places per transaction and require an unchanged baseline hash.
- Never store or expose `DEEPSEEK_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, or `DATABASE_URL`.
- Do not include image/rating/price/tag/RLS remediation or Trip Planner algorithm changes.
- Do not apply production rows until the reviewed 100-row pilot has passed a rollback test.

## File Structure

**Database**

- Create via `npx supabase migration new add_place_translation_detailed_description`: CLI-generated file in `backend/supabase/migrations/`.
- Create: `backend/supabase/tests/place_content_backfill_schema_test.sql`

**Pipeline**

- Create: `cf_service/scripts/place_content_backfill/__init__.py`
- Create: `cf_service/scripts/place_content_backfill/constants.py`
- Create: `cf_service/scripts/place_content_backfill/models.py`
- Create: `cf_service/scripts/place_content_backfill/artifacts.py`
- Create: `cf_service/scripts/place_content_backfill/repository.py`
- Create: `cf_service/scripts/place_content_backfill/sources/__init__.py`
- Create: `cf_service/scripts/place_content_backfill/sources/osm.py`
- Create: `cf_service/scripts/place_content_backfill/sources/wikimedia.py`
- Create: `cf_service/scripts/place_content_backfill/sources/website.py`
- Create: `cf_service/scripts/place_content_backfill/naming.py`
- Create: `cf_service/scripts/place_content_backfill/generator.py`
- Create: `cf_service/scripts/place_content_backfill/validators.py`
- Create: `cf_service/scripts/place_content_backfill/cli.py`
- Create: `cf_service/scripts/place_content_backfill/prompts/place_content_v1.md`

**Tests**

- Create: `cf_service/test_place_content_models.py`
- Create: `cf_service/test_place_content_artifacts.py`
- Create: `cf_service/test_place_content_repository.py`
- Create: `cf_service/test_place_content_sources.py`
- Create: `cf_service/test_place_content_naming.py`
- Create: `cf_service/test_place_content_generator.py`
- Create: `cf_service/test_place_content_validators.py`
- Create: `cf_service/test_place_content_apply.py`
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

### Task 1: Add the localized detailed-description schema

**Files:**
- Create: `backend/supabase/tests/place_content_backfill_schema_test.sql`
- Create: CLI-generated `backend/supabase/migrations/*_add_place_translation_detailed_description.sql`

**Interfaces:**
- Consumes: existing `place`, `place_translation`, `place_localized_en`.
- Produces: nullable translation detail column and English view field.

- [ ] **Step 1: Verify CLI and migration history**

Run from `backend`:

```powershell
npx supabase --version
npx supabase migration --help
npx supabase db --help
npx supabase migration list --linked
```

Expected: linked project `ziouozppetvvdrzgojcx` is reachable. The repository currently does not show the migration that created `place_translation`; if local replay lacks it, first run:

```powershell
npx supabase db pull reconcile_place_translation_baseline --linked --yes
```

Review and commit that generated baseline separately; it must describe existing remote objects, not introduce new behavior.

- [ ] **Step 2: Write the failing pgTAP test**

Create `backend/supabase/tests/place_content_backfill_schema_test.sql`:

```sql
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select has_column('public', 'place_translation', 'detailed_description');
select col_type_is('public', 'place_translation', 'detailed_description', 'text');
select col_is_null('public', 'place_translation', 'detailed_description');
select has_column('public', 'place_localized_en', 'detailed_description');
select ok(
  coalesce((select reloptions @> array['security_invoker=true']
              from pg_class
             where oid = 'public.place_localized_en'::regclass), false),
  'English place view uses security_invoker'
);
select results_eq(
  $$ select count(*)::bigint from public.place_localized_en $$,
  $$ select count(*)::bigint from public.place $$,
  'view remains one row per place'
);

select * from finish();
rollback;
```

- [ ] **Step 3: Run the test and confirm the missing-column failure**

```powershell
npx supabase test db supabase/tests/place_content_backfill_schema_test.sql
```

- [ ] **Step 4: Create the migration using the CLI**

```powershell
npx supabase migration new add_place_translation_detailed_description
```

Use the exact emitted path; do not invent a migration timestamp.

- [ ] **Step 5: Implement the migration**

```sql
alter table public.place_translation
  add column if not exists detailed_description text;

comment on column public.place_translation.detailed_description is
  'Localized long-form place description; description remains short-form.';

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

- [ ] **Step 6: Run the pgTAP test and diff checks**

```powershell
npx supabase test db supabase/tests/place_content_backfill_schema_test.sql
git diff --check -- supabase/migrations supabase/tests/place_content_backfill_schema_test.sql
```

Expected: 6 assertions pass; no unrelated schema changes.

- [ ] **Step 7: Commit**

```powershell
git add supabase/migrations supabase/tests/place_content_backfill_schema_test.sql
git commit -m "feat: add localized place detail descriptions"
```

---

### Task 2: Define strict models, province allowlist, artifacts, and CLI safety

**Files:**
- Create: pipeline package files `__init__.py`, `constants.py`, `models.py`, `artifacts.py`, `cli.py`
- Create: `cf_service/test_place_content_models.py`
- Create: `cf_service/test_place_content_artifacts.py`

**Interfaces:**
- Produces: `APPROVED_PROVINCES`, `BaselineRecord`, `SourceFact`, `SourceSnapshot`, `NameDecision`, `GeneratedContent`, `Proposal`, `ValidationResult`, `RunManifest`, `ArtifactStore`, and `build_parser()`.

- [ ] **Step 1: Write failing scope/model tests**

Assert the allowlist equals the five UUIDs above, `EXPECTED_TOTAL == 1533`, Pydantic models use `extra='forbid'`, confidence stays in `[0,1]`, and `RunManifest.new()` rejects any other province UUID.

Use this generated-content contract:

```python
class GeneratedContent(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    short_description_vi: str
    detailed_description_vi: str
    short_description_en: str
    detailed_description_en: str
    used_fact_ids: list[str]
    warnings: list[str]
    confidence: float = Field(ge=0, le=1)
```

- [ ] **Step 2: Write failing artifact tests**

Test UTF-8 JSONL append/read/resume, atomic manifest replacement, completed-place detection, and recursive rejection of secret-shaped keys/values.

- [ ] **Step 3: Run tests and verify missing-module failures**

```powershell
cd D:\Work\hello-vietnam\cf_service
python -m unittest test_place_content_models.py test_place_content_artifacts.py -v
```

- [ ] **Step 4: Implement constants and Pydantic models**

Define exact count constants, `MAX_APPLY_BATCH_SIZE = 50`, and `PROMPT_VERSION = 'place_content_v1'`. All data models are immutable and reject unknown fields. `SourceFact` includes `fact_id`, `value`, `source_url`, and source kind. `NameDecision` includes selected names, rule, source, confidence, warnings, and rejected alternatives.

- [ ] **Step 5: Implement `ArtifactStore`**

Expose these exact methods on `ArtifactStore`:

- `__init__(root: Path, run_id: str) -> None`
- `write_manifest(manifest: RunManifest) -> None`
- `read_manifest() -> RunManifest`
- `append(stream: str, value: BaseModel | dict) -> None`
- `read_all(stream: str) -> list[dict]`
- `completed_place_ids(stream: str) -> set[str]`
- `write_review_csv(proposals: list[Proposal]) -> Path`

Artifacts live at `.artifacts/place-content/<run-id>/` and use `manifest.json`, `baseline.jsonl`, `sources.jsonl`, `proposals.jsonl`, `approved.jsonl`, `needs-review.csv`, `applied.jsonl`, and `rollback.jsonl`.

- [ ] **Step 6: Implement the CLI shell**

Commands: `audit`, `collect`, `generate`, `validate`, `apply`, `rollback`, `status`. `apply` and `rollback` require `--run-id` and `--confirm`; without confirmation, exit with code 2 before opening a DB connection.

- [ ] **Step 7: Run tests and commit**

```powershell
python -m unittest test_place_content_models.py test_place_content_artifacts.py -v
git add scripts/place_content_backfill test_place_content_models.py test_place_content_artifacts.py
git commit -m "feat: scaffold safe place content pipeline"
```

---

### Task 3: Extract and hash the exact Supabase baseline

**Files:**
- Create: `cf_service/scripts/place_content_backfill/repository.py`
- Create: `cf_service/test_place_content_repository.py`
- Modify: `cf_service/scripts/place_content_backfill/cli.py`

**Interfaces:**
- Produces: `fetch_baseline()`, `verify_baseline_counts()`, `editable_hash()`, and working `audit`.

- [ ] **Step 1: Write failing pagination, allowlist, and hash tests**

Use fake paginated responses to prove all pages are read, every query has a province/content-ID filter, missing `vi`/`en` translations fail, 1,532 rows fail count verification, equal records have equal hashes, and changing any editable field changes its hash.

- [ ] **Step 2: Run the failing test**

```powershell
python -m unittest test_place_content_repository.py -v
```

- [ ] **Step 3: Implement paginated filtered reads**

Read `place` in pages of 500 filtered by the five UUIDs. Fetch matching translations, `content_freshness`, subcategory, and place tags in ID batches. Build exactly one `BaselineRecord` per place and require both language rows.

- [ ] **Step 4: Implement canonical editable hashes**

SHA-256 sorted UTF-8 JSON containing the three `place` content values and timestamps plus `name`, `description`, `detailed_description`, and timestamps for both translations. Do not normalize the stored text before hashing.

- [ ] **Step 5: Implement `audit --scope approved-five`**

It must require counts `539/201/235/200/358`, total 1,533, and zero outside-scope records; write baseline/manifest and print only counts plus a run ID formatted `YYYYMMDD-HHMMSS-<8 hex chars>`.

- [ ] **Step 6: Run tests and commit**

```powershell
python -m unittest test_place_content_repository.py test_place_content_models.py test_place_content_artifacts.py -v
git add scripts/place_content_backfill test_place_content_repository.py
git commit -m "feat: audit scoped place content baseline"
```

---

### Task 4: Collect and cache grounded source facts

**Files:**
- Create: `cf_service/scripts/place_content_backfill/sources/__init__.py`
- Create: `cf_service/scripts/place_content_backfill/sources/osm.py`
- Create: `cf_service/scripts/place_content_backfill/sources/wikimedia.py`
- Create: `cf_service/scripts/place_content_backfill/sources/website.py`
- Create: `cf_service/test_place_content_sources.py`
- Modify: `cf_service/scripts/place_content_backfill/cli.py`

**Interfaces:**
- Consumes: `BaselineRecord`, injected `httpx.AsyncClient`, artifact cache.
- Produces: `collect_source_snapshot(record) -> SourceSnapshot` and `sources.jsonl`.

- [ ] **Step 1: Write failing OSM identity tests**

Cover:

```python
self.assertEqual(parse_osm_id("osm:node:123"), ("node", 123))
self.assertEqual(parse_osm_id("osm:way:456"), ("way", 456))
self.assertEqual(parse_osm_id("osm:relation:789"), ("relation", 789))
with self.assertRaises(ValueError):
    parse_osm_id("osm:node:not-a-number")
```

Use `httpx.MockTransport`; no unit test may call the internet.

- [ ] **Step 2: Write failing Wikimedia identity tests**

Accept explicit Wikidata IDs matching `Q[0-9]+` and Wikipedia tags formatted as `<language-code>:<page-title>`. Reject a same-name article with conflicting province/type/coordinates and reject name-only matching without corroboration.

- [ ] **Step 3: Write failing official-site SSRF tests**

Reject `file://`, localhost, private/link-local/loopback IPs, public-to-private redirects, non-HTML bodies, and responses above 1 MiB.

- [ ] **Step 4: Run tests and confirm failure**

```powershell
python -m unittest test_place_content_sources.py -v
```

- [ ] **Step 5: Implement OSM batch collection**

Group `node`, `way`, and `relation` IDs and use Overpass batches of at most 100. Allow only:

```text
name, name:vi, name:en, official_name, alt_name,
wikidata, wikipedia, description, description:vi, description:en,
tourism, amenity, historic, natural, leisure, shop, cuisine,
brand, operator, website, contact:website, opening_hours
```

Every fact has a stable ID such as `osm.name_vi` and retains its OSM source URL.

- [ ] **Step 6: Implement Wikimedia enrichment**

Use `wbgetentities` in QID batches and MediaWiki Action API extracts. Fetch an article only through an explicit source link or after exact name/province/type/coordinate checks. Store excerpts as evidence; do not copy paragraphs verbatim into descriptions.

- [ ] **Step 7: Implement optional official-site metadata**

Follow only OSM/database URLs, revalidate redirects, cap reads at 1 MiB, and extract only `<title>`, meta description, and JSON-LD name/type/address using standard-library parsers. Default off; enable only with `collect --include-official-sites`.

- [ ] **Step 8: Implement retry, rate-limit, and resume behavior**

Use an identifying User-Agent, timeouts, three attempts, exponential backoff, `Retry-After`, and concurrency 3. Cache by request URL/parameters and baseline input hash. A missing source becomes a valid sparse snapshot with warnings.

- [ ] **Step 9: Run tests and commit**

```powershell
python -m unittest test_place_content_sources.py test_place_content_repository.py -v
git add scripts/place_content_backfill test_place_content_sources.py
git commit -m "feat: collect grounded place content sources"
```

---

### Task 5: Normalize names deterministically using option 3

**Files:**
- Create: `cf_service/scripts/place_content_backfill/naming.py`
- Create: `cf_service/test_place_content_naming.py`

**Interfaces:**
- Consumes: baseline plus source snapshot.
- Produces: `normalize_names(record, sources) -> NameDecision`.

- [ ] **Step 1: Write approved regression tests**

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

Assert `Sông Hương != Perfume River`, `Cái Cấm` never contains `Forbidden`, and `Bề Bề Nội` never becomes `Interior Surface`.

- [ ] **Step 2: Write source-priority and protected-token tests**

Prove `name:vi` wins when identity matches, an OSM `name:en=Perfume River` is rejected as display name, a verified official institution name may be used, and digits/acronyms/brands/personal names survive unchanged.

- [ ] **Step 3: Run tests and confirm failure**

```powershell
python -m unittest test_place_content_naming.py -v
```

- [ ] **Step 4: Implement longest-match generic-type rules**

Use Unicode case-insensitive rules for `Nhà Thờ Giáo Xứ`, `Nhà Thờ`, `Bảo Tàng`, `Sân Bay`, `Nhà Ga`, `Bến Xe`, `Chùa`, `Đền`, `Chợ`, `Cầu`, `Sông`, `Hồ`, `Núi`, `Bãi`, and `Công Viên`. Preserve unmatched proper-name text and diacritics exactly.

- [ ] **Step 5: Implement contextual brand/geographic behavior**

Use subcategory/source type: a restaurant brand called `Sông Tiền` stays `Sông Tiền`; a river named `Sông Tiền` becomes `Tiền River`. Accept external English institution/brand names only when explicitly sourced and identity-safe.

- [ ] **Step 6: Return explainable decisions**

Record names, source, rule, confidence, warnings, and rejected alternatives. Confidence below `0.85` becomes review-only.

- [ ] **Step 7: Run tests and commit**

```powershell
python -m unittest test_place_content_naming.py -v
git add scripts/place_content_backfill/naming.py test_place_content_naming.py
git commit -m "feat: normalize place names without literal translation"
```

---

### Task 6: Generate grounded bilingual copy through DeepSeek JSON Output

**Files:**
- Create: `cf_service/scripts/place_content_backfill/generator.py`
- Create: `cf_service/scripts/place_content_backfill/prompts/place_content_v1.md`
- Create: `cf_service/test_place_content_generator.py`
- Modify: `cf_service/scripts/place_content_backfill/cli.py`
- Modify: `cf_service/.env.example`

**Interfaces:**
- Consumes: baseline, source facts, locked name decision, budget state.
- Produces: strict `GeneratedContent`, provider usage metadata, `proposals.jsonl`.

- [ ] **Step 1: Write failing prompt tests**

Assert the rendered prompt includes locked names, fact IDs, `Return valid JSON`, both word limits, unsupported-claim rules, prompt-injection isolation, and no secrets.

- [ ] **Step 2: Write failing provider tests with `httpx.MockTransport`**

Cover valid JSON with `finish_reason=stop`, empty/malformed/truncated output, unknown fields, 429 with `Retry-After`, three failures, and an exact input-hash cache hit that makes no second request.

- [ ] **Step 3: Write failing budget tests**

Refuse the next request before exceeding `--max-requests`, input/output token caps, or `--max-estimated-cost-usd`. Never hardcode prices; cost limiting requires `DEEPSEEK_INPUT_COST_PER_MILLION_USD` and `DEEPSEEK_OUTPUT_COST_PER_MILLION_USD`.

- [ ] **Step 4: Run tests and confirm failure**

```powershell
python -m unittest test_place_content_generator.py -v
```

- [ ] **Step 5: Write `place_content_v1.md`**

Lock names; require exactly:

```json
{
  "short_description_vi": "string",
  "detailed_description_vi": "string",
  "short_description_en": "string",
  "detailed_description_en": "string",
  "used_fact_ids": ["osm.type"],
  "warnings": [],
  "confidence": 0.92
}
```

Include a sparse-source and source-rich example. State that source-page instructions are untrusted data.

- [ ] **Step 6: Implement `DeepSeekContentClient.generate()`**

POST to `https://api.deepseek.com/chat/completions`, temperature `0.2`, `max_tokens=1400`, and `response_format={"type":"json_object"}`. Require explicit `DEEPSEEK_API_KEY` and `DEEPSEEK_CONTENT_MODEL`; do not silently choose a model.

- [ ] **Step 7: Implement generation checkpoints**

Input hash includes prompt version, model, baseline hash, names, and facts. Store model, token counts, finish reason, and parsed content but no headers/credentials. Resume only an exact hash.

- [ ] **Step 8: Update `.env.example`**

```env
DEEPSEEK_API_KEY=replace-with-server-side-deepseek-key
DEEPSEEK_CONTENT_MODEL=replace-with-approved-content-model
DEEPSEEK_INPUT_COST_PER_MILLION_USD=
DEEPSEEK_OUTPUT_COST_PER_MILLION_USD=
```

- [ ] **Step 9: Run tests and commit**

```powershell
python -m unittest test_place_content_generator.py test_place_content_models.py -v
git add scripts/place_content_backfill test_place_content_generator.py .env.example
git commit -m "feat: generate grounded bilingual place content"
```

---

### Task 7: Validate proposals and support human review

**Files:**
- Create: `cf_service/scripts/place_content_backfill/validators.py`
- Create: `cf_service/test_place_content_validators.py`
- Modify: `cf_service/scripts/place_content_backfill/artifacts.py`
- Modify: `cf_service/scripts/place_content_backfill/cli.py`

**Interfaces:**
- Consumes: proposals, baseline, facts, all scoped descriptions.
- Produces: `ValidationResult`, `approved.jsonl`, `needs-review.csv`.

- [ ] **Step 1: Write failing content/name tests**

Reject empty/out-of-range content, `Hihi`/test/demo/placeholders, protected-name loss, changed digits/acronyms/brands, `Perfume River`, `Forbidden`, Markdown/HTML, and model/instruction fragments.

- [ ] **Step 2: Write failing grounded-claim tests**

Reject a year, price, rating, distance, or time not found in allowlisted facts; accept a normalized claim only when its source fact exists and is referenced by `used_fact_ids`.

- [ ] **Step 3: Write failing bilingual/duplicate tests**

Reject province/category/name disagreement. Verify punctuation/address-only variants exceed near-duplicate threshold `0.92`.

- [ ] **Step 4: Run tests and confirm failure**

```powershell
python -m unittest test_place_content_validators.py -v
```

- [ ] **Step 5: Implement deterministic validators**

Expose these exact functions:

- `validate_proposal(proposal: Proposal, baseline: BaselineRecord, sources: SourceSnapshot) -> ValidationResult`
- `find_near_duplicates(proposals: list[Proposal]) -> dict[str, list[str]]`

Use Unicode word counts, protected-token checks, fact-ID subset checks, numeric-claim extraction, forbidden patterns, and deterministic character 5-gram similarity. Do not use an LLM approval judge.

- [ ] **Step 6: Implement review CSV import/export**

Columns: place/province IDs, current/proposed names, four descriptions, flags, source URLs, `reviewer_decision`, `reviewer_notes`. Accept only `approve`, `edit`, or `reject`; edited content must pass all validators again.

- [ ] **Step 7: Wire `validate` and `status`**

Rebuild approved/review artifacts from immutable proposals. Status prints counts/budget only, not content.

- [ ] **Step 8: Run tests and commit**

```powershell
python -m unittest test_place_content_validators.py test_place_content_artifacts.py -v
git add scripts/place_content_backfill test_place_content_validators.py
git commit -m "feat: validate and review generated place content"
```

---

### Task 8: Apply and roll back approved batches atomically

**Files:**
- Modify: `cf_service/scripts/place_content_backfill/repository.py`
- Modify: `cf_service/scripts/place_content_backfill/cli.py`
- Create: `cf_service/test_place_content_apply.py`

**Interfaces:**
- Consumes: approved proposals, baselines, `DATABASE_URL`.
- Produces: atomic updates, `applied.jsonl`, `rollback.jsonl`.

- [ ] **Step 1: Write failing safety tests**

Prove missing `--confirm`, batch size 51, outside-scope province, or unapproved proposal exits before mutation.

- [ ] **Step 2: Write failing transaction tests**

With a fake asyncpg transaction, cover successful three-row update, changed hash conflict, missing translation, zero-row update, and final-update exception. Failed cases must roll back and not append applied state.

- [ ] **Step 3: Write failing rollback tests**

Restore exactly nine values: name/short/detail in `place`, `vi`, and `en`. Refuse rollback if content was edited after apply.

- [ ] **Step 4: Run tests and confirm failure**

```powershell
python -m unittest test_place_content_apply.py -v
```

- [ ] **Step 5: Implement `apply_approved_batch()`**

Lock each place and both translations, recompute baseline hash, enforce allowlisted province, and parameterize all SQL. One transaction handles at most 50 places; assert one place, one `vi`, and one `en` row per proposal.

- [ ] **Step 6: Persist recovery data safely**

Fsync a temporary rollback payload before commit; after commit, atomically append rollback/applied streams. If artifact finalization fails after DB commit, reconstruct state by comparing live values with proposal hashes before retrying.

- [ ] **Step 7: Implement constrained rollback**

Support `--place-id`, `--batch-id`, `--province-id`, or `--all`, always limited by manifest. Lock, verify current applied hash, restore prior payload transactionally, and preserve later admin edits.

- [ ] **Step 8: Run tests and commit**

```powershell
python -m unittest test_place_content_apply.py test_place_content_repository.py -v
git add scripts/place_content_backfill test_place_content_apply.py
git commit -m "feat: apply reversible place content batches"
```

---

### Task 9: Expose long descriptions only on Recommend detail

**Files:**
- Modify: `cf_service/routes/recommend.py`
- Create: `cf_service/test_recommend_place_detail.py`
- Modify: `frontend/lib/features/recommend/data/recommend_repository.dart`
- Modify: `frontend/lib/features/recommend/presentation/recommended_place_detail_page.dart`
- Modify: `frontend/test/features/recommend/data/recommend_repository_test.dart`
- Create: `frontend/test/features/recommend/presentation/recommended_place_detail_page_test.dart`

**Interfaces:**
- Consumes: `place_localized_en.detailed_description`.
- Produces: API `detailed_description` and Dart `detailedDescription` for detail UI.

- [ ] **Step 1: Write failing Python response/query tests**

Assert `_place_response()` maps `detailed_description` and the individual `_get_recommended_place_sync()` select requests it. Assert province ranking/candidate selects remain unchanged so Trip Planner/card payloads do not carry long copy.

- [ ] **Step 2: Write the failing Dart mapping test**

```dart
final ProvinceTopPlace place = ProvinceTopPlace.fromJson(<String, dynamic>{
  'id_place': 'p1',
  'name': 'Hương River',
  'short_description': 'Short copy',
  'detailed_description': 'Long copy',
});
expect(place.shortDescription, 'Short copy');
expect(place.detailedDescription, 'Long copy');
```

- [ ] **Step 3: Write failing detail/fallback widget tests**

Cover long-copy preference and blank/null long-copy fallback. Extract and test:

```dart
String recommendedPlaceDescription(ProvinceTopPlace place, String fallback) {
  final String detailed = place.detailedDescription?.trim() ?? '';
  if (detailed.isNotEmpty) return detailed;
  final String short = place.shortDescription?.trim() ?? '';
  return short.isNotEmpty ? short : fallback;
}
```

- [ ] **Step 4: Run tests and confirm failure**

```powershell
cd D:\Work\hello-vietnam\cf_service
python -m unittest test_recommend_place_detail.py -v
cd D:\Work\hello-vietnam\frontend
flutter test test/features/recommend/data/recommend_repository_test.dart test/features/recommend/presentation/recommended_place_detail_page_test.dart
```

- [ ] **Step 5: Implement service and Flutter changes**

Add the API key, select it only in the individual detail query, map nullable `detailedDescription`, and use the helper in the detail page. Cards continue using `shortDescription`.

- [ ] **Step 6: Run tests/analyzer and commit**

```powershell
cd D:\Work\hello-vietnam\cf_service
python -m unittest test_recommend_place_detail.py -v
cd D:\Work\hello-vietnam\frontend
flutter test test/features/recommend/data/recommend_repository_test.dart test/features/recommend/presentation/recommended_place_detail_page_test.dart
flutter analyze
git add ..\cf_service\routes\recommend.py ..\cf_service\test_recommend_place_detail.py lib\features\recommend test\features\recommend
git commit -m "feat: show detailed place descriptions"
```

Expected: targeted tests pass and analysis has no new issues.

---

### Task 10: Add an operator runbook and artifact hygiene

**Files:**
- Modify: `.gitignore`
- Create: `docs/place-content-backfill-runbook.md`

**Interfaces:**
- Produces: reproducible preflight, pilot, rollout, rollback, and verification procedure.

- [ ] **Step 1: Ignore generated artifacts**

Append to `.gitignore`:

```gitignore
.artifacts/place-content/
```

- [ ] **Step 2: Document Windows secret setup**

Use PowerShell syntax and mark every angle-bracket value as owner-supplied:

```powershell
cd D:\Work\hello-vietnam\cf_service
$env:SUPABASE_URL = "https://ziouozppetvvdrzgojcx.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY = "<owner-supplied service key>"
$env:DATABASE_URL = "<Supavisor session-pooler URL>"
$env:DEEPSEEK_API_KEY = "<owner-supplied DeepSeek key>"
$env:DEEPSEEK_CONTENT_MODEL = "<approved current model>"
```

State that secrets must not be committed, logged, or shown in screenshots.

- [ ] **Step 3: Document phases and expected counts**

The runbook must show `audit`, `collect`, `generate`, `validate`, `status`, `apply`, and `rollback`, using `$placeContentRunId` populated from audit output. Required counts: total 1,533; provinces 539/201/235/200/358; outside scope zero.

- [ ] **Step 4: Document pilot and stop conditions**

Review all 100 pilot rows, correct only through CSV import, validate again, apply, verify UI, rollback, verify restoration, then reapply. Stop on hash conflicts, count mismatches, unresolved review rows, partial translations, provider-budget exhaustion, or UI regression.

- [ ] **Step 5: Document rollout order**

Huế → Hà Nội → Quảng Ninh → Lâm Đồng → Hồ Chí Minh, with verification after every province.

- [ ] **Step 6: Check and commit docs**

```powershell
git diff --check -- .gitignore docs/place-content-backfill-runbook.md
git add .gitignore docs/place-content-backfill-runbook.md
git commit -m "docs: add place content backfill runbook"
```

---

### Task 11: Verify code/schema and execute the guarded 100-row pilot

**Files:**
- Verification only; update the runbook if actual verified commands differ.

**Interfaces:**
- Consumes: implemented pipeline, linked Supabase, owner secrets.
- Produces: deployed schema/code and reviewed reversible pilot.

- [ ] **Step 1: Run all targeted local tests**

```powershell
cd D:\Work\hello-vietnam\backend
npx supabase test db supabase/tests/place_content_backfill_schema_test.sql

cd D:\Work\hello-vietnam\cf_service
python -m unittest test_place_content_models.py test_place_content_artifacts.py test_place_content_repository.py test_place_content_sources.py test_place_content_naming.py test_place_content_generator.py test_place_content_validators.py test_place_content_apply.py test_recommend_place_detail.py -v

cd D:\Work\hello-vietnam\frontend
flutter test test/features/recommend/data/recommend_repository_test.dart test/features/recommend/presentation/recommended_place_detail_page_test.dart
flutter analyze
```

Expected: all feature tests pass; analyzer has no new issues.

- [ ] **Step 2: Deploy migration/code through normal workflows**

Review the linked migration diff, deploy the CLI-generated migration rather than running ad-hoc production DDL, deploy the Recommend service/app changes, and rerun pgTAP in the intended environment.

- [ ] **Step 3: Run Supabase security and performance advisors**

Fix findings introduced by the view/migration. Report existing unrelated findings separately without broadening scope.

- [ ] **Step 4: Run the read-only audit**

```powershell
cd D:\Work\hello-vietnam\cf_service
python -m scripts.place_content_backfill.cli audit --scope approved-five
```

Require exactly 1,533 rows with verified province counts and zero outside-scope rows. Copy the emitted ID into `$placeContentRunId`.

- [ ] **Step 5: Collect and generate only the pilot**

```powershell
python -m scripts.place_content_backfill.cli collect --run-id $placeContentRunId
python -m scripts.place_content_backfill.cli generate --run-id $placeContentRunId --pilot --max-items 100 --max-requests 120
python -m scripts.place_content_backfill.cli validate --run-id $placeContentRunId
python -m scripts.place_content_backfill.cli status --run-id $placeContentRunId
```

Expected: 20 stratified rows per province and every non-approved row in `needs-review.csv`.

- [ ] **Step 6: Review all 100 pilot rows**

Check names, both short/long descriptions, source URLs, province/category, unsupported claims, and option-3 naming. Import edits and revalidate until every pilot row is approved or explicitly rejected.

- [ ] **Step 7: Apply, verify, rollback, and reapply the pilot**

```powershell
python -m scripts.place_content_backfill.cli apply --run-id $placeContentRunId --pilot --confirm
python -m scripts.place_content_backfill.cli status --run-id $placeContentRunId
python -m scripts.place_content_backfill.cli rollback --run-id $placeContentRunId --pilot --confirm
python -m scripts.place_content_backfill.cli status --run-id $placeContentRunId
python -m scripts.place_content_backfill.cli apply --run-id $placeContentRunId --pilot --confirm
```

Expected: apply changes exactly 100 places and 200 translations; rollback exactly restores baseline; reapply restores approved content.

- [ ] **Step 8: Verify UI and Trip Planner**

Check at least two pilot places per province: cards use short copy, details use long English copy, option-3 names preserve proper identity, and a non-pilot row falls back to short copy. Confirm Trip Planner still loads with unchanged candidate payload/performance.

- [ ] **Step 9: Record sanitized pilot evidence**

Add run ID, counts, tests, validation totals, rollback result, and screenshot checklist to the runbook. Never include secrets or a full database URL.

---

### Task 12: Roll out all five provinces and prove completeness

**Files:**
- Update: `docs/place-content-backfill-runbook.md` run log only.

**Interfaces:**
- Consumes: successful pilot and reviewed proposals.
- Produces: complete 1,533-row backfill and verification evidence.

- [ ] **Step 1: Generate remaining rows with explicit caps**

Run resumable chunks using owner-approved request/token/cost limits. Never remove a cap merely to finish faster.

- [ ] **Step 2: Resolve every review row before its province applies**

Approve, edit, or reject with reason. Every edit must pass validation again; unresolved rows block that province.

- [ ] **Step 3: Apply and verify Huế**

Province `b5f3ef5e-dc49-4482-88e3-a8048cb32639`; verify exactly 201 places and both translations.

- [ ] **Step 4: Apply and verify Hà Nội**

Province `3355c4a1-ccb1-46be-99e5-046d5f55b891`; verify exactly 235.

- [ ] **Step 5: Apply and verify Quảng Ninh**

Province `8f9d18e3-7e24-4e36-bf50-a3823c1f78df`; verify exactly 200.

- [ ] **Step 6: Apply and verify Lâm Đồng**

Province `49fa7ad8-b892-494d-a712-bb49802200c1`; verify exactly 358 and two inactive rows remain inactive.

- [ ] **Step 7: Apply and verify Hồ Chí Minh**

Province `094014a7-b8f6-481a-bbce-5ed6cdd457c5`; verify exactly 539.

- [ ] **Step 8: Run final read-only completeness checks**

Assert:

```text
target places=1533
valid place detailed descriptions=1533
valid vi translation detailed descriptions=1533
valid en translation detailed descriptions=1533
missing vi/en rows=0
Hihi/test/demo/placeholders=0
outside-scope changes from this run=0
```

- [ ] **Step 9: Run final regressions/advisors**

Repeat pgTAP, all pipeline Python tests, targeted Recommend Flutter tests, `flutter analyze`, and Supabase advisors. Compare Recommend/Trip Planner latency to pre-rollout baseline.

- [ ] **Step 10: Finalize and commit sanitized evidence**

Record final counts, reviewed/rejected totals, provider/model, prompt version, token totals, source coverage, advisor outcome, and rollback artifact path. Do not commit `.artifacts`.

```powershell
git add docs/place-content-backfill-runbook.md
git commit -m "docs: record place content backfill verification"
```

## Current Documentation References

- [DeepSeek JSON Output](https://api-docs.deepseek.com/guides/json_mode/)
- [DeepSeek Chat Completions](https://api-docs.deepseek.com/api/create-chat-completion)
- [MediaWiki page content API](https://www.mediawiki.org/wiki/API:Get_the_contents_of_a_page/en)
- [Supabase API security](https://supabase.com/docs/guides/api/securing-your-api)
- [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security)
