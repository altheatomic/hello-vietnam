# Public Trip Sharing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cho phép chủ lịch trình tạo link HTTPS có hạn dùng, người nhận xem lịch trình công khai trên web hoặc app và sao chép an toàn vào tài khoản của mình.

**Architecture:** Supabase lưu duy nhất hash của bearer token và Edge Functions là cổng truy cập duy nhất. Một web viewer tĩnh tải public DTO đã được lọc; Android App Link mở cùng URL trong Flutter, còn người chưa cài app tiếp tục xem trên web.

**Tech Stack:** PostgreSQL/RLS, Supabase Edge Functions (Deno/TypeScript), Flutter 3.41/Dart 3.11, `share_plus: 11.1.0`, Cloudflare Pages static hosting, Android App Links.

## Global Constraints

- Android package phải giữ nguyên `com.hellovietnam.app`.
- Link chia sẻ dùng mẫu `${SHARE_WEB_BASE_URL}/trip/<token>` và không hard-code domain chưa được cấp.
- Token gốc không được lưu trong PostgreSQL; chỉ lưu SHA-256 và prefix dùng cho quản trị.
- Public response không chứa user id, hồ sơ sở thích, điểm thuật toán nội bộ hoặc plan id.
- Hạn dùng được phép là 7, 30 hoặc 90 ngày; mặc định 30 ngày.
- Copy chỉ được phép bằng share token hợp lệ và khi `allow_copy = true`.

---

### Task 1: Share-token domain and database schema

**Files:**
- Create: `backend/supabase/functions/_shared/trip_share_domain.ts`
- Create: `backend/supabase/functions/_shared/trip_share_domain_test.ts`
- Create: `backend/supabase/migrations/20260801000100_trip_share_links.sql`

**Interfaces:**
- Produces: `createShareToken()`, `hashShareToken(token)`, `parseExpiryDays(value)`, `publicShareUrl(baseUrl, token)`.
- Produces table: `public.trip_share_link` accessible only to `service_role`.

- [ ] Write tests that require a URL-safe random token, stable SHA-256 hash, strict 7/30/90 expiry validation and normalized public URL.
- [ ] Run `deno test backend/supabase/functions/_shared/trip_share_domain_test.ts` and verify RED because the module does not exist.
- [ ] Implement the domain helpers with Web Crypto and no environment access.
- [ ] Run the domain tests and verify GREEN.
- [ ] Add a migration with UUID PK, plan/owner foreign keys, unique `token_hash`, `token_prefix`, `allow_copy`, expiry/revocation/access columns, indexes, RLS, revoked public/anon/authenticated grants and service-role grant.

### Task 2: Authenticated and public Edge Function flows

**Files:**
- Create: `backend/supabase/functions/trip-share/trip_share_handler.ts`
- Create: `backend/supabase/functions/trip-share/trip_share_handler_test.ts`
- Create: `backend/supabase/functions/trip-share/index.ts`
- Modify: `backend/supabase/functions/trip-planner/trip_handler.ts`
- Test: `backend/supabase/functions/trip-planner/trip_handler_test.ts`

**Interfaces:**
- Authenticated POST actions: `create`, `list`, `revoke`, `copy`.
- Public GET: `/trip-share/public/<token>`.
- Public DTO: `{ title, n_days, days, allow_copy, expires_at }`.

- [ ] Write handler tests for owner-only creation, generic not-found for invalid/expired/revoked links, whitelisted public DTO, disabled copy and successful copy.
- [ ] Run the handler tests and verify RED because the handler is absent.
- [ ] Implement dependency-injected domain handlers and an Edge entrypoint that authenticates all mutations while permitting only the public GET route anonymously.
- [ ] Add strict CORS for `SHARE_WEB_ALLOWED_ORIGINS`, `Cache-Control: no-store`, constant-shape 404 errors and access counters.
- [ ] Make copy call the existing FastAPI clone route only after token validation; preserve forum behavior but reject arbitrary raw UUID cloning unless owner or a visible forum share authorizes it.
- [ ] Run all Edge Function tests and verify GREEN.

### Task 3: Flutter repository, routing and share UI

