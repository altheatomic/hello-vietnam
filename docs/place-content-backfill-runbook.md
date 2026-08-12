# Place-content backfill runbook

This runbook is for the owner-approved continuation after Phase A. Phase A
does not reconcile migrations, call DeepSeek, create a database connection, or
apply/rollback content. Run commands from the repository root unless a command
explicitly changes into `cf_service` or `frontend`.

## Safety gates

Stop immediately and preserve the fsynced artifacts if any of these occur:

- the migration history cannot be reconciled and freshly replayed locally;
- the baseline is not exactly 1,533 places with the five expected province
  counts, one `vi`, and one `en` translation per place;
- a place, province, translation, or baseline hash is outside the manifest;
- a proposal lacks an explicit `approve`, or an `edit` does not pass all
  deterministic validators again;
- an apply transaction would exceed 50 places, a rollback hash conflicts, or
  any update returns zero or multiple rows;
- the provider, token, request, or owner-supplied cost budget would be
  exceeded;
- a secret appears in a log, artifact, diff, screenshot, or command history;
- resident set size reaches 1.5 GiB or the process begins swapping heavily.

Do not remediate unrelated RLS, image, rating, price, tag, freshness,
migration, or Trip Planner findings as part of this backfill.

## Migration reconciliation gate

`backend/supabase/` is the authoritative Supabase tree. Review the sanitized
preflight and compare local and remote history before changing anything:

```zsh
cd "$(git rev-parse --show-toplevel)"
npx supabase migration list --workdir backend
npx supabase test db --help
```

The Phase A preflight records known drift and that the historical migration
creating `place_translation` is absent locally. The owner must choose and
review a reconciliation strategy, prove a fresh local replay creates
`place_translation` and `place_localized_en`, then run the pgTAP contract
without migration repair. Do not run `db pull`, `db push`, migration repair,
remote DDL/DML, or deployment as part of this review step.

After the migration and code diff are reviewed, the owner may use the
repository's normal deployment workflow. Verify that only
`place_translation.detailed_description` is added and that the English view
uses `security_invoker=true` and preserves one row per place.

## Runtime secrets and budgets

Secrets and prices are owner-supplied at the approved execution gate only.
Do not put them in `.env.example`, committed files, shell transcripts, logs,
artifacts, or screenshots. Disable shell tracing before entering values:

```zsh
set +x
read -s DEEPSEEK_API_KEY
export DEEPSEEK_API_KEY
read -s DATABASE_URL
export DATABASE_URL
```

Supply the approved model and input/output prices through the pipeline's
runtime configuration. Prices are not inferred from memory and are never
hardcoded. Keep request, input-token, output-token, and estimated-cost caps
explicit and below the owner's approved budget. Never print the environment:

```zsh
export DEEPSEEK_CONTENT_MODEL='<OWNER_APPROVED_MODEL>'
export DEEPSEEK_INPUT_COST_PER_MILLION_USD='<OWNER_SUPPLIED_INPUT_PRICE>'
export DEEPSEEK_OUTPUT_COST_PER_MILLION_USD='<OWNER_SUPPLIED_OUTPUT_PRICE>'
export DEEPSEEK_MAX_REQUESTS='<OWNER_APPROVED_REQUEST_CAP>'
export DEEPSEEK_MAX_INPUT_TOKENS='<OWNER_APPROVED_INPUT_TOKEN_CAP>'
export DEEPSEEK_MAX_OUTPUT_TOKENS='<OWNER_APPROVED_OUTPUT_TOKEN_CAP>'
export DEEPSEEK_MAX_ESTIMATED_COST_USD='<OWNER_APPROVED_COST_CAP>'
```

Use a secret manager or an interactive shell for production-shaped values;
never pass secrets as command-line arguments. Phase A tests use only
`httpx.MockTransport` and must remain network-safe.

## Build and audit a run

Use a fresh run ID matching `YYYYMMDD-HHMMSS-<8 lowercase hex chars>`. The
read-only audit must produce exact counts before source collection:

```zsh
RUN_ID='<OWNER_CREATED_RUN_ID>'
(cd cf_service && python3 -m scripts.place_content_backfill.cli audit --scope approved-five --run-id "$RUN_ID")
(cd cf_service && python3 -m scripts.place_content_backfill.cli status --run-id "$RUN_ID")
```

Expected province counts are Hồ Chí Minh 539, Huế 201, Hà Nội 235, Quảng
Ninh 200, and Lâm Đồng 358. Include both inactive Lâm Đồng rows; do not
change status.

The owner must persist a deterministic 20-place pilot per province. Select
the lexicographically smallest place IDs from the immutable `baseline.jsonl`,
grouped by the five province UUIDs, and verify that the result contains
exactly 100 unique IDs before writing the pilot IDs to the manifest. A
streaming selection check from the repository root is:

