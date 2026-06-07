# Physical Device QA

Run this checklist against the latest build installed on a physical iPhone and connected to the hosted Supabase backend.

## Device And Build

- Date:
- Tester:
- Device:
- iOS version:
- App version/build:
- Backend project:

## Account And Profile

| Check | Expected | Result | Notes |
| --- | --- | --- | --- |
| Fresh Sign in with Apple | User reaches Home and first name appears |  |  |
| Sign out and sign back in | Display name persists |  |  |
| Profile color selector | Color changes tab tint, icons, and key accents |  |  |
| Delete account with disposable user | User is removed and returned to sign-up |  |  |

## Brackets

| Check | Expected | Result | Notes |
| --- | --- | --- | --- |
| Create group-stage bracket | Can rank all groups and select exactly 8 third-place advancers |  |  |
| Save group-stage bracket | Brackets tab shows saved group-stage unit |  |  |
| Create knockout bracket | Knockout selector opens from saved group-stage bracket |  |  |
| Save knockout bracket | App returns to Brackets home |  |  |
| View saved bracket | Swipe-back and back navigation return to Brackets |  |  |
| Delete unentered bracket | Deletion succeeds |  |  |
| Delete entered bracket | App blocks deletion until withdrawn from group |  |  |

## Groups And Invites

| Check | Expected | Result | Notes |
| --- | --- | --- | --- |
| Create group | Group appears in Groups tab with invite/share available in detail view |  |  |
| Enter bracket into group | Group shows full bracket entered |  |  |
| View group detail | Participants, standings, and bracket rows are visible |  |  |
| View another participant bracket | Tapping row opens read-only bracket |  |  |
| Share invite link | Share sheet opens with `https://bracket48.app/join/?code=...` |  |  |
| Open invite link from Safari/Messages | App opens to invite flow |  |  |
| Join by manual code | Join succeeds and input/card state resets cleanly |  |  |
| Invalid invite | App shows clear invalid invite state |  |  |

## Results And Leaderboards

| Check | Expected | Result | Notes |
| --- | --- | --- | --- |
| Group leaderboard | Shows current points and possible points remaining |  |  |
| Group detail standings | Rows match backend leaderboard order |  |  |
| Winner fixture/screenshot route | Winner screen renders final standings and no-prizes copy |  |  |

## Public Site

| Check | Expected | Result | Notes |
| --- | --- | --- | --- |
| `https://bracket48.app` | Loads public landing page over HTTPS |  |  |
| Privacy URL | Loads privacy page |  |  |
| Support URL | Loads support page |  |  |
| AASA | Universal Link association file is reachable |  |  |

## Final Notes

- Launch blockers:
- Non-blocking polish:
- Follow-up tickets:
