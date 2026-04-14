# Authentication & Accounts -- Manual Test Scenarios

> **Prerequisites:** Read `01-product-overview.md` first for glossary and product context.
> This document covers FR75, FR88-FR94, FR102-FR105, NFR29-NFR35, and the
> hard-tier auth model defined in `offline-first-architecture-v2-2026-04-10.md`.

---

## 1. Context: What & Why

### The Hard-Tier Auth Model

Learning Tracker uses a **hard-tier auth model** where every user has a real
account with email and password. The tier -- cloud-born or local-born -- is
determined at signup by whether the device has internet, and it is **immutable**
after that moment.

**Cloud-born** (signed up with internet):
- Credentials stored in Firebase Auth (email/password or Google Sign-In)
- Gets Firestore sync, multi-device support, cloud backup
- Session persists locally for 30+ days -- the user can go offline for weeks
  without being locked out
- On reconnect, queued writes sync automatically

**Local-born** (signed up without internet):
- Credentials stored as argon2id password hash in local SQLite
- No sync, no backup, no recovery, no multi-device
- If the user forgets their password or loses the device, all data is
  permanently lost
- A prominent "No Backup" badge is always visible in the profile area

**Why this matters for testing:** A local-born user who loses their device loses
everything. The app must make this crystal clear at signup and throughout the
experience. A tester who skips the local-born scenarios is leaving the most
dangerous data-loss path unverified. Every warning, every badge, every
acknowledgment gate exists to protect a real user from irreversible loss.

**Upgrade path:** Local-born users can upgrade to cloud-born through an explicit,
one-way flow. This involves checking for email collisions with existing Firebase
accounts and, if a collision is found, presenting guided merge options. There is
no silent auto-merge.

---

## 2. Test Scenarios

### Cloud-Born Signup (P0)

---

#### AUTH-01: Email/password signup (cloud-born, happy path)

**Priority:** P0
**Preconditions:** Fresh install. Device online (Wi-Fi or mobile data).
**Steps:**
1. Launch the app. Confirm the signup/sign-in screen appears.
2. Tap "Create Account" (or equivalent).
3. Enter a valid, unused email address.
4. Enter a password that meets the app's strength requirements.
5. Confirm the password.
6. Tap "Sign Up".

**Expected Result:**
- Firebase Auth account is created (verifiable in Firebase Console).
- The app proceeds to the onboarding flow (mode selection, profile setup).
- No "No Backup" warning is shown -- this is a cloud-born account.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-02: Google Sign-In signup (cloud-born)

**Priority:** P0
**Preconditions:** Fresh install. Device online. Google account available on device.
**Steps:**
1. Launch the app to the signup/sign-in screen.
2. Tap "Sign in with Google".
3. Select a Google account from the system picker (or sign into one).
4. Complete the Google auth flow.

**Expected Result:**
- Firebase Auth account is created with the Google provider.
- The app proceeds to onboarding.
- No "No Backup" warning is shown.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-03: Signup with invalid email format

**Priority:** P0
**Preconditions:** Fresh install. Device online.
**Steps:**
1. Navigate to the signup screen.
2. Enter an invalid email (e.g., `notanemail`, `user@`, `@domain.com`).
3. Enter a valid password.
4. Tap "Sign Up".

**Expected Result:**
- A validation error is shown on the email field before or upon submission.
- No network call is made to Firebase.
- The user remains on the signup screen.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-04: Signup with weak password

**Priority:** P0
**Preconditions:** Fresh install. Device online.
**Steps:**
1. Navigate to the signup screen.
2. Enter a valid email address.
3. Enter a weak password (e.g., `123`, `abc`, a single character).
4. Tap "Sign Up".

**Expected Result:**
- Password requirements are displayed (minimum length, complexity rules).
- The signup does not proceed.
- The user remains on the signup screen with the error visible.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-05: Signup with already-registered email

**Priority:** P0
**Preconditions:** Fresh install. Device online. An account already exists in Firebase with the email you will use.
**Steps:**
1. Navigate to the signup screen.
2. Enter the email of an existing Firebase account.
3. Enter a valid password.
4. Tap "Sign Up".

**Expected Result:**
- An error message indicates the email is already in use (e.g., "An account with this email already exists").
- The user is not signed in to the existing account.
- The user remains on the signup screen. A "Sign In" option should be accessible.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

### Local-Born Signup (P0)

---

#### AUTH-06: Email/password signup (local-born, airplane mode)

