# WCB-014: Real Groups And Invites

Status: In Progress
Owner: Codex
Priority: P0
Phase: MVP

## Problem

Groups and invite links are currently local-only prototype data.

## User Value

Users can create real groups, share invite links, and have friends join the same competition.

## Scope

- Create group API.
- List my groups API.
- Join group by invite code API.
- Store group memberships with owner/member roles.
- Wire Groups tab to backend-backed service.

## Out Of Scope

- Public group discovery.
- Admin moderation.
- Custom scoring settings.

## Acceptance Criteria

- [ ] User can create a group that persists on the backend.
- [ ] User can share an invite code/link backed by backend data.
- [ ] Another authenticated user can join by invite code/link.
- [ ] Groups tab renders backend memberships.

## Test Expectations

- Database constraint tests or SQL checks where practical.
- iOS service tests with mocked transport.
- Manual simulator flow.

## Design Notes

Keep the Groups tab list-based and Apple-native.

## Data And API Notes

Invite codes should be unique, short, and non-secret. Authorization must still check membership on protected data.

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

- Added `SupabasePoolService` implementing create/list/join group operations behind `PoolServicing`.
- Invite codes are generated client-side for now and protected by the backend unique constraint.
- UI wiring and hosted schema deployment remain outstanding.
