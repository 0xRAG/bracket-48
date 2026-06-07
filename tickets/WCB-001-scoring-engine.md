# WCB-001: Scoring Engine

Status: Done
Owner: Codex
Priority: P0
Phase: MVP

## Problem

The app needs a deterministic scoring engine that evaluates group-stage and knockout predictions against official results.

## User Value

Users can trust that leaderboards are accurate, explainable, and consistent across groups.

## Scope

- Score exact group order picks.
- Score third-place advancement predictions.
- Score knockout winner picks by round.
- Emit explainable score events.
- Support combined total score.
- Support max possible points calculation if feasible in this ticket; otherwise define the interface for it.

## Out Of Scope

- Custom scoring rules.
- Exact match score predictions.
- Underdog bonuses.
- UI presentation.

## Acceptance Criteria

- [x] Group-stage score can be calculated from predictions and final standings.
- [x] Knockout score can be calculated from predictions and match winners.
- [x] Score events include source and reason.
- [x] Re-running scoring with the same inputs is idempotent.
- [x] Tests cover group-stage, knockout, and combined scoring.

## Test Expectations

- Exact group order.
- Partially correct group order.
- Correct advancing third-place team.
- Incorrect third-place advancement.
- Correct picks in each knockout round.
- Champion bonus.
- Recalculation after corrected result.

## Design Notes

No direct UI.

## Data And API Notes

Likely models involved:

- `GroupStagePrediction`
- `KnockoutBracketPrediction`
- `KnockoutPick`
- `Match`
- `ScoreEvent`
- `LeaderboardEntry`

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

This should be implemented before leaderboard UI.

Implementation added in `App/Bracket48Core`.

Current test command:

```sh
make test
```

Closed after scoring regression tests passed and backend scoring integration began consuming the core scoring model.
