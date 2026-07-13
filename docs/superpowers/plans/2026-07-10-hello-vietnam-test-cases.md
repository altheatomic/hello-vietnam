# Hello Vietnam Test Case Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a repository-native test case package for Hello Vietnam that covers core frontend journeys, backend edge functions, execution environments, and an automation gap backlog.

**Architecture:** Keep the work documentation-first. Create a small `docs/qa/` set that mirrors the current monorepo structure, groups cases by feature risk, and maps every major test area to concrete frontend and backend files already present in the repo. Reuse existing test files only as evidence for current automation coverage; do not broaden into framework work.

**Tech Stack:** Markdown documentation, Flutter test inventory, Deno edge-function test inventory, Supabase functions, PowerShell commands

## Global Constraints

- Do not add new dependencies or new automation frameworks.
- Keep scope focused on reusable test case documentation for the current repository state as of `2026-07-10`.
- Prioritize feature-level coverage for `auth`, `explore`, `item_detail`, `forum`, `planner`, `location`, and `personalization`.
- Treat existing automated tests as coverage evidence, not as a reason to skip manual test cases.
- Keep terminology aligned with existing folders under `frontend/lib/features/` and `backend/supabase/functions/`.
- Use ASCII-only markdown content.

---

### Task 1: Inventory Product Surface And Existing Coverage

**Files:**
- Create: `docs/qa/test-scope.md`
- Modify: `docs/superpowers/specs/2026-07-10-project-test-cases-design.md`
- Test: coverage discovery only

**Interfaces:**
- Consumes: repository structure under `frontend/lib/features/`, existing tests under `frontend/test/`, existing functions under `backend/supabase/functions/`
- Produces: `docs/qa/test-scope.md` with sections `Feature Priority Matrix`, `Existing Automated Coverage`, and `Out Of Scope For Phase 1`

- [ ] **Step 1: Create the `docs/qa/` directory**

Run:

```powershell
New-Item -ItemType Directory -Path docs/qa -Force
```

Expected: PowerShell prints directory creation output or confirms the directory already exists.

- [ ] **Step 2: Write the failing scope skeleton**

Create `docs/qa/test-scope.md` with:

```markdown
# Hello Vietnam Test Scope

## Feature Priority Matrix

| Feature | Priority | Why It Matters | Current Coverage |
| --- | --- | --- | --- |
| auth | P0 | Login and access control gate multiple flows | No dedicated automated tests found |
| explore | P0 | Discovery entry point with backend dependency | Flutter unit/widget tests, Deno behavior tests |
| item_detail | P0 | Shared destination for explore/forum flows | Request parsing test only |
| forum | P0 | User-generated content and sharing flow | Share widget tests |
| planner | P0 | Multi-screen stateful flow | No dedicated automated tests found |
| location | P1 | Personalization input and device dependency | No dedicated automated tests found |
| personalization | P1 | Recommendation setup and persisted preferences | No dedicated automated tests found |
| profile | P1 | User settings and saved content access | No dedicated automated tests found |
| translate | P1 | External-service edge cases | No dedicated automated tests found |
| admin | P2 | Operational workflow but narrower audience | No dedicated automated tests found |

## Existing Automated Coverage

- `frontend/test/features/explore/domain/explore_parsing_test.dart`
- `frontend/test/features/explore/data/explore_repository_test.dart`
- `frontend/test/features/explore/data/explore_tracking_service_test.dart`
- `frontend/test/features/explore/presentation/explore_page_test.dart`
- `frontend/test/features/forum/domain/create_forum_post_request_test.dart`
- `frontend/test/features/forum/presentation/forum_share_post_widgets_test.dart`
- `frontend/test/features/item_detail/domain/item_detail_request_test.dart`
- `backend/supabase/functions/explore/explore_behavior_test.ts`

## Out Of Scope For Phase 1

- Performance benchmarking
- Security penetration testing
- Full device/browser matrix certification
- Screenshot diff automation
```

- [ ] **Step 3: Verify the repository evidence for the scope document**

Run:

```powershell
Get-ChildItem frontend/lib/features -Directory | Select-Object -ExpandProperty Name
```

Expected: includes `auth`, `explore`, `forum`, `planner`, `location`, `personalization`, and `admin`.

- [ ] **Step 4: Add coverage notes to the design spec**

Append this section to `docs/superpowers/specs/2026-07-10-project-test-cases-design.md` if missing:

```markdown
## Coverage Evidence Snapshot

- Flutter tests currently exist for `explore`, `forum`, and `item_detail` request handling.
- Deno behavior coverage currently exists for `backend/supabase/functions/explore/explore_behavior.ts`.
- No dedicated automated coverage was found during planning for `auth`, `planner`, `location`, `personalization`, `translate`, or `admin`.
```

- [ ] **Step 5: Re-open the scope document and confirm all P0/P1 features are listed**

Run:

```powershell
Get-Content docs/qa/test-scope.md
```

Expected: the table includes all P0/P1 features and at least one coverage note per row.

- [ ] **Step 6: Commit**

```bash
git add docs/qa/test-scope.md docs/superpowers/specs/2026-07-10-project-test-cases-design.md
git commit -m "docs: define hello vietnam test scope"
```

### Task 2: Define Test Environments And Data Preconditions

**Files:**
- Create: `docs/qa/test-environments.md`
- Test: environment checklist only

**Interfaces:**
- Consumes: `README.md`, `frontend/pubspec.yaml`, `backend/supabase/functions/*/README.md`, `frontend/lib/main.dart`, `frontend/lib/main_admin.dart`
- Produces: `docs/qa/test-environments.md` with sections `Entry Points`, `Accounts`, `Data Setup`, and `Execution Notes`

- [ ] **Step 1: Write the failing environment skeleton**

Create `docs/qa/test-environments.md` with:

```markdown
# Hello Vietnam Test Environments

## Entry Points

- User web app: `frontend/lib/main.dart`
- Admin web app: `frontend/lib/main_admin.dart`
- Backend functions: `backend/supabase/functions/`

## Accounts

| Account Type | Purpose | Required |
| --- | --- | --- |
| Anonymous user | Browse public routes and guest gating | Yes |
| Registered user | Forum, planner, wishlist, profile flows | Yes |
| Admin user | Admin food management smoke checks | Yes |

## Data Setup

- At least one province with related explore content in `activity`, `culture`, `food`, and `local_products`
- One user account with saved or favorited content
- One forum-capable account that can create a post
- One account with personalization answers already stored

## Execution Notes

- Mark which cases can run with local mocks only.
- Mark which cases require Supabase connectivity.
- Record any reset actions needed after destructive scenarios.
```

- [ ] **Step 2: Verify the repo startup guidance**

Run:

```powershell
Get-Content README.md
```

Expected: mentions `frontend/lib/main.dart` and `frontend/lib/main_admin.dart` as app entry points.

- [ ] **Step 3: Add backend-dependent notes for function-backed features**

Append this content to `docs/qa/test-environments.md`:

```markdown
## Backend-Dependent Areas

- `explore`: requires content tables and, for event tracking, authenticated requests
- `users/location-preference`: requires a logged-in user to persist preference data
- `users/travel-preferences`: requires a logged-in user and stored questionnaire output
- `users/wishlist`: requires a logged-in user and saved content records
- `subscription-payment`: requires a non-production payment test setup before execution
```

- [ ] **Step 4: Re-read the environment document and verify every P0 flow has preconditions**

Run:

```powershell
Get-Content docs/qa/test-environments.md
```

Expected: includes account and data notes for `auth`, `explore`, `forum`, `planner`, and admin access.

- [ ] **Step 5: Commit**

```bash
git add docs/qa/test-environments.md
git commit -m "docs: define hello vietnam test environments"
```

### Task 3: Author Core Manual Test Cases

**Files:**
- Create: `docs/qa/manual-test-cases.md`
- Test: manual-case structure review

