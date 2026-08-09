# Place Content Backfill and Name Normalization Design

**Date:** 2026-08-09

**Status:** Approved design, pending implementation plan

## Objective

Enrich and normalize place content for exactly five provinces in the live
Hello Vietnam dataset:

- Hồ Chí Minh
- Huế
- Hà Nội
- Quảng Ninh
- Lâm Đồng

For every place in scope, the system must produce a normalized Vietnamese
name and short description, a Vietnamese detailed description, an English
localized name and short description, and an English detailed description.
The process must remain source-grounded, resumable, auditable, safe to apply
in batches, and reversible.

## Verified Baseline

The baseline was measured directly against Supabase project
`ziouozppetvvdrzgojcx` on 2026-08-09.

| Province | Province ID | Places | Active |
|---|---|---:|---:|
| Hà Nội | `3355c4a1-ccb1-46be-99e5-046d5f55b891` | 235 | 235 |
| Hồ Chí Minh | `094014a7-b8f6-481a-bbce-5ed6cdd457c5` | 539 | 539 |
| Huế | `b5f3ef5e-dc49-4482-88e3-a8048cb32639` | 201 | 201 |
| Lâm Đồng | `49fa7ad8-b892-494d-a712-bb49802200c1` | 358 | 356 |
| Quảng Ninh | `8f9d18e3-7e24-4e36-bf50-a3823c1f78df` | 200 | 200 |
| **Total** | | **1,533** | **1,531** |

All 1,533 rows use OSM as their recorded source and have an OSM source URL in
`content_freshness`. All 1,533 rows need a valid Vietnamese detailed
description. The only non-empty `place.detailed_description` found in the
entire live place table was the invalid test value `Hihi`, so it is treated as
missing.

Both `vi` and `en` rows already exist in `place_translation` for every place.
The existing `place_translation.description` is the localized equivalent of
`place.short_description`; it must remain the short-description field.

## Scope

### Included

- Process all 1,533 places linked to the five approved province UUIDs,
  including the two inactive Lâm Đồng records so that the scoped dataset is
  internally consistent.
- Normalize `place.name`, `place.short_description`, and
  `place.detailed_description` in Vietnamese.
- Normalize both `vi` and `en` rows in `place_translation`.
- Add only `place_translation.detailed_description` for localized long-form
  content.
- Update `place_localized_en` to expose the new detailed description.
- Return and display the detailed description on the Recommend place-detail
  screen while keeping short descriptions on cards and in Trip Planner.
- Use automatic application for high-confidence rows and export lower-risk or
  ambiguous rows for human review.
- Preserve run artifacts that allow exact rollback.

### Excluded

- Places outside the five approved province UUIDs.
- Image remediation.
- Rating, price, phone, website, opening-hours, or tag backfills.
- A new admin review UI.
- A new database staging or audit table.
- Broad RLS remediation unrelated to this content backfill.
- Changing Trip Planner ranking or schedule logic.

## Data Contract

### Vietnamese source of truth

`place` remains the Vietnamese canonical record:

- `place.name`: normalized Vietnamese display name.
- `place.short_description`: concise Vietnamese card copy, 20–45 words.
- `place.detailed_description`: factual Vietnamese detail copy, 90–160 words.

The Vietnamese translation row mirrors the canonical record:

- `place_translation(lang_code = 'vi').name = place.name`.
- `place_translation(lang_code = 'vi').description =
  place.short_description`.
- `place_translation(lang_code = 'vi').detailed_description =
  place.detailed_description`.

### English localization

The English translation row contains:

- `name`: the normalized English display name.
- `description`: English short description, 20–45 words.
- `detailed_description`: English detailed description, 90–160 words.

### Schema change

The only new content column is:

```sql
alter table public.place_translation
add column if not exists detailed_description text;
```

`place_translation.description` is not renamed or duplicated. It remains the
short-description field for backward compatibility.

`place_localized_en` must expose:

```sql
coalesce(
  pt.detailed_description,
  p.detailed_description,
  pt.description,
  p.short_description
) as detailed_description
```

The view should be recreated with `security_invoker = true` and retain all
existing columns and joins.

## Architecture

