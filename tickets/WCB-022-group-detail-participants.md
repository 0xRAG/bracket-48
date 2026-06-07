# WCB-022: Group Detail And Participant Brackets

Status: Done
Owner: Codex
Priority: P1
Phase: MVP

## Problem

Groups could be created, joined, and entered, but there was no dedicated group detail screen for reviewing members, standings, or other submitted brackets.

## User Value

Players can tap a group, see who is participating, check current standings, and inspect read-only group-stage or knockout picks submitted by other members.

## Scope

- Add a tappable group row from the Groups tab.
- Add a group detail screen with invite sharing, participants, standings, and entered brackets.
- Add read-only bracket viewers for group-stage and knockout entries.
- Load participants and entered brackets from Supabase.
- Update RLS so active group members can view co-member display names and entered bracket picks.

## Out Of Scope

- Commenting or reactions on brackets.
- Editing another user's bracket.
- Prize, payout, or wagering mechanics.

## Acceptance Criteria

- [x] Tapping a group opens a native stack detail screen.
- [x] Group detail lists active participants.
- [x] Group detail shows combined standings by participant.
- [x] Group detail lists submitted group-stage and knockout entries.
- [x] Tapping an entry opens a read-only bracket view.
- [x] Supabase policies restrict profile and bracket visibility to active co-members.

## Agent Tribunal

Required: Yes

Roles:

- Builder: Codex
- Reviewer:
- Product Judge:
- Security And Integrity Judge:
