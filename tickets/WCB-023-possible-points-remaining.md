# WCB-023: Possible Points Remaining In Groups

Status: Backlog
Owner: Unassigned
Priority: P2
Phase: V1

## Problem

Group standings show current scored points, but players cannot see how much upside each participant still has based on unresolved matches and surviving picks.

## User Value

Players can understand who is truly still alive in a group, not just who is currently leading.

## Scope

- Show possible points remaining per participant on group detail standings.
- Derive the value from existing bracket picks, scoring rules, and unresolved tournament matches.
- Consider a combined group-stage plus knockout total where both bracket phases have been entered.
- Present the value compactly so standings remain readable.

## Out Of Scope

- Cash, prize, betting, or gambling mechanics.
- Scenario simulation UI for every possible future result.
- Notifications when a player is eliminated.

## Acceptance Criteria

- [ ] Group detail standings include a possible-points-remaining value for each participant.
- [ ] Remaining points decrease as matches become final and brackets are rescored.
- [ ] Values are consistent with the published scoring explainer.
- [ ] Empty or unscored groups still render cleanly.

## Test Expectations

- Unit tests for possible-points calculations across group-stage and knockout brackets.
- Backend scoring simulation that verifies current points, max points, and remaining points after partial results.

## Design Notes

Keep the standings row scannable. Prefer a short value such as `+42 possible` or a secondary line only when needed.

## Data And API Notes

May require adding a `possible_points_remaining` column or view/RPC field alongside leaderboard entries. The current `max_points` field is static maximum score, not remaining attainable score after incorrect eliminated picks.

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

Requested by Ryan during invite-functionality work.
