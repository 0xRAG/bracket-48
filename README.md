# Bracket 48

Native iOS soccer tournament bracket pool app.

Users sign in with Apple, join groups, submit group-stage predictions before the tournament, submit knockout brackets after the Round of 32 is known, and compare leaderboards with friends.

Bracket 48 is an independent, unofficial app for entertainment with friends. It is not affiliated with or endorsed by tournament organizers, teams, or federations, and it does not offer cash rewards, prizes, betting, or gambling.

## Current Docs

- Product plan: `BRACKET_48_APP_PLAN.md`
- Design direction: `docs/DESIGN_DIRECTION.md`
- Engineering standards: `docs/ENGINEERING_STANDARDS.md`
- AI development workflow: `docs/AI_DEVELOPMENT_WORKFLOW.md`
- Production runbook: `docs/PRODUCTION_RUNBOOK.md`
- Physical device QA: `docs/PHYSICAL_DEVICE_QA.md`
- Tickets: `tickets/`

## Current Code

- `App/Bracket48Core`: Swift package for shared domain logic and scoring.
- `App/Bracket48`: SwiftUI iOS app generated with XcodeGen.
- `Backend`: Supabase/Postgres backend foundation, migrations, and setup notes.

## Local Workflow

The core scoring package is active and the SwiftUI app can be generated and built locally.

Commands:

```sh
make generate
make test
make build-ios
make tickets
```

Backend setup starts in `Backend/README.md`.

Planned commands once the app skeleton and local tools are installed:

```sh
make format
make lint
make ci
```

## App Flow

The current app supports this backend-backed journey:

1. Sign in with Apple.
2. Move between Home, Brackets, and Groups tabs.
3. Create and share private groups before or after filling out a bracket.
4. Join a group by pasting either an invite code or join URL.
5. Create a group-stage bracket from the real 2026 tournament groups.
6. Submit the group-stage bracket as a standalone bracket.
7. Continue directly into the knockout bracket without adding the bracket to a group.
8. Advance winners through the knockout rounds toward a champion pick.
9. View saved brackets and scoring preview.

The bracket fixture is backed by the core tournament schema and uses the real 48-team 2026 group field, with system-rendered country flag icons in the UI.

The core package also models pools, memberships, invite codes, entry phases, submission lock windows, and one-entry-per-user validation for future backend integration.

The tabbed app supports multiple groups and invite links. Group creation is independent of bracket creation, with membership and bracket persistence backed by Supabase.

## Product Decisions

- Group-stage picks lock before the tournament.
- MVP supports exact group order.
- Users get one entry per pool.
- MVP uses one default scoring system.
- Match results should come from a sports data provider, with admin correction fallback.
- Knockout-only late entry is a separate group type created after the group stage ends and before the knockout stage starts.
