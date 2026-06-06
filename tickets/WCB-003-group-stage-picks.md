# WCB-003: Group-Stage Picks Flow

Status: Done
Owner: Codex
Priority: P1
Phase: MVP

## Problem

Users need a clear way to predict the exact order of each group before the tournament locks.

## User Value

Users can complete the first phase of the competition quickly and confidently.

## Scope

- Show all 12 groups.
- Allow exact 1 through 4 ordering per group.
- Show lock deadline.
- Review picks before submission.
- Submit one entry per pool.
- Show submitted and locked states.

## Out Of Scope

- Match score predictions.
- Group-by-group lock behavior.
- Custom scoring.

## Acceptance Criteria

- [x] User can order all teams in each group.
- [x] User cannot submit incomplete picks.
- [x] User can review picks before final submission.
- [x] User cannot edit after lock.
- [x] User sees clear submitted and locked states.
- [x] VoiceOver can describe each team position.

## Test Expectations

- View model tests for complete/incomplete validation.
- Lock state tests.
- One-entry-per-pool submission tests.

## Design Notes

Follow `docs/DESIGN_DIRECTION.md`.

Use native iOS controls where possible. Drag-to-rank may be useful, but provide accessible alternatives.

## Data And API Notes

Requires tournament teams and groups.

## Agent Tribunal

Required: Yes

Roles:

- Builder: Implemented group-stage validation, review-and-lock submission copy, lock deadline display, locked Home state, and team position accessibility labels.
- Reviewer: Verified `make test`, `make build-ios`, and simulator locked-state navigation.
- Product Judge: Flow now distinguishes draft picks, review before submission, and submitted locked state.
- Design Judge: Keeps the Apple-native list/navigation pattern with pinned primary actions and concise status language.
- Security And Integrity Judge: Local lock prevents prototype editing after submission; server-side lock enforcement remains future backend scope.

## Notes

Implemented as the first major group-stage UX proof point.

Verification:

- `make test` passes with group-stage validation coverage.
- `make build-ios` succeeds.
- Manual simulator check confirms submitted entries restore as locked, Home shows "Picks Locked", and "View Submitted Bracket" routes to the submitted confirmation instead of editing.
