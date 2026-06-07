# WCB-013: Apple Sign In Backend Auth

Status: Done
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

- [x] User can sign in with Apple on device/simulator.
- [x] Backend profile exists for the signed-in user.
- [x] iOS app can fetch `me`.
- [x] Sign-out clears local authenticated session.

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
- Real Supabase and Apple provider values are configured.
- Device sign-in was proved with backend profile persistence, display-name persistence, sign-out, and in-app account deletion.