**Interfaces:**
- Consumes: `docs/qa/test-scope.md`, `docs/qa/test-environments.md`, routes and feature names from `frontend/lib/app/router.dart`
- Produces: `docs/qa/manual-test-cases.md` containing executable manual cases for P0 and selected P1 flows with IDs in the form `UI-###`

- [ ] **Step 1: Write the manual test case template and first four P0 cases**

Create `docs/qa/manual-test-cases.md` with:

```markdown
# Hello Vietnam Manual Test Cases

## Case Format

- ID
- Feature
- Priority
- Preconditions
- Steps
- Expected Result

## UI-001: Register With Valid Information

- Feature: auth
- Priority: P0
- Preconditions: app is reachable, no existing account uses the target email
- Steps:
  1. Open the user web app.
  2. Navigate to the register screen.
  3. Enter valid name, email, and password values.
  4. Submit the form.
- Expected Result: registration succeeds and the app moves to the next intended state without a validation error.

## UI-002: Login Guard Redirects Profile Access

- Feature: auth
- Priority: P0
- Preconditions: user is logged out
- Steps:
  1. Open the user app.
  2. Tap the Profile tab from the bottom navigation.
- Expected Result: the app redirects the user to the login route instead of opening profile content.

## UI-003: Explore Search Opens Province Results

- Feature: explore
- Priority: P0
- Preconditions: backend is reachable and at least one searchable province exists
- Steps:
  1. Open Explore.
  2. Open search.
  3. Search for a known province such as `Da Nang`.
  4. Select a result.
- Expected Result: the app opens the province search result flow without route or parsing errors.

## UI-004: Share Explore Item Into Forum Post Composer

- Feature: forum
- Priority: P0
- Preconditions: logged-in user, at least one explore item is available
- Steps:
  1. Open an explore item detail page.
  2. Trigger the share action into forum.
  3. Confirm the composer opens.
- Expected Result: the composer shows the shared item preview and hides add-photo controls for the share-only flow.
```

- [ ] **Step 2: Expand the manual suite with planner, item detail, location, and personalization cases**

Append these additional IDs:

```markdown
## UI-005: Planner Saves A Trip
## UI-006: Saved Trip Opens From Bookmark Shortcut
## UI-007: Item Detail Loads From Shared Forum Card
## UI-008: Location Preference Saves Successfully
## UI-009: Travel Personalization Onboarding Persists Answers
## UI-010: Wishlist Reflects A Newly Saved Item
## UI-011: Translate Screen Returns A Result For Valid Input
## UI-012: Profile Opens Saved Content And Settings Routes
```

For each case, fill the same fields with explicit preconditions, 3-6 steps, and one observable expected result.

- [ ] **Step 3: Verify route and feature names before finalizing case wording**

Run:

```powershell
Get-Content frontend/lib/app/router.dart
```

Expected: route and feature labels used in the document match real app areas such as `Explore`, `Forum`, `Profile`, and planner-related pages.

- [ ] **Step 4: Re-read the manual cases and confirm each P0 feature has at least one happy-path and one guard/error-path case**

Run:

```powershell
Get-Content docs/qa/manual-test-cases.md
```

Expected: `auth`, `explore`, `forum`, `planner`, and `item_detail` all appear; at least one case covers access gating or invalid/missing-state behavior.

- [ ] **Step 5: Commit**

```bash
git add docs/qa/manual-test-cases.md
git commit -m "docs: add hello vietnam manual test cases"
```

### Task 4: Author Backend And Edge Function Test Cases

**Files:**
- Create: `docs/qa/api-test-cases.md`
- Test: function-case structure review

**Interfaces:**
- Consumes: `backend/supabase/functions/*/README.md`, request shapes in function entry files, and `docs/qa/test-environments.md`
- Produces: `docs/qa/api-test-cases.md` containing function test cases with IDs in the form `API-###`

- [ ] **Step 1: Write the API test case template and `explore` cases first**

Create `docs/qa/api-test-cases.md` with:

```markdown
# Hello Vietnam API Test Cases

## Case Format

- ID
- Function
- Priority
- Preconditions
- Request
- Expected Result

## API-001: Explore Sections Returns Default Payload

- Function: `explore`
- Priority: P0
- Preconditions: content data exists and the function endpoint is reachable
- Request:
  ```json
  {
    "action": "getExploreSections",
    "limitPerCategory": 4,
    "language": "en"
  }
  ```
- Expected Result: response includes a `sections` object and no server error.

## API-002: Explore Province Search Returns Matches

- Function: `explore`
- Priority: P0
- Preconditions: at least one searchable province exists
- Request:
  ```json
  {
    "action": "searchExploreProvinces",
    "query": "Da Nang",
    "limit": 8
  }
  ```
- Expected Result: response returns one or more matching province records without schema errors.

## API-003: Explore Event Tracking Rejects Missing Auth

- Function: `explore`
- Priority: P0
- Preconditions: no authorization header is sent
- Request:
  ```json
  {
    "action": "recordExploreEvent",
    "contentType": "culture",
    "contentId": "sample-id",
    "provinceId": "sample-province",
    "eventType": "favorite",
    "requestId": "req-missing-auth"
  }
  ```
- Expected Result: the function rejects the request because authenticated access is required for event recording.
```

- [ ] **Step 2: Add cases for the remaining high-risk functions**

Append these sections and fill them with one success case and one failure/auth case each:

```markdown
## API-004: `users/location-preference`
## API-005: `users/travel-preferences`
## API-006: `users/wishlist`
## API-007: `translate`
## API-008: `ai-search`
## API-009: `media-upload`
## API-010: `subscription-payment`
## API-011: `admin/admin-food`
```

Each case must include a concrete JSON request body or an explicit note that the call shape is multipart/auth-header based.

- [ ] **Step 3: Verify the `explore` request shapes against the repo README**

Run:

```powershell
Get-Content backend/supabase/functions/explore/README.md
```

Expected: confirms the action names `getExploreSections`, `searchExploreProvinces`, `getExploreCategoryItems`, and `recordExploreEvent`.

- [ ] **Step 4: Re-read the API document and confirm every high-risk function has both positive and negative coverage**

Run:

```powershell
Get-Content docs/qa/api-test-cases.md
```

Expected: every P0/P1 function has at least one valid-input case and one auth/invalid-input/empty-state case.

- [ ] **Step 5: Commit**

```bash
git add docs/qa/api-test-cases.md
git commit -m "docs: add hello vietnam api test cases"
```

### Task 5: Map Regression Checklist And Automation Gaps

**Files:**
- Create: `docs/qa/regression-checklist.md`
- Create: `docs/qa/automation-gap-backlog.md`
- Test: checklist completeness review

**Interfaces:**
- Consumes: `docs/qa/test-scope.md`, `docs/qa/manual-test-cases.md`, `docs/qa/api-test-cases.md`, existing test files under `frontend/test/` and `backend/supabase/functions/explore/`
- Produces: `docs/qa/regression-checklist.md` for quick execution and `docs/qa/automation-gap-backlog.md` with backlog IDs in the form `AUTO-###`

- [ ] **Step 1: Write the regression checklist**

Create `docs/qa/regression-checklist.md` with:

```markdown
# Hello Vietnam Regression Checklist

## Pre-Merge Smoke

- UI-002 Login guard redirects unauthenticated profile access
- UI-003 Explore search opens a result successfully
- UI-004 Share Explore item opens forum composer correctly
- UI-005 Planner saves a trip
- UI-010 Wishlist reflects a newly saved item
- API-001 Explore sections returns default payload
- API-003 Explore event tracking rejects missing auth

## Pre-Demo Smoke

- App launch on user web entry point
- App launch on admin web entry point
- Login with a valid test account
- Explore to item detail navigation
- Forum share flow
- One admin food-management smoke check
```

- [ ] **Step 2: Write the automation backlog tied to exact files**

Create `docs/qa/automation-gap-backlog.md` with:

```markdown
# Hello Vietnam Automation Gap Backlog

## AUTO-001: Add auth route-guard widget tests

- Target files:
  - `frontend/lib/app/router.dart`
  - `frontend/test/`
- Reason: profile-tab login gating is business-critical and currently lacks a dedicated automated test.

## AUTO-002: Add planner widget or state tests

- Target files:
  - `frontend/lib/features/planner/`
  - `frontend/test/features/planner/`
- Reason: planner is a P0 multi-screen flow with no visible automated coverage.

## AUTO-003: Add location preference repository tests

- Target files:
  - `frontend/lib/features/location/data/location_preference_repository.dart`
  - `frontend/test/features/location/`
- Reason: persisted preference behavior is user-state-sensitive and currently uncovered.

## AUTO-004: Add travel preferences repository or handler tests

- Target files:
  - `frontend/lib/features/personalization/data/travel_preferences_repository.dart`
  - `backend/supabase/functions/users/travel-preferences/travel_preferences_handler.ts`
- Reason: personalization directly affects recommendation behavior and needs validation on both client and backend boundaries.

## AUTO-005: Expand edge-function negative-path tests

- Target files:
  - `backend/supabase/functions/explore/explore_behavior_test.ts`
  - `backend/supabase/functions/users/*`
  - `backend/supabase/functions/admin/admin-food/`
- Reason: current backend automated coverage is concentrated in one explore behavior test file.
```

- [ ] **Step 3: Verify the existing automated file paths used in the backlog**

Run:

```powershell
rg --files frontend/test backend/supabase/functions
```

Expected: returns the existing test files and function folders referenced in the backlog.

- [ ] **Step 4: Re-read both documents and confirm every regression item traces back to a documented test case**

Run:

```powershell
Get-Content docs/qa/regression-checklist.md
Get-Content docs/qa/automation-gap-backlog.md
```

Expected: every smoke item references a manual or API case ID, and every backlog item points to exact repo paths.

- [ ] **Step 5: Commit**

```bash
git add docs/qa/regression-checklist.md docs/qa/automation-gap-backlog.md
git commit -m "docs: add regression checklist and automation backlog"
```

### Task 6: Final Validation

**Files:**
- Verify only

**Interfaces:**
- Consumes: all files created in `docs/qa/`
- Produces: a validated documentation bundle ready for team review

- [ ] **Step 1: Run a final read-through of the generated QA package**

Run:

```powershell
Get-Content docs/qa/test-scope.md
Get-Content docs/qa/test-environments.md
Get-Content docs/qa/manual-test-cases.md
Get-Content docs/qa/api-test-cases.md
Get-Content docs/qa/regression-checklist.md
Get-Content docs/qa/automation-gap-backlog.md
```

Expected: each file opens cleanly and uses consistent feature names and case IDs.

- [ ] **Step 2: Run the current focused automated checks to preserve baseline confidence**

Run:

```bash
cd frontend
flutter test test/features/explore test/features/forum test/features/item_detail
```

Expected: existing Flutter tests pass or any failures are documented separately from the new QA docs work.

- [ ] **Step 3: Run the existing backend behavior test**

Run:

```bash
deno test backend/supabase/functions/explore/explore_behavior_test.ts
```

Expected: the current explore behavior test passes and remains the baseline backend coverage reference.

- [ ] **Step 4: Re-check the plan against the design spec**

Run:

```powershell
Get-Content docs/superpowers/specs/2026-07-10-project-test-cases-design.md
Get-Content docs/superpowers/plans/2026-07-10-hello-vietnam-test-cases.md
```

Expected: every deliverable from the design spec appears in at least one plan task.

## Self-Review

- Spec coverage:
  - feature prioritization: Task 1
  - environment and data prerequisites: Task 2
  - manual P0/P1 cases: Task 3
  - backend/API cases: Task 4
  - regression pack and automation mapping: Task 5
  - verification and baseline checks: Task 6
- Placeholder scan:
  - no TBD/TODO markers
  - every task names exact files and concrete document sections
  - every verification step has a command and expected outcome
- Type consistency:
  - manual case IDs use `UI-###`
  - API case IDs use `API-###`
  - automation backlog IDs use `AUTO-###`
  - all feature names match existing repo folders and routing language
