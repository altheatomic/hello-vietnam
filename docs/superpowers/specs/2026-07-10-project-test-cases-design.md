# Hello Vietnam Test Case Strategy Design

## Goal

Create a practical, reusable test case package for the Hello Vietnam monorepo so the team can validate the highest-risk user journeys consistently across Flutter frontend and Supabase backend.

## Scope

In scope:

- define a feature-based test scope for the current product surface
- prioritize test coverage by business risk and existing code maturity
- create manual test case documents for core user journeys
- create backend/API test case documents for Supabase edge functions
- map existing automated coverage and identify the next automation targets
- define a lightweight regression checklist the team can run before major merges or demos

Out of scope:

- building a new end-to-end automation framework
- rewriting existing frontend or backend tests
- full cross-device/browser certification
- performance, load, and security penetration testing beyond checklist-level coverage

## Current Situation

The repository is a monorepo with:

- `frontend/`: Flutter app for user and admin experiences
- `backend/`: Supabase functions, SQL, migrations, and scripts

The current automated coverage is concentrated in a few areas:

- Flutter tests for `explore`, `forum`, and `item_detail` request/parsing behavior
- a Deno test for `backend/supabase/functions/explore/explore_behavior.ts`

The app surface is broader than the current test coverage. The router and feature directories show active user-facing areas including:

- `auth`
- `home`
- `explore`
- `item_detail`
- `planner`
- `forum`
- `profile`
- `location`
- `personalization`
- `translate`
- `notification`
- `admin`

Because coverage is uneven, the test case effort should not start by trying to test every screen equally. It should start with the highest-risk flows and establish a structure that can grow incrementally.

## Proposed Strategy

Use a hybrid test case strategy with three layers:

### 1. Core Manual Journey Coverage

Document end-to-end manual test cases for business-critical flows that cross multiple screens and dependencies. These cases should be written so a tester can execute them without reverse-engineering the code.

Priority journeys:

- app launch and initial navigation
- login, register, forgot password
- explore browse, search, category drill-down, item detail
- share explore item into forum
- planner save/view trip flow
- location preference and travel personalization onboarding
- wishlist/saved content behavior
- translation and AI search entry flows

### 2. Backend/API Functional Coverage

Document request/response and edge-condition test cases for the Supabase functions currently present in the repo:

- `explore`
- `translate`
- `ai-search`
- `media-upload`
- `subscription-payment`
- `users/location-preference`
- `users/travel-preferences`
- `users/wishlist`
- `admin/admin-food`

These cases should focus on valid input, invalid input, auth requirements, empty states, fallback behavior, and data side effects.

### 3. Automation Alignment

Map each manual test area against existing automated tests. For high-risk areas already supported by test infrastructure, create an automation backlog so the team knows which widget/unit/function tests to add next.

Recommended first automation targets after the documents exist:

- `auth` form validation and route guard behavior
- `explore` happy path plus failure states
- `forum` post creation and share flow regressions
- `location` and `personalization` repository/service logic
- edge-function behavior tests for request validation and auth failure paths

## Deliverables

The test case effort should produce the following repository artifacts:

- `docs/qa/test-scope.md`
- `docs/qa/test-environments.md`
- `docs/qa/manual-test-cases.md`
- `docs/qa/api-test-cases.md`
- `docs/qa/regression-checklist.md`
- `docs/qa/automation-gap-backlog.md`

Each document should have a clear purpose:

- `test-scope.md`: feature inventory, prioritization, and coverage boundaries
- `test-environments.md`: accounts, data setup, platforms, and reset notes
- `manual-test-cases.md`: executable UI/business-flow cases
- `api-test-cases.md`: edge function functional cases and expected outcomes
- `regression-checklist.md`: compact pre-release or pre-demo checks
- `automation-gap-backlog.md`: missing automated coverage linked to concrete files

## Design Details

### 1. Feature Prioritization

Prioritize by a combination of:

- business value
- number of dependent systems
- likelihood of regressions
- presence of user state, auth, or persistence
- existing absence of automated coverage

Recommended priorities:

- P0: `auth`, `explore`, `item_detail`, `forum`, `planner`
- P1: `location`, `personalization`, `profile`, `wishlist`, `translate`
- P2: `notification`, `loyalty`, `popular_apps`, `admin`, less-trafficked pages

### 2. Test Case Format

Manual and API cases should use a consistent structure:

- test case ID
- feature/module
- priority
- preconditions
- steps
- expected result
- notes/data dependencies

This keeps the suite searchable and makes it easier to convert selected cases into automation later.

### 3. Environment Guidance

The test package should explicitly capture:

- web user app entry via `frontend/lib/main.dart`
- web admin app entry via `frontend/lib/main_admin.dart`
- required Supabase configuration assumptions
- seeded or mock accounts needed for auth/forum/planner/admin checks
- which tests can run offline/mock versus which need backend connectivity

### 4. Automation Mapping

The automation backlog should point directly to current code and test locations, for example:

- existing Flutter tests in `frontend/test/features/explore/...`
- existing Flutter tests in `frontend/test/features/forum/...`
- existing Deno function tests in `backend/supabase/functions/explore/...`

This avoids generic backlog items and gives the next engineer a concrete starting point.

## Risks

- If the first version tries to cover every screen in equal detail, it will become large and hard to maintain.
- If test cases omit environment and seed-data notes, execution will stall quickly.
- If manual and automation artifacts use different naming or feature boundaries, the suite will drift.

## Recommendation

Start with a documentation-first test package focused on core user journeys and backend function behavior, then attach an automation backlog to the exact files already present in this repo. That gives the team something immediately usable while keeping the next automation work grounded in current architecture.
