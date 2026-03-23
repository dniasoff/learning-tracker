# Privacy Policy

**Torah Learning Tracker**
**Last updated: March 23, 2026**

## Overview

Torah Learning Tracker ("the App") is a mobile application for managing daily Torah study. This privacy policy explains what data the App collects, how it is used, and your choices.

## Data We Collect

### Account Information
- **Email address** and **display name** — used for authentication and identifying your account.
- You may also sign in with **Google Sign-In**, which provides your name and email from your Google account.

### Learning Data
- Study progress (completions, bookmarks, streaks, goals, test scores)
- Reward and achievement status
- Curriculum selections and preferences

### App Preferences
- Display settings (font size, diacritics preference)
- Parent/tutor PINs — stored locally on your device only, hashed with bcrypt, and never transmitted to any server.

## Data We Do NOT Collect

- Location data
- Contacts, photos, or camera access
- Device identifiers or advertising IDs
- Analytics events or usage telemetry
- Crash reports

## How Your Data Is Used

- **Authentication**: Your email and name are used solely to create and manage your account via Firebase Authentication.
- **Cloud sync**: Learning progress is synced to Google Cloud Firestore so your data is available across devices and preserved if you reinstall the App. Data is scoped to your user account and not shared with other users.
- **Content delivery**: The App fetches Torah texts from the Sefaria public API (`sefaria.org`). These requests do not include any personal information.

## Third-Party Services

The App uses the following third-party services:

| Service | Purpose | Privacy Policy |
|---------|---------|----------------|
| Firebase Authentication | Account sign-in | [Google Privacy Policy](https://policies.google.com/privacy) |
| Cloud Firestore | Cloud data sync | [Google Privacy Policy](https://policies.google.com/privacy) |
| Google Sign-In | OAuth authentication | [Google Privacy Policy](https://policies.google.com/privacy) |
| Sefaria API | Torah text content | [Sefaria Privacy Policy](https://www.sefaria.org/privacy-policy) |

No data is sold to third parties. No data is shared with third parties for advertising or marketing purposes.

## Data Storage and Security

- Cloud data is stored in Google Cloud Firestore, secured by Firebase Authentication.
- Local data is stored on-device in an encrypted SQLite database and secure storage.
- PINs are hashed with bcrypt before storage and are never transmitted.
- The App supports full offline operation; data syncs when connectivity is restored.

## Children's Privacy

The App may be used by children under parental supervision. The App includes a parent PIN lock feature to restrict access to settings. We do not knowingly collect personal information from children beyond what is described in this policy. A parent or guardian must create the account.

## Data Retention and Deletion

Your data is retained as long as you maintain an account. To delete your data:

1. Contact us at the email below to request account and data deletion, or
2. Delete your account through the App's settings (when available).

Upon account deletion, all associated data in Cloud Firestore will be removed.

## Your Rights

You may:
- Access your data through the App at any time
- Request a copy of your data
- Request deletion of your account and all associated data

## Changes to This Policy

We may update this privacy policy from time to time. Changes will be posted here with an updated "Last updated" date.

## Contact

If you have questions about this privacy policy, contact us at:

**Email**: dniasoff@gmail.com
