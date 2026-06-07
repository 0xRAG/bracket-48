# WCB-018: App Store Privacy And Metadata

Status: In Progress
Owner: Codex
Priority: P1
Phase: MVP

## Problem

App Store submission requires privacy policy URL, app metadata, app privacy answers, screenshots, age rating, support URL, and review notes.

## User Value

Users and Apple reviewers get clear product, privacy, and support information before install.

## Scope

- Add PrivacyInfo.xcprivacy.
- Draft privacy answers.
- Draft age rating answers.
- Draft App Store metadata.
- Add public privacy/support pages.
- Add screenshot generation flow.

## Out Of Scope

- Legal review.
- Final App Store Connect data entry.
- Paid marketing assets.

## Acceptance Criteria

- [x] Privacy manifest exists in the app target.
- [x] Privacy policy page exists.
- [x] Support page exists.
- [x] Metadata draft exists.
- [x] Privacy answers draft exists.
- [x] Age rating draft exists.
- [x] Screenshot generation script exists.
- [x] Public pages are deployed.
- [ ] App Store Connect record is completed.

## Test Expectations

- `make test`
- `make build-ios`
- Screenshot script completes on simulator.

## Design Notes

Metadata must keep the app clearly unofficial and entertainment-only.

## Data And API Notes

Privacy answers must be revisited if analytics, crash reporting, notifications, or live sports-data providers are added.

## Agent Tribunal

Required: No

Roles:

- Builder: Codex
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

- Public pages are deployed at `https://bracket48.app/`.
- GitHub Pages is currently configured in legacy `gh-pages` branch mode; public site changes must be published to `gh-pages` until Pages is switched to GitHub Actions mode.
- 2026-06-07: Added `make archive-ios`, `make upload-ios`, App Store Connect export options, and `docs/APP_STORE_SUBMISSION.md`. A local Release archive succeeds at `Build/Archives/Bracket48.xcarchive`; upload is blocked until the App Store Connect app record exists for bundle ID `app.bracket48.Bracket48`.
