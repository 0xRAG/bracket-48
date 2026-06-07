# WCB-016: In-App Account Deletion

Status: Done
Owner: Codex
Priority: P1
Phase: MVP

## Goal

Provide an App Store-ready way for signed-in users to delete their account from inside the iOS app.

## Scope

- Add a visible account deletion control in the app.
- Confirm destructive intent before deletion.
- Delete the authenticated Supabase Auth user from a trusted backend context.
- Rely on database cascades to remove app profile, brackets, pools, memberships, and entries.
- Clear local draft state and return to sign-in after deletion.

## Implementation Notes

- iOS calls the `delete-account` Supabase Edge Function through the authenticated Supabase client.
- The Edge Function verifies the caller's bearer token before using the service-role key to delete that same `auth.users` record.
- The service-role key must never be shipped in the iOS bundle.

## Acceptance Criteria

- A signed-in user can find Delete Account from Home > Profile.
- Tapping Delete Account presents a destructive confirmation dialog.
- Confirming deletes the user's Supabase Auth account.
- App data cascades from `auth.users` deletion.
- The app clears local state and returns to Sign in with Apple.
- Failed deletion leaves the user signed in and shows an error.
