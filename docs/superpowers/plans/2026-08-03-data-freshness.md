# Data Freshness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a demo-ready hybrid freshness system that automatically expires dated events, detects changes in scraped content, queues risky changes for admin review, and accepts authenticated incorrect-information reports.

**Architecture:** Supabase remains the source of truth. Four generic freshness tables track provenance, checks, proposals, reports, and runs; an internal scheduled Edge Function evaluates sources through isolated adapters; a separate authenticated Edge Function serves user-report and admin-review actions. Flutter consumes freshness metadata in existing detail flows and adds a dedicated admin queue without letting crawlers overwrite editorial fields.

**Tech Stack:** PostgreSQL/Supabase migrations and pgTAP, Supabase Edge Functions on Deno/TypeScript, Python crawler utilities, Flutter/Dart, Supabase PostgREST/RPC, `pg_cron`, and `pg_net`.

## Global Constraints

- Keep `place`, `activity`, `culture`, `food`, and `local_products` as the canonical content tables.
- Use exactly these content statuses: `active`, `draft`, `hidden`, `expired`, `archived`.
- Use exactly these freshness statuses: `fresh`, `due`, `stale`, `needs_review`, `expired`.
- A scheduled checker run claims at most 50 due records.
- Business checks recur every 7 days, attraction/activity checks every 14 days, and evergreen checks every 30 days.
- Only `scheduled_event` records with `valid_until < now()` may be expired without admin review.
- Two valid consecutive `missing` source responses are required before creating `possibly_closed`; timeout and parser errors never increment the missing counter.
- Crawlers may propose operational fields but never overwrite editorial description, curated media, tags, or internal ratings.
- A user may submit at most three content reports per UTC day and may not have duplicate open reports for the same content and reason.
- Never hard-delete dynamic content in normal admin workflows; archive it and retain audit data.
- Do not expose the service-role key or checker secret to Flutter.

---

## File Map

### Database

- `backend/supabase/migrations/20260803000100_data_freshness.sql`: schema, indexes, RLS, backfill, atomic RPCs, cron trigger, and content status normalization.
- `backend/supabase/tests/data_freshness_test.sql`: pgTAP coverage for schema, transitions, RLS helpers, idempotency, and report limits.

### Crawler identity

- `backend/crawldata/source_identity.py`: canonical source identifiers and deterministic UUIDs.
- `backend/crawldata/test_source_identity.py`: standard-library unit tests.
- `backend/crawldata/stage1_seed_places.py`: reuse the common identity helper and explicit conflict target.
- `backend/crawldata/crawl_seed_data_fixed_v3.py`: persist source URL/type/external ID for activity, culture, and local-product output.

### Checker Edge Function

- `backend/supabase/functions/data-freshness-check/freshness_domain.ts`: types, hashes, field ownership, and pure transition rules.
- `backend/supabase/functions/data-freshness-check/freshness_domain_test.ts`: rule tests.
- `backend/supabase/functions/data-freshness-check/source_adapter.ts`: source adapter interface, host allowlist, and adapter registry.
- `backend/supabase/functions/data-freshness-check/osm_source_adapter.ts`: OSM element loader and normalizer.
- `backend/supabase/functions/data-freshness-check/wikipedia_source_adapter.ts`: Wikipedia page loader and metadata normalizer.
- `backend/supabase/functions/data-freshness-check/source_adapter_test.ts`: fake-fetch adapter tests.
- `backend/supabase/functions/data-freshness-check/data_freshness_gateway.ts`: Supabase persistence boundary.
- `backend/supabase/functions/data-freshness-check/data_freshness_handler.ts`: batch orchestration.
- `backend/supabase/functions/data-freshness-check/data_freshness_handler_test.ts`: fake-gateway orchestration tests.
- `backend/supabase/functions/data-freshness-check/index.ts`: secret validation and Deno entrypoint.
- `backend/supabase/functions/data-freshness-check/deno.json`: imports and test configuration.

### Authenticated freshness API

- `backend/supabase/functions/data-freshness/freshness_api_gateway.ts`: report, queue, overview, run, and review persistence.
- `backend/supabase/functions/data-freshness/freshness_api_handler.ts`: action parsing and role-aware dispatch.
- `backend/supabase/functions/data-freshness/freshness_api_handler_test.ts`: user/admin authorization and payload tests.
- `backend/supabase/functions/data-freshness/index.ts`: authenticated Edge Function entrypoint.
- `backend/supabase/functions/data-freshness/deno.json`: imports and test configuration.

### Eligibility consumers

- `backend/supabase/functions/explore/freshness_eligibility.ts`: pure Explore eligibility and warning mapping.
- `backend/supabase/functions/explore/freshness_eligibility_test.ts`: eligibility tests.
- `backend/supabase/functions/explore/explore_handler.ts`: load freshness metadata, filter lists, and return detail warnings.
- `cf_service/db/place_repository.py`: remove `needs_review` and `expired` IDs from itinerary candidate sets.
- `cf_service/test_data_freshness_eligibility.py`: fake-Supabase repository tests.

### Flutter user flow

- `frontend/lib/features/data_freshness/domain/content_freshness_models.dart`: freshness/report types.
- `frontend/lib/features/data_freshness/data/content_freshness_repository.dart`: `data-freshness` Edge Function client.
- `frontend/lib/features/data_freshness/presentation/content_report_sheet.dart`: authenticated content-specific report form.
- `frontend/lib/features/data_freshness/presentation/freshness_warning_banner.dart`: stale and review warnings.
- `frontend/lib/features/item_detail/domain/item_detail_models.dart`: detail freshness fields.
- `frontend/lib/features/item_detail/data/item_detail_repository.dart`: parse freshness metadata.
- `frontend/lib/features/item_detail/presentation/shared_item_detail_page.dart`: show warning and open the content report sheet.
- `frontend/lib/features/recommend/presentation/recommended_place_detail_page.dart`: pass the `place` report target.
- `frontend/lib/core/language/app_language.dart`: Vietnamese and English copy.
- `frontend/test/features/data_freshness/data/content_freshness_repository_test.dart`: API serialization tests.
- `frontend/test/features/data_freshness/presentation/content_report_sheet_test.dart`: validation, success, duplicate, and rate-limit UI tests.
- `frontend/test/features/item_detail/data/item_detail_repository_test.dart`: freshness response parsing.
- `frontend/test/features/item_detail/presentation/shared_item_detail_page_freshness_test.dart`: warning and target tests.

### Flutter admin flow

