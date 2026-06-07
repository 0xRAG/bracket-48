# WCB-021: Results Scoring And Leaderboards

Status: In Progress
Owner: Codex
Priority: P1
Phase: MVP

## Problem

Sportmonks results now land in Supabase, but pool entries are not yet rescored from the normalized result tables.

## User Value

Players can see live standings in each group and compare bracket scores as the tournament progresses.

## Scope

- Convert `tournament_matches` and `group_standings` into the existing scoring engine input model.
- Add backend score tables for pool-entry totals and score events.
- Add a protected scoring Edge Function that can be run after each results sync.
- Add leaderboards to group detail views.
- Add a small latest-results/standings surface in the app.
- Add admin override workflow that triggers a rescore.

## Out Of Scope

- Cash prizes or rewards.
- Betting odds.
- Push notifications.

## Acceptance Criteria

- [x] Group-stage picks are scored from final `group_standings`.
- [x] Knockout picks are scored from final `tournament_matches` winners.
- [x] Scores are persisted by pool entry and phase.
- [x] Score events explain why points were awarded.
- [x] Group leaderboards sort by total points with deterministic tie handling.
- [ ] Admin result overrides cause affected scores to refresh.

## Implementation Notes

`008_bracket_scores.sql` adds `bracket_scores` and `bracket_score_events`.

`score-brackets` is a protected Edge Function with:

- `dry_run: true` default for safe score previews.
- `dry_run: false` for persisted score rows.
- `simulation` input for fake full-tournament tests before real matches are final.
- Groups tab reads `bracket_scores` and shows a compact top-three leaderboard preview per group.

Hosted smoke test:

- Synthetic perfect entry scored `78/78`.
- Synthetic partial entry scored `2/34`.
- Database-source dry-run currently returns `0` scores because hosted `pool_entries` is empty.

## Test Expectations

- Result-to-scoring-model transformation tests.
- Regression tests for group-stage third-place advancement scoring.
- Regression tests for knockout round scoring.
- RLS tests for group leaderboard visibility.

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Security And Integrity Judge:
