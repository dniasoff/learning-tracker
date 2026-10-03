# Privacy Policy

**Torah Learning Tracker**
**Last updated: October 3, 2026**

## Overview

Torah Learning Tracker ("the App") is a mobile application for managing daily Torah study. This privacy policy explains what data the App collects, how it is used, and your choices.

## Data We Collect

### Account Information
- **Email address** and **display name** — used for authentication and identifying your account.
- You may also sign in with **Google Sign-In**, which provides your name and email from your Google account.

### Learning Data
- Learning records (what was learnt and when, and any corrections), goals, tracks, streaks and test scores
- Reward and achievement status
- Curriculum selections and preferences
- A change history of edits made to a learner's goals, tracks and learning records, including who made each change and when (see "Tutor Access and Change History" below)

### Usage Analytics and Crash Reports
- **Usage analytics** (Google Analytics for Firebase): events about how the App's features are used, such as that a learning entry was recorded. Event data is limited to fixed categories and counts (for example, which curriculum and how many items). It never contains names, email addresses, free text or the content of a learner's study, and it is associated only with a random identifier generated on the device, never with the learner's name or email address.
- **Crash reports** (Firebase Crashlytics): technical details of an app crash or error (device model, OS version, the error and where in the App it happened), tagged with the App's internal learner-profile ID (a random code, not a name or email address) so related errors can be grouped. They are used only to fix bugs.
- For all users, including children: the advertising ID is not collected, ad personalization signals are disabled, and Google Signals is turned off. Analytics data is not used for advertising.

### App Preferences
- Display settings (font size, diacritics preference)
- Parent/tutor PINs — stored locally on your device only, hashed with bcrypt, and never transmitted to any server.

## Data We Do NOT Collect

- Location data
- Contacts, photos, or camera access
- Advertising IDs (the advertising ID permission is removed from the App)
- Data for advertising, ad personalization or cross-app tracking

## How Your Data Is Used

- **Authentication**: Your email and name are used solely to create and manage your account via Firebase Authentication.
- **Cloud sync**: Learning progress is synced to Google Cloud Firestore so your data is available across devices and preserved if you reinstall the App. Data is scoped to your user account and is not shared with other users, except with a tutor that a parent chooses to grant access to (see below).
- **Analytics and crash reports**: Used only in aggregate to understand which features help learners and to fix bugs, as described above.
- **Content delivery**: The App fetches Torah texts from the Sefaria public API (`sefaria.org`). These requests do not include any personal information.

## Tutor Access and Change History

A parent can invite a tutor (for example, a rebbe or teacher) to follow a learner. Nothing is shared with a tutor unless the parent grants access, and the parent can change or revoke that access at any time.

- **What a tutor can see**: a tutor granted access can view the learner's learning data that the parent's grant allows, such as progress, goals, tracks and learning records.
- **What a tutor can change**: if the parent allows editing ("Can edit learning"), the tutor can also edit the learner's learning data, including recording, correcting or removing learning entries and changing the learner's tracks, deadline and goals. The parent can turn editing off at any time; the tutor's next change is then refused.
- **Change history**: every change a tutor makes is recorded in a change history, together with who made it and when. The parent can see this history. Changes made by the parent are recorded in the same history.
- **After access ends**: when a parent revokes a tutor's access, the tutor can no longer see or change the learner's data. Learning entries and history already recorded stay part of the learner's data.

## Third-Party Services

The App uses the following third-party services:

| Service | Purpose | Privacy Policy |
|---------|---------|----------------|
| Firebase Authentication | Account sign-in | [Google Privacy Policy](https://policies.google.com/privacy) |
| Cloud Firestore | Cloud data sync | [Google Privacy Policy](https://policies.google.com/privacy) |
| Google Sign-In | OAuth authentication | [Google Privacy Policy](https://policies.google.com/privacy) |
| Cloud Functions for Firebase | Server-side processing of tutor changes and the change history | [Google Privacy Policy](https://policies.google.com/privacy) |
| Google Analytics for Firebase | Usage analytics (no advertising ID, ad personalization or Google Signals) | [Google Privacy Policy](https://policies.google.com/privacy) |
| Firebase Crashlytics | Crash reports | [Google Privacy Policy](https://policies.google.com/privacy) |
| Firebase App Check | Protects the App's backend from abuse | [Google Privacy Policy](https://policies.google.com/privacy) |
| Sefaria API | Torah text content | [Sefaria Privacy Policy](https://www.sefaria.org/privacy-policy) |

No data is sold to third parties. No data is shared with third parties for advertising or marketing purposes.

## Data Storage and Security

- Cloud data is stored in Google Cloud Firestore, secured by Firebase Authentication.
- Local data is stored on-device in an encrypted SQLite database and secure storage.
- PINs are hashed with bcrypt before storage and are never transmitted.
- The App supports full offline operation; data syncs when connectivity is restored.

## Children's Privacy

The App may be used by children under parental supervision. The App includes a parent PIN lock feature to restrict access to settings. We do not knowingly collect personal information from children beyond what is described in this policy. A parent or guardian must create the account. A child's learning data is visible to a tutor only when the parent grants it, and every tutor change to it is recorded in the parent-visible change history.

## Data Retention and Deletion

Your data is retained as long as you maintain an account. To delete your data:

1. Contact us at the email below to request account and data deletion, or
2. Delete your account through the App's settings (when available).

Upon account deletion, all associated data in Cloud Firestore will be removed, including learning records and the change history.

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