- `frontend/lib/features/admin/domain/admin_data_freshness.dart`: overview, queue, diff, report, and run models.
- `frontend/lib/features/admin/data/admin_data_freshness_repository.dart`: paged admin actions.
- `frontend/lib/features/admin/presentation/pages/admin_data_freshness_page.dart`: overview and four-tab queue.
- `frontend/lib/features/admin/presentation/widgets/admin_data_freshness_widgets.dart`: stat cards, diff card, action bar, and run row.
- `frontend/lib/app/router_admin_web.dart`: `/admin/data-freshness` route.
- `frontend/lib/features/admin/presentation/admin_shell.dart`: page title.
- `frontend/lib/features/admin/presentation/widgets/admin_sidebar.dart`: navigation destination.
- `frontend/lib/features/admin/data/admin_content_repository.dart`: archive instead of delete.
- `frontend/lib/features/admin/domain/admin_content.dart`: normalized status fields for managed tables.
- `frontend/test/features/admin/data/admin_data_freshness_repository_test.dart`: API and pagination tests.
- `frontend/test/features/admin/presentation/admin_data_freshness_page_test.dart`: tab, diff, and action-state tests.
- `frontend/test/features/admin/data/admin_content_repository_test.dart`: archive mutation test.
- `frontend/test/features/admin/presentation/admin_shell_test.dart`: route title and sidebar test.

---

### Task 1: Add the Freshness Schema and Atomic Database Contracts

**Files:**
- Create: `backend/supabase/migrations/20260803000100_data_freshness.sql`
- Create: `backend/supabase/tests/data_freshness_test.sql`

**Interfaces:**
- Produces: `claim_due_content_freshness(uuid, integer)`, `record_content_freshness_result(uuid, jsonb)`, `review_content_change_proposal(uuid, text, jsonb)`, `submit_content_report(text, uuid, text, text)`, and `request_content_freshness_check(text, uuid)` RPCs.
- Produces: `content_freshness`, `content_change_proposal`, `content_report`, and `content_update_run` tables consumed by every later task.

- [ ] **Step 1: Write the failing pgTAP schema and constraint assertions**

Create a transaction-based pgTAP test with these exact structural assertions:

```sql
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

select has_table('public', 'content_freshness');
select has_table('public', 'content_change_proposal');
select has_table('public', 'content_report');
select has_table('public', 'content_update_run');
select col_is_pk('public', 'content_freshness', 'id');
select has_function('public', 'claim_due_content_freshness', array['uuid', 'integer']);
select has_function('public', 'record_content_freshness_result', array['uuid', 'jsonb']);
select has_function('public', 'review_content_change_proposal', array['uuid', 'text', 'jsonb']);
select has_function('public', 'submit_content_report', array['text', 'uuid', 'text', 'text']);
select has_function('public', 'request_content_freshness_check', array['text', 'uuid']);
select has_column('public', 'activity', 'status');
select has_column('public', 'culture', 'status');
select has_column('public', 'local_products', 'status');
select has_column('public', 'food', 'status');

select * from finish();
rollback;
```

- [ ] **Step 2: Run the SQL test to confirm the new contracts do not exist**

Run from `backend`:

```powershell
npx supabase test db supabase/tests/data_freshness_test.sql
```

Expected: FAIL on the first missing freshness table.

- [ ] **Step 3: Implement tables, constraints, indexes, and timestamp triggers**

Use text checks instead of PostgreSQL enums so future migrations can add states. Include these exact keys and uniqueness rules:

```sql
create table public.content_freshness (
  id uuid primary key default gen_random_uuid(),
  content_type text not null check (content_type in ('place','activity','culture','food','local_product')),
  content_id uuid not null,
  source_type text not null,
  source_url text,
  source_external_id text,
  availability_type text not null check (availability_type in ('business','scheduled_event','evergreen','seasonal')),
  valid_from timestamptz,
  valid_until timestamptz,
  freshness_status text not null default 'due' check (freshness_status in ('fresh','due','stale','needs_review','expired')),
  last_checked_at timestamptz,
  last_verified_at timestamptz,
  next_check_at timestamptz not null default now(),
  source_hash text,
  consecutive_missing_count integer not null default 0 check (consecutive_missing_count >= 0),
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (content_type, content_id)
);

create unique index content_freshness_source_identity_idx
  on public.content_freshness (content_type, source_type, source_external_id)
  where source_external_id is not null;

create unique index content_change_proposal_one_pending_idx
  on public.content_change_proposal (freshness_id)
  where decision = 'pending';

create unique index content_report_one_open_reason_idx
  on public.content_report (reporter_user_id, content_type, content_id, reason)
  where status = 'open';
```

Add `status` and `updated_at` to content tables only when missing. Add a shared `set_row_updated_at()` trigger to all five content tables and the four new tables.

- [ ] **Step 4: Implement atomic RPCs and explicit content-type whitelists**

`claim_due_content_freshness` must use `FOR UPDATE SKIP LOCKED`, clamp the limit to `1..50`, update claimed rows to `due`, and return their complete source metadata. `record_content_freshness_result` must atomically update the freshness row, upsert one pending proposal when required, and update the associated run counters.

`review_content_change_proposal` must derive the reviewer from `auth.uid()`, verify `user_account.role = 'admin'`, lock the proposal, reject stale `before_data`, and update only these whitelisted source-owned columns:

```sql
array[
  'name', 'address', 'latitude', 'longitude', 'timespan', 'timeclose',
  'phone', 'website', 'status'
]
```

The RPC must never accept table or column names directly from the client. Select the target table and primary-key column with a `case content_type` expression.

`submit_content_report` must use `auth.uid()`, enforce three reports since `date_trunc('day', now() at time zone 'UTC')`, validate reason against `closed`, `wrong_hours`, `wrong_location`, `event_ended`, `other`, and return the inserted report UUID.

- [ ] **Step 5: Add backfill, RLS, grants, and cron invocation**

Backfill `place` rows with existing `source/source_place_id`; use `legacy_import` and `stale` for records without reconstructable provenance. Backfill the other four tables as `legacy_import/stale` without hiding them.

RLS policy matrix:

```text
content_freshness: authenticated read only through Edge Functions; no client writes
content_change_proposal: no client access
content_update_run: no client access
content_report: insert/select own rows; admin access through Edge Function
```

Create `invoke_data_freshness_cron()` using `pg_net`. Read `data_freshness_check_secret` from Vault and POST to `/functions/v1/data-freshness-check`; schedule `cron.schedule('data-freshness-daily', '15 2 * * *', 'select public.invoke_data_freshness_cron()')`. The function must warn and return safely when the Vault secret is absent.

- [ ] **Step 6: Expand pgTAP behavior coverage and run it**

Add assertions for one pending proposal, duplicate open-report rejection, fourth-report rejection, claim limit 50, missing counter preservation on error payloads, and event expiration. Run:

```powershell
npx supabase test db supabase/tests/data_freshness_test.sql
```

Expected: all planned pgTAP assertions pass and the transaction rolls back.

- [ ] **Step 7: Commit the database foundation**

```powershell
git add backend/supabase/migrations/20260803000100_data_freshness.sql backend/supabase/tests/data_freshness_test.sql
git commit -m "feat: add data freshness schema"
```

---

### Task 2: Make Scraped Source Identity Stable

**Files:**
- Create: `backend/crawldata/source_identity.py`
- Create: `backend/crawldata/test_source_identity.py`
- Modify: `backend/crawldata/stage1_seed_places.py`
- Modify: `backend/crawldata/crawl_seed_data_fixed_v3.py`

