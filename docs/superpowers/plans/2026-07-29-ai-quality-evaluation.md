# AI Quality Evaluation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and run a reproducible quality evaluation for HelloVietnam's Gemini AI Search, DeepSeek AI Chat and translation, and VBee TTS features.

**Architecture:** A dependency-free Python evaluation package loads locked JSONL cases, invokes the same deployed Supabase Edge Functions used by Flutter, records raw responses and latency, computes automatic metrics, and exports CSV/Markdown reports. An ephemeral authenticated Premium user is provisioned only for the live run and is removed in a `finally` cleanup path. Human-only judgments such as factuality, fluency, and speech naturalness are exported as rating sheets and are never fabricated.

**Tech Stack:** Python 3.11 standard library, `unittest`, Supabase Auth/Admin REST API, PostgREST, deployed Supabase Edge Functions.

## Global Constraints

- Do not modify production Edge Functions or database schema.
- Do not print or persist the Supabase service-role key, user JWT, or generated password.
- Preserve all existing uncommitted architecture and report changes.
- Use the deployed `ai-search`, `ai-chat`, and `translate` functions because those are the functions used by the current Flutter application.
- Treat model-provided confidence as uncalibrated until compared with observed correctness.
- Keep raw model outputs for reproducibility, but mark human-only quality dimensions as pending until rated.
- Always remove the ephemeral evaluation user and related public rows after a live run.

---

### Task 1: Pure AI Quality Metrics

**Files:**
- Create: `evaluation/ai_quality/__init__.py`
- Create: `evaluation/ai_quality/metrics.py`
- Test: `evaluation/ai_quality/tests/test_metrics.py`

**Interfaces:**
- Produces: `normalize_text`, `token_f1`, `character_f_score`, `classification_summary`, `expected_calibration_error`, `percentile`, and `preserved_numbers`.

- [ ] **Step 1: Write failing metric tests**

Cover accent-insensitive normalization, hand-calculated token F1, perfect and imperfect character scores, macro-F1 with a missing class, calibration error, percentile interpolation, and number preservation.

- [ ] **Step 2: Run tests to verify RED**

Run: `python -m unittest evaluation.ai_quality.tests.test_metrics -v`

Expected: import failure because `evaluation.ai_quality.metrics` does not exist.

- [ ] **Step 3: Implement the minimal pure functions**

Use only the Python standard library. Validate empty inputs and clamp confidence values to `[0, 1]`.

- [ ] **Step 4: Run tests to verify GREEN**

Run: `python -m unittest evaluation.ai_quality.tests.test_metrics -v`

Expected: all metric tests pass.

### Task 2: Dataset Contracts and Automatic Scoring

**Files:**
- Create: `evaluation/ai_quality/contracts.py`
- Create: `evaluation/ai_quality/scoring.py`
- Test: `evaluation/ai_quality/tests/test_contracts.py`
- Test: `evaluation/ai_quality/tests/test_scoring.py`

**Interfaces:**
- Consumes: metric functions from Task 1.
- Produces: `load_jsonl`, `validate_cases`, `score_ai_search`, `score_ai_chat`, `score_translation`, `score_tts`, and `aggregate_scores`.

- [ ] **Step 1: Write failing contract and scoring tests**

Use literal fixtures for valid and invalid JSONL rows. Assert classification accuracy, name similarity, database-match correctness, action-key correctness, translation preservation, TTS URL success, and error accounting.

- [ ] **Step 2: Run tests to verify RED**

Run: `python -m unittest evaluation.ai_quality.tests.test_contracts evaluation.ai_quality.tests.test_scoring -v`

Expected: imports fail because the contract and scoring modules do not exist.

- [ ] **Step 3: Implement contract validation and scoring**

Reject duplicate IDs and missing required fields. Keep factuality, relevance, fluency, and MOS as nullable human scores.

- [ ] **Step 4: Run tests to verify GREEN**

Run: `python -m unittest evaluation.ai_quality.tests.test_contracts evaluation.ai_quality.tests.test_scoring -v`

Expected: all tests pass.

### Task 3: Supabase Live Evaluation Client

**Files:**
- Create: `evaluation/ai_quality/supabase_client.py`
- Test: `evaluation/ai_quality/tests/test_supabase_client.py`

