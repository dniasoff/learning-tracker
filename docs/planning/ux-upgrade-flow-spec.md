# Local → Cloud Upgrade Flow — UX Spec

**Date:** 2026-04-10
**Status:** Draft — for UX designer handoff
**Author:** Mary (Business Analyst) with Daniel
**Scope:** Complete flow, state, and copy specification for the local-born → cloud-born upgrade flow defined in `architecture-offline-v2.md` §4.3. Visual design (wireframes, component choices, spacing, iconography) is explicitly out of scope here — handed off to the UX designer agent.

> ⚠️ **Superseded mechanism — 2026-07-13.** This spec's core step (§5.2 "Confirm
> password" — re-authenticate by verifying the existing local password) assumed
> local-born accounts have a password to verify. Per the 2026-06-14 product decision,
> offline/local-born accounts are now **credential-less**, so there is no password to
> confirm. The shipped upgrade flow instead does "full sign-in at conversion": the
> Upgrade screen collects a brand-new email + password directly (no password-verify
> step), per `UpgradeToCloudService.upgradeWithNewCredentials()`
> (`../../learning_tracker/lib/features/account/domain/services/upgrade_to_cloud_service.dart`).
> Treat this doc as a historical record of the pre-credential-less design; for the
> shipped design record see `docs/_archive/superseded/loop-progress.md`, "ONBOARDING REWORK ... Phase 2b
> CONVERT-COMPLETION" (2026-06-15).

---

## 1. What This Spec Covers

- **Entry points** — where the user encounters the upgrade option
- **Preconditions** — what state the app and user must be in
- **Happy path** — no email collision
- **Collision path** — email already exists as a Firebase account
- **Error paths** — network drop, Firebase errors, validation failures, sync failures
- **Edge cases** — backgrounded mid-flow, crashes, double-submits, session expiry
- **Copy** — every screen title, body, button label, error message
- **State machine** — explicit state transitions, resumability, idempotence
- **Success criteria** — how we know the flow works

## 2. What This Spec Does NOT Cover (Handed Off)

- **Visual design** — layouts, colors, spacing, typography, iconography, motion
- **Component selection** — which design-system components to use
- **Accessibility review** — screen reader behavior, focus order, contrast (should be applied by UX designer using existing design-system accessibility rules)
- **Animation / transition timing**
- **Localization** — all copy here is English; copy keys are named so i18n can be added later
- **Argon2id parameter selection** — deferred to v2 doc §7 follow-up #1
- **Merge algorithm implementation detail** — high-level merge semantics are from v2 §4.1; this spec covers only the UX *around* merging, not the implementation

---

## 3. The Big Picture (Why This Flow Is Tricky)

The upgrade flow has to gracefully handle four qualitatively different situations, and the user doesn't know which one they're in when they tap "Back Up to Cloud":

| Situation | Frequency | Complexity |
|---|---|---|
| **A. Clean promotion** — email is unused in Firebase, no conflicts | Most common | Low |
| **B. Email collision, user recognizes the other account** — e.g. they had the app on an old phone | Uncommon but inevitable | High — merge UX |
| **C. Email collision, user does NOT recognize the other account** — typo'd email, shared family email, misremembered | Rare but very bad if wrong | High — high-risk if user chooses incorrectly |
| **D. Network drops mid-flow** — request partially completes | Common on the 10% tier | Medium — must be resumable |

**Design principle:** The flow is *always* initiated explicitly by the user and *always* lets them back out without consequence until the final confirmation step. No silent merging, no auto-resolution of collisions. When in doubt, the user sees an "I'm not sure, cancel" option.

**Design principle:** The user's local data is *sacred until the final confirm*. No destructive local writes happen until after Firebase operations succeed. If anything fails before the final confirm, the local state is exactly what it was before the flow started.

**Design principle:** The flow must be *safe to retry*. If the user aborts, crashes, or loses network, they can restart the flow from the beginning with no leftover bad state.

---

## 4. Entry Points

There are exactly **two entry points** into the upgrade flow. No others.

### 4.1 Primary: Settings → "Back up to cloud"

- **Location:** Settings screen, top section (above other settings — this is an important action for the user, not a buried option)
- **Visible to:** Local-born users only. Cloud-born users never see this row.
- **Label:** "Back up to cloud"
- **Subtitle:** "Sync your progress across devices and protect your data"
- **Right-side accessory:** chevron (`>`)
- **Tap behavior:** opens Step 1 of the flow (§5.1)

### 4.2 Secondary: "No backup" badge in profile area

- **Location:** Profile area (as defined in v2 §4.6), always visible for local-born users
- **Tap behavior:** opens the same Step 1 of the flow
- **Copy on the badge itself:** "No backup" (neutral, not alarmist)
- **Rationale:** The badge exists primarily as ambient pressure; tapping it is a natural next step for users who want to resolve that pressure

