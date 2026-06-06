# WCB-017: Branding And Entertainment Disclaimer

Status: Completed
Owner: Codex
Priority: P1
Phase: MVP

## Problem

The app needed a production-ready identity that does not imply FIFA, official tournament, team, federation, betting, or prize affiliation.

## User Value

Users can understand the product as a friendly bracket game for private groups, while the app presents a clearer and more App Store-ready brand posture.

## Scope

- Choose a user-facing product name.
- Add app icon and brand mark assets.
- Update onboarding copy.
- Add visible unofficial and entertainment-only disclaimer language.
- Document brand constraints for future design work.

## Out Of Scope

- Legal trademark clearance.
- Paid pools, cash prizes, betting, gambling, or sweepstakes.
- Renaming Swift modules, target names, Supabase tables, or bundle identifiers.

## Acceptance Criteria

- [x] User-facing app name avoids official tournament naming.
- [x] App icon avoids official logos, trophy replicas, country crests, and prize imagery.
- [x] Sign-up screen uses the new brand mark and entertainment-only positioning.
- [x] Profile includes an affiliation and no-prizes disclaimer.
- [x] Design docs capture the brand constraints.

## Test Expectations

- `make test`
- `make build-ios`

## Design Notes

The selected name is `Bracket 48`. The visual direction uses abstract pitch and bracket geometry rather than official marks.

## Data And API Notes

No backend schema changes. Internal module and bundle identifiers remain unchanged for this pass.

## Agent Tribunal

Required: No

Roles:

- Builder: Codex
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

This is not a legal clearance. A formal trademark review should happen before broad public launch.
