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
- [ ] Public pages are deployed.
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

GitHub CLI auth is currently invalid on this machine, so Pages deployment may require re-authentication or manual enablement.