**Out of scope (explicit):** No entry from push notifications, no entry from onboarding (local-born users confirmed their tier at signup; we don't badger them inside onboarding), no entry from deep links.

---

## 5. Happy Path (Situation A — Clean Promotion)

### 5.1 Step 1 — Intro screen

**Screen title:** "Back up your account to the cloud"

**Body copy:**
> Your account and progress are currently stored only on this device. Backing up to the cloud will:
>
> • **Protect your data** if you lose your device
> • **Sync your progress** across phones and tablets
> • **Let you sign in on another device** with the same email
>
> We'll use the email and password you already created for this account — no need to create a new one.

**Primary button:** "Continue"
**Secondary (text link or back button):** "Not now"

**Preconditions to show this screen:**
- User is authenticated as a local-born user
- A network check has been performed and the device has connectivity (see §7.1 for offline entry handling)

**Exit behavior:**
- "Continue" → Step 2
- "Not now" / back → exit flow, return user to entry point with no side effects

### 5.2 Step 2 — Confirm password

**Screen title:** "Confirm your password"

**Body copy:**
> For security, please enter your account password. This is the same password you use to sign in on this device.

**Fields:**
- Password (secure text entry, single field, no confirmation)
- Show/hide password toggle

**Primary button:** "Continue" — disabled until a non-empty password is entered
**Secondary:** Back (← arrow or "Back" text)

**Why this step exists:**
The password is stored as an argon2id hash locally. We need to *verify* it (not re-derive it) because Firebase Auth requires the plaintext password at signup time to create the cloud credential. We cannot send the hash to Firebase — Firebase hashes the password itself. So the user has to re-enter the plaintext they already use on this device.

**Validation on Continue:**
1. Verify entered password against the local argon2id hash
2. **If incorrect:** show inline error (§8.2); stay on this screen
3. **If correct:** hold plaintext in memory (**not persisted**) and advance to Step 3

**Exit behavior:**
- "Continue" with valid password → Step 3
- Back → Step 1 (password input is cleared)

**Copy for wrong-password error:**
> "That password doesn't match the one on this device. Please try again."

**What does NOT happen here:**
- No password reset flow (local-born users have no recovery path — this is stated at signup and cannot be softened here)
- No "forgot password" link — would be misleading

### 5.3 Step 3 — Checking for existing account

**Screen title:** "Checking…"

**Body copy (transient, during the Firebase call):**
> We're checking if this email already has a cloud account.

**Spinner / progress indicator** (minimal, 1-3 seconds expected)

**Network call:** `FirebaseAuth.fetchSignInMethodsForEmail(email)` — no account created yet, just a lookup.

**Outcomes:**
- **Empty list returned** → email is unused → advance to Step 4 (Clean Promotion path)
- **Non-empty list returned** → email collision → branch to §6 (Collision path)
- **Network error** → §7.2 error handling
- **Firebase service error** → §7.3 error handling

**Why this step is its own screen:**
The lookup is fast but not instant, and the branching is consequential. Showing it explicitly tells the user "something is happening, wait" rather than making Step 2 hang on submit. Also, if the lookup fails, the user hasn't yet entered anything in Step 4, so there's less to recover.

### 5.4 Step 4 — Confirm promotion

**Screen title:** "Ready to back up"

**Body copy:**
> We're about to create a cloud account for **{email}** and upload your data.
>
> After this:
>
> • Your progress will sync to the cloud automatically
> • You'll be able to sign in on other devices with this email and password
> • Your "No backup" warning will go away
>
> **This takes about a minute.** Please keep the app open and connected to the internet.

**Primary button:** "Back up now"
**Secondary:** Cancel (text link)

**Exit behavior:**
- "Back up now" → Step 5
- Cancel → return to Step 1 (password in memory is cleared)

### 5.5 Step 5 — Promotion in progress

**Screen title:** "Backing up your data…"

**Body copy:**
> Creating your cloud account and uploading your progress. Please keep the app open.

**Progress indicator:** Determinate if possible (e.g. "Uploading 34 of 128 items…"), indeterminate spinner otherwise.

**Blocking:** This screen *does* block the user from navigating away — the user cannot interact with the rest of the app while promotion is happening. A hard back gesture / back button triggers the abort confirmation (§7.4).

**Operations happening (in order, each must succeed before the next):**

1. `FirebaseAuth.createUserWithEmailAndPassword(email, plaintextPassword)` — creates the cloud identity. Discard plaintext from memory immediately after this call returns.
2. Update local `UserProfiles` row: set `tier = cloudBorn`, set `firebaseUid`, clear `passwordHash` (no longer needed locally — Firebase owns it now).
3. Initialize Firestore doc for this user: `users/{firebaseUid}` with profile metadata.
4. Upload the User DB content to Firestore in batches (profiles, completions, bookmarks, goals, streaks, XP event log, etc.) — reuses the existing sync engine's push-all logic.
5. Mark the sync engine as "active" for this user — transition from dormant to running.
6. Advance to Step 6.

**Failure at any step:** transitions to §7 error handling with specific recovery based on which step failed.

**Idempotence requirement:** If the user crashes or force-quits mid-upload, the next launch must detect the partial state (Firebase account created, some data uploaded) and offer to resume or roll back. See §9.2.

### 5.6 Step 6 — Success

**Screen title:** "Your account is backed up"

**Body copy:**
> Your data is now synced to the cloud. You can sign in on other devices with your email and password, and you'll never lose your progress.

**Primary button:** "Done" — returns user to the entry point (Settings) with updated UI state (the "Back up to cloud" row is gone, replaced by "Signed in as {email}").

**What happens behind the scenes on dismiss:**
- The sync engine is now running in cloud-born mode
- The top-banner and "no backup" badge (§4.6) are hidden
- The app's offline indicator behavior switches to the cloud-born variant

---

## 6. Collision Path (Situations B and C)

Triggered when Step 3 (§5.3) finds that `{email}` already has sign-in methods registered in Firebase.

### 6.1 Step 3b — Collision detected

**Screen title:** "This email already has a cloud account"

**Body copy:**
> The email **{email}** is already registered with a cloud account, from another device or a previous install.
>
> What would you like to do?

**Choices (each presented as a large tappable card or row with title + description):**

**Option A card:**
- **Title:** "Sign in and upload this device's data"
- **Description:** "I recognize this account. Sign me in to the existing cloud account and upload my progress from this device. If there's overlap, we'll keep the better of the two."
- **Consequence preview (small text below):** "Your local progress will be uploaded and merged with what's in the cloud."

**Option B card:**
- **Title:** "Sign in and replace this device's data"
- **Description:** "I recognize this account and I want to use what's in the cloud. Discard this device's local progress and use the cloud version instead."
- **Consequence preview:** "This device's local progress will be deleted. This cannot be undone."

**Option C card:**
- **Title:** "This isn't my account — cancel"
- **Description:** "I don't recognize this cloud account. Don't do anything. I'll check and try again."
- **Consequence preview:** "No changes. Your local account is untouched."

**No primary button** — the user must pick one of the three options explicitly. There is no default.

**Exit behavior:**
- Option A → §6.2 (Merge-up path)
- Option B → §6.3 (Replace-local path)
- Option C → exit flow entirely, return to Settings, no side effects. Show a brief toast: "Cancelled. Your local account is unchanged."

**Critical copy principles:**
- Never use "merge" as a verb in user-facing copy — too abstract. Use "upload", "keep", "replace", "discard".
- Never show the word "conflict" — too technical and scary.
- Consequences are stated *before* the tap, not after. User makes an informed choice.
- "This cannot be undone" appears on Option B because it cannot.
- The cancel option (C) must be visually equal to the other two — not a tiny link. Users who are unsure need a no-consequence escape that feels like a real choice.

### 6.2 Merge-up path (Option A)

**Step 6.2.1 — Confirm cloud credentials**

**Screen title:** "Sign in to your cloud account"

**Body copy:**
> Enter the password for your cloud account **{email}**. This might be different from the password on this device.

**Fields:**
- Password (secure text entry)
- "Show password" toggle
- **"Forgot password?" link** — opens Firebase's password reset flow (email link). This only applies to cloud-born accounts and is a standard Firebase feature.

**Primary button:** "Sign in" — disabled until non-empty
**Secondary:** Back → returns to §6.1

**Validation:**
- `FirebaseAuth.signInWithEmailAndPassword(email, plaintextPassword)`
- **Wrong password:** inline error "That password doesn't match your cloud account. Try again or tap 'Forgot password'."
- **Rate-limited:** after 5 failed attempts, show error "Too many attempts. Please try again in a few minutes." and disable the Sign in button for 60 seconds.
- **Success:** advance to §6.2.2

**Step 6.2.2 — Preview merge**

**Screen title:** "Review your data"

**Body copy:**
> We'll merge this device's data with your cloud account. Here's what will happen:

**Three subsections (expandable cards or a list):**

1. **Profiles** — "You have {N_local} profiles on this device and {N_cloud} profiles in the cloud. We'll keep all of them. If any profiles have the same name and track, we'll use the more recent version."
2. **Progress** — "Completed items on either side will stay completed. Your read positions will use whichever is further along."
3. **Streaks & XP** — "Your current streak is the longer of the two. Your XP is the sum of both sides — you won't lose any points."

**Note beneath:** "We won't delete anything. If the merge doesn't look right, you can sign out afterward — your local data stays on this device."

**Primary button:** "Merge and sync"
**Secondary:** Cancel → returns to §6.1

**Critical design note:** The preview should show *actual counts* from the local DB before the tap (e.g. "You have **3** profiles on this device") — not static copy. The cloud-side counts can be static "your cloud account's data" if computing them requires an extra Firestore fetch that slows the flow down. Defer that optimization to the designer.

**Step 6.2.3 — Merging**

**Screen title:** "Merging your data…"

**Body copy:**
> This might take a minute or two. Please keep the app open.

Blocking progress screen, same rules as §5.5.

**Operations:**
1. Fetch the remote User DB state from Firestore (full pull)
2. Reconcile local state with remote state, per v2 §4.1 rules (LWW for settings, merge-forward for progress, event-log replay for streaks/XP)
3. Write the reconciled state back to local SQLite
4. Push the reconciled state to Firestore (canonical post-merge state)
5. Update `UserProfiles` row: `tier = cloudBorn`, `firebaseUid = ...`, clear local `passwordHash`
6. Transition sync engine to cloud-born active mode
7. Advance to §6.2.4

**Note on step 2:** The reconciliation is deterministic and does not require user input for any per-item decision. This is important — we decided in v2 §4.1 that per-data-type rules are enough to resolve all conflicts without asking the user. If that assumption turns out wrong during implementation, the flow needs a "manual resolve" screen that is currently not specified.

**Step 6.2.4 — Merge complete**

**Screen title:** "All merged"

**Body copy:**
> Your data from both devices is now synced to your cloud account. You're signed in as **{email}**.

**Primary button:** "Done"

### 6.3 Replace-local path (Option B)

**Step 6.3.1 — Confirm cloud credentials**

Same as §6.2.1 — user signs in to their existing cloud account.

**Step 6.3.2 — Hard confirmation**

**Screen title:** "This will delete your local progress"

**Body copy:**
> You're about to **replace this device's data** with what's in your cloud account.
>
> **This device currently has:**
> • {N} profiles
> • {N} completed items
> • A {N}-day streak
> • {N} XP earned
>
> **All of this will be permanently deleted** and replaced with your cloud account's data. This cannot be undone.

**Primary button:** "Delete and replace" — destructive styling (red / warning color per design system)
**Secondary:** Cancel → returns to §6.1

**Checkbox (unticked by default):** "I understand this will permanently delete my local progress"

The primary button is **disabled until the checkbox is ticked**. This is a deliberate friction — Option B is genuinely destructive and the user should not be able to tap through it on muscle memory.

**Step 6.3.3 — Replacing**

**Screen title:** "Replacing your data…"

Same blocking pattern as §5.5 and §6.2.3.

**Operations:**
1. Delete local User DB content (profiles, progress, streaks, XP, everything except auth fields)
2. Pull full cloud state from Firestore
3. Populate local User DB with cloud state
4. Update `UserProfiles` row: `tier = cloudBorn`, `firebaseUid = ...`, clear local `passwordHash`
5. Transition sync engine to cloud-born active mode
6. Advance to §6.3.4

**Step 6.3.4 — Replacement complete**

**Screen title:** "Done"

**Body copy:**
> You're now signed in to your cloud account **{email}**. Your data from this device's cloud account is in sync.

**Primary button:** "Done"

---

## 7. Error Paths

### 7.1 Offline at flow entry

**Trigger:** User taps "Back up to cloud" while the device has no network.

**Behavior:** Do *not* enter the flow. Instead show a modal:

**Title:** "You're offline"
**Body:** "Backing up to the cloud needs an internet connection. Please connect to Wi-Fi or mobile data and try again."
**Button:** "OK" (dismisses modal, stays on Settings)

**Not shown:** a "retry when online" option. Keep the user in control of when to initiate this flow.

### 7.2 Network drop during Firebase lookup (Step 3)

**Trigger:** `fetchSignInMethodsForEmail` times out or returns a network error.

**Behavior:**

**Title:** "Couldn't check your email"
**Body:** "We lost connection while checking your email. Please check your internet and try again."
**Primary button:** "Try again" → retries Step 3 (same inputs, no data loss)
**Secondary:** "Cancel" → exits flow

**Timeout:** 10 seconds for the lookup.

### 7.3 Firebase service error (any step)

**Trigger:** Firebase returns a non-network error (rate limit, invalid email format that passed local validation, service unavailable, etc.)

**Behavior:**

**Title:** "Something went wrong"
**Body:** "We couldn't complete the backup because of an issue with our cloud service. Please try again in a few minutes."
**Body continuation (small print):** "Error code: {firebase_error_code}"
**Primary button:** "Try again"
**Secondary:** "Cancel"

**Telemetry:** log the full error with stack trace for debugging. Do not show stack traces to the user.

### 7.4 Network drop during promotion (Step 5) or merge (Step 6.2.3 / 6.3.3)

This is the nastiest case. The Firebase account creation might have succeeded but the data upload might be partially complete.

**Behavior during the drop:**
- Progress screen freezes its indicator
- After 30 seconds of no progress, show a non-blocking sub-message: "Still trying…"
- After 60 seconds of no progress, replace the screen with a recovery prompt:

**Title:** "Upload paused"
**Body:** "We lost connection while uploading your data. We've saved your progress and will finish when you're back online."
**Primary button:** "Try again now"
**Secondary:** "I'll try later"

**"I'll try later" behavior:**
- Exit the flow
- Set a flag: `upgrade_in_progress = true` in local state
- Next time the app launches with network, show a persistent banner: "Your cloud backup is paused — tap to finish"
- Tapping the banner resumes the flow from the resumable step (see §9.2 for state machine)

**"Try again now" behavior:**
- Re-attempt from the last successful operation (not from Step 1 — that would re-prompt for password the user already entered)
- Uses the state machine in §9.2 to determine restart point

### 7.5 App crash or force-quit during promotion

**Next launch behavior:**
- Detect partial upgrade state via `upgrade_in_progress` flag + presence of Firebase user without synced Firestore data
- Show a launch-time modal: "We were backing up your data when the app closed. Want to finish now?"
- Primary: "Resume backup" → continues the flow
- Secondary: "Not now" → dismisses, banner shows until resolved (same as §7.4 "I'll try later")

### 7.6 User explicitly aborts during Step 5 or 6.2.3/6.3.3

If the user taps system back or tries to leave the blocking progress screen:

**Modal:**
**Title:** "Cancel backup?"
**Body:** "If you cancel now, your data might not be fully backed up. It's safer to let this finish."
**Primary button:** "Keep backing up" (safe default)
**Destructive secondary:** "Cancel anyway"

If they confirm "Cancel anyway": transition to §7.4's "paused" state with a persistent banner to resume.

### 7.7 Password validation edge cases (Step 2)

- **Empty input:** button disabled, no error message
- **Correct password:** advance
- **Wrong password, attempt 1-2:** inline error, retry
- **Wrong password, attempt 3:** inline error with addition: "If you've forgotten your password, your local account cannot be recovered — but this won't delete anything on this device."
- **Wrong password, attempt 5:** disable the button for 30 seconds to prevent brute force. Copy: "Too many attempts. Please wait 30 seconds and try again."

**Why this matters:** Local-born passwords have no recovery, and a user who has forgotten their password cannot upgrade. This is a sad dead-end but must be honest. Copy should not imply there's a fix we're hiding.

### 7.8 Firebase rejects the email/password for promotion reasons

Possible Firebase errors on `createUserWithEmailAndPassword`:

- **`email-already-in-use`** — should have been caught by Step 3 lookup. If this fires here it means the email was claimed between Step 3 and Step 5 (race condition). Re-run Step 3 logic (branch to §6.1 collision flow).
- **`weak-password`** — Firebase has a minimum password strength that the local-born password might not meet. This is a real risk and needs product discussion: do we allow weak local passwords but block promotion, or do we enforce Firebase's minimum at local signup time? **Open question — see §10.**
- **`invalid-email`** — should have been caught at signup. If it fires here it means our local validation is weaker than Firebase's. Show a generic error and escalate to bug tracker.
- **`operation-not-allowed`** — Firebase project misconfiguration. Show a generic "something went wrong" error. This is a dev problem, not a user problem.

---

## 8. Copy Reference (All Strings in One Place)

For i18n and copy review. Copy keys are suggested names — final keys depend on the i18n framework.

| Key | String |
|---|---|
| `upgrade.entry.settings.title` | Back up to cloud |
| `upgrade.entry.settings.subtitle` | Sync your progress across devices and protect your data |
| `upgrade.entry.badge.label` | No backup |
| `upgrade.step1.title` | Back up your account to the cloud |
| `upgrade.step1.body` | Your account and progress are currently stored only on this device. Backing up to the cloud will: (bulleted list) |
| `upgrade.step1.bullet1` | Protect your data if you lose your device |
| `upgrade.step1.bullet2` | Sync your progress across phones and tablets |
| `upgrade.step1.bullet3` | Let you sign in on another device with the same email |
| `upgrade.step1.footer` | We'll use the email and password you already created for this account — no need to create a new one. |
| `upgrade.step1.primary` | Continue |
| `upgrade.step1.secondary` | Not now |
| `upgrade.step2.title` | Confirm your password |
| `upgrade.step2.body` | For security, please enter your account password. This is the same password you use to sign in on this device. |
| `upgrade.step2.primary` | Continue |
| `upgrade.step2.error.wrong_password` | That password doesn't match the one on this device. Please try again. |
| `upgrade.step2.error.rate_limit` | Too many attempts. Please wait 30 seconds and try again. |
| `upgrade.step2.error.forgotten_warning` | If you've forgotten your password, your local account cannot be recovered — but this won't delete anything on this device. |
| `upgrade.step3.title` | Checking… |
| `upgrade.step3.body` | We're checking if this email already has a cloud account. |
| `upgrade.step4.title` | Ready to back up |
| `upgrade.step4.body` | We're about to create a cloud account for **{email}** and upload your data. (followed by bullets) |
| `upgrade.step4.bullet1` | Your progress will sync to the cloud automatically |
| `upgrade.step4.bullet2` | You'll be able to sign in on other devices with this email and password |
| `upgrade.step4.bullet3` | Your "No backup" warning will go away |
| `upgrade.step4.footer` | This takes about a minute. Please keep the app open and connected to the internet. |
| `upgrade.step4.primary` | Back up now |
| `upgrade.step4.secondary` | Cancel |
| `upgrade.step5.title` | Backing up your data… |
| `upgrade.step5.body` | Creating your cloud account and uploading your progress. Please keep the app open. |
| `upgrade.step6.title` | Your account is backed up |
| `upgrade.step6.body` | Your data is now synced to the cloud. You can sign in on other devices with your email and password, and you'll never lose your progress. |
| `upgrade.step6.primary` | Done |
| `upgrade.collision.title` | This email already has a cloud account |
| `upgrade.collision.body` | The email **{email}** is already registered with a cloud account, from another device or a previous install. What would you like to do? |
| `upgrade.collision.optionA.title` | Sign in and upload this device's data |
| `upgrade.collision.optionA.description` | I recognize this account. Sign me in to the existing cloud account and upload my progress from this device. If there's overlap, we'll keep the better of the two. |
| `upgrade.collision.optionA.consequence` | Your local progress will be uploaded and merged with what's in the cloud. |
| `upgrade.collision.optionB.title` | Sign in and replace this device's data |
| `upgrade.collision.optionB.description` | I recognize this account and I want to use what's in the cloud. Discard this device's local progress and use the cloud version instead. |
| `upgrade.collision.optionB.consequence` | This device's local progress will be deleted. This cannot be undone. |
| `upgrade.collision.optionC.title` | This isn't my account — cancel |
| `upgrade.collision.optionC.description` | I don't recognize this cloud account. Don't do anything. I'll check and try again. |
| `upgrade.collision.optionC.consequence` | No changes. Your local account is untouched. |
| `upgrade.collision.cancel_toast` | Cancelled. Your local account is unchanged. |
| `upgrade.mergeup.cloudauth.title` | Sign in to your cloud account |
| `upgrade.mergeup.cloudauth.body` | Enter the password for your cloud account **{email}**. This might be different from the password on this device. |
| `upgrade.mergeup.cloudauth.forgot` | Forgot password? |
| `upgrade.mergeup.cloudauth.primary` | Sign in |
| `upgrade.mergeup.cloudauth.error.wrong_password` | That password doesn't match your cloud account. Try again or tap 'Forgot password'. |
| `upgrade.mergeup.cloudauth.error.rate_limit` | Too many attempts. Please try again in a few minutes. |
| `upgrade.mergeup.preview.title` | Review your data |
| `upgrade.mergeup.preview.body` | We'll merge this device's data with your cloud account. Here's what will happen: |
| `upgrade.mergeup.preview.profiles` | You have {N_local} profiles on this device and {N_cloud} profiles in the cloud. We'll keep all of them. If any profiles have the same name and track, we'll use the more recent version. |
| `upgrade.mergeup.preview.progress` | Completed items on either side will stay completed. Your read positions will use whichever is further along. |
| `upgrade.mergeup.preview.streaks` | Your current streak is the longer of the two. Your XP is the sum of both sides — you won't lose any points. |
| `upgrade.mergeup.preview.footer` | We won't delete anything. If the merge doesn't look right, you can sign out afterward — your local data stays on this device. |
| `upgrade.mergeup.preview.primary` | Merge and sync |
| `upgrade.mergeup.progress.title` | Merging your data… |
| `upgrade.mergeup.progress.body` | This might take a minute or two. Please keep the app open. |
| `upgrade.mergeup.success.title` | All merged |
| `upgrade.mergeup.success.body` | Your data from both devices is now synced to your cloud account. You're signed in as **{email}**. |
| `upgrade.replace.hardconfirm.title` | This will delete your local progress |
| `upgrade.replace.hardconfirm.body` | You're about to **replace this device's data** with what's in your cloud account. (followed by stats) |
| `upgrade.replace.hardconfirm.stat_profiles` | • {N} profiles |
| `upgrade.replace.hardconfirm.stat_completed` | • {N} completed items |
| `upgrade.replace.hardconfirm.stat_streak` | • A {N}-day streak |
| `upgrade.replace.hardconfirm.stat_xp` | • {N} XP earned |
| `upgrade.replace.hardconfirm.warning` | All of this will be permanently deleted and replaced with your cloud account's data. This cannot be undone. |
| `upgrade.replace.hardconfirm.checkbox` | I understand this will permanently delete my local progress |
| `upgrade.replace.hardconfirm.primary` | Delete and replace |
| `upgrade.replace.progress.title` | Replacing your data… |
| `upgrade.replace.success.title` | Done |
| `upgrade.replace.success.body` | You're now signed in to your cloud account **{email}**. Your data from this device's cloud account is in sync. |
| `upgrade.error.offline.title` | You're offline |
| `upgrade.error.offline.body` | Backing up to the cloud needs an internet connection. Please connect to Wi-Fi or mobile data and try again. |
| `upgrade.error.lookup_failed.title` | Couldn't check your email |
| `upgrade.error.lookup_failed.body` | We lost connection while checking your email. Please check your internet and try again. |
| `upgrade.error.lookup_failed.primary` | Try again |
| `upgrade.error.service.title` | Something went wrong |
| `upgrade.error.service.body` | We couldn't complete the backup because of an issue with our cloud service. Please try again in a few minutes. |
| `upgrade.error.service.code` | Error code: {code} |
| `upgrade.paused.title` | Upload paused |
| `upgrade.paused.body` | We lost connection while uploading your data. We've saved your progress and will finish when you're back online. |
| `upgrade.paused.primary` | Try again now |
| `upgrade.paused.secondary` | I'll try later |
| `upgrade.banner.paused` | Your cloud backup is paused — tap to finish |
| `upgrade.abort_modal.title` | Cancel backup? |
| `upgrade.abort_modal.body` | If you cancel now, your data might not be fully backed up. It's safer to let this finish. |
| `upgrade.abort_modal.primary` | Keep backing up |
| `upgrade.abort_modal.destructive` | Cancel anyway |
| `upgrade.crash_resume.title` | We were backing up your data when the app closed. Want to finish now? |
| `upgrade.crash_resume.primary` | Resume backup |
| `upgrade.crash_resume.secondary` | Not now |

---

## 9. State Machine

### 9.1 High-level states

```
idle
  ├── entered (user taps entry point)
  │     ├── checking_online → idle (if offline, shows error and returns)
  │     └── online → intro_shown
  ├── intro_shown
  │     ├── continue → password_prompt
  │     └── cancel → idle
  ├── password_prompt
  │     ├── verified → checking_email
  │     └── cancel → idle
  ├── checking_email
  │     ├── no_collision → confirm_promotion
  │     ├── collision → collision_choice
  │     ├── network_error → error_retry (target: checking_email)
  │     └── service_error → error_retry (target: checking_email)
  ├── confirm_promotion
  │     ├── confirm → promoting
  │     └── cancel → intro_shown
  ├── collision_choice
  │     ├── option_a (merge-up) → mergeup_cloudauth
  │     ├── option_b (replace) → replace_cloudauth
  │     └── option_c (cancel) → idle
  ├── mergeup_cloudauth
  │     ├── verified → mergeup_preview
  │     └── cancel → collision_choice
  ├── mergeup_preview
  │     ├── confirm → mergeup_progress
  │     └── cancel → collision_choice
  ├── mergeup_progress
  │     ├── success → mergeup_success
  │     ├── network_drop → paused (persistent state)
  │     └── service_error → error_retry (target: mergeup_progress)
  ├── replace_cloudauth
  │     ├── verified → replace_hardconfirm
  │     └── cancel → collision_choice
  ├── replace_hardconfirm
  │     ├── confirm → replace_progress
  │     └── cancel → collision_choice
  ├── replace_progress
  │     ├── success → replace_success
  │     ├── network_drop → paused (persistent state)
  │     └── service_error → error_retry (target: replace_progress)
  ├── promoting
  │     ├── success → promotion_success
  │     ├── network_drop → paused (persistent state)
  │     └── service_error → error_retry (target: promoting)
  ├── paused (PERSISTENT — survives app restart)
  │     ├── resume → (original target state)
  │     └── dismiss → idle (banner remains visible)
  ├── promotion_success | mergeup_success | replace_success
  │     └── dismiss → idle (flow complete, entry point rerenders)
```

### 9.2 Resumability & persistence

**Critical design requirement:** The flow must be resumable after app restart if it crashes or is backgrounded during `promoting`, `mergeup_progress`, or `replace_progress`.

**Persistence strategy:**
- When entering any of the three progress states, write a row to a `pending_upgrade` table in the local User DB with:
  - `state` (one of the three)
  - `firebase_uid` (if created yet, else null)
  - `last_completed_step` (enum tracking the sub-operations from §5.5 / §6.2.3 / §6.3.3)
  - `started_at` timestamp
- On successful completion of the final sub-operation, delete the row.
- On app launch, check for a `pending_upgrade` row. If present, show the §7.5 resume modal.
- On "Resume backup", restart from `last_completed_step + 1`.

**Idempotence requirement per sub-operation:**
- `createUserWithEmailAndPassword` — not idempotent. If we retry and the user was already created, Firebase returns `email-already-in-use`. Handle by *signing in* with the stored password instead of creating.
- Firestore writes — should be idempotent by design (same doc paths, same content). If we retry, writes are safe.
- Local DB updates — wrapped in a transaction, safe to retry.

### 9.3 What state is held in memory vs persisted

**In memory only (cleared on any error or abort):**
- User's plaintext password (Step 2)
- User's cloud plaintext password (Step 6.2.1 / 6.3.1)
- Cached `fetchSignInMethodsForEmail` result

**Persisted to disk (survives app restart):**
- `pending_upgrade` row (see §9.2)
- Sync engine state
- All User DB changes that have already happened

**Never persisted:**
- Plaintext passwords — *ever*. If we need to retry a Firebase operation after an app restart, the user has to re-enter their password. This is a deliberate security choice.

---

## 10. Open Questions for Product + Design

These are questions the UX designer or product should resolve before implementation. I've made reasonable defaults in the spec above, but each of these deserves a deliberate answer.

1. **Firebase minimum password strength vs local-born passwords.** If Firebase requires 8+ characters with a digit, and a local-born user set a 4-character numeric password, what happens at Step 5? Two options: (a) enforce Firebase's minimum at *local* signup so upgrade always works, (b) let local users set weaker passwords and block upgrade with a dead-end "your password is too weak for cloud backup — please [???]". Option (a) is cleaner but imposes cloud requirements on users who might never go online. Option (b) is user-friendly for the 10% case but creates an unrecoverable upgrade failure.

2. **Email change between local signup and upgrade.** Can a local-born user change their email on the account before upgrading? Currently the spec assumes the email at upgrade = the email at signup. If email change is a feature, it needs its own flow and has implications for "this email" messaging.

3. **Real-time cloud data preview (§6.2.2).** Should the merge preview show actual cloud-side data counts, or static copy? Fetching cloud counts adds a Firestore call and delay. Static copy is less informative. Designer call.

4. **Post-upgrade telemetry banner.** Should we show a one-time toast/banner after successful upgrade like "You're now synced across devices"? Or is the "Done" screen enough? Tempting to add but risks feeling noisy.

5. **What does "profile names match" mean for merge semantics (§6.2.2 profiles bullet)?** If local has a profile "Yoni" with track A and cloud has "Yoni" with track B, is that a match? Or does it require name+track to match? This is an *implementation* detail but the copy currently says "if any profiles have the same name and track" which implies both must match. Needs confirmation.

6. **Hard-confirmation checkbox on Option B (§6.3.2).** Is a checkbox enough friction, or should it require typing "DELETE" or similar? Common pattern for destructive actions in data-sensitive apps. Designer call.

7. **Forgotten local password dead-end (§7.7).** Is there *any* softer handling we can offer? E.g. "sign in to Firebase with this email anyway, create a fresh cloud account, and abandon the local data"? This would be a third option on the collision screen essentially. Product call.

8. **Multi-language support for number formatting in consequence previews.** Not in this spec. Standard i18n responsibility.

9. **What happens to PIN/biometric local auth if it's enabled on the device?** If the user has a PIN set up on the local-born account (e.g. for child safety), does it persist after upgrade? Does it need to be re-entered as part of the upgrade flow? Not covered here — needs its own spec amendment if PIN is in scope.

---

## 11. Success Criteria (Testable)

- [ ] User can reach the flow via Settings entry and via "No backup" badge entry
- [ ] User can cancel at every non-progress step and return to idle with zero side effects
- [ ] Offline entry shows the §7.1 modal and does not enter the flow
- [ ] Wrong local password shows inline error, allows retry, and rate-limits after 5 attempts
- [ ] Clean promotion happy path completes in under 90 seconds on a typical device with normal data volumes
- [ ] Email collision always shows the three-option screen — never auto-resolves
- [ ] Option C (cancel from collision) produces zero side effects — local DB is byte-for-byte identical
- [ ] Merge-up path (Option A) produces a cloud state that reflects the union rules from v2 §4.1 — no completed items lost, no streak/XP loss, longer streak wins, XP sums
- [ ] Replace path (Option B) requires checkbox confirmation — button cannot be tapped without it
- [ ] Replace path completely deletes local state before pulling cloud state — no "half old, half new" local DB
- [ ] Network drop during progress transitions cleanly to paused state with banner
- [ ] App crash during progress is detected on next launch and offers resume
- [ ] Resume from paused state works without re-prompting for password when possible, and safely re-prompts when plaintext is unavailable
- [ ] Plaintext passwords are never written to disk — verify via DB dump after every flow variant
- [ ] After successful upgrade, "No backup" badge and banner are gone; Settings shows "Signed in as {email}"
- [ ] After successful upgrade, sync engine is in cloud-born active mode
- [ ] All copy keys from §8 are externalized and translatable
- [ ] Accessibility pass: screen reader announces every state transition; focus order is top-to-bottom per screen; destructive buttons announce their consequence

---

## 12. Handoff Checklist for UX Designer

The following items are out of scope for this spec and need to be produced by the UX designer:

- [ ] Wireframes or high-fidelity mocks for every screen in §5 and §6
- [ ] Component selection from the design system for: cards, buttons (primary/secondary/destructive), inline errors, blocking progress screens, top banners, modals
- [ ] Colors and iconography for destructive actions (Replace path)
- [ ] Spacing, typography, and layout for the collision choice screen (§6.1) — this is the most complex screen and the three options need to feel visually equivalent
- [ ] Animation / motion design for state transitions (if the design system has opinions)
- [ ] Accessibility pass on focus order, screen reader labels, and contrast
- [ ] Resolution of the open questions in §10
- [ ] i18n copy review — the copy in §8 is English-first; other languages may need different structure

---

## 13. References

- **Canonical architecture doc:** [`docs/planning/architecture-offline-v2.md`](architecture-offline-v2.md)
- **v2 §4.3** — the decision that this spec implements
- **v2 §4.1** — conflict resolution rules that the merge-up path relies on
- **v2 §4.6** — "No backup" badge entry point
- **Linear Epic 20** — [Epic 20: Offline-First Architecture v2 — Hard-Tier Auth Refactor](https://linear.app/dniasoff/project/epic-20-offline-first-architecture-v2-hard-tier-auth-refactor-d9ed0690d244)
