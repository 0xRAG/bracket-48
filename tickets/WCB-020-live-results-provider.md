# WCB-020: Live Results Provider

Status: Done
Owner: Codex
Priority: P1
Phase: MVP

## Problem

Bracket scoring needs official or reliable match results, standings, and knockout winners.

## User Value

Users can see group standings, completed match results, and scored brackets without manual app updates.

## Scope

- Select sports-data provider.
- Map provider team and match IDs to internal IDs.
- Poll fixtures/results through backend jobs.
- Normalize match statuses and final scores.
- Rescore brackets from normalized internal results.
- Add admin correction fallback.

## Out Of Scope

- Betting odds.
- Player-level stats.
- Live commentary.
- Push notifications.

## Acceptance Criteria

- [x] Provider selected with pricing and license review.
- [x] Backend stores provider fixture/result IDs.
- [x] Results polling runs from trusted backend context.
- [x] Group-stage standings can be derived or stored.
- [x] Knockout winners update internal result records.
- [x] Scoring engine runs from internal result model.
- [x] Admin can correct provider errors.

## Test Expectations

- [x] Provider payload fixture tests.
- [x] Result normalization tests.
- [x] Scoring regression tests.
- [x] Backend RLS tests.

## Design Notes

Keep live data informational and non-gambling. Do not display odds.

## Data And API Notes

Sportmonks selected for MVP. The API token is stored as a Supabase Edge Function secret. Normalized tables were added for provider teams, tournament matches, group standings, sync run audits, and result overrides.

Confirmed provider constants:

- League ID: `732`
- Season ID: `26618`
- Group stage ID: `77478590`

The first Edge Function is `sync-sportmonks-results`. It supports `all`, `fixtures`, `standings`, and `live` sync modes.

Hosted Cron is active:

- `bracket48-results-live-sync`: `*/5 * * * *`
- `bracket48-results-standings-sync`: `22 * * * *`
- `bracket48-results-full-sync`: `37 */6 * * *`

Successful syncs invoke `score-brackets` automatically.

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

See `AppStore/sports-data-api-evaluation.md`.

Closed after Sportmonks selection, hosted result ingestion, normalized result tables, and scheduled Supabase sync jobs were deployed and verified.

Added Deno regression tests for Sportmonks fixture/standing normalization in `Backend/supabase/functions/_shared/sportmonks-normalization_test.ts`.
