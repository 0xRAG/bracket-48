# WCB-024: Profile Primary Color Selector

Status: Backlog
Owner: Unassigned
Priority: P3
Phase: V1

## Problem

Bracket 48 has a strong default green accent, but users do not have a way to personalize the app's primary color.

## User Value

Users can make the app feel a bit more personal while keeping the overall Bracket 48 visual system intact.

## Scope

- Add a Profile setting for primary color.
- Keep green as the default.
- Offer a small curated palette: green, purple, blue, yellow, and red.
- Apply the selected color to primary buttons, active tab accents, key icons, and other primary accent surfaces.
- Persist the selection per user when signed in.
- Fall back to the local/default setting while offline or before profile sync completes.

## Out Of Scope

- Arbitrary custom colors or color pickers.
- Full theme customization.
- Per-group color themes.
- Changing team colors or flag styling.

## Acceptance Criteria

- [ ] Profile includes a primary color selector using color swatches.
- [ ] Green is selected by default for new users.
- [ ] The selected color updates primary app accents consistently.
- [ ] The color choice persists after sign out/sign in.
- [ ] All palette options maintain readable contrast in light and dark mode.

## Test Expectations

- Unit or service tests for saving/loading the selected profile color if profile persistence is extended.
- Manual UI pass in light and dark mode for each palette option.

## Design Notes

Use compact circular swatches or Apple-style selectable rows in Profile. Avoid making the whole app feel like a separate one-note theme; the color should be an accent, not a full repaint.

## Data And API Notes

Likely add a nullable `primary_color` field to `app_users` with a constrained enum/string value such as `green`, `purple`, `blue`, `yellow`, `red`.

## Agent Tribunal

Required: Yes

Roles:

- Builder:
- Reviewer:
- Product Judge:
- Design Judge:
- Security And Integrity Judge:

## Notes

Requested by Ryan after the Groups overview cleanup. Green should remain the default.
