# App Store Privacy Answers Draft

These answers reflect the current app implementation as of June 6, 2026. Revisit before submission if analytics, crash reporting, notifications, ads, or sports-data SDKs are added.

## Tracking

- Do you or your third-party partners use data from this app to track users? No.
- Does the app use App Tracking Transparency? No.
- Tracking domains: None.

## Data Types Collected

### Contact Info: Name

- Collected: Yes.
- Linked to user: Yes.
- Used for tracking: No.
- Purpose: App Functionality.
- Reason: User display name is shown in the app and group context.

### Contact Info: Email Address

- Collected: Yes, through Sign in with Apple/Supabase Auth when Apple provides it.
- Linked to user: Yes.
- Used for tracking: No.
- Purpose: App Functionality.
- Reason: Account authentication and account management.

### Identifiers: User ID

- Collected: Yes.
- Linked to user: Yes.
- Used for tracking: No.
- Purpose: App Functionality.
- Reason: Supabase Auth user ID links brackets, groups, memberships, and account deletion to the signed-in user.

### User Content: Gameplay Content

- Collected: Yes.
- Linked to user: Yes.
- Used for tracking: No.
- Purpose: App Functionality.
- Reason: Bracket picks, knockout picks, scores, and saved entries are core app functionality.

### User Content: Other User Content

- Collected: Yes.
- Linked to user: Yes.
- Used for tracking: No.
- Purpose: App Functionality.
- Reason: Group names, invite codes, and group memberships are core app functionality.

## Data Types Not Currently Collected

- Health and Fitness
- Financial Info
- Location
- Sensitive Info
- Contacts
- Photos or Videos
- Audio Data
- Browsing History
- Search History
- Purchases
- Usage Data, unless later adding analytics
- Diagnostics, unless later adding crash reporting
- Other Data

## Privacy Choices URL

Use the Privacy Policy URL unless we add a dedicated choices page:

https://0xrag.github.io/bracket-48/privacy/
