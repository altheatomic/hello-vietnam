# Budgeted Place Content Generation Design

## Context

The five-province backfill must populate Vietnamese and English detailed
descriptions for 1,533 places without running a local language model or relying
on Goong, Google Maps, or paid search grounding. This is a graduation project,
so the target is defensible, grounded content with bounded cost rather than
production-scale prose optimization.

The existing baseline is sufficient for a guaranteed fallback: all 1,533
places have a short description, address, and subcategory. The current
100-place pilot also has 729 OpenStreetMap facts, with at least two facts for
every place. The existing pipeline already provides immutable artifacts,
locked names, deterministic validation, human review, guarded Supabase writes,
fresh workers, and resumable provider accounting.

## Goals

- Generate reasonable `place.detailed_description` and
  `place_translation.detailed_description` values for all 1,533 places.
- Use free public evidence plus the owner's existing DeepSeek API account.
- Keep the complete rollout below a hard estimated-cost cap of USD 1.20.
- Guarantee progress when the provider is unavailable or a response is invalid.
- Preserve deterministic validation and explicit human approval before apply.

## Non-goals

- Do not use a local LLM, Ollama, Gemini, Goong, Google Maps, or Google Search.
- Do not ask a model to discover facts, select place names, or write directly to
  Supabase.
- Do not fabricate opening hours, prices, rankings, awards, historical dates,
  accessibility, or facilities that are absent from the evidence.
- Do not rewrite completed Phase A history. A new implementation-plan addendum
  will supersede only the generation portions of Task 13 and Phase C.

## Considered approaches

### Deterministic templates only

This has no provider cost and always completes, but 1,533 descriptions would be
more repetitive and would not demonstrate grounded language-model generation.
It remains the mandatory fallback rather than the primary path.

### Hosted free-tier model

A Gemini or Groq free tier could produce natural prose without local compute,
but it would add another account, key, provider contract, quota model, and data
handling policy. Free-tier availability can also change before the project is
assessed. This approach is rejected because the owner already has a working
DeepSeek integration and the projected DeepSeek cost is small.

### DeepSeek with deterministic fallback

DeepSeek V4 Flash produces the first candidate. V4 Pro may repair only eligible
word-count failures, within a separate cap. Deterministic templates handle
budget exhaustion, provider unavailability, malformed output, non-word-count
validation failures, or a failed repair. This is the selected approach because
it gives natural copy in the common case and guarantees bounded completion.

## Evidence sources

The content pipeline uses only data already captured by the audit and free,
identity-safe evidence collection:

- existing Vietnamese and English short descriptions;
- approved Vietnamese and English names;
- address, province, category, and subcategory;
- explicit OSM identity facts;
- explicitly linked Wikimedia facts when available;
- the official-site title when collection is owner-enabled.

Goong and routing APIs are unrelated to place-content generation and are not
called. A provider prompt receives only the selected place's public metadata
and source facts. It never receives API keys, database URLs, authorization
headers, user records, or unrelated artifact rows.

## Generation flow

For each place, serially in a fresh worker bounded to at most 25 places:

1. Load one baseline record, source snapshot, and deterministic name decision.
2. Render the existing grounded bilingual prompt and call
   `deepseek-v4-flash` in non-thinking JSON mode.
3. Account for the attempt, tokens, model, and estimated cost before accepting
   content.
4. Validate names, field lengths, fact IDs, numeric claims, unsupported claims,
   and provenance.
5. If every issue is an eligible word-count issue and the repair allowance
   remains, call `deepseek-v4-pro` once and merge only the named text fields.
6. If the primary candidate is invalid for another reason, the repair is still
   invalid, the response is malformed, authentication fails, a provider quota
   is reached, or any configured budget cap would be exceeded, build a
   deterministic fallback proposal without another provider call.
7. Validate the final proposal and append it immediately to the resumable
   artifacts.
8. Export every proposal for explicit human approval before any guarded apply.

There is no retry loop around content validation. Existing bounded transport
retries remain inside the global request-attempt cap. A completed proposal hash
continues to make resume idempotent.

## Deterministic fallback

The fallback generator consumes `BaselineRecord`, `SourceSnapshot`, and
`NameDecision` and returns the same strict `GeneratedContent` interface as the
provider path. It has no network dependency.

It uses versioned Vietnamese and English sentence banks for these broad groups:

- cultural and religious places;
- natural attractions;
- museums and historic attractions;
- markets, food, and shopping;
- transport facilities;
- accommodation and services;
- generic or unknown categories.