**Interfaces:**
- Produces: `canonical_source_url(url: str) -> str`, `source_external_id(source_type: str, raw_id: str) -> str`, and `deterministic_content_uuid(content_type: str, source_type: str, external_id: str) -> str`.
- Later checker adapters must emit the same canonical URL and external-ID format.

- [ ] **Step 1: Write deterministic identity tests**

```python
import unittest

from source_identity import (
    canonical_source_url,
    deterministic_content_uuid,
    source_external_id,
)


class SourceIdentityTest(unittest.TestCase):
    def test_wikipedia_url_discards_fragment_and_tracking_query(self):
        self.assertEqual(
            canonical_source_url("https://en.wikipedia.org/wiki/Hoi_An?utm_source=x#History"),
            "https://en.wikipedia.org/wiki/Hoi_An",
        )

    def test_same_identity_produces_same_uuid(self):
        external_id = source_external_id("wikipedia", "https://en.wikipedia.org/wiki/Hoi_An")
        first = deterministic_content_uuid("activity", "wikipedia", external_id)
        second = deterministic_content_uuid("activity", "wikipedia", external_id)
        self.assertEqual(first, second)

    def test_content_types_have_distinct_uuid_namespaces(self):
        external_id = source_external_id("wikipedia", "https://en.wikipedia.org/wiki/Hoi_An")
        self.assertNotEqual(
            deterministic_content_uuid("activity", "wikipedia", external_id),
            deterministic_content_uuid("culture", "wikipedia", external_id),
        )


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the identity test and verify it fails**

```powershell
python -m unittest test_source_identity.py -v
```

Run from `backend/crawldata`. Expected: import failure for `source_identity`.

- [ ] **Step 3: Implement canonical identity helpers**

Use one fixed namespace UUID committed in the module. Lowercase the scheme and hostname, drop fragments, remove `utm_*` query keys, retain content-bearing query keys, and strip a trailing slash except for the root URL.

`source_external_id("osm", "node:123")` returns `osm:node:123`. `source_external_id("wikipedia", canonical_url)` returns `wikipedia:` followed by the canonical URL. Callers pass the provider-native ID without an existing provider prefix.

```python
SOURCE_NAMESPACE = uuid.UUID("b179b2f4-f28e-5f19-ae6f-5d31eb4b7915")


def deterministic_content_uuid(content_type: str, source_type: str, external_id: str) -> str:
    token = f"{content_type.strip().lower()}:{source_type.strip().lower()}:{external_id.strip()}"
    return str(uuid.uuid5(SOURCE_NAMESPACE, token))
```

- [ ] **Step 4: Update OSM place seeding to use the shared helper**

Keep the existing OSM token format `osm:{element_type}:{element_id}` by calling `source_external_id("osm", f"{element_type}:{element_id}")`. Change the upsert call to name the conflict target explicitly:

```python
client.table("place").upsert(batch, on_conflict="id_place").execute()
```

Do not change the existing field ownership or OSM normalization in this step.

- [ ] **Step 5: Add provenance to activity, culture, and local-product rows**

Every record emitted by `crawl_seed_data_fixed_v3.py` must include `source_type`, `source_url`, and `source_external_id`. Replace `uuid.uuid4()` with `deterministic_content_uuid(content_type, source_type, external_id)`. Wikipedia list-page products must use their detail-page URL; if no detail page exists, use a stable composite external ID built from the canonical list URL, region heading, and normalized product name.

Add an explicit `--upsert` flag. Without it, the script remains export-only. With it, upsert the canonical content columns into the target content table using the deterministic primary key, then upsert provenance into `content_freshness` on `(content_type, content_id)`. Do not try to insert the three provenance-only fields into the content table.

- [ ] **Step 6: Run deterministic tests and two dry crawls**

```powershell
python -m unittest test_source_identity.py -v
python crawl_seed_data_fixed_v3.py --mode activity --output-dir output/identity-run-1
python crawl_seed_data_fixed_v3.py --mode activity --output-dir output/identity-run-2
```

Expected: unit tests pass; both JSON files contain the same IDs for the same source URLs. Do not commit generated output directories.

Run `--upsert` only against the non-production Supabase project after Task 1 has been applied; verify a second run leaves both content and freshness row counts unchanged.

- [ ] **Step 7: Commit crawler identity**

```powershell
git add backend/crawldata/source_identity.py backend/crawldata/test_source_identity.py backend/crawldata/stage1_seed_places.py backend/crawldata/crawl_seed_data_fixed_v3.py
git commit -m "fix: stabilize scraped content identity"
```

---

### Task 3: Implement the Pure Freshness Rule Engine

**Files:**
- Create: `backend/supabase/functions/data-freshness-check/freshness_domain.ts`
- Create: `backend/supabase/functions/data-freshness-check/freshness_domain_test.ts`
- Create: `backend/supabase/functions/data-freshness-check/deno.json`

**Interfaces:**
- Produces: `evaluateFreshness(input: FreshnessEvaluationInput): FreshnessDecision`.
- Produces: `sourceOwnedPatch(before, proposed): JsonObject`, `stableSourceHash(data): Promise<string>`, and `nextCheckAt(availabilityType, now): string`.
- Consumed by the checker handler and source adapters.

- [ ] **Step 1: Define rule tests before implementation**

Use a fixed `now = new Date("2026-08-03T02:15:00Z")`. Cover these exact cases:

```typescript
function fixtureFreshness(
  overrides: Partial<ContentFreshnessRow> = {},
): ContentFreshnessRow {
  return {
    id: "10000000-0000-4000-8000-000000000001",
    contentType: "place",
    contentId: "20000000-0000-4000-8000-000000000001",
    sourceType: "osm",
    sourceUrl: "https://www.openstreetmap.org/node/123",
    sourceExternalId: "osm:node:123",
    availabilityType: "business",
    validUntil: null,
    freshnessStatus: "due",
    sourceHash: "same",
    consecutiveMissingCount: 0,
    ...overrides,
  };
}

Deno.test("a past scheduled event auto expires", () => {
  const decision = evaluateFreshness({
    freshness: fixtureFreshness({
      availabilityType: "scheduled_event",
      validUntil: "2026-08-02T23:59:00Z",
    }),
    source: { outcome: "found", data: {}, sourceHash: "same" },
    currentContent: { status: "active" },
    now: new Date("2026-08-03T02:15:00Z"),
  });
  assertEquals(decision.kind, "auto_expire");
  assertEquals(decision.contentPatch, { status: "expired" });
});

