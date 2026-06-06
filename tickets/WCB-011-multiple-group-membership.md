# WCB-011: Multiple Group Membership

Status: Done
Owner: Codex
Priority: P1
Phase: MVP

## Problem

The tabbed prototype exposes Groups as a top-level destination, but local state still represents one submitted prototype group-stage entry.

## User Value

Users should be able to join or create multiple pools, then choose where to submit eligible brackets.

## Scope

- Represent multiple joined groups in app state.
- Add local create-group and join-by-invite flows.
- Show all joined groups in the Groups tab.
- Let users share invites for groups they own.
- Connect entries to the selected group.

## Out Of Scope

- Backend invite redemption.
- Push notifications.
- Real contacts integration.

## Acceptance Criteria

- [x] User can create more than one group.
- [x] User can join a group by invite code or link.
- [x] Groups tab lists all joined groups.
- [x] Bracket submission no longer blocks local group creation.
- [x] Invite sharing is available for owned groups.

## Test Expectations

- Local state tests for multiple groups.
- Simulator flow for creating and joining groups.

## Design Notes

Keep the UI Apple-native and list-based; avoid turning Groups into a marketing page.

## Data And API Notes

This should build on WCB-008 pool and membership domain models.

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

Implemented local multiple group membership in the SwiftUI prototype.

- Persisted joined groups in local state with backwards-compatible decoding for earlier prototype state.
- Groups tab now lists every joined group, shows per-group invite codes and share links, and supports joining by either raw code or join URL.
- Create Group can be used independently of bracket creation. A bracket can be submitted as a standalone local entry and continue into knockout picks without joining or creating a group.
- Bracket-to-pool entry submission is intentionally deferred to backend-backed follow-up work.
- Backend invite redemption, pool permissions, and server-side duplicate-entry enforcement remain future integration work.

Agent tribunal review:

- Builder: Implementation is scoped to local prototype state and UI, avoiding backend assumptions.
- Reviewer: `make test` and `make build-ios` pass after the local state migration.
- Product Judge: The flow now supports the user's requested tabs, viewing groups, adding groups, and sharing/joining by invite.
- Design Judge: Groups remains an Apple-native list experience with SF Symbols, native `ShareLink`, and compact status rows.
- Security And Integrity Judge: Invite codes are prototype-only and clearly defer real redemption/permission enforcement to backend work.
