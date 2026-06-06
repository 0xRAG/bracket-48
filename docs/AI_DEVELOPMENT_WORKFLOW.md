# AI Development Workflow

## Purpose

This project should be designed for fast AI-assisted development without letting speed outrun judgment.

The workflow uses:

- Small tickets
- Clear acceptance criteria
- Automated tests
- Agent tribunal review
- Human final decision-making

## Ticket Lifecycle

Statuses:

- `Backlog`
- `Ready`
- `In Progress`
- `In Review`
- `Needs Changes`
- `Done`

Every ticket should include:

- Problem statement
- User value
- Scope
- Out of scope
- Acceptance criteria
- Test expectations
- Design notes, if applicable
- Data/model implications, if applicable

## Agent Roles

Use these roles during AI-assisted development.

### Builder

Implements the ticket.

Responsibilities:

- Read the relevant plan, ticket, and docs.
- Make the smallest complete change.
- Add or update tests.
- Update docs if behavior changes.
- Produce a concise implementation note.

### Reviewer

Reviews for correctness and maintainability.

Responsibilities:

- Look for bugs, regressions, missing tests, and unclear code.
- Verify acceptance criteria.
- Check that the implementation fits existing architecture.
- Do not bikeshed style if formatters and lint rules cover it.

### Product Judge

Reviews product behavior.

Responsibilities:

- Confirm the feature matches the intended user journey.
- Check edge cases and empty states.
- Ensure copy is clear.
- Check whether the feature increases or reduces user confusion.

### Design Judge

Reviews UX and visual quality.

Responsibilities:

- Check Apple-native interaction patterns.
- Check light and dark mode implications.
- Check accessibility basics.
- Check whether the app still feels fun, trustworthy, and clearly unofficial.

### Security And Integrity Judge

Reviews trust, abuse, and data integrity.

Responsibilities:

- Check auth assumptions.
- Check authorization boundaries.
- Check one-entry-per-pool enforcement.
- Check scoring and leaderboard tamper resistance.
- Check data-provider ingestion and admin correction risks.

## Agent Tribunal Review

For important tickets, run a tribunal review before marking the ticket done.

Required tribunal for:

- Auth
- Scoring
- Lock rules
- Leaderboards
- Group membership
- Data provider ingestion
- Admin tools
- Payment or prize features, if ever added

Optional tribunal for:

- UI polish
- Copy updates
- Internal refactors

### Tribunal Process

1. Builder summarizes the change.
2. Reviewer checks code and tests.
3. Product Judge checks user behavior.
4. Design Judge checks interface and accessibility.
5. Security And Integrity Judge checks trust boundaries.
6. Findings are labeled:
   - `Blocker`
   - `High`
   - `Medium`
   - `Low`
   - `Nit`
7. Builder fixes all blockers and high-priority findings.
8. Human decides whether medium/low findings are required before merge.

## Review Output Template

```md
## Tribunal Review

Ticket: WCB-000
Change:

### Builder Summary

### Reviewer Findings

### Product Findings

### Design Findings

### Security And Integrity Findings

### Required Fixes

### Deferred Follow-Ups

### Final Recommendation
```

## AI Working Rules

- One ticket per branch when practical.
- Keep commits focused.
- Do not mix product decisions with unrelated refactors.
- Do not change scoring rules without updating tests and docs.
- Do not introduce new dependencies without a short rationale.
- Do not bypass failing tests without documenting the reason.
- When uncertain about product behavior, capture the decision in the ticket.

## Human Control Points

Human approval is required for:

- App name and branding
- Scoring rule changes
- Sports data provider choice
- Backend platform choice
- Sign in with Apple configuration
- Public launch settings
- Any paid pool, prize, gambling, or compliance-related feature
