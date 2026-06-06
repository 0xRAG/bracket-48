# Design Direction

## Goal

The app should feel native to iOS, trustworthy enough for a real competition, and fun enough that people want to check it throughout the tournament.

The target feeling is:

- Apple-native
- Fast
- Clear
- Trustworthy
- Energetic
- Social

Avoid making the app feel like a sportsbook, fantasy sports dashboard, or generic sports-news site. This is a friendly pool app first.

## Apple Design Foundations

Use Apple's Human Interface Guidelines as the baseline, especially:

- Navigation and tab bars: https://developer.apple.com/design/human-interface-guidelines/tab-bars
- Materials and visual hierarchy: https://developer.apple.com/design/human-interface-guidelines/materials
- iOS app design guidance: https://developer.apple.com/design/human-interface-guidelines

Practical implications:

- Use standard iOS navigation patterns.
- Prefer SwiftUI system components before custom controls.
- Use SF Symbols for iconography.
- Use Dynamic Type and semantic text styles.
- Support light mode and dark mode from the beginning.
- Respect safe areas, system gestures, and platform conventions.
- Use haptics sparingly for high-confidence moments, like submitting picks or winning a round.
- Make content feel primary and chrome feel secondary.

## Navigation Model

Use a tab-based app structure for top-level destinations.

Recommended MVP tabs:

- Home
- Groups
- Picks
- Leaderboard
- Profile

Tab behavior:

- Tabs are for primary navigation only.
- Creation flows, edit flows, and filters should not become tabs.
- The selected tab should always preserve context when possible.
- Use badges only for timely tournament actions, such as "knockout bracket open" or "picks closing soon."

Screen hierarchy:

- Use navigation stacks for drill-down flows.
- Use sheets for focused creation/editing tasks.
- Use confirmation dialogs for destructive or high-commitment actions.
- Use full-screen covers only for immersive flows that need full attention, such as completing a bracket.

## Visual Identity

The product name is `Bracket 48`. The app should imply international soccer bracket energy without copying official tournament branding or implying affiliation.

Use:

- Deep green as the field/sport anchor
- Bright accent colors for tournament moments
- Clean white/black system backgrounds
- Subtle flag/team color accents in team rows
- Card-like grouped content only where it helps scanning
- Tournament graphics based on brackets, paths, standings, and match tiles
- Clear entertainment-only language in onboarding and Profile

Avoid:

- Official tournament marks, trophy replicas, or event branding unless licensed
- Cash reward, prize, sportsbook, betting, gambling, or sweepstakes language
- Heavy gradients as the main visual language
- Overly dark sports-betting aesthetics
- Confetti everywhere
- Decorative imagery that competes with picks and standings
- Dense fantasy-sports table overload

## Design Tokens

These are starting points, not final brand values.

### Color

- `AppAccent`: energetic green
- `AppAccentSecondary`: tournament gold
- `Success`: system green
- `Warning`: system orange
- `Eliminated`: system red
- `Pending`: secondary label
- `Locked`: tertiary label

Use system colors wherever possible:

- `Color.primary`
- `Color.secondary`
- `Color(.systemBackground)`
- `Color(.secondarySystemBackground)`
- `Color(.tertiarySystemBackground)`
- `Color(.separator)`

### Typography

Use Apple's semantic text styles:

- Large title for top-level dashboards
- Title 2 or title 3 for phase headers
- Headline for team names and leaderboard rows
- Subheadline for match metadata
- Caption for status, lock windows, and point details

Do not use fixed font sizes unless a component truly needs it.

### Shape

- Prefer system list/grouped-list styling.
- Keep custom cards at modest radii.
- Use circular or capsule shapes for compact statuses and avatars.
- Avoid making every surface a large rounded card.

### Motion

Motion should clarify state changes:

- Picks advancing through a bracket
- Leaderboard rank changes
- Lock/open transitions
- Successful submission

Avoid motion that delays common tasks.

## Core Screens

### Home

Purpose:

- Tell the user what matters now.

Content:

- Current tournament phase
- Next lock deadline
- Open action: make picks, edit picks, view leaderboard
- User's best/active group
- Countdown or next match

Tone:

- Calm, direct, tournament-aware.

### Groups

Purpose:

- Let users manage their pools.

Content:

- Joined groups
- Create group
- Join by code/link
- Group type: full tournament, group-stage only, knockout only
- Member count and lock status

### Picks

Purpose:

- Let users make and review predictions.

Group-stage mode:

- Show one group at a time or a compact group grid.
- Make exact 1 through 4 ordering easy.
- Clearly show what is locked and what is editable.

Knockout mode:

- Use a bracket-first visual layout.
- Provide compact matchup cards.
- Keep the champion pick emotionally prominent.

### Leaderboard

Purpose:

- Make competition legible and social.

Content:

- Rank
- Display name
- Total points
- Group-stage points
- Knockout points
- Max possible points
- Movement since previous scoring update

### Profile

Purpose:

- Account settings, display name, favorite team, notification preferences.

## Tone And Copy

Use short, clear labels:

- "Make picks"
- "Review picks"
- "Locked"
- "Open until"
- "Knockout bracket opens after group stage"
- "One entry per group"

Avoid:

- Long explanations inside primary screens
- Marketing copy
- Jokes in critical scoring or lock states
- Ambiguous tournament terms

## Accessibility

Required from MVP:

- Dynamic Type support
- VoiceOver labels for team rows, matchup choices, and point statuses
- Color is never the only state indicator
- Minimum tappable target size of 44x44 points
- Sufficient contrast in light and dark mode
- Reduced Motion support

## Design Review Checklist

Every feature should answer:

1. Does this use standard iOS interaction patterns where possible?
2. Is the current tournament state obvious?
3. Can the user tell what is open, locked, submitted, correct, and eliminated?
4. Does the screen work in light and dark mode?
5. Does the design avoid looking like gambling or official tournament branding?
6. Does the experience still feel fun?
