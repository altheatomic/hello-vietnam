# Admin Data Freshness English and Cron Alignment Design

## Goal

Make the Data Freshness area consistent with the English-only admin interface and move its daily checker into the same overnight operating window as collaborative-filtering retraining.

## Scope

- Replace every Vietnamese user-facing string in the Data Freshness admin page, cards, report dialog, empty states, tooltips, actions, and error messages with concise English copy.
- Keep database enum values and API contracts unchanged.
- Schedule `data-freshness-daily` at `15 19 * * *` UTC, which is 02:15 in Vietnam, while `daily_cf_retrain` remains at 02:00.
- Preserve the existing cron name and command.
- Update operator and defense documentation that states the former 09:15 Vietnam schedule.

## Architecture

The UI change remains presentation-only in the existing three Flutter files. Widget tests assert the English labels and ensure representative Vietnamese labels have disappeared. The database change is additive: a new Supabase migration calls `cron.schedule` with the existing job name, which replaces the existing schedule through the supported pg_cron API rather than directly updating `cron.job`.

## Error Handling and Safety

- No repository, domain model, Edge Function, batch size, or checker behavior changes.
- The migration catches missing pg_cron support and emits a warning, matching the existing migration style.
- The cron command remains `select public.invoke_data_freshness_cron()`.
- The 15-minute offset prevents Data Freshness and CF retraining from starting simultaneously.

## Verification

- Run the focused Flutter widget tests after first observing them fail against the Vietnamese UI.
- Add pgTAP assertions for the cron name, schedule, and command.
- Run static checks that all three admin Data Freshness presentation files contain no Vietnamese copy.
- Run Flutter format/analyze and the relevant Supabase migration checks available in the workspace.