**Files:**
- Modify: `frontend/pubspec.yaml`
- Modify: `frontend/lib/core/config/env.dart`
- Modify: `frontend/lib/features/planner/data/trip_repository.dart`
- Create: `frontend/lib/features/planner/data/models/trip_share_link.dart`
- Create: `frontend/lib/features/planner/presentation/shared_trip_page.dart`
- Create: `frontend/lib/features/planner/presentation/widgets/trip_share_sheet.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_result_page.dart`
- Modify: `frontend/lib/app/router.dart`
- Modify: `frontend/lib/app/deep_link_state.dart`
- Modify: `frontend/android/app/src/main/AndroidManifest.xml`
- Test: `frontend/test/app/deep_link_state_test.dart`
- Test: `frontend/test/features/planner/data/trip_share_link_test.dart`

**Interfaces:**
- Repository methods: `createShareLink`, `listShareLinks`, `revokeShareLink`, `getPublicSharedPlan`, `copySharedPlan`.
- Route: `/shared-trip?token=<token>`.

- [ ] Add failing model and deep-link tests for JSON mapping, HTTPS `/trip/<token>` parsing and preservation of existing payment/recovery links.
- [ ] Run focused Flutter tests and verify RED.
- [ ] Pin `share_plus: 11.1.0`, add configurable share base URL, implement models/repository calls and make public reads not require JWT.
- [ ] Implement share sheet with 7/30/90-day selection, system share, copy link, list/revoke actions and forum-sharing entry.
- [ ] Implement public in-app viewer and login-return flow for copying.
- [ ] Add a separate HTTPS App Link intent filter using a manifest placeholder host; do not mix it with the custom-scheme filter.
- [ ] Run focused Flutter tests and analyzer; verify GREEN.

### Task 4: Public web viewer and App Link association

**Files:**
- Create: `trip-share-web/index.html`
- Create: `trip-share-web/app.js`
- Create: `trip-share-web/styles.css`
- Create: `trip-share-web/config.example.js`
- Create: `trip-share-web/_redirects`
- Create: `trip-share-web/.well-known/assetlinks.json.example`
- Create: `trip-share-web/README.md`
- Test: `trip-share-web/app.test.mjs`

**Interfaces:**
- Loads `GET <SUPABASE_FUNCTION_URL>/trip-share/public/<token>`.
- Exposes `window.TRIP_SHARE_CONFIG.functionBaseUrl`.

- [ ] Write failing Node tests for token extraction, HTML escaping, public response validation and expired/revoked UI states.
- [ ] Run `node --test trip-share-web/app.test.mjs` and verify RED.
- [ ] Implement the dependency-free responsive viewer with day accordions, place cards, map links and Open-in-app/copy controls.
- [ ] Add Cloudflare Pages SPA fallback and example Digital Asset Links file for `com.hellovietnam.app`.
- [ ] Document deployment, environment replacement and both release/Play signing fingerprints.
- [ ] Run web tests and verify GREEN.

### Task 5: Regression and acceptance verification

**Files:**
- Modify only files required by failures caused by Tasks 1-4.

**Interfaces:**
- Consumes all interfaces above; produces a buildable public-sharing feature.

- [ ] Run all Deno tests under `backend/supabase/functions`.
- [ ] Run `flutter pub get`, focused Flutter tests, full `flutter test` and `flutter analyze` from `frontend`.
- [ ] Run web viewer Node tests.
- [ ] Inspect `git diff --check` and confirm no secrets, real tokens or signing fingerprints are committed.
- [ ] Record the remaining deployment-only inputs: chosen HTTPS host, Supabase Function deployment and release/Play certificate SHA-256 fingerprints.

## Self-review

- Spec coverage: create/view/copy/revoke/expiry/privacy/web/App Link are each assigned to Tasks 1-4.
- Security coverage: raw tokens are bearer credentials, hashes only are stored, public DTO is whitelisted and clone authorization is server-side.
- Type consistency: all clients use the same `token`, `allow_copy`, `expires_at`, `title`, `n_days`, `days` contract.
- No production domain, secret, share token or certificate fingerprint is embedded in source control.