Deno.test("an error never increments missing count", () => {
  const decision = evaluateFreshness({
    freshness: fixtureFreshness({ consecutiveMissingCount: 1 }),
    source: { outcome: "error", error: "timeout" },
    currentContent: { status: "active" },
    now: new Date("2026-08-03T02:15:00Z"),
  });
  assertEquals(decision.kind, "error");
  assertEquals(decision.consecutiveMissingCount, 1);
});
```

Also test unchanged source, first missing, second missing, recovery, risky address change, and editorial-field removal.

- [ ] **Step 2: Run the Deno test and verify it fails**

```powershell
npx -y deno test freshness_domain_test.ts
```

Expected: module-not-found failure for `freshness_domain.ts`.

- [ ] **Step 3: Implement exact domain contracts**

```typescript
export type FreshnessStatus = "fresh" | "due" | "stale" | "needs_review" | "expired";
export type AvailabilityType = "business" | "scheduled_event" | "evergreen" | "seasonal";
export type JsonObject = Record<string, unknown>;
export type ContentFreshnessRow = {
  id: string;
  contentType: "place" | "activity" | "culture" | "food" | "local_product";
  contentId: string;
  sourceType: string;
  sourceUrl: string | null;
  sourceExternalId: string | null;
  availabilityType: AvailabilityType;
  validUntil: string | null;
  freshnessStatus: FreshnessStatus;
  sourceHash: string | null;
  consecutiveMissingCount: number;
};
export type SourceResult =
  | { outcome: "found"; data: JsonObject; sourceHash: string }
  | { outcome: "missing" }
  | { outcome: "error"; error: string };

export type FreshnessDecision = {
  kind: "unchanged" | "proposal" | "first_missing" | "second_missing" | "recovered" | "auto_expire" | "error";
  freshnessStatus: FreshnessStatus;
  consecutiveMissingCount: number;
  contentPatch: JsonObject;
  proposedData: JsonObject;
  changedFields: string[];
  reason: string;
  nextCheckAt: string;
};
```

Allow source patches only for `name`, `address`, `latitude`, `longitude`, `timespan`, `timeclose`, `phone`, `website`, and source `status`. Sort JSON object keys recursively before SHA-256 hashing so field order never creates false changes.

- [ ] **Step 4: Implement transition order explicitly**

Evaluate in this order: event expiration, source error, source missing, source recovery, unchanged hash, changed source-owned fields. First missing returns `stale`; second valid missing returns `needs_review` plus reason `possibly_closed`; changed operational data returns `proposal`. An unchanged source sets `fresh`, clears `lastError`, and resets missing count.

- [ ] **Step 5: Run tests and type-check**

```powershell
npx -y deno test freshness_domain_test.ts
npx -y deno check freshness_domain.ts
```

Expected: every transition test passes and type-check succeeds.

- [ ] **Step 6: Commit the rule engine**

```powershell
git add backend/supabase/functions/data-freshness-check/freshness_domain.ts backend/supabase/functions/data-freshness-check/freshness_domain_test.ts backend/supabase/functions/data-freshness-check/deno.json
git commit -m "feat: add freshness transition rules"
```

---

### Task 4: Implement Allowlisted Source Adapters

**Files:**
- Create: `backend/supabase/functions/data-freshness-check/source_adapter.ts`
- Create: `backend/supabase/functions/data-freshness-check/osm_source_adapter.ts`
- Create: `backend/supabase/functions/data-freshness-check/wikipedia_source_adapter.ts`
- Create: `backend/supabase/functions/data-freshness-check/source_adapter_test.ts`

**Interfaces:**
- Consumes: `SourceResult`, `stableSourceHash`, and source identity formats from Task 2/3.
- Produces: `SourceAdapter.fetch(freshness, signal): Promise<SourceResult>` and `adapterFor(sourceType): SourceAdapter`.

- [ ] **Step 1: Write fake-fetch allowlist and classification tests**

```typescript
function fixtureWikipediaFreshness(
  sourceUrl = "https://en.wikipedia.org/wiki/Hoi_An",
): ContentFreshnessRow {
  return {
    id: "10000000-0000-4000-8000-000000000001",
    contentType: "activity",
    contentId: "20000000-0000-4000-8000-000000000001",
    sourceType: "wikipedia",
    sourceUrl,
    sourceExternalId: `wikipedia:${sourceUrl}`,
    availabilityType: "evergreen",
    validUntil: null,
    freshnessStatus: "due",
    sourceHash: null,
    consecutiveMissingCount: 0,
  };
}

function fixtureOsmFreshness(): ContentFreshnessRow {
  return {
    ...fixtureWikipediaFreshness("https://www.openstreetmap.org/node/123"),
    contentType: "place",
    sourceType: "osm",
    sourceExternalId: "osm:node:123",
    availabilityType: "business",
  };
}

Deno.test("rejects a source URL outside the configured allowlist", async () => {
  const adapter = new WikipediaSourceAdapter(async () => new Response("ok"));
  const result = await adapter.fetch(
    fixtureWikipediaFreshness("http://127.0.0.1/admin"),
    AbortSignal.timeout(100),
  );
  assertEquals(result, { outcome: "error", error: "Source host is not allowed." });
});

Deno.test("OSM 404 is a valid missing result", async () => {
  const adapter = new OsmSourceAdapter(async () => new Response("", { status: 404 }));
  const result = await adapter.fetch(fixtureOsmFreshness(), AbortSignal.timeout(100));
  assertEquals(result, { outcome: "missing" });
});
```

Also test timeout as `error`, Wikipedia page parsing, stable hashes, and OSM operational field normalization.

- [ ] **Step 2: Run adapter tests and verify they fail**

```powershell
npx -y deno test source_adapter_test.ts
```

Expected: missing adapter module failure.

- [ ] **Step 3: Define the adapter boundary and host allowlist**

```typescript
export interface SourceAdapter {
  fetch(freshness: ContentFreshnessRow, signal: AbortSignal): Promise<SourceResult>;
}

