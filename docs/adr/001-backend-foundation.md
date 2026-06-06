# ADR 001: Backend Foundation

Status: Accepted
Date: 2026-05-30

## Context

The prototype currently uses local Swift state and `UserDefaults`. The MVP needs authenticated users, private groups, invite links, standalone brackets, bracket entries into groups, and eventually scoring/leaderboards.

## Decision

Use Supabase as the initial backend foundation:

- Postgres for relational data and constraints.
- Supabase Auth for Apple-backed user sessions.
- Row Level Security for per-user and per-group access control.
- Edge Functions later for workflows that should not live in the client, such as invite redemption hardening, scoring jobs, provider ingestion, and admin corrections.

Keep the SwiftUI app buildable during migration by introducing iOS service protocols and DTOs before replacing the prototype app model.

## Consequences

- We get a real database, auth, and generated REST/Realtime surfaces quickly.
- MVP data can be modeled with normal relational constraints instead of app-only checks.
- RLS policies become a core part of correctness and must be reviewed carefully.
- The app should isolate Supabase-specific code behind service boundaries so we can change backend strategy later if needed.

## Follow-Ups

- WCB-013: Apple Sign In Backend Auth
- WCB-014: Real Groups And Invites
- WCB-015: Real Bracket Persistence
