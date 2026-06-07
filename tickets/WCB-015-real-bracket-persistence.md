# WCB-015: Real Bracket Persistence

Status: Done
Owner: Codex
Priority: P0
Phase: MVP

## Problem

Bracket submissions are currently stored only in local prototype state.

## User Value

Users can submit picks once, recover them later, and enter eligible groups.

## Scope

- Persist group-stage bracket submissions.
- Persist knockout bracket submissions.
- Support standalone brackets.
- Support bracket-to-group entry association.
- Wire Brackets tab to backend-backed service.

## Out Of Scope

- Live scoring.
- Bracket comparison UI.
- Admin correction tools.

## Acceptance Criteria

- [x] User can submit a standalone group-stage bracket to the backend.
- [x] User can submit a knockout bracket to the backend.
- [x] User can list their brackets after relaunch.
- [x] User can associate a bracket with an eligible group.
- [x] Duplicate entries for the same user, group, and phase are rejected.

## Test Expectations

- Core validation tests.
- Backend constraint tests or SQL checks.
- iOS service tests with mocked transport.

## Design Notes

Preserve the current two-phase bracket UX.

## Data And API Notes

Bracket payloads should remain JSONB initially so product iteration does not require frequent relational migrations for pick shape.

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

- Added `SupabaseBracketService` implementing list/submit group-stage/submit knockout/enter bracket operations behind `BracketServicing`.
- Pick payloads are encoded as JSON objects for the existing `brackets.picks` JSONB column.
- Hosted schema is deployed.
- Device flows proved group-stage bracket save, knockout bracket save, listing, group entry, delete guard, and linked bracket behavior.