**Priority:** P0
**Preconditions:** Fresh install. Device in airplane mode (no Wi-Fi, no mobile data).
**Steps:**
1. Enable airplane mode.
2. Launch the app. Confirm the signup/sign-in screen appears.
3. Tap "Create Account".
4. Enter a valid email address.
5. Enter a password that meets strength requirements.
6. Confirm the password.
7. Tap "Sign Up".

**Expected Result:**
- The app detects no network and routes to the local-born path.
- A prominent "No Backup" warning is displayed, stating clearly:
  - This account exists only on this device.
  - If you forget your password or lose this device, your data cannot be recovered.
  - There is no password reset available.
- The user must explicitly acknowledge/accept this warning before proceeding.
- After acknowledgment, the argon2id password hash is stored in SQLite.
- The app proceeds to onboarding.
- No Firebase calls are attempted.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-07: "No Backup" acknowledgment is mandatory

**Priority:** P0
**Preconditions:** Fresh install. Device in airplane mode. Reached the "No Backup" warning during local-born signup (AUTH-06 steps 1-7).
**Steps:**
1. Follow AUTH-06 steps 1-7 until the "No Backup" warning appears.
2. Attempt to proceed without accepting/acknowledging the warning (tap outside, tap "Continue" if it is disabled, use back gesture, etc.).
3. Verify the warning cannot be bypassed.
4. Now accept/acknowledge the warning.
5. Confirm the signup completes.

**Expected Result:**
- The user cannot proceed past the warning without explicitly acknowledging it.
- The acknowledgment control (checkbox, button, etc.) must require a deliberate action -- not just dismissing a dialog.
- After acknowledgment, signup completes normally.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-08: Persistent "No Backup" badge for local-born account

**Priority:** P0
**Preconditions:** Local-born account created (AUTH-06 completed). Logged in.
**Steps:**
1. Navigate to the profile or settings area.
2. Look for a "No Backup" badge or indicator.
3. Tap the badge.

**Expected Result:**
- A "No Backup" badge is permanently visible in the profile/settings area.
- The badge is not dismissible.
- Tapping the badge opens information about upgrading to a cloud-backed account (the upgrade flow entry point).

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

### Sign-In (P0)

---

#### AUTH-09: Cloud-born sign-in with correct credentials

**Priority:** P0
**Preconditions:** Cloud-born account already exists (created via AUTH-01 or AUTH-02). App is at the sign-in screen (either fresh launch after sign-out, or reinstall).
**Steps:**
1. On the sign-in screen, enter the correct email.
2. Enter the correct password.
3. Tap "Sign In".

**Expected Result:**
- Firebase Auth verifies credentials successfully.
- The app navigates to the dashboard or profile picker (if multiple profiles exist).
- Sync begins in the background if online.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-10: Local-born sign-in with correct password

**Priority:** P0
**Preconditions:** Local-born account already exists (AUTH-06 completed). App is at the sign-in screen (after sign-out or app restart).
**Steps:**
1. On the sign-in screen, enter the email used during local-born signup.
2. Enter the correct password.
3. Tap "Sign In".

**Expected Result:**
- The argon2id hash verification succeeds against the stored hash in SQLite.
- The app navigates to the dashboard or profile picker.
- No network calls are made.
- The "No Backup" badge is visible in the profile/settings area.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-11: Sign-in with wrong password (either tier)

**Priority:** P0
**Preconditions:** An account exists (cloud-born or local-born). App is at the sign-in screen.
**Steps:**
1. Enter the correct email for an existing account.
2. Enter an incorrect password.
3. Tap "Sign In".

**Expected Result:**
- An error message is shown (e.g., "Incorrect password" or "Invalid credentials").
- The error message does not reveal whether the email exists (security best practice).
- No data is accessible. The user remains on the sign-in screen.
- Repeat with the other tier (if first test was cloud-born, repeat with local-born, and vice versa).

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-12: Sign-in with nonexistent email

**Priority:** P0
**Preconditions:** App is at the sign-in screen.
**Steps:**
1. Enter an email that has never been registered (cloud or local).
2. Enter any password.
3. Tap "Sign In".

**Expected Result:**
- An appropriate error message is shown (e.g., "No account found" or generic "Invalid credentials").
- The user remains on the sign-in screen.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

### Session & Persistence (P1)

---

#### AUTH-13: Cloud-born user goes offline

**Priority:** P1
**Preconditions:** Cloud-born account signed in. Device online.
**Steps:**
1. Verify the app is functioning normally with sync active.
2. Enable airplane mode.
3. Navigate through the app: open the dashboard, view a curriculum, mark a completion, check streaks.
4. Look for an offline indicator.

