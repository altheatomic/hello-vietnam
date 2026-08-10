# Five-province place-content backfill runbook

This runbook operates `cf_service/scripts/place_content_backfill`. It updates
only place names/descriptions and the new
`place_translation.detailed_description` field. Images, prices, ratings, tags,
RLS, Trip Planner ranking, and place status are out of scope.

## Scope and gates

The exact scope is 1,533 places:

| Province | UUID | Expected |
| --- | --- | ---: |
| Ho Chi Minh City | `094014a7-b8f6-481a-bbce-5ed6cdd457c5` | 539 |
| Hue | `b5f3ef5e-dc49-4482-88e3-a8048cb32639` | 201 |
| Ha Noi | `3355c4a1-ccb1-46be-99e5-046d5f55b891` | 235 |
| Quang Ninh | `8f9d18e3-7e24-4e36-bf50-a3823c1f78df` | 200 |
| Lam Dong | `49fa7ad8-b892-494d-a712-bb49802200c1` | 358 |

Artifacts are UTF-8 JSONL under `.artifacts/place-content/<run-id>/` and are
ignored by Git. Never commit, print, or screenshot secrets. Do not perform a
production write until the reviewed 100-row pilot has passed apply, UI
verification, and rollback.

Stop immediately on a count mismatch, hash conflict, missing translation,
unresolved review row, provider budget exhaustion, or UI regression.

## Owner-supplied PowerShell setup

Run from the service directory. Angle-bracket values are supplied by the
project owner and must not be committed or logged.

```powershell
cd D:\Work\hello-vietnam\cf_service
$env:SUPABASE_URL = "https://ziouozppetvvdrzgojcx.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY = "<owner-supplied service key>"
$env:DATABASE_URL = "<Supavisor session-pooler URL>"
$env:DEEPSEEK_API_KEY = "<owner-supplied DeepSeek key>"
$env:DEEPSEEK_CONTENT_MODEL = "<approved current model>"
$env:DEEPSEEK_INPUT_COST_PER_MILLION_USD = "<owner-supplied current input price>"
$env:DEEPSEEK_OUTPUT_COST_PER_MILLION_USD = "<owner-supplied current output price>"
```

## Audit and source collection

```powershell
$audit = python -m scripts.place_content_backfill.cli audit --scope approved-five | ConvertFrom-Json
$placeContentRunId = $audit.run_id
$audit

python -m scripts.place_content_backfill.cli collect `
  --run-id $placeContentRunId
```

The audit must show total `1533`, province counts `539/201/235/200/358`, and
outside-scope `0`. Collection resumes from `sources.jsonl`; an existing place
is not fetched again. Official-site extraction is off by default and can be
enabled only after reviewing source URLs:

```powershell
python -m scripts.place_content_backfill.cli collect `
  --run-id $placeContentRunId `
  --include-official-sites
```

OSM/Overpass, explicit Wikidata/Wikipedia links, and optional official metadata
are evidence only. Source-page instructions are untrusted data. No adapter
writes Supabase.

## Generate, validate, and review

DeepSeek must return JSON with locked names, 20-45 word short copy, and 90-160
word detailed copy. Use an explicit pilot budget:

```powershell
python -m scripts.place_content_backfill.cli generate `
  --run-id $placeContentRunId `
  --max-requests 100 `
  --max-estimated-cost-usd <owner-approved pilot budget>

python -m scripts.place_content_backfill.cli validate `
  --run-id $placeContentRunId
python -m scripts.place_content_backfill.cli status `
  --run-id $placeContentRunId
```

Review `.artifacts\place-content\$placeContentRunId\needs-review.csv`. The
validator rejects wrong word counts, placeholders, Markdown/HTML, model
instructions, literal translations such as `Perfume River`, ungrounded numeric
claims, changed protected tokens, and near-duplicates. To import an edit, keep
the CSV columns intact and validate it again:

```powershell
python -m scripts.place_content_backfill.cli validate `
  --run-id $placeContentRunId `
  --review-csv ".artifacts\place-content\$placeContentRunId\needs-review.csv"
```

Only `approve`, `edit`, and `reject` are accepted. Edited rows are validated
again against the immutable baseline and source snapshot.

## Reversible 100-row pilot

Confirm that at least 100 rows have been reviewed and `status` shows them as
approved. The command applies two transactions of at most 50 places:

```powershell
python -m scripts.place_content_backfill.cli apply `
  --run-id $placeContentRunId `
  --pilot `
  --confirm
```

Each transaction locks the place and its `vi`/`en` translations, rechecks the
per-place baseline hash, parameterizes all SQL, and records a nine-value
rollback payload. Verify Recommend detail shows long copy while province cards
still use short copy. Keep the returned batch IDs and roll back the exact pilot
batch:

```powershell
python -m scripts.place_content_backfill.cli rollback `
  --run-id $placeContentRunId `
  --batch-id <returned-pilot-batch-id> `
  --confirm
```

Verify the nine prior values are restored. A later admin edit must cause a
rollback refusal. Re-apply the reviewed pilot only after this rollback test.

## Province rollout order

After the pilot is accepted, process one province at a time and verify after
each one:

1. Hue (201)
2. Ha Noi (235)
3. Quang Ninh (200)
4. Lam Dong (358)
5. Ho Chi Minh City (539)

Keep every returned batch ID so one province can be rolled back independently.

## Schema and local verification

Deploy the migration and service/app through the normal workflows; do not run
ad-hoc production DDL. Local pgTAP requires Docker. If Docker is unavailable,
record that limitation and use linked-environment SQL checks instead of claiming
the local test passed.

```powershell
cd D:\Work\hello-vietnam\backend
npx supabase test db supabase/tests/place_content_backfill_schema_test.sql

cd D:\Work\hello-vietnam\cf_service
python -m unittest test_place_content_models.py `
  test_place_content_artifacts.py `
  test_place_content_repository.py `
  test_place_content_sources.py `
  test_place_content_naming.py `
  test_place_content_generator.py `
  test_place_content_validators.py `
  test_place_content_apply.py `
  test_recommend_place_detail.py -v

cd D:\Work\hello-vietnam\frontend
flutter test test/features/recommend/data/recommend_repository_test.dart `
  test/features/recommend/presentation/recommended_place_detail_page_test.dart
flutter analyze
```