export const SOURCE_HOST_ALLOWLIST = new Set([
  "overpass-api.de",
  "www.openstreetmap.org",
  "en.wikipedia.org",
  "vi.wikipedia.org",
  "commons.wikimedia.org",
]);
```

Reject non-HTTPS URLs except the configured Overpass endpoint when explicitly supplied by server environment. Resolve no redirects to a host outside the allowlist.

- [ ] **Step 4: Implement OSM and Wikipedia normalization**

OSM must parse `osm:{node|way|relation}:{id}`, request that exact element, and normalize only operational fields. Wikipedia must fetch the canonical page URL, treat HTTP 404/410 as missing, and extract canonical title plus a deterministic text summary used for hashing. HTML structure changes and 429/5xx responses are errors, not missing.

- [ ] **Step 5: Add three-attempt retry with injected fetch**

The common fetch helper makes one initial call plus two retries for timeout, 429, and 5xx using 200 ms and 500 ms delays. It does not retry 404/410. Keep `fetch` and delay injectable so tests do not sleep or use the network.

- [ ] **Step 6: Run adapter and domain tests**

```powershell
npx -y deno test source_adapter_test.ts freshness_domain_test.ts
npx -y deno check source_adapter.ts osm_source_adapter.ts wikipedia_source_adapter.ts
```

Expected: all tests pass without external network access.

- [ ] **Step 7: Commit source adapters**

```powershell
git add backend/supabase/functions/data-freshness-check/source_adapter.ts backend/supabase/functions/data-freshness-check/osm_source_adapter.ts backend/supabase/functions/data-freshness-check/wikipedia_source_adapter.ts backend/supabase/functions/data-freshness-check/source_adapter_test.ts
git commit -m "feat: add freshness source adapters"
```

---

### Task 5: Build the Scheduled Checker Pipeline

**Files:**
- Create: `backend/supabase/functions/data-freshness-check/data_freshness_gateway.ts`
- Create: `backend/supabase/functions/data-freshness-check/data_freshness_handler.ts`
- Create: `backend/supabase/functions/data-freshness-check/data_freshness_handler_test.ts`
- Create: `backend/supabase/functions/data-freshness-check/index.ts`
- Modify: `backend/supabase/functions/data-freshness-check/deno.json`

**Interfaces:**
- Consumes: database RPCs from Task 1, adapters from Task 4, and `evaluateFreshness` from Task 3.
- Produces: internal POST endpoint authenticated by `x-data-freshness-secret`.

- [ ] **Step 1: Write fake-gateway batch tests**

Define a gateway with these exact methods:

```typescript
export interface DataFreshnessGateway {
  startRun(triggerType: "cron" | "admin" | "retry"): Promise<string>;
  claimDue(runId: string, limit: number): Promise<ContentFreshnessRow[]>;
  loadContent(row: ContentFreshnessRow): Promise<JsonObject>;
  recordResult(rowId: string, payload: JsonObject): Promise<void>;
  finishRun(runId: string, status: "completed" | "partial_failure" | "failed"): Promise<void>;
}
```

Test that the handler requests limit 50, records each item independently, marks partial failure when one adapter errors, and still processes later items.

- [ ] **Step 2: Run handler tests and verify they fail**

```powershell
npx -y deno test data_freshness_handler_test.ts
```

Expected: missing handler/gateway module failure.

- [ ] **Step 3: Implement the Supabase gateway**

Use service-role PostgREST only inside the Edge Function. Map `claim_due_content_freshness`, `record_content_freshness_result`, run insert/update, and whitelisted content-table reads into the gateway. Reject an unknown `content_type` before selecting a table.

- [ ] **Step 4: Implement batch orchestration**

For each claimed row: load current content, obtain the source result, evaluate rules, and persist one atomic result payload. Limit concurrent source calls to five. Always call `finishRun` in `finally`; use `partial_failure` when at least one item fails and at least one item completes.

- [ ] **Step 5: Protect the entrypoint with a constant-time secret comparison**

`index.ts` must require POST, compare `x-data-freshness-secret` with `DATA_FRESHNESS_CHECK_SECRET`, return 401 before creating the service client on mismatch, and pass `{ triggerType: "cron" }` to the handler. Do not accept source URLs or content IDs from this internal endpoint.

- [ ] **Step 6: Run and type-check the complete checker**

```powershell
npx -y deno test freshness_domain_test.ts source_adapter_test.ts data_freshness_handler_test.ts
npx -y deno check index.ts
```

Expected: all checker tests pass and the Edge Function type-checks.

- [ ] **Step 7: Commit the checker**

```powershell
git add backend/supabase/functions/data-freshness-check
git commit -m "feat: add scheduled freshness checker"
```

---

### Task 6: Add the Authenticated User and Admin Freshness API

**Files:**
- Create: `backend/supabase/functions/data-freshness/freshness_api_gateway.ts`
- Create: `backend/supabase/functions/data-freshness/freshness_api_handler.ts`
- Create: `backend/supabase/functions/data-freshness/freshness_api_handler_test.ts`
- Create: `backend/supabase/functions/data-freshness/index.ts`
- Create: `backend/supabase/functions/data-freshness/deno.json`

**Interfaces:**
- Produces user actions: `submitReport`, `listMyReports`.
- Produces admin actions: `adminGetOverview`, `adminListQueue`, `adminListReports`, `adminListRuns`, `adminReviewProposal`, `adminRequestCheck`.
- Consumed by both Flutter repositories.

- [ ] **Step 1: Write action and authorization tests**

```typescript
type JsonObject = Record<string, unknown>;

function requestFor(action: string, payload: JsonObject): Request {
  return new Request("http://localhost/data-freshness", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ action, ...payload }),
  });
}

class FakeFreshnessApiGateway implements FreshnessApiGateway {
  submittedReports: JsonObject[] = [];

  async submitReport(payload: JsonObject): Promise<JsonObject> {
    this.submittedReports.push(payload);
    return { id: "40000000-0000-4000-8000-000000000001" };
  }

  async listMyReports(): Promise<{ rows: JsonObject[]; totalCount: number }> {
    return { rows: [], totalCount: 0 };
  }

  async getOverview(): Promise<JsonObject> {
    return { due: 0, pending: 0, autoExpiredToday: 0, failedRuns: 0 };
  }

  async listQueue(): Promise<{ rows: JsonObject[]; totalCount: number }> {
    return { rows: [], totalCount: 0 };
  }

  async listReports(): Promise<{ rows: JsonObject[]; totalCount: number }> {
    return { rows: [], totalCount: 0 };
  }

  async listRuns(): Promise<{ rows: JsonObject[]; totalCount: number }> {
    return { rows: [], totalCount: 0 };
  }

  async reviewProposal(): Promise<JsonObject> {
    return { decision: "approved" };
  }

  async requestCheck(): Promise<void> {}
}

Deno.test("submitReport forwards the authenticated user payload", async () => {
  const gateway = new FakeFreshnessApiGateway();
  const response = await handleFreshnessApiRequest({
    request: requestFor("submitReport", {
      contentType: "place",
      contentId: "10000000-0000-4000-8000-000000000001",
      reason: "wrong_hours",
      note: "Closes at 21:00",
    }),
    userId: "20000000-0000-4000-8000-000000000001",
    isAdmin: false,
    gateway,
  });
  assertEquals(response.status, 200);
  assertEquals(gateway.submittedReports.length, 1);
});

Deno.test("a non-admin cannot review proposals", async () => {
  const response = await handleFreshnessApiRequest({
    request: requestFor("adminReviewProposal", {
      proposalId: "30000000-0000-4000-8000-000000000001",
      decision: "approved",
      appliedData: {},
    }),
    userId: "20000000-0000-4000-8000-000000000001",
    isAdmin: false,
    gateway: new FakeFreshnessApiGateway(),
  });
  assertEquals(response.status, 403);
});
```

Also test unknown action, invalid content type/reason, page size clamp `1..50`, stale proposal conflict 409, duplicate report 409, and daily report limit 429.

- [ ] **Step 2: Run the handler test and verify it fails**

```powershell
npx -y deno test freshness_api_handler_test.ts
```

Expected: missing API handler module failure.

- [ ] **Step 3: Implement typed payload parsing and response contracts**

Use a flat JSON request body containing `action` plus the action-specific fields. Return `{ report }`, `{ reports, totalCount }`, `{ overview }`, `{ proposals, totalCount }`, `{ runs, totalCount }`, or `{ proposal }`. Convert database unique violations to 409 and the daily limit exception to 429 with stable error codes `duplicate_report` and `report_rate_limited`.

Export this gateway contract from `freshness_api_gateway.ts`:

```typescript
export interface FreshnessApiGateway {
  submitReport(payload: JsonObject): Promise<JsonObject>;
  listMyReports(userId: string, page: number, pageSize: number): Promise<PagedRows>;
  getOverview(): Promise<JsonObject>;
  listQueue(page: number, pageSize: number): Promise<PagedRows>;
  listReports(page: number, pageSize: number): Promise<PagedRows>;
  listRuns(page: number, pageSize: number): Promise<PagedRows>;
  reviewProposal(proposalId: string, decision: "approved" | "rejected", appliedData: JsonObject): Promise<JsonObject>;
  requestCheck(contentType: string, contentId: string): Promise<void>;
}