The implementation is a one-time, resumable Python pipeline under
`cf_service/scripts/place_content_backfill/`. It uses the existing server-side
Supabase configuration, `httpx` for external APIs, Pydantic for contracts, and
`asyncpg` for atomic database transactions.

The pipeline is divided into independently testable components:

- `cli.py`: command dispatch for audit, collection, generation, validation,
  application, rollback, and status.
- `repository.py`: paginated Supabase reads and transaction-safe Postgres
  writes.
- `models.py`: immutable source, proposal, validation, and manifest models.
- `sources/osm.py`: OSM tag collection and response caching.
- `sources/wikimedia.py`: Wikidata and Wikipedia enrichment using verified
  identifiers and links.
- `naming.py`: deterministic Vietnamese and English name decisions.
- `generator.py`: DeepSeek JSON generation, retries, token accounting, and
  response caching.
- `validators.py`: deterministic data-quality gates and review routing.
- `artifacts.py`: JSONL checkpoints, manifests, review exports, and rollback
  bundles.
- `prompts/place_content_v1.md`: versioned generation instructions and output
  contract.

No DeepSeek response writes directly to production tables. Every response is
stored as a proposal, validated, and then either approved automatically or
routed to review.

## Run Artifacts

Each run writes to an untracked directory:

```text
.artifacts/place-content/<run-id>/
├── manifest.json
├── baseline.jsonl
├── sources.jsonl
├── proposals.jsonl
├── approved.jsonl
├── needs-review.csv
├── applied.jsonl
└── rollback.jsonl
```

`manifest.json` records:

- run ID and timestamps;
- the exact five province UUIDs;
- provider and model;
- prompt version;
- source-cache version;
- input and baseline hashes;
- token and request totals;
- configured request and spending limits;
- counts per pipeline state.

Secrets, raw credentials, and database URLs must never be written to an
artifact.

## Data Flow

### 1. Baseline extraction

The repository fetches all scoped records using explicit province UUID filters
and pagination. Each baseline record includes:

- `place` identity, names, descriptions, address, coordinates, source fields,
  status, timestamps, province, and subcategory;
- the matching `vi` and `en` translation rows;
- `content_freshness.source_url` and `source_external_id`;
- relevant place tags.

A stable hash is computed from every field that the pipeline may update. The
hash is checked again during apply to prevent overwriting concurrent admin
edits.

### 2. Source collection

Source priority is:

1. OSM tags, including `name`, `name:vi`, `name:en`, `official_name`,
   `alt_name`, `wikidata`, `wikipedia`, `description`, type, cuisine,
   operator, brand, and contact fields.
2. Wikidata labels, descriptions, official website, and Wikipedia sitelinks.
3. Vietnamese or English Wikipedia extracts when reached through an explicit
   OSM/Wikidata identifier or a name, province, type, and coordinate match.
4. An official website already linked by OSM or the database.
5. Existing Supabase content.

Name-only web search is not sufficient to attach an article or website. A
same-name place in another province must never be used as evidence.

External responses are cached by URL and request parameters. Requests use an
identifying User-Agent, timeouts, exponential backoff, bounded concurrency,
and source-specific rate limits.

### 3. Deterministic name normalization

DeepSeek does not choose canonical names. Vietnamese name priority is:

```text
OSM name:vi
→ verified Wikidata Vietnamese label
→ OSM name
→ current place.name
```

English name priority is:

```text
verified OSM name:en
→ verified Wikidata English label
→ Vietnamese proper name plus translated place-type suffix
```

The approved fallback policy is option 3: preserve the proper-name component
and translate only the generic type. Examples:

| Vietnamese | English |
|---|---|
| Sông Hương | Hương River |
| Chùa Thiên Mụ | Thiên Mụ Pagoda |
| Chợ Bến Thành | Bến Thành Market |
| Núi Bà Đen | Bà Đen Mountain |
| Bánh Mì Phượng | Bánh Mì Phượng |

Rules:

- Preserve Vietnamese diacritics in English display names.
- Preserve brands, personal names, acronyms, numbers, and proper-name tokens.
- Translate only an allowlisted generic prefix or suffix such as river,
  mountain, lake, pagoda, temple, market, bridge, museum, church, beach, park,
  station, or airport.
