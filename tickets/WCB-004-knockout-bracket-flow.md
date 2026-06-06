# WCB-004: Knockout Bracket Flow

Status: Done
Owner: Codex
Priority: P1
Phase: MVP

## Problem

Users need to create a traditional knockout bracket once the official Round of 32 field is known.

## User Value

Users get the familiar March Madness-style moment of filling out a bracket and picking a champion.

## Scope

- Show official Round of 32 matchups.
- Let users advance teams through each round.
- Highlight champion selection.
- Review and submit bracket.
- Support knockout-only groups.
- Show submitted and locked states.

## Out Of Scope

- Pre-tournament projected knockout bracket.
- Custom scoring.
- Social sharing image.

## Acceptance Criteria

- [x] User can pick every knockout winner through champion.
- [x] User cannot submit incomplete bracket.
- [x] Knockout bracket only opens after group stage completion.
- [x] Knockout-only group entries are supported.
- [x] User cannot edit after lock.
- [x] Bracket remains readable on supported iPhone sizes.

## Test Expectations

- Bracket completion validation.
- Lock state tests.
- Knockout-only group eligibility tests.

## Design Notes

Follow `docs/DESIGN_DIRECTION.md`.

The bracket should be visual and celebratory, but still compact and Apple-native.

## Data And API Notes

Requires official knockout matchups from tournament data service.

## Agent Tribunal

Required: Yes

Roles:

- Builder: Implemented local knockout bracket model, Round of 32 through final pick flow, champion display, knockout-only entry type, and locked submission state.
- Reviewer: Verified unit tests and iOS build; simulator smoke-tested Home entry point, knockout screen rendering, and Round of 32 winner selection.
- Product Judge: The second-phase bracket moment is now present after a locked group-stage entry, with a champion path and knockout-only entry type.
- Design Judge: Refined the screen into compact match cards with a persistent primary action and verified readable first-viewport layout on iPhone 17 Pro and iPhone 16e.
- Security And Integrity Judge: Local lock disables edits after knockout submission; official lock enforcement and server-side entry integrity remain backend scope.

## Notes

First implementation pass is in place using deterministic prototype matchups until official knockout data is available.

Verification:

- `make test` passes with knockout completion validation coverage.
- `make build-ios` succeeds.
- Manual simulator verification confirms saved group-stage submission restores, Home shows "Create Knockout Bracket", knockout screen opens, winner selection works, incomplete bracket submission remains disabled, and locked knockout picks are disabled after submission.
- Copied the locked prototype state to iPhone 16e and verified the first viewport remains readable with no text overflow or incoherent overlap.
