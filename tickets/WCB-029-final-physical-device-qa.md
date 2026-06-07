# WCB-029: Final Physical Device QA Checklist

Status: In Progress
Owner: Codex
Priority: P1
Phase: MVP

## Problem

The app has many end-to-end flows that depend on Apple Sign In, Universal Links, Supabase, device state, and native navigation. Before App Store submission, those flows need one deliberate physical-device pass.

## User Value

Users get fewer launch-day surprises across sign-in, bracket creation, group creation, invites, scoring views, and account deletion.

## Scope

- Create a physical-device QA checklist.
- Cover sign-in, display name persistence, profile color, bracket CRUD, group CRUD, invite join, bracket entry, group details, and account deletion.
- Record pass/fail notes and issues found.
- Identify launch-blocking bugs.

## Out Of Scope

- Automated XCUITest suite.
- Exhaustive device matrix.
- App Store review metadata.

## Acceptance Criteria

- [x] QA checklist exists in `docs/`.
- [ ] Checklist covers the core production user journey.
- [ ] Checklist includes expected results and notes fields.
- [ ] Physical device pass is completed before submission.

## Test Expectations

- Run against the latest device build connected to the hosted backend.
- Use at least two accounts for invite/member visibility where feasible.

## Design Notes

Keep the checklist crisp enough to run repeatedly.

## Data And API Notes

Account deletion checks should use disposable accounts unless Ryan explicitly chooses to test with his own account.

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

Suggested after backlog cleanup as final launch QA.

Created `docs/PHYSICAL_DEVICE_QA.md`. Physical device execution remains open before submission.