**Interfaces:**
- Produces: `SupabaseEvaluationClient`, `EphemeralEvaluationUser`, `load_env_file`, and HTTP result records.

- [ ] **Step 1: Write failing HTTP-boundary tests**

Use a local in-process HTTP server. Verify headers, JSON request bodies, image download MIME handling, auth-user provisioning, and cleanup order without contacting production.

- [ ] **Step 2: Run tests to verify RED**

Run: `python -m unittest evaluation.ai_quality.tests.test_supabase_client -v`

Expected: import failure because the client module does not exist.

- [ ] **Step 3: Implement the minimal REST client**

Use `urllib.request`, per-request timeouts, redacted errors, and a context manager whose `__exit__` performs cleanup even after provider failures.

- [ ] **Step 4: Run tests to verify GREEN**

Run: `python -m unittest evaluation.ai_quality.tests.test_supabase_client -v`

Expected: all tests pass.

### Task 4: Locked Evaluation Cases and Runner

**Files:**
- Create: `evaluation/ai_quality/datasets/ai_search.jsonl`
- Create: `evaluation/ai_quality/datasets/ai_chat.jsonl`
- Create: `evaluation/ai_quality/datasets/translation.jsonl`
- Create: `evaluation/ai_quality/datasets/tts.jsonl`
- Create: `evaluation/ai_quality/run_evaluation.py`
- Create: `evaluation/ai_quality/README.md`
- Test: `evaluation/ai_quality/tests/test_runner.py`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: `validate`, `run`, and `summarize` CLI commands plus timestamped raw JSONL, scored CSV, summary JSON, report Markdown, and human-rating CSV.

- [ ] **Step 1: Write failing runner tests**

Assert that `validate` accepts all four locked datasets and that `summarize` produces deterministic aggregate fields from a small raw fixture.

- [ ] **Step 2: Run tests to verify RED**

Run: `python -m unittest evaluation.ai_quality.tests.test_runner -v`

Expected: import failure because the runner does not exist.

- [ ] **Step 3: Add representative locked cases**

Use database-backed Vietnamese food/culture images, multi-intent travel-chat prompts, bilingual travel phrases with references, and Vietnamese/English TTS sentences containing place names, dates, and prices.

- [ ] **Step 4: Implement the runner and report export**

Support `--features`, `--limit`, `--env-file`, `--provision-user`, and `--output-dir`. Always write skipped/error records instead of silently dropping cases.

- [ ] **Step 5: Run tests to verify GREEN**

Run: `python -m unittest evaluation.ai_quality.tests.test_runner -v`

Expected: all tests pass.

### Task 5: Live Pilot and Evidence

**Files:**
- Create: `evaluation/ai_quality/results/<run-id>/raw.jsonl`
- Create: `evaluation/ai_quality/results/<run-id>/scores.csv`
- Create: `evaluation/ai_quality/results/<run-id>/summary.json`
- Create: `evaluation/ai_quality/results/<run-id>/report.md`
- Create: `evaluation/ai_quality/results/<run-id>/human_ratings.csv`

**Interfaces:**
- Consumes: the complete evaluation CLI and `cf_service/.env`.
- Produces: reproducible pilot evidence for the thesis report.

- [ ] **Step 1: Validate all cases**

Run: `python -m evaluation.ai_quality.run_evaluation validate`

Expected: zero invalid or duplicate cases.

- [ ] **Step 2: Run a smoke pilot**

Run: `python -m evaluation.ai_quality.run_evaluation run --provision-user --limit 2`

Expected: each selected deployed function returns either a scored success or an explicit provider/configuration error; the temporary user is removed.

- [ ] **Step 3: Run the locked pilot**

Run: `python -m evaluation.ai_quality.run_evaluation run --provision-user`

Expected: raw and scored artifacts are created for every case, with no missing rows.

- [ ] **Step 4: Complete automatic summary**

Run: `python -m evaluation.ai_quality.run_evaluation summarize --run-dir <run-dir>`

Expected: summary JSON and Markdown contain per-feature sample counts, success/error rate, latency percentiles, task metrics, and pending-human-rating counts.

- [ ] **Step 5: Run the full verification suite**

Run: `python -m unittest discover -s evaluation/ai_quality/tests -v`

Expected: all tests pass with zero failures and zero errors.

