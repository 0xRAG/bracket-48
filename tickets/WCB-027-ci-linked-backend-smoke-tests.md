# WCB-027: CI Linked Backend Smoke Tests

Status: Done
Owner: Codex
Priority: P1
Phase: MVP

## Problem

Backend regressions can reach a device before we notice if local-only checks pass but hosted Supabase RPCs, RLS policies, or extension search paths behave differently.

## User Value

Users get a more reliable app because create-group, invite, auth, and scoring permissions are checked automatically before changes ship.

## Scope

- Add CI for core Swift tests, Edge Function shared tests, and iOS build validation.
- Add optional linked Supabase smoke coverage for the hosted project.
- Ensure the linked smoke path includes the `create_pool` RPC regression test.
- Document required GitHub secrets and variables.

## Out Of Scope

- Full App Store archive/signing automation.
- Hosted dress rehearsal on every commit.
- External monitoring setup.

## Acceptance Criteria

- [x] CI runs on push and pull request.
- [x] CI runs core Swift tests.
- [x] CI runs Supabase shared function tests.
- [x] CI builds the iOS app.
- [x] CI can run linked Supabase smoke tests when secrets are configured.
- [x] Missing linked Supabase secrets are handled explicitly.

## Test Expectations

- Validate workflow syntax by inspection.
- Run local commands that mirror CI where feasible.
- Confirm linked smoke test still passes locally with `make test-backend-linked-query`.

## Design Notes

Keep linked production smoke tests narrow, rollback-only, and fast. The purpose is to catch contract regressions, not replace full hosted dress rehearsal.

## Data And API Notes

Required CI configuration should include Supabase access token, project ref, and database password for a non-destructive rollback test.

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

Created after the hosted `create_pool` RNG/search-path regression.

Implemented `.github/workflows/ci.yml` with macOS app/core/function checks and an optional linked Supabase smoke job gated by `SUPABASE_PROJECT_REF`, `SUPABASE_ACCESS_TOKEN`, and `SUPABASE_DB_PASSWORD`.
