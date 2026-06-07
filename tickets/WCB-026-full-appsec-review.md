# WCB-026: Full AppSec Review

Status: Backlog
Owner: Unassigned
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
- [ ] RLS policies are tested for cross-user access to groups, brackets, entries, profiles, and leaderboards.
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