**Expected Result:**
- A subtle offline indicator (e.g., top banner) appears, communicating "Offline -- changes will sync when you're back" or similar.
- All features continue to work: navigation, marking completions, viewing progress.
- No error dialogs or crashes.
- The banner is not dismissible by the user (it disappears automatically when connectivity returns).

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-14: Cloud-born session persistence

**Priority:** P1
**Preconditions:** Cloud-born account signed in.
**Steps:**
1. Close the app completely (swipe away from recent apps).
2. Wait at least 2 hours (or adjust device clock forward if time-sensitive).
3. Reopen the app.

**Expected Result:**
- The app opens directly to the dashboard or last-used screen.
- No sign-in screen is shown. The session persists.
- If online, sync resumes in the background.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-15: Local-born session persistence

**Priority:** P1
**Preconditions:** Local-born account signed in. Device in airplane mode.
**Steps:**
1. Close the app completely.
2. Wait at least 2 hours (or adjust device clock forward).
3. Reopen the app (still in airplane mode).

**Expected Result:**
- The app opens directly to the dashboard or last-used screen.
- No sign-in screen is shown. The session persists.
- No sync operations occur. No network error messages appear.
- The "No Backup" badge remains visible in profile/settings.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

### Upgrade Flow (P1)

---

#### AUTH-16: Local-born upgrade to cloud (no collision)

**Priority:** P1
**Preconditions:** Local-born account exists with data (some completions, streaks). Device now has internet. The email used for the local-born account does NOT exist in Firebase Auth.
**Steps:**
1. Disable airplane mode (connect to internet).
2. Navigate to Settings or tap the "No Backup" badge.
3. Find and tap the "Upgrade to Cloud" option.
4. Follow the upgrade flow prompts.
5. Confirm the upgrade.

**Expected Result:**
- A Firebase Auth account is created with the same email and password.
- Sync begins: local data is pushed to Firestore.
- The "No Backup" badge disappears from the profile area.
- All existing data (completions, streaks, XP, profiles) is preserved.
- The account is now cloud-born. Subsequent behavior matches cloud-born expectations.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-17: Local-born upgrade with email collision

**Priority:** P1
**Preconditions:** Local-born account exists. A different Firebase Auth account already exists with the same email address. Device has internet.
**Steps:**
1. Navigate to the upgrade flow (via Settings or "No Backup" badge).
2. Initiate the upgrade.
3. Observe the collision detection.

**Expected Result:**
- The app detects that a Firebase account with the same email already exists.
- A guided merge screen is shown with clear options:
  - **Upload local into cloud:** sign in to the existing cloud account, merge local data up.
  - **Keep cloud, discard local:** sign in to the existing cloud account, local data is cleared.
  - **Cancel:** back out, local account remains unchanged.
- No silent auto-merge occurs.
- Whichever option the user selects, the result matches the described behavior.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-18: Upgrade attempt while offline

**Priority:** P1
**Preconditions:** Local-born account exists. Device in airplane mode.
**Steps:**
1. Navigate to the upgrade flow entry point (Settings or "No Backup" badge).
2. Attempt to initiate the upgrade.

**Expected Result:**
- The app shows a clear message explaining that internet connectivity is required to upgrade (e.g., "Connect to the internet to upgrade your account to cloud-backed storage").
- The upgrade does not proceed.
- The local-born account is unchanged.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

### Account Management (P1)

---

#### AUTH-19: Sign out (cloud-born)

**Priority:** P1
**Preconditions:** Cloud-born account signed in with data.
**Steps:**
1. Navigate to Settings.
2. Tap "Sign Out".
3. Confirm sign-out if a confirmation dialog appears.
4. Observe the resulting screen.
5. Sign back in with the same credentials.

**Expected Result:**
- Session is cleared. The app returns to the sign-in screen.
- On re-sign-in, all data is intact (preserved locally and in Firestore).
- Sync resumes normally after re-sign-in.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-20: Sign out (local-born)

**Priority:** P1
**Preconditions:** Local-born account signed in with data.
**Steps:**
1. Navigate to Settings.
2. Tap "Sign Out".
3. Confirm sign-out if a confirmation dialog appears.
4. Observe the resulting screen.
5. Sign back in with the same credentials.

**Expected Result:**
- Session is cleared. The app returns to the sign-in screen.
- On re-sign-in with the correct password, all local data is intact.
- The "No Backup" badge reappears in the profile area.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-21: Change password (cloud-born, email/password)

**Priority:** P1
**Preconditions:** Cloud-born account created with email/password (not Google Sign-In). Signed in. Device online.
**Steps:**
1. Navigate to Settings > Account or Profile.
2. Find and tap "Change Password".
3. Enter the current password.
4. Enter a new password that meets strength requirements.
5. Confirm the new password.
6. Submit.

