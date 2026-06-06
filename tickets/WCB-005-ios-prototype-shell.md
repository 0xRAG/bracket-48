# WCB-005: iOS Prototype Shell

Status: Done
Owner: Codex
Priority: P0
Phase: MVP

## Problem

The project needs a runnable native iOS prototype that can be built and opened in Simulator.

## User Value

We can validate the core app journey on-device before backend, provider, and polish work are complete.

## Scope

- Generate an Xcode project.
- Add a SwiftUI app target.
- Link the core scoring Swift package.
- Support a local in-memory prototype store.
- Build for iOS Simulator.

## Out Of Scope

- Real backend integration.
- Real Sign in with Apple production configuration.
- Live score updates.
- Persistent storage.

## Acceptance Criteria

- [x] Xcode project can be generated from source-controlled config.
- [x] App builds for an iOS Simulator destination.
- [x] App launches to an onboarding/sign-up screen.
- [x] Core package remains testable from `make test`.

## Test Expectations

- `make test`
- iOS Simulator build

## Design Notes

Follow `docs/DESIGN_DIRECTION.md`.

## Data And API Notes

Use local prototype data only.

## Agent Tribunal

Required: No

## Notes

This ticket creates the shell needed for the first user journey.

Implemented with XcodeGen in `project.yml`.
