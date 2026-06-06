# WCB-009: Tab Navigation Shell

Status: Done
Owner: Codex
Priority: P0
Phase: MVP

## Problem

The prototype is currently a single-screen state machine. Users need persistent top-level navigation for Home, Brackets, and Groups.

## User Value

Users can return to their brackets and groups without backing through a linear onboarding flow.

## Scope

- Add a signed-in tab shell.
- Keep Home as the current dashboard.
- Add a Brackets tab for viewing and creating group-stage and knockout brackets.
- Add a Groups tab for viewing and creating groups.
- Preserve the current sign-up flow before tabs appear.

## Out Of Scope

- Backend navigation state.
- Deep links.
- Multi-account support.

## Acceptance Criteria

- [x] Signed-in users see Home, Brackets, and Groups tabs.
- [x] Home retains the current dashboard experience.
- [x] Brackets tab shows group-stage and knockout bracket status.
- [x] Groups tab shows current group status.
- [x] Existing create bracket, create group, submit, and knockout flows still work.

## Test Expectations

- `make test`
- iOS Simulator build
- Manual simulator tab smoke test

## Design Notes

Use native SwiftUI `TabView` with SF Symbol tab icons.

## Data And API Notes

Keep tab state local to the prototype app model.

## Agent Tribunal

Required: No

## Notes

Implemented with a signed-in `TabView` over Home, Brackets, and Groups. The Brackets tab routes into existing group-stage, submitted, and knockout screens. The Groups tab shows current prototype group state and an Add section, with multi-group membership left to backend-backed follow-up work.

Verification:

- `make test` passes.
- `make build-ios` succeeds.
- Manual simulator smoke test confirms Home, Brackets, and Groups tabs render and preserve existing navigation paths.
