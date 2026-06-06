# WCB-019: Group Bracket View/Edit Flow

Status: In Progress
Owner: Codex
Priority: P1
Phase: MVP

## Problem

Viewing a completed group bracket routed to an old submitted screen and trapped users away from the Brackets dashboard. The group-stage form also showed duplicate drag affordances.

## User Value

Users can view saved group brackets in the same familiar form and edit them until the dependent knockout bracket exists.

## Scope

- Route group bracket view actions to the group-stage form.
- Allow editing saved group-stage brackets only before a linked knockout bracket exists.
- Save edits to Supabase.
- Remove duplicate drag affordance.
- Keep native back navigation.

## Out Of Scope

- Tournament deadline lock enforcement.
- Admin override tooling.
- Pool withdrawal UX.

## Acceptance Criteria

- [x] View Group Stage opens the group-stage form.
- [x] Saved group-stage bracket can be edited when no linked knockout bracket exists.
- [x] Saved group-stage bracket is read-only when linked knockout bracket exists.
- [x] Team rows show only one drag/reorder affordance.
- [x] Saved edits persist to Supabase.

## Test Expectations

- `make test`
- `make build-ios`
- Manual device test for editable and read-only saved brackets.

## Design Notes

The form title should distinguish saved group brackets from new bracket creation.

## Data And API Notes

Requires an RLS policy allowing group-stage bracket updates before a dependent knockout bracket exists.

## Agent Tribunal

Required: No

Roles:

- Builder: Codex
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes
