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

The iOS app should receive backend settings through local configuration, not checked-in secrets:

- `WCB_BACKEND_MODE`: `supabase`.
- `WCB_SUPABASE_URL`: the project URL, for example `https://<project-ref>.supabase.co`.
- `WCB_SUPABASE_ANON_KEY`: the publishable/anon project key from Supabase API settings.

The checked-in app defaults to Supabase mode in `App/WorldCupBracket/Support/WorldCupBracket.xcconfig`. Local secrets should go in `App/WorldCupBracket/Support/WorldCupBracket.local.xcconfig`, which is ignored by git and included optionally by the shared config.

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
