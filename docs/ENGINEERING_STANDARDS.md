# Engineering Standards

## Goals

The codebase should be easy for humans and AI agents to change safely.

Priorities:

- Clear architecture
- Small testable units
- Automated formatting
- Automated linting
- Fast local tests
- CI enforcement before merging
- Explicit ticket and review workflow

## App Stack

Recommended:

- Native iOS app with SwiftUI
- Swift Concurrency
- Swift Package Manager
- XCTest and Swift Testing where appropriate
- SwiftLint
- SwiftFormat
- Backend API backed by PostgreSQL

Backend direction is still open between Supabase-first and custom API-first.

## Repository Shape

Recommended starting structure:

```text
.
├── App/
│   ├── Bracket48/
│   ├── Bracket48Tests/
│   └── Bracket48Core/
├── Backend/
├── docs/
├── tickets/
├── BRACKET_48_APP_PLAN.md
├── .swiftlint.yml
├── .swiftformat
└── Makefile
```

The actual Xcode project can be generated once we choose the app name and bundle identifier.

`App/Bracket48Core` is a Swift package for pure domain logic that can be tested before the app shell exists.

## Swift Architecture

Use feature-oriented modules:

- Auth
- Dashboard
- Groups
- GroupStagePredictions
- KnockoutBracket
- Leaderboards
- Profile
- TournamentData
- ScoringPreview

Each feature should keep:

- Views
- View models
- Domain models
- API DTOs or mappers
- Tests

Guidelines:

- Keep business rules out of SwiftUI views.
- Keep scoring logic in shared/testable domain code.
- Make API clients protocol-driven for tests.
- Prefer value types for domain models.
- Use async/await for network flows.
- Use dependency injection for services.

## Testing

Minimum expected coverage by area:

- Scoring engine: high coverage
- Bracket validation: high coverage
- Lock rules: high coverage
- API clients: contract or integration tests
- SwiftUI views: focused snapshot or state tests where valuable

Required test cases for MVP:

- Exact group order scoring
- Third-place advancement scoring
- One-entry-per-pool enforcement
- Full-tournament group scoring
- Knockout-only group scoring
- Lock deadline enforcement
- Provider result update idempotency
- Admin correction rescoring

## Formatting And Linting

Use:

- SwiftFormat for mechanical formatting
- SwiftLint for maintainability rules
- Xcode warnings treated seriously

Local commands should eventually include:

```sh
make format
make lint
make test
make ci
```

Until the Xcode project exists, these commands can be placeholders that document the expected workflow.

## CI

Recommended checks:

- Format check
- Lint
- Unit tests
- Build app for simulator
- Backend tests
- Database migration validation

No PR should merge unless CI is green or a human explicitly documents why an override is acceptable.

## Branching

Use short-lived feature branches.

Branch naming:

- `codex/<ticket-id>-short-description`
- `human/<ticket-id>-short-description`

Examples:

- `codex/WCB-001-scoring-engine`
- `human/WCB-014-design-system`

## Definition Of Done

A ticket is done when:

- Acceptance criteria are met.
- Tests are added or explicitly waived.
- Formatting and linting pass.
- Relevant docs are updated.
- Agent tribunal review has no blocking findings.
- The change is small enough to review.

## Decision Records

Use Architecture Decision Records for meaningful technical choices.

Store them in:

```text
docs/adr/
```

Suggested format:

- Status
- Context
- Decision
- Consequences
- Alternatives considered
