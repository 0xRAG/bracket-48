# WCB-030: Device UX Polish Pass

Status: Backlog
Owner: Unassigned
Priority: P2
Phase: MVP

## Problem

Small device-only layout, navigation, keyboard, and state issues are easiest to catch through real use. We need a parking lot for final polish from Ryan's physical-device testing.

## User Value

The app feels more native, stable, and trustworthy at launch.

## Scope

- Triage fresh device feedback.
- Fix launch-blocking visual or interaction issues.
- Keep changes scoped and low-risk.
- Rebuild and install on device after fixes.

## Out Of Scope

- New product features.
- Major navigation redesign.
- Non-launch-critical visual experimentation.

## Acceptance Criteria

- [ ] Fresh device feedback is collected.
- [ ] P0/P1 UX issues are fixed.
- [ ] Remaining non-blocking nits are documented.
- [ ] Latest build is installed on physical device after fixes.

## Test Expectations

- Manual device verification for each fixed issue.
- `make build-ios` before install.

## Design Notes

Prioritize native Apple interaction expectations, readable layouts, and clear recovery from backend/auth states.

## Data And API Notes

None.

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

Keep this open until Ryan provides the next batch of device feedback.
