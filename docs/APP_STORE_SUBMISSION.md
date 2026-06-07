# App Store Submission

## Release Commands

Run the full release gate before uploading:

```sh
make test
make test-functions
make test-backend-linked-query
make hosted-dress-rehearsal
make build-ios
```

Create an App Store archive:

```sh
make archive-ios
```

Upload the archive to App Store Connect:

```sh
make upload-ios
```

If command-line upload cannot access the Apple account, open Xcode Organizer, select `Build/Archives/Bracket48.xcarchive`, and use Distribute App > App Store Connect.

## Build Settings

- App name: Bracket 48
- Bundle ID: `app.bracket48.Bracket48`
- Version: `1.0`
- Build: `1`
- Team ID: `497S7CC998`
- Supported devices: iPhone
- Backend mode: Supabase
- Public site: `https://bracket48.app/`

Before archiving, confirm `App/Bracket48/Support/Bracket48.local.xcconfig` exists locally and contains the production Supabase URL and publishable key. That file is intentionally ignored by git.

## App Store Connect Fields

Create the App Store Connect app record before running `make upload-ios`:

- Platform: iOS
- Name: Bracket 48
- Primary language: English (U.S.)
- Bundle ID: `app.bracket48.Bracket48`
- SKU: `bracket48-ios`
- User Access: Full Access

If `make upload-ios` fails with `exportArchive Error Downloading App Information`, check that this app record exists. Xcode has successfully authenticated to App Store Connect when the distribution log shows a `200` response but `data: []` for `filter[bundleId]=app.bracket48.Bracket48`; that means App Store Connect has no app record for the bundle ID yet.

Use the drafts in:

- `AppStore/metadata.md`
- `AppStore/privacy-answers.md`
- `AppStore/age-rating.md`

Upload iPhone 6.5-inch screenshots from:

- `AppStore/Screenshots/iPhone-6.5/01-home.png`
- `AppStore/Screenshots/iPhone-6.5/02-brackets.png`
- `AppStore/Screenshots/iPhone-6.5/03-group-bracket.png`
- `AppStore/Screenshots/iPhone-6.5/04-groups.png`
- `AppStore/Screenshots/iPhone-6.5/05-winner.png`
- `AppStore/Screenshots/iPhone-6.5/06-profile.png`

The root `AppStore/Screenshots/*.png` files are simulator originals and may not match App Store Connect's accepted upload dimensions. The `iPhone-6.5` copies are resized to `1242 x 2688`, which is accepted for the iPhone 6.5-inch screenshot slot.

URLs:

- Privacy Policy URL: `https://bracket48.app/privacy/`
- Support URL: `https://bracket48.app/support/`
- Marketing URL: `https://bracket48.app/`

## Review Notes

Bracket 48 is an independent, unofficial soccer tournament bracket app for entertainment with friends. It is not affiliated with tournament organizers, teams, or federations, and does not offer cash rewards, prizes, betting, gambling, sweepstakes, or paid contests.

The app uses Sign in with Apple. Account deletion is available from Profile > Delete Account.

No special hardware is required.

## Final Manual Checks

- Complete `docs/PHYSICAL_DEVICE_QA.md` on a physical iPhone.
- Install the uploaded build through TestFlight and repeat the highest-risk flows: Apple sign-in, display-name persistence, bracket create/edit, group create/join, invite link, leaderboard, profile color, sign out, and account deletion with a disposable account.