export type PagedRows = { rows: JsonObject[]; totalCount: number };
```

- [ ] **Step 4: Implement the gateway and admin pagination**

Admin queue queries must select proposal, freshness, and report metadata using explicit columns, order pending items by user-report count then `detected_at`, and use inclusive Supabase ranges. Review actions call the atomic RPC from Task 1; request-check actions call `request_content_freshness_check`.

- [ ] **Step 5: Implement authenticated entrypoint and role lookup**

Follow `admin-dashboard/index.ts`: validate bearer token with the anon client, obtain `userId`, create a service client, read role once, then pass `isAdmin` into the pure handler. User actions require authentication but not admin role.

- [ ] **Step 6: Run tests and type-check**

```powershell
npx -y deno test freshness_api_handler_test.ts
npx -y deno check index.ts
```

Expected: authorization, validation, conflict, and pagination tests pass.

- [ ] **Step 7: Commit the API**

```powershell
git add backend/supabase/functions/data-freshness
git commit -m "feat: add data freshness API"
```

---

### Task 7: Enforce Freshness Eligibility in Explore and Trip Planning

**Files:**
- Create: `backend/supabase/functions/explore/freshness_eligibility.ts`
- Create: `backend/supabase/functions/explore/freshness_eligibility_test.ts`
- Modify: `backend/supabase/functions/explore/explore_handler.ts`
- Modify: `cf_service/db/place_repository.py`
- Create: `cf_service/test_data_freshness_eligibility.py`

**Interfaces:**
- Produces Explore detail fields: `freshnessStatus`, `lastVerifiedAt`, `freshnessWarning`.
- Produces Python `remove_freshness_ineligible_places(supabase, places) -> list[dict]`.
- Consumed by Flutter item details and the existing trip-planning candidate pipeline.

- [ ] **Step 1: Write pure Explore eligibility tests**

```typescript
Deno.test("stale content remains listable with a warning", () => {
  const result = resolveFreshnessEligibility({
    freshness_status: "stale",
    last_verified_at: "2026-07-01T00:00:00Z",
  });
  assertEquals(result.listable, true);
  assertEquals(result.plannerEligible, true);
  assertEquals(result.warning, "stale");
});

Deno.test("needs_review content is not listable or planner eligible", () => {
  const result = resolveFreshnessEligibility({ freshness_status: "needs_review" });
  assertEquals(result.listable, false);
  assertEquals(result.plannerEligible, false);
});
```

Also assert that `fresh`, `due`, and a missing legacy freshness row remain listable; `expired` is not listable.

- [ ] **Step 2: Write the Python filtering test**

Use `unittest` and a fake chainable Supabase query. Given three place rows and freshness rows marking one `needs_review` and one `expired`, assert only the fresh place remains. Assert `stale` remains eligible.

- [ ] **Step 3: Run both tests and verify they fail**

```powershell
npx -y deno test freshness_eligibility_test.ts
python test_data_freshness_eligibility.py
```

Expected: missing TypeScript module and missing Python helper failures.

- [ ] **Step 4: Load freshness in Explore without polymorphic joins**

After loading category rows, query `content_freshness` by `content_type` plus the loaded UUIDs, create a map keyed by `content_id`, and filter list/category responses with `resolveFreshnessEligibility`. Detail requests remain accessible for `needs_review`, but return warning metadata. Add `expired` to `isRenderableStatus` so expired content cannot be opened as a normal live item.

- [ ] **Step 5: Filter FastAPI place candidates after the existing required query**

Implement `remove_freshness_ineligible_places` as a second query to `content_freshness` for the returned place IDs. Remove only `needs_review` and `expired`; keep rows with no freshness record for migration compatibility. Call it in `fetch_places_required_filter` and `fetch_places_near_point` before caching or radius fallback decisions.

- [ ] **Step 6: Run eligibility and affected service tests**

```powershell
npx -y deno test freshness_eligibility_test.ts explore_behavior_test.ts explore_rating_test.ts
python test_data_freshness_eligibility.py
python test_module3_scheduling_rules.py
```

Expected: all tests pass; the scheduling evidence remains 8/8.

- [ ] **Step 7: Commit eligibility enforcement**

```powershell
git add backend/supabase/functions/explore/freshness_eligibility.ts backend/supabase/functions/explore/freshness_eligibility_test.ts backend/supabase/functions/explore/explore_handler.ts cf_service/db/place_repository.py cf_service/test_data_freshness_eligibility.py
git commit -m "feat: enforce content freshness eligibility"
```

---

### Task 8: Add User Freshness Warnings and Incorrect-Information Reports

**Files:**
- Create: `frontend/lib/features/data_freshness/domain/content_freshness_models.dart`
- Create: `frontend/lib/features/data_freshness/data/content_freshness_repository.dart`
- Create: `frontend/lib/features/data_freshness/presentation/content_report_sheet.dart`
- Create: `frontend/lib/features/data_freshness/presentation/freshness_warning_banner.dart`
- Modify: `frontend/lib/features/item_detail/domain/item_detail_models.dart`
- Modify: `frontend/lib/features/item_detail/data/item_detail_repository.dart`
- Modify: `frontend/lib/features/item_detail/presentation/shared_item_detail_page.dart`
- Modify: `frontend/lib/features/recommend/presentation/recommended_place_detail_page.dart`
- Modify: `frontend/lib/core/language/app_language.dart`
- Create: `frontend/test/features/data_freshness/data/content_freshness_repository_test.dart`
- Create: `frontend/test/features/data_freshness/presentation/content_report_sheet_test.dart`
- Modify: `frontend/test/features/item_detail/data/item_detail_repository_test.dart`
- Create: `frontend/test/features/item_detail/presentation/shared_item_detail_page_freshness_test.dart`

**Interfaces:**
- Consumes: `data-freshness` actions and Explore detail freshness fields.
- Produces: `ContentFreshnessRepository.submitReport({required FreshnessContentType contentType, required String contentId, required ContentReportReason reason, String? note})`, `showContentReportSheet(BuildContext context, {required FreshnessContentType contentType, required String contentId, required String contentName})`, and reusable `FreshnessWarningBanner`.

- [ ] **Step 1: Write repository serialization tests**

```dart
test('submitReport sends a content-specific payload', () async {
  final client = FakeSupabaseFunctionClient();
  final repository = ContentFreshnessRepository(functionClient: client);

  await repository.submitReport(
    contentType: FreshnessContentType.place,
    contentId: '10000000-0000-4000-8000-000000000001',
    reason: ContentReportReason.wrongHours,
    note: 'Closes at 21:00',
  );

  expect(client.lastBody, <String, Object?>{
    'action': 'submitReport',
    'contentType': 'place',
    'contentId': '10000000-0000-4000-8000-000000000001',
    'reason': 'wrong_hours',
    'note': 'Closes at 21:00',
  });
});
```

Test stable exception mapping for 401, `duplicate_report`, and `report_rate_limited`.

- [ ] **Step 2: Write UI tests for validation, stale warning, and place targeting**

Pump the report sheet, tap submit without a reason, and assert validation copy. Submit a valid reason and assert one repository call plus success state. Pump `SharedItemDetailPage` with `freshnessStatus = stale` and assert `FreshnessWarningBanner`. Pump `RecommendedPlaceDetailPage` with a fake place and assert the report target is `place`, not `activity`.

- [ ] **Step 3: Run the focused Flutter tests and verify they fail**

```powershell
flutter test test/features/data_freshness test/features/item_detail/presentation/shared_item_detail_page_freshness_test.dart test/features/item_detail/data/item_detail_repository_test.dart
```

Expected: missing freshness model/repository/widget failures.

- [ ] **Step 4: Implement immutable domain models and repository**

```dart
enum FreshnessContentType { place, activity, culture, food, localProduct }
enum ContentReportReason { closed, wrongHours, wrongLocation, eventEnded, other }
enum ContentFreshnessStatus { fresh, due, stale, needsReview, expired, unknown }

