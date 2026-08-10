# Place Content Provider Repair Design

## Context

Task 13 has a resumable 100-place pilot with one valid proposal already
checkpointed. DeepSeek V4 Flash authenticated and produced parseable JSON, but
three prompt-only adjustments still produced copy outside the deterministic
word limits: 50 words for a short field, then 88 and 163 words for long fields.
The current generator raises `ProviderOutputError` for the first invalid field,
which exits the fresh worker and stops the serial supervisor. Changing the
primary model alone would not remove that single-row failure mode.

This change remains inside the existing isolated worktree. Tests use
`httpx.MockTransport`; implementation and verification must make zero real
provider requests and no Supabase or production changes.

## Considered approaches

### 1. Replace Flash with Pro for every place

This is operationally simple, but Pro costs about 3.1 times as much as Flash and
does not provide a contract for exact whitespace word counts. A single invalid
Pro response would still stop the worker. This approach is rejected because it
changes cost without fixing the failure boundary.

### 2. Keep adjusting the Flash prompt

The prompt already targets narrower ranges and asks the model to count every
field. Three successive prompt-only changes moved the error rather than making
the output deterministic. A fourth prompt-only attempt would repeat the same
architectural weakness. This approach is rejected.

### 3. Flash primary with one bounded Pro repair

Flash remains the economical primary model. A parseable response is checked by
the existing deterministic rules. If one or more text fields fail only their
word-count limits, Pro receives one repair request containing the candidate,
structured validation issues, locked names, and the same untrusted evidence.
Only text fields named by those issues may be replaced; valid fields, fact IDs,
and locked names remain unchanged. Other parseable validation failures are
checkpointed for human review without a Pro request. The merged result is
validated again. This is the selected approach because Pro usage is limited to
word-count exceptions and deterministic code remains the acceptance authority.

## Runtime configuration and budget

Existing variables continue to configure the primary provider and global caps:

- `DEEPSEEK_CONTENT_MODEL`
- `DEEPSEEK_INPUT_COST_PER_MILLION_USD`
- `DEEPSEEK_OUTPUT_COST_PER_MILLION_USD`
- `DEEPSEEK_MAX_REQUESTS`
- `DEEPSEEK_MAX_INPUT_TOKENS`
- `DEEPSEEK_MAX_OUTPUT_TOKENS`
- `DEEPSEEK_MAX_ESTIMATED_COST_USD`

The repair provider requires explicit owner-supplied configuration:

- `DEEPSEEK_REPAIR_MODEL`
- `DEEPSEEK_REPAIR_INPUT_COST_PER_MILLION_USD`
- `DEEPSEEK_REPAIR_OUTPUT_COST_PER_MILLION_USD`
- `DEEPSEEK_MAX_REPAIR_REQUESTS`

The API key is shared only through the existing runtime environment and is
never placed in commands, logs, status files, or artifacts. A single shared
`BudgetState` accounts for primary and repair attempts, tokens, cost, and the
repair-request count. Each non-secret usage entry identifies its provider role
and model so resume can reconstruct those counters exactly. Each client
calculates actual cost using its own owner-supplied prices while obeying the
same global request, token, and cost ceilings. Repair dispatch also refuses
before exceeding the separate repair-request cap.

Preflight reserves one Flash request for every pending place and the configured
number of possible Pro repair requests. It uses conservative input estimates
and the existing 1,400-token output maximum. Exact resume caps will be reported
from the new preflight after tests pass; they will not be guessed or silently
increased during a real run.

## Generation and repair flow

For each place, serially:

1. Render the existing grounded generation prompt and call Flash once.
2. Parse the response and account for its attempt and usage before content
   acceptance.
3. Collect structured validation issues instead of discarding the candidate at
   the first error.
4. If there are no issues, checkpoint the proposal exactly as today.
5. If every issue is a text-field word-count issue and the repair allowance
   remains, call Pro once. The repair prompt includes only data needed to
   correct the named fields and treats all supplied evidence as untrusted data.
6. Merge only named text fields from the repair response into the original.
   Preserve valid fields, locked names, fact IDs, and source provenance.
7. Validate the merged result. A passing result becomes the proposal and
   records both provider roles in non-secret provenance.
8. If the repair is still invalid, checkpoint the best parseable candidate as a
   `review_only` proposal with a sanitized repair warning. The normal `validate`
   command exports its deterministic errors to `needs-review.csv`; no invalid
   proposal can enter `approved.jsonl` without a validator-passing human edit.

A parseable candidate with any non-word-count issue skips Pro and follows step
8 directly. This keeps unknown fact IDs, unsupported claims, and protected-name
problems under deterministic human review instead of asking a model to alter
provenance.

Malformed or empty primary output has no safe candidate to merge. Pro may make
one full regeneration using the original grounded prompt. If that also cannot
produce a parseable candidate, the worker writes sanitized failure status and
stops; it does not fabricate content or mark the place complete.

## Checkpoint and resume rules

Every provider call must remain budget-accounted even when its content is
malformed or fails validation. Usage for a failed primary call is fsynced to
`generation-budget.jsonl` before a repair call begins. Those entries include a
sanitized `provider_role` and `model`, and never request or response content.
The final successful or review-only proposal owns the final call's usage,
avoiding double counting when status reconstructs cumulative budget state.

An unexpected worker exception records the difference between its starting and
current budget state before exit. Existing completed proposal hashes remain
authoritative, so the current valid proposal is preserved and generation
resumes only the remaining 99 places.

Workers stay fresh, serial, and bounded to at most 25 places. No retry loop is
added around validation: there is at most one primary generation and one repair
request per place, in addition to the existing bounded HTTP retry behavior for
retryable transport responses.

## Error handling and safety

- Deterministic limits remain 20–45 words for short copy and 90–160 words for
  long copy.
- The implementation never truncates, pads, or automatically loosens content.
- HTTP authentication and non-retryable 4xx failures are not repaired.
- Existing bounded handling for 429/5xx remains subject to global caps.
- Unknown fact IDs, unsupported numeric claims, protected-name loss, and other
  validator findings remain review blockers.
- Provider candidates are artifacts only; this change does not apply data,
  alter Supabase, deploy, push, merge, or open a pull request.

## Tests and acceptance criteria

Tests are written first and must prove, with mocked HTTP only:

1. A valid Flash response makes no Pro request.
2. An out-of-range Flash field triggers exactly one Pro request.
3. Merge replaces only fields named by structured issues.
4. A valid repair produces a normal proposal with primary/repair provenance.
5. A still-invalid repair produces a `review_only` proposal that deterministic
   validation sends to `needs-review.csv`.
6. Empty or malformed Flash output can use one full Pro regeneration; a second
   malformed response fails without a third request.
7. Flash and Pro usage use their respective prices and share global caps.
8. The separate repair cap refuses before a Pro request.
9. Failed calls and retry attempts survive worker failure and resume without
   double counting.
10. Supervisor preflight includes the bounded repair allowance and preserves
    the existing completed proposal.
11. API keys never appear in subprocess arguments, status, or artifacts.

After targeted tests pass, run the full Python suite serially and rerun the
1,533-record memory regression with `/usr/bin/time -l`. Stop if RSS reaches
1.5 GiB. Do not make a real DeepSeek request as part of implementation or
verification.
