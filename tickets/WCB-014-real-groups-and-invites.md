# WCB-014: Real Groups And Invites

Status: Done
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

- [x] User can create a group that persists on the backend.
- [x] User can share an invite code/link backed by backend data.
- [x] Another authenticated user can join by invite code/link.
- [x] Groups tab renders backend memberships.

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
- Invite codes are generated client-side and protected by the backend unique constraint.
- Hosted schema is deployed.
- Universal Links, public invite landing page, custom app URL scheme, invite preview RPC, and device invite join flow are working.
