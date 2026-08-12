# Place Content Backfill Preflight

Date: 2026-08-10
Branch: `codex/phase-a-five-province-place-content-backfill`
Worktree: isolated worktree created from committed `HEAD`

## Tool versions

- Supabase CLI: `2.113.0`
- Python: `3.11.9`
- Flutter: `3.41.4` (Dart `3.11.1`)
- `npx supabase migration list --help`: available
- `npx supabase test db --help`: available

The clean-worktree baseline was verified before this file was created. The
local Python unit baseline passed 2 tests and the Flutter baseline passed 446
tests. Dependency setup and all verification commands were run serially.

## Supabase tree authority

`backend/supabase/` is authoritative for this feature because it contains the
active migration and pgTAP trees. The root `supabase/` directory is legacy and
was not edited.

The backend tree is not linked to a Supabase project. The read-only CLI check
therefore returned `LegacyProjectNotLinkedError`; no link, pull, repair, or
write operation was attempted. Remote migration metadata was obtained through
the read-only Supabase metadata tool instead.

## Remote schema facts

Read-only metadata and aggregate queries reported:

- `public.place` has nullable `detailed_description` at ordinal position 27.
- `public.place_translation` has `place_id`, `lang_code`, `name`,
  `description`, and timestamp fields, but no `detailed_description` column.
- `public.place_localized_en` currently has no `security_invoker` relation
  option and does not expose a detailed-description column.
- The scoped place counts are Hồ Chí Minh 539, Huế 201, Hà Nội 235,
  Quảng Ninh 200, and Lâm Đồng 358, totaling exactly 1,533.
- Every scoped place has one `vi` and one `en` translation (1,533 rows and
  1,533 distinct places for each language).
- Every scoped place has a blank place-level detailed description and an OSM
  identity matching `osm:(node|way|relation):<integer>`.
- Exactly two scoped rows are inactive, both in Lâm Đồng.

No place content, credentials, authorization headers, database URLs, or other
secrets were recorded.

## Migration drift

The authoritative local tree contains 59 migration files and ends at
`20260809000100_plan_component_tags`. The remote history returned 59 entries
and ends at `20260807000100_fix_data_freshness_source_selection`.

The remote history includes versions absent from the local authoritative tree:

- `20260729000100_planning_reference_rpc`
- `20260729000200_user_planning_data_rpc`
- `20260729000300_user_planning_query_indexes`
- `20260805000100_unify_planning_province_source`
- `20260805000200_backfill_plan_province_from_places`
- `20260806202843_content_report_status_workflow`

The local tree includes versions not present in the returned remote history,
including the duplicate/timestamp-divergent media and planning migrations
`20260722095930_manage_uploaded_media`,
`20260722162311_media_delete_tombstone`, the two
`20260801000100_*` files, `20260806090100_add_province_description_en`,
`20260806090200_plan_default_title_use_province`, and
`20260809000100_plan_component_tags`. This drift is recorded only; it was not
repaired.
## Security/advisor note

The read-only metadata advisor reported a pre-existing critical finding that
38 public tables have RLS disabled, including `public.place_translation`.
This is outside the Phase A feature scope. No RLS or unrelated security
remediation was applied.
