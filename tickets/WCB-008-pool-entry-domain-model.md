# WCB-008: Pool And Entry Domain Model

Status: Done
Owner: Codex
Priority: P0
Phase: MVP

## Problem

The prototype can create local groups and submit brackets, but the core package does not yet model pools, memberships, invites, or one-entry-per-user enforcement.

## User Value

Users can compete in private groups with clear entry rules, and backend work can build on a stable product contract.

## Scope

- Model users, pools, memberships, invite codes, and entries.
- Support full-tournament and knockout-only pool types.
- Represent pool lock/submission windows.
- Enforce one entry per user per pool and phase.
- Validate whether an entry is eligible for a pool.

## Out Of Scope

- Backend persistence.
- Real Apple identity validation.
- Invite link transport.
- Leaderboard queries.

## Acceptance Criteria

- [x] Full-tournament pools accept group-stage entries and knockout entries from members.
- [x] Knockout-only pools accept knockout entries and reject group-stage entries.
- [x] Duplicate entries for the same user, pool, and bracket phase are rejected.
- [x] Non-members cannot submit entries.
- [x] Locked pools reject new entries.
- [x] Invite codes are represented as first-class values.

## Test Expectations

- Unit tests for membership eligibility.
- Unit tests for duplicate entry detection.
- Unit tests for pool type and lock state validation.

## Design Notes

Keep this as domain logic only; UI and backend adapters can map into it later.

## Data And API Notes

Use Codable, Sendable value types to keep the model portable across app, backend, and fixtures.

## Agent Tribunal

Required: No

## Notes

Implemented in `Bracket48Core` with Codable, Sendable value types for pools, memberships, entries, invite codes, entry phases, lock windows, and validation issues.

Verification:

- `make test` passes with pool entry validation coverage.
- `make build-ios` succeeds.
