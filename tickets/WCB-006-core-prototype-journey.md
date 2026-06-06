# WCB-006: Core Prototype Journey

Status: Done
Owner: Codex
Priority: P0
Phase: MVP

## Problem

The prototype needs to demonstrate the core journey: sign up, create bracket, create group, and submit bracket.

## User Value

We can evaluate whether the app concept feels clear and compelling before investing in backend and production auth.

## Scope

- Prototype sign-up/onboarding screen.
- Local profile creation.
- Group-stage bracket creation using sample groups.
- Group creation.
- Bracket submission confirmation.
- Simple post-submission summary.

## Out Of Scope

- Live results.
- Real groups/invites.
- Real Apple identity token validation.
- Knockout bracket creation.
- Leaderboard updates.

## Acceptance Criteria

- [x] User can complete sign-up locally.
- [x] User can rank sample group teams.
- [x] User can create a group.
- [x] User can submit the bracket into the group.
- [x] App shows a submitted state.

## Test Expectations

- Build verification for Simulator.
- Manual journey verification in Simulator if available.

## Design Notes

Use Apple-native SwiftUI navigation and form patterns with a polished tournament feel.

## Data And API Notes

Use fixture teams and groups until WCB-002 is implemented.

## Agent Tribunal

Required: Yes

Roles:

- Builder: Implemented native SwiftUI prototype journey.
- Reviewer: Verified app builds and core package tests pass.
- Product Judge: Journey demonstrates sign up, bracket creation, group creation, and submission with live scoring explicitly deferred.
- Design Judge: Uses Apple-native navigation, form controls, pinned primary actions, and a polished tournament visual treatment.
- Security And Integrity Judge: Prototype remains local-only; production Apple auth, backend groups, and score integrity controls are deferred by scope.

## Notes

This is the first end-to-end product prototype.

Manual simulator verification completed on iPhone 17 Pro, iOS 26.0:

1. Entered display name.
2. Continued to Home.
3. Opened Create Bracket.
4. Continued to Create Group.
5. Entered a group name.
6. Submitted the bracket.
7. Confirmed submitted state and scoring preview.
