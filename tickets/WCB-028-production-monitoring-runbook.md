# WCB-028: Production Monitoring And Runbook

Status: Done
Owner: Codex
Priority: P1
Phase: MVP

## Problem

Sportmonks sync, scoring, result overrides, invite flows, and account deletion now depend on hosted services. We need an operational checklist for detecting and responding to production issues.

## User Value

Users get faster recovery from stale scores, bad provider data, failed syncs, or backend incidents.

## Scope

- Document critical hosted systems and data flows.
- Document expected monitoring signals for Sportmonks sync, scoring, overrides, auth, database, and public site.
- Document incident triage steps.
- Document admin override and rescoring paths.
- Document scheduled pre-tournament and matchday checks.

## Out Of Scope

- Buying or configuring a paid observability platform.
- 24/7 on-call process.
- Formal incident-management policy.

## Acceptance Criteria

- [x] A production runbook exists in `docs/`.
- [x] Runbook covers result sync and scoring jobs.
- [x] Runbook covers admin overrides and rescoring.
- [x] Runbook covers invite/auth/account-deletion checks.
- [x] Runbook includes quick verification commands.

## Test Expectations

- Review commands against existing Makefile/scripts.
- Prefer rollback or read-only checks where possible.

## Design Notes

Keep it practical and short enough to use under pressure.

## Data And API Notes

Avoid writing secrets into the runbook. Use placeholder env vars and Supabase Vault references only.

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

Suggested after backlog cleanup as a production readiness item.

Implemented `docs/PRODUCTION_RUNBOOK.md` with routine checks, result sync/scoring triage, admin override flow, invite/auth/account-deletion checks, public site checks, and release gates.