**Expected Result:**
- Password is updated in Firebase Auth.
- A success confirmation is shown.
- Signing out and signing back in requires the new password.
- The old password no longer works.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-22: Link Google Sign-In to existing email account

**Priority:** P1
**Preconditions:** Cloud-born account created with email/password. The email matches a Google account available on the device. Signed in. Device online.
**Steps:**
1. Navigate to Settings > Account or Profile.
2. Find and tap "Link Google Account" or "Add Sign-In Method".
3. Complete the Google Sign-In flow.

**Expected Result:**
- The Google provider is linked to the existing Firebase Auth account (verifiable in Firebase Console).
- The user can now sign in with either email/password or Google Sign-In.
- A success confirmation is shown in the app.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

### Account Deletion (P0 -- Data Safety)

---

#### AUTH-23: Delete account (cloud-born)

**Priority:** P0
**Preconditions:** Cloud-born account with data (profiles, completions, streaks). Signed in. Device online.
**Steps:**
1. Navigate to Settings > Account.
2. Find and tap "Delete Account".
3. Read any confirmation dialogs carefully.
4. Confirm deletion (this may require re-entering the password or re-authenticating).
5. Observe the result.

**Expected Result:**
- A confirmation dialog warns that this action is irreversible and all data will be deleted.
- After confirmation:
  - Firestore user data is deleted.
  - Firebase Auth account is deleted.
  - Local data is cleared.
- The app returns to the signup/sign-in screen.
- Attempting to sign in with the old credentials fails (account no longer exists).

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-24: Delete account (local-born)

**Priority:** P0
**Preconditions:** Local-born account with data. Signed in.
**Steps:**
1. Navigate to Settings > Account.
2. Find and tap "Delete Account".
3. Read any confirmation dialogs carefully.
4. Confirm deletion.

**Expected Result:**
- A confirmation dialog warns that this action is irreversible. It should be especially emphatic for local-born accounts: there is no backup, no recovery, and all data will be permanently lost.
- After confirmation:
  - All local data is cleared (SQLite database wiped for this account).
- The app returns to the signup/sign-in screen.
- The old credentials no longer work.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

### Edge Cases (P2)

---

#### AUTH-25: Network drops during cloud-born signup

**Priority:** P2
**Preconditions:** Fresh install. Device online. Ready to sign up.
**Steps:**
1. Navigate to the signup screen.
2. Enter a valid email and password.
3. Tap "Sign Up".
4. Immediately enable airplane mode (or disconnect Wi-Fi) while the signup request is in flight.

**Expected Result:**
- The app shows a graceful error message (e.g., "Network error. Please check your connection and try again").
- No partial account is created in Firebase Auth. If a partial account was created, verify the app handles it on retry (idempotent signup or cleanup).
- The user can retry signup when connectivity is restored.

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

#### AUTH-26: App killed during signup flow

**Priority:** P2
**Preconditions:** Fresh install. Device online or offline.
**Steps:**
1. Navigate to the signup screen.
2. Begin filling in email and password.
3. Force-kill the app (swipe away from recent apps, or use Settings > Force Stop).
4. Relaunch the app.

**Expected Result:**
- The app relaunches cleanly to the signup/sign-in screen.
- No crash, no blank screen, no corrupted state.
- If the user was mid-signup (form partially filled), the app starts the signup flow from the beginning -- no stale partial state persists.
- If a Firebase account was partially created before the kill, the app handles re-registration gracefully (either detects the existing account or allows re-signup without error).

**Pass/Fail:** `[ ] Pass  [ ] Fail  Date: ___  Notes: ___`

---

## 3. Cross-Feature References

The auth system touches nearly every other feature area. When testing other
modules, keep these interactions in mind:

| Test Document | Interaction with Auth |
|---|---|
| **03 - Onboarding** | Onboarding begins immediately after signup. The tier (cloud/local) determines whether sync setup occurs. Mode selection (child/adult) and profile creation happen post-auth. |
| **13 - Settings** | Settings contains sign-out, account deletion, password change, provider linking, and the upgrade flow entry point. The "No Backup" badge lives in the profile/settings area. |
| **14 - Sync** | Sync is cloud-born only. All sync test scenarios depend on having a cloud-born account. Local-born accounts must never trigger sync operations. |
| **15 - Profiles** | Profile creation requires an existing account. The Account > Profile > Track hierarchy is identical across tiers. Multi-profile scenarios should be tested on both cloud-born and local-born accounts. |
