# AI Recognition Food Linking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Link recognized food images to verified Supabase food records when a sufficiently reliable match exists.

**Architecture:** Gemini remains responsible for visual recognition. The `ai-search` Edge Function loads a narrow, cached food-name catalog from `food` and `food_translation`, ranks canonical and translated names locally, and returns an optional `db_match`; Flutter keeps the AI result as a fallback and exposes the existing Explore detail flow only for verified matches.

**Tech Stack:** Supabase Edge Functions (Deno/TypeScript), Supabase JS, Flutter/Dart, GoRouter, Flutter tests, Deno tests.

## Global Constraints

- Never accept or invent a database ID from Gemini output.
- Only automatically link a high-confidence match; ambiguous results remain AI-only.
- Preserve the current recognition response when the DB is unavailable.
- Implement `food` first; other categories are outside this phase.

---

### Task 1: Food name matcher

**Files:**
- Create: `backend/supabase/functions/ai-search/food_matcher.ts`
- Create: `backend/supabase/functions/ai-search/food_matcher_test.ts`

**Interfaces:**
- Consumes: Gemini `detected_name`, `alternative_names`, and food catalog rows.
- Produces: `findBestFoodMatch(input): FoodDatabaseMatch | null`.

- [ ] **Step 1: Write failing tests for exact accented/unaccented aliases, fuzzy matches, and ambiguous rejection**
- [ ] **Step 2: Run `deno test food_matcher_test.ts` and verify RED**
- [ ] **Step 3: Implement normalization, scoring, and threshold rules**
- [ ] **Step 4: Run the matcher tests and verify GREEN**

### Task 2: Supabase food catalog and Edge response

**Files:**
- Create: `backend/supabase/functions/ai-search/food_catalog.ts`
- Modify: `backend/supabase/functions/ai-search/index.ts`
- Create: `backend/supabase/functions/ai-search/deno.json`

**Interfaces:**
- Consumes: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.
- Produces: optional JSON field `db_match` with `status`, `category`, `id`, `name`, `match_score`, and image metadata.

- [ ] **Step 1: Add tests around catalog-row mapping and graceful failure**
- [ ] **Step 2: Verify tests fail because catalog mapping is absent**
- [ ] **Step 3: Add a narrow cached catalog loader and attach matches after Gemini parsing**
- [ ] **Step 4: Verify Edge tests pass**

### Task 3: Flutter parsing and verified detail action

**Files:**
- Modify: `frontend/lib/features/ai_search/data/ai_search_service.dart`
- Modify: `frontend/lib/features/ai_search/presentation/ai_search_page.dart`
- Modify: `frontend/test/features/ai_search/data/ai_search_service_test.dart`
- Add or modify: `frontend/test/features/ai_search/presentation/ai_search_dark_mode_test.dart`

**Interfaces:**
- Consumes: optional `db_match`.
- Produces: a verified-source panel and navigation to `DetailCategory.food` using `ItemDetailRequest`.

- [ ] **Step 1: Add failing parsing and widget tests**
- [ ] **Step 2: Verify Flutter tests fail for the missing DB match model/UI**
- [ ] **Step 3: Extend the model and add the verified-detail action**
- [ ] **Step 4: Run focused tests, `flutter analyze`, and inspect the final diff**
