# WCB-010: Group Invite Sharing

Status: Done
Owner: Codex
Priority: P0
Phase: MVP

## Problem

Users can create prototype groups, but there is no way to share a group invite link with friends.

## User Value

Players can invite friends into a pool immediately after creating it, which is core to bracket competition.

## Scope

- Represent a shareable group invite link in the prototype.
- Show the invite link or code from the Groups tab.
- Add a native share affordance for the link.
- Keep invite link behavior local/prototype-only until backend deep links exist.

## Out Of Scope

- Real deep-link routing.
- Backend invite redemption.
- Invite expiration.
- Invite permission management.

## Acceptance Criteria

- [x] Created groups show an invite code.
- [x] Created groups show a shareable join URL.
- [x] Users can open the native share sheet for the group link.
- [x] Empty group state explains that a group must be created before sharing.

## Test Expectations

- iOS Simulator build.
- Manual simulator verification of Groups tab share affordance.

## Design Notes

Use Apple-native `ShareLink` where available.

## Data And API Notes

Prototype URL can use a placeholder production-style host until backend routing exists.

## Agent Tribunal

Required: No

## Notes

Implemented in the Groups tab with a prototype invite code, production-style placeholder join URL, selectable link text, and native `ShareLink`.

Verification:

- `make build-ios` succeeds.
- Manual simulator check confirms the Groups tab shows the invite code/link and opens the native share sheet.