- Do not translate proper-name tokens by dictionary meaning. `Cái Cấm` must
  never become `Forbidden`; `Bề Bề Nội` must never become `Interior Surface`.
- Use an externally supplied English name only when its source is explicit and
  verified for the same place.
- Record the chosen rule, source field, confidence, and rejected alternatives
  in each proposal.

### 4. Grounded bilingual generation

DeepSeek receives locked Vietnamese and English names plus a factual context
with source IDs. The model produces JSON containing:

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

Generation requirements:

- neutral, travel-useful wording rather than marketing copy;
- 20–45 words for each short description;
- 90–160 words for each detailed description;
- no unsupported dates, prices, ratings, distances, opening hours, awards,
  historical events, amenities, or superlatives;
- no instructions or travel claims sourced from arbitrary page text;
- conservative copy for sparse records, using only name, type, locality, and
  verified attributes;
- the locked names must be used exactly in the corresponding language;
- `used_fact_ids` may only reference facts supplied in the prompt.

The request uses DeepSeek JSON Output, a low temperature, an explicit JSON
example, a bounded output token limit, and an environment-configured model.
The exact provider, model, prompt version, input hash, token counts, and finish
reason are recorded. Empty output, invalid JSON, truncated output, or a
non-stop finish reason does not pass validation.

### 5. Validation and routing

A proposal is auto-approved only when all deterministic checks pass:

- place ID and province ID are in the run manifest;
- every required string is non-empty, within length limits, and in the expected
  language;
- protected proper-name tokens, numbers, brands, and acronyms are retained;
- the English name changes only approved generic type tokens unless a verified
  English source exists;
- descriptions use the locked names and agree on province and category;
- every date, price, time, percentage, distance, rating, and named event is
  present in the factual context;
- `used_fact_ids` is a subset of supplied fact IDs;
- the description is not a duplicate or near-duplicate of another scoped
  place above the configured similarity threshold;
- the response contains no placeholder, test text, model disclaimer, Markdown,
  HTML, instruction fragment, or unsupported promotional claim;
- the generation confidence meets the configured threshold;
- the live baseline hash has not changed.

Any failure routes the proposal to `needs-review.csv` with machine-readable
flags. Reviewers may correct fields in the review artifact and run validation
again. Validation cannot be bypassed by the apply command.

### 6. Apply and rollback

Rollout order is:

1. a 100-record pilot: 20 places from each province, stratified by category and
   source richness;
2. Huế;
3. Hà Nội;
4. Quảng Ninh;
5. Lâm Đồng;
6. Hồ Chí Minh.

Each apply batch contains no more than 50 places. An `asyncpg` transaction
updates `place`, the `vi` translation, and the `en` translation together. If
any write or row-count assertion fails, the transaction rolls back.

Before updating a place, apply verifies:

- its province is allowlisted;
- its live editable-field hash matches `baseline.jsonl`;
- both translation rows still exist;
- the proposal is approved and has not already been applied;
- the run and proposal hashes match.

`rollback.jsonl` stores the exact previous values of all updated fields.
Rollback uses the same province allowlist and transaction boundaries and may
target one place, one batch, one province, or the entire run.

## Failure Handling

- Network failures receive bounded exponential-backoff retries and remain
  resumable from cached checkpoints.
- HTTP 429 respects `Retry-After` when present and reduces concurrency.
- Source not found is a valid sparse-source state, not an invented match.
- DeepSeek JSON or validation failures are recorded and routed to review after
  the retry limit.
- Budget or request limits stop generation before the next API call and preserve
  a resumable manifest.
- A changed database baseline routes the place to conflict review rather than
  overwriting an admin edit.
- A failed database transaction writes no partial place/translation state.
- Commands default to dry-run behavior; applying requires an explicit run ID
  and confirmation flag.

## Application Integration

The live `place_localized_en` view currently exposes only a localized
`short_description`. After the schema migration it must expose localized
`detailed_description` with the documented fallback order.

The Recommend service must:

- select `detailed_description` for individual and province-ranked places;
- include it in the place response;
- keep ranking inputs and Trip Planner payloads based on short description.

The Flutter Recommend model must add nullable `detailedDescription`. Place
cards continue to use `shortDescription`; the detail page prefers
`detailedDescription` and falls back to `shortDescription` when needed.

