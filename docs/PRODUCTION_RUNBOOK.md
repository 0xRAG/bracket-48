# Production Runbook

## Purpose

This runbook covers Bracket 48 hosted operations for the MVP: result ingestion, scoring, admin overrides, invites, auth, account deletion, and public site checks.

## Critical Systems

- iOS app: `app.bracket48.Bracket48`
- Public site and Universal Links: `https://bracket48.app`
- Backend: Supabase project `aqtrnbaykpogolclhrai`
- Result provider: Sportmonks
- Edge Functions:
  - `sync-sportmonks-results`
  - `score-brackets`
  - `apply-result-override`
  - `delete-account`
- Database areas:
  - `tournament_matches`
  - `group_standings`
  - `brackets`
  - `pool_entries`
  - `bracket_scores`
  - `bracket_score_events`
  - `provider_sync_runs`

## Routine Checks

Before major app changes:

```sh
make test
make test-functions
make test-backend-linked-query
make build-ios
```

Before live match windows:

```sh
make hosted-dress-rehearsal
```

Check recent provider syncs:

```sh
pnpm dlx supabase db query --workdir Backend --linked --output table \
  "select provider, status, fetched_at, error_message from public.provider_sync_runs order by fetched_at desc limit 10;"
```

Check recent scores:

```sh
pnpm dlx supabase db query --workdir Backend --linked --output table \
  "select pool_id, phase, count(*) as scored_entries, max(calculated_at) as last_scored_at from public.bracket_scores group by pool_id, phase order by last_scored_at desc limit 20;"
```

## Result Sync Triage

Symptoms:

- Match results look stale.
- Group standings are missing or incorrect.
- Scoring does not update after a match is final.

Steps:

1. Check `provider_sync_runs` for the latest status and error.
2. Verify the Sportmonks token exists in Supabase secrets.
3. Invoke `sync-sportmonks-results` from Supabase dashboard or scheduled job.
4. Check `tournament_matches` for final status and `winner_team_id`.
5. Run `score-brackets` for affected pools if sync did not invoke scoring.

## Scoring Triage

Symptoms:

- Leaderboard is empty.
- Possible points remaining looks wrong.
- A bracket score does not reflect a corrected result.

Steps:

1. Run `make hosted-dress-rehearsal` to confirm scoring functions still work end to end.
2. Inspect `bracket_scores` for the affected `pool_id`.
3. Inspect `bracket_score_events` for rule-level explanations.
4. Re-run `score-brackets` for the affected pool with the sync secret.
5. If results are wrong, apply an admin override and trigger scoped rescoring.

## Admin Override

Use only for confirmed provider errors or manual corrections.

```sh
curl -X POST "https://aqtrnbaykpogolclhrai.functions.supabase.co/apply-result-override" \
  -H "Content-Type: application/json" \
  -H "x-sync-secret: $SYNC_RESULTS_SECRET" \
  -d '{
    "match_id": "internal-match-id",
    "corrected_status": "final",
    "corrected_home_score": 1,
    "corrected_away_score": 0,
    "corrected_winner_team_id": "team-id",
    "reason": "Provider correction.",
    "scoring_pool_id": "optional-pool-id"
  }'
```

After override:

1. Confirm `tournament_matches.admin_corrections` records the reason.
2. Confirm affected `bracket_scores` changed as expected.
3. Confirm the group leaderboard renders in the app.

## Invite And Group Creation Checks

Smoke test:

```sh
make test-backend-linked-query
```

This rollback-only SQL test covers:

- `create_pool` RPC execution.
- Random invite-code generation.
- Owner membership creation.
- owner/member/non-member visibility.
- invite and bracket RLS behavior.

If users see group creation failures:

1. Check app error text and Supabase PostgREST logs.
2. Confirm `public.create_pool(text, public.pool_type)` has `search_path=public, extensions`.
3. Confirm `extensions.pgcrypto` exists.
4. Re-run `make test-backend-linked-query`.

## Auth And Account Deletion Checks

For sign-in issues:

1. Confirm Apple Services ID and bundle ID match Supabase Auth Apple provider settings.
2. Confirm Supabase redirect URL is present in Apple developer settings.
3. Confirm `app_users` has the signed-in user's profile row.

For account deletion:

1. Delete a disposable account in-app.
2. Confirm `auth.users` no longer has that user.
3. Confirm cascaded rows are gone from `app_users`, `pools`, `pool_memberships`, `brackets`, `pool_entries`, and `bracket_scores`.

## Public Site And Universal Links

Checks:

```sh
curl -I https://bracket48.app
curl https://bracket48.app/.well-known/apple-app-site-association
curl -I "https://bracket48.app/join/?code=BRKT48"
```

Expected:

- HTTPS is valid.
- AASA JSON is reachable without redirects.
- Join URLs render the public invite landing page and can redirect to the app.

## Release Gate

Before submitting an app build:

- `make test`
- `make test-functions`
- `make test-backend-linked-query`
- `make hosted-dress-rehearsal`
- `make build-ios`
- Complete `docs/PHYSICAL_DEVICE_QA.md`