class ContentFreshnessInfo {
  const ContentFreshnessInfo({
    required this.status,
    this.lastVerifiedAt,
    this.warning,
  });
  final ContentFreshnessStatus status;
  final DateTime? lastVerifiedAt;
  final String? warning;
}
```

The repository must use `SupabaseFunctionClient.invokeJson` with `requireAuth: true` and never access freshness tables directly.

- [ ] **Step 5: Extend detail parsing and rendering**

Add `freshnessInfo` to `ItemDetail` and parse `freshnessStatus`, `lastVerifiedAt`, and `freshnessWarning`. Render a warning below the title for `stale` and `needsReview`. Use the existing report icon placement, but open `showContentReportSheet` with explicit content type and UUID instead of the generic feature report flow.

Add `reportContentType` to `SharedItemDetailPage`; derive it from `DetailCategory` by default. `RecommendedPlaceDetailPage` must pass `FreshnessContentType.place` because it currently reuses the activity detail category for layout.

- [ ] **Step 6: Add localized copy**

Add Vietnamese and English strings for the five reasons, stale warning, needs-review warning, duplicate report, daily limit, submit, success, and sign-in requirement. Keep the visible Vietnamese wording approved in the design: `Thông tin chưa được xác minh gần đây` and `Báo thông tin không chính xác`.

- [ ] **Step 7: Run focused tests, analyze, and format**

```powershell
dart format lib/features/data_freshness lib/features/item_detail lib/features/recommend/presentation/recommended_place_detail_page.dart lib/core/language/app_language.dart test/features/data_freshness test/features/item_detail
flutter test test/features/data_freshness test/features/item_detail
flutter analyze
```

Expected: tests pass and analyzer reports no issues.

- [ ] **Step 8: Commit the user flow**

```powershell
git add frontend/lib/features/data_freshness frontend/lib/features/item_detail frontend/lib/features/recommend/presentation/recommended_place_detail_page.dart frontend/lib/core/language/app_language.dart frontend/test/features/data_freshness frontend/test/features/item_detail
git commit -m "feat: add content freshness reports"
```

---

### Task 9: Add the Admin Data Freshness Queue and Archive Semantics

**Files:**
- Create: `frontend/lib/features/admin/domain/admin_data_freshness.dart`
- Create: `frontend/lib/features/admin/data/admin_data_freshness_repository.dart`
- Create: `frontend/lib/features/admin/presentation/pages/admin_data_freshness_page.dart`
- Create: `frontend/lib/features/admin/presentation/widgets/admin_data_freshness_widgets.dart`
- Modify: `frontend/lib/app/router_admin_web.dart`
- Modify: `frontend/lib/features/admin/presentation/admin_shell.dart`
- Modify: `frontend/lib/features/admin/presentation/widgets/admin_sidebar.dart`
- Modify: `frontend/lib/features/admin/data/admin_content_repository.dart`
- Modify: `frontend/lib/features/admin/domain/admin_content.dart`
- Modify: `frontend/lib/features/admin/domain/admin_food.dart`
- Modify: `frontend/lib/features/admin/data/admin_food_repository.dart`
- Modify: `frontend/lib/features/admin/presentation/pages/admin_food_page.dart`
- Modify: `backend/supabase/functions/admin/admin-food/admin_food_management_handler.ts`
- Create: `frontend/test/features/admin/data/admin_data_freshness_repository_test.dart`
- Create: `frontend/test/features/admin/presentation/admin_data_freshness_page_test.dart`
- Modify: `frontend/test/features/admin/data/admin_content_repository_test.dart`
- Modify: `frontend/test/features/admin/data/admin_food_repository_test.dart`
- Modify: `frontend/test/features/admin/presentation/admin_food_page_test.dart`
- Modify: `frontend/test/features/admin/presentation/admin_shell_test.dart`

**Interfaces:**
- Consumes: all `admin*` actions from Task 6.
- Produces: `/admin/data-freshness`, four queue tabs, diff review actions, and archive-based content removal.

- [ ] **Step 1: Write admin repository request tests**

```dart
test('reviewProposal sends selected applied fields', () async {
  final client = FakeSupabaseFunctionClient();
  final repository = AdminDataFreshnessRepository(functionClient: client);

  await repository.reviewProposal(
    proposalId: '10000000-0000-4000-8000-000000000001',
    decision: AdminFreshnessDecision.approved,
    appliedData: <String, Object?>{'timespan': '08:00', 'timeclose': '21:00'},
  );

  expect(client.lastBody?['action'], 'adminReviewProposal');
  expect(client.lastBody?['appliedData'], <String, Object?>{
    'timespan': '08:00',
    'timeclose': '21:00',
  });
});
```

Test overview decoding, queue pagination, report pagination, run history, check-now, 409 stale proposal, and action timeouts.

- [ ] **Step 2: Write admin page and archive tests**

Pump the page with a fake repository snapshot and assert the four tabs `Chờ duyệt`, `Báo sai`, `Dữ liệu stale`, `Lịch sử chạy`. Open a proposal and assert old/new values. Tap approve twice and assert only one repository call while loading. Test reject, check again, and edited applied fields.

Update the admin content repository test to assert removal sends:

```dart
await client.from('place').update(<String, Object?>{'status': 'archived'}).eq('id_place', record.id);
```

and never calls `.delete()`.

- [ ] **Step 3: Run focused admin tests and verify they fail**

```powershell
flutter test test/features/admin/data/admin_data_freshness_repository_test.dart test/features/admin/presentation/admin_data_freshness_page_test.dart test/features/admin/data/admin_content_repository_test.dart test/features/admin/presentation/admin_shell_test.dart
```

Expected: missing models/page/route and archive assertion failures.

- [ ] **Step 4: Implement models and repository with paged contracts**

Create immutable models for overview counts, proposal diff, user report, update run, and paged results. Parse timestamps as UTC. Use `SupabaseFunctionClient` for every action and keep page size at 20 in the UI.

- [ ] **Step 5: Build the approved four-tab admin page**

The header contains overview cards and `Kiểm tra ngay`. Queue cards show content name/type, source, reason, confidence, timestamp, and old/new values. Actions are `Xác nhận đã đóng`, `Giữ hoạt động`, `Kiểm tra lại`, and `Chỉnh sửa`. Disable every mutating button while its proposal is being processed and reload overview plus the active tab after success.

Reports show reporter count, reason, note, and content link. Runs show status, selected/checked/unchanged/proposal/auto-applied/failed counts and duration. Every tab has loading, empty, error, retry, and paged-next states.

- [ ] **Step 6: Register route, title, and sidebar destination**

Add `AdminWebRoutes.dataFreshness = '/admin/data-freshness'`, `AdminDataFreshnessPage`, title `Data Freshness`, and a sidebar destination using `Icons.update_rounded`. Update shell tests to assert route selection.

- [ ] **Step 7: Normalize managed content status and archive behavior**

Add status fields with `active`, `draft`, `hidden`, `expired`, `archived` options to activity, culture, and local-product configs. Change `AdminContentRepository.delete` to `archive`, update page confirmation copy from permanent deletion to archive, and keep an explicit hard-delete method absent from the Flutter client.

Food status is managed by extending the admin-food backend payload and Flutter `AdminFood` model with the same status options; default newly created food to `active`.

Change `deleteFood` in the backend handler to an update of the resolved status column with `archived`. Preserve `deleteFoodType` because it manages taxonomy rather than dynamic travel content. Add repository and page tests that assert food archive copy and that archived food disappears from the default active list.

- [ ] **Step 8: Run admin tests, format, and analyze**

```powershell
dart format lib/features/admin lib/app/router_admin_web.dart test/features/admin
flutter test test/features/admin
flutter analyze
```

Expected: all admin tests pass and analyzer reports no issues.

- [ ] **Step 9: Commit admin review tooling**

```powershell
git add frontend/lib/features/admin frontend/lib/app/router_admin_web.dart frontend/test/features/admin backend/supabase/functions/admin/admin-food/admin_food_management_handler.ts
git commit -m "feat: add admin freshness review queue"
```

---

### Task 10: Verify the Complete Demo Workflow and Document Operations

**Files:**
- Create: `docs/data-freshness-operations.md`
- Modify: `README.md`
- Modify: `Report.docx.md`
- Test: all files created or modified in Tasks 1–9

**Interfaces:**
- Consumes: deployed migrations, both Edge Functions, Flutter user/admin flows, and checker secrets.
- Produces: exact setup, manual-run, demo, rollback, and evidence instructions for project handoff.

- [ ] **Step 1: Write the operations document before final verification**

Document these exact setup inputs and commands:

```text
Supabase Vault secret: data_freshness_check_secret
Edge Function secret: DATA_FRESHNESS_CHECK_SECRET
Edge Functions: data-freshness-check, data-freshness
Cron job: data-freshness-daily at 02:15 UTC
Manual admin action: adminRequestCheck
Default batch size: 50
```

Include how to inspect `content_update_run`, retry failed rows by setting `next_check_at = now()`, disable the cron without deleting data, and restore archived content by setting `status = active` after verification.

- [ ] **Step 2: Add the six approved demo scenarios to the report**

Update the data section in `Report.docx.md` with the hybrid strategy and evidence sequence: automatic event expiry, two valid missing checks, admin archive, user wrong-hours report, timeout safety, and duplicate-free crawler rerun. Do not claim production-grade multi-source verification.

- [ ] **Step 3: Run database tests**

```powershell
cd backend
npx supabase test db --file supabase/tests/data_freshness_test.sql
```

Expected: all data-freshness pgTAP assertions pass.

- [ ] **Step 4: Run every Edge Function test and type-check both entrypoints**

```powershell
cd backend/supabase/functions/data-freshness-check
npx -y deno test freshness_domain_test.ts source_adapter_test.ts data_freshness_handler_test.ts
npx -y deno check index.ts
cd ../data-freshness
npx -y deno test freshness_api_handler_test.ts
npx -y deno check index.ts
cd ../explore
npx -y deno test freshness_eligibility_test.ts explore_behavior_test.ts explore_rating_test.ts
```

Expected: all Deno tests and checks pass.

- [ ] **Step 5: Run Python crawler and planning tests**

```powershell
cd backend/crawldata
python -m unittest test_source_identity.py -v
cd ../../cf_service
python test_data_freshness_eligibility.py
python test_module3_scheduling_rules.py
```

Expected: identity tests pass, eligibility script passes, and scheduling evidence remains 8/8.

- [ ] **Step 6: Run the complete Flutter verification**

```powershell
cd frontend
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Expected: formatting is clean, analyzer reports no issues, and the full Flutter suite passes.