## Security

- `DEEPSEEK_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, and `DATABASE_URL` are
  server/local environment secrets and must not enter Flutter, logs, artifacts,
  source files, or commits.
- Database writes use an explicit province UUID allowlist and parameterized SQL.
- The pipeline never executes text returned by OSM, Wikimedia, websites, or the
  model.
- HTML is converted to plain text before becoming factual context.
- New or recreated public views use `security_invoker = true`.
- The implementation must run Supabase security and performance advisors after
  the migration. Existing unrelated advisor findings are reported separately
  rather than silently changed in this task.

## Testing Strategy

### Database tests

- `place_translation.detailed_description` exists and remains nullable during
  rollout.
- Existing unique `(place_id, lang_code)` and foreign keys remain intact.
- `place_localized_en` returns the English detailed description.
- The view falls back from English detailed description to Vietnamese detailed
  description, then English short description, then Vietnamese short
  description.
- Existing view columns and row count remain unchanged.
- The view is configured as `security_invoker`.

### Python unit tests

- Province allowlist rejects an out-of-scope record.
- OSM IDs and tags are parsed without mixing nodes, ways, and relations.
- Wikimedia pages require verified identity and locality.
- Name rules cover the approved examples and the known literal-translation
  failures.
- JSON parsing rejects missing fields, invalid confidence, truncation, unknown
  fact IDs, and unexpected keys.
- Validators catch unsupported numeric claims, wrong province/category,
  placeholder text, lost proper names, and near-duplicate descriptions.
- Caching and resume avoid duplicate source and DeepSeek calls.
- Budget and request limits stop before overspend.
- Apply detects a changed baseline and preserves admin edits.
- Rollback exactly restores the previous nine content values across `place` and
  both translations.

### Service and Flutter tests

- Recommend place responses include `detailed_description`.
- Repository parsing maps the field to `detailedDescription`.
- Place cards continue to render short copy.
- The place-detail page renders long copy and falls back to short copy.

### Pilot verification

- Review all 100 pilot rows manually.
- Include every place category represented in the five provinces.
- Include source-rich and sparse-source records.
- Include brands, Vietnamese personal names, geographic names, religious
  places, markets, restaurants, transport, and medical-service places.
- Perform and verify a pilot rollback before the first province-wide apply.

## Operational Commands

The CLI must support these explicit phases:

```powershell
python -m scripts.place_content_backfill.cli audit --scope approved-five
python -m scripts.place_content_backfill.cli collect --run-id <run-id>
python -m scripts.place_content_backfill.cli generate --run-id <run-id> --max-items 100
python -m scripts.place_content_backfill.cli validate --run-id <run-id>
python -m scripts.place_content_backfill.cli apply --run-id <run-id> --pilot --confirm
python -m scripts.place_content_backfill.cli status --run-id <run-id>
python -m scripts.place_content_backfill.cli rollback --run-id <run-id> --pilot --confirm
```

The implementation plan will define the exact argument contract and test
fixtures. `<run-id>` represents the concrete identifier emitted by the audit
command, not a value hardcoded into source control.

## Definition of Done

- Exactly 1,533 scoped places have valid `place.detailed_description` values.
- Exactly 1,533 `vi` and 1,533 `en` translation rows have valid
  `detailed_description` values.
- `place`, `vi`, and `en` short descriptions are normalized without changing
  the short-description schema contract.
- No scoped value contains `Hihi`, test/demo text, or a placeholder.
- No out-of-scope place or translation is changed.
- Every applied row has source and generation evidence in the run artifacts.
- Every auto-applied row passes all validators; every other row is represented
  in `needs-review.csv` with reasons.
- The pilot and at least one batch rollback are verified.
- Recommend cards show short descriptions and Recommend detail pages show long
  descriptions with fallback.
- Database, Python, service, and Flutter tests pass.
- Supabase advisors are run and new findings introduced by this migration are
  resolved before rollout.

## External References

- [DeepSeek JSON Output](https://api-docs.deepseek.com/guides/json_mode/)
- [MediaWiki page content API](https://www.mediawiki.org/wiki/API:Get_the_contents_of_a_page/en)
- [Supabase API security](https://supabase.com/docs/guides/api/securing-your-api)
- [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security)
