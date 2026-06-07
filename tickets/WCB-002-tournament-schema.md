# WCB-002: Tournament Data Schema

Status: Done
Owner: Codex
Priority: P0
Phase: MVP

## Problem

The app needs a durable data model for the 2026 World Cup tournament structure, including teams, groups, matches, standings, and knockout slots.

## User Value

Users can make picks against the real tournament structure and see accurate tournament state.

## Scope

- Define tournament, team, group, match, standings, and knockout slot models.
- Represent tournament phases.
- Support provider-supplied match updates.
- Support admin corrections.
- Support knockout-only group creation after the group stage.

## Out Of Scope

- Choosing the sports data provider.
- Building the admin UI.
- Building the iOS pick UI.

## Acceptance Criteria

- [x] Schema represents 12 groups of 4 teams.
- [x] Schema represents top 2 plus 8 third-place advancement.
- [x] Schema supports Round of 32 through champion.
- [x] Schema supports match status and result updates.
- [x] Schema supports data-provider IDs.
- [x] Schema supports admin correction audit metadata.

## Test Expectations

- Data fixture can represent a full tournament.
- A group-stage completion state can be detected.
- Knockout bracket open state can be detected.
- Provider updates can be matched to internal matches.

## Design Notes

No direct UI.

## Data And API Notes

This ticket should produce either database migrations or a detailed schema contract, depending on backend choice.

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

This is a dependency for picks, scoring, provider ingestion, and leaderboards.

Implemented in `App/Bracket48Core/Sources/Bracket48Core/TournamentSchema.swift`.

The SwiftUI prototype now adapts its local fixture data from the core `Tournament` schema.

Closed after the app, Sportmonks ingestion, scoring, and UI flows all moved onto the shared tournament schema.