```zsh
python3 - <<'PY'
import json
from collections import defaultdict
from pathlib import Path

run_id = '<OWNER_CREATED_RUN_ID>'
path = Path('.artifacts/place-content') / run_id / 'baseline.jsonl'
province_ids = (
    '094014a7-b8f6-481a-bbce-5ed6cdd457c5',
    'b5f3ef5e-dc49-4482-88e3-a8048cb32639',
    '3355c4a1-ccb1-46be-99e5-046d5f55b891',
    '8f9d18e3-7e24-4e36-bf50-a3823c1f78df',
    '49fa7ad8-b892-494d-a712-bb49802200c1',
)
by_province = defaultdict(list)
with path.open(encoding='utf-8') as handle:
    for line in handle:
        row = json.loads(line)
        by_province[row['province_id']].append(row['place_id'])
pilot = []
for province_id in province_ids:
    ids = sorted(by_province[province_id])
    if len(ids) < 20:
        raise SystemExit(f'pilot source is incomplete for {province_id}')
    pilot.extend(ids[:20])
if len(pilot) != 100 or len(set(pilot)) != 100:
    raise SystemExit('pilot selection is not exactly 100 unique places')
print('\n'.join(pilot))
PY
```

Collect, generate, validate, and export review artifacts only in bounded
fresh worker chunks. Keep the provider disabled until the migration, model,
prompt, and budget have been approved.

After the owner approves the model, prices, and caps, call the real provider
only from the owner terminal that holds `DEEPSEEK_API_KEY`. The explicit
confirmation flag is required; the supervisor launches fresh workers serially
and never places the secret in a command argument:

```zsh
(cd cf_service && python3 -m scripts.place_content_backfill.cli generate \
  --run-id "$RUN_ID" --pilot --confirm-provider)
(cd cf_service && python3 -m scripts.place_content_backfill.cli validate \
  --run-id "$RUN_ID" --pilot)
```

The generation gate fails before any request if the aggregate request,
input-token, output-token, or estimated-cost cap cannot cover the remaining
pilot. A 429/5xx retry consumes another request-cap unit; if the cap is
reached, stop and reconcile the run before retrying. Review every row in
`needs-review.csv`; deterministic validation does not approve content.

## Human review and the pilot gate

Inspect every pilot row, including rows that pass deterministic validation.
Import a CSV one row at a time with the exact command:

```zsh
(cd cf_service && python3 -m scripts.place_content_backfill.cli review-import \
  --run-id "$RUN_ID" \
  --file "../.artifacts/place-content/$RUN_ID/needs-review-reviewed.csv")
```

Only `approve`, `edit`, and `reject` are accepted. An edited row must pass all
validators again. Do not count rejected or unresolved rows toward the 100-row
pilot. Before applying, verify that `approved.jsonl` contains exactly 100
pilot places and that every place has an explicit human decision.

Apply in transactions of at most 50 places, then verify one `place`, one `vi`,
and one `en` row per place and confirm that the two inactive Lâm Đồng rows are
still inactive. The owner-approved command shape is:

```zsh
(cd cf_service && python3 -m scripts.place_content_backfill.cli apply \
  --run-id "$RUN_ID" --pilot --confirm)
(cd cf_service && python3 -m scripts.place_content_backfill.cli status \
  --run-id "$RUN_ID")
```

Clear or redeploy the service cache, or wait longer than the Recommend detail
cache TTL of 120 seconds, before checking two pilot places per province and a
non-pilot place whose long description is blank and must fall back to short
copy.

Prove rollback against the applied-content hash, not the original timestamp
hash, and preserve any later administrator edit:

```zsh
(cd cf_service && python3 -m scripts.place_content_backfill.cli rollback \
  --run-id "$RUN_ID" --pilot --confirm)
(cd cf_service && python3 -m scripts.place_content_backfill.cli status \
  --run-id "$RUN_ID")
(cd cf_service && python3 -m scripts.place_content_backfill.cli apply \
  --run-id "$RUN_ID" --pilot --confirm)
```

Repeat database counts, Recommend detail behavior, cache handling, and
artifact checks after reapply. Stop for owner approval before full rollout.

## Full rollout order and recovery

After the pilot passes and the owner explicitly approves continuation, process
provinces in this order:

1. Huế — 201
2. Hà Nội — 235
3. Quảng Ninh — 200
4. Lâm Đồng — 358
5. Hồ Chí Minh — 539

At each gate, require exact place/`vi`/`en` counts, zero unresolved review,
zero outside-scope changes, applied and rollback artifacts, Recommend detail
verification, and a clean applied-content hash check. If any gate fails,
stop that province, preserve artifacts, and use the constrained selector for
only the affected approved batch. Never roll back over a later admin edit.

The final expected total is 1,533 places, 1,533 `vi` translations, and 1,533
`en` translations. Record sanitized evidence for counts, source coverage,
prompt version, provider model, token totals, estimated cost, cache checks,
advisor results, and rollback artifact paths. Do not commit generated content
or run artifacts.

## Optional Windows appendix

PowerShell is supported only as an equivalent operator shell; keep paths
repository-relative and do not echo secret values:

```powershell
Set-Location (git rev-parse --show-toplevel)
$env:DEEPSEEK_CONTENT_MODEL = '<OWNER_APPROVED_MODEL>'
python3 -m scripts.place_content_backfill.cli status --run-id $env:RUN_ID
```
