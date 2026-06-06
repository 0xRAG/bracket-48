# WCB-007: Local Prototype Persistence

Status: Done
Owner: Codex
Priority: P1
Phase: MVP

## Problem

The prototype currently stores profile, group, and bracket submission state in memory. Relaunching the app resets the journey.

## User Value

The prototype will feel more like a real app because submitted brackets and groups remain available after relaunch.

## Scope

- Persist local profile display name.
- Persist local group name.
- Persist group-stage bracket picks.
- Persist submitted state.
- Restore the app to the correct screen on launch.
- Keep persistence local-only until backend work begins.

## Out Of Scope

- Cloud sync.
- Real Sign in with Apple credential storage.
- Backend groups.
- Live score updates.

## Acceptance Criteria

- [x] User can submit a bracket and relaunch the app without losing it.
- [x] Submitted state restores after launch.
- [x] User can reset local prototype data.
- [x] Stored data uses a versioned local schema.

## Test Expectations

- Unit tests for encoding/decoding local app state.
- Manual simulator relaunch verification.

## Design Notes

Add reset affordance in Profile or a temporary prototype control.

## Data And API Notes

Prefer a small Codable local store for now. Avoid committing to SwiftData until persistence requirements are clearer.

## Agent Tribunal

Required: No

## Notes

Implemented with a small Codable `LocalPrototypeState` stored through `UserDefaults`.

Verification:

- `make test` passes with local state encoding/decoding coverage.
- `make build-ios` succeeds.
- Manual simulator flow verified on iPhone 17 Pro: sign up as Ryan, create group-stage bracket, create "Saturday Pool", submit bracket, terminate app, relaunch app, and confirm it restores to the submitted confirmation.