Each description starts from the existing short description, preserves the
locked name, and adds only statements supported by address, category, and
selected source facts. Neutral visitor guidance may be used to make the text
read naturally, but it must not imply unsourced hours, prices, amenities,
popularity, quality rankings, or historical facts. Sentence variants are
selected from a stable hash of the place ID so output is reproducible without
making every row identical.

Fallback output must satisfy the same whitespace-delimited limits as provider
output: 20–45 words for short fields and 90–160 words for detailed fields. It
records `generation_mode="deterministic-template"`, a template version, and the
fact IDs it used. Every fallback proposal is `review_only=true`, even when all
deterministic validators pass.

## Provider and budget configuration

The runtime key remains `DEEPSEEK_API_KEY`. It is supplied through the process
environment or an ignored local `.env` file and never committed. The tracked
`.env.example` contains placeholders only.

The owner-approved provider configuration is:

- primary model: `deepseek-v4-flash`;
- repair model: `deepseek-v4-pro`;
- full-rollout request-attempt cap: 1,687;
- full-rollout repair-attempt cap: 154;
- full-rollout input-token cap: 1,500,000;
- full-rollout output-token cap: 2,400,000;
- full-rollout estimated-cost cap: USD 1.20.

For the resumable 100-place pilot, the exact caps remain:

- request-attempt cap: 120;
- repair-attempt cap: 10;
- input-token cap: 110,000;
- output-token cap: 160,000;
- estimated-cost cap: USD 0.08.

The 100-place source snapshots render an estimated 67,208 primary input tokens.
Scaling that observed average to 1,533 places and reserving the 1,400-token
maximum output per place gives a Flash-only upper estimate of approximately
USD 0.75 at the approved prices. Reserving Pro repair for at most 10 percent of
places raises the projected upper estimate to approximately USD 1.11. The USD
1.20 hard cap is enforced from actual checkpointed usage; it is not permission
to increase any other cap automatically.

If granted or promotional balance exists, DeepSeek may deduct it first, but the
pipeline never assumes that API usage is free. It stops provider dispatch before
any cap is exceeded and completes remaining rows through the deterministic
fallback.

## Provenance and artifacts

Each proposal records enough non-secret provenance to explain how it was made:

- generation mode: provider, repaired-provider, or deterministic-template;
- provider model names when a provider was called;
- prompt or template version;
- selected source fact IDs and source snapshot hash;
- provider usage and budget-checkpoint ownership;
- `repair_used`, `sparse_source`, and `review_only` flags;
- deterministic proposal hash.

Provider request bodies and raw responses are not persisted. Existing artifact
secret rejection remains mandatory. Template fallback does not erase usage from
an earlier failed provider call.

## Validation and review

The existing validators remain the acceptance authority. In addition, fallback
tests must prove that output:

- preserves locked Vietnamese and English names;
- stays within all four word-count limits;
- uses only known fact IDs;
- introduces no unsupported numeric claims;
- avoids prohibited superlatives and unsourced factual patterns;
- is byte-for-byte reproducible for the same inputs;
- varies sentence selection across different place IDs;
- is always routed to human review.

No proposal enters `approved.jsonl` without an explicit imported human decision.
Edited rows are validated again. Apply, rollback, and reapply retain their
existing transaction, scope, hash, and row-count guards.

## Supabase impact

This design creates no new table, view, function, policy, or remote operation.
It uses the already planned nullable detailed-description column and existing
guarded repository writes. Therefore current Data API grant changes for newly
created tables do not alter this design. Migration replay, pgTAP, dry-run,
advisors, deployment, and production writes remain separate owner-approved
gates.

## Testing and acceptance

Implementation uses TDD and mocked provider transports. It must prove:

1. valid Flash output does not call Pro or the template fallback;
2. an eligible word-count failure can use exactly one bounded Pro repair;
3. malformed, non-grounded, over-budget, quota, and authentication failures use
   the deterministic fallback without additional provider calls;
4. fallback generation satisfies bilingual schema and validator rules;
5. failed provider usage remains checkpointed before fallback acceptance;
6. resume preserves completed proposal hashes and regenerates only stale rows;
7. the 100-place pilot preflight fits the exact pilot caps;
8. the 1,533-place projection fits the exact rollout caps;
9. API keys never appear in arguments, logs, statuses, or artifacts;
10. the full Python suite passes serially;
11. the 1,533-record regression passes under `/usr/bin/time -l` with maximum
    RSS below 1.5 GiB and zero requirement for a local model.

Real provider generation, human review, Supabase apply, rollback, deployment,
push, and pull-request creation are outside implementation verification and
remain explicit owner-approved operations.
