# WCB-013: Apple Sign In Backend Auth

Status: In Progress
Owner: Codex
Priority: P0
Phase: MVP

## Problem

The app visually represents Sign in with Apple but does not authenticate users or create backend profiles.

## User Value

Users can securely access their account and keep brackets/groups across devices.

## Scope

- Add real Sign in with Apple entitlement and native flow.
- Exchange/validate Apple identity with backend auth.
- Create or update app user profile on first sign-in.
- Store authenticated session on iOS.

## Out Of Scope

- Account deletion flow.
- Multi-provider auth.
- Family sharing or managed Apple IDs.

## Acceptance Criteria

- [ ] User can sign in with Apple on device/simulator.
- [ ] Backend profile exists for the signed-in user.
- [ ] iOS app can fetch `me`.
- [ ] Sign-out clears local authenticated session.

## Test Expectations

- Auth service unit tests where feasible.
- Manual simulator/device auth flow.

## Design Notes

Use Apple-native button and system auth sheet.

## Data And API Notes

Supabase Auth is the assumed backend auth provider for the first implementation.

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

- Added Apple Sign In entitlement wiring, native nonce generation, Supabase package dependency, and app config placeholders.
- Added a Supabase-backed auth service that exchanges Apple ID tokens and upserts `app_users`.
- The sign-up screen still supports prototype mode until real Supabase and Apple provider values are configured.
