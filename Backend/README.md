# Backend

Initial backend target: Supabase.

The backend starts with database schema and policies. Secrets and environment files should stay outside git until a real project is created.

## Structure

- `supabase/migrations`: SQL migrations for local and hosted Supabase.
- `functions`: future Supabase Edge Functions for scoring, provider ingestion, and protected workflows.

## Local Setup

Install the Supabase CLI, then from this directory:

```sh
supabase start
supabase db reset
```

Run database authorization tests against a local Supabase stack:

```sh
make test-backend
```

When validating the currently linked hosted project, use the explicit linked target. The pgTAP tests run inside a transaction and roll back their seeded test users/data:

```sh
make test-backend-linked
```

If Docker Desktop is not running, the Supabase pgTAP runner may be unavailable. Use the query-backed linked smoke target instead:

```sh
make test-backend-linked-query
```

The iOS app should receive backend settings through local configuration, not checked-in secrets:

- `WCB_BACKEND_MODE`: `supabase`.
- `WCB_SUPABASE_URL`: the project URL, for example `https://<project-ref>.supabase.co`.
- `WCB_SUPABASE_ANON_KEY`: the publishable/anon project key from Supabase API settings.

The checked-in app defaults to Supabase mode in `App/Bracket48/Support/Bracket48.xcconfig`. Local secrets should go in `App/Bracket48/Support/Bracket48.local.xcconfig`, which is ignored by git and included optionally by the shared config.

## Values Needed From Supabase

- Project URL: `https://<project-ref>.supabase.co`
- Publishable/anon key for the iOS client.
- Project ref, useful for CLI/API work and callback URLs.
- Supabase Apple provider callback URL, normally `https://<project-ref>.supabase.co/auth/v1/callback`.

## Values Needed From Apple

For the native app:

- Apple Developer Team ID.
- iOS bundle ID with Sign in with Apple enabled. The current bundle ID is `app.bracket48.Bracket48`.

For Supabase's Apple provider configuration:

- Services ID / client ID, commonly a web-style identifier such as `app.bracket48.auth`.
- Website domain set to `<project-ref>.supabase.co`.
- Return URL set to `https://<project-ref>.supabase.co/auth/v1/callback`.
- Apple signing Key ID.
- Apple Developer Team ID.
- Apple private key file contents from `AuthKey_<KEY_ID>.p8`, handled securely and never committed.
- The generated Apple client secret entered in Supabase Auth provider settings.

Generate the Apple client secret locally after the Services ID exists:

```sh
Backend/scripts/generate_apple_client_secret.sh 497S7CC998 <services-id-client-id> 9CL6UHBGQ9 /Users/ryan/Desktop/AuthKey_9CL6UHBGQ9.p8
```

Apple only returns the user's name on the first authorization, so the iOS app captures the native full-name response and stores our own display name in `app_users`.

## Current Schema

The first migration creates:

- `app_users`
- `pools`
- `pool_memberships`
- `brackets`
- `pool_entries`

It also enables Row Level Security and installs MVP policies for owners/members to view and manage their own data.

## Sports Data

Live results use Sportmonks from a trusted backend context. The API token must be stored as a Supabase Edge Function secret and must never be shipped in the iOS app.

Current provider IDs:

- Provider: `sportmonks`
- World Cup league ID: `732`
- 2026 season ID: `26618`
- Group stage ID: `77478590`

The `007_sportmonks_results_ingestion.sql` migration adds normalized provider tables:

- `provider_teams`
- `tournament_matches`
- `group_standings`
- `provider_sync_runs`
- `result_overrides`

Run a full fixture and standings sync through the protected Edge Function:

```sh
curl -X POST \
  "https://<project-ref>.functions.supabase.co/sync-sportmonks-results" \
  -H "Authorization: Bearer <service-role-key>" \
  -H "Content-Type: application/json" \
  -d '{"mode":"all"}'
```

Supported modes are `all`, `fixtures`, `standings`, and `live`.

Deploy after linking the project:

```sh
pnpm dlx supabase secrets set SPORTMONKS_API_TOKEN=<token> --project-ref <project-ref>
pnpm dlx supabase db push --workdir Backend --linked
pnpm dlx supabase functions deploy sync-sportmonks-results --workdir Backend --project-ref <project-ref> --no-verify-jwt
```

For scheduled polling, create a Supabase Cron job that calls the Edge Function with the service-role bearer token. Use `mode: "all"` before and after matchdays, and `mode: "live"` during live match windows.

Current hosted Cron jobs:

- `bracket48-results-live-sync`: every 5 minutes, calls `sync-sportmonks-results` with `mode: "live"`.
- `bracket48-results-standings-sync`: hourly at minute 22, calls `mode: "standings"`.
- `bracket48-results-full-sync`: every 6 hours at minute 37, calls `mode: "all"`.

The sync function invokes `score-brackets` with `dry_run: false` after each successful sync, so leaderboards update from the latest normalized rows. Cron secrets are stored in Supabase Vault under `bracket48_project_url` and `bracket48_sync_secret`.

## Edge Functions

### `delete-account`

Deletes the currently authenticated user from Supabase Auth. The `app_users` table references `auth.users` with `on delete cascade`, so brackets, memberships, entries, and owned pools are removed by the database after the auth user is deleted.

Deploy after linking the project:

```sh
pnpm dlx supabase functions deploy delete-account --project-ref <project-ref>
```

The function expects Supabase's standard Edge Function environment variables:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Do not put the service-role key in the iOS app. It is only used inside the deployed Edge Function.

### `sync-sportmonks-results`

Fetches World Cup 2026 fixtures, live scores, and group standings from Sportmonks, normalizes the payloads, and upserts them into the results tables. The function accepts only protected POST requests using the Supabase service-role bearer token or an optional `SYNC_RESULTS_SECRET` header.

### `score-brackets`

Scores pool entries from normalized result tables and persists score totals/events when `dry_run` is `false`. The default is `dry_run: true`, which returns computed scores without writing leaderboard rows.

Deploy:

```sh
pnpm dlx supabase functions deploy score-brackets --workdir Backend --project-ref <project-ref> --no-verify-jwt
```

Score current database results without writing:

```sh
curl -X POST \
  "https://<project-ref>.functions.supabase.co/score-brackets" \
  -H "x-sync-secret: <sync-results-secret>" \
  -H "Content-Type: application/json" \
  -d '{"dry_run":true}'
```

Persist scores for existing pool entries:

```sh
curl -X POST \
  "https://<project-ref>.functions.supabase.co/score-brackets" \
  -H "x-sync-secret: <sync-results-secret>" \
  -H "Content-Type: application/json" \
  -d '{"dry_run":false}'
```

Use `simulation.entries`, `simulation.group_standings`, `simulation.advancing_third_place_team_ids`, and `simulation.knockout_results` to test a fake tournament without touching production scores.
