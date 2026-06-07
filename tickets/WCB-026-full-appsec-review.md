# WCB-026: Full AppSec Review

Status: In Progress
Owner: Codex
Priority: P1
Phase: MVP

## Problem

Bracket 48 now has a real iOS client, Supabase backend, authentication, database policies, edge functions, public website, and Universal Link surfaces. Before broad distribution, the full system needs a deliberate security review.

## User Value

Users can trust that their account, brackets, groups, invite links, and profile data are protected appropriately for a friends-only entertainment app.

## Scope

- Review iOS frontend security posture.
- Review Sign in with Apple and Supabase Auth configuration.
- Review database schema, RLS policies, RPC functions, triggers, and migrations.
- Review Supabase Edge Functions and secrets handling.
- Review public site, Universal Links, AASA file, invite landing page, privacy/support pages, and custom URL scheme behavior.
- Review invite-code lifecycle and group membership authorization.
- Review account deletion and data-retention paths.
- Review API abuse, rate-limit, logging, and observability gaps.
- Produce prioritized findings with recommended fixes.

## Out Of Scope

- Formal penetration test by an external vendor.
- Compliance certification.
- Bug bounty setup.
- Security work unrelated to Bracket 48 systems.

## Acceptance Criteria

- [ ] Findings cover frontend, backend, auth, database, functions, and public site.
- [ ] Each finding includes severity, affected files/systems, risk, and recommended fix.
- [x] RLS policies are tested for cross-user access to groups, brackets, entries, profiles, and leaderboards.
- [ ] Secrets are verified to be absent from committed source and exposed app bundles except intended public anon keys.
- [ ] Invite links and custom URL scheme behavior are tested for malformed/hostile inputs.
- [ ] Account deletion is verified end to end.
- [ ] P0/P1 findings are ticketed or fixed before App Store submission.

## Test Expectations

- Backend authorization test matrix for owner, member, non-member, unauthenticated, and deleted-user cases.
- Manual iOS review for URL handling, auth state transitions, and local persistence.
- Public site checks for HTTPS, AASA correctness, redirects, and unwanted data exposure.

## Design Notes

Keep any user-facing security changes native and low-friction. Security prompts should be reserved for actions with real risk, such as account deletion.

## Data And API Notes

Pay special attention to `security definer` RPC functions, Supabase storage/secrets, Sportmonks token handling, edge function authorization, and public invite preview fields.

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

Requested by Ryan as a full AppSec review of frontend, backend, auth, and public sites.

2026-06-07: Started review, ran Supabase database advisors, inspected live RLS/RPC grants, reviewed Edge Functions, public site, invite link handling, local persistence, and app configuration. Added `011_harden_rpc_surface.sql` to close initial RPC exposure findings.

2026-06-07: Added pgTAP RLS authorization tests for owner/member/non-member/anon visibility and entry behavior. The test exposed infinite recursion in the pool entry insert policy, fixed by `012_fix_pool_entry_insert_rls_recursion.sql`, and was verified against the linked database through a rollback-only query run.

2026-06-07: Sanitized production-facing Edge Function errors for account deletion, scoring, and Sportmonks sync. Deployed all three functions and restricted `provider_sync_runs` from authenticated client reads with `013_restrict_provider_sync_runs.sql`.

2026-06-07: Narrowed browser CORS on operational scoring and results sync functions to `https://bracket48.app` and removed `x-sync-secret` from preflight-allowed headers. Redeployed both functions and verified OPTIONS headers.

2026-06-07: Rotated `SYNC_RESULTS_SECRET`, updated the matching `bracket48_sync_secret` Vault value used by Cron, and verified protected score dry-run access with the rotated secret.
