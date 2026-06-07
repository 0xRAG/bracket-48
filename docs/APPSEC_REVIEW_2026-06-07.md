# Bracket 48 AppSec Review

Date: 2026-06-07

Status: Initial review complete, first remediation applied

## Scope Reviewed

- Native iOS auth, deep links, local persistence, and Supabase configuration.
- Supabase schema, RLS policies, RPC functions, triggers, function grants, and database advisor output.
- Supabase Edge Functions for account deletion, Sportmonks sync, and score calculation.
- Public site, privacy/support pages, invite landing page, AASA file, and custom URL scheme handoff.
- Secret handling in committed source.

## Summary

No P0 issue was found in the current review. The highest-risk area was the Supabase RPC surface: several `security definer` functions were executable through the public API because Postgres grants function execution broadly by default. Migration `011_harden_rpc_surface.sql` was applied to the linked Supabase project and moves the membership helper into an unexposed private schema, removes public execution from trigger helpers, restricts invite preview/join/create RPCs to authenticated users, adds an explicit auth check to invite joins, and generates invite codes server-side.

The remaining important work is to add repeatable authorization tests, tighten operational access to privileged Edge Functions, sanitize backend error messages, and decide whether public invite preview should stay authenticated-only or become public again with rate limiting.

## Findings

### P1: Exposed Security-Definer RPC Surface

Affected:

- `Backend/supabase/migrations/001_initial_schema.sql`
- `Backend/supabase/migrations/002_fix_pool_membership_rls_recursion.sql`
- `Backend/supabase/migrations/003_create_pool_rpc.sql`
- `Backend/supabase/migrations/010_invite_preview.sql`

Risk:

Supabase advisors reported that `add_pool_owner_membership`, `create_pool`, `is_active_pool_member`, `join_pool_by_invite`, and `preview_pool_invite` were executable through the public RPC API. Some functions are intentionally callable, but trigger helpers and RLS helper functions should not be API endpoints. `is_active_pool_member` also accepted arbitrary `pool_id` and `user_id` inputs, making it a possible membership oracle.

Action Taken:

- Added `Backend/supabase/migrations/011_harden_rpc_surface.sql`.
- Moved membership helper to `app_private.is_active_pool_member`.
- Rebuilt RLS policies to call the private helper.
- Dropped the public helper.
- Revoked public/anon/authenticated execution from trigger helper functions.
- Recreated `create_pool` with server-generated invite codes.
- Added an explicit auth check to `join_pool_by_invite`.
- Restricted `preview_pool_invite` to authenticated users.

Verification:

- Re-run advisors and function grant queries.
- Confirmed `anon` cannot execute `create_pool`, `join_pool_by_invite`, `preview_pool_invite`, `set_updated_at`, `add_pool_owner_membership`, or the private membership helper.
- Confirmed `authenticated` can execute the intended public RPCs: `create_pool`, `join_pool_by_invite`, and `preview_pool_invite`.

Follow-Up:

- Add database authorization tests for owner/member/non-member/anon behavior.

### P1: Privileged Edge Functions Depend On Shared Secrets

Affected:

- `Backend/supabase/functions/sync-sportmonks-results/index.ts`
- `Backend/supabase/functions/score-brackets/index.ts`

Risk:

The sync and scoring functions correctly require either the service-role bearer token or `SYNC_RESULTS_SECRET`, but they are network-callable functions with permissive CORS. If the sync secret leaked, any origin could invoke privileged scoring/sync behavior.

Recommendation:

- Keep `SYNC_RESULTS_SECRET` only in Supabase secrets.
- Prefer scheduled/internal invocation paths where possible.
- Log invocation metadata without logging secrets.

Action Taken:

- Rotated `SYNC_RESULTS_SECRET` in Supabase Edge Function secrets.
- Updated the matching Supabase Vault secret `bracket48_sync_secret` used by Cron.
- Verified `score-brackets` accepts the rotated secret with a protected dry-run request.
- Narrowed `score-brackets` and `sync-sportmonks-results` CORS to `https://bracket48.app`.
- Removed `x-sync-secret` from browser preflight allowed headers for those operational functions. Server-to-server callers can still pass the header because CORS is only a browser constraint.

Follow-Up:

- Rotate operational secrets again if they are ever pasted into an untrusted tool or shared outside the project.

### P1: Missing Repeatable RLS Authorization Tests

Affected:

- Supabase policies for `app_users`, `pools`, `pool_memberships`, `pool_entries`, `brackets`, `bracket_scores`, and `bracket_score_events`.

Risk:

Current RLS behavior has been manually exercised through the app, but the system needs repeatable tests for cross-user data access before broader distribution.

Action Taken:

- Added `Backend/supabase/tests/rls_authorization_test.sql`.
- Added `make test-backend` for local Supabase pgTAP runs.
- Added `make test-backend-linked` for explicit linked-project pgTAP runs.
- Ran the test SQL against the linked database through `supabase db query` because the Supabase pgTAP runner requires Docker.
- Confirmed the test transaction rolled back and left no fake auth users or pools behind.
- The first test run exposed an infinite-recursion bug in the `pool_entries` insert policy.
- Added and applied `Backend/supabase/migrations/012_fix_pool_entry_insert_rls_recursion.sql`.

