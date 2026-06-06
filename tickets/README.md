# Ticket Tracking

Tickets live in this directory as Markdown files until a dedicated tracker is introduced.

## Naming

Use:

```text
WCB-000-short-title.md
```

Examples:

- `WCB-001-scoring-engine.md`
- `WCB-002-tournament-schema.md`
- `WCB-003-group-stage-picks.md`

## Ticket Template

```md
# WCB-000: Title

Status: Backlog
Owner: Unassigned
Priority: P0/P1/P2/P3
Phase: MVP/V1/Later

## Problem

## User Value

## Scope

## Out Of Scope

## Acceptance Criteria

- [ ]

## Test Expectations

## Design Notes

## Data And API Notes

## Agent Tribunal

Required: Yes/No

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes
```

## Priority

- `P0`: Blocks core MVP or correctness.
- `P1`: Required for MVP.
- `P2`: Important for V1 quality.
- `P3`: Nice to have.
