# WCB-020: Live Results Provider

Status: Backlog
Owner: Unassigned
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

- [ ] Provider selected with pricing and license review.
- [ ] Backend stores provider fixture/result IDs.
- [ ] Results polling runs from trusted backend context.
- [ ] Group-stage standings can be derived or stored.
- [ ] Knockout winners update internal result records.
- [ ] Scoring engine runs from internal result model.
- [ ] Admin can correct provider errors.

## Test Expectations

- Provider payload fixture tests.
- Result normalization tests.
- Scoring regression tests.
- Backend RLS tests.

## Design Notes

Keep live data informational and non-gambling. Do not display odds.

## Data And API Notes

Current recommendation: evaluate Sportmonks first, with API-Football as backup comparison and Sportradar as enterprise fallback.

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