- [ ] **Step 7: Execute the deployed smoke-test sequence**

In a non-production Supabase project, create fixtures with UUIDs reserved for the demo. Verify:

1. A past `scheduled_event` becomes `expired` with `auto_applied` audit.
2. One valid missing response yields `stale` and leaves content active.
3. A second valid missing response yields one `possibly_closed` proposal.
4. Admin approval archives content and removes it from Explore/Trip Planner.
5. A user report appears in the admin reports tab without changing content.
6. A forced adapter timeout records an error without changing hash or missing count.
7. Two identical crawler imports leave the content row count unchanged.

Capture SQL result rows and screenshots for the project report; do not commit secrets or real user identifiers.

- [ ] **Step 8: Review the final diff against the design spec**

```powershell
git diff --check
git status --short
rg -n "Not implemented|UnsupportedError" backend/supabase/functions/data-freshness-check backend/supabase/functions/data-freshness frontend/lib/features/data_freshness docs/data-freshness-operations.md
```

Expected: no whitespace errors, no implementation placeholders, and only intended files are changed.

- [ ] **Step 9: Commit operational documentation**

```powershell
git add docs/data-freshness-operations.md README.md Report.docx.md
git commit -m "docs: document data freshness operations"
```

---

## Completion Criteria

- All four freshness tables and five RPCs exist with RLS and uniqueness constraints.
- Daily cron can invoke an authenticated checker and safely handles a missing secret.
- Re-running each supported crawler preserves content identity.
- Automatic expiry, unchanged, changed, first-missing, second-missing, recovery, and error transitions are tested.
- Admin can review diffs, edit selected values, approve, reject, archive, and request recheck.
- Authenticated users can submit content-specific reports with duplicate and daily-rate protection.
- Explore and Trip Planner consistently exclude `needs_review`, `expired`, `hidden`, and `archived` content while retaining stale content with a warning.
- Flutter user and admin interfaces match the approved flows and have loading, empty, error, and disabled-action states.
- SQL, Deno, Python, Flutter, formatting, and analyzer checks pass.
- Operations and report documentation explain setup, demo evidence, recovery, and limitations without exposing secrets.