Coverage:

- Owner can view own pool, memberships, entries, entered bracket, and cannot delete an entered bracket.
- Member can view group participants, entered brackets, entries, and leaderboard rows.
- Non-member cannot view group participants, entries, brackets, or scores.
- Active member can enter their own bracket.
- Non-member cannot enter a bracket.
- User cannot delete a bracket after it is entered into a group.
- Anonymous users cannot call authenticated RPCs.

Follow-Up:

- Add a deleted-user cascade test once local Supabase test containers are available.
- Prefer `make test-backend` locally/CI once Docker Desktop or a CI Postgres service is configured.

### P2: Invite Preview Exposes Group Metadata

Affected:

- `Backend/supabase/migrations/010_invite_preview.sql`
- `App/Bracket48/AppModel.swift`

Risk:

Invite preview returns group name, invite code, and member count for a valid invite. This is useful UX, but it means anyone with a code can confirm the group exists. Codes are high entropy, but brute-force/rate-limit controls are not yet explicit.

Action Taken:

Migration `011_harden_rpc_surface.sql` restricts invite preview to authenticated users.

Recommendation:

- Keep preview payload minimal.
- Add rate limiting if preview is made anonymous again.
- Consider invite expiry/revocation before launch if groups become more sensitive.

### P2: Raw Backend Errors Can Reach Users

Affected:

- `Backend/supabase/functions/delete-account/index.ts`
- `Backend/supabase/functions/sync-sportmonks-results/index.ts`
- `Backend/supabase/functions/score-brackets/index.ts`
- `App/Bracket48/AppModel.swift`
- `Backend/supabase/migrations/013_restrict_provider_sync_runs.sql`

Risk:

Several backend paths return raw exception or provider messages. This helps development, but production error messages can reveal implementation details, provider response bodies, or database failures.

Action Taken:

- Updated Edge Functions to return stable `error_code` values and user-safe messages.
- Kept detailed diagnostics in Supabase function logs through `console.error`.
- Deployed `delete-account`, `score-brackets`, and `sync-sportmonks-results`.
- Removed the authenticated read policy from `provider_sync_runs`, which stores operational sync status and raw error detail.
- Smoke-tested unauthorized `score-brackets` and `sync-sportmonks-results` responses after deploy.

Follow-Up:

- Consider narrowing CORS on operational functions separately from error sanitization.

### P2: Local Draft Data Is Stored In UserDefaults

Affected:

- `App/Bracket48/Support/DraftStateStore.swift`

Risk:

Draft brackets, display name, group metadata, and pending invite state are stored in `UserDefaults`. This is probably acceptable for a casual entertainment app, but it is not encrypted application storage.

Recommendation:

- Document this in the privacy review if considered collected/stored app data.
- Clear local state on sign out and account deletion; current code paths should continue to be tested.
- Consider file protection or Keychain only if bracket privacy becomes a stronger product requirement.

### P2: Public Site And Deep-Link Handoff Need Regression Checks

Affected:

- `PublicSite/.well-known/apple-app-site-association`
- `PublicSite/join/index.html`
- `App/Bracket48/Support/Info.plist`
- `App/Bracket48/AppModel.swift`

Risk:

The invite site hands off to `bracket48://join?code=...`, and the app accepts codes from incoming URLs. This is the right shape for fallback behavior, but malformed URLs and hostile inputs should be regression tested.

Recommendation:

- Test valid invite, invalid invite, empty code, long code, encoded query values, duplicate invites, signed-out launch, and already-member launch.
- Keep code normalization strict.
- If Universal Links become flaky, serve AASA from an endpoint with explicit `application/json`.

### P3: Supabase Advisor Performance Warnings

Affected:

- Multiple RLS policies.

Risk:

Advisor output includes `auth_rls_initplan` and multiple permissive policy warnings. These are primarily performance/maintainability concerns, not immediate security issues.

Recommendation:

- Convert `auth.uid()` references in policies to `(select auth.uid())` as policies are touched.
- Consolidate overlapping permissive policies where it improves clarity.

### Accepted Risk: Public Anon Key In App Bundle

Affected:

- `App/Bracket48/Support/Info.plist`
- `App/Bracket48/Services/AppConfiguration.swift`

Notes:

The Supabase publishable/anon key is intended to be public in client apps. The service-role key, Sportmonks token, Apple private key, and sync secret were not found in committed source during this review.

## Verification Performed

- Ran Supabase database advisors against the linked project.
- Queried live `pg_policies`.
- Queried live function grants for `anon`, `authenticated`, and `public`.
- Searched committed source for Sportmonks token, service-role key, Apple private key material, client secrets, and JWT-like strings.
- Re-ran committed-source secret scan after secret rotation; only documentation placeholders/examples were found.
- Reviewed auth, invite handling, account deletion function, scoring function, sync function, public site, and local draft storage.

## Launch Gate

Before App Store submission, close or explicitly accept these:

- Extend backend authorization tests to cover deleted-user cascades.
- Confirm account deletion still works after hardening.
- Re-test invite link flows on physical device after the migration.
