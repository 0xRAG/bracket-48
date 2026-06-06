# WCB-012: Backend Foundation

Status: Done
Owner: Codex
Priority: P0
Phase: MVP

## Problem

The app is still backed by local prototype state. We need a real backend foundation for identity, groups, invites, and bracket persistence.

## User Value

Users can keep their account, groups, invites, and brackets across devices and compete with friends.

## Scope

- Choose the initial backend architecture.
- Create database schema for users, groups, memberships, invites, brackets, and entries.
- Document environment setup.
- Add iOS service boundaries so UI can move off prototype state incrementally.

## Out Of Scope

- Production Apple Sign In validation.
- Live scoring jobs.
- Sports data provider ingestion.
- Push notifications.

## Acceptance Criteria

- [x] Backend architecture decision is documented.
- [x] Initial database migration exists.
- [x] Local environment setup is documented.
- [x] iOS app has backend service protocols/types for the first real integration.
- [x] Existing tests and iOS build still pass.

## Test Expectations

- `make test`
- `make build-ios`

## Design Notes

Keep current SwiftUI screens usable while replacing prototype state behind service boundaries.

## Data And API Notes

Use UUID primary keys, server timestamps, and database constraints for one-entry-per-user-per-pool-per-phase.

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

Started as the first real-backend milestone after the prototype split groups and brackets into independent flows.

Implemented first foundation slice:

- Added ADR 001 choosing Supabase/Postgres/Auth/RLS as the initial backend foundation.
- Added `Backend/` with Supabase migration and setup notes.
- Added schema for users, pools, memberships, brackets, and pool entries.
- Added RLS policies and `join_pool_by_invite` RPC instead of broad client-side membership inserts.
- Added iOS service protocols and DTOs for auth, pools, and brackets.

Verification:

- `make test` passes with 29 tests.
- `make build-ios` succeeds.

Agent tribunal review:

- Builder: The slice creates a concrete backend start while keeping the current prototype app buildable.
- Reviewer: Schema uses database uniqueness constraints for one entry per pool/user/phase and RLS is enabled on all app tables.
- Product Judge: The next work can move Groups and Brackets off local state independently.
- Design Judge: No UI churn in this slice; existing SwiftUI shell remains intact.
- Security And Integrity Judge: Invite joining is routed through a dedicated RPC; production hardening still belongs in WCB-014/WCB-015.
