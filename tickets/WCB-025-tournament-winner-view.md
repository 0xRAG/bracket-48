# WCB-025: Tournament Winner View

Status: Done
Owner: Codex
Priority: P2
Phase: V1

## Problem

After the tournament ends, groups need a clear closing moment that shows who won the pool and celebrates the final standings.

## User Value

Players get a satisfying end state for the competition, can see who won bragging rights, and can revisit final results with friends.

## Scope

- Add a winner view for completed groups after final scoring is locked.
- Show the group winner, final score, and final leaderboard.
- Include the winning bracket and a summary of key correct picks.
- Make the view available from group detail once the tournament is complete.
- Handle ties clearly according to the scoring/tiebreak rules.

## Out Of Scope

- Cash rewards, prizes, betting, or gambling mechanics.
- Public global leaderboards.
- Social posting integrations beyond normal OS share affordances.

## Acceptance Criteria

- [x] Completed groups show a winner/final standings entry point.
- [x] Winner view identifies the winning player or tied winners.
- [x] Final leaderboard is frozen after tournament scoring is complete.
- [x] Empty or incomplete groups do not show a misleading winner state.
- [x] The view is visually distinct from the live standings state.

## Test Expectations

- Backend scoring fixture for completed tournament state.
- UI state test or manual QA for winner, tie, empty group, and unscored group cases.

## Design Notes

This can be more celebratory than the normal operational screens, but should still feel native and Apple-standard. Keep the no-prizes/friends-only positioning clear if any sharing language is added.

## Data And API Notes

May use existing leaderboard data once all tournament matches are final. Consider adding a group completion/status helper so the client does not infer completion solely from local match counts.

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

Requested by Ryan as an end-of-tournament experience.

Implemented a completed-group entry point when scored standings have no points remaining, plus a dedicated Winner screen with final winner/tie state, final leaderboard, winning bracket links, and the no-prizes entertainment disclaimer. Screenshot fixtures now include a completed tournament winner route.
