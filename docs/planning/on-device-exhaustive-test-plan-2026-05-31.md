# On-Device Exhaustive Test Plan — Learning Tracker

**Created:** 2026-05-31 · **Target:** real Android device (`com.jcom.torah.learning_tracker`), driven by ADB.
**Companion kickoff prompt:** `docs/planning/on-device-test-KICKOFF-PROMPT.md`.

> The goal of this plan is to make on-device manual testing **unnecessary** by exhaustively specifying it:
> **every screen, every button, every toggle, every field, every gesture, every state** is a numbered step with
> an explicit expected result a tester (human or ADB-driving agent) marks Pass / Fail / Notes against. This plan
> was generated from the **actual screen source** (not guessed): **47 routed screens + 2 pushed screens + every
> dialog/sheet/wizard-step = 126 screen-entries, 1,353 interactive elements enumerated**, plus **13 cross-cutting
> end-to-end flows**.

---

## 0. Scope & coverage

- **12 feature clusters** (sections 1–12 below), each enumerating every interactive element per screen.
- **Cross-cutting end-to-end flows** (section F) — the user journeys that span screens (L3-level).
- **1,353** enumerated interactive elements across **126** screen-entries.

### Screens the route-list misses (push-route, not `@RoutePage`) — MUST be covered
- **`BulkMarkScreen`** (`lib/features/onboarding/presentation/screens/bulk_mark_screen.dart`) — pushed from
  CurriculumSettings (`:137`/`:176`) **and** TrackDetail (`:604`). **Load-bearing for the completion-credit
  policy** (sentinel-date bulk mark must credit siyumim/lifetime WITHOUT polluting streak/recent). Covered in §F9.
- **`LearningProcessWizardScreen`** (`lib/features/onboarding/presentation/screens/learning_process_wizard_screen.dart`)
  — pushed from CurriculumSettings (`:137`). Distinct from AddTrackFlow's embedded wizard.

### Items to RESOLVE during the sweep (dead-or-document, per the project DoD)
- `ParentPortalBottomNav` — built widget with no live callers → delete (provably dead) or wire it.
- `ScopeSelectionScreen` — screen file with **no route registered**; constructor-only entry from the scope step →
  confirm reachable or delete.
- `TrackLearningOrderScreen` (per-track reorder) — reached via `MaterialPageRoute`, **not** `@RoutePage`; document
  its non-routed entry (the deep-link harness has no path for it).
- `EmailVerificationConfirmPanel` / `GoalSetupForm` — each mounts in **two** contexts; test both.

---

## 1. Device setup (one-time)

| Step | Command / action | Expected |
|---|---|---|
| Connect | `adb connect 100.72.6.10:5555` (phone on Tailscale) | `100.72.6.10:5555  device` in `adb devices` |
| JDK | `export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64` | Gradle uses JDK 21 |
| Build current code | `cd learning_tracker && flutter build apk --debug` | `app-debug.apk` built (exit 0) |
| Install (no data loss) | `adb -s 100.72.6.10:5555 install -r build/app/outputs/flutter-apk/app-debug.apk` | `Success` — existing build is **debug-signed**, so `-r` preserves data. Do **NOT** `uninstall` (wipes the user's profiles/tracks) without explicit OK. |
| Launch | `adb -s 100.72.6.10:5555 shell monkey -p com.jcom.torah.learning_tracker 1` | App opens |
| Screen geometry | 1080 × 2340 px | tap coordinates are absolute px |

### Driving primitives (ADB)
- **Screenshot:** `adb -s 100.72.6.10:5555 exec-out screencap -p > /tmp/s.png` → Read `/tmp/s.png` (image) to see the screen.
- **Tap:** `adb -s 100.72.6.10:5555 shell input tap <x> <y>`  ·  **Swipe:** `... input swipe x1 y1 x2 y2 <ms>`
- **Type:** `... shell input text 'hello'` (no spaces → use `%s`)  ·  **Back:** `... shell input keyevent 4`  ·  **Home:** `keyevent 3`
- **Reach first-run state:** `adb ... shell pm clear com.jcom.torah.learning_tracker` (⚠ WIPES app data — only with explicit OK; use a throwaway/test profile).
- **Toggle network (offline state):** `adb ... shell svc wifi disable && svc data disable` (re-enable with `enable`).
- **Dark mode:** `adb ... shell cmd uimode night yes|no`  ·  **Locale (Hebrew/RTL):** change in device Settings → Languages (or `adb shell am broadcast` locale helper).

### Execution protocol (per step)
1. Screenshot **before**; confirm the precondition/screen.
2. Perform the step's Action on the named element (tap the element's on-screen coordinates).
3. Screenshot **after**; compare to **Expected result**.
4. Mark **Pass / Fail / Notes** (with the after-screenshot filename) in the step's last column.
5. On any **Fail**: capture `adb logcat -d` around the action, record repro steps in the **Defect Log** (§D),
   and — per the standing mandate — **fix the root cause + add a regression test**, or escalate if it needs a decision.
6. Cover **every State row** for the screen (loading/empty/error/offline/child/adult/tutor/Hebrew-RTL/dark) — each is its own pass/fail.

---

## 2. Product rules to assert (cite in the relevant step)

1. Two profile types only — **child** and **adult** (no "parent" type). Adults have **no points/gamification**.
2. **No track-type label** ("Personal"/"Standard"/"Custom"/`אישי`) anywhere.
3. **Chazara** (review) UI renders **only** when `track.chazaraEnabled`; otherwise NO chazara references anywhere.
4. **Tutor `canMarkLiveCompletion = false`** — in a tutored session the live "mark complete" affordance is absent/disabled; the tutor sees the child's **parent-management** view (NOT child mode).
5. **Persistent profile/role switcher at the top** of EVERY context (Learner/Adult/Tutor), tappable → profiles + modes.
6. **Settings:** top header = account-only sheet; profile management only in the PROFILE section; no duplicated action.
7. **Account switch needs NO sign-out** (instant switch to Dashboard).
8. Program **start date ∈ [today−30, today]**; back-dating generates past-dated **catch-up** tasks (overdue).
9. **Bulk/lifetime marking uses a sentinel date** — credits siyumim/lifetime, does NOT appear in streak/recent activity.
10. **Hebrew terms vs transliteration** is independent of UI locale; locale-aware dates (`DateFormat.yMMMd(locale)`).
11. **Offline-first** — everything works offline (Drift-first reads, queued writes); sync is informational only.

## 3. Session fixes to regression-confirm on-device (this run's bug fixes)

- All 5 route guards (Auth/Restore/Pin/ChildMode/Profile) **never hang/lock-out** navigation (fail-safe).
- Account-merge **"discard local"** path no longer crashes; sign-in connectivity routing works online/offline.
- Sacred-time **"in Israel"** manual toggle **sticks** (not reverted by a background reload).
- **Scope-selection Save disabled** for an empty subset (no false "saved" toast).
- Redemption **Fulfil/Decline single-tap guarded** (no double-fire).
- **Magic-link / deep-link** handling does not crash on malformed links.
- 27 Cloud Functions deployed (tutor mutations, deletes, invite lifecycle) — confirm tutor actions take effect server-side.


---

# Section F — Cross-cutting end-to-end FLOWS (L3)

These are the user journeys that span multiple screens. Run each as a single uninterrupted on-device session,
screenshotting at every arrow. They are the highest-signal tests — most real defects live in the seams.

### F1 — Canonical happy path (cold start → first reward)
First-run cold start → **AppIntro** → **PermissionPrompt** → **Onboarding** (create a **child** profile + set
Parent PIN + intent) → first track via **AddTrackFlow** → first daily task **mark-complete** →
**AchievementUnlockCelebration** → points/level update on **Dashboard**.
**Assert:** credit lands in engagement + achievement + lifetime tiers; switcher present throughout; no track-type label.

### F2 — Adult-as-tutor two-phase invite (END-TO-END)
**InviteTutorScreen** (generate token) → email/deep-link `/invite?token=` → **AcceptInviteScreen** 6-step state
machine (email-match, single-use token, transactional access-doc write) → **Tutor PIN setup** → enter talmid
(child's **parent-view, NOT child mode**) → edit a track/points → **live-mark BARRED**
(`TutorWriteForbiddenException`) → **revoke** from ManageTutors → talmid vanishes.
**Also:** offline stub-grant fallback; `incomingTutorGrantsProvider` CF∪mirror union + account-switch dedup
(grant uid-churn: re-created account = new uid orphans grants).

### F3 — Offline → reconnect sync round-trip
Go **offline** (`svc wifi disable`) → mark completions + create a track (queued writes) → confirm Drift-first
reads still render everywhere with **OfflineTopBanner** → **reconnect** → queued writes push →
**SyncStatusIndicator** transitions through its states → DriftMergeStore `remoteIsNewer` / tombstone-resurrection
/ FK-guard behave at the ±5 s boundary. **Assert:** no data loss, no UI is network-gated.

### F4 — Multi-account switch on one device
**AccountPicker** → sign in as 2nd account → hit the **5-account cap** → Google-collides-local → **UpgradeToCloud**
→ confirm per-account Drift DB threading + tutor grants re-resolve against the new uid. **Assert:** switch is
instant, **no sign-out**, lands on Dashboard.

### F5 — Backup → device restore
Fresh device → sign in → **DeviceRestoreScreen** (restoreGuard) → pull cloud state → land on a populated
Dashboard with profiles/tracks/progress intact. **Assert:** no data loss, correct active profile.

### F6 — Persistent profile/mode switcher in EVERY context (repeatedly-requested)
Tap the top role label in **Dashboard / Learn / Progress / Settings / parent portal** → **ProfileSwitcherSheet**
→ switch learner; enter/exit **Parent Mode** (PIN verify); enter/exit **Tutor talmid view**.
**Assert:** the switcher is present in ALL contexts; `_TutorModeIndicatorBar` / child-view banner appear & clear correctly.

### F7 — Parent-mode gated entry & exit
Child-mode app → tap a PIN-gated surface (Parent Settings / Point Config / Reward Config / Pending Redemptions /
Parent Track Management / Lifetime Marking) → **PinFlow verify** (and first-time **setup**, and **change/reset**)
→ perform an action → exit to child mode. **Assert:** pinGuard scoping; **no lockout/dead-end** (this run's guard fix).

### F8 — Full rewards economy loop
Parent configures points (**PointConfig**) + rewards (**RewardConfiguration**) → child earns points via completions
→ **ChildRedemptionScreen** (affordable / unaffordable / confirm) → **ParentPendingRedemptions** approve/decline
(**double-tap guard**) → balance debits + reflects on Dashboard. **Assert:** adults never see points.

### F9 — Bulk prior-progress / lifetime marking (sentinel-date credit policy)
Enter **BulkMarkScreen** (from CurriculumSettings or TrackDetail) OR **LifetimeMarking** → bulk mark with the
sentinel date (1/1/2000) → **assert** siyumim/lifetime credited but **streak and RecentActivity NOT polluted**.

### F10 — Back-dated enrolment → overdue catch-up
**AddTrackFlow** with a back-dated start ∈ [today−30, today] → confirm scheduled catch-up tasks are generated
dated in the past and surface as **OVERDUE** on Scheduler + Dashboard.

### F11 — Chazara per-track conditional
Create a track with **chazaraEnabled = false** → assert **NO chazara UI anywhere** (AddTrackFlow step skipped, no
review card/refs on Dashboard/Scheduler/TrackDetail). Then a **chazaraEnabled = true** track shows the full review pipeline.

### F12 — Skipped-onboarding recovery
Skip profile creation → **EmptyLoginScreen** / zero-profile Dashboard with **SkippedOnboardingCtaBanner** → tap
CTA → resume onboarding (resume-from-prefs) → create first profile → land on a populated Dashboard.

### F13 — Hebrew / RTL + locale
Switch device to **Hebrew** → assert RTL layout, Hebrew terms (binary, independent of UI locale via
`useHebrewTermsProvider`), and locale-aware `DateFormat.yMMMd` dates across audit log / scheduler / progress.
**Watch for** hardcoded English (e.g. "TALMID PROFILES", AppIntro/PermissionPrompt strings, scope empty-state).

### F14 — Guard redirect chains (router L3)
For `/` (AppShell) the guard order is **authGuard → restoreGuard → profileGuard → childModeGuard → pinGuard**.
Walk each redirect path (not-onboarded, new-device, no-profile, child-route-as-adult, pin-gated) and assert a
**clean resolve every time — never a hang/blank (no-dead-end)** — this run's systemic guard fix.

---

# Per-cluster screen-by-screen plans (§1–§12)


# Cluster: First-Run / Onboarding / Restore

Covers: `AppIntroScreen`, `PermissionPromptScreen`, `OnboardingScreen` (all phases including embedded step widgets), `EmptyLoginScreen`, and `DeviceRestoreScreen`.

---

## 1. AppIntroScreen

**Route:** `AppIntroRoute`

**How to reach:**
- Fresh install (no `intro_seen` key in SharedPreferences) — app launches directly here.
- To reproduce on an existing device: `adb shell pm clear com.jcom.torah.learning_tracker` OR clear app data in device Settings, then re-launch.

**Preconditions:** `intro_seen` must be absent or `false` in SharedPreferences.

### 1.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass / Fail / Notes |
|---|--------|---------|-----------------|-------------------|---------------------|
| 1 | Launch app (clean install) | App entry point | `AppIntroScreen` displays with cream (`#F8F9FB`) background; Page 1 (Daily Plan) is visible; hero illustration is animating (scale-in bounce); "Skip" TextButton visible top-right; "Continue Journey" GlowingCtaButton visible at bottom | Route guard fail-safe: must not hang or redirect unexpectedly on first launch | |
| 2 | Observe Page 1 content | Page 1 — Daily Plan | Title "Your Daily Torah Plan" (navy italic "Torah Plan"), subtitle about "clear daily tasks", `IntroDailyPlanIllustration` (animated card), `IntroDailyPlanProgressBar` (green fill ~1/3, label "SETUP PROGRESS") all visible; NO track-type label ("Personal"/"Standard"/"Custom") visible anywhere | Product rule: no track-type label | |
| 3 | Tap "Continue Journey" CTA (GlowingCtaButton, page 1) | Bottom overlaid button | Page animates to Page 2 (Mishna); `_iconController` resets and re-plays animation; page indicator advances; CTA label still reads "Continue Journey" | | |
| 4 | Observe Page 2 content | Page 2 — Mishna | Title "Never Forget a Mishna" (navy italic "Mishna"), subtitle about spaced-repetition engine, `IntroMishnaIllustration` (animated rotate), `IntroMishnaProgressBar` (grey fill ~2/3); NO chazara/review UI beyond the illustration decoration | | |
| 5 | Swipe left on PageView | PageView (anywhere on page body) | Navigates from Page 1/2 to the next page (horizontal swipe gesture triggers `onPageChanged`); CTA label updates; icon animation restarts | | |
| 6 | Swipe right on PageView (page 2 → page 1) | PageView | Navigates back to previous page; page indicator dot moves; CTA label reverts to "Continue Journey" | | |
| 7 | Tap "Continue Journey" CTA (page 2) | Bottom CTA | Page animates to Page 3 (Rewards); CTA label changes to "Get Started"; `_currentPage` == 2 (last) | | |
| 8 | Observe Page 3 content | Page 3 — Rewards | Title "Earn While You Learn", `IntroRewardsHeroIllustration` (scale-in bounce with trophy/star/streak badge), `IntroChildModeTag` banner ("For Child profiles only — Points, streaks, and rewards..."), `IntroFeatureCardsRow` (Badge Collection + Mystery Prizes cards), `IntroScholarLevelCard` (shows "Scholar Progress" + "EXAMPLE" badge + NOVICE → TALMID CHOCHOM/תלמיד חכם progress bar); NO real user data displayed; NO track-type label | Product rule: Adults have no points/gamification (banner explicitly notes child-only); no track-type label | |
| 9 | Verify `IntroScholarLevelCard` label (Hebrew terms ON) | `IntroScholarLevelCard` right label | Shows the Hebrew term from `domainTermLabels(ref).talmidChochomCaps` (e.g. "תלמיד חכם" in Hebrew locale, or "TALMID CHOCHOM" in English locale) — confirm it responds to locale, not hardcoded English | Product rule: Hebrew terms vs transliteration is independent of UI locale | |
| 10 | Tap "Get Started" CTA (page 3, final page) | Bottom CTA | `_markIntroSeenAndContinue()` is called: `intro_seen = true` is written to SharedPreferences; navigation replaces to `SignInRoute`; `AppIntroScreen` is removed from the stack | Session fix: route guards never lock out / hang navigation | |
| 11 | Tap "Skip" TextButton (any page) | Top-right "Skip" TextButton | Same outcome as step 10 — `_markIntroSeenAndContinue()` fires; `intro_seen = true`; navigates to `SignInRoute` | Session fix: route guards never lock out | |
| 12 | Re-launch app after step 10 or 11 | App entry | `AppIntroScreen` is NOT shown (intro_seen = true); goes directly to sign-in/auth gate | | |
| 13 | Verify "Skip" is at end (AlignmentDirectional.centerEnd) in RTL locale | Header, Hebrew locale | "Skip" button is on the LEFT side of the header (RTL) because `AlignmentDirectional.centerEnd` maps to left in RTL | Product rule: Hebrew/RTL rendering | |
| 14 | Observe dark mode rendering | Entire screen (system dark mode ON) | Background `_kBg = #F8F9FB` and navy `_kNavy = #1A36A5` used directly — verify no text becomes invisible; the GlowingCtaButton (navy fill) remains legible with cream text | | |
| 15 | Observe very short viewport (small device / split screen) | Page 1 on short viewport | `SingleChildScrollView` with `BouncingScrollPhysics` prevents overflow; hero is constrained `[220, 320]` px and scales with `FittedBox`; bottom CTA reserve of 82 px leaves space | | |

### 1.2 States to Verify

| State | How to Reach | What to Verify |
|-------|-------------|----------------|
| Page 1 (first launch) | Fresh install | Hero animation plays; progress bar at ~1/3 |
| Page 2 | Swipe or tap CTA | Hero rotates; progress bar at ~2/3 |
| Page 3 (last) | Swipe/CTA twice | "Get Started" label; `IntroChildModeTag` visible |
| RTL (Hebrew) | Device language = Hebrew | "Skip" on left side; talmidChochomCapsLabel shows Hebrew |
| Dark mode | System dark mode | Navy/cream colours still legible |
| Very small viewport | Tiny display / split-screen | No RenderFlex overflow; hero scales down |

---

## 2. PermissionPromptScreen

**Route:** `PermissionPromptRoute(isOnboarding: bool)`

**How to reach:**
- **Onboarding path** (`isOnboarding: true`): During `OnboardingScreen`, after "Add Another Prompt" step → "Start Learning" → `_PermissionPromptPhase` pushes this route automatically. Title reads "Almost Done!", CTA reads "Start Learning".
- **Settings path** (`isOnboarding: false`): Navigated to from the Settings screen (re-prompt after install). Title reads "App Permissions", CTA reads "Done".

### 2.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass / Fail / Notes |
|---|--------|---------|-----------------|-------------------|---------------------|
| 1 | Arrive via onboarding path | Screen | AppBar title "Almost Done!"; subtitle "Allow these optional permissions so Learning Tracker can remind you to learn and compute Shabbos times for your location."; two permission cards (Notifications, Location) each show "Allow" FilledButton (blue, idle state) | | |
| 2 | Arrive via Settings path | Screen | AppBar title "App Permissions"; subtitle "Manage optional permissions for reminders and Shabbos-time calculations."; "Done" primary CTA at bottom; "Skip for now" TextButton visible below CTA (at least one card still idle) | | |
| 3 | Tap "Allow" on Notifications card | Notifications "Allow" button | Button transitions to spinner (CircularProgressIndicator, 22 × 22 px); OS permission dialog appears requesting POST_NOTIFICATIONS (Android 13+) | | |
| 4 | Grant notifications in OS dialog | OS system dialog | OS dialog dismissed; card status → granted; check-circle icon (green `#1E7B5A`) replaces the Allow button; no crash | Session fix: magic-link / deep-link handling; connectivity routing | |
| 5 | Deny notifications in OS dialog | OS system dialog | Card status → denied; cancel-outlined icon (grey `#9CA3B4`) replaces the Allow button; no error message shown (denial is graceful) | | |
| 6 | Tap "Allow" on Location card | Location "Allow" button | Spinner shows; OS permission dialog for location (fine/coarse) appears | | |
| 7 | Grant location in OS dialog | OS system dialog | Card → granted; green check-circle; `SacredLocationNotifier.detect()` fires; no crash | | |
| 8 | Deny location in OS dialog | OS system dialog | Card → denied; grey cancel icon; graceful | | |
| 9 | Attempt to tap "Allow" again after card is in granted/denied state | Notifications or Location card (granted/denied) | `onTap: null` — button is inert (no second fire); `_notifDone` / `_locationDone` guard prevents re-entry | Product rule: no double-fire on guarded actions | |
| 10 | Verify "Skip for now" TextButton disappears when both cards are resolved | Both cards granted or denied | "Skip for now" TextButton is no longer visible (`!_allDone` condition is false); only the primary CTA remains | | |
| 11 | Tap "Skip for now" TextButton | "Skip for now" TextButton | Calls `_finish()` → `context.maybePop()`; screen pops; navigation continues correctly (child → handoff step; adult → dashboard) | Session fix: route guards never lock out / hang | |
| 12 | Tap "Start Learning" / "Done" primary FilledButton | Primary CTA at bottom | Calls `_finish()` → `context.maybePop()`; screen pops regardless of permission state (both are optional); no crash | | |
| 13 | Tap AppBar back arrow (if present) | AppBar leading back arrow | Screen pops; no navigation hang | Session fix: route guards never lock out | |
| 14 | Press Android system Back button | OS back button | Screen pops via `maybePop`; no navigation hang or crash | Session fix: route guards never lock out | |
| 15 | Verify requesting state prevents double-tap | Rapidly double-tap "Allow" on either card | Guard `if (_notifStatus == _PermissionStatus.requesting) return;` prevents duplicate OS dialog from firing | | |
| 16 | Verify dark mode | System dark mode | `AppTheme.brandCreamCard` background + white card interiors remain legible; blue FilledButton has sufficient contrast | | |

### 2.2 States to Verify

| State | How to Reach | What to Verify |
|-------|-------------|----------------|
| Idle (both cards not yet tapped) | Fresh arrival | "Skip for now" visible; "Allow" buttons on both cards |
| Requesting | Tap "Allow" | Spinner shown; button disabled |
| Granted (one or both) | Grant OS permission | Green check-circle; cannot re-tap |
| Denied (one or both) | Deny OS permission | Grey cancel icon; cannot re-tap |
| All resolved | Both granted or denied | "Skip for now" hidden; primary CTA only |
| Onboarding variant | Via onboarding flow | "Almost Done!" title + "Start Learning" CTA |
| Settings variant | Via Settings | "App Permissions" title + "Done" CTA |

---

## 3. OnboardingScreen — Phase: Profile Creation (`OnboardingProfileCreationStep`)

**Route:** `OnboardingRoute` (phase `profileCreation`)

**How to reach:**
- After sign-up (new account, no existing profiles): app navigates to `OnboardingRoute` automatically.
- If `onboarding_complete` is not set in SharedPreferences, the route guard sends new users here.
- For testing: clear app data, create new account via sign-up.

**Preconditions:** User is signed in (verified by `authStateProvider.isSignedIn`); if not signed in, screen redirects to `SignInRoute` (auth guard).

### 3.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass / Fail / Notes |
|---|--------|---------|-----------------|-------------------|---------------------|
| 1 | Arrive at profile creation step | Screen | No AppBar; gradient cream-to-blue body; "What should we call you?" heading; name TextField (hint "Enter name", edit icon suffix); "Learning Experience" section with two mode cards (Child Mode / Adult Mode); preferences card (Nikud, Calendar, optionally Hebrew Terms); "Create Profile" FilledButton (disabled until name typed); "You can change these settings anytime later." note; "Skip for now" TextButton at bottom | Session fix: route guards never lock out on AuthState failure | |
| 2 | Tap name TextField | Name TextField | Keyboard opens; cursor in field; border highlights blue; no leading spaces (TrimLeadingSpaceFormatter active) | | |
| 3 | Type a valid name (e.g., "Yosef") | Name TextField | "Create Profile" button becomes enabled (blue); no error shown; `_nameError == null` | | |
| 4 | Clear name field (empty) | Name TextField → delete all | "Create Profile" button disabled again; no error shown for empty (validation only fires for non-empty duplicate check) | | |
| 5 | Type a name that is a duplicate of an existing profile | Name TextField | After short async validation delay: `_nameError = 'A profile with this name already exists'`; red error text under field; "Create Profile" button disabled | | |
| 6 | Type a very long name (50+ characters) | Name TextField | No explicit max-length limit in code — executor should verify field accepts or truncates; check for overflow in the button/profile display | | |
| 7 | Tap "Child Mode" card | Child Mode InkWell card | Card gets blue border + "ACTIVE" red badge top-right; Adult Mode card loses selection; `_profileMode = 'child'` | | |
| 8 | Tap "Adult Mode" card | Adult Mode InkWell card | Card gets blue border + "ACTIVE" badge; Child Mode card deselected; `_profileMode = 'adult'` (default) | | |
| 9 | Tap "Without nikud" pill (Nikud section) | Left pill of Nikud pillPair | Pill turns white (selected); Right pill ("With nikud") turns grey; `_showNikud = false` | | |
| 10 | Tap "With nikud" pill (Nikud section) | Right pill of Nikud pillPair | Right pill selected (default state); `_showNikud = true` | | |
| 11 | Tap "English" pill (Calendar section) | Left pill of Calendar pillPair | `_useHebrewCalendar = false`; "English" selected | | |
| 12 | Tap "Hebrew" pill (Calendar section) | Right pill of Calendar pillPair | `_useHebrewCalendar = true` (default); "Hebrew" selected | | |
| 13 | Verify Hebrew Terms section (non-Hebrew device locale) | Hebrew Terms pillPair | Section IS visible (condition: `languageCode != 'he'`); can toggle English/Hebrew for terms preference | Product rule: Hebrew terms vs transliteration independent of UI locale | |
| 14 | Verify Hebrew Terms section (Hebrew device locale) | Entire prefs card | Hebrew Terms section is NOT rendered (condition `languageCode != 'he'` is false); only Nikud and Calendar sections visible | Product rule: Hebrew terms vs transliteration independent of UI locale | |
| 15 | Tap "Create Profile" button with valid name and no error | "Create Profile" FilledButton | Button shows CircularProgressIndicator spinner; async profile creation fires; on success transitions to next phase (parentPinSetup if childMode, intentChooser if adult); button cannot be tapped again during creation (`_isCreatingProfile` guard) | Session fix: route guards never lock out | |
| 16 | Verify no double-creation on rapid tap | "Create Profile" FilledButton — tap twice quickly | Second tap is ignored (`_isCreatingProfile` guard); only one profile created | | |
| 17 | Tap "Skip for now" TextButton | "Skip for now" TextButton | Calls `onSkipProfileCreation` callback → `_navigateToDashboardSkipped(joinedToTutor: false)`; sets `onboarding_complete = true`, `onboarding_skipped = true` in SharedPreferences; navigates to `EmptyLoginRoute` | Session fix: route guards never lock out | |
| 18 | Scroll the page | SingleChildScrollView | Content scrolls; keyboard remains manageable; no overflow | | |
| 19 | Verify onboarding resume after backgrounding mid-profile-creation | Background app after typing name, reopen | If profile row not yet committed, `_tryResumeFromSavedState` returns null (phase not saved yet) — form resets; name field is empty; profile creation phase restarts from scratch | | |

### 3.2 States to Verify

| State | How to Reach | What to Verify |
|-------|-------------|----------------|
| Initial (empty name) | Arrive fresh | "Create Profile" disabled |
| Valid name typed | Type in field | Button enabled |
| Duplicate name | Type existing profile name | Error shown; button disabled |
| Creating (in-progress) | Tap "Create Profile" | Spinner shown; button disabled |
| Child mode selected | Tap "Child Mode" card | ACTIVE badge on child card |
| Adult mode selected (default) | Tap "Adult Mode" card | ACTIVE badge on adult card |
| Hebrew locale | Device lang = Hebrew | Hebrew Terms section hidden |
| English locale | Device lang = English | Hebrew Terms section visible |

---

## 4. OnboardingScreen — Phase: Parent PIN Setup (`OnboardingParentPinStep`)

**Route:** `OnboardingRoute` (phase `parentPinSetup`)

**How to reach:**
- After profile creation step completes with `isChildMode = true` (Child Mode selected).
- AppBar shows "Set Parent PIN".

### 4.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass / Fail / Notes |
|---|--------|---------|-----------------|-------------------|---------------------|
| 1 | Arrive at parent PIN step | Screen | AppBar title "Set Parent PIN"; card body with subtitle "Set a 4-digit PIN to access parent controls for [childName]. The PIN is stored only on this device."; `PinEntryWidget` with title "Enter New PIN"; 4 digit slots; no error | | |
| 2 | Tap first PIN digit slot | PIN digit slot 1 | Numeric keyboard appears; focus on slot 1 | | |
| 3 | Enter 4 digits one by one | PIN slots 1–4 | Each slot fills with a bullet (●) visual indicator (NOT the character — transparent text with overlay circle); focus auto-advances to next slot on each digit; after digit 4 keyboard hides; `_onFirstPinEntered` fires | | |
| 4 | Enter partial PIN (1–3 digits) and wait | PIN slots | No `onPinComplete` fires; callback only fires on exactly 4 digits | | |
| 5 | Enter backspace in slot 2 | PIN slot 2 (backspace) | Slot 2 clears; focus moves back to slot 1 | | |
| 6 | Enter first PIN successfully (e.g., "1234") | PIN slot 4 | Subtitle changes to "Re-enter the PIN to confirm"; widget title changes to "Confirm PIN"; all 4 slots clear (new step triggered `didUpdateWidget`); no error shown | | |
| 7 | Enter matching confirmation PIN ("1234") | Confirm PIN slots | `_onConfirmPinEntered` fires; PINs match → `pinService.setProfilePin` called; on success: PIN step transitions away (onComplete); navigates to `addTrack` phase | | |
| 8 | Enter non-matching confirmation PIN (e.g., "5678") | Confirm PIN slots | Error message "PINs do not match"; `_pinStep` resets to `enterPin`; title reverts to "Enter New PIN"; all slots clear (error appeared → `didUpdateWidget` clears) | | |
| 9 | After mismatch error, re-enter correctly | PIN slots (after error) | Error clears; retry from step 6 | | |
| 10 | Verify "Clear" TextButton in error state | "Clear" TextButton (appears in error row) | Tapping clears all slots; focus moves to slot 1 | | |
| 11 | Verify lockout state (if triggered) | PIN lockout container | If `isLockedOut = true` (not set in onboarding flow but test the widget directly): shows lock-clock icon, "Too many failed attempts", "Try again in N minute(s)" countdown container instead of digit slots; no digit input possible | | |
| 12 | Scroll card when keyboard visible | SingleChildScrollView | Card scrolls up so PIN fields remain visible; no overflow | | |
| 13 | Press Android back button | OS back | Behavior depends on navigator stack — executor should verify: does back return to profile creation step or does the guard prevent back-navigation during PIN setup? Note: source does not explicitly block back; behavior is **unclear from source — probe carefully** | Session fix: route guards never lock out / hang navigation | |

### 4.2 States to Verify

| State | How to Reach | What to Verify |
|-------|-------------|----------------|
| Initial (enter step) | Arrive at step | "Enter New PIN" title; empty slots; no error |
| Confirm step | Enter 4 digits | "Confirm PIN" title; slots cleared |
| Mismatch error | Enter differing confirmation | Error row visible; "Clear" button present |
| Lockout | Not reachable in onboarding (no attempts guard), but verify widget renders lock message if provided | Lock icon + countdown |

---

## 5. OnboardingScreen — Phase: Intent Chooser (`OnboardingIntentStep`)

**Route:** `OnboardingRoute` (phase `intentChooser`)

**How to reach:**
- Adult mode profile created (Child mode skips directly to `addTrack`).
- No AppBar shown (hidden by `showAppBar` guard in `OnboardingScreen.build()`).

### 5.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass / Fail / Notes |
|---|--------|---------|-----------------|-------------------|---------------------|
| 1 | Arrive at intent chooser | Screen | No AppBar; "What brings you here?" heading (h800 weight); "Choose how you want to get started." subtext; two intent cards: (a) "Track my own learning" (book icon, blue deep), (b) "Skip for now" (skip-next icon, green). Note: "Join to tutor someone" card is intentionally ABSENT from this step per source comment | Product rule: tutor flow reached via invite link, not this step | |
| 2 | Tap "Track my own learning" card | First `_IntentCard` | `onChosen(OnboardingIntent.trackMyLearning)` fires; `_phase` transitions to `addTrack`; `OnboardingScreen` shows `AddTrackFlow` | | |
| 3 | Tap "Skip for now" card | Second `_IntentCard` | `onChosen(OnboardingIntent.skipForNow)` fires; `_navigateToDashboardSkipped(joinedToTutor: false)`; sets `onboarding_complete = true`, `onboarding_skipped = true` in SharedPreferences; navigates to `EmptyLoginRoute` | Session fix: route guards never lock out | |
| 4 | Confirm "Join to tutor someone" card is absent | Entire screen | The card with `OnboardingIntent.joiningToTutor` is NOT rendered; only two cards present | Source comment explicitly removed it from this step | |
| 5 | Scroll the page | SingleChildScrollView | Both cards scroll if viewport is small | | |
| 6 | Verify chevron icons on cards | Both cards | Each card has `Icons.chevron_right_rounded` on trailing edge (RTL: maps to left) | | |
| 7 | Press Android back button | OS back | Behavior **unclear from source** — `OnboardingScreen` is a `ConsumerStatefulWidget` with internal state machine; back may navigate back inside the navigator or be blocked; probe carefully | Session fix: route guards never hang | |

---

## 6. OnboardingScreen — Phase: Add Another Prompt (`OnboardingAddAnotherPromptStep`)

**Route:** `OnboardingRoute` (phase `addAnotherPrompt`)

**How to reach:**
- After `AddTrackFlow` completes successfully → `_onAddTrackComplete` fires → `_trackCount++` → phase set to `addAnotherPrompt`.
- AppBar shows "Track Ready!".

### 6.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass / Fail / Notes |
|---|--------|---------|-----------------|-------------------|---------------------|
| 1 | Arrive after first track added | Screen | AppBar "Track Ready!"; large check-circle icon; `'Your track "[trackLabel]" is ready!'` heading; `'You have 1 track set up.'` subtext; "Start Learning" FilledButton; "Add another track" OutlinedButton | | |
| 2 | Arrive after second track added | Screen | Subtext reads "You have 2 tracks set up." (pluralization check) | | |
| 3 | Tap "Start Learning" FilledButton | "Start Learning" FilledButton | Calls `onStartLearning`; `_phase` → `permissionPrompt`; `_PermissionPromptPhase` widget appears; pushes `PermissionPromptRoute(isOnboarding: true)` | | |
| 4 | Tap "Add another track" OutlinedButton | "Add another track" OutlinedButton | Calls `onAddAnotherTrack`; `_phase` → `addTrack`; `AddTrackFlow` shown again | | |
| 5 | Verify track label displayed | Heading text | Label matches the `result.label` returned from `AddTrackFlow`; correctly quoted; no track-type prefix ("Personal"/"Standard"/etc.) | Product rule: no track-type label anywhere | |

---

## 7. OnboardingScreen — Phase: Handoff (`OnboardingHandoffStep`)

**Route:** `OnboardingRoute` (phase `handoff`)

**How to reach:**
- Child mode profile: after `_PermissionPromptPhase` resolves → `onChildModeComplete` fires → phase set to `handoff`.
- Also reachable if child-mode track setup is cancelled (`_onAddTrackCancel` with child mode).
- AppBar shows "Setup Complete!".

### 7.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass / Fail / Notes |
|---|--------|---------|-----------------|-------------------|---------------------|
| 1 | Arrive at handoff step (child mode) | Screen | AppBar "Setup Complete!"; large check-circle (80 px); `"[childName]'s learning is all set up"` heading; `"Hand the device to [childName] to start learning"` body; `"You can set up rewards later in Parent Mode"` italic note; "Start Learning" FilledButton; "Add another track" OutlinedButton; "Add another learner" TextButton | | |
| 2 | Verify child name displayed | Heading and body texts | Shows actual profile name (e.g., "Shimon's learning is all set up"); fallback "Your child" if name is null | | |
| 3 | Tap "Start Learning" FilledButton | "Start Learning" button | Calls `onStartLearning` → `_navigateToDashboard()`; clears onboarding state; marks complete; if profiles ≥ 2 → `ProfilePickerRoute`, else → `AppShellRoute` | Session fix: route guards never lock out | |
| 4 | Tap "Add another track" OutlinedButton | "Add another track" button | Calls `onAddAnotherTrack` → `_phase = addTrack`; `AddTrackFlow` shown for this child profile | | |
| 5 | Tap "Add another learner" TextButton | "Add another learner" TextButton | Calls `onAddAnotherLearner` → `_addAnotherLearner()`; resets all state (`_createdProfileId = null`, `_profileMode = 'adult'`, etc.); `_phase = profileCreation`; user can create a new profile | | |
| 6 | Verify no adult-profile path reaches handoff | Adult flow | Adult mode: after permissions, `_navigateToDashboard()` is called directly (bypasses handoff). Handoff is child-only. | | |

---

## 8. OnboardingScreen — Phase: Done (`OnboardingDoneStep`)

**Route:** `OnboardingRoute` (phase `done`)

**How to reach:**
- This phase is defined in the enum but not explicitly set by any transition in the current `OnboardingScreen` source — it appears to be a legacy/unused terminal step. The AppBar would show "All Set!". Executor should check if any code path reaches this phase during normal flow.

### 8.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass / Fail / Notes |
|---|--------|---------|-----------------|-------------------|---------------------|
| 1 | Observe if phase is reachable | Navigation trace | `OnboardingDoneStep` shows: check-circle icon + "All set!" (from l10n.allSet); no interactive elements. **Source shows no code path currently sets `_phase = done` — verify this is dead code or probe via resume store phase = 'done'** | Unclear from source — probe carefully | |

---

## 9. Onboarding Wizard Steps — Learning Process Wizard (`wizard_steps.dart`)

**How to reach:**
- These steps are shown inside `AddTrackFlow` (not directly in `OnboardingScreen`), which is used during the `addTrack` phase. They are reached via the `learning_process_wizard_screen.dart`.
- `WizardChooseMethodStep` is step 1 of the wizard inside the track setup flow.

### 9.1 WizardChooseMethodStep (Step 1 — Choose Method)

| # | Action | Element | Expected Result | Product Rule / Fix | Pass / Fail / Notes |
|---|--------|---------|-----------------|-------------------|---------------------|
| 1 | Arrive at wizard step 1 | Screen | "How do you review?" (adult) OR "How does [childName] review?" (child mode); curriculum label below heading; up to 3 option cards: "Follow a program" (only if presets.isNotEmpty), "Custom schedule", "No formal review" | | |
| 2 | Tap "Follow a program" card | `_OptionCard` with school icon | Calls `ctx.advance()`; navigates to `WizardSelectPresetStep` | | |
| 3 | Tap "Custom schedule" card | `_OptionCard` with tune icon | Calls `onComplete(WizardResult(choice: WizardChoice.custom))`; skips preset selection; goes to custom wizard | | |
| 4 | Tap "No formal review" card | `_OptionCard` with play_arrow icon | Calls `onComplete(WizardResult(choice: WizardChoice.noReview))`; wizard completes with no-review choice; NO chazara/review UI should be set up | Product rule: chazara UI only when track has chazaraEnabled | |
| 5 | Verify chevron on each card | Trailing of each `_OptionCard` | `Icons.chevron_right` visible on each card | | |
| 6 | If presets are empty, verify "Follow a program" absent | `_OptionCard` list | "Follow a program" card is NOT rendered when `presets.isEmpty` | | |

### 9.2 WizardSelectPresetStep (Step 2 — Select Program)

| # | Action | Element | Expected Result | Product Rule / Fix | Pass / Fail / Notes |
|---|--------|---------|-----------------|-------------------|---------------------|
| 7 | Arrive at preset selection | Screen | "Select a program" heading (or child variant); scrollable `ListView` of `_PresetCard` items; "Confirm" FilledButton (disabled until a preset selected) | | |
| 8 | Tap a preset card | Any `_PresetCard` | Card selected (blue border, elevated, check-circle icon); "Confirm" button enabled | | |
| 9 | Tap a different preset card | Another `_PresetCard` | Previous deselects; new card selected (radio-style single selection via `data.selectedPresetId`) | | |
| 10 | Tap "Confirm" button (with preset selected) | FilledButton "Confirm" | `onComplete(WizardResult(choice: WizardChoice.preset, programId: selectedPresetId))`; wizard completes | | |
| 11 | Tap "Confirm" without selection | FilledButton (disabled) | Button is disabled (`onPressed: null`); no action | | |

### 9.3 WizardCustomStep1 (Custom — Choose Rounds)

| # | Action | Element | Expected Result | Product Rule / Fix | Pass / Fail / Notes |
|---|--------|---------|-----------------|-------------------|---------------------|
| 12 | Arrive at custom step 1 | Screen | "How many review rounds?" heading; "Each round reviews the material at increasing intervals" subtitle; large display counter "1 round"; Slider (min 1, max 5, divisions 4, labeled); "Next" FilledButton | | |
| 13 | Drag slider to 3 | Slider | Counter updates to "3 rounds" (plural); slider label "3" | | |
| 14 | Drag slider to 1 | Slider | Counter updates to "1 round" (singular) | | |
| 15 | Tap "Next" button | "Next" FilledButton | `ctx.advance()`; rounds list synced to match slider value; navigates to `WizardCustomStep2` | | |

### 9.4 WizardCustomStep2 (Custom — Set Delays per Round)

| # | Action | Element | Expected Result | Product Rule / Fix | Pass / Fail / Notes |
|---|--------|---------|-----------------|-------------------|---------------------|
| 16 | Arrive at custom step 2 | Screen | "Set delay for each round" heading; list of `_RoundTimingCard` items (one per round set in step 1); each card shows chazara stage label (domain term, e.g., "Chazara 1" or Hebrew), SegmentedButton "Days / Weeks", delay slider or day-of-week chips | Product rule: chazara terms from domain terms (Hebrew if Hebrew terms setting ON) | |
| 17 | Tap "Weeks" segment on a round card | SegmentedButton "Weeks" | `state.useWeekly = true`; day-of-week FilterChips appear (Sun, Mon, Tue, Wed, Thu, Fri, Shabbos); delay slider hidden | | |
| 18 | Tap day chips (Shabbos, Mon) | FilterChip for Shabbos, FilterChip for Mon | Both chips selected (multi-select); `state.selectedDays` contains {6, 1} | | |
| 19 | Deselect a chip | FilterChip — tap selected chip | Chip deselects; removed from `state.selectedDays` | | |
| 20 | Tap "Days" segment (switch back) | SegmentedButton "Days" | `state.useWeekly = false`; delay slider reappears; day chips hidden | | |
| 21 | Drag delay slider | Slider (1–60 days) | Label updates "N day(s) after"; min 1 day, max 60 days, 59 divisions | | |
| 22 | Tap "Next" button | "Next" FilledButton | `ctx.advance()`; navigates to `WizardCustomStep3` | | |

### 9.5 WizardCustomStep3 (Custom — Review & Confirm Schedule)

| # | Action | Element | Expected Result | Product Rule / Fix | Pass / Fail / Notes |
|---|--------|---------|-----------------|-------------------|---------------------|
| 23 | Arrive at custom step 3 | Screen | "Review your schedule" heading; Card showing "Learn / Daily new material" then each chazara stage with its delay summary; "Confirm" FilledButton | Product rule: chazara UI renders ONLY when track has chazaraEnabled; confirm no reference to chazara if noReview was chosen (wizard branch guard) | |
| 24 | Verify daily new-material row | Card content | Shows domain term `terms.stageLearn` (Hebrew if Hebrew terms ON) + "Daily new material" | Product rule: Hebrew terms independent of UI locale | |
| 25 | Verify chazara stage rows | Card content | Each round shows `terms.chazaraStage(i+1)` + delay description ("N days after learning" or "Every Mon, Fri"); Dividers between rounds | Product rule: chazara UI only present for tracks with chazaraEnabled | |
| 26 | Tap "Confirm" | "Confirm" FilledButton | `onComplete(LearningProcessWizardResult(...))` fires with custom rounds; wizard exits; `AddTrackFlow` receives result | | |

---

## 10. EmptyLoginScreen

**Route:** `EmptyLoginRoute`

**How to reach:**
- After skipping profile creation in onboarding (`onSkipProfileCreation` tap), or after skipping in the intent chooser.
- Key condition: `onboarding_complete = true`, `onboarding_skipped = true` in SharedPreferences; zero profiles exist.
- The `ProfileGuard` on `AppShellRoute` blocks zero-profile accounts; `EmptyLoginRoute` has no such guard.

### 10.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass / Fail / Notes |
|---|--------|---------|-----------------|-------------------|---------------------|
| 1 | Arrive at empty login screen | Screen | AppBar title "Learning Tracker" (from l10n); no back arrow (replacement route); account-switch icon button in AppBar actions (only visible if ≥ 2 accounts exist); Settings icon button in AppBar actions; `SkippedOnboardingCtaBanner`; Divider; "I'm a tutor" `OutlinedButton.icon`; `DeviceNotificationToggle` card; gradient background | | |
| 2 | Verify account-switch icon (single account) | AppBar trailing | `IconButton(Icons.switch_account_outlined)` is ABSENT when `accountCount < 2` (FutureBuilder renders `SizedBox.shrink`) | Product rule: account switching needs no sign-out; available only if multiple accounts exist | |
| 3 | Verify account-switch icon (multiple accounts) | AppBar trailing (2+ accounts) | `Icons.switch_account_outlined` button IS visible; tapping pushes `AccountPickerRoute` | Product rule: account switching → instant switch to Dashboard without sign-out | |
| 4 | Tap account-switch icon (multiple accounts) | `IconButton(Icons.switch_account_outlined)` | `AccountPickerRoute` pushed; on account selection, navigates to that account's dashboard without sign-out | Product rule: account switching needs no sign-out (instant switch) | |
| 5 | Tap Settings icon button | `IconButton(Icons.settings_outlined)` | `SettingsRoute` pushed; no crash | | |
| 6 | Verify `SkippedOnboardingCtaBanner` content — skip path | Banner | Banner visible with waving-hand icon, "Get started" heading, "Add a learning track to begin tracking your progress." body; "Add a learning track" FilledButton.icon with `Icons.add_rounded`; "Dismiss" TextButton | | |
| 7 | Verify `SkippedOnboardingCtaBanner` content — tutor-join path | Banner (when `onboarding_joined_to_tutor = true`) | Banner shows `l10n.tutorWelcomeBannerTitle` and `l10n.tutorWelcomeBannerBody` instead of generic "Get started" copy | | |
| 8 | Tap "Add a learning track" FilledButton in banner | FilledButton.icon | Navigates to `TrackManagementHubRoute(startAdding: true)`; no crash | | |
| 9 | Tap "Dismiss" TextButton in banner | "Dismiss" TextButton | Calls `clearOnboardingSkipState()` → removes `onboarding_skipped` and `onboarding_joined_to_tutor` from SharedPreferences; `onboardingSkipStateProvider` invalidated; banner disappears on next rebuild (state.skipped = false) | | |
| 10 | Tap "I'm a tutor" OutlinedButton (key: `empty_login_tutor_entry`) | OutlinedButton.icon with `Icons.school_outlined` | `context.router.replaceAll([const ProfilePickerRoute()])` — navigates to ProfilePicker showing "TALMID PROFILES" section with active tutor grants; no crash | Product rule: tutor sees child's parent-management surfaces | |
| 11 | Verify `DeviceNotificationToggle` card | `Card` with `SwitchListTile` (key: `device_notification_toggle`) | Card visible with toggle; subtitle shows "Checking..." briefly then either "Allowed" or "Blocked"; toggle fires `_onToggleChanged` on interaction | Product rule (DEC-27): notification toggle available even before any profile exists | |
| 12 | Toggle notifications ON (if currently OFF) | `SwitchListTile` toggle | OS permission dialog fires; on grant: toggle state updates to ON, subtitle "Allowed"; on denial: toggle stays OFF, SnackBar with `deviceNotificationsBlockedHint` message appears | | |
| 13 | Toggle notifications OFF (if currently ON) | `SwitchListTile` toggle | SnackBar shows `deviceNotificationsDisableHint` ("Open Settings to disable"); toggle state reverts to ON (cannot programmatically disable) | | |
| 14 | Background then foreground app | `WidgetsBindingObserver.didChangeAppLifecycleState` | On resume: `_checkPermission()` re-queries OS state; if user disabled in OS Settings during background, toggle reflects new OFF state | | |
| 15 | Press Android back button | OS back | No back target (replacement route); Android back may exit app or do nothing — verify no crash or navigation hang | Session fix: route guards never lock out / hang | |
| 16 | Verify no profile-management UI | Entire screen | No profile list, profile switcher, or profile-management controls; this is a zero-profile surface | Product rule: Profile management only in PROFILE section of Settings | |
| 17 | Verify no gamification UI | Entire screen | No points, streaks, or rewards display (no profile, no gamification) | Product rule: adults have no points/gamification | |

### 10.2 States to Verify

| State | How to Reach | What to Verify |
|-------|-------------|----------------|
| Skip path | `onboarding_skipped = true`, `onboarding_joined_to_tutor = false` | Generic "Get started" banner |
| Tutor-join path | `onboarding_joined_to_tutor = true` | Tutor welcome banner copy |
| Single account | Only one device account | No switch-account icon |
| Multiple accounts | Sign in with two separate accounts | Switch-account icon visible |
| Notifications checking | Just arrived | "Checking..." subtitle briefly |
| Notifications granted | OS permission granted | "Allowed" subtitle + ON toggle |
| Notifications denied | OS permission denied | "Blocked" subtitle + OFF toggle |
| Offline | Airplane mode | Screen renders normally (offline-first; no sync UI on this surface) |

---

## 11. DeviceRestoreScreen

**Route:** `DeviceRestoreRoute`

**How to reach:**
- Automatic: `RestoreGuard` intercepts navigation on first post-sign-in request when it detects a new device (cloud account exists AND local DB is empty — no completions, no user profiles).
- Manual / forced: clear app data, sign in with existing cloud account.

**Preconditions:** Firebase account signed in; local DB empty (0 completions, 0 user profiles).

### 11.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass / Fail / Notes |
|---|--------|---------|-----------------|-------------------|---------------------|
| 1 | Arrive at restore screen (new device) | `RestoreGuard` redirect | `DeviceRestoreScreen` shown; `_startRestore()` fires in `initState`; initial `restoreStatusProvider` state = `idle` (SizedBox.shrink shown briefly) | Session fix: route guards never lock out / hang — RestoreGuard must call `resolver.next()` on any exception | |
| 2 | Observe "checking" state | `restoreStatusProvider` = `checking` | `CircularProgressIndicator` + `l10n.deviceRestoreChecking` text ("Checking for your data...") displayed | | |
| 3 | Observe "restoring" state | `restoreStatusProvider` = `restoring(phase, completedSteps, totalSteps)` | CircularProgressIndicator + phase label (e.g., "Restoring profiles"); `LinearProgressIndicator` with fill = `completedSteps / totalSteps`; step count text via `l10n.deviceRestoreStep(N, M)`; smooth progress updates | | |
| 4 | Observe "complete" state | `restoreStatusProvider` = `complete(collectionsRestored)` | Gold check-circle icon (`AppTheme.brandGold`, 64 px); `l10n.deviceRestoreComplete` text; then `_navigateAfterRestore()` fires automatically | | |
| 5 | Verify navigation after restore — 1 profile | 1 profile in restored DB | `selectedProfileIdProvider` set to that profile's ID; navigates to `AppShellRoute` | Session fix: restore guard marks complete; route guard no longer redirects | |
| 6 | Verify navigation after restore — 2+ profiles | 2+ profiles in restored DB | `selectedProfileIdProvider` cleared; navigates to `ProfilePickerRoute` | | |
| 7 | Verify navigation after restore — 0 profiles | 0 profiles (defensive path) | Navigates to `AppShellRoute` (defensive fallback) | | |
| 8 | Observe "error" state | `restoreStatusProvider` = `error(message)` | Red `Icons.error_outline` icon (64 px, `AppTheme.brandCoralDeep`); `l10n.deviceRestoreFailed` title; error `message` body text; "Retry" `ElevatedButton`; "Skip and continue" `TextButton` | | |
| 9 | Tap "Retry" button (error state) | "Retry" `ElevatedButton` | `_retry()` called → `service.retry()`; if succeeds → `_navigateAfterRestore()`; UI transitions back to checking/restoring states | | |
| 10 | Tap "Skip and continue" TextButton (error state) | "Skip and continue" `TextButton` | `_navigateToApp()` called → `_refreshProvidersAfterRestore()` (invalidates profile providers); `restoreGuard.markRestoreComplete()`; navigates to `AppShellRoute` | Session fix: route guard must not re-trigger after skip; `markRestoreComplete()` sets `_isNewDevice = false` | |
| 11 | Verify RestoreGuard fail-safe (exception path) | Simulate DB read error | Guard catches exception; `resolver.next()` still called (fail-open); navigation proceeds normally without hanging | Session fix: route guards never lock out / hang navigation | |
| 12 | Verify RestoreGuard skips for local-only users | Sign in without Firebase (local account) | `_hasCloudAccount()` returns false; guard skips restore entirely; `_isNewDevice = false`; navigation proceeds | Session fix: route guards never lock out | |
| 13 | Verify RestoreGuard caches result | Navigate away and return to a guarded route | Second navigation after `_isNewDevice = false`: guard immediately calls `resolver.next()` without re-querying DB | | |
| 14 | Verify provider refresh post-restore | After successful restore | `profileListProvider`, `profileListStreamProvider`, `selectedProfileProvider` are all invalidated; dashboard rebuilds from fresh DB data | | |
| 15 | Verify no AppBar | Screen during restore | `Scaffold` has no `AppBar` — the entire body is a centered column; no navigation affordances during active restore (intentional: user should wait) | | |
| 16 | Press Android back button during restore | OS back (while restoring) | Behavior **unclear from source** — no explicit WillPopScope/PopScope; executor should probe: does back abort restore? Should not crash | Session fix: route guards never lock out / hang | |

### 11.2 States to Verify

| State | How to Reach | What to Verify |
|-------|-------------|----------------|
| Idle | Instant on load | SizedBox.shrink briefly |
| Checking | Service starts | Spinner + checking text |
| Restoring (indeterminate) | `totalSteps = 0` | Null LinearProgressIndicator |
| Restoring (determinate) | `totalSteps > 0` | Fraction fill on linear bar |
| Complete | Restore succeeds | Gold check + complete text; auto-navigate |
| Error | Restore fails | Red icon + message + Retry + Skip |
| Offline / no connectivity | Airplane mode when restore triggers | Error state fires with network message; Retry and Skip both available |

---

## Cross-Cutting Product-Rule and Regression Checks

| Check | Screens | What to Assert |
|-------|---------|---------------|
| No track-type label ("Personal"/"Standard"/"Custom"/אישי) anywhere | All intro pages, add-another-prompt screen, handoff screen | Search for these strings; must be absent |
| Chazara UI only when chazaraEnabled | WizardCustomStep3, WizardSelectPresetStep review card | For a track created with `noReview`, no chazara rows or stage labels appear in the schedule summary |
| Adults have no gamification | AppIntroScreen page 3 (IntroChildModeTag), EmptyLoginScreen | "For Child profiles only" tag clearly present; no points/streaks on adult surfaces |
| Hebrew terms independent of locale | Profile creation prefs card (Hebrew Terms toggle), WizardCustomStep3 (chazaraStage label), IntroScholarLevelCard | Toggle Hebrew terms ON in English locale: all domain terms switch; UI locale remains English |
| Persistent profile/role switcher | All post-onboarding screens (AppShell) | Once onboarding completes and AppShell is reached, the top switcher is present — verify onboarding transition lands in a properly initialised shell |
| Route guards never lock out / hang | AppIntroScreen → SignInRoute, OnboardingScreen auth check, PermissionPromptScreen pop, DeviceRestoreScreen skip | Each navigation completes; no `resolver` left un-resolved; no infinite spinner |
| Account merge "discard local" no crash | DeviceRestoreScreen — reached when existing cloud data merges with empty local DB | Complete the restore flow; verify no crash at the merge-completion point |
| Magic-link / deep-link no crash on malformed link | App launch with `adb shell am start -a android.intent.action.VIEW -d "learning-tracker://malformed"` | App does not crash; gracefully falls back to sign-in or current screen |
| Onboarding resume after kill | Kill app mid-onboarding (any phase); relaunch | `_tryResumeFromSavedState` correctly restores the saved phase; no duplicate profile created; no navigation hang |
| Skip-for-now banner dismissal | EmptyLoginScreen "Dismiss" tap | `onboarding_skipped` and `onboarding_joined_to_tutor` prefs removed; banner gone on next frame; no false "saved" toast |
| Scope-selection Save disabled for empty subset | (AddTrackFlow, out of scope here — noted for adjacency) | N/A for this cluster |




# Cluster: Account / Auth

## Scope

Screens and widgets covered:

- `SignInScreen` — route `/sign-in`
- `AccountPickerScreen` — route `/account-picker`
- `SignupScreen` — route `/signup`
- `UpgradeToCloudScreen` — route `/upgrade-to-cloud` (Settings → Account)
- `EmailVerificationConfirmPanel` — appears as dialog (sign-in flow) and as inline block (upgrade flow)
- `SignInModeCard` — informational widget embedded in SignInScreen (non-interactive but must be verified in each connectivity state)

---

## 1. SignInScreen (`/sign-in`)

### How to reach

- **Cold launch, no account on device:** app routes to `/sign-in` automatically after onboarding skip or fresh install.
- **From AccountPickerScreen:** tap a cloud tile whose Firebase session is expired — app pushes `SignInRoute`.
- **From SignupScreen:** tap the "Log In" rich-text link.
- **Precondition variants:** (a) device online; (b) device offline (toggle airplane mode before launch).

### Interactive elements

| # | Action | Element | Expected result | Product rule / Fix to confirm | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------------------|-----------------|
| 1 | Observe screen load | `SignInModeCard` at top of card | Shows **cloud mode** card (blue border, `Icons.cloud_done_rounded`) when online; shows **local-warning** (coral double card) when offline | Connectivity routing is live — no hardcoded state | |
| 2 | Tap email field | `TextFormField` (email) | Field focused; keyboard with `emailAddress` input type opens; hint text "you@quest.com" visible | — | |
| 3 | Type short string (<5 chars) | Email `TextFormField` | No registry hint appears below field (debounce requires ≥5 chars / 300 ms) | Epic 21.7 registry lookup | |
| 4 | Type known LOCAL-born email (≥5 chars, wait 300 ms) | Email `TextFormField` | Registry hint "Found on device (local)" appears below field; `SignInModeCard` switches to **local** variant (coral) | Registry match `localBorn` → `SignInModeHint.local` | |
| 5 | Type known CLOUD-born email (online, ≥5 chars, wait 300 ms) | Email `TextFormField` | Hint "Found on device (cloud)" appears; `SignInModeCard` stays **cloud** (blue) | Registry match `cloudBorn` + online → `SignInModeHint.cloud` | |
| 6 | Type known CLOUD-born email (offline, ≥5 chars, wait 300 ms) | Email `TextFormField` | `SignInModeCard` switches to **cloudOffline** variant (coral, `Icons.cloud_off_rounded`) | `cloudBorn` + offline → `SignInModeHint.cloudOffline` | |
| 7 | Type email NOT on device (online) | Email `TextFormField` | Subtitle below field: "Not on device — will check cloud"; `SignInModeCard` shows **cloud** | `notOnDevice` + online → cloud mode | |
| 8 | Type email NOT on device (offline) | Email `TextFormField` | Subtitle below field: offline-variant text; `SignInModeCard` shows **local** warning | `notOnDevice` + offline → local mode | |
| 9 | Clear email field | Email `TextFormField` | Registry hint disappears; mode card reverts to default (cloud if online, local if offline) | `RegistryMatchKind.none` resets to defaults | |
| 10 | Submit with empty email | "Sign In" `FilledButton` (or keyboard Done) | Inline form validation error "Email is required" appears on email field; no network request | `validateEmail` — empty case | |
| 11 | Submit with invalid email (e.g. "abc") | "Sign In" button | Inline error "Please enter a valid email address" on email field | `validateEmail` — regex case | |
| 12 | Submit with empty password | "Sign In" button | Inline error message on password field (l10n `authPasswordRequired`) | `validatePassword` — empty case | |
| 13 | Submit with valid email + wrong password (local account) | "Sign In" button | Spinner appears; snackbar "Incorrect password" (coral, 5 s) after reject; state returns to idle | `InvalidCredentialsException` path | |
| 14 | Submit with valid cloud credentials (online) | "Sign In" button | Spinner appears; if email unverified, `EmailVerificationConfirmPanel` dialog opens; if verified, navigates to app shell / profile picker / onboarding | Email verification gate; navigation routing | |
| 15 | Submit valid cloud credentials (offline, account on device) | "Sign In" button | Offline cloud restore activates; navigates to app shell without Firebase call | Fix: sign-in connectivity routing; offline restore path | |
| 16 | Submit cloud credentials (offline, NOT on device) | "Sign In" button | Snackbar error "Can't sign in to a cloud account while offline" (l10n `authEmailOfflineUnreachable`) | Offline-first rule; no hang | |
| 17 | Sign-in times out (>15 s) | Any active spinner | Snackbar shows timeout message; button re-enables | 15 s watchdog timer | |
| 18 | Tap password toggle icon (`Icons.visibility_off_rounded` / `Icons.visibility_rounded`) | Suffix `IconButton` on password field | Password text toggles between obscured (dots) and visible; icon changes accordingly | `_obscurePassword` toggle | |
| 19 | Tap "Keep me signed in" checkbox | `Checkbox` widget | Checkbox toggles checked/unchecked; disabled (greyed) while `isLoading = true` | `keepSignedIn` state | |
| 20 | Press keyboard Done on password field | IME action `TextInputAction.done` | Triggers `_handleSignInWithEmail` same as tapping "Sign In" button | `onFieldSubmitted` wired to `onSubmit` | |
| 21 | Tap "Sign In" button (loading state) | `FilledButton` during `SignInSubmitting` | Button shows `CircularProgressIndicator` (20×20, white); button is disabled (`onPressed: null`) | Loading guard | |
| 22 | Tap "Sign In with Google" button (online) | `OutlinedButton.icon` with Google icon | Google sign-in intent launches; on success navigates to onboarding or app shell; on cancel returns to idle | `signInWithGoogle` — cancel = `SignInIdle`; max-device-accounts guard | |
| 23 | Attempt Google sign-in when device at max accounts (5) | "Sign In with Google" button | Snackbar "Maximum 5 accounts reached. Remove one to add another." | `kMaxDeviceAccounts` guard | |
| 24 | Attempt Google sign-in with email matching a local account | "Sign In with Google" button | Snackbar "An offline account with this email exists… use Upgrade to Cloud" | Local-collision guard | |
| 25 | Verify "Sign In with Google" button absent when offline | Observe `SignInActions` | Google button NOT rendered (hidden by `if (isOnline)` guard) | Offline-only: Google SSO requires connectivity | |
| 26 | Tap "Register here" rich-text link | `TapGestureRecognizer` in `RichText` | Navigates to `SignupRoute` via `context.router.replace`; link disabled while loading | `onRegister` callback | |
| 27 | Tap system Back button | Android back gesture | Returns to previous route (if any) or exits app; must NOT loop or hang | Route-guard fail-safe fix | |

### States to verify

| State | How to reach | What to assert |
|-------|-------------|---------------|
| Online / default | Normal network | Blue cloud `SignInModeCard`; Google button visible |
| Offline | Airplane mode before opening | Coral local-warning `SignInModeCard`; Google button hidden |
| Loading | Tap Sign In with valid creds | Spinner in button; all inputs and toggles disabled |
| Error / snackbar | Wrong password | Coral snackbar for 5 s; button re-enabled after dismiss |
| Cloud-born offline | Offline + cloud email typed | `cloudOffline` card shown |
| RTL / Hebrew | System language = Hebrew | Card and labels flip correctly; no truncation |
| Dark mode | System dark theme | Card backgrounds readable; no invisible-on-dark text |

---

## 2. AccountPickerScreen (`/account-picker`)

### How to reach

- **Precondition:** ≥1 account registered in device registry.
- After signing out when other accounts remain, the router pushes `AccountPickerRoute`.
- Direct route push from account-switcher flow (e.g. Settings → switch account).
- If device has ZERO accounts, screen auto-redirects to `SignInRoute` (test this edge case).

### Interactive elements

| # | Action | Element | Expected result | Product rule / Fix to confirm | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------------------|-----------------|
| 28 | Observe tile — cloud account, session valid | `_AccountTile` (cloud + valid Firebase session) | Blue avatar (`Icons.cloud_rounded`), blue "Cloud Account" pill, `Icons.chevron_right_rounded` trailing icon | Session status display | |
| 29 | Observe tile — cloud account, session expired | `_AccountTile` (cloud, `fbUser.uid ≠ account.firebaseUid`) | Pink/red avatar, red "Sign In Again" pill, `Icons.warning_rounded` trailing icon | Expired-session visual cue | |
| 30 | Observe tile — local account | `_AccountTile` (local-born) | Orange avatar (`Icons.smartphone_rounded`), grey "Local Account" pill, `Icons.lock_outline_rounded` trailing icon | Local-born badge display | |
| 31 | Tap cloud tile (valid session, online) | `InkWell` on `_AccountTile` | Instantly swaps DB + activates session; navigates to `AppShellRoute` without sign-out dialog | Rule: account switching needs NO sign-out (DEC-34) | |
| 32 | Tap cloud tile (expired session, online) | `InkWell` on `_AccountTile` | Pushes `SignInRoute` to re-authenticate | Expired session → sign-in redirect | |
| 33 | Tap cloud tile (expired session, offline) | `InkWell` on `_AccountTile` | Offline-first: activates local data without Firebase; navigates to `AppShellRoute` | Offline cloud restore path | |
| 34 | Tap local tile | `InkWell` on `_AccountTile` | Instantly activates local session; navigates to `AppShellRoute`; no password prompt | Local-born instant activation (DEC-34); stale selected-profile-id cleared (R1o-C2) | |
| 35 | Swipe left (endToStart) on cloud tile | `Dismissible` | Red "Remove from device" background label revealed | Cloud dismissal label | |
| 36 | Swipe left (endToStart) on local tile | `Dismissible` | Red "Delete account" background label revealed | Local dismissal label | |
| 37 | Complete swipe dismiss — cloud tile | `Dismissible` → `_confirmDismiss` | `AlertDialog` opens: title "Remove from device", body explains cloud data stays safe; two buttons: "Cancel" and "Remove" | Confirm-before-dismiss guard | |
| 38 | In dismiss dialog (cloud) — tap "Cancel" | `TextButton` ("Cancel") | Dialog closes; tile re-appears in list unchanged | Cancel = no action | |
| 39 | In dismiss dialog (cloud) — tap "Remove" | `FilledButton` (error color, "Remove") | Dialog closes; `AccountLifecycleService.removeCloudFromDevice` called; tile removed from list | Cloud remove path | |
| 40 | Complete swipe dismiss — local tile | `Dismissible` → `_confirmDismiss` | `AlertDialog`: title "Delete account", body warns data is permanent; buttons "Cancel" and "Delete forever" | Delete-forever guard | |
| 41 | In dismiss dialog (local) — tap "Cancel" | `TextButton` | Dialog closes; tile stays | Cancel path | |
| 42 | In dismiss dialog (local) — tap "Delete forever" | `FilledButton` (error color) | `AccountLifecycleService.deleteLocalAccount` called; tile removed; if list now empty, screen redirects to `SignInRoute` | Fix: "discard local" no-crash; route-guard fail-safe | |
| 43 | Tap "Add another account" dashed button (when < 5 accounts) | `_DashedOutlineButton` | Navigates to `SignupRoute` | Account count < `kMaxDeviceAccounts` gate | |
| 44 | Observe bottom section when at max accounts (5) | `_BottomAddAccountSection` | Dashed add-button is REPLACED by "Max X accounts reached" text; no tappable button | Max-accounts limit visible | |
| 45 | Observe privacy footer text | Static `Text` | Visible, not truncated, correct string | Informational | |
| 46 | Tap system Back | Android back gesture | Pops picker; must not hang or loop | Route-guard fail-safe | |
| 47 | Loading state (FutureBuilder not resolved) | Initial build | `CircularProgressIndicator` centered on screen | Loading guard | |
| 48 | Zero accounts edge case | Delete all accounts (from test state) | Screen auto-redirects to `SignInRoute` without crashing | Fail-safe: `accounts.isEmpty` → `replaceAll([SignInRoute])` | |

### States to verify

| State | How to reach | What to assert |
|-------|-------------|---------------|
| 1 account | Fresh install, 1 local account | Single tile + "Add another" button |
| 5 accounts | Create max accounts | Add-button replaced by max-count text |
| Mix of cloud + local | Register both types | Correct icons, pills, colours for each type |
| All expired sessions | Sign out of all cloud accounts | All cloud tiles show red warning icon |
| RTL | Hebrew locale | Swipe direction, tile layout mirror correctly |
| Dark mode | System dark theme | Tiles readable; error colours not washed out |

---

## 3. SignupScreen (`/signup`)

### How to reach

- From `SignInScreen`: tap "Register here" link.
- From `AccountPickerScreen`: tap "Add another account" dashed button.
- From onboarding intent screen (if present).
- Precondition for offline path: airplane mode ON before tapping any button.

### Interactive elements

| # | Action | Element | Expected result | Product rule / Fix to confirm | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------------------|-----------------|
| 49 | Observe account-mode card (online) | `_buildAccountModeCard` (online) | Blue cloud card: "Cloud account: your data is backed up…" | Cloud-born path announcement | |
| 50 | Observe account-mode card (offline) | `_buildAccountModeCard` (offline) | Two coral cards: "Local account only: no cloud backup…" + "No cloud backup… stays only on this device" | Offline-born warning cards | |
| 51 | Observe offline-acknowledge checkbox (offline only) | `Checkbox` in coral container | Visible ONLY when `!isOnline`; unchecked by default; disabled during loading | Offline-acknowledgement guard | |
| 52 | Tap offline-acknowledge checkbox | `Checkbox` | Toggles `_offlineAcknowledged`; enabled state only when not loading | Must be checked before offline signup proceeds | |
| 53 | Tap "Sign Up" / "Create Offline Account" button without checking offline-acknowledge (offline) | `FilledButton` | Snackbar error "Please acknowledge the offline account warning…" | Offline-acknowledgement guard | |
| 54 | Tap "Sign Up" with all fields empty | `FilledButton` | Form validates; errors on Display Name, Email, Password fields | `validateDisplayName`, `validateEmail`, `validatePassword` | |
| 55 | Tap "Sign Up" with empty Display Name only | `FilledButton` | Error "Display name is required" on name field | `validateDisplayName` — empty | |
| 56 | Tap "Sign Up" with invalid email | `FilledButton` | Error "Please enter a valid email address" on email field | `validateEmail` — regex | |
| 57 | Tap "Sign Up" with short password (< 6 chars) | `FilledButton` | Error "Password must be at least 6 characters" | `validatePassword` — length | |
| 58 | Type spaces in password field | Password `TextFormField` | Spaces rejected (`NoSpaceFormatter`); no space character inserted | `NoSpaceFormatter` in effect | |
| 59 | Tap "Sign Up" with duplicate cloud email (online) | `FilledButton` | Snackbar "An account already exists with this email." (`DuplicateEmailException`) | Duplicate-email guard | |
| 60 | Tap "Sign Up" with duplicate local email (offline) | `FilledButton` | Snackbar "An account with this email already exists on this device. Sign in instead." | Device registry duplicate guard | |
| 61 | Successful cloud signup (online, valid unique email) | `FilledButton` ("Sign Up") | Loading spinner in button; Firebase account created; verification email sent; snackbar "Verification email sent. Verify your email, then sign in."; navigates to `SignInRoute` | Cloud signup flow | |
| 62 | Successful local signup (offline, acknowledged, valid fields) | `FilledButton` ("Create Offline Account") | Local-born account created; onboarding starts (`OnboardingRoute` pushed) | Local-born path; PendingLocalSignupStore rollback on incomplete | |
| 63 | Firebase call fails mid-flight (network drops during cloud signup) | Simulate network loss after submit | Fallback dialog opens: title (l10n `connectionLostTitle`), body "…Would you like to create an offline account instead?", two buttons: "Try Again" and "Create Offline Account" | Fix: magic-link / deep-link crash → `_showFallbackDialog` safety | |
| 64 | In fallback dialog — tap "Try Again" | `TextButton` | Dialog closes; `_signUpCloud` called again with same credentials | Retry path | |
| 65 | In fallback dialog — tap "Create Offline Account" | `FilledButton` | Dialog closes; `_offlineAcknowledged` set to true; `_signUpLocal` called | Offline fallback from failed cloud | |
| 66 | Tap "Sign Up with Google" button (online) | `OutlinedButton` with Google icon | Google sign-in intent; on success creates/links account and navigates to onboarding or app shell | Google signup flow | |
| 67 | Attempt Google signup when at max accounts (5) | "Sign Up with Google" | Snackbar "Maximum 5 accounts reached. Remove one to add another." | Max-device-accounts guard | |
| 68 | Attempt Google signup with email matching local account | "Sign Up with Google" | Snackbar "An offline account with this email exists… use Upgrade to Cloud option" | Local-collision guard | |
| 69 | Verify "Sign Up with Google" absent when offline | Observe layout | Google button and OR divider NOT rendered | `if (isOnline)` guard | |
| 70 | Toggle password visibility icon | Suffix `IconButton` | `_obscurePassword` toggles; icon switches between lock and visibility icons | Password reveal toggle | |
| 71 | Press keyboard Done on password field | IME `TextInputAction.done` | Submits via `_signUpWithEmail()` same as tapping button | `onFieldSubmitted` | |
| 72 | Tap "Log In" rich-text link | `TapGestureRecognizer` in `RichText` | Navigates to `SignInRoute` via `context.router.replace`; disabled while loading | Navigation to sign-in | |
| 73 | Observe button label changes with connectivity | `FilledButton` label | Online: "Sign Up"; Offline: "Create Offline Account" | Dynamic label | |
| 74 | Tap system Back | Android back | Pops to previous screen; no hang or crash | Route-guard fail-safe | |
| 75 | Loading state | After tapping Sign Up | All fields disabled (`enabled: !_isLoading`); spinner in button; Google button disabled | Loading guard | |

### States to verify

| State | How to reach | What to assert |
|-------|-------------|---------------|
| Online | Default | Blue cloud card; "Sign Up" button label; Google button present |
| Offline | Airplane mode | Coral double card; acknowledge checkbox; "Create Offline Account" label; Google hidden |
| Loading | Tap submit | Fields disabled; spinner in button |
| Validation errors | Submit empty/invalid | Per-field inline errors appear |
| Fallback dialog | Simulate mid-flight network drop | Dialog has both action buttons; retry re-fires cloud path |
| RTL | Hebrew locale | Layout mirrors; no wrapping issues |
| Dark mode | System dark | Coral warning cards readable |

---

## 4. UpgradeToCloudScreen (`/upgrade-to-cloud`)

### How to reach

- Settings → Account section → "Upgrade to Cloud" action (available only to local-born signed-in account).
- Precondition: signed in as a local-born account; device online (offline shows error inline).

### Interactive elements — Phase: Form (_PhaseForm)

| # | Action | Element | Expected result | Product rule / Fix to confirm | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------------------|-----------------|
| 76 | Observe AppBar | `AppBar` title | Shows l10n `upgradeToCloudTitle`; back arrow present | Settings: no duplicated action | |
| 77 | Tap back arrow (AppBar) | `AppBar` leading back button | Pops to Settings; no data loss | Navigation | |
| 78 | Observe description text | Static body text | Shows current user email; explains one-way upgrade; no references to account-type labels ("Personal"/"Standard") | Rule: no track-type label anywhere | |
| 79 | Submit with empty password | `FilledButton` ("Upgrade to Cloud") | Inline validator error "Password required" on password field | `validator` in `TextFormField` | |
| 80 | Submit with incorrect password | `FilledButton` | `UpgradePasswordMismatchException` → inline error "Incorrect password." below field | Password mismatch path | |
| 81 | Submit (offline) | `FilledButton` | `_requireInternet()` fails → error "Internet connection is required to upgrade to cloud. Your account and data stay local until you retry online." | Offline guard | |
| 82 | Submit valid password (online, no collision, unverified email) | `FilledButton` | Transitions to `_PhaseVerifying`; `EmailVerificationConfirmPanel` inline block appears | Verification required phase | |
| 83 | Submit valid password (online, no collision, email already verified) | `FilledButton` | Upgrade completes; transitions to `_PhaseSuccess` | Happy path | |
| 84 | Submit valid password (email collision) | `FilledButton` | Transitions to `_PhaseCollision`; collision block appears | `EmailCollisionException` path | |
| 85 | Loading state during submit | `FilledButton` | Spinner 20×20 in button; field disabled (`enabled: !isLoading`) | Loading guard | |
| 86 | Tap system Back | Android back | Pops; no navigation hang | Route-guard | |

### Interactive elements — Phase: Verifying (_PhaseVerifying) — uses EmailVerificationConfirmPanel

| # | Action | Element | Expected result | Product rule / Fix to confirm | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------------------|-----------------|
| 87 | Tap "Open Email" button | `FilledButton` ("Open Email") | Default mail app opens (or chooser); panel stays open | `openEmailApp` with `email` parameter | |
| 88 | Tap "Send Again" button | `FilledButton` ("Send Again") peach pill | `_resendVerification()` called; spinner shows in button while sending; snackbar "Verification email sent" on success | `onSendAgain` callback; re-send guard | |
| 89 | Tap "Cancel" button | `OutlinedButton` ("Cancel") | Transitions back to `_PhaseForm` (clears verification state) | `onCancel: () => setState(() => _phase = _PhaseForm())` | |
| 90 | Tap "I've verified — complete upgrade" link | `TextButton` | Spinner in button while checking; if verified, upgrade completes and transitions to `_PhaseSuccess`; if not verified, stays in verifying phase | `onVerified` → `_submit()` called again | |
| 91 | Tap any action while another is in progress (`actionsLocked = true`) | All three buttons | All disabled (`onPressed: null`) | `busy` flag prevents double-fire; Fix: single-tap guard | |
| 92 | Tap barrier (dialog dismiss) — N/A for inline panel | Swipe away or back | "Cancel" button is only dismissal path for inline panel; back button returns to form | Panel is not a dismissible dialog here | |

### Interactive elements — Phase: Collision (_PhaseCollision)

| # | Action | Element | Expected result | Product rule / Fix to confirm | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------------------|-----------------|
| 93 | Tap "Upload local into cloud" option tile | `_OptionTile` | Tile gains selected highlight (radio filled); cloud password field and Confirm button appear | Upload choice selection | |
| 94 | Tap "Keep cloud, discard local" option tile | `_OptionTile` | Discard tile selected; "discard acknowledged" checkbox also appears below cloud password field | Discard choice selection | |
| 95 | Enter cloud password (collision, either option) | `TextField` ("Cloud account password") | Text entered; no spaces allowed (`NoSpaceFormatter`) | Password field enabled only when choice ≠ none | |
| 96 | For discard option: tap acknowledge checkbox | `Checkbox` | Toggles `discardAcknowledged` | Must be checked before discard can proceed | |
| 97 | Tap "Upload and sign in" or "Discard local and sign in" without entering password | `FilledButton` | Inline error "Please enter your cloud account password." | Password-required guard | |
| 98 | Tap "Discard local and sign in" without checking acknowledge | `FilledButton` | Inline error "Please acknowledge that local data will be replaced…" | Acknowledge guard; Fix: "discard local" path no longer crashes | |
| 99 | Tap "Upload and sign in" with correct cloud password | `FilledButton` | Spinner; `executeUploadLocalIntoCloud` runs; on success → `_PhaseSuccess` | Upload-merge path | |
| 100 | Tap "Discard local and sign in" with correct password + acknowledged | `FilledButton` | Spinner; `executeKeepCloudDiscardLocal` runs; on success → `_PhaseSuccess` | Discard-local path; Fix: no crash | |
| 101 | Tap "Discard" with wrong cloud password | `FilledButton` | Inline error "Incorrect cloud account password." | `wrong-password` Firebase code mapped | |
| 102 | Tap Cancel (keep offline) link | `TextButton` (l10n `upgradeToCloudCancelKeepOffline`) | Cloud password field cleared; phase resets to `_PhaseCollision(choice: none)` | Cancel-collision path | |
| 103 | Tap any action while loading | Any button | All disabled (`isLoading = true`) | Single-tap / double-fire guard | |

### Phase: Success (_PhaseSuccess)

| # | Action | Element | Expected result | Product rule / Fix to confirm | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------------------|-----------------|
| 104 | Observe success block | `_SuccessBlock` | Green/primary container card with cloud-done icon and "You're backed up!" title; body "Your data will now sync across devices automatically." | Upgrade success state | |
| 105 | Tap back from success | AppBar back / system back | Returns to Settings | Navigation | |

### States to verify

| State | How to reach | What to assert |
|-------|-------------|---------------|
| Form / default | Navigate to screen | Password field + Upgrade button; current email in description |
| Offline | Airplane mode, tap Upgrade | Inline error shown; form still visible |
| Verifying | Valid password, unverified Firebase | Verification panel shown; all 4 buttons active |
| Collision | Duplicate email in Firebase | Collision block; both option tiles; no auto-merge |
| Success | Full happy path | Success card; no further interactive elements |
| Loading (form) | Tap Upgrade with valid password | Spinner in button; field disabled |
| Loading (verifying) | Tap "Send Again" or "I've verified" | Spinner in respective button; others disabled |
| Loading (collision) | Tap execute | Spinner in execute button; all controls disabled |

---

## 5. EmailVerificationConfirmPanel (dialog — sign-in flow)

### How to reach

- During `SignInScreen` email+password sign-in: if Firebase account's email is unverified, `showEmailVerificationDialog` is called automatically.
- Precondition: create a cloud account via SignupScreen, do NOT verify email, then try to sign in.

### Interactive elements

| # | Action | Element | Expected result | Product rule / Fix to confirm | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------------------|-----------------|
| 106 | Observe panel | `_MailIllustration` + title | Dashed envelope frame, mail icon with blue star badge; title "Confirm Your Email" (l10n `authVerifyEmailTitle`) | Panel renders correctly | |
| 107 | Observe body text | `Text` (bodyText) | l10n `authVerifyEmailBody` showing user's email address | Email address in body | |
| 108 | Tap "Open Email" | `FilledButton` blue | Default email client opens with pre-filled `mailto:<email>`; dialog stays open | `openEmailApp` call | |
| 109 | Tap "Send Again" | `FilledButton` peach | `resendVerificationEmail` called; spinner in button while in progress; button locks all siblings | Fix: `send_verification_email_failed` now logged instead of silently swallowed | |
| 110 | Tap "Cancel" | `OutlinedButton` | `Navigator.of(dialogContext).pop(false)` — dialog closes; sign-in state resets to idle; user stays on sign-in screen | Cancel path returns `false` | |
| 111 | Tap "I've verified" (`verifiedLinkLabel`) | `TextButton` | `_wrapVerified()` runs; spinner in button; if verified, `Navigator.pop(true)` → sign-in completes and navigates to app | Verification check; `_waitForVerified` + pending code check | |
| 112 | Tap barrier (outside dialog) | Tap dimmed backdrop | `barrierDismissible: true` — dialog closes with `null` result → treated as `false`; user stays on sign-in screen | Barrier dismiss returns false | |
| 113 | Tap any button while `actionsLocked` or during async op | All buttons | All `onPressed` guarded by `busy` flag; no double-fire | Single-tap guard; Fix: redemption double-fire pattern | |
| 114 | Malformed deep-link / OOB code handling | Background: receive malformed magic link | `_tryApplyPendingVerificationCode` catches `expired-action-code` / `invalid-action-code` gracefully; panel stays open; no crash | Fix: magic-link / deep-link handling doesn't crash on malformed links | |

---

## 6. SignInModeCard widget — all variants (within SignInScreen)

This is a display-only widget but each variant must be verified as a distinct visual state.

| # | State | How to trigger | What to assert |
|---|-------|---------------|---------------|
| 115 | `SignInModeHint.cloud` | Online + no email typed | Blue border card; `Icons.cloud_done_rounded`; l10n `authModeCloud` text |
| 116 | `SignInModeHint.cloudOffline` | Offline + cloud-born email typed | Coral border card; `Icons.cloud_off_rounded`; l10n `authModeCloudOffline` text |
| 117 | `SignInModeHint.local` | Offline + no email, OR any state where local applies | Two coral cards; warning icon + `authModeLocalTitle`; danger icon + `authModeLocalBody` |
| 118 | `SignInModeHint.unknown` | (Not triggered in current logic — rendered as `SizedBox.shrink()`) | No visible card; layout unchanged | Executor: probe if any code path yields `unknown` |

---

## Cross-cutting product rules — assert on every screen above

| Rule | Where to check | How to assert |
|------|---------------|---------------|
| No track-type label ("Personal"/"Standard"/"Custom") | All account/auth screens | Search visible text on screen; none of those strings should appear anywhere |
| Tutor `canMarkLiveCompletion = FALSE` | Not directly on auth screens; auth grants access for tutors | N/A here — covered in tutoring cluster |
| Persistent profile/role switcher at top of every context | Auth screens are pre-auth — switcher NOT expected | Confirm no switcher renders before sign-in completes |
| Account switching needs NO sign-out | AccountPickerScreen step 31 and 34 | Tap local tile or valid-session cloud tile — direct navigation, zero sign-out dialogs |
| Route guards never lock out / hang | All screens — test back button + malformed state | No infinite redirect; back always resolves |
| Account-merge "discard local" no longer crashes | UpgradeToCloudScreen step 100 | Complete discard path; observe no exception |
| Sign-in connectivity routing | SignInScreen step 15, 16 | Online = Firebase; offline + on-device = local restore; offline + not-on-device = error |
| Magic-link / deep-link no crash on malformed | EmailVerificationConfirmPanel step 114 | Force bad OOB code in SharedPreferences; verify no crash |

---

## Regression confirmation checklist (session fixes)

| Fix | Screen | Step # | Pass/Fail |
|-----|--------|--------|-----------|
| Route guards never lock out / hang (Auth/Restore/Pin/ChildMode/Profile) | All | 27, 46, 74, 76, 86 | |
| Account-merge "discard local" path no longer crashes | UpgradeToCloudScreen | 99, 100 | |
| Sign-in connectivity routing | SignInScreen | 14, 15, 16 | |
| Magic-link / deep-link no crash on malformed | EmailVerificationConfirmPanel | 114 | |
| Redemption Fulfil/Decline single-tap guard (pattern tested here) | EmailVerificationConfirmPanel, UpgradeToCloudScreen | 91, 103, 113 | |



# Cluster: Profiles + PIN — Exhaustive On-Device Test Plan

---

## Preconditions & Shared Setup Notes

- **App under test:** `com.jcom.torah.learning_tracker` (Flutter, Android)
- **Profile types:** CHILD and ADULT only — no "parent" type exists in the domain model (`mode` field is `'child'` or `'adult'`).
- **PIN scope:** The "parent PIN" is stored per-profile (hashed, device-local). A CHILD profile always requires a PIN to be set at creation. An ADULT profile has no PIN.
- **Tutor mode:** A signed-in user who has accepted a tutor grant enters the tutored session via `TutoredChildrenSection`. The tutor sees parent-management surfaces for the child but `canMarkLiveCompletion = FALSE`.
- **Route guard chain:** Auth guard → Profile guard → Child-mode guard → PIN guard. Any break must fail safe (never hang navigation).
- **Session fix regression tag [SF-x]** refers to the Session Fixes listed in the preamble.

---

## 1. ProfilePickerScreen

**Route/widget:** `ProfilePickerScreen` — `@RoutePage()`, no route arguments.
**How to reach:** App launch after account is authenticated AND no profile is currently selected (first run, after sign-out, or after explicit profile deselect). Also reachable by switching accounts via `ProfileSwitcherSheet → Switch Account → AccountPickerRoute` and then selecting the new account.

**Preconditions to set up various states:**

| State | How to reach |
|---|---|
| Loading | Slow device or large DB; watch spinner briefly on cold start |
| Empty (0 profiles) | Fresh account with no profiles created |
| 1 profile (own child) | Account with exactly one child profile |
| 1 profile (own adult) | Account with exactly one adult profile |
| Multiple profiles | Account with ≥2 profiles of mixed mode |
| Tutor-segmented | Account with ≥1 active tutor grant → section headers appear |
| Pending tutor invite | Account has pending (not yet accepted) tutor invitation addressed to its email |
| Error | Force network/DB error; verify retry path |
| Offline | Disable Wi-Fi/mobile data before launch |
| LocalBorn (no cloud) | Account created locally, never signed in; `NoBackupBadge` visible |
| Dark mode | Android system dark mode enabled |
| Hebrew/RTL | Android system language set to Hebrew |

### 1.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|---|---|---|---|---|
| 1 | Observe screen on load with 0 profiles | Full screen | Gradient background, title text, subtitle text, `NoBackupBadge` if local-born, NO profile cards, empty `ProfileGrid` shows only `AddProfileCard`, `_buildSignOutSection` section visible (Logout button) if signed in | — | |
| 2 | Observe screen with ≥1 own profiles | ProfileGrid | Each own profile renders as a `ProfileCard` with a child/adult badge, first-letter avatar circle, profile name, and "Tap to continue" sub-label | No track-type label ("Personal"/"Standard"/"Custom") anywhere on this screen | |
| 3 | Observe `NoBackupBadge` (local-born) | Center-top badge | Badge is visible; tapping it opens account backup/sign-in flow | — | |
| 4 | Observe `NoBackupBadge` (cloud-born) | Center-top badge | Badge is NOT visible (hidden by tier gate inside `NoBackupBadge`) | — | |
| 5 | Tap a CHILD profile card | `ProfileCard` (onTap) | `_isSelectingProfile` guard activates (cards non-interactive during transition); navigates to `AppShellRoute` (replaceAll); no crash | [SF-1] Route guards never lock out / hang | |
| 6 | Tap a CHILD profile card twice rapidly | `ProfileCard` (double tap) | Only one navigation fires (`_isSelectingProfile` guard); no duplicate `replaceAll` pushes | [SF-1] | |
| 7 | Tap an ADULT profile card | `ProfileCard` (onTap) | Navigates to `AppShellRoute` for that adult profile; no PIN prompt (adults have no PIN) | Adults have no points/gamification (visible once inside shell, not on picker) | |
| 8 | Long-press a profile card (≥2 profiles) | `ProfileCard` (onLongPress) | Bottom sheet appears with two `ListTile`s: "Rename" (edit icon) and "Delete" (error-red) | — | |
| 9 | Long-press a profile card (only 1 profile) | `ProfileCard` (onLongPress) | Bottom sheet appears; "Delete" tile is disabled and shows `mustKeepOneProfile` subtitle; "Rename" is still enabled | — | |
| 10 | Tap "Rename" in long-press sheet | `ListTile` 'rename' | Bottom sheet closes; Rename `AlertDialog` opens with `TextField` pre-filled with current name, Cancel + Save buttons | — | |
| 11 | Clear name field in Rename dialog | `TextField` in AlertDialog | Save button disabled (`ctrl.text.trim().isNotEmpty` is false) | — | |
| 12 | Type a duplicate name in Rename dialog | `TextField` in AlertDialog | Async duplicate check fires; `errorText` shows `profileNameAlreadyExists`; Save button disabled | — | |
| 13 | Type a valid unique name in Rename dialog | `TextField` in AlertDialog | `errorText` clears; Save button enabled | — | |
| 14 | Tap Cancel in Rename dialog | Cancel `TextButton` | Dialog closes; profile name unchanged; profile list refreshes | — | |
| 15 | Tap Save with valid name in Rename dialog | Save `FilledButton` | Dialog closes; profile name updated; `profileListProvider` invalidated; renamed card visible | — | |
| 16 | Tap Save with name that races to duplicate (conflict on save) | Save `FilledButton` | `DuplicateProfileNameException` caught; snackbar shows `profileNameTaken` message; no crash | — | |
| 17 | Tap "Delete" in long-press sheet (≥2 profiles) | `ListTile` 'delete' | Bottom sheet closes; Delete `AlertDialog` opens with profile name, Cancel + red Delete button | — | |
| 18 | Tap Cancel in Delete dialog | Cancel `TextButton` | Dialog closes; profile unchanged | — | |
| 19 | Tap Delete in Delete dialog (cloud account, online) | Red `FilledButton` | Profile deleted; if it was the active profile, `selectedProfileIdProvider` cleared; `profileListProvider` invalidated; profile card disappears | — | |
| 20 | Tap Delete in Delete dialog (cloud account, offline) | Red `FilledButton` | Connectivity check fails; snackbar shows `errorDeleteProfileRequiresInternet`; profile unchanged | [SF-1] fail-safe | |
| 21 | Tap Delete for the last profile (local-born) | Red `FilledButton` (isLast variant) | Special "Delete your only profile?" dialog with stronger warning text + "Delete anyway" button shown; on confirm, profile deleted; account returns to empty picker | — | |
| 22 | Tap Delete in long-press sheet (only 1 profile) | `ListTile` 'delete' (disabled) | Nothing happens (onTap is null) | — | |
| 23 | Tap "Add Profile" card (< 10 profiles) | `AddProfileCard` (onTap, isDisabled=false) | `showAddProfileDialog` opens; card shows "+" icon with dashed circle, title and subtitle are active | — | |
| 24 | Observe "Add Profile" card at 10 profiles | `AddProfileCard` (isDisabled=true) | Card shows `maxProfilesLabel`/`maxProfilesSubtitle`; "+" icon dimmed; tap does nothing | — | |
| 25 | Observe "YOUR PROFILES" header (≥1 active tutor grant) | Section header text | Header visible above own-profile grid | — | |
| 26 | Observe no section headers (0 tutor grants) | Section header | Header NOT present; single flat grid | — | |
| 27 | Observe pending tutor invite card | `_PendingInviteCard` | Card visible above own-profiles section; school icon, `acceptInviteHeading`, `acceptInviteBody`, "Accept" `FilledButton` | — | |
| 28 | Tap "Accept" on pending tutor invite card | `FilledButton` onAccept | Pushes `AcceptInviteRoute(token: grant.grantId)`; on return, `pendingTutorInvitesProvider` and `incomingTutorGrantsProvider` invalidated; card disappears | — | |
| 29 | Observe `TutoredChildrenSection` (≥1 active tutor grant) | Below own-profile grid | "TALMID PROFILES" header visible; one `_TutoredChildRow` card per active grant | — | |
| 30 | Tap tutored child row | `_TutoredChildRow` (onTap) | `TutorPinEntryGate` modal presented; on correct PIN, tutored session entered and `AppShellRoute` replaces stack | Tutor canMarkLiveCompletion = FALSE (verify after entering tutored shell) | |
| 31 | Tap tutored child row — cancel PIN gate | `TutorPinEntryGate` cancel | Modal dismissed; returns to picker; no crash; no tutored session set | [SF-1] | |
| 32 | Observe `_ViewInvitationsRow` (pending grants) | Inside `TutoredChildrenSection` | Row visible with mail icon + orange badge showing count, subtitle `tutoredChildrenPendingInvitations` | — | |
| 33 | Tap "View invitations" row | `_ViewInvitationsRow` (onTap) | `TutorPinEntryGate` modal presented; on success, `ManageGrantsRoute` pushed | — | |
| 34 | Observe Sign Out button (tutor-only, no own profiles) | `OutlinedButton.icon` | Sign Out button visible below divider; red color | — | |
| 35 | Tap Sign Out button | `OutlinedButton.icon` | `showSignOutConfirmation` invoked; confirmation dialog appears | — | |
| 36 | Observe error state (`profileListProvider` error) | `AppErrorView` | Error message shown with Retry button | — | |
| 37 | Tap Retry on error state | `AppErrorView` Retry | `ref.refresh(profileListProvider)` fires; loading state appears then data (or error again) | [SF-1] | |
| 38 | Press system Back button from picker | Android system Back | Behaviour depends on nav stack; if picker is root, app goes to background (no lockout) | [SF-1] Route guards never lock out / hang navigation | |
| 39 | Observe in Hebrew/RTL | Full screen layout | Title, subtitle, profile names, "Tap to continue" labels are RTL-mirrored; no overflow | — | |
| 40 | Observe in dark mode | Full screen | Gradient, card colors, text colors adapt to dark theme; no invisible-on-dark text | — | |

---

## 2. ManageLearnersScreen

**Route/widget:** `ManageLearnersScreen` — `@RoutePage()`.
**How to reach:** From inside the app shell, navigate to Parent Settings or an admin menu entry that includes "Manage Learners". (In source, this screen is accessed from the `AppBar` title "Manage Learners" directly; reachable via `context.pushRoute(ManageLearnersRoute())`.)

**Preconditions:**

| State | How to reach |
|---|---|
| Loading | Cold open with network latency |
| Empty | Account with 0 profiles |
| 1 profile | Account with exactly 1 profile |
| Multiple profiles | Account with ≥2 profiles |
| Error | DB/network failure |

### 2.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|---|---|---|---|---|
| 41 | Observe AppBar | `AppBar` title | Shows "Manage Learners" text via `AppBarTitle` widget | — | |
| 42 | Tap system Back / AppBar back button | AppBar back arrow | Pops to previous route; no crash | [SF-1] | |
| 43 | Observe loading state | `CircularProgressIndicator` | Spinner centered; no list shown yet | — | |
| 44 | Observe empty state | `noProfilesYet` text | Centered text shown; FAB still visible | — | |
| 45 | Observe list with profiles | `ListView.builder` | Each profile shown as `Card` > `ListTile` with `ProfileAvatar`, display name, child/adult subtitle, and `PopupMenuButton` (three-dot) | — | |
| 46 | Observe profile subtitle label for child | ListTile subtitle | Shows `childMode` string (NOT "Personal"/"Standard"/"Custom") | No track-type label | |
| 47 | Observe profile subtitle label for adult | ListTile subtitle | Shows `adultMode` string (NOT track-type label) | No track-type label | |
| 48 | Tap `PopupMenuButton` on a profile tile | Trailing three-dot icon | Dropdown opens with two items: `profilesEditLabel`, `profilesDeleteLabel` | — | |
| 49 | Tap "Edit" in popup menu | `PopupMenuItem` value 'edit' | `editProfileFlow` invoked; `ProfileEditFormDialog` opens with current name + avatar + mode segmented control | — | |
| 50 | Tap "Delete" in popup menu | `PopupMenuItem` value 'delete' | `deleteProfileFlow` invoked; delete confirmation dialog opens | — | |
| 51 | Tap FAB (+) | `FloatingActionButton` | `showAddProfileDialog` opens | — | |
| 52 | Observe error state | `AppErrorView` | Error message + Retry button; tapping Retry calls `ref.refresh(profileListStreamProvider)` | — | |
| 53 | Observe in Hebrew/RTL | Full screen | ListTile layout mirrors; popup menu appears at correct corner | — | |

---

## 3. ParentSettingsScreen

**Route/widget:** `ParentSettingsScreen` — `@RoutePage()`.
**How to reach:** Must have a CHILD profile active (child-mode guard). From the app shell with a child profile active, tap the parent settings entry (e.g., from the bottom-nav parent icon or the settings hub). PIN guard is applied at route level — PIN entry is required first.

**Preconditions:**

| State | How to reach |
|---|---|
| Owner mode | Signed-in account owns the child profile; no tutor active |
| Tutored mode — full perms | Tutor enters child context; all `tutorPerms` fields true |
| Tutored mode — restricted | Tutor enters child context; some perms false (e.g. `canEditPoints=false`) |
| Tutored mode — all locked | Tutor enters; all gated fields false → entire edit panel hidden |
| User is null (local-born) | No Firebase user; `showDeleteAccountTile` still true because `authState.isLocalBorn` |

### 3.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|---|---|---|---|---|
| 54 | Observe AppBar | AppBar back arrow + title | `parentSettingsTitle` centered; back arrow navigates to previous route | — | |
| 55 | Tap AppBar back | `Icons.arrow_back_rounded` `IconButton` | `context.router.maybePop()` fires; navigates back | [SF-1] | |
| 56 | Observe `UserProfileHeaderCard` | Top of ListView | Shows avatar, profile name, account email; surface = parent; contextRole = parent (or tutor) | Settings: top header = ACCOUNT-only sheet (Settings rule) | |
| 57 | Tap `UserProfileHeaderCard` | Tappable card | Opens profile/account switcher (NOT re-opens settings); distinct from the PROFILE section | Settings rule: profile management ONLY in PROFILE section; no duplicated action | |
| 58 | Observe "Manage Tracks" row (owner) | `_ManageRow` purple route icon | Visible; subtitle is `manageTracksForChildSubtitle`; chevron right | — | |
| 59 | Tap "Manage Tracks" | `_ManageRow` onTap | Pushes `ParentTrackManagementRoute` | — | |
| 60 | Observe "Point Configuration" row (owner) | `_ManageRow` tune icon | Visible; subtitle `pointConfigurationSubtitle` | Adults have no points/gamification (child ONLY gets this) | |
| 61 | Tap "Point Configuration" | `_ManageRow` onTap | Pushes `PointConfigRoute` | — | |
| 62 | Observe "Adjust Points" row (owner) | `_ManageRow` add-circle icon | Visible below Point Configuration; subtitle `parentPointsAdjustSubtitle` | — | |
| 63 | Tap "Adjust Points" row | `_ManageRow` onTap | `_showAdjustPointsDialog` opens; AlertDialog with segmented button (Add/Deduct), amount field, note field, Cancel, Confirm | — | |
| 64 | Toggle "Add/Deduct" segmented button | `SegmentedButton<bool>` | Selection switches; `addMode` state updates | — | |
| 65 | Enter numeric amount in amount field | `TextField` (digits-only) | Only digits accepted (FilteringTextInputFormatter); text appears | — | |
| 66 | Enter text in note field | `TextField` (free text) | Free text accepted | — | |
| 67 | Tap Cancel in Adjust Points dialog | `TextButton` Cancel | Dialog closes; no points change | — | |
| 68 | Tap Confirm in Adjust Points dialog (amount > 0) | `FilledButton` Confirm | Dialog closes; `parentAdjust` called; snackbar `parentPointsAdjustAppliedSnackbar` shown | — | |
| 69 | Tap Confirm with amount = 0 or empty | `FilledButton` Confirm | `int.tryParse` returns 0; guard `if (amount <= 0) return` fires; no action; no crash | — | |
| 70 | Observe "Reward Configuration" row (owner) | `_ManageRow` gift icon | Visible; subtitle `rewardConfigurationSubtitle` | — | |
| 71 | Tap "Reward Configuration" | `_ManageRow` onTap | Pushes `RewardConfigurationRoute` | — | |
| 72 | Observe "Pending Redemptions" row (owner, canEditRewards) | `_ManageRow` redeem icon | Visible | — | |
| 73 | Tap "Pending Redemptions" | `_ManageRow` onTap | Pushes `ParentPendingRedemptionsRoute` | Redemption Fulfil/Decline are single-tap guarded (no double-fire) | |
| 74 | Observe "Add What You Learned" (bulk-mark) row | `_ManageRow` menu-book icon | Visible when `canBulkMark` is true (default = true for owner and for tutor unless disabled) | Bulk/lifetime marking uses sentinel date — not in streak/recent activity | |
| 75 | Tap "Add What You Learned" | `_ManageRow` onTap | Pushes `LifetimeMarkingRoute` | — | |
| 76 | Observe "Manage Tutors" row (owner only) | `_ManageRow` school icon | Visible only when NOT in tutored context | WS3.3d: tutors cannot manage other tutors | |
| 77 | Tap "Manage Tutors" | `_ManageRow` onTap | Pushes `ManageTutorsRoute` | — | |
| 78 | Observe `BackupSyncSection` (owner only) | Backup panel | Visible only in owner mode; NOT in tutored mode | — | |
| 79 | Observe "ACCOUNT SAFETY" section header | Label text | Visible in owner mode | — | |
| 80 | Observe "Sign Out" row | `_ManageRow` logout icon (red) | Visible in owner mode | — | |
| 81 | Tap "Sign Out" | `_ManageRow` onTap | `showSignOutConfirmation(context, ref)` invoked; confirmation dialog appears | Account switching needs NO sign-out (rule confirmed negatively — sign-out is explicit) | |
| 82 | Observe "Delete Account" row (cloud user) | `_ManageRow` delete-forever icon | Visible when `showDeleteAccountTile` is true; subtitle = `deleteAccountSubtitle` | — | |
| 83 | Tap "Delete Account" (cloud) | `_ManageRow` onTap | `showDeleteAccountFlow(context, ref, user)` invoked | — | |
| 84 | Observe "Delete Account" row (local-born) | `_ManageRow` | Subtitle = `deleteLocalAccountSubtitle` | — | |
| 85 | Tap "Delete Account" (local-born) | `_ManageRow` onTap | `showDeleteLocalAccountFlow(context, ref)` invoked | [SF-2] Account-merge "discard local" path no longer crashes | |
| 86 | Observe in tutored mode — canEditTracks=false | `_ManageRow` "Manage Tracks" | Row NOT present | WS3.3d tutored permission gate | |
| 87 | Observe in tutored mode — canEditPoints=false | `_ManageRow` "Point Configuration" + "Adjust Points" | Both rows NOT present | WS3.3d | |
| 88 | Observe in tutored mode — canEditRewards=false | `_ManageRow` "Reward Configuration" + "Pending Redemptions" | Both rows NOT present | WS3.3d | |
| 89 | Observe in tutored mode — all perms false | Edit panel | Panel entirely hidden (no `_WhitePanel` for edit rows shown) | WS3.3d | |
| 90 | Observe in tutored mode — "Manage Tutors" | `_ManageRow` "Manage Tutors" | NOT present (owner-only tile) | WS3.3d | |
| 91 | Observe in tutored mode — BackupSyncSection | `BackupSyncSection` | NOT present (owner-only) | WS3.3d | |
| 92 | Observe in tutored mode — sign-out / delete | Danger tiles | NOT present (owner-only) | WS3.3d | |
| 93 | Observe in dark mode | Full screen | White panels remain white cards; text adapts | — | |
| 94 | Observe in Hebrew/RTL | Full screen | Row layout mirrors (icon left in LTR → icon right in RTL); chevrons flip | — | |

---

## 4. ParentTrackManagementScreen

**Route/widget:** `ParentTrackManagementScreen` — `@RoutePage()`.
**How to reach:** Tap "Manage Tracks" in `ParentSettingsScreen`. Requires a CHILD profile active + PIN authenticated.

**Preconditions:**

| State | How to reach |
|---|---|
| Empty (no tracks) | Child profile with no active tracks |
| With tracks | Child profile with ≥1 active track |
| Add-track inline mode | Tap FAB or "Add Track" button |

### 4.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|---|---|---|---|---|
| 95 | Observe AppBar (tracks exist) | AppBar + back icon | "Manage Tracks" title; back arrow visible | — | |
| 96 | Tap AppBar back | `Icons.arrow_back_ios_new_rounded` `IconButton` | `context.maybePop()` fires; returns to ParentSettingsScreen | [SF-1] | |
| 97 | Observe empty state | `_buildEmptyState` | Large icon, `noActiveTracks` headline, `manageTracksDetail` body, `FilledButton.icon` "Add Track" | — | |
| 98 | Tap "Add Track" (empty state) | `FilledButton.icon` | `_addingTrack = true`; `AddTrackFlow` widget replaces body; no separate route push | — | |
| 99 | Observe track list (≥1 tracks) | `ListView` | "Active Tracks" header + count chip "N RUNNING"; each track rendered as `LearningTrackCard` with progress | No track-type label ("Personal"/"Standard"/"Custom") on card | |
| 100 | Tap a `LearningTrackCard` | Card onTap | Pushes `TrackDetailRoute(track: track)` | — | |
| 101 | Long-press a `LearningTrackCard` | Card onLongPress | `_showDeleteDialog` fires; AlertDialog with Archive + Wipe + Cancel options | — | |
| 102 | Tap Cancel in delete dialog | `TextButton` Cancel | Dialog closes; track unchanged | — | |
| 103 | Tap "Archive" in delete dialog | `TextButton` 'archive' | `dao.deleteTrackAndData(track.id)` called; track removed from list; history preserved | — | |
| 104 | Tap "Wipe" in delete dialog | `FilledButton` (error style) 'wipe' | `dao.purgeHistory(track.id)` called; track AND completions removed; snackbar or silent removal | — | |
| 105 | Observe FAB (≥1 tracks) | `FloatingActionButton.extended` | "Add Track" FAB visible at bottom-right | — | |
| 106 | Observe FAB (0 tracks) | `FloatingActionButton.extended` | FAB is null / not rendered | — | |
| 107 | Tap FAB "Add Track" | `FloatingActionButton.extended` | `_addingTrack = true`; `AddTrackFlow` widget shown inline | — | |
| 108 | Complete `AddTrackFlow` | `AddTrackFlow` onComplete | `_addingTrack = false`; snackbar `trackCreated(result.label)` shown; track appears in list | — | |
| 109 | Cancel `AddTrackFlow` | `AddTrackFlow` onCancel | `_addingTrack = false`; returns to track list | — | |
| 110 | Observe error state | `AppErrorView` | Error message + Retry; tapping Retry calls `ref.refresh(tm.activeTracksProvider)` | — | |
| 111 | Observe in Hebrew/RTL | Full screen | Header, track cards, dialogs mirror RTL | — | |

---

## 5. PinFlowScreen (Setup / Verify / Change modes)

**Route/widget:** `PinFlowScreen` — three route wrappers: `PinFlowSetupRoute`, `PinFlowVerifyRoute`, `PinFlowChangeRoute`.

**How to reach:**
- **Setup mode:** Triggered automatically by `PinGuard` when no PIN is set for the profile scope; or when `showAddProfileDialog` creates a child profile (via `showParentPinSetupDialog`).
- **Verify mode:** Triggered by `PinGuard` whenever a PIN-gated route is navigated to and no session auth exists.
- **Change mode:** Via a Settings entry (Change PIN, not shown in this cluster's source — executor should confirm route exists). Can also be reached via `context.pushRoute(PinFlowChangeRoute())`.

**Preconditions:**

| State | How to reach |
|---|---|
| Setup — first entry step | PIN not yet set for profile |
| Setup — confirm step | Enter first 4 digits; screen transitions |
| Setup — mismatch | Enter 4 digits then different 4 on confirm |
| Verify — correct | PIN is set; enter correct digits |
| Verify — incorrect | Enter wrong digits |
| Verify — lockout | Enter wrong PIN ≥ threshold attempts |
| Change — step 1 (verify current) | Enter correct current PIN |
| Change — step 2 (enter new) | After step 1 success |
| Change — step 3 (confirm new) | After step 2 |
| Change — mismatch new | Enter different PIN on confirm |

### 5.1 Setup Mode Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|---|---|---|---|---|
| 112 | Observe setup screen | `_SetupScaffold` | AppBar with `setParentPinDialogTitle`; device-local PIN info banner (lock icon + `pinFlowSetupDeviceLocalBanner` text); `PinKeypadDialogFrame` below | — | |
| 113 | Observe `PinKeypadDialogFrame` (setup, enter step) | Frame | Title = `setParentPinDialogTitle`; subtitle = `pinFlowSetupSubtitle`; 4 empty dot indicators; digit pad 0–9; NO close button; NO cancel button in keypad | — | |
| 114 | Tap digits 1–4 | `_KeypadChip` buttons 0–9 | Dots fill left to right with each digit | — | |
| 115 | Tap backspace after entering 2 digits | `_KeypadChip` backspace icon | Last dot empties; digit count decreases | — | |
| 116 | Tap backspace when 0 digits | `_KeypadChip` backspace | Nothing happens; no crash | — | |
| 117 | Enter 4th digit (first entry) | `_KeypadChip` | Auto-submits; transitions to confirm step; all dots clear; title changes to `confirmNewPin`; subtitle changes to `confirmNewPinSubtitle` | — | |
| 118 | Observe confirm step | `PinKeypadDialogFrame` | Title = `confirmNewPin`; subtitle = `confirmNewPinSubtitle`; 4 empty dots | — | |
| 119 | Enter same 4 digits on confirm step | Digit keys | Auto-submits; `PinService.setProfilePin` called; state transitions to `completed = true`; screen pops with `true` result | — | |
| 120 | Enter different 4 digits on confirm step | Digit keys | Error message `pinsDoNotMatch` shown in red; resets to enter-new step (all dots clear); can retry | — | |
| 121 | Tap system Back (setup mode) | Android system Back | `PopScope(canPop: false)` prevents back navigation; user cannot bypass setup | Session fix [SF-1] guards never lock out — setup must always complete or be explicitly cancelled | |
| 122 | Observe busy state during save | Spinner/disabled keys | Digit buttons disabled while `busy=true`; no double-submission possible | — | |

### 5.2 Verify Mode Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|---|---|---|---|---|
| 123 | Observe verify screen | Scaffold + keypad | AppBar title = `enterParentPin`; `PinKeypadDialogFrame` with close button (X) and cancel button in keypad | — | |
| 124 | Tap close (X) button in frame | `showCloseButton` close `IconButton` | `_onCancel` fires; `router.maybePop(false)` called; returns to previous screen | [SF-1] | |
| 125 | Tap Cancel in keypad bottom row | `TextButton` Cancel | `_onCancel` fires; same as close button | [SF-1] | |
| 126 | Enter correct PIN | 4 digit buttons | Auto-submits; `verifyProfilePin` returns true; `pinGuard.markAuthenticated(profileId)` called; pops with `true`; guarded route opens | — | |
| 127 | Enter wrong PIN | 4 digit buttons | Error message `incorrectPin` shown; dots clear; can retry | — | |
| 128 | Enter wrong PIN repeatedly to lockout | Multiple wrong attempts | After threshold, `PinLockoutException` caught; `_LockoutPanel` shown with lock icon, "Too many failed attempts", "Try again in N minute(s)" | — | |
| 129 | Observe locked-out state | `_LockoutPanel` | Keypad hidden; no digit buttons; lock icon + messages visible | — | |
| 130 | Tap system Back in verify mode | Android system Back | `PopScope(canPop: false)` blocks; `onClose()` runs; pops with false (never hangs) | [SF-1] Route guards never lock user out / hang | |
| 131 | Observe busy state during verify | Digit buttons | Buttons disabled while async bcrypt verify runs | — | |

### 5.3 Change Mode Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|---|---|---|---|---|
| 132 | Observe change screen — step 1 | Scaffold + frame | AppBar title = `changeParentPin`; frame title = `enterCurrentPin`; subtitle = `enterParentPinSubtitle`; close + cancel present | — | |
| 133 | Enter correct current PIN | 4 digit buttons | Auto-submits; transitions to "Enter new PIN" step; title = `enterNewPin`; subtitle = `enterNewPinSubtitle` | — | |
| 134 | Enter wrong current PIN | 4 digit buttons | Error message `incorrectPin`; can retry | — | |
| 135 | Lockout on change — step 1 | Multiple wrong attempts | `_LockoutPanel` shown | — | |
| 136 | Enter new PIN — step 2 | 4 digit buttons | Auto-submits; transitions to confirm step; title = `confirmNewPin` | — | |
| 137 | Confirm new PIN — same as entered | 4 digit buttons | `PinService.setProfilePin` called; snackbar `pinChangedSuccessfully`; pops with `true` | — | |
| 138 | Confirm new PIN — different | 4 digit buttons | Error `pinsDoNotMatch`; reverts to enter-new step | — | |
| 139 | Tap Cancel/Close in change mode | Close or Cancel | `router.maybePop(false)` fires; change flow aborted; old PIN still active | [SF-1] | |
| 140 | Tap system Back (change mode) | Android system Back | `PopScope` blocks; `onClose()` cancels; never hangs | [SF-1] | |

---

## 6. AddProfileCard Widget

**Used in:** `ProfileGrid` as the last item. Standalone tests within `ProfilePickerScreen` context.

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|---|---|---|---|---|
| See steps 23–24 above | Covered under ProfilePickerScreen | | | | |

---

## 7. AddProfileDialog (showAddProfileDialog)

**Triggered from:** `ProfilePickerScreen` → `AddProfileCard` tap; `ManageLearnersScreen` → FAB tap; `ProfileSwitcherSheet` → "Add Profile" row tap.

### 7.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|---|---|---|---|---|
| 141 | Observe dialog | `ParentModeDialogFrame` | Title = `addProfile`; subtitle = `addProfileDialogSubtitle`; close (X) button; name text field (autofocus); "Choose mode" section with two `AddProfileModePickCard`s (child/adult); "Create Profile" `FilledButton`; Cancel `TextButton` | — | |
| 142 | Observe mode cards initial state | `AddProfileModePickCard` | Adult card selected by default (blue border + check); child card unselected | — | |
| 143 | Tap "Child" mode card | `AddProfileModePickCard` child | Child card becomes selected (blue border + check); adult becomes unselected | — | |
| 144 | Tap "Adult" mode card | `AddProfileModePickCard` adult | Adult card selected; child unselected | — | |
| 145 | Observe Create Profile button with empty name | `FilledButton` (disabled) | Button disabled (`canSubmit = false`) | — | |
| 146 | Type a name in the name field | `TextField` | Button becomes enabled as soon as text is non-empty and no error | — | |
| 147 | Type leading spaces | `TextField` with `TrimLeadingSpaceFormatter` | Leading spaces stripped automatically; no leading whitespace in field | — | |
| 148 | Type a duplicate name | `TextField` | Async check fires; `errorText = profileNameAlreadyExists`; button re-disables | — | |
| 149 | Clear name field after typing | `TextField` | Error clears; button disables again | — | |
| 150 | Tap close (X) | `IconButton` onClose | Dialog dismissed; no profile created | — | |
| 151 | Tap Cancel `TextButton` | Cancel button | Dialog dismissed; no profile created | — | |
| 152 | Tap Create Profile (adult mode) | `FilledButton` (canSubmit=true) | Dialog closes; `repo.createProfile` called with mode='adult'; `profileListProvider` invalidated; NO PIN setup dialog shown (adults have no PIN) | Adults have no points/gamification (adult profiles do not require PIN) | |
| 153 | Tap Create Profile (child mode) | `FilledButton` | Dialog closes; profile created with mode='child'; `showParentPinSetupDialog` immediately shown (blocking, `canPop: false`) | — | |
| 154 | Complete PIN setup after child creation | PIN setup dialog | Profile PIN saved; dialog closes with `true`; profile available in picker | — | |
| 155 | Reach max 10 profiles then attempt add | FAB or AddProfileCard | `MaxProfilesExceededException` caught; snackbar `maxProfilesReached`; `AddProfileCard` shows disabled state | — | |
| 156 | Race condition: duplicate on save | Create Profile with name that becomes duplicate between check and save | `DuplicateProfileNameException` caught; snackbar `profileNameTaken` shown | — | |

---

## 8. ProfileEditDeleteActions / ProfileEditFormDialog

**Triggered from:** `ManageLearnersScreen` popup menu (edit/delete); `ProfileSwitcherSheet` pencil/trash icon per row.

### 8.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|---|---|---|---|---|
| See step 49 | Edit via popup | `ProfileEditFormDialog` | Dialog opens with title `profilesEditLearner`, name field pre-filled, mode segmented button, avatar horizontal scroll (10 avatars) | — | |
| 157 | Observe mode segmented button in edit dialog | `SegmentedButton<String>` | Shows current mode pre-selected; mode is displayable but changing mode via this control does NOT persist (only name + avatar are saved per code) | CHILD/ADULT type labels only | |
| 158 | Scroll avatar picker horizontally | `SingleChildScrollView` horizontal row | 10 avatar circles scrollable; selected one has blue border highlight | — | |
| 159 | Tap a different avatar | `GestureDetector` per avatar | Selection border moves to tapped avatar | — | |
| 160 | Clear the name field | `TextField` | Save button stays enabled until empty (no: actually Save `FilledButton` checks `name.isEmpty` → returns without pop; button appears enabled but does nothing) | UNKNOWN BEHAVIOUR — cannot determine from source whether button is visually disabled when empty; executor must probe | |
| 161 | Tap Cancel | `TextButton` Cancel | Dialog dismissed; no changes | — | |
| 162 | Tap Save with valid name | `FilledButton` Save | `repo.updateProfile(id, displayName, avatarIndex)` called; providers invalidated; dialog closes | — | |
| 163 | Tap Save in tutored context with permission denied | `FilledButton` Save | `TutorWriteException` caught; snackbar `tutorPermissionDenied` shown | WS3.3d tutor write permission | |
| See step 50 | Delete via popup | `deleteProfileFlow` | Confirm dialog with last-profile guard and offline guard | — | |
| 164 | Tap Cancel in delete confirm | `TextButton` Cancel | Dialog dismissed; profile unchanged | — | |
| 165 | Tap Delete (non-last, online) | `TextButton` (foreground=error) Delete | Profile deleted; providers invalidated | — | |
| 166 | Tap Delete (offline, cloud account) | `TextButton` Delete | Connectivity check fails; snackbar `errorDeleteProfileRequiresInternet` | [SF-1] | |
| 167 | Tap Delete (last profile) | `TextButton` `deleteProfileLastConfirm` | Special "last" confirm dialog text; on confirm, profile deleted; `selectedProfileIdProvider` cleared | — | |

---

## 9. ProfileSwitcherSheet

**Triggered from:** `UserProfileHeaderCard` tap in Settings/ParentSettings (the top header). Call: `showProfileSwitcherSheet(context)`.

### 9.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|---|---|---|---|---|
| 168 | Observe sheet layout | `DecoratedBox` bottom sheet | White rounded sheet; drag handle at top; "ACCOUNT" section header + `switchAccount` ListTile; divider; "PROFILES" section header; profile tiles; "Add Profile" row at bottom | — | |
| 169 | Observe drag handle | Center top bar | 40×4 grey pill handle visible | — | |
| 170 | Swipe down to dismiss | Sheet drag | Sheet dismisses; no action taken | — | |
| 171 | Observe Account / Switch row | `ListTile` with swap icon | Shows `switchAccount` title; if `accountEmail` non-null, email shown as subtitle (1 line, ellipsis) | Account switching needs NO sign-out (instant switch to Dashboard) — rule implies no sign-out prompt | |
| 172 | Tap "Switch Account" row | `ListTile` onTap | Sheet closes; `AccountPickerRoute` pushed | Account switching needs NO sign-out — verify picker appears without requiring sign-out first | |
| 173 | Observe active profile tile | `_SwitcherProfileTile` (isActive=true) | Blue check-circle icon before edit/delete icons; tile NOT tappable (onTap is null for active) | — | |
| 174 | Observe inactive profile tile | `_SwitcherProfileTile` (isActive=false) | No check-circle; tile is tappable | — | |
| 175 | Tap an inactive profile tile | `ListTile` onTap | Sheet closes; `activeTutoredProfileSelectionProvider` exits any tutored session; `parentPinAuthenticatedProfileIdProvider` cleared; `selectedProfileIdProvider` updated; `AppShellRoute` replaces stack | — | |
| 176 | Tap edit pencil icon on a profile | `IconButton` pencil | `editProfileFlow` invoked; `ProfileEditFormDialog` opens (sheet stays open until dialog closes) | — | |
| 177 | Tap delete trash icon on a profile | `IconButton` trash | `deleteProfileFlow` invoked; delete confirmation dialog | — | |
| 178 | Observe `TutoredChildrenSection` embedded in sheet | Inside scrollable area | Talmid section appears if user has active/pending tutor grants | — | |
| 179 | Observe "Add Profile" row at bottom | `ListTile` with circle + icon | Visible; `addProfile` title; `brandBlueDeep` color | — | |
| 180 | Tap "Add Profile" | `ListTile` onTap | Sheet closes; `showAddProfileDialog` opens | — | |
| 181 | Observe in Hebrew/RTL | Full sheet | Account section, profile tiles, icons all mirror RTL | — | |
| 182 | Observe in dark mode | Full sheet | Sheet background remains white (hardcoded `Colors.white`); text contrast may vary — PROBE | — | |

---

## 10. TutoredChildrenSection Widget

**Used in:** `ProfilePickerScreen` (embedded) and `ProfileSwitcherSheet` (embedded).

### 10.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|---|---|---|---|---|
| 183 | Observe with 0 grants | `TutoredChildrenSection` | `SizedBox.shrink()` — nothing rendered | — | |
| 184 | Observe loading state | While `grantsAsync` is loading | `SizedBox.shrink()` — nothing rendered (never blocks own-profile render) | — | |
| 185 | Observe with ≥1 active grants | Active grant rows | Divider, "TALMID PROFILES" header, `_TutoredChildRow` per active grant | — | |
| 186 | Observe with pending grants only | Pending grants | `_ViewInvitationsRow` visible; no child rows | — | |
| 187 | Observe `_TutoredChildRow` | Row layout | School icon; child display name (denormalised label); "Tutoring" green subtitle; green "Rebbe" badge | — | |
| 188 | Tap a tutored child row | `_TutoredChildRow` onTap | `TutorPinEntryGate` modal pushed; on success: tutored session entered, `AppShellRoute` replaces stack | Tutor canMarkLiveCompletion = FALSE — verify once inside shell | |
| 189 | First-time entry (no cached mirror) | Talmid row tap + PIN success | Loading spinner shown (blocking); 15-second timeout; on success, shell loads; on `permissionDenied`, snackbar + session exited; on error, snackbar + session exited | [SF-1] fail-safe; offline-first | |
| 190 | Cached mirror entry (previous session) | Talmid row tap + PIN success | Navigation to `AppShellRoute` fires immediately without spinner; delta listeners attach in background | offline-first rule | |
| 191 | Tap tutored child row — cancel PIN | `TutorPinEntryGate` cancel | Modal dismissed; no session state set; remains on picker/switcher | — | |
| 192 | Observe `_ViewInvitationsRow` | Row | Mail icon with orange badge (count); `tutoredChildrenViewInvitations` title; `tutoredChildrenPendingInvitations(count)` subtitle; chevron right | — | |
| 193 | Tap "View invitations" row | `_ViewInvitationsRow` onTap | `TutorPinEntryGate` pushed; on success, `ManageGrantsRoute` pushed | — | |
| 194 | Tap "View invitations" — cancel PIN | Cancel in gate | Modal dismissed; no navigation | [SF-1] | |

---

## 11. ParentPinSetupDialog (showParentPinSetupDialog)

**Triggered:** Automatically after `showAddProfileDialog` creates a child profile. Also called from `PinGuard` when no PIN is set (via the setup route).

This dialog wraps `_ParentPinSetupDialog` which uses `PinKeypadDialogFrame`. It is NOT dismissible (`barrierDismissible: false`, `PopScope(canPop: false)`).

### 11.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|---|---|---|---|---|
| 195 | Observe dialog | `PinKeypadDialogFrame` | Title = `setParentPinDialogTitle`; subtitle = `setParentPinDialogSubtitle(profileName)`; 4 empty dots; digit keypad; NO close button; NO cancel | — | |
| 196 | Attempt to dismiss by tapping outside | Barrier | Not dismissible (`barrierDismissible: false`); dialog stays | — | |
| 197 | Attempt system Back | Android Back | `PopScope(canPop: false)` blocks; cannot escape setup | — | |
| 198 | Enter 4 digits (first entry) | Digit buttons | Dots fill; auto-transitions to confirm step; title = `confirmNewPin`; subtitle = `confirmNewPinSubtitle`; dots clear | — | |
| 199 | Enter same 4 digits on confirm | Digit buttons | `PinService.setProfilePin` called; dialog pops with `true` | — | |
| 200 | Enter different 4 digits on confirm | Digit buttons | Error `pinsDoNotMatch`; reverts to first-entry step; dots clear; can retry | — | |
| 201 | Tap backspace at any step | Backspace chip | Last entered dot empties | — | |
| 202 | Observe busy state during hash | Keypad | All digit buttons disabled while `_busy = true` | — | |

---

## 12. ParentPinKeypadDialog — Verification (showParentPinVerificationDialog)

**Triggered by:** PIN guard prompt; direct call from parent-mode entry flows.

### 12.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|---|---|---|---|---|
| 203 | Observe dialog | `PinKeypadDialogFrame` (via `_ParentPinVerificationDialog`) | Title = `enterParentPin`; subtitle = `enterParentPinSubtitle`; 4 empty dots; digit 0–9 + backspace + Cancel; close (X) button visible | — | |
| 204 | Tap close (X) | Close `IconButton` | Dialog pops with `false` | [SF-1] | |
| 205 | Tap Cancel in keypad | `TextButton` Cancel | Dialog pops with `false` | [SF-1] | |
| 206 | Attempt to dismiss by tapping outside | Barrier | `barrierDismissible: false`; must use Cancel/X | — | |
| 207 | Enter correct 4-digit PIN | Digit buttons | Auto-submits; `verifyProfilePin` returns true; `analytics.logParentModeEntered` fires if analytics provided; dialog pops with `true` | — | |
| 208 | Enter wrong 4-digit PIN | Digit buttons | `verifyProfilePin` returns false; error `incorrectPin` shown; dots clear | — | |
| 209 | Trigger lockout | Repeat wrong entries ≥ threshold | `PinLockoutException` caught; `_LockoutPanel` shown; keypad hidden; "Too many failed attempts" + "Try again in N minute(s)" | — | |
| 210 | Tap system Back (verification dialog) | Android Back | `PopScope(canPop: false)` blocks; `onClose()` called (pops with `false`); no hang | [SF-1] Route guards never lock out / hang | |
| 211 | Observe busy state | Digit buttons during verify | All digit + backspace + cancel disabled while async verify runs | — | |

---

## 13. ParentPinKeypadDialog — Change PIN (showParentPinChangeDialog)

**Triggered by:** Settings entry "Change Parent PIN" (route: `PinFlowChangeRoute`). The `_ParentPinChangeDialog` implements the same multi-step flow as `PinFlowScreen` change mode but as an in-dialog widget.

### 13.1 Test Steps

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|---|---|---|---|---|
| 212 | Observe dialog — step 1 | `_ParentPinChangeDialog` | Title = `enterCurrentPin`; subtitle = `enterParentPinSubtitle`; Cancel + backspace present | — | |
| 213 | Enter correct current PIN | Digit buttons | Transitions to step 2; title = `enterNewPin`; subtitle = `enterNewPinSubtitle` | — | |
| 214 | Enter wrong current PIN | Digit buttons | Error `incorrectPin`; step stays at verifyCurrent | — | |
| 215 | Lockout on current PIN | Repeat wrong | `_LockoutPanel` shown | — | |
| 216 | Enter new PIN — step 2 | Digit buttons | Transitions to step 3; title = `confirmNewPin` | — | |
| 217 | Confirm new PIN — matches | Digit buttons | `PinService.setProfilePin` called; snackbar `pinChangedSuccessfully`; dialog pops with `true` | — | |
| 218 | Confirm new PIN — mismatch | Digit buttons | Error `pinsDoNotMatch`; reverts to step 2 (`enterNew`); `_newPin` cleared | — | |
| 219 | Tap Cancel at any step | Cancel | Dialog pops with `false`; old PIN still valid | [SF-1] | |
| 220 | Tap Close (X) at any step | Close icon | Dialog pops with `false` | [SF-1] | |
| 221 | System Back at any step | Android Back | `PopScope(canPop: false)` blocks; `onClose()` cancels | [SF-1] | |

---

## 14. Cross-Cutting States Summary

### 14.1 States to verify per surface

| Screen/Widget | Loading | Empty | Error | Offline | Data — child mode | Data — adult mode | Data — tutor mode | Hebrew/RTL | Dark mode |
|---|---|---|---|---|---|---|---|---|---|
| ProfilePickerScreen | Spinner | 0 cards + sign-out section | AppErrorView + Retry | Profiles from local DB; deletion of cloud profile blocked | Profile cards show child badge | Profile cards show adult badge | Tutored section visible; pending invite card | RTL layout | Gradient + cards adapt |
| ManageLearnersScreen | Spinner | noProfilesYet text | AppErrorView + Retry | Same as above | Child label in subtitle | Adult label | (same screen, not mode-specific) | RTL list tiles | — |
| ParentSettingsScreen | (list renders from async data, no separate spinner) | — | — | (parent settings loaded synchronously) | All tiles shown | Only shown when child profile active | Subset tiles per permissions | RTL | Cards adapt |
| ParentTrackManagementScreen | Spinner | Empty-state with AddTrack button | AppErrorView + Retry | Track list from local cache | Track cards | Only reached via child profile | Tutor sees same screen | RTL | — |
| PinFlowScreen setup | Busy indicator on keypad | — | Error message on mismatch | PIN is hashed locally; offline-safe | — | — | — | RTL keypad | — |
| PinFlowScreen verify | Busy indicator | — | Error/lockout panel | PIN verify is local; offline-safe | — | — | — | RTL keypad | — |
| PinFlowScreen change | Busy indicator | — | Error/lockout panel | Same | — | — | — | RTL keypad | — |
| ProfileSwitcherSheet | Profiles from stream (may be stale) | (no own profiles = only Add row) | (graceful empty list) | Own profiles from local stream | Both child + adult shown | Same | TutoredSection visible | RTL sheet | White bg (hardcoded — may not adapt) |
| TutoredChildrenSection | SizedBox.shrink (no block) | SizedBox.shrink | SizedBox.shrink | Cached grants visible | — | — | Active + pending rows | RTL | — |
| ParentPinSetupDialog | Busy on keypad | — | pinsDoNotMatch error | Fully offline-safe (local hash) | — | — | — | RTL keypad | — |
| ParentPinKeypadDialog verify | Busy on keypad | — | incorrectPin / lockout panel | Offline-safe | — | — | — | RTL keypad | — |
| ParentPinKeypadDialog change | Busy on keypad | — | incorrectPin / lockout / mismatch | Offline-safe | — | — | — | RTL keypad | — |

### 14.2 Session Fixes — Regression Checklist

| Fix ID | Description | Where to verify in this cluster |
|---|---|---|
| [SF-1] Route guards never lock out / hang | PinGuard wraps all async in try/catch; `resolver.next(false)` on any error | PinFlowScreen: system Back, Cancel, lockout path; TutoredChildRow: cancel PIN gate |
| [SF-1] Auth/Restore/Profile fail safe | ProfilePickerScreen error state shows AppErrorView (not blank); Retry re-fetches | ProfilePickerScreen step 36–37 |
| [SF-2] Account-merge "discard local" no crash | `showDeleteLocalAccountFlow` called from ParentSettingsScreen | ParentSettingsScreen step 85 |
| [SF-3] Sign-in connectivity routing | `showDeleteAccountFlow` and sign-out confirm flows reached from ParentSettingsScreen | Steps 81–85 |
| [SF-4] Sacred-time "in Israel" toggle sticks | Not directly in this cluster (no sacred-time UI here) | — |
| [SF-5] Scope-selection Save disabled for empty subset | Not directly in this cluster | — |
| [SF-6] Redemption Fulfil/Decline single-tap guarded | `ParentPendingRedemptionsRoute` reached from step 73 | Step 73 |
| [SF-7] Magic-link / deep-link no crash on malformed | `AcceptInviteRoute` pushed from profile picker invite card | Step 28 |

### 14.3 Product Rules — Assertion Checklist

| Rule | Where to assert in this cluster |
|---|---|
| No track-type label ("Personal"/"Standard"/"Custom"/אישי) anywhere | ProfilePickerScreen cards (step 2), ManageLearnersScreen subtitles (steps 46–47), ParentTrackManagementScreen track cards (step 99) |
| Chazara UI only when track has chazaraEnabled | ParentTrackManagementScreen: verify `LearningTrackCard` for a non-chazara track shows no chazara references |
| Tutor canMarkLiveCompletion = FALSE | After entering tutored shell (step 30 / step 188): confirm no live "mark complete" affordance in the child's learning view |
| Persistent profile/role switcher at TOP of every context | ProfileSwitcherSheet is the canonical entry; `UserProfileHeaderCard` tap in ParentSettingsScreen (step 57) confirms it opens switcher, not a settings duplicate |
| Settings: top header = ACCOUNT-only; profile management ONLY in PROFILE section | ParentSettingsScreen step 57 — `UserProfileHeaderCard` opens switcher; no "manage profile" action duplicated in account header |
| Account switching needs NO sign-out | ProfileSwitcherSheet → "Switch Account" (step 172) should navigate directly to account picker without sign-out |
| Adults have no points/gamification | ParentSettingsScreen only appears for CHILD profiles; adult profiles never reach this screen (child-mode guard) |
| Program start date constrained, back-dating creates catch-up tasks | Not directly in this cluster (no program-start date UI here) |
| Bulk/lifetime marking sentinel date — not in streak/recent activity | ParentSettingsScreen step 74–75; verify `LifetimeMarkingRoute` behavior |
| Hebrew terms vs transliteration independent of UI locale | Profile names and track names should render as stored regardless of device language |

---

## 15. Unknown / Probe-Required Behaviours

The following elements have behaviours that cannot be fully determined from source alone. The on-device executor must probe these carefully:

1. **`ProfileEditFormDialog` Save button with empty name** (step 160): The button has no explicit `onPressed: name.isEmpty ? null : ...` guard — it always appears enabled, but the onPressed handler returns early if `name.isEmpty`. Visually it may look enabled but do nothing. Probe: is the button visually enabled when name is empty? Does it feel broken to the user?

2. **`ProfileSwitcherSheet` dark mode** (step 182): The sheet background is `Colors.white` (hardcoded). In Android dark mode, does Material's dialog surface override this, or does it appear blindingly white?

3. **`PinFlowScreen` — cancel/back from setup mode opened by `PinGuard`** (step 121): `PopScope(canPop: false)` prevents back navigation in setup mode, but the `_SetupScaffold` does NOT show a Cancel button. If a user arrives at PIN setup via the guard (not via `showAddProfileDialog` which always completes before returning), they may be stuck. Probe: is there any exit path from the guard-triggered setup route?

4. **`_TutoredChildRow` first-time pull — loading spinner** (step 189): A `CircularProgressIndicator` is shown in a non-dismissible dialog during the pull. If the 15-second timeout fires, the error case dismisses the dialog and shows a snackbar. Probe: does the timeout snackbar appear correctly and the user land back on the picker without any hanging state?

5. **`ManageLearnersScreen` FAB position**: The FAB uses `MediaQuery.of(context).viewPadding.bottom` for bottom padding. On devices without a home-bar (classic Android with on-screen buttons), the FAB may overlap the navigation bar. Probe on both gesture-nav and classic 3-button nav configurations.

6. **`ParentSettingsScreen` — `showDeleteAccountTile` when `user == null && !isLocalBorn`**: In this case `showDeleteAccountTile = false`; the delete tile is hidden. Probe: confirm there is no "orphaned" signed-in state where a user has a cloud-born account but `currentUser` is momentarily null, causing the tile to disappear confusingly.



## Cluster: App Shell (Bottom Nav + Persistent Context Switcher) + Dashboard

---

### 1. AppShellScreen — Persistent Chrome (bottom nav, context banners, offline banner)

**Route / how to reach:** Automatic after successful authentication and profile resolution. Every signed-in screen is hosted inside `AppShellScreen`. No tap path needed — it is the root scaffold.

**Preconditions for various sub-states:**

| Sub-state | How to reach |
|---|---|
| Normal (adult, own profile) | Sign in with an adult account that has ≥1 active track |
| No own profiles | Sign in with an account that has zero profiles (e.g. tutor-only adult who deleted all profiles) |
| Parent mode (child-view banner) | Adult account with ≥1 child profile; enter the child's profile via Profile Switcher; separately enter Parent Mode (PIN prompt) |
| Tutor mode (amber bar) | Adult account with ≥1 active incoming tutor grant; enter the talmid's profile via the Profile Switcher (PIN gate) |
| Offline (cloud-born) | Put device in airplane mode; app must be cloud-born (signed in with Firebase account) |
| Offline (local-born) | Born as local — no offline banner should ever appear |
| Dark mode | Enable dark mode in device system settings |
| Hebrew/RTL | Set device language to Hebrew OR toggle Hebrew Terms in Settings |

#### Test-step table — Bottom Navigation Bar

| # | Action on which element | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|---|---|---|---|
| 1 | Tap **Dashboard** tab (house/grid icon, label "Dashboard") | Dashboard screen replaces active tab content; tab item animates to selected state (white icon + blue pill background) | Persistent tab; round-trip navigation must never hang — Route-guard fix | |
| 2 | Tap **Learn** tab (book icon) | Learning screen loads; tab item becomes selected; Dashboard tab deselects | Navigation must not lock — Route-guard fix | |
| 3 | Tap **Progress** tab (graph icon) | Progress hub loads | Navigation must not lock | |
| 4 | Tap **Settings** tab (gear icon) | Settings screen loads | Navigation must not lock | |
| 5 | While on Learn tab, tap the **Dashboard** tab | Dashboard tab becomes active; no double-push/stack corruption | Account switching needs no sign-out | |
| 6 | In **parent mode** (adult has entered PIN for a child profile), observe the bottom nav | Bottom nav is completely absent (`SizedBox.shrink()`); no four-tab bar visible | Parent-mode hides bottom nav per spec | |
| 7 | In **tutor mode** (amber bar visible), observe the bottom nav | Standard four-tab bottom nav IS visible (tutor uses full child-profile tabs) | Tutor sees full tab set; parent mode is the only case hiding it | |
| 8 | With **zero own profiles** and no active tutored session, observe which tab is active on launch | App automatically jumps to the **Settings** tab (index 3); Dashboard tab is NOT selected | Profile-less users land on Settings to manage account | |
| 9 | After jumping to Settings (step 8), add a profile | `_didJumpToSettings` resets; next launch starts on Dashboard | Auto-jump resets when profiles are non-empty | |

#### Test-step table — Offline Top Banner

| # | Action on which element | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|---|---|---|---|
| 10 | With a **cloud-born account**, enable airplane mode | Slim banner appears at top of screen reading "Offline — changes will sync when you're back"; height 32 dp; fits below system status bar | Banner visible only for cloud-born accounts | |
| 11 | While offline banner is visible, re-enable network | Banner animates away (AnimatedSize) — no blank gap remains | Offline-first: sync is informational only | |
| 12 | With a **local-born account**, enable airplane mode | Offline banner must NOT appear at any point | Local-born users never see the offline banner | |
| 13 | Observe banner height integration: when offline banner is hidden vs shown | No layout jump or content behind the status bar; `PreferredSize` height adjusts correctly | Correct sizing guards content from status-bar overlap | |

#### Test-step table — Tutor Mode Indicator Bar (amber, height 24 dp)

Precondition: adult account with active incoming tutor grant; has entered talmid's profile through PIN gate.

| # | Action on which element | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|---|---|---|---|
| 14 | Observe tutor-mode bar | Amber bar (#D97706) visible below offline strip; shows school icon + `tutorModeIndicator` text + "Exit" button | Tutor mode accent color distinct from primary blue | |
| 15 | Tap the **tutor bar body** (anywhere except Exit button) | `ProfileSwitcherSheet` opens | Bar body is a `GestureDetector` → switcher | |
| 16 | Tap the **Exit button** in the tutor bar | `activeTutoredProfileSelectionProvider.notifier.exit()` called; router replaces stack with `AppShellRoute`; amber bar disappears; user lands on their own profile's Dashboard | Tutor exit clears active tutored context; account switch needs no sign-out | |
| 17 | After exiting tutor mode (step 16), confirm tutor bar is gone | No amber bar; standard tab bar visible; standard Dashboard loads for own profile | Route-guard fix: no hang post-exit | |

#### Test-step table — Child View Banner (emerald green, height 28 dp)

Precondition: adult has ≥1 child profile; adult entered the child's profile AND entered parent mode (PIN prompt was satisfied); no active tutored session.

| # | Action on which element | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|---|---|---|---|
| 18 | Observe child-view banner | Emerald-green (#047857) banner visible; shows child_care icon + "Viewing [child name]" text + "Exit parent mode" button | Child-view banner distinct from tutor bar; mutually exclusive | |
| 19 | Tap the **banner body** (anywhere except Exit button) | `ProfileSwitcherSheet` opens | Banner body tap → switcher | |
| 20 | Tap the **"Exit parent mode" button** | `routerProvider.pinGuard.lock()` called; router replaces stack with `AppShellRoute`; green banner disappears; child profile remains active (no automatic switch to adult) | Exiting parent mode drops PIN elevation only — child profile stays active | |
| 21 | Confirm that when **tutor bar** is visible, child-view banner is NOT shown | Only one context banner displays at a time | Banners are mutually exclusive per source logic | |

---

### 2. ProfileSwitcherSheet

**How to reach:**
- Tap any context banner (tutor bar body, child-view banner body) → sheet opens.
- The profile row in `UserProfileHeaderCard` in Settings also calls `showProfileSwitcherSheet`.

**Preconditions for section visibility:**
- "Talmid Profiles" section visible only when the account has ≥1 active tutor grant OR ≥1 pending invitation (DEC-8 rule).

#### Test-step table

| # | Action on which element | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|---|---|---|---|
| 22 | Open sheet: observe overall layout | White rounded bottom sheet; drag handle at top; "ACCOUNT" section header; "Switch Account" list tile; divider; "PROFILES" section header; profile tiles; "Add Profile" tile at bottom | Layout correct | |
| 23 | **Drag handle** — swipe down to dismiss | Sheet dismisses; returns to previous screen | Standard modal bottom sheet dismiss | |
| 24 | Tap **"Switch Account" list tile** | Sheet closes; navigates to `AccountPickerRoute` | Account switching needs NO sign-out (product rule) | |
| 25 | Observe **account email subtitle** on "Switch Account" tile | Current Firebase email shown in muted small text; truncated with ellipsis when long | Email shown for cloud-born accounts | |
| 26 | For each **profile tile**: tap a non-active profile row | Sheet closes; `selectedProfileIdProvider` updated; `AppShellRoute` replaces stack; Dashboard loads for that profile | Account switching (profile switch) needs no sign-out; route-guard fix: no hang | |
| 27 | For the **currently-active profile tile**: observe the row | Tap has no effect (`onTap: isActive ? null : onTap`); row shows a `check_circle_rounded` icon | Active profile tile is not re-tappable | |
| 28 | For each profile tile, tap the **edit (pencil) icon button** | `editProfileFlow(context, ref, profile)` is called; profile edit dialog/flow opens | Profile management only in PROFILE section — not duplicated in account header | |
| 29 | For each profile tile, tap the **delete (trash) icon button** | `deleteProfileFlow(context, ref, profile)` is called; confirmation dialog appears; confirm deletion removes profile | Profile management only in PROFILE section | |
| 30 | Tap **"Add Profile" tile** at the bottom | Sheet closes; `showAddProfileDialog(context, ref)` is called; add-profile dialog opens | Profile management in profile section only | |
| 31 | With **no tutor grants and no pending invitations**: confirm "Talmid Profiles" section is absent | `TutoredChildrenSection` renders `SizedBox.shrink()`; no talmid header, no grant rows | DEC-8 gating | |
| 32 | With **≥1 pending tutor invitation**: observe "Talmid Profiles" section | Section visible; "View invitations" row with orange badge showing pending count | DEC-8: section shows when pending invites exist | |
| 33 | Tap the **"View invitations" row** | `TutorPinEntryGate` presented modally; on PIN success, navigates to `ManageGrantsRoute` | Tutor PIN gate enforced before showing invite data | |
| 34 | In the `TutorPinEntryGate` modal (from step 33), tap **Cancel** | Modal dismisses; returns to sheet (or previously dismissed sheet) | PIN gate cancel must not crash — Route-guard fix | |
| 35 | With **≥1 active talmid grant**: observe "Talmid Profiles" section | Section shows child name(s) with "Tutoring" green badge; no raw Firestore profile ids displayed | Talmid profiles show display name | |
| 36 | Tap a **talmid row** (active grant) | `TutorPinEntryGate` presented; on PIN success, tutored pull fires (≤15 s timeout); on success navigates to talmid's `AppShellRoute` with amber tutor bar | T2.entry-pull + T2.nav; canMarkLiveCompletion = FALSE in tutor session | |
| 37 | Tap a **talmid row** while **offline** (no cached mirror) | Spinner shown; 15 s timeout elapses; error snackbar shown; active tutored selection cleared; user lands back at their own profile — no crash or infinite spinner | Offline-first: error path must fail safe; route-guard fix: no hang | |
| 38 | Tap a **talmid row** while **offline** (cached mirror exists) | Enters talmid view immediately without waiting for network; amber tutor bar visible | Offline-first with cached mirror | |
| 39 | While in `ProfileSwitcherSheet`, press the Android **system Back button** | Sheet dismisses | System Back dismisses modal sheet | |

---

### 3. DashboardScreen + DashboardBody (primary populated state)

**Route name:** `DashboardRoute()` — tab index 0.

**How to reach:** Launch app with a profile that has ≥1 active track. Tap "Dashboard" in the bottom nav, or the app lands here by default.

**Preconditions matrix:**

| State | How to reach |
|---|---|
| Loading state | First launch before stream emits; or trigger by disabling wifi mid-session and force-refreshing |
| Error state | Cannot be easily triggered manually; source shows `AppErrorView` with retry button — note for executor to probe |
| Data (populated) | Normal: profile with active tracks and some tasks |
| All caught up | Profile with tracks, all counts (today, overdue, chazara) = 0 AND sync complete |
| Child mode | Switch to a child profile |
| Adult mode | Default for adult profiles |
| Tutor mode | Enter a talmid's AppShell via Profile Switcher |
| Offline | Enable airplane mode (data persists from local DB) |
| Initial sync not complete | First launch on fresh install before Firestore pull finishes (task counts show "…") |
| Hebrew/RTL | Set Hebrew Terms in Settings |
| Dark mode | Set device to dark mode |

#### Test-step table — DashboardBody header area

| # | Action on which element | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|---|---|---|---|
| 40 | Observe the **greeting chip** at top-left | Shows time-appropriate greeting ("Good morning" / "Good afternoon" / "Good evening") with matching icon and color chip; changes at hour boundary | Greeting is time-based; no interactive tap | |
| 41 | Observe the **profile name heading** below the greeting | Displays `profileName` from `selectedProfileProvider`; falls back to "Learner" when null | Profile name resolved correctly | |
| 42 | Observe the **date label** | Today's date formatted in locale (e.g. "May 29, 2026" or Hebrew equivalent) | Date uses device locale | |
| 43 | Observe the **streak counter** badge (red pill, fire icon, top-right) | Shows `currentStreak` integer from `dashboardStreakProvider`; 0 when no streak | Streak visible for all profiles (child and adult) | |
| 44 | **Pull to refresh** on the dashboard ListView | All dashboard providers invalidated and re-fetched; loading states briefly appear; data refreshes | Pull-to-refresh triggers full invalidation | |

#### Test-step table — ProgressTierCounterRow

| # | Action on which element | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|---|---|---|---|
| 45 | Observe **ProgressTierCounterRow** in adult mode | Row shows engagement, achievement, lifetime counters; NO points (⭐) counter | Adults have no points/gamification (product rule) | |
| 46 | Observe **ProgressTierCounterRow** in child mode | Row shows engagement, achievement, lifetime counters PLUS a ⭐ points counter (`showPoints: true`) | Child mode includes points counter | |

#### Test-step table — DashboardLevelPointsCard (blue gradient stats card)

Shown when: tracks exist AND at least one count (today, overdue, or chazara) is non-zero OR sync not yet complete.

| # | Action on which element | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|---|---|---|---|
| 47 | Observe **points display** in adult mode | Points abbreviation (e.g. "0 pts") shown in top-right; no change on completion | Adults have no gamification — points should remain 0 regardless | |
| 48 | Observe the **OVERDUE stat bubble** | Shows count or "…" (when `tasksReady = false`); tap navigates to Scheduler in `overdue` section | Bubble tappable → Scheduler; "…" during sync | |
| 49 | Tap the **OVERDUE bubble** | `schedulerTaskSectionProvider` set to `overdue`; `SchedulerRoute` pushed | Bubble tap navigates to Scheduler overdue lane | |
| 50 | Observe the **TODAY DUE stat bubble** | Shows count or "…" | Bubble tappable → Scheduler today lane | |
| 51 | Tap the **TODAY DUE bubble** | `schedulerTaskSectionProvider` set to `today`; `SchedulerRoute` pushed | | |
| 52 | With a track that has **chazara enabled**: observe the **chazara bubble** | Third bubble visible with Hebrew/transliteration label from `domainTermLabels`; tap navigates to Scheduler review lane | Rule 8: chazara UI renders ONLY when track has chazaraEnabled | |
| 53 | With **no track having chazara**: observe the stats row | Only two bubbles (OVERDUE + TODAY DUE); NO chazara bubble — not zeroed, not greyed, entirely absent | Rule 8: no chazara bubble when no track has chazara | |
| 54 | Observe the **lifetime progress bar** (gold animated bar) | Bar displays `cumulativeLifetime` fraction; animates on load | Progress bar visible | |
| 55 | Tap the **lifetime progress bar** | Navigates to `ProgressRoute` (Progress hub) | Progress bar is tappable → Progress tab | |
| 56 | Verify **no track-type label** ("Personal"/"Standard"/"Custom"/אישי) appears anywhere in the stats card | None of those strings are rendered | No track-type label (product rule) | |

#### Test-step table — DashboardAllCaughtUpCard

Shown when: `tasksReady && lifetimeReady && reviewCount == 0 && overdueCount == 0 && todayCount == 0`.

| # | Action on which element | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|---|---|---|---|
| 57 | Observe the "All caught up" card when all tasks are done | Blue gradient card with check icon, "All caught up" title, subtitle, lifetime progress % and animated bar | Shown only after sync is complete (not during loading) | |
| 58 | Tap the **lifetime progress bar** on the all-caught-up card | Navigates to `ProgressRoute` | Progress bar tappable → Progress | |

#### Test-step table — ChildPointsRewardsTabCard (child mode only)

Precondition: active profile is a child.

| # | Action on which element | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|---|---|---|---|
| 59 | Observe the **points card** in child mode | Blue gradient card shows trophy icon, "CURRENT BALANCE" label, formatted points number, "Redeem Prizes" button | Child points card visible in child mode | |
| 60 | Tap the **"Redeem Prizes" button** | Navigates to `ChildRedemptionRoute` | Opens child redemption screen | |
| 61 | Confirm card is **absent in adult mode** | No blue points card anywhere on the dashboard | Adults have no points/gamification (product rule) | |

#### Test-step table — "Today's Missions" section (MainFocusMissionCard + CompactMissionCard cards)

| # | Action on which element | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|---|---|---|---|
| 62 | Observe the **"Today's Missions" heading** row | Title "Today's Missions" (28px bold) + remaining count badge on the right | Header always visible when tracks exist | |
| 63 | Tap the **MainFocusMissionCard** (the large "DUE TODAY / Start Learning" card) — tap the card body | `schedulerTaskSectionProvider` set to `today`; `SchedulerRoute` pushed | Card-level tap → Scheduler today | |
| 64 | Tap the **"Start Learning →" FilledButton** inside MainFocusMissionCard | Same: `SchedulerRoute` pushed with `today` section | Button inside card has same destination as card tap | |
| 65 | With **chazara enabled track**: observe the **chazara CompactMissionCard** (gold accent) | Card visible with chazara label (Hebrew or transliteration per Hebrew Terms setting) and review count | Rule 8: chazara card only visible when a track has chazaraEnabled | |
| 66 | With **no chazara-enabled track**: confirm chazara card is absent | No chazara compact card at all; no placeholder or zero count | Rule 8: no chazara references without chazaraEnabled track | |
| 67 | Tap the **chazara CompactMissionCard** (when visible) | `schedulerTaskSectionProvider` set to `review`; `SchedulerRoute` pushed | Taps to Scheduler review lane | |
| 68 | Observe the **Overdue CompactMissionCard** (dashed red border, "URGENT" label) | Always visible (even when count = 0); shows overdue count; dashed red border styling | Overdue card always present | |
| 69 | Tap the **Overdue CompactMissionCard** | `schedulerTaskSectionProvider` set to `overdue`; `SchedulerRoute` pushed | Taps to Scheduler overdue lane | |

#### Test-step table — ActiveTracksCarouselSection + ActiveTrackCard

| # | Action on which element | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|---|---|---|---|
| 70 | Observe the **carousel section header** ("Active Tracks" + subtitle) | Title and subtitle text rendered; left/right arrow buttons on right | Header visible | |
| 71 | With **1 active track**: observe left and right **ArrowButtons** | Left arrow disabled (muted); right arrow disabled (muted); no crash | Arrow buttons disabled when only one track | |
| 72 | With **≥2 active tracks**: tap the **right ArrowButton** (chevron_right) | PageView animates to next card; `_activeIndex` increments; left arrow becomes enabled | Right arrow navigates forward; right arrow disables at last page | |
| 73 | Tap the **left ArrowButton** (chevron_left) after step 72 | PageView animates back to first card; left arrow becomes disabled again | Left arrow navigates back; disables at first page | |
| 74 | **Swipe horizontally** within the PageView | Pages swipe; arrow state updates | Swipe gesture on carousel | |
| 75 | Tap an **ActiveTrackCard** body (when a task has a focus ref) | Navigates to `TextDisplayRoute(sefariaRef: focusRef)` — opens the text viewer | Card tap → text for current focus | |
| 76 | Tap an **ActiveTrackCard** body (when NO task is scheduled — empty queue) | Navigates to `ContentHierarchyRoute(curriculumId: ...)` — opens browse tree | Card tap → browse tree fallback | |
| 77 | Observe **curriculum name** on the track card | Shows primary name (localised label) + optional Hebrew secondary name; NO track type suffix ("Personal"/"Standard"/etc.) | No track-type label (product rule) | |
| 78 | With a track that has **chazara enabled**: observe the **TrackStatGrid** | Three stat boxes: chazara | due today | overdue; each tappable when count > 0 | Rule 8: chazara column shown only when track has chazara stages | |
| 79 | With a track that has **no chazara**: observe the **TrackStatGrid** | Two stat boxes only: due today | overdue; no chazara column | Rule 8 | |
| 80 | Tap a **non-zero stat box** (chazara / due today / overdue) in the TrackStatGrid | Navigates to `TextDisplayRoute` for the first task in that bucket | Stat box tappable when count > 0 | |
| 81 | Tap a **zero-count stat box** | No navigation; box is non-tappable (`onTap: null`) | Zero boxes not tappable | |
| 82 | Tap the **"Continue →" FilledButton** at the bottom of the ActiveTrackCard (when task has focus ref) | Navigates to `TextDisplayRoute(sefariaRef: focusRef)` | Continue CTA → text viewer | |
| 83 | Tap the **"Continue →" FilledButton** when no task is scheduled | Navigates to `LearningRoute` (Learn tab) | Continue CTA fallback → Learn tab | |
| 84 | In **tutor mode**: observe the "Continue →" button behavior | Button navigates to the text viewer for the talmid's focus ref; there is NO live-mark affordance in the text viewer (executor must verify in TextDisplayRoute that mark-complete is absent/disabled) | Tutor canMarkLiveCompletion = FALSE (product rule) — to be confirmed in TextDisplayRoute test section | |

#### Test-step table — StreakRecoveryBanner (child mode only)

| # | Action on which element | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|---|---|---|---|
| 85 | In **child mode** where streak was just recovered by grace period: observe the banner | Coral-tinted card with shield icon and "Streak recovered! Current streak: N" message is shown below the carousel | Streak recovery banner visible only to child + when `wasRecovered = true` | |
| 86 | When **streak was NOT recovered** (or in adult mode) | Banner is entirely absent (`SizedBox.shrink()`) | Banner suppressed for adults and non-recovered streaks | |

---

### 4. EmptyDashboard (no active tracks, not skipped-onboarding)

**How to reach:** Sign in with a profile that has zero active tracks AND `onboardingSkipStateProvider.skipped = false`.

| # | Action on which element | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|---|---|---|---|
| 87 | Observe the empty-dashboard layout in **adult mode** | Greeting + name heading; book icon circle; "No tracks yet" title; "Add your first track…" prompt text; "Add Track" FilledButton | Adult sees Add Track button | |
| 88 | Tap the **"Add Track" FilledButton** | Navigates to `TrackManagementHubRoute(startAdding: true)` | Adult CTA navigates to track setup | |
| 89 | Observe the empty-dashboard in **child mode** | Greeting + name; book icon; "No tracks yet"; "Ask a grown-up to add a track" message; NO "Add Track" button | Child cannot add own tracks | |
| 90 | Confirm **no track-type label** on the empty screen | None of "Personal" / "Standard" / "Custom" / אישי appear | No track-type label (product rule) | |

---

### 5. SkippedOnboardingCtaBanner (skipped-onboarding empty state)

**How to reach:** During onboarding, tap "Skip for now" (sets `onboarding_skipped = true` in SharedPreferences). Then navigate to Dashboard with zero tracks and an adult profile.

| # | Action on which element | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|---|---|---|---|
| 91 | Observe the banner for **standard skip** (`joinedToTutor = false`) | "Get started" heading; "Add a learning track…" body; "Add a learning track" filled button; "Dismiss" text button | Standard skip variant | |
| 92 | Observe the banner for **tutor-join skip** (`joinedToTutor = true`) | `tutorWelcomeBannerTitle` heading; `tutorWelcomeBannerBody` body; "Add a learning track" filled button | Tutor welcome variant | |
| 93 | Tap the **"Add a learning track" FilledButton** | Navigates to `TrackManagementHubRoute(startAdding: true)` | CTA → track setup | |
| 94 | Tap the **"Dismiss" TextButton** | `clearOnboardingSkipState()` called; SharedPreferences flags removed; `onboardingSkipStateProvider` invalidated; banner disappears and `EmptyDashboard` is shown instead | Dismiss clears banner permanently | |
| 95 | Confirm this banner is **never shown to child profiles** (or tutored sessions) | `isChildMode` and `isTutoredSession` both gate the banner off | T3.gating: suppress Add Track CTA in tutored session | |

---

### 6. State Verification Matrix

For every screen in this cluster, the executor must verify the following variants. This table specifies the exact preconditions and what to observe.

| Variant | How to reach | What to assert |
|---|---|---|
| **Loading state** | On a fresh install or after clearing app data, launch app; observe Dashboard before initial data arrives | `CircularProgressIndicator` visible; task count bubbles show "…" not 0; no crash |
| **Error state (AppErrorView)** | Hard to trigger manually — executor should note if app enters error state and confirm the "Retry" button in `AppErrorView` re-fires `dashboardActiveTracksStreamProvider.refresh()` | Retry button visible and functional |
| **Initial sync not complete** | First launch; `initialSyncCompleteProvider = false`; task counts show "…" | "…" in bubbles instead of numbers; "All caught up" card NOT shown prematurely |
| **Offline (cloud-born)** | Cloud account; airplane mode on | Offline banner visible; Dashboard still renders with cached local data; all taps work (Scheduler, TextDisplay navigate) |
| **Adult mode** | Sign in with adult profile | No ⭐ points counter; no ChildPointsRewardsTabCard; no StreakRecoveryBanner |
| **Child mode** | Switch to child profile | Points counter in ProgressTierCounterRow; ChildPointsRewardsTabCard present; StreakRecoveryBanner potentially visible |
| **Tutor mode** | Enter talmid's shell via Profile Switcher + PIN | Amber tutor bar visible; full bottom nav visible; no live-mark in TextDisplay |
| **Parent mode** | Adult enters child profile; then enters parent mode via PIN | Emerald child-view banner visible; bottom nav ABSENT |
| **Hebrew/RTL** | Enable Hebrew Terms in Settings | Chazara labels use Hebrew script (חזרה etc.); layout mirrors correctly for RTL; greeting chip + date use Hebrew formatting |
| **Dark mode** | Device dark mode | All cards and banners adapt to dark theme; no hardcoded white backgrounds blowing out |
| **No tracks** | Profile with zero active tracks | EmptyDashboard or SkippedOnboardingCtaBanner shown; no crash on nil track list |
| **All caught up** | Profile where all task counts = 0 and sync complete | DashboardAllCaughtUpCard shown; DashboardLevelPointsCard absent |

---

### 7. Product Rules Asserted in This Cluster

| Rule | Where to check |
|---|---|
| No track-type label ("Personal"/"Standard"/"Custom"/אישי) | Dashboard heading, ActiveTrackCard curriculum name chip, EmptyDashboard, stats card — none of these strings must appear |
| Chazara UI only when track has chazaraEnabled | Chazara bubble in DashboardLevelPointsCard; chazara CompactMissionCard; chazara column in TrackStatGrid — all absent when no track has chazara stages |
| Adults have no points/gamification | ProgressTierCounterRow `showPoints: false`; ChildPointsRewardsTabCard absent; points bubble stays 0; StreakRecoveryBanner absent |
| Tutor canMarkLiveCompletion = FALSE | After entering talmid's AppShell, navigate into a TextDisplayRoute via "Continue" or a stat-box tap — executor must confirm no mark-complete affordance is visible or enabled |
| Persistent context banner at top | Tutor amber bar OR child-view emerald banner must be visible at the top of every tab in the respective mode |
| Account switching needs no sign-out | Profile switch via ProfileSwitcherSheet immediately loads new profile's Dashboard; no sign-in screen appears |
| Bulk/lifetime sentinel completions not in streak/recent activity | Not directly visible on Dashboard — streak count must not increment for bulk-mark operations |

### 8. Session Fixes to Regression-Confirm

| Fix | How to confirm in this cluster |
|---|---|
| Route guards never lock / hang navigation | Tap all four bottom-nav tabs rapidly; switch profiles; exit tutor mode; exit parent mode — none should freeze or produce blank screens |
| Account-merge "discard local" no longer crashes | Trigger from Settings; after completion, Dashboard must load normally with no crash |
| Tutor entry on malformed/revoked grant shows snackbar, not crash | Revoke a grant server-side, then tap the talmid row in ProfileSwitcherSheet — expect error snackbar, not crash |
| Magic-link / deep-link handling does not crash on malformed links | Send a malformed deep link intent via ADB (`adb shell am start -d "learningtracker://invalid"`) — Dashboard must still load, no crash |
| Scope-selection Save disabled for empty subset | Not directly on Dashboard — covered in Settings cluster; confirm Settings tab is reachable from Dashboard without hang |


# Section 4 — Tracks + Add/Edit-Track Wizard

---

## 4.1  TrackManagementHubScreen  (`/track-management-hub`)

### How to reach
Adult or child profile → Dashboard → "Manage Tracks" (or deep-link with `?startAdding=true`). Can also be navigated to via the `TrackManagementHub` auto_route.

### Preconditions & variants
| Variant | How to reach |
|---|---|
| **Empty state** | Profile with zero active tracks |
| **Populated state** | Profile with ≥ 1 active track |
| **startAdding=true deep link** | Navigate via URL / route param |
| **Back-navigation from onboarding** | After completing onboarding wizard |

### Test steps

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 1 | Observe AppBar leading | Back arrow (`Icons.arrow_back`) | Visible; tapping pops to caller or navigates to LearningRoute when stack is empty | Route-guard fix — hub must never strand user |
| 2 | Tap back arrow | AppBar leading `IconButton` | If stack can pop: previous screen shown. If no stack: Learning tab shown. | SESSION FIX: Route guards never lock / hang navigation |
| 3 | Observe AppBar title | "Manage Tracks" text | Title visible in `brandBlueDeep`, `headlineSmall w800`; NOT "Personal Tracks" or any track-type label | PRODUCT RULE: No track-type label anywhere |
| 4 | Observe FAB (populated state) | `FloatingActionButton.extended` labelled "Add Track" | FAB is present with `+` icon and label; `backgroundColor = brandBlue` | FAB absent in empty state |
| 5 | Tap FAB | FAB | Wizard (`AddTrackFlow`) replaces body inline; AppBar disappears; step-counter header appears | (wizard flow — see §4.5) |
| 6 | Observe track list | `ListView` of `LearningTrackCard` items | Each card shows: curriculum label (via `CurriculumLabel.curriculum`), coloured progress bar, `%` reading, chevron; NO "Personal"/"Standard"/"Custom" label anywhere | PRODUCT RULE: No track-type label |
| 7 | Observe progress bar on card (chazara-enabled track) | `LinearProgressIndicator` + label | Label reads e.g. "Completion (with חזרה)" only when `trackHasChazara = true` | PRODUCT RULE: Chazara UI only when enabled |
| 8 | Observe progress bar on card (learn-only track) | Label above bar | Label reads "Track progress", NOT any chazara term | PRODUCT RULE: No chazara refs on learn-only track |
| 9 | Tap a track card | `LearningTrackCard.onTap` | Navigates to `TrackDetailRoute` passing the `CurriculumTrack` object | |
| 10 | Long-press a track card | `LearningTrackCard.onLongPress` | Delete dialog opens with title `deleteTrackArchiveTitle` | |
| 11 | In delete dialog — tap Cancel | `TextButton` (l10n `actionCancel`) | Dialog dismisses; track list unchanged | |
| 12 | In delete dialog — tap Archive | `TextButton` (l10n `deleteTrackArchive`) | Dialog returns `'archive'`; `dao.deleteTrackAndData` called; track removed from list | |
| 13 | In delete dialog — tap Delete (wipe) | `FilledButton` (l10n `deleteTrackWipe`, error colour) | Dialog returns `'wipe'`; `dao.purgeHistory` called; track removed from list; completion history gone | |
| 14 | Tap system Back from populated state | Android back gesture / button | Same as step 2 (pop or go to Learning) | SESSION FIX: Route guards |
| 15 | Observe **empty state** | `_buildEmptyState` | Illustration icon + "No tracks yet" headline + descriptive text + "Add your first track" `FilledButton.icon` shown; no FAB | |
| 16 | Tap "Add your first track" in empty state | `FilledButton.icon` (l10n `addYourFirstTrack`) | Wizard (`AddTrackFlow`) launches inline | |
| 17 | Complete wizard successfully | Wizard `onComplete` | `_addingTrack = false`; SnackBar shows `trackCreated(result.label)`; list now shows new track | |
| 18 | Open wizard via `?startAdding=true` | Route param | Wizard is shown immediately without tapping FAB; `_addingTrack = true` from constructor | |
| 19 | Observe in dark mode | Full screen | Background `surfaceF5`, card whites, text colours all adapt correctly | Dark mode variant |
| 20 | Observe in Hebrew/RTL | Full screen | AppBar title right-aligned; cards mirrored; curriculum name in Hebrew | RTL variant |
| 21 | Observe loading state | While `activeTracksProvider` resolves | `CircularProgressIndicator` centred; FAB absent | Loading state |
| 22 | Observe error state | Simulate DB error | "Error: …" text centred | Error state |

### States
- **Loading**: spinner shown, FAB hidden.
- **Empty**: empty-state widget, FilledButton to add.
- **Populated**: track list with FAB.
- **Wizard active**: inline wizard replaces body.
- **Delete dialog open**: modal dialog.

---

## 4.2  TrackManagementBody widget (Child-mode hub / Parent-mode pushed route)

### How to reach
- **Child-mode** (tab root): logged-in as CHILD profile → Tracks tab (no back button).
- **Parent-mode** (pushed): adult profile managing a child → "Tracks" item pushed onto stack (back button present).

### Test steps

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 1 | Observe AppBar in child-mode | No leading widget | Back arrow absent (`showBackButton = false`) | |
| 2 | Observe AppBar in parent-mode | `IconButton` `Icons.arrow_back_ios_new_rounded` | Back arrow present; tapping calls `context.maybePop()` | |
| 3 | Tap back (parent-mode) | Back arrow | Returns to previous parent-management screen | |
| 4 | Observe track cards (same as Hub §4.1 steps 6–8) | `LearningTrackCard` | No track-type labels; chazara label conditional | PRODUCT RULE |
| 5 | Tap track card | `LearningTrackCard.onTap` | Pushes `TrackDetailRoute` | |
| 6 | Long-press track card | `onLongPress` | Delete dialog opens | |
| 7 | Delete dialog — Cancel, Archive, Wipe | As §4.1 steps 11–13 | Same outcomes; note: for known `CurriculumId`, Archive calls `curriculumActivationService.deactivate` | |
| 8 | Attempt archive on last active curriculum | Archive button | SnackBar: `cannotDeactivateLastCurriculum` + detail; track NOT removed | Special error path |
| 9 | FAB — tap (populated) | `FloatingActionButton.extended` | Wizard opens inline | |
| 10 | Empty state — "Add track" button | `FilledButton.icon` (l10n `addTrack`) | Wizard opens inline | |
| 11 | Error state retry button | `AppErrorView.onRetry` | `ref.refresh(activeTracksProvider)` re-triggers provider | Error state |
| 12 | Wizard completes | `onComplete` | SnackBar `trackCreated(result.label)` shown; list reloads | |
| 13 | Observe in tutor mode | AppBar etc. | Tutor can see the list in read-only; track additions blocked at service layer (see §4.5 tutor check) | PRODUCT RULE: Tutor canMarkLiveCompletion = FALSE |
| 14 | Observe loading / error / populated | All three states | Spinner / AppErrorView / list respectively | |

---

## 4.3  TrackDetailScreen  (`TrackDetailRoute`)

### How to reach
Tap any `LearningTrackCard` from Hub or Body.

### Test steps

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 1 | Observe AppBar | Back arrow (auto) + title = curriculum label | Back arrow present; title is `curriculumLabelText()` (NOT "Personal/Standard/Custom") | PRODUCT RULE: No track-type label |
| 2 | Tap AppBar back arrow | Navigation | Returns to track list | |
| 3 | Observe `TrackInfoCard` | Info card at top of list | Rows: Started date, Goal date (if deadline goal), Required pace, Actual pace, Elapsed/Remaining | |
| 4 | Observe Hebrew calendar toggle effect | Dates in `TrackInfoCard` | When `useHebrewCalendar = true`: dates shown in Hebrew calendar format | Hebrew date variant |
| 5 | Observe header card (non-program track) | `_buildHeaderCard` | Shows dual-progress: "Track progress: X%" and "Lifetime: Y%"; progress bar visible with curriculum colour | |
| 6 | Observe header card — chazara label (chazara track) | Row above progress bar | Label = `carouselCompletion(chazaraTerm)` e.g. "Completion (with חזרה)" | PRODUCT RULE: Chazara UI only when enabled |
| 7 | Observe header card — chazara label (learn-only track) | Row above progress bar | Label = `trackProgressLabel` (e.g. "Track progress"), NO chazara reference | PRODUCT RULE: No chazara refs on learn-only track |
| 8 | Observe header card for program-enrolled track | `_buildHeaderCard` | Progress bar section (`!hasProgramEnrollment` block) hidden; only dual-progress text shown | |
| 9 | Observe `_configRow` rows | Goal / Items remaining / Est. finish | Present only when values exist; Est. finish hidden for deadline goals (avoiding duplication) | |
| 10 | Observe actions card — non-program track | `_buildActionsCard` | Three tiles: "Mark Previously Learned" (outlined, blue), "Reorder Content" (blue), "Edit Track" (blue), "Delete Track" (error colour) | |
| 11 | Observe actions card — program-enrolled track | `_buildActionsCard` | "Mark Previously Learned" and "Reorder Content" tiles absent; only "Edit Track" and "Delete Track" present | |
| 12 | Tap "Mark Previously Learned" | `ListTile` key=`trackDetail.bulkPriorTile` | `BulkMarkScreen` pushed via `MaterialPageRoute`; scoped to track's scope constraints | SESSION FIX: Bulk/lifetime uses sentinel date; must NOT appear in streak/recent activity |
| 13 | Tap "Reorder Content" | `ListTile` | `TrackLearningOrderScreen` pushed via `MaterialPageRoute` | |
| 14 | Tap "Edit Track" | `ListTile` | `EditTrackScreen` pushed via `MaterialPageRoute` | |
| 15 | Tap "Delete Track" | `ListTile` (error colour) | Delete dialog opens | |
| 16 | Delete dialog — Cancel | `TextButton` | Dialog dismissed; track list unchanged | |
| 17 | Delete dialog — Archive | `TextButton` | Dialog `'archive'`; `dao.deleteTrackAndData` called; pop back to hub; track gone | |
| 18 | Delete dialog — Wipe | `FilledButton` (error colour) | Dialog `'wipe'`; `dao.purgeHistory` then `deleteTrackAndData`; pop to hub; history wiped | |
| 19 | Tap system Back | Back gesture | Returns to track list | |
| 20 | Observe loading state (before providers resolve) | Providers loading | Dual-progress shows "…"; pace rows show "—" | Loading state |
| 21 | Observe in tutor mode | "Edit Track" tile | Tapping opens EditTrackScreen; Save button shows tutor-restricted SnackBar if `canEditGoals || canEditStages` is false | PRODUCT RULE: Tutor canMarkLiveCompletion=FALSE |
| 22 | Observe adult profile | Header card | No points / gamification UI visible anywhere | PRODUCT RULE: Adults have no points/gamification |
| 23 | Observe in dark mode | Full screen | White cards retain shape; colours invert correctly | |

---

## 4.4  EditTrackScreen  (MaterialPageRoute from TrackDetail)

### How to reach
TrackDetail → "Edit Track" tile.

### Preconditions
- Track must exist in the active profile.
- Tutor permission `canEditGoals && canEditStages` gates Save button.

### Test steps

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 1 | Observe screen while loading | `_loading = true` | AppBar "Edit Track" + centered `CircularProgressIndicator`; no editable fields | Loading state |
| 2 | Observe AppBar (loaded) | Title + action area | Title "Edit Track" (`trackEditTitle`); Save `TextButton` OR saving spinner | |
| 3 | Tap system Back | Back gesture | Returns to `TrackDetailScreen` without saving | |
| 4 | Observe **Track Name** section | `TextField` in `_SectionCard` | Pre-filled with `goal.description` or curriculum label; `TrimLeadingSpaceFormatter` prevents leading spaces | |
| 5 | Clear name field | TextField delete | Field empties; trimming applied on each keystroke | Validation |
| 6 | Type a very long name (>200 chars) | TextField | No crash; text truncated visually; system keyboard visible | Validation |
| 7 | Observe **Goal** section (pace goal) | `_SectionCard` goal | Goal-type chip shows locked "Pace · per_day/per_week"; stepper (−/+) and per-day/per-week chips visible | |
| 8 | Tap pace `−` stepper when paceValue=1 | `_StepperButton` (disabled) | Button greyed; paceValue stays at 1 | Validation — no negative pace |
| 9 | Tap pace `−` stepper when paceValue>1 | `_StepperButton` | paceValue decrements; display updates | |
| 10 | Tap pace `+` stepper | `_StepperButton` | paceValue increments | |
| 11 | Tap "per day" chip | `_PeriodChip` | Chip selected (blue), "per week" chip deselected | |
| 12 | Tap "per week" chip | `_PeriodChip` | Chip selected; "per day" deselected | |
| 13 | Observe **Goal** section (deadline goal) | `InkWell` container with date | Date shown; edit icon visible | |
| 14 | Tap deadline date picker | `InkWell` → `showLearningAppDatePicker` | System/themed date picker opens with initialDate = current deadline | |
| 15 | Pick a future date in deadline picker | Date picker | `_targetDate` updates; formatted label shown | |
| 16 | Dismiss date picker (back/cancel) | Picker cancel | `_targetDate` unchanged | |
| 17 | Observe **Study Days** section (non-program track) | 7 `StudyDayCard` rows | All 7 days listed Sun–Shabbos; each has a Switch | |
| 18 | Toggle a study-day switch | `Switch` in `StudyDayCard` | Switch animates; internal `_editedStudyDays` updates | |
| 19 | Observe **Review** section (chazara-enabled track) | `_SectionCard` review | Summary text + "Change Review" `OutlinedButton` visible | PRODUCT RULE: Review section hidden on learn-only track |
| 20 | Observe **Review** section absent (learn-only track) | Missing `_SectionCard` | Section entirely absent; no chazara references | PRODUCT RULE |
| 21 | Tap "Change Review" | `OutlinedButton` | `ChazaraInlineSetup` bottom sheet slides up (DraggableScrollableSheet, 75% initial) | |
| 22 | In bottom sheet — select a preset | `ReviewPresetCard` | Preset highlighted blue; summary changes | |
| 23 | In bottom sheet — tap "Custom Cycle" | Custom card InkWell | Custom mode activated; chip editors shown | |
| 24 | In bottom sheet — tap `−` on a chip | `TinyCircleButton` remove | Delay decrements (floor=1) | |
| 25 | In bottom sheet — tap `+` on a chip | `TinyCircleButton` add | Delay increments | |
| 26 | In bottom sheet — tap "Remove" on a chip (when >1 round) | TextButton remove | Round removed; count chip decrements | |
| 27 | In bottom sheet — tap "Add new" chip (up to 5) | `AddRoundChip` | New round added; "Add new" disappears at 5 rounds | |
| 28 | In bottom sheet — tap "Add new" when 5 rounds exist | Chip hidden | `AddRoundChip` absent at max | |
| 29 | In bottom sheet — tap Continue | `FilledButton` | Sheet closes; `_pendingChazarah` set; review summary updates | |
| 30 | Drag bottom sheet down | Swipe down | Sheet collapses to 50%; further down dismisses | |
| 31 | Observe **Clear Overdue** section (program track, overdue) | `OutlinedButton.icon` | Button red/active; label `trackEditClearOverdueButton` | |
| 32 | Observe Clear Overdue disabled (no overdue) | Same button | Button greyed/disabled | |
| 33 | Tap Clear Overdue (active) | `OutlinedButton.icon` | Confirmation dialog opens | |
| 34 | Clear Overdue dialog — Cancel | `TextButton` | Dialog dismissed; overdue unchanged | |
| 35 | Clear Overdue dialog — Confirm | `FilledButton` (red) | Tracking start re-anchored to today; Firestore sync attempt; overdue flag cleared; button becomes disabled | |
| 36 | Observe **Program Locked** banner (program track) | `_buildProgramLockedBanner` | Lock icon + `trackEditProgramLocked` text shown; Study Days and Review sections absent | |
| 37 | Tap Save action (loaded, can save) | `TextButton` "Save" | Save confirmation dialog opens | |
| 38 | Save dialog — Cancel | `TextButton` | Dialog dismissed; no save | |
| 39 | Save dialog — Save/Confirm | `FilledButton` | Save spinner replaces Save button; `trackEditService.editTrack` called; on success pop screen | |
| 40 | Tap Save while saving | Spinner visible | No duplicate tap possible (spinner replaces button) | |
| 41 | Save in tutor mode with `canSave=false` | Save TextButton (shows) | Tapping shows SnackBar `tutorPermissionDenied`; no save | PRODUCT RULE: Tutor write blocked |
| 42 | Observe in dark mode | Full screen | Section cards use white with shadow; text/chip colours adapt | |
| 43 | Observe in Hebrew/RTL | Full screen | All chips, stepper layout mirrored; Hebrew curriculum name pre-filled in name field | |

---

## 4.5  AddTrackFlow wizard (embedded in hub or onboarding)

### How to reach
- Hub empty state → "Add your first track"
- Hub populated → FAB "Add Track"
- Onboarding flow (not this cluster's primary focus but same code)

### Wizard-level elements (present on all steps)

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 1 | Observe step counter header (≥2 steps) | "STEP X OF Y" label + `%` + `LinearProgressIndicator` | Present; progress bar fills as steps advance | |
| 2 | Tap system Back on step 1 (no data) | `PopScope` | `_handleExit()` → since no curriculum selected yet, exits immediately without dialog | |
| 3 | Tap system Back on step 1 (curriculum selected) | `PopScope` | "Exit Track Setup?" dialog appears | |
| 4 | Exit dialog — tap "Exit" | `FilledButton` (blue) | `_clearSavedState()` called; `onCancel()` fires; hub body shown | |
| 5 | Exit dialog — tap "Cancel" | `TextButton` (grey) | Dialog dismisses; wizard stays on current step | |
| 6 | Tap system Back on step 2+ | Back gesture | Previous step shown (page slide animation 300 ms) | |
| 7 | Rapid double-back during animation | Multiple back taps | `_AnimatingWithPending` queues; only one extra step back; no crash | |
| 8 | Kill app mid-wizard (step >1) | Resume app | `_tryResumeState` restores curriculum + scope + program + study days + label from SharedPreferences | State persistence |
| 9 | Tutor opens wizard | Add Track FAB | If `TutorWriteException` is thrown on finish, SnackBar `tutorPermissionDenied` shown; wizard does NOT navigate away | PRODUCT RULE: Tutor canMarkLiveCompletion=FALSE |

---

### Step 1 — CurriculumPickerStep

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 10 | Observe heading | Title text | "Select a Curriculum" (or "What would you like to learn?" in onboarding); subtitle "Choose one curriculum for this track." | |
| 11 | Scroll list | `ListView` | 9 curriculum tiles visible (5 featured first); each tile has coloured icon, curriculum name (`CurriculumLabel.curriculum`), Hebrew subtitle (when not Hebrew mode), chevron | |
| 12 | Verify no track-type labels | All tiles | No "Personal", "Standard", "Custom", "אישי" visible | PRODUCT RULE: No track-type label |
| 13 | Tap a curriculum tile (no existing track) | `_CurriculumTile InkWell` | Step advances to Program (if exists) or Scope; no warning shown | |
| 14 | Tap a curriculum that already has an active track | `_CurriculumTile InkWell` | Step advances; warning icon (orange `Icons.warning_amber_rounded`) visible on that tile | Replace-warning |
| 15 | Tap the warning icon (not the tile body) | `IconButton` warning | SnackBar `addTrackCurriculumReplaceWarning` shown for 4 s | |
| 16 | Observe in Hebrew terms mode | All curriculum names | Hebrew script shown; English subtitle hidden | |

---

### Step 2 — ProgramSelectionStep (curricula with programs only)

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 17 | Observe heading | Title + subtitle | "Join a Program?" + "Follow a global study calendar, or learn at your own pace." | |
| 18 | Observe featured program card | `_FeaturedProgramCard` | First program shown with large card, icon, name, description, "Starts: [name]" row | |
| 19 | Tap featured program card | `InkWell` | Program selected; step advances (scope/study-days auto-filled) | |
| 20 | Observe compact program cards (if >1 program) | `_CompactProgramCard` | Alternating peach/blue accent; each tappable | |
| 21 | Tap a compact program card | `InkWell` | That program selected; step advances | |
| 22 | Tap "Self-paced (no program)" | `FilledButton.icon` (peach/gold) | `onSelected(null, null, null)` → step advances without program; Scope step shown | |
| 23 | Curriculum has no programs (auto-skip) | Step not shown | `_didAutoSkip` prevents display; step silently advances | |

---

### Step 3 — ScopeStepContent (self-paced only)

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 24 | Observe top-level header | Title + curriculum chip | `selfPacedScopeTitle`; curriculum badge shown | |
| 25 | Observe "Learn All" hero card | `ScopeTopLevelView` hero | Gradient blue card; tap → `onComplete(null)` (full curriculum) | |
| 26 | Tap "Learn All" | Hero card `InkWell` | Step advances; `scopeSelections = null` (full scope) | SESSION FIX: Scope-selection Save disabled for empty subset |
| 27 | Observe scope item tiles | `ScopeLevelTile` list | Each tile: icon, title, child count + level label + section description; checkbox + optional drill arrow | |
| 28 | Tap a scope tile checkbox | `onCheck` | Tile selected (badge "Selected"); Continue button shows count and activates | |
| 29 | Verify Continue disabled with zero selections | `FilledButton` (disabled) | Button shows "Select at least one"; not tappable | SESSION FIX: Save disabled for empty subset |
| 30 | Tap Continue with ≥1 selection | `FilledButton` active | Step advances with `scopeSelections` set | |
| 31 | Tap "Select All" button | `OutlinedButton.icon` (select_all) | All visible tiles selected; button changes to "Deselect All" | |
| 32 | Tap "Deselect All" | `OutlinedButton.icon` (remove_done) | All selections cleared; Continue re-disabled | |
| 33 | Tap drill arrow on a tile (canDrillDeeper=true) | `onDrill` on `ScopeLevelTile` | Drill-down view shown with breadcrumb trail; back arrow appears | |
| 34 | In drill-down: tap Back arrow | `Icons.arrow_back` button | One breadcrumb level popped; parent list shown | |
| 35 | In drill-down: tap curriculum breadcrumb label | `InkWell` on curriculum root | All breadcrumbs cleared; returns to top-level view | |
| 36 | In drill-down: tap intermediate breadcrumb | `InkWell` on crumb | Breadcrumbs trimmed to that level | |
| 37 | In drill-down: tap a selection chip's `×` | `Chip.onDeleted` | That selection removed; count in Continue button decrements | |
| 38 | Auto-skip on empty content | Content provider returns empty | `onComplete(null)` fires automatically; spinner shown briefly | |
| 39 | Observe in Hebrew terms mode | All level/item names | Hebrew names shown for items and breadcrumbs | |

---

### Step 4 — StudyDaysEditable / StudyDaysReadOnly

#### Self-paced (StudyDaysEditable)

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 40 | Observe screen | Title + 7 cards | `studyDaysTitle`, `studyDaysSubtitle`; 7 `StudyDayCard` rows: Sun Mon Tue Wed Thu Fri Shabbos | |
| 41 | Verify all days default ON | All 7 Switches | All switches green/active by default (incl. Shabbos) | |
| 42 | Toggle Shabbos switch off | `Switch` (day 6) | Switch grey; card border style = dashed (Shabbos styling); day stored as `'review'` | |
| 43 | Toggle Shabbos back on | `Switch` | Switch green; day stored as `'study'` | |
| 44 | Toggle any weekday off | `Switch` | Switches to grey; day set `'review'` | |
| 45 | Tap Continue | `FilledButton` (full-width, height 52, radius 28) | Step advances with current `_days` map | |

#### Program-enrolled (StudyDaysReadOnly)

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 46 | Observe screen | Title + program name text + list | `studyDaysTitle`; italic `studyDaysSetByProgram(programName)` text; 7 rows each with check icon (read-only) | |
| 47 | Tap Continue | `FilledButton` | Step advances; all days sent as default `kDefaultStudyDays` | |

---

### Step 5 — ChazaraInlineSetup (self-paced or open-chazara program)

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 48 | Observe header | Title + subtitle | Correct `headerTitle` / `headerSubtitle` for self-paced vs program variant | |
| 49 | Observe preset cards (4) | `ReviewPresetCard` grid | "Learn Only" / "1 day" / "1 + 7 days" (default selected) / "1 + 7 + 30 days"; selected card has blue gradient | |
| 50 | Tap "Learn Only" preset | Card InkWell | Card selected (gradient); "1 day", etc. deselected | |
| 51 | Tap "1 day" preset | Card InkWell | That card selected; Custom panel shows 1 chip | |
| 52 | Tap "1 + 7 days" preset | Card InkWell | Default preset; 2 chips shown in custom panel | |
| 53 | Tap "1 + 7 + 30 days" preset | Card InkWell | 3 chips shown | |
| 54 | Tap "Custom Cycle" card | `InkWell` border highlights blue | Custom mode activated (`_selectedPresetIndex = -1`); preset cards deselected | |
| 55 | In custom mode — tap `+` on a chip | `TinyCircleButton` | Delay increments by 1 | |
| 56 | In custom mode — tap `−` on a chip | `TinyCircleButton` | Delay decrements (floor=1) | |
| 57 | In custom mode — tap "Remove" (>1 chip) | TextButton remove | Chip removed; sessions count badge decrements | |
| 58 | In custom mode — tap "Remove" (1 chip) | Remove button | Remove button absent when only 1 chip (guarded by `onRemove` condition) | |
| 59 | In custom mode — tap "Add new" (4 rounds) | `AddRoundChip` | Round added (doubles last delay) | |
| 60 | In custom mode — tap "Add new" (5 rounds) | No chip | "Add new" chip hidden at max 5 | |
| 61 | Tap Continue with "Learn Only" | `FilledButton` | `WizardChoice.noReview` emitted; step advances | |
| 62 | Tap Continue with preset selected | `FilledButton` | `WizardChoice.custom` with matching `customRounds` delays emitted | |

### Step 5b — ChazaraReadOnlyStep (program with defined chazara)

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 63 | Observe heading | Title + program name | `reviewScheduleTitle`; italic `reviewScheduleSetByProgram(programName)` | |
| 64 | Observe lock banner | Container (blue) | Lock icon + `reviewScheduleFixedHint` shown | |
| 65 | Observe stage list | `ListView.separated` | Each stage card: numbered avatar, normalised stage name, delay label (e.g. "After 1 day"), lock icon | |
| 66 | Observe empty stages | `ListView` empty | `reviewScheduleNoStages` text shown centred | |
| 67 | Tap Continue | `FilledButton` | `onComplete(null)` fires; step advances | |

---

### Step 6 — SelfPacedGoalStep (pace/deadline)

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 68 | Observe screen | Title + subtitle | `goalPaceOrDeadlineTitle`, `goalPaceOrDeadlineSubtitle` | |
| 69 | Observe PaceGoalCard (active by default) | `PaceGoalCard` | Blue border; stepper, per-day/per-week `SegmentedButton`, pace value, projected-finish italic text | |
| 70 | Tap `−` pace icon (value=1) | `IconButton remove_circle_outline` | Value stays at 1 (not negative); `_mode='pace'` preserved | |
| 71 | Tap `+` pace icon | `IconButton add_circle_outline` | Value increments; projected-finish updates | |
| 72 | Tap "per day" segment | `SegmentedButton` | `_paceUnit = 'per_day'`; projected finish recalculates | |
| 73 | Tap "per week" segment | `SegmentedButton` | `_paceUnit = 'per_week'` | |
| 74 | Observe granularity segment (curriculum with choice e.g. Bavli) | Optional `SegmentedButton` | Coarse/fine level options (e.g. Masechta / Daf) shown | |
| 75 | Tap coarse granularity segment | Segment | `_paceGranularity` updates; pace description line changes | |
| 76 | Observe DeadlineGoalCard (inactive/blurred) | `BlurInactiveGoalOption` | Blurred card + hint text "Tap to use Deadline" overlay | |
| 77 | Tap blurred deadline card | `BlurInactiveGoalOption InkWell` | `_activateDeadlineMode()` called; date picker opens immediately | |
| 78 | Pick a future date in date picker | Date picker | `_deadline` set; mode = `'deadline'`; deadline card activates; pace card blurs | |
| 79 | In deadline mode — observe deadline card | `DeadlineGoalCard` | Active border; date label shown; `X items/day across Y study days` pace estimate text | |
| 80 | In deadline mode — tap date label row | `InkWell` | Date picker opens again | |
| 81 | Pick today's date as deadline | Date picker | No study days in window → error text `addTrackGoalDeadlineNoStudyDaysInWindow` in red | |
| 82 | While scope loading in deadline mode | Spinner in header | Continue button disabled; `addTrackGoalDeadlinePaceLineLoading` text shown | SESSION FIX: Continue disabled while loading (F-M2) |
| 83 | Tap Continue (pace mode) | `FilledButton` | `GoalEntity` with `goalType='pace'`, `paceValue`, `pacePeriod`, description emitted | |
| 84 | Tap Continue (deadline mode, valid) | `FilledButton` (enabled) | `GoalEntity` with `goalType='deadline'`, targetDate, derived pace emitted | |
| 85 | Tap Continue (deadline mode, no date) | `FilledButton` | SnackBar `goalPickDeadlineFirst`; no advance | |
| 86 | Hebrew calendar toggle ON | Dates in projected-finish | Hebrew date format shown in projected-finish label | Hebrew variant |

---

### Step 7/8 (self-paced) — SelfPacedPriorProgressStep

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 87 | Observe screen | Title + subtitle | `priorLearningTitle`, `priorLearningSubtitle`, `priorLearningChooseSections(curriculumName)` | |
| 88 | Observe `HierarchySelectionPanel` | Embedded panel | Full hierarchy browser for the curriculum, constrained to scope if set | |
| 89 | Tap "Skip" in panel | `onSkip` callback | `_finishFlow()` called with no prior selections; track created | |
| 90 | Select some sections and tap "Mark Completed" | `onMarkCompleted` | `_finishFlow(priorSelections: selections)` called; bulk prior completions applied async with sentinel date | SESSION FIX: Bulk/lifetime uses sentinel date — not in streak/recent activity |
| 91 | Verify confirm-replace dialog if existing track | Dialog | If curriculum already has active track, "Replace?" dialog appears before `createTrack` | |
| 92 | Replace dialog — Cancel | `TextButton` Cancel | Track NOT replaced; wizard stays | |
| 93 | Replace dialog — Replace (red) | `FilledButton` | `createTrack` proceeds; existing track configuration overwritten | |

---

### Step 7/8 (program) — StartingPositionStep (content mode)

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 94 | Observe screen | Title + hint texts | `startingPositionTitle`, `startingPositionWhereAreYou(programName)`, leaf-level label e.g. "Select the Daf you are currently up to." | |
| 95 | Observe container list | `ListView.builder` | Containers (Sedarim/Masechtot etc.) listed as `ListTile` with chevron | |
| 96 | Tap a container | `ListTile.onTap` | Container list replaced by leaf list; back row with container name shown | |
| 97 | Back arrow in leaf view | `IconButton Icons.arrow_back` | Returns to container list; `_selectedContainer = null` | |
| 98 | Tap a leaf item | `ListTile.onTap` | Item selected; `Icons.check_circle` shown; selected-item card appears at top with ×-button | |
| 99 | Tap × on selected-item card | `IconButton Icons.close` | Selection cleared; leaf list reappears | |
| 100 | Observe "Start Here" button with selection | `FilledButton` active | Button enabled; tapping calls `onComplete(_selectedLeaf.sefariaRef)` → wizard finishes | |
| 101 | Observe "Start Here" button without selection | `FilledButton` disabled | `onPressed = null`; button greyed | |

### Step 7/8 (program) — StartingPositionCalendarMode

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 102 | Observe screen | Title + hint | `startingPositionTitle`, `startingPositionHint` | |
| 103 | Observe date card | White card | Calendar icon, weekday+date label, calendar-entry reference text + pill | |
| 104 | Observe offset badge | Red pill top-right | Shows "Today" / "Day -N" / "Day +N" | |
| 105 | Tap left chevron (offset > min) | `_OffsetButton` left | `_offsetDays -= 1`; calendar entry re-fetched; date label updates | PRODUCT RULE: back-date constrained to [today-30, today] |
| 106 | Tap left chevron at minimum offset | Chevron invisible | Left chevron hidden (Visibility.visible=false at min); no tap possible | SESSION FIX: B2 back-date constraint |
| 107 | Tap right chevron (offset < 0) | `_OffsetButton` right | `_offsetDays += 1`; calendar entry re-fetched | |
| 108 | Tap right chevron at offset=0 (today) | Chevron invisible | Right chevron hidden; no future dates | PRODUCT RULE: no future dates (B2) |
| 109 | Tap "Use Today" tonal button | `FilledButton.tonal` | `_offsetDays = 0`; calendar entry refreshed | |
| 110 | Observe loading spinner in card | `CircularProgressIndicator` | Tiny 16×16 spinner shown during calendar entry fetch | |
| 111 | Observe error state in card | No calendar entry | Error text "No local calendar entry found for this date." shown in error colour | Offline/error variant |
| 112 | Observe "Start Here" button (canStart=true) | `FilledButton` | Button enabled; tapping encodes `'offset:N|ref:todayRef'` and finishes wizard | |
| 113 | Observe "Start Here" button (loading/no entry) | `FilledButton` (disabled) | Button greyed; `canStart = false` | |

---

## 4.6  LearningOrderScreen  (`LearningOrderScreen` route — whole-curriculum)

### How to reach
Settings → (standalone route) OR programmatically. Distinct from per-track reorder.

### Test steps

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 114 | Observe AppBar | Title + optional Reset icon | Title = `"{Curriculum} Order"`; Reset `Icons.refresh` present when `!isRestricted` | |
| 115 | Observe loading state | Provider not resolved | `CircularProgressIndicator` centred | Loading state |
| 116 | Observe error state | Provider error | `AppErrorView` with Retry button | Error state |
| 117 | Tap Retry in error state | `AppErrorView.onRetry` | `ref.refresh(learningOrderProvider)` fired | |
| 118 | Observe empty state | No items | "No items to order" text shown | |
| 119 | Observe restricted banner (child-controlled) | Banner container | "Controlled by parent" banner shown; drag handles absent; list non-reorderable | |
| 120 | Drag an item (non-restricted) | `ReorderableListView` drag handle | `ReorderConfirmDialog` shown if overdue items exist | Reorder-amnesty guard |
| 121 | Reorder confirm dialog — cancel | TextButton | Drag cancelled; order unchanged | |
| 122 | Reorder confirm dialog — confirm | FilledButton | Item moved; `saveLearningOrderUseCaseProvider` persisted async | |
| 123 | Tap Reset icon | `IconButton Icons.refresh` | `ResetOrderDialog` shown | |
| 124 | Reset dialog — Cancel | `TextButton` | Dialog closed; order unchanged | |
| 125 | Reset dialog — Reset | `FilledButton` | `repository.resetToDefault` called; `_localOrder = null`; provider invalidated; default order reloaded | |
| 126 | Tap system Back | Back arrow | Returns to previous screen | |

---

## 4.7  TrackLearningOrderScreen  (per-track "Reorder Content" from TrackDetail)

### How to reach
TrackDetail → "Reorder Content" tile → MaterialPageRoute.

### Test steps

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 127 | Observe AppBar | Title + Reset icon | Title = `"{Curriculum} • Reorder"`; Reset `Icons.refresh` always present | |
| 128 | Observe loading state | `isLoading` | `CircularProgressIndicator` centred | Loading state |
| 129 | Observe Sedarim section header | `_buildSectionHeader` | Header label respects Hebrew Terms toggle | Hebrew-terms variant |
| 130 | Observe Masechtos section header | Second header | Present only when `CurriculumLabels.hasReorderableLevel2(curriculumId)` | |
| 131 | Drag a Seder item | `ReorderableListView` drag | `ReorderConfirmDialog` shown if overdue; on confirm seder moved; `_persistSedarim` called | Reorder-amnesty guard |
| 132 | Drag a Masechta item | `ReorderableListView` drag | `ReorderConfirmDialog`; on confirm masechta moved; `_persistMasechtos` called | |
| 133 | Reorder confirm — cancel | TextButton | Drag reverted | |
| 134 | Reorder confirm — confirm | FilledButton | Persistence async; provider invalidated; masechtos re-fetched (sequence guard) | Race-condition guard |
| 135 | Rapid dual-reorder (Sedarim then Masechtos quickly) | Two quick drags | `_sedarimSaveSeq` guards prevent stale overwrite; final state correct | |
| 136 | Tap Reset | `IconButton Icons.refresh` | `ResetOrderDialog` opens | |
| 137 | Reset — Cancel | `TextButton` | No change | |
| 138 | Reset — Reset | `FilledButton` | `resetToDefault(trackId)` called; both local lists set to null; providers invalidated | |
| 139 | Tap Back | AppBar back | Returns to `TrackDetailScreen` | |

---

## 4.8  Delete-track flow (shared dialog — assert same behavior from Hub and Detail)

| # | Action | Element | Expected result | Rule / Fix |
|---|---|---|---|---|
| 140 | Open from Hub (long-press) | Long-press card | Dialog opens with correct title/body | |
| 141 | Open from Detail | "Delete Track" tile | Same dialog | |
| 142 | Dismiss dialog by tapping barrier | Tap outside | Dialog dismissed (barrierDismissible default = true) | |
| 143 | After wipe — navigate back to hub | System back | Track gone from list; no crash | Route-guard fix |

---

## 4.9  Cross-cutting / Product-rule assertions

| # | Assertion | Where to check | Expected | Rule |
|---|---|---|---|---|
| 144 | No "Personal" / "Standard" / "Custom" / "אישי" label | All cards, tiles, headers in this cluster | Absent | PRODUCT RULE: No track-type label |
| 145 | Chazara UI absent on learn-only track | TrackManagementBody card, TrackDetailScreen header, EditTrackScreen Review section | No chazara text, no review bar | PRODUCT RULE: Chazara only when enabled |
| 146 | Tutor cannot save edits when permissions blocked | EditTrackScreen Save button | SnackBar `tutorPermissionDenied` only; no DB write | PRODUCT RULE: Tutor canMarkLiveCompletion=FALSE |
| 147 | No points/gamification on adult profile | TrackDetailScreen, Hub | No star/points widgets | PRODUCT RULE: Adults no gamification |
| 148 | Scope-selection Save disabled for empty subset | ScopeTopLevelView, ScopeHierarchyView Continue button | Disabled when `selections.isEmpty` | SESSION FIX: Scope Save disabled for empty subset |
| 149 | Bulk/prior sentinel date not in streak | After SelfPacedPriorProgressStep completes | Activity feed and streak do NOT show bulk-marked items | SESSION FIX: Bulk/lifetime uses sentinel date |
| 150 | Program start date back-date limit ≤ 30 days | StartingPositionCalendarMode left chevron | Cannot go past day −30; left chevron hidden at limit | PRODUCT RULE: start date [today-30, today] |
| 151 | No future start dates | StartingPositionCalendarMode right chevron | Right chevron hidden at today | PRODUCT RULE |
| 152 | Replace-track confirmation dialog fires before createTrack | Re-adding an existing curriculum | "Replace?" dialog shown; pressing Cancel does NOT create track | Track-replace guard |
| 153 | Route guard never hangs | Back navigation from empty stack on hub | Navigates to LearningRoute; no freeze | SESSION FIX: Route guards |
| 154 | After track deletion — detail screen popped | Delete from detail | `context.router.pop()` called; returns to hub; hub list updated | |
| 155 | Hebrew terms toggle: chazara term | ChazaraInlineSetup, EditTrackScreen review section | Term shown as "חזרה" or "Chazara" per toggle, not per UI locale | Hebrew-terms rule |
| 156 | Dual-progress metrics match Dashboard | TrackDetailScreen header | "Track progress" % and "Lifetime" % numerically match Dashboard active-track card | W5-B consistency |

---

## 4.10  State matrix

| Screen | Loading | Empty | Error | Offline | Populated | Tutor | Child | Adult | Dark | RTL |
|---|---|---|---|---|---|---|---|---|---|---|
| TrackManagementHubScreen | Spinner | Empty-state widget + FilledButton | "Error: …" text | List from local DB | Track list + FAB | Read only add/edit blocked | N/A | Full access | Tested | Tested |
| TrackManagementBody | Spinner | Empty-state + FilledButton | AppErrorView + Retry | Local DB | Track list + FAB | Archive last-curriculum error | Tab root, no back | Back button | Tested | Tested |
| TrackDetailScreen | "…" in metrics | N/A | "—" in rows | Metrics from DB | Full metrics | Save blocked on edit | N/A | Full | Tested | Tested |
| EditTrackScreen | Full-screen spinner | N/A | N/A | Works offline | Editable form | Save blocked (SnackBar) | N/A | Full | Tested | Tested |
| AddTrackFlow wizard | Per-step spinners | Auto-skip on empty content | Error snackbar + Retry | Works offline | Full wizard | Write exception SnackBar | N/A | Full | Tested | Tested |
| LearningOrderScreen | Spinner | "No items to order" | AppErrorView | Works offline | Reorderable list | N/A | Restricted (parent-controlled banner) | Full | Tested | Tested |
| TrackLearningOrderScreen | Spinner | (implicit) | N/A | Works offline | Two reorderable sections | N/A | N/A | Full | Tested | Tested |




# Cluster: Learning + Content Browsing (Reader)

> CRITICAL PRODUCT RULES referenced throughout this section:
> - **RULE-TRACK-LABEL**: No track-type label ("Personal"/"Standard"/"Custom"/אישי) appears anywhere.
> - **RULE-CHAZARA**: Chazara UI renders ONLY when the track has `chazaraEnabled`; tracks without it show no chazara references.
> - **RULE-TUTOR-BAR**: `canMarkLiveCompletion = FALSE` in a tutored session — the live "Mark Complete" button is disabled/absent and shows tutor-specific styling and tooltip. The domain-layer `MarkLiveCompletionUseCase` also throws `TutorWriteForbiddenException` if somehow called.
> - **RULE-SWITCHER**: Persistent profile/role switcher at the TOP of every context.
> - **RULE-ADULTS-NO-POINTS**: Adults have no points/gamification.
> - **RULE-SENTINEL**: Bulk/lifetime marking uses a sentinel date — does not appear in streak/recent activity.

---

## 1. LearningRoute — `/learn`

### How to Reach
App launch → tap **Learn** tab in bottom navigation bar (second tab from left). Requires an authenticated account with at least one profile selected.

### Pre-conditions for Variants
- **With tracks**: at least one active curriculum track for the active profile.
- **No tracks (empty state)**: active profile has no tracks enrolled.
- **Child mode**: selected profile has `profileMode == ProfileMode.child`.
- **Adult mode**: selected profile has `profileMode == ProfileMode.adult`.
- **Tutor session**: `activeTutoredProfileSelectionProvider` is non-null (tutor has passed the TutorPinEntryGate for a talmid).
- **Tutor with `canEditStages = false`**: the grant's `TutorPermissions.canEditStages` is false.
- **Tutor with `canEditStages = true`**: grant allows stage editing.

### Test Steps

| # | Action | Element | Expected Result | Rule / Fix to Confirm | Pass/Fail/Notes |
|---|--------|---------|-----------------|----------------------|-----------------|
| 1 | Observe screen on arrival | Top-level switcher | Profile/role switcher is visible at the top of the shell (not inside the screen body). | RULE-SWITCHER | |
| 2 | Observe loading state | Entire body | `CircularProgressIndicator` (centered) shown while `dashboardActiveCurriculaStreamProvider` is loading. | — | |
| 3 | Observe error state | Body when provider errors | `AppErrorView` widget shown with error message and a **Retry** button. | Session fix: route guards never hang navigation | |
| 4 | Tap **Retry** on error view | Retry button in `AppErrorView` | Re-calls `ref.refresh(dashboardActiveCurriculaStreamProvider)`; loading spinner appears then data or error again. | Session fix: route guards never hang | |
| 5 | Observe empty state — child mode (no tracks, `isChildMode = true`) | Body when `activeCurricula.isEmpty` and child | `EmptyState` widget shows icon + `noActiveTracks` label + `askGrownUpToAddTrack` subtitle. **No** "Add Track" button is rendered. | RULE-TUTOR-BAR (child cannot add track) | |
| 6 | Observe empty state — adult/owner mode (no tracks, not tutor) | Body when `activeCurricula.isEmpty` and adult, not tutored | `EmptyState` shows `noActiveTracks` + `addTrackToStart` subtitle + **Add Track** `FilledButton.icon`. | — | |
| 7 | Tap **Add Track** button | `FilledButton` in empty state | Navigates to `TrackManagementHubRoute(startAdding: true)`. | — | |
| 8 | Observe empty state — tutor session, `canEditStages = false` | Body when `activeCurricula.isEmpty`, `isTutoredSession = true`, `canEditStages = false` | `EmptyState` shows `askGrownUpToAddTrack` subtitle; **no Add Track button**. | RULE-TUTOR-BAR: tutor without `canEditStages` cannot add track | |
| 9 | Observe empty state — tutor session, `canEditStages = true` | Body when `activeCurricula.isEmpty`, `isTutoredSession = true`, `canEditStages = true` | **Add Track** button is visible (tutor with permission may add). | — | |
| 10 | Observe normal data state — pull-to-refresh | Pull down on `ListView` | `RefreshIndicator` triggers; `allDailyTasksProvider`, `dashboardActiveCurriculaStreamProvider`, `dashboardStreakProvider` all invalidated; updated data reloads. | — | |
| 11 | Observe `_StreakHeroCard` — labels | Streak card | Shows localised `learnStreakCurrentAchievement` label (ALL CAPS), `learnStreakDayStreak(currentStreak)` as large number, `learnStreakPersonalBest(maxStreak)` pill, and `learnStreakKeepItUp` badge. No emoji in text (ARB comment confirms RTL safety). | RULE-ADULTS-NO-POINTS: streak card still appears for adults (streak is not gamification points). | |
| 12 | Observe `_StreakHeroCard` — Hebrew/RTL | Same card with `@@locale = he` or device language set to Hebrew | All text in card is RTL-aligned; no text overflow; `learnStreakKeepItUp` tag wraps correctly. | Bilingual/RTL rule | |
| 13 | Tap anywhere on the `_StreakHeroCard` | `GestureDetector` over entire card | Navigates to `RecentActivityRoute` (`/progress/recent`). | — | |
| 14 | Observe **Daily Tasks** section header | Row with title + task count button | `dailyTasksTitle` ("Daily Tasks") shown in large bold text. Adjacent `TextButton` shows `itemsCount(tasks.length)` label (e.g. "3 Items"). | — | |
| 15 | Tap task count `TextButton` ("N Items") | `TextButton` next to "Daily Tasks" heading | Navigates to `SchedulerRoute` (`/scheduler`). | — | |
| 16 | Observe Daily Tasks loading state | Tasks section when `allDailyTasksProvider` is loading | `CircularProgressIndicator` centred inside a `Padding` widget. | — | |
| 17 | Observe Daily Tasks error state | Tasks section when provider errors | `AppErrorView` shown with **Retry** button; tap Retry calls `ref.invalidate(allDailyTasksProvider)`. | Session fix: route guards never hang | |
| 18 | Observe Daily Tasks empty state (all done) | Tasks section when `tasks.isEmpty` | `_InfoCard` with `Icons.celebration_outlined`, `tasksAllCaughtUp` title, `tasksNoTasksRemainingToday` subtitle. | — | |
| 19 | Observe up to 5 task cards | Tasks section with ≥1 tasks | At most 5 `_LearnTaskCard` rows rendered (`.take(5)`); each shows stage label chip, task title (breadcrumb minus leading seder segment), track label row. | — | |
| 20 | Observe overdue task card | `_LearnTaskCard` where `task.isOverdue = true` | Card shows red "OVERDUE" pill chip + `Icons.priority_high_rounded` icon in red. | — | |
| 21 | Observe task card stage label — Hebrew/RTL | Stage chip on `_LearnTaskCard` | Stage name resolved via `domainTermLabels.resolveStoredStageName`; if Hebrew Terms toggle ON, Hebrew name displayed. | Bilingual/RTL rule | |
| 22 | Verify NO track-type label on any task card | All `_LearnTaskCard` instances | No text reading "Personal", "Standard", "Custom", or אישי appears on any card (stage chip only shows stage name, not track type). | RULE-TRACK-LABEL | |
| 23 | Tap a `_LearnTaskCard` | `InkWell` on entire card | Navigates to `TextDisplayRoute(sefariaRef: task.contentItemSefariaRef)`. | — | |
| 24 | Observe **Browse** section | `_BrowseSection` | "Browse" header (hardcoded, font 36 bold) and one `_CurriculumBrowseCard` per `CurriculumId` value: chumash, nach, tanach, mishnayos, bavli, yerushalmi, mishnehTorah, mishnaBerurah, mussar (9 cards total). | — | |
| 25 | Observe curriculum browse card label | Each `_CurriculumBrowseCard` | `CurriculumLabel.curriculum(curriculum)` used — localised curriculum name shown. No raw `displayNameEn` or `displayNameHe` accessed directly in this widget. | RULE-TRACK-LABEL (no track-type text); layering Rule 5 | |
| 26 | Tap each `_CurriculumBrowseCard` (repeat 9×) | `InkWell` per card | Navigates to `ContentHierarchyRoute(curriculumId: curriculum.storageKey)`. | — | |
| 27 | Verify streak card absent in adult mode (no gamification conflict) | Streak hero card | RULE-ADULTS-NO-POINTS: streak card is rendered in both adult and child modes (it tracks a learning metric, not points). Confirm streak card is present in adult mode but NO points/coin icon appears on it. | RULE-ADULTS-NO-POINTS | |
| 28 | Switch to dark theme | Theme toggle in Settings | Streak hero card uses hard-coded gradient colours (unchanged); cards use `Colors.white` background in both themes — verify no white-on-white text. Executor should note visual result. | — | |
| 29 | Verify back button | System back | With bottom nav active, system back exits the app or returns to previous nav entry; does NOT lock navigation. | Session fix: route guards never lock/hang navigation | |

### States to Verify

| State | How to Reach | Variants |
|-------|-------------|---------|
| Loading | Fresh app launch before data arrives | Any profile type |
| Empty (no tracks) | Profile with zero enrolled tracks | Child (no Add Track button), Adult (Add Track button visible), Tutor (depends on `canEditStages`) |
| Error | Disable network + clear local cache so stream emits error | Any profile |
| Offline with data | Airplane mode after first load | Data still shows (offline-first) |
| Data — 0 tasks | All today's tasks completed | `_InfoCard` "All caught up" message |
| Data — ≤5 tasks | Normal day | Task cards shown |
| Data — >5 tasks | Many tasks outstanding | Only 5 shown; full list via "N Items" button |
| Child mode | Select a child profile | No "Add Track" button in empty state; streak card visible |
| Adult mode | Select an adult profile | Add Track button shown; RULE-ADULTS-NO-POINTS: no points on card |
| Tutor session | Activate tutored profile via TutorPinEntryGate | Depends on `canEditStages` |
| Hebrew/RTL | Device or app locale set to Hebrew | RTL text alignment in streak card and task chips |
| Dark mode | Toggle dark theme in Settings | No colour regressions |

---

## 2. CurriculumListRoute — `/browse`

### How to Reach
From any screen that has a "Browse Content" entry point, or directly navigate to `/browse`. In practice reached from `_CurriculumBrowseCard` on the Learning screen OR from the side navigation. Requires an authenticated session.

### Test Steps

| # | Action | Element | Expected Result | Rule / Fix to Confirm | Pass/Fail/Notes |
|---|--------|---------|-----------------|----------------------|-----------------|
| 30 | Observe AppBar | Title | "Browse Content" title (hard-coded) in bold. | — | |
| 31 | Tap search icon in AppBar actions | `IconButton(Icons.search)` with tooltip "Search curricula" | `onPressed` is `() {}` — currently a no-op placeholder. Confirm nothing crashes and no navigation occurs. Note as UNKNOWN BEHAVIOUR for executor to probe carefully. | — | |
| 32 | Observe search bar visual element | Static `Container` with `Icons.search` + "Search curricula..." text | This is a non-interactive display element (no `GestureDetector`, no `TextField`). Tapping it should do nothing. Executor: confirm no tap handler fires. | — | |
| 33 | Observe "CURRICULA" section header | Static `Text` | "CURRICULA" header with letter-spacing. | — | |
| 34 | Observe each `_CurriculumCard` — loading state | Card while `curriculumContentProvider` is loading | Mini spinner (`CircularProgressIndicator(strokeWidth: 2)`) shown in top-right area of card instead of item counts. | — | |
| 35 | Observe each `_CurriculumCard` — zero completion | Card where `dashboardCompletionPercentageProvider` returns 0 | "New" badge shown in top-right (amber chip); no progress bar. | — | |
| 36 | Observe each `_CurriculumCard` — non-zero completion | Card where percentage > 0 | "X% Done" badge with `Icons.check_circle` + `LinearProgressIndicator` progress bar. | — | |
| 37 | Observe curriculum card labels | Each `_CurriculumCard` | `CurriculumLabel.curriculum(curriculum)` used for primary label. When Hebrew Terms toggle OFF, Hebrew name shown as subtitle. When ON, only localised name shown. | Bilingual/RTL rule | |
| 38 | Verify NO track-type label on any card | All 9 `_CurriculumCard` items | No "Personal", "Standard", "Custom", or אישי text anywhere on cards. | RULE-TRACK-LABEL | |
| 39 | Tap each `_CurriculumCard` (9 times) | `GestureDetector` per card | Each navigates to `ContentHierarchyRoute(curriculumId: curriculum.storageKey)`. | — | |
| 40 | Observe "RECENT ACTIVITY" section | `_RecentActivityPlaceholder` | Static info card: gold history icon, "Start learning to see activity here", "Your recent completions will appear below". No interactive elements. | — | |
| 41 | Observe Hebrew/RTL | Entire screen with Hebrew locale | Card titles use RTL text direction for Hebrew; English subtitle aligns LTR. No overlap or overflow. | Bilingual/RTL rule | |
| 42 | System back | Device back button | Pops route; returns to previous screen without hang. | Session fix: route guards never lock/hang | |

### States to Verify

| State | How to Reach |
|-------|-------------|
| Cards loading | Fresh load, slow network |
| Cards with "New" badge | Profile with no completions for a curriculum |
| Cards with progress | Profile with some completions |
| Hebrew locale | Toggle device language to Hebrew |
| Dark mode | Settings dark theme toggle |

---

## 3. ContentHierarchyRoute — `/curriculum/:curriculumId/browse`

### How to Reach
Tap any curriculum card on CurriculumList screen, or tap any `_CurriculumBrowseCard` on the Learning screen. Deep-links also valid via `/curriculum/mishnayos/browse` (etc.).

### Pre-conditions
- `curriculumId` must be a valid `CurriculumId.storageKey` value; invalid IDs show the "Unknown Curriculum" error state.
- Internet connectivity needed for initial content load; offline uses cached data.

### Test Steps

| # | Action | Element | Expected Result | Rule / Fix to Confirm | Pass/Fail/Notes |
|---|--------|---------|-----------------|----------------------|-----------------|
| 43 | Observe AppBar | "Browse Content" title, leading back arrow | Back button and title visible. | — | |
| 44 | Tap AppBar back arrow — at root level (navigation stack empty) | Leading `IconButton(Icons.arrow_back)` | Calls `context.router.maybePop()` — navigates back to calling screen. Does NOT crash. | Session fix: route guards never lock/hang | |
| 45 | Tap AppBar back arrow — when drilled down (stack non-empty) | Same back button | Calls `_navigateUp()` — pops one level off the `_navigationStack` (state update, no full route pop). | — | |
| 46 | Observe curriculum chip (root level) | Top pill badge | Shows `CurriculumLabel.curriculum(curriculum)` in curriculum-colour. | Bilingual/RTL rule | |
| 47 | Observe breadcrumb when drilled down | `BreadcrumbNavigation` widget | Breadcrumb shows ancestor segments separated by `Icons.chevron_right`. Each ancestor segment (not the last) is a tappable `InkWell` with underline. Last segment is bold and non-tappable. | — | |
| 48 | Tap a non-last breadcrumb segment | Underlined `_BreadcrumbItem` `InkWell` | `_navigateToLevel(i)` is called; navigation stack is trimmed to that depth; item list updates to show items at that level. | — | |
| 49 | Observe content list — loading state | `Expanded` body | `CircularProgressIndicator` centred. | — | |
| 50 | Observe content list — empty state | Body when items list is empty | Icon `Icons.inbox_outlined` + "No content available" text centred. | — | |
| 51 | Observe content list — error state | Body when provider errors | Error icon + `errorLoadingContent(error.toString())` text. No retry button in this path (source confirmed). Executor: note whether a retry affordance is available. | UNKNOWN BEHAVIOUR — no retry in error branch; probe carefully | |
| 52 | Observe container items (non-leaf) | `ContentItemTile` for containers | Folder icon (`Icons.folder`), Hebrew/English name via `CurriculumLabel.item`, trailing `Icons.chevron_right`. No completion badge shown (review count badge hidden for containers). | — | |
| 53 | Tap a container `ContentItemTile` | `onTap` callback | `_handleItemTap` called; since item is not leaf and not at max browse depth, `_drillDown(item)` is called; navigation stack grows by one; list updates to next level. | — | |
| 54 | Tap an item at `maxBrowseDepth` (chapter-level ref) | `ContentItemTile` at max depth | `_isChapterLevelRef` returns true; navigates to `TextDisplayRoute(sefariaRef: item.sefariaRef)`. | — | |
| 55 | Tap a leaf `ContentItemTile` | `onTap` on leaf item | `item.isLeaf = true`; navigates to `TextDisplayRoute(sefariaRef: item.sefariaRef)`. | — | |
| 56 | Observe leaf item completion icon | Leading icon of leaf `ContentItemTile` | `Icons.check_circle` in primary colour when `completionCount > 0`; `Icons.radio_button_unchecked` in outline colour when 0. | — | |
| 57 | Observe review count badge | Trailing `ReviewCountBadge` on leaf tile | Shows "Nx" badge when count ≥ 1; completely absent (no "0x") when count = 0. | AC-6 rule | |
| 58 | Long-press a leaf tile with completions (count > 0) | `onLongPress` on `ContentItemTile` | `_showStageBreakdown` called; `_StageBreakdownSheet` bottom-sheet opens. | — | |
| 59 | Long-press a leaf tile with count = 0 | `onLongPress` on `ContentItemTile` | No bottom-sheet opens (`onLongPress` is null when count = 0). | — | |
| 60 | Long-press a container tile | `onLongPress` on container `ContentItemTile` | No bottom-sheet opens (`onLongPress` is null for containers). | — | |
| 61 | Observe `_StageBreakdownSheet` content | Bottom-sheet | Drag handle at top, `CurriculumLabel.item` title, "Review History" subtitle, `ItemReviewBreakdown` with "StageName: N" entries per stage. | — | |
| 62 | Observe `_StageBreakdownSheet` — loading | While `itemStageBreakdownProvider` is loading | `CircularProgressIndicator` centred. | — | |
| 63 | Observe `_StageBreakdownSheet` — empty (no completions) | When `breakdown.isEmpty` | "No completions yet." text. | — | |
| 64 | Observe `_StageBreakdownSheet` — error | When provider errors | `AppErrorView` with a **Retry** button; tap Retry calls `ref.refresh(itemStageBreakdownProvider(...))`. | — | |
| 65 | Observe `_StageBreakdownSheet` — stage names with Hebrew Terms ON | Toggle Hebrew Terms | Stage names resolved via `terms.resolveStoredStageName` — Hebrew name shown. | Bilingual/RTL rule | |
| 66 | Dismiss bottom-sheet via drag or tap outside | Sheet drag gesture or tap outside | Sheet dismisses; returns to hierarchy view. | — | |
| 67 | Verify NO track-type label anywhere | All tiles and breadcrumbs | No "Personal"/"Standard"/"Custom"/אישי text. | RULE-TRACK-LABEL | |
| 68 | Verify item names in Hebrew locale | All `ContentItemTile` headings | `CurriculumLabel.item` renders Hebrew name when `domainTermLabels.isHebrew = true`. | Bilingual/RTL rule | |
| 69 | Verify breadcrumb Hebrew names | Breadcrumb segments when drilled | `CurriculumLabelRenderer.renderBreadcrumb` with `hebrewNamesPerSegment` from `ContentTree.containerFor` — ancestor names shown in Hebrew when toggle is on. | Bilingual/RTL rule | |
| 70 | Invalid curriculumId deep-link | Navigate to `/curriculum/bogus/browse` | "Unknown Curriculum" error screen shown with `Icons.error_outline` and text. | Session fix: route guards never hang | |
| 71 | System back at root level | Device back | `maybePop()` called; screen pops safely. | Session fix | |
| 72 | System back when drilled down | Device back | UNKNOWN BEHAVIOUR — device back calls `maybePop()` on the router, not `_navigateUp()`. This will pop the route entirely rather than popping a hierarchy level. Executor: confirm and note. | — | |

### States to Verify

| State | How to Reach | Variants |
|-------|-------------|---------|
| Loading | First launch on curriculum | — |
| Empty | Edge-case empty curriculum (unlikely on production) | — |
| Error | Disable network, clear cache | Error message visible |
| Offline with cached data | Airplane mode after prior load | Data shows from `ContentTree`/`filteredContentProvider` |
| Root level (no drill) | First open | Breadcrumb hidden |
| Drilled 1–4 levels | Tap containers | Breadcrumb grows |
| Hebrew locale | Device set to Hebrew | Names in Hebrew, RTL layout |
| Dark mode | Settings toggle | Card/tile colours adapt |

---

## 4. ContentSearchRoute — `/curriculum/:curriculumId/search`

### How to Reach
Route is registered at `/curriculum/:curriculumId/search`. The UI path from the app is not directly exposed via a prominent button in the reviewed source — it is a registered route that callers push with `ContentSearchRoute`. Note: `CurriculumListScreen` has a non-functional search icon placeholder (step 31). Executor should navigate via deep-link or by identifying in-app entry points.

### Test Steps

| # | Action | Element | Expected Result | Rule / Fix to Confirm | Pass/Fail/Notes |
|---|--------|---------|-----------------|----------------------|-----------------|
| 73 | Observe AppBar on load | `TextField` in AppBar with `autofocus: true` | Keyboard opens automatically; `hintText` shows "Search [CurriculumName]…" using `curriculumLabelText`. | — | |
| 74 | Observe initial empty body | Body before any query | Centred text `searchHintEnterTerm` ("Enter a search term above"). | — | |
| 75 | Type a valid search query | `TextField` in AppBar | After 300 ms debounce, `contentSearchProvider` is watched; loading spinner appears. | — | |
| 76 | Type a query that returns results | `TextField` | `ListView.builder` rendered with `ContentItemTile` per result. | — | |
| 77 | Tap a leaf result item | `ContentItemTile.onTap` (item.isLeaf = true) | Navigates to `TextDisplayRoute(sefariaRef: item.sefariaRef)`. | — | |
| 78 | Tap a non-leaf result item | `ContentItemTile.onTap` (item.isLeaf = false) | `onTap` is `() {}` (no-op for non-leaf in search). Executor: confirm tap does not crash and does not navigate. | UNKNOWN BEHAVIOUR | |
| 79 | Type a query that returns no results | `TextField` with obscure string | `noResultsForQuery(query)` text shown centred. | — | |
| 80 | Observe loading state during debounce | Body while provider loading | `CircularProgressIndicator` centred. | — | |
| 81 | Observe error state | Simulate search provider error | `Icons.error_outline` + `errorSearchError(error.toString())` centred. | — | |
| 82 | Clear search field (delete all text) | Keyboard delete | `_debouncedQuery` becomes empty; body reverts to `searchHintEnterTerm` hint. No crash. | — | |
| 83 | Type leading spaces | Input with spaces before text | `TrimLeadingSpaceFormatter` applied — leading spaces stripped, query cleaned. | — | |
| 84 | Type Hebrew characters | Hebrew keyboard input | Hebrew text accepted; search executes; results (if any) shown. RTL alignment in `TextField` if locale is Hebrew. | Bilingual/RTL rule | |
| 85 | Verify invalid curriculum deep-link | `/curriculum/bogus/search` | "Search" AppBar title shown; body shows `errorUnknownCurriculum("bogus")`. | Session fix: route guards never hang | |
| 86 | Observe long-press on result tile with completions | `ContentItemTile.onLongPress` | If `count > 0` and `item.isLeaf`, stage breakdown bottom-sheet opens (same as hierarchy screen). | — | |
| 87 | System back | Device back button | Pops route; keyboard dismissed; returns to calling screen. | Session fix: route guards never hang | |

### States to Verify

| State | How to Reach |
|-------|-------------|
| Initial / empty query | Screen first opens |
| Searching | Query entered, within debounce |
| Results | Valid query |
| No results | Query that returns nothing |
| Error | Network error during search |
| Hebrew input | Hebrew keyboard |

---

## 5. TextDisplayRoute — `/text/:sefariaRef`

### How to Reach
- Tap a task card on Learning screen.
- Tap a leaf content item in ContentHierarchyRoute.
- Tap a leaf item in ContentSearchRoute.
- Auto-navigated from `_CompletionSection` after marking complete when a next task exists.

### Pre-conditions for Variants
- **Tutor session**: `activeTutoredProfileSelectionProvider` is non-null.
- **Own session (adult or child)**: tutor selection is null.
- **Task in daily schedule**: the `sefariaRef` appears in `allDailyTasksProvider`.
- **Text not in schedule**: `sefariaRef` has no matching task in `allDailyTasksProvider`.
- **Text not cached / offline**: `textContent` returns null.

### Test Steps

| # | Action | Element | Expected Result | Rule / Fix to Confirm | Pass/Fail/Notes |
|---|--------|---------|-----------------|----------------------|-----------------|
| 88 | Observe AppBar — title | `Text(chainTitle)` | Full breadcrumb chain shown (e.g. "Berachos › Chapter 1" or Hebrew equivalent), up to 3 lines with ellipsis overflow. | Bilingual/RTL rule | |
| 89 | Observe AppBar — back button | `IconButton(Icons.arrow_back)` | Back button present; taps call `context.router.maybePop()`. | Session fix: route guards never hang | |
| 90 | Observe AppBar — Previous navigation button | `IconButton(Icons.chevron_left)` with tooltip "Previous" | When `adj?.prev != null`, button is enabled; tap calls `context.router.replace(TextDisplayRoute(sefariaRef: adj!.prev!))`. | — | |
| 91 | Tap Previous button when prev exists | Enabled previous `IconButton` | Replaces current route with previous sibling text. | — | |
| 92 | Observe Previous button disabled state | Same button when `adj?.prev == null` | Button `onPressed` is null (disabled). No crash on tap attempt. | — | |
| 93 | Observe AppBar — Next navigation button | `IconButton(Icons.chevron_right)` with tooltip "Next" | When `adj?.next != null`, button is enabled; tap calls `context.router.replace(TextDisplayRoute(sefariaRef: adj!.next!))`. | — | |
| 94 | Tap Next button when next exists | Enabled next `IconButton` | Replaces current route with next sibling text. | — | |
| 95 | Observe Next button disabled state | Same button when `adj?.next == null` | Button `onPressed` is null (disabled). | — | |
| 96 | Observe loading state | Body while `textContentProvider` loading | Spinner + `loadingText` ("Loading text...") centred. | — | |
| 97 | Observe offline/unavailable text state | Body when `textContent == null` (not cached, no network) | `_OfflineMessage`: `Icons.cloud_off` icon, "Text not available" title, "Check your internet connection and try again." message. | Session fix: offline-first — all works offline once cached | |
| 98 | Observe error state | Body when provider throws | `_ErrorView`: error icon, "Failed to load text" title, `error.toString()` detail. | — | |
| 99 | Observe text content — Hebrew section | `_ReaderSectionCard` with red label | "Hebrew Text" label (top-left positioned pill, red). Hebrew text body in `AppTextStyles.hebrewBodyLarge`, font size = `26 * fontSize.multiplier`, RTL direction. | Bilingual/RTL rule | |
| 100 | Observe text content — English section | `_ReaderSectionCard` with blue label | "English Translation" label (top-right positioned pill, blue). English text LTR, font size = `16 * fontSize.multiplier`. | Bilingual/RTL rule | |
| 101 | Observe nikud display — Hebrew text with nikud enabled (default) | `_NumberedSegmentColumn` for Hebrew | Hebrew text shows with nikud (vowel marks). | — | |
| 102 | Observe nikud display — nikud toggled off via settings | Same column after disabling nikud in Settings | `HebrewUtils.stripNikud` applied; vowel marks removed from Hebrew text. | — | |
| 103 | Observe font size change — small | Settings → font size small | Hebrew text font = 26 * 0.85 (~22 pt); English = 16 * 0.85. | — | |
| 104 | Observe font size change — large | Settings → font size large | Hebrew text font = 26 * 1.25 (~32 pt); English = 16 * 1.25. | — | |
| 105 | Observe segment numbers — Hebrew side | `_VerseNumberBadge` in Hebrew column | When multiple segments exist and have numbers, gematriya marker (alef, bet…) shown as a small badge before each segment (RTL: badge on right side of line). | Bilingual/RTL rule | |
| 106 | Observe segment numbers — English side | `_VerseNumberBadge` in English column | Arabic numerals (1, 2…) shown as badge before each English segment. | — | |
| 107 | Observe progress bar | Thin `LinearProgressIndicator` at top of content | Static blue progress bar at 15% fill (placeholder; not dynamic from content position). Executor: note if it ever changes. | UNKNOWN BEHAVIOUR — progress is static 0.15 | |
| 108 | Observe insight chips | Below English text | 0–2 keyword chips (e.g. "Vocabulary: Priests", "Concept: Time") shown as rounded pill chips when matching keywords found in English text. Static heuristic. | — | |
| 109 | Observe `_CompletionSection` — no matching task | When `sefariaRef` not in `allDailyTasksProvider` | Completion section is `SizedBox.shrink()` — nothing shown. | — | |
| 110 | Observe `_CompletionSection` — loading | While `allDailyTasksProvider` loading | Small spinner (20×20) centred in 44 px height box. | — | |
| 111 | Observe `_CompletionSection` — error | When `allDailyTasksProvider` errors | Error icon + `unableToLoadCompletionContext(error.toString())` text. | — | |
| 112 | Observe `_CompletionSection` — own session, task not yet done | `FilledButton` in default state | Blue filled button with `Icons.check_circle_outline_rounded` + `markComplete` label ("Mark complete"). Button is enabled. | — | |
| 113 | Tap "Mark Complete" button — own session, not yet done | `FilledButton.onPressed` | `_saving` set to true (spinner inside button); `MarkLiveCompletionUseCase` called; on success `completionCommittedProvider.notifier.increment()` called; if next task exists, router replaces to that task's text; otherwise `markedComplete` snackbar shown. | RULE-TUTOR-BAR: own session passes through; Session fix: route guards never hang | |
| 114 | Observe "Mark Complete" button after completion — own session | Button after `isDone = true` | Button shows gold background, `Icons.check_circle`, `markCompleteCompletedStage(stageName)` label. Button is disabled. | — | |
| 115 | Tap already-done "Mark Complete" button | Disabled button | `onPressed` is null; nothing happens. | — | |
| 116 | Observe "Mark Complete" button — TUTOR SESSION | `FilledButton` when `_isTutorSession = true` | **CRITICAL RULE-TUTOR-BAR check**: Button has muted amber background/disabled colouring, `Icons.school_rounded` icon, `markCompleteTutorUnavailable` label ("Not available (tutor mode)"), `onPressed = null` (disabled). Tooltip wraps with `tutorCannotMarkLiveCompletion` message. | RULE-TUTOR-BAR: `canMarkLiveCompletion = FALSE` | |
| 117 | Tap disabled tutor "Mark Complete" button | Disabled button | `onPressed` is null; button does NOT fire. | RULE-TUTOR-BAR | |
| 118 | Long-press tutor "Mark Complete" button | Tooltip trigger | Tooltip shows: "Tutors cannot mark live completions". | RULE-TUTOR-BAR | |
| 119 | Verify domain-layer guard fires if somehow invoked | (Code-path test; simulate by calling _handleComplete with tutor session) | `MarkLiveCompletionUseCase.call()` throws `TutorWriteForbiddenException`; caught in `_handleComplete`; `AlertDialog` shown with `tutorWriteForbiddenTitle` + `tutorWriteForbiddenMessage`; single **OK** button dismisses. | RULE-TUTOR-BAR / Session fix: H1 domain guard | |
| 120 | Tap **OK** in `TutorWriteForbiddenException` dialog | `TextButton(l10n.actionOk)` | Dialog dismissed; `_saving` reset to false; returns to screen normally. | Session fix: no double-fire | |
| 121 | Observe "Next daily task" button — when a next task exists | `OutlinedButton.icon` below mark-complete button | Blue outlined button with `Icons.arrow_forward_rounded` + `textReaderNextDailyTask` label visible. | — | |
| 122 | Tap "Next daily task" button | `OutlinedButton.onPressed` | `context.router.replace(TextDisplayRoute(sefariaRef: nextTask.contentItemSefariaRef))` — replaces current screen with next task's text. | — | |
| 123 | Observe no "Next daily task" button — when no further task | Button when `nextTask == null` | Button is absent from the widget tree. | — | |
| 124 | Observe `_CompletionSection` — save in progress (spinner) | During `_saving = true` | Mark-complete button shows `CircularProgressIndicator(strokeWidth: 2)` inside button instead of icon. Button is disabled. | Session fix: no double-fire (guard: `if (_saving) return`) | |
| 125 | Trigger save error | Simulate repository exception | Error snackbar with `couldNotSave(error.toString())` in coral background. `_saving` reset to false. | — | |
| 126 | Child mode — achievement celebration | Mark complete in child mode when milestones unlock | `AchievementUnlockCelebration.showForUnlockedMilestones` shows celebration overlay. Adults do NOT see this celebration. | RULE-ADULTS-NO-POINTS | |
| 127 | Verify NO track-type label anywhere | AppBar title, completion section | No "Personal"/"Standard"/"Custom"/אישי text. | RULE-TRACK-LABEL | |
| 128 | Verify Hebrew title in AppBar — Hebrew locale | AppBar `chainTitle` with Hebrew Terms ON | Breadcrumb chain renders in Hebrew (Sefaria ref rendered via `renderedDisplayForRefProvider`). | Bilingual/RTL rule | |
| 129 | System back | Device back button | `maybePop()` called; returns to calling screen. No hang. | Session fix: route guards never hang | |
| 130 | Navigate to malformed sefariaRef deep-link | `/text/bogus___ref` | `textContentProvider("bogus___ref")` errors or returns null; screen shows `_ErrorView` or `_OfflineMessage` without crash. | Session fix: deep-link handling doesn't crash on malformed links | |

### States to Verify

| State | How to Reach | Variants |
|-------|-------------|---------|
| Loading text | Navigate before cache available | — |
| Offline (not cached) | Airplane mode, text not previously loaded | `_OfflineMessage` |
| Error | Force provider exception | `_ErrorView` |
| No task context | View arbitrary sefariaRef with no matching daily task | No completion section |
| Own session — not done | Daily task, not yet marked | Mark Complete enabled |
| Own session — done | After marking or DB shows complete | Mark Complete shows gold + disabled |
| Tutor session — BARRED | Enter tutored profile context | Mark Complete disabled, tutor styling |
| Child mode milestone | Mark complete when milestone threshold hit | Celebration overlay |
| Hebrew locale | Device/app Hebrew | RTL Hebrew text block, Hebrew breadcrumb |
| Nikud off | Settings > disable nikud | Nikud stripped from Hebrew |
| Font size small/medium/large | Settings > font size | Text sizes scale |
| Dark mode | Settings toggle | Background and card colours adapt |

---

## 6. ContentItemTile Widget

(Tested exhaustively as part of ContentHierarchyRoute steps 52–66 and ContentSearchRoute steps 76–86. Summary of all interactive elements for element count purposes.)

| Element | Steps Covered |
|---------|--------------|
| `onTap` (all tiles) | 53, 54, 55, 77, 78 |
| `onLongPress` (leaf, count > 0) | 58 |
| `onLongPress` absent (container, or leaf with count 0) | 59, 60 |
| `ReviewCountBadge` — shown when count ≥ 1 | 57 |
| `ReviewCountBadge` — hidden when count = 0 | 57 |
| Completion icon (check vs unchecked) | 56 |
| `_StageBreakdownSheet` drag-dismiss | 66 |
| `_StageBreakdownSheet` Retry button | 64 |

---

## 7. HierarchySelectionPanel Widget

### How to Reach
Used embedded in track-setup flows (not in the direct reading/browsing cluster). Included here because it is specified in the cluster assignment.

### Test Steps (Default Mode — with Skip/Confirm buttons)

| # | Action | Element | Expected Result | Rule / Fix to Confirm | Pass/Fail/Notes |
|---|--------|---------|-----------------|----------------------|-----------------|
| 131 | Observe panel without navigation stack | Breadcrumb area | No breadcrumb row shown (only shown when `_navigationStack.isNotEmpty`). | — | |
| 132 | Observe breadcrumb when drilled | Breadcrumb row | Horizontal scroll row: curriculum `TextButton` root, then `Icons.chevron_right` separators, then ancestor segment `TextButton` items (enabled if not last), then last level (disabled). | — | |
| 133 | Tap curriculum label `TextButton` in breadcrumb | Root curriculum button | Calls `clearNavigation()` → `_browserKey.currentState?.clearNavigation()`. Panel jumps back to root. | — | |
| 134 | Tap an ancestor segment button (not last) | Enabled `TextButton` for ancestor | Calls `_browserKey.currentState?.navigateBack()` N times to reach that depth. Panel shows items at that level. | — | |
| 135 | Tap last segment button | Disabled `TextButton` (last level) | `onPressed: null` — no action. | — | |
| 136 | Observe content loading | `Expanded` body while loading | `CircularProgressIndicator` centred. | — | |
| 137 | Observe content error | `Expanded` body on error | `AppErrorView` with **Retry** button; Retry calls `ref.refresh(curriculumContentProvider(...))`. | — | |
| 138 | Tap a checkbox tile to select an item | `ListTile` with `Checkbox` | Checkbox toggles to checked; item added to `_selections`. Selection counter "N selection(s)" appears below browser if `useDefaultTiles = true`. | — | |
| 139 | Tap the same item again to deselect | Same tile | Checkbox unchecks; item removed from `_selections`; counter updates. | — | |
| 140 | Tap a drill-down tile (has `onDrill`) | `ListTile` with `Icons.chevron_right` trailing | `onDrill()` called; navigation drills into next level; breadcrumb grows. | — | |
| 141 | Observe "N selection(s)" counter visibility | Counter text | Only visible when `useDefaultTiles = true` AND `_selections.isNotEmpty`. Hidden when selections empty. | — | |
| 142 | Tap **Skip for now** button | `OutlinedButton` with `skipLabel` or `actionSkipForNow` | `widget.onSkip` callback invoked. | — | |
| 143 | Tap **Next / Confirm** button — selections non-empty | `FilledButton` | Enabled; calls `widget.onConfirmed(Set.of(_selections))`. | — | |
| 144 | Tap **Next / Confirm** button — selections EMPTY | Same button | `onPressed: null` (disabled). No false "saved" toast. | Session fix: Scope-selection Save disabled for empty subset | |
| 145 | Call `navigateBack()` via `GlobalKey` (external caller) | Exposed public API | `_browserKey.currentState?.navigateBack()` pops one hierarchy level. | — | |

---

## Cross-Cutting Checks (apply to ALL screens in this cluster)

| # | Check | Rule / Fix |
|---|-------|-----------|
| C1 | No track-type label ("Personal"/"Standard"/"Custom"/אישי) visible on ANY screen in this cluster | RULE-TRACK-LABEL |
| C2 | In a tutored session: the "Mark Complete" button in `TextDisplayScreen` is disabled with amber tutor styling; tooltip reads `tutorCannotMarkLiveCompletion` | RULE-TUTOR-BAR |
| C3 | In a tutored session: `MarkLiveCompletionUseCase` domain guard throws `TutorWriteForbiddenException` if triggered by any call path bypassing the UI (verify via `_handleComplete` with isTutor = true) | RULE-TUTOR-BAR (H1 fix) |
| C4 | `AlertDialog` for `TutorWriteForbiddenException` shows single-tap OK button; confirm no double-fire of dialog or action | Session fix: Redemption single-tap guard pattern |
| C5 | Tracks without `chazaraEnabled`: verify no chazara icon (`Icons.history_rounded`) or chazara-labelled stage shows in task cards or stage breakdown sheets | RULE-CHAZARA |
| C6 | Tracks WITH `chazaraEnabled`: chazara review tasks appear as `DailyTaskPriority.overdueChazara` / `scheduledChazara` with `Icons.history_rounded` icon | RULE-CHAZARA |
| C7 | Offline mode: LearningScreen loads cached curricula and tasks; ContentHierarchyScreen loads cached content tree; TextDisplayScreen loads cached text — all without crash | Session fix: offline-first |
| C8 | Route navigation never hangs on auth/restore/pin/profile guard transitions into or out of these screens | Session fix: route guards never lock user out |
| C9 | Hebrew locale: all text in this cluster renders RTL-correctly; no overflow; no bidirectional text mixing issues in Hebrew section of TextDisplayScreen | Bilingual/RTL rule |
| C10 | Adults (own profile in adult mode): no points, coins, gamification elements visible on LearningScreen or TextDisplayScreen | RULE-ADULTS-NO-POINTS |
| C11 | Malformed deep-links to `/text/MALFORMED` or `/curriculum/bogus/browse` do not crash the app | Session fix: deep-link handling doesn't crash on malformed links |



# Cluster: Scheduler + Study Days

## Overview and Shared Preconditions

- **Profile types in scope:** CHILD and ADULT only (no "parent" type label anywhere on screen).
- **Modes in scope:** own-learner, adult-management, tutor.
- **Product rule — no track-type label:** The strings "Personal", "Standard", "Custom", "אישי" must never appear on any of these screens.
- **Product rule — chazara gating:** Chazara / review UI (review-only day toggle, review section card, chazara task rows) renders ONLY when the active track for the curriculum has more than one stage (`count > 1` in `_curriculumTrackHasChazaraProvider`). Tracks with a single stage must show no chazara references anywhere, including on `StudyDayConfigScreen`.
- **Product rule — tutor live-mark barred:** `TutorPermissions.canMarkLiveCompletion` is hardwired to `false`; the live "mark complete" button on `TextDisplayScreen` (reached by tapping a task card) must be absent or disabled when viewing as a tutor.
- **Product rule — adults have no points/gamification:** Adult profiles must not see streak, level, or XP on these screens.
- **Session fix — route guards fail-safe:** Navigating to `SchedulerRoute` from any entry point (dashboard mission cards, notification tap, learning screen FAB) must never hang or produce a blank screen.

---

## 1. SchedulerScreen (`SchedulerRoute`)

### Route and Entry Points

| Entry point | Precondition | Section filter set before push |
|---|---|---|
| Dashboard "Today's Focus" mission card tap | At least one active track with a goal; device has tasks due today | `SchedulerTaskSection.today` |
| Dashboard "Review / Chazara" mission card tap | At least one track with chazara enabled AND review tasks exist | `SchedulerTaskSection.review` |
| Dashboard "Overdue" mission card tap | At least one overdue task | `SchedulerTaskSection.overdue` |
| `DashboardLevelPointsCard` bubble taps (overdue, today, review) | same per-section preconditions | Respective section |
| Learning screen FAB / scheduler shortcut | Any state | `SchedulerTaskSection.all` (or whatever last section was set) |
| Notification tap (daily reminder / missed tasks) | Background notification tapped | `SchedulerRoute` via `router.navigate` |
| System Back button from TextDisplay | After opening a task card | Returns to SchedulerScreen |

### States to Verify

| State | How to reach | Expected behaviour |
|---|---|---|
| **Loading** | Open screen immediately after cold start / profile switch | `CircularProgressIndicator` centred in body |
| **Empty (all tasks done or no tasks)** | Complete all tasks, then re-open; or open with a profile that has no active tracks | `EmptyState` widget: icon `celebration_outlined`, title "All caught up! Great work!", subtitle "You have no tasks remaining for today." |
| **Error** | Simulate DB error (e.g. force-close DB in dev; or use a corrupt DB) | Error text + "Retry" `ElevatedButton` centred in body |
| **Data — flat list view** | Default on open (grouped view starts `false`) | `_TaskList` `ListView` with `DailyTaskCard` per task |
| **Data — grouped view** | Tap the grid/list toggle in `_GoalCard` | `GroupedDailyView` with `ExpansionTile` per curriculum |
| **Section = today** | Open via "Today" mission card | Only tasks where `!t.isOverdue && priority != overdueChazara && priority != scheduledChazara` are shown |
| **Section = overdue** | Open via "Overdue" mission card | Only tasks where `t.isOverdue == true` are shown; each card shows red "Overdue" badge |
| **Section = review** | Open via "Review" mission card | Only tasks where `priority == overdueChazara || priority == scheduledChazara` are shown; this section is only reachable when ≥1 track has chazara stages — verify chazara term appears in summary |
| **Section = all** | Open from learning screen FAB | All task priorities shown in sort order: `overdueProgram > todayProgram > overdueChazara > overdueNewLearning > scheduledChazara > newLearning` |
| **Hebrew/RTL** | Set device language to Hebrew | Layout mirrors RTL; dismiss swipe direction reverses; snackbar text is Hebrew |
| **Dark mode** | Enable dark theme | Background `AppColors.surfaceF5` darkens; card surfaces remain legible |
| **Child mode** | Open under a CHILD profile | No points/gamification visible; screen contents identical otherwise |
| **Tutor mode** | Enter tutored session for a child | Screen visible; mark-complete on `TextDisplayScreen` is absent (tested there); task cards themselves have no inline mark-complete affordance (verified below) |

### Test Step Table

| # | Action on WHICH element | Expected result | Product rule / fix |
|---|---|---|---|
| 1 | **Launch app** with at least two active tracks, one with chazara. Tap "Today" mission card on dashboard. | Router pushes `SchedulerRoute` with `schedulerTaskSectionProvider` = `today`. SchedulerScreen loads without hang. | Session fix: route guards fail-safe |
| 2 | Observe **screen title** (text in `_HeaderRow`). | Text reads "Daily Tasks" (EN) / "משימות יומיות" (HE). No "Personal", "Standard", "Custom", "אישי" label. | No track-type label rule |
| 3 | Observe **`_GoalCard`** summary line. | Text reads "N today tasks" where N matches the count of tasks in the active section. Gradient card is blue, no XP or streak info visible (adult or child). | Adults no gamification |
| 4 | Tap the **view-toggle `InkWell`** (grid/list icon) inside `_GoalCard`. | View toggles between `_TaskList` (flat `ListView`) and `GroupedDailyView`. Icon flips between `grid_view_rounded` and `view_list_rounded`. `schedulerGroupedViewProvider` state changes. | — |
| 5 | Tap the **view-toggle** again. | Returns to the previous view mode. | — |
| 6 | In **flat list view**, observe a task card for an overdue item. | Red "Overdue" badge visible in the top-right of the card. Curriculum colour-bar on left reflects the track's curriculum colour. Stage label displayed. No track-type text. | No track-type label; overdue bucketing |
| 7 | In **flat list view**, observe a task card for a chazara item (if a chazara track exists). | Stage label reflects domain term (e.g. "Chazara" or "חזרה" depending on Hebrew Terms pref), NOT "Personal"/"Standard". | Chazara gating; no track-type |
| 8 | **Tap a task card** (the `InkWell`/`onTap` on `DailyTaskCard`). | App pushes `TextDisplayRoute` for `task.contentItemSefariaRef`. TextDisplay screen opens. | — |
| 9 | On `TextDisplayScreen`, check for **live "mark complete" affordance** while in tutor mode. | Affordance is absent or disabled. No way to mark completion from this screen when `tutorPerms.canMarkLiveCompletion == false`. | Tutor canMarkLiveCompletion = FALSE |
| 10 | Press **system Back** from `TextDisplayScreen`. | Returns to `SchedulerScreen`. Scheduler list is still visible with same tasks. | Session fix: route guards fail-safe |
| 11 | **Swipe a task card right-to-left** (end-to-start `Dismissible`). | Card dismisses with a grey skip background showing `Icons.skip_next_rounded`. Snackbar appears: "Task skipped until tomorrow" with "Undo" action. Task disappears from the list. | Skip behaviour |
| 12 | Tap **"Undo"** in the skip snackbar within the dismissal window. | Task reappears in the list. `skippedTasksProvider` state removes the ref. | Undo skip |
| 13 | Swipe another task card; let snackbar **auto-dismiss without tapping Undo**. | Task remains absent from the list. `SharedPreferences` stores the skipped ref. On next app cold-start same day, task is still absent. | Skip persistence |
| 14 | Observe that **yesterday's skipped task** (if any) appears at higher priority. | The previously-skipped item's priority is boosted to `overdueChazara` rank in the sorted list (appears near top). Its `reason` contains "(previously skipped)". | Previously-skipped priority boost |
| 15 | Switch to **grouped view** and observe a curriculum group header. | `ExpansionTile` shows curriculum name (from `curriculumLabelText`) + count in parentheses, with a colour circle. Curriculum order follows Jewish-learning order (Chumash → Nach → Tanach → Bavli → Yerushalmi → Mussar), NOT alphabetical. No "Personal"/"Standard" text. | No track-type label; canonical ordering |
| 16 | **Tap the `ExpansionTile` header** for a curriculum group. | Section collapses, hiding all child task cards. Arrow rotates. | — |
| 17 | **Tap the collapsed header** again. | Section expands again, showing all task cards. | — |
| 18 | **Swipe a task card** inside grouped view (end-to-start). | Calls `onTaskDismissed(curriculum, index)` which invokes `skippedTasksProvider.notifier.skip(ref)`. Snackbar appears with "Undo". | Skip in grouped view |
| 19 | **Undo skip** in grouped view. | `undoSkip` called; task reappears in the group. | Undo in grouped view |
| 20 | With section = `today`, confirm **overdue tasks are absent**. | No task with `isOverdue == true` appears in the list. Summary reads "N today tasks". | Today section bucketing |
| 21 | With section = `overdue`, confirm **only overdue tasks appear**. | Every visible card has "Overdue" badge. Tasks with `isOverdue == false` are absent. Summary reads "N missed/overdue tasks". | Overdue bucketing |
| 22 | With section = `review`, confirm **only chazara tasks appear** (and this section was only reachable because ≥1 track has chazara). | Only tasks with `priority == overdueChazara` or `priority == scheduledChazara` visible. Summary uses the `chazaraTerm` label. No "Personal"/"Standard". | Chazara gating; review bucketing |
| 23 | Navigate to SchedulerScreen when **all tasks for the current section are completed or skipped**. | `EmptyState` widget shows: icon `celebration_outlined`, title "All caught up! Great work!", subtitle "You have no tasks remaining for today." No crash. | Session fix: route guards |
| 24 | Simulate an **error state** (disable network + DB, or force provider error in debug). Observe error widget. | Text "Error loading tasks: [error message]" and "Retry" `ElevatedButton` displayed. | — |
| 25 | Tap the **"Retry"** `ElevatedButton` in the error state. | `ref.invalidate(allDailyTasksProvider)` fires; loading spinner shows, then either data or error again. | — |
| 26 | Open Scheduler with a profile that has **no active tracks** (brand-new profile). | `EmptyState` shown. No crash. No "Daily Tasks" title below a loading spinner hanging indefinitely. | Session fix: route guards |
| 27 | Open Scheduler with a profile that has an active track with **a bulk/lifetime sentinel completion** (completedAt = 2000-01-01) for an item. | The item still appears in today's list (sentinel completions do NOT filter tasks per `isTaskCompleted` check). | Bulk/lifetime sentinel not in streak/activity |
| 28 | Open Scheduler with a **back-dated track** (program start date = today−30). | Overdue tasks from the back-dated period appear in the overdue section. Count matches the number of calendar days behind. No tasks amnestied that were scheduled on/after the reorder day. | Back-dating generates catch-up tasks; reorder amnesty |
| 29 | Observe the screen in **Hebrew locale** (RTL). | Overdue badge on the card top-right flips to top-left. Swipe direction for skip reverses (start-to-end). Snackbar text in Hebrew. | Hebrew/RTL |
| 30 | Verify **no track-type label** anywhere on screen (inspect every text widget). | Strings "Personal", "Standard", "Custom", "אישי" are absent from every visible text element. | No track-type label rule |

---

## 2. DailyTaskCard Widget

*Appears inside `_TaskList` and `GroupedDailyView`. Interactive elements are documented here.*

### States to Verify

| State | Condition |
|---|---|
| Normal (today, not overdue) | `isOverdue == false`; no badge |
| Overdue | `isOverdue == true`; red "Overdue" badge top-right (top-left in RTL) |
| Chazara stage | `stageName` resolves to chazara term; only when track has chazara stages |
| Dismissible reveal | Mid-swipe; grey background with skip icon |

### Test Step Table

| # | Action on WHICH element | Expected result | Product rule / fix |
|---|---|---|---|
| 31 | **Tap the card body** (`InkWell`, full card). | Pushes `TextDisplayRoute(sefariaRef: task.contentItemSefariaRef)`. | — |
| 32 | Observe **curriculum colour bar** on left edge. | Matches `AppTheme.getCurriculumColor(task.curriculumId)`. Width 6, height 104. Not a track-type colour label. | No track-type label |
| 33 | Observe **title text** (rendered via `renderedDisplayForRefProvider`). | Shows the human-readable label for the sefaria ref (e.g. "Berakhot 2a"). Falls back to `sefariaRef.replaceAll('_', ' ')`. `overflow: ellipsis`. | — |
| 34 | Observe **curriculum pill label** (bottom-left of card). | Shows curriculum name text, NOT "Personal"/"Standard". Background is curriculum colour at 15% opacity. | No track-type label |
| 35 | Observe **stage label** (next to curriculum pill). | Domain term resolved by `domainTermLabels(ref).resolveStoredStageName(task.stageName)`. If chazara stage, shows chazara term. Only visible if track has chazara stages. | Chazara gating |
| 36 | Observe card when `isOverdue == true`. | Red "Overdue" badge (`AppColors.statusDanger` background) in top-right corner (LTR) / top-left (RTL). | Overdue badge |
| 37 | **Swipe card end-to-start** past the dismiss threshold. | `onDismissed` fires. Grey background with `Icons.skip_next_rounded`. Snackbar "Task skipped until tomorrow" with "Undo". | Skip |
| 38 | **Swipe card start-to-end** (wrong direction). | No dismiss; `DismissDirection.endToStart` only. Card snaps back. | — |
| 39 | Verify **no track-type text** on card (title, subtitle, badge, any text widget). | "Personal", "Standard", "Custom", "אישי" absent. | No track-type label |

---

## 3. GroupedDailyView Widget

### Test Step Table

| # | Action on WHICH element | Expected result | Product rule / fix |
|---|---|---|---|
| 40 | Observe **grouping order** when multiple curricula present. | Curricula ordered by `CurriculumId.index` — Chumash, Nach, Tanach, Bavli, Yerushalmi, Mussar. Never alphabetical. | Canonical Jewish ordering |
| 41 | Observe **group header circle** colour. | Matches `AppTheme.getCurriculumColor(curriculum)`. | — |
| 42 | Observe **group header text**. | Format: `"[CurriculumLabel] ([count])"`. No track-type label. | No track-type label |
| 43 | **Tap group header** to collapse. | Task cards for that curriculum hide; `initiallyExpanded: true` default verified on first render. | — |
| 44 | **Tap collapsed header** to re-expand. | Task cards for that curriculum show. | — |
| 45 | **Pull-to-refresh** (if `ListView` supports it). | SOURCE: `GroupedDailyView` has no `RefreshIndicator` wrapper — confirm behaviour cannot be triggered and does not crash. (Mark probe.) | — |
| 46 | Observe **empty grouped view** when all tasks in a curriculum are skipped and grouped view rebuilt. | `Center(child: Text(noTasksForToday))` shows if `grouped.isEmpty`. | Empty state |

---

## 4. StudyDayConfigScreen (`StudyDayConfigRoute`)

### Route and Entry Points

`StudyDayConfigRoute` is registered in `app_router.dart` but no explicit push site was found outside the router itself and the add-track / edit-track flows (which use `step_study_days.dart` as an embedded step, not a full-screen push). The standalone screen is accessible if `StudyDayConfigRoute` is pushed directly with a `curriculumId` argument.

**Precondition:** Must have an active track for the `curriculumId` passed. To test chazara-enabled path: track must have > 1 stage. To test learn-only path: track must have exactly 1 stage.

**How to reach:** Navigate programmatically via `context.router.push(StudyDayConfigRoute(curriculumId: someId))` (currently only reachable from track setup/edit flow; probe carefully whether it is also surfaced from Settings > track management). Executor should also look for an entry in parent settings screen or track detail screen.

### States to Verify

| State | How to reach |
|---|---|
| **Loading** | Open screen; brief spinner while `studyDayConfigsProvider` and `_curriculumTrackHasChazaraProvider` resolve |
| **Learn-only track** (`trackHasChazara == false`) | Open with a track that has exactly 1 stage | "All days are study days for this track." message; no day toggles |
| **Chazara-enabled track** | Open with a track that has > 1 stage | Day toggle grid with all 7 days, legend, summary |
| **Error** | Simulate DB error on `studyDayConfigsProvider` | `AppErrorView` with Retry |
| **Tutor, canEditStudyDays = true** | Enter tutored session where tutor has `canEditStudyDays: true` | Day tiles tappable |
| **Tutor, canEditStudyDays = false** | Enter tutored session where tutor has `canEditStudyDays: false` | Day tiles read-only (`onToggle == null`); tapping does nothing |
| **Hebrew/RTL** | Hebrew locale | Text/layout mirrors RTL |
| **Dark mode** | Dark theme | Tile colours update; legend dots readable |

### Test Step Table

| # | Action on WHICH element | Expected result | Product rule / fix |
|---|---|---|---|
| 47 | Open `StudyDayConfigScreen` for a **learn-only track** (1 stage). | AppBar shows `"[CurriculumLabel] Study Days"`. Body shows "All days are study days for this track." NO chazara/review words in the message. No day toggle grid rendered. | Chazara gating (per-track) |
| 48 | Open `StudyDayConfigScreen` for a **chazara-enabled track** (> 1 stage). | Day toggle grid with 7 rows, legend row ("Study" blue dot, "Review only" grey dot), and summary text. | — |
| 49 | Observe **legend dots**. | "Study" label next to a primary-colour dot. "Review only" label next to a grey dot. Strings come from `schedulerStudyLabel` / `schedulerReviewOnlyLabel` localized strings. | — |
| 50 | Observe **day order** in the toggle grid. | Sun, Mon, Tue, Wed, Thu, Fri, Sat — per `_displayOrder = [7,1,2,3,4,5,6]`. | — |
| 51 | Observe a **study-day tile**. | Left icon `Icons.menu_book` (primary colour). Day label bold. Right badge reads "Study" (primary colour on light background). Tile background is primary at 10% opacity. | — |
| 52 | **Tap a study-day tile** (owner context). | Tile flips to review: icon becomes `Icons.refresh`, badge text becomes "Review", colours become grey. Summary text decrements study-day count. `studyDayConfigDao.upsertDayConfig` called in background. `allDailyTasksProvider` invalidated. | Day toggle saves immediately |
| 53 | **Tap the review-day tile** just created. | Reverts to study day. Badge reads "Study". Count increments. | Round-trip toggle |
| 54 | After toggling, **kill and restart the app**. | Toggled days persist; the previously toggled day still shows the new state. | Persistence |
| 55 | While online, toggle a day; check sync. | `syncFacade.pushStudyDayConfig` is called. No crash. Outbox entry visible in debug sync screen (if accessible). | — |
| 56 | Toggle a day while **offline**. | Toggle applies locally. No error or crash. Outbox queues the change for later sync. | Offline-first |
| 57 | Toggle a day in **tutor context with `canEditStudyDays == false`**. | Tile `onToggle` is `null`; tapping the tile does nothing — no state change, no snackbar. | Tutor canEditStudyDays gate |
| 58 | Toggle a day in **tutor context with `canEditStudyDays == true`** but remote write is blocked (`TutorWriteException` with `permission-denied`). | Toggle fires locally; remote push fails; snackbar shows "You don't have permission to make this edit". | Tutor write gate |
| 59 | Observe **summary text** at bottom of grid. | "N study day(s) per week" where N equals the current count of study-type days. Singular "study day" when N=1, plural "study days" when N≠1. | — |
| 60 | Tap **AppBar back arrow** (`Icons.arrow_back` leading button). | `context.router.maybePop()` called; screen pops. Scheduler or parent screen resumes. No data lost. | Session fix: route guards |
| 61 | Press **system Back button**. | Same as step 60. Screen pops cleanly. | Session fix: route guards |
| 62 | Observe AppBar **title text**. | Reads "[CurriculumLabel] Study Days" where [CurriculumLabel] respects Hebrew Terms preference. No "Personal"/"Standard"/"Custom" text. | No track-type label |
| 63 | Observe screen with **error loading configs** (`AppErrorView`). | Error message + Retry button shown. Tapping Retry calls `ref.refresh(studyDayConfigsProvider(curriculumId))`. | — |
| 64 | Toggle days to leave **0 study days** (set all 7 to review). | All tiles show "Review" state. Summary reads "0 study days per week". No crash. (Behaviour with 0 study days in the scheduler itself — no tasks generated — should be confirmed on SchedulerScreen.) | Edge case |

---

## 5. GoalSetupScreen / GoalSetupForm

### Route and Entry Points

`GoalSetupScreen` is a `StatelessWidget` (no `@RoutePage` annotation found). It is used as an embedded form (`GoalSetupForm`) inside the add-track flow and edit-track flow, and exposed as a standalone screen wrapping that form. There is no `GoalSetupRoute` in the router; it is pushed via `Navigator.of(context).push(MaterialPageRoute(...))` or embedded in the add-track page view.

**How to reach (standalone):** Add a new track for any curriculum, reach the Goal Setup step in the add-track wizard. OR edit an existing track's goal.

**Preconditions:**
- At least one active curriculum with a track.
- To see unit picker: track must be Bavli, Yerushalmi, Chumash, Nach, Tanach, or Mussar.
- To see projected-completion / pace-summary card: `totalItems` must be non-null (passed from parent).

### States to Verify

| State | Condition |
|---|---|
| **New goal** (`existingGoal == null`) | Creating a goal for the first time |
| **Edit goal** (`existingGoal != null`) | Editing an existing goal |
| **Deadline mode** | `_goalType == 'deadline'` |
| **Pace mode** | `_goalType == 'pace'` |
| **No-deadline mode** | `_goalType == 'none'` |
| **With unit picker** (Bavli/Yerushalmi) | `_showUnitPicker == true`; Amudim/Dafim segments |
| **With unit picker** (Chumash/Nach/Tanach/Mussar) | `_showUnitPicker == true`; Perakim/Pesukim segments |
| **Without unit picker** | Other curricula | No unit segment control shown |
| **Hebrew date mode** | `useHebrewDateProvider == true` | Date picker invokes `HebrewDatePicker.show`; displayed date is Hebrew |
| **Gregorian date mode** | `useHebrewDateProvider == false` | `showLearningAppDatePicker` shown; displayed date is Gregorian |
| **Deadline in the past** | Target date set to a past date | "Deadline has passed" text in error colour |
| **Hebrew/RTL** | Hebrew locale | Layout mirrors RTL |
| **Dark mode** | Dark theme | Cards and sliders legible |

### Test Step Table

| # | Action on WHICH element | Expected result | Product rule / fix |
|---|---|---|---|
| 65 | Open **GoalSetupScreen** for a new goal (from add-track flow). | AppBar title reads "New Goal" (EN) / localized HE. Slider starts at 100%. `_goalType` starts as "deadline". | — |
| 66 | Open **GoalSetupScreen** to edit an existing goal. | AppBar title reads "Edit Goal". All fields pre-populated with `existingGoal` values. | — |
| 67 | Drag the **target percentage slider** from 100% to 50%. | Label above slider updates: "Complete 50% of the material (N of M items)" if `totalItems` provided, else "Complete 50% of the material". Projected daily pace card updates. | Slider interaction |
| 68 | Drag slider to **minimum (1%)**. | Label shows 1%. No crash. | Slider boundary |
| 69 | Drag slider to **maximum (100%)**. | Label shows 100%. | Slider boundary |
| 70 | Observe **unit picker** for Bavli curriculum. | `SegmentedButton` with "Amudim" and "Dafim" segments visible. Default selected: "Amudim" (from `_defaultUnit`). | — |
| 71 | Tap **"Dafim"** segment in unit picker. | `_paceGranularity` changes to `'daf'`. Pace label updates to "Dafim per day". | — |
| 72 | Observe **unit picker** for Chumash curriculum. | `SegmentedButton` with "Perakim" and "Pesukim" segments. Default: "Perakim". | — |
| 73 | Tap **"Pesukim"** segment. | `_paceGranularity` = `'pasuk'`. Label updates to "Pesukim per day". | — |
| 74 | Observe **goal type SegmentedButton** (Deadline / Pace / No deadline) with icons. | Three segments visible. Default = "Deadline" selected (with `Icons.calendar_today`). | — |
| 75 | Tap **"Pace"** segment (`Icons.speed`). | Pace section (`_buildPaceSection`) shown: pace text field + per-day/per-week `SegmentedButton`. Deadline section hidden. | — |
| 76 | Tap **"No deadline"** segment (`Icons.all_inclusive`). | Text "Learn at your own pace with no time pressure." shown. Deadline and pace sections hidden. | — |
| 77 | Tap **"Deadline"** segment to return. | Deadline section re-shows. | — |
| 78 | In **deadline mode**, tap the **date card** (`InkWell` with `Icons.calendar_today`) when `useHebrewDateProvider == false`. | Standard `showLearningAppDatePicker` opens. Min date = today; max = 2100. | Gregorian date picker |
| 79 | Select a future date in the **Gregorian picker**. | Card updates to show selected date. "Tap to choose a date" placeholder replaced. `Icons.clear` appears. Daily pace summary card shows estimated pace if `totalItems != null`. | — |
| 80 | Tap **`Icons.clear`** on the date card. | `_targetDate` set to null. Date card reverts to "Tap to choose a date". Pace summary card hides. | Clear date |
| 81 | In **deadline mode**, tap the **date card** when `useHebrewDateProvider == true`. | `HebrewDatePicker.show(context)` opens (see Section 6 below). Returns Gregorian UTC. Card shows Hebrew date string. | Hebrew date picker |
| 82 | Set a target date **in the past** (not possible via picker since `firstDate = now`, but test by pre-loading an existing goal with a past date). | "Deadline has passed" text shown in `Theme.colorScheme.error` colour. No pace calculation shown. | Past deadline |
| 83 | In **deadline mode**, type in the **Occasion text field** (`TextField` with `TrimLeadingSpaceFormatter`). | Input accepted. Leading spaces trimmed. Max length: no explicit limit in source — note for executor to probe. | — |
| 84 | Leave the **Occasion text field** empty. | Submit still allowed (`_descriptionController.text` defaults to `''`). | — |
| 85 | In **pace mode**, observe the **pace value `TextFormField`** and type `"3"`. | `_paceValue` updates to 3. Helper text updates to "How many [unitLabel] per day?". Projected completion card recalculates if `totalItems != null`. | — |
| 86 | Clear pace value field and type **`"0"` or `-1`**. | `int.tryParse(v)` returns 0 or negative; the `if (parsed != null && parsed > 0)` guard means `_paceValue` does NOT update. Projected completion card should not crash (division by zero guard: `if (dailyRate <= 0) return SizedBox.shrink()`). | Edge case — zero pace |
| 87 | Clear pace value and type **non-numeric text** (e.g. "abc"). | `int.tryParse` returns null; `_paceValue` unchanged. No error shown on field. | — |
| 88 | In **pace mode**, tap **"Per week"** `SegmentedButton` segment. | `_paceUnit = 'per_week'`. Pace label updates to "Dafim per week" (or equivalent). Projected completion recalculates using weekly rate. | — |
| 89 | Tap **"Per day"** segment. | `_paceUnit = 'per_day'`. Label reverts. | — |
| 90 | Verify **projected completion card** visible in pace mode when `totalItems != null`. | Shows "Projected completion: [formatted date]" and "[N items] in ~[M] days". Date formatted per `useHebrewDateProvider`. | Hebrew/Gregorian date display |
| 91 | Tap the **Submit / Create Goal button** (`FilledButton`) with goal type = `'deadline'` and a date set. | `_submit()` called. `GoalEntity` constructed with `goalType: 'deadline'`, `targetDate` set, `paceValue: null`, `pacePeriod: null`. `onComplete(result)` fires. `Navigator.of(context).pop(result)` dismisses screen. | — |
| 92 | Tap **Submit** with goal type = `'pace'`. | `GoalEntity` constructed with `goalType: 'pace'`, `paceValue: _paceValue`, `pacePeriod: _paceUnit`, `targetDate: null`. | — |
| 93 | Tap **Submit** with goal type = `'none'`. | `GoalEntity` with `goalType: 'none'`, `targetDate: null`, `paceValue: null`. | — |
| 94 | Tap **AppBar back arrow** (auto-back button) before submitting. | Screen pops with `null` result. No goal saved. | Session fix: route guards |
| 95 | Press **system Back** before submitting. | Same as 94. | Session fix: route guards |
| 96 | Check **submit button label**. | For new goal: "Create Goal". For edit: "Update Goal". Can be overridden via `submitLabel` parameter. | — |

---

## 6. HebrewDatePicker Dialog

*Shown from `GoalSetupForm._pickHebrewDate()`. An independent `Dialog` widget.*

### Test Step Table

| # | Action on WHICH element | Expected result | Product rule / fix |
|---|---|---|---|
| 97 | Open the dialog via date card tap (Hebrew date mode). | Dialog appears with title "Select Hebrew date". Fields: Year stepper, Month dropdown, Day dropdown, Gregorian equivalent preview row, Cancel button, "Select date" `FilledButton`. | — |
| 98 | Tap **year decrement** `IconButton` (minus icon). | `_hebrewYear` decrements by 1. Year text updates. Gregorian equivalent row updates. Day is clamped if month has fewer days in the new year (leap year boundary). | Leap year clamping |
| 99 | Tap **year increment** `IconButton` (plus icon). | `_hebrewYear` increments. Gregorian preview updates. | — |
| 100 | Change **month dropdown**. | `_hebrewMonth` updates. `_clampDayToMonth()` called; if selected day > days in new month, it clamps. Gregorian preview updates. | Day clamping |
| 101 | In a non-leap year, verify **Adar II absent** from month dropdown. | Only one Adar (Adar I = month 6 in kosher_dart) appears. Adar II option not listed when `!isHebrewLeapYear(_hebrewYear)`. | Leap year month list |
| 102 | In a leap year, verify **both Adar I and Adar II** appear. | Both months listed. | Leap year month list |
| 103 | Change **day dropdown** to a valid day. | `_hebrewDay` updates. Gregorian preview updates. | — |
| 104 | Tap **"Cancel"** `TextButton`. | `Navigator.of(context).pop()` with no value. Parent screen `_targetDate` unchanged. | Cancel dialog |
| 105 | Press **system Back** while dialog open. | Dialog dismisses (barrier dismissible). Parent `_targetDate` unchanged. | — |
| 106 | Tap **close `IconButton`** (top-right `Icons.close`). | `Navigator.of(context).pop()` with no value. Dialog closes. | — |
| 107 | Tap **"Select date" `FilledButton`**. | `Navigator.of(context).pop(gregorianDate)` fires with the Gregorian UTC equivalent. Parent form `_targetDate` updates; card displays Hebrew string. | — |
| 108 | Pick a date in **Cheshvan** of a year where Cheshvan has 29 days (short year). | Day dropdown shows 1–29 maximum. No crash. | Calendar edge case |
| 109 | Pick a date in **Kislev** of a year where Kislev has 29 days (short year). | Day dropdown shows 1–29. | Calendar edge case |

---

## 7. PaceIndicator Widget

*Read-only display widget; no interactive elements. Confirm correct visual rendering.*

| State | Condition | Expected label |
|---|---|---|
| Ahead (deadline goal) | `PaceStatusType.ahead`, `DateScheduleDelta` | "+N days ahead" in green |
| Ahead (pace goal) | `PaceStatusType.ahead`, `PaceScheduleDelta` | "+N items/week ahead" in green |
| On pace | `PaceStatusType.onPace` | "On pace" in amber |
| Behind (deadline goal) | `PaceStatusType.behind`, `DateScheduleDelta` | "N days behind" in red |
| Behind (pace goal) | `PaceStatusType.behind`, `PaceScheduleDelta` | "N items/week behind" in red |

| # | Action on WHICH element | Expected result | Product rule / fix |
|---|---|---|---|
| 110 | Observe `PaceIndicator` with **ahead status, deadline goal**. | Green circle dot + "+N days ahead". No track-type text. | No track-type label |
| 111 | Observe `PaceIndicator` with **on-pace status**. | Amber dot + "On pace". | — |
| 112 | Observe `PaceIndicator` with **behind status, deadline goal**. | Red dot + "N days behind". Absolute value used (no double-negative). | — |
| 113 | Observe `ProjectedCompletionText` with a valid `projectedDate`. | "At current pace, you'll finish by [date]" in italic body-small style. Date formatted by `MaterialLocalizations.formatMediumDate`. | — |
| 114 | Observe `ProjectedCompletionText` with `projectedDate == null`. | `SizedBox.shrink()`; nothing rendered. | — |

---

## 8. Cross-Cutting Regression Checks for This Cluster

| # | Check | How to verify | Session fix / rule |
|---|---|---|---|
| 115 | Open Scheduler from **notification deep-link** on lock screen. | Tap the daily-reminder notification. `router.navigate(SchedulerRoute())` fires. App opens to SchedulerScreen without hang or crash. | Session fix: route guards / deep-link handling |
| 116 | Open Scheduler from **learning screen** back-button / FAB. | From TextDisplay, tap back to SchedulerScreen (or use FAB link). Screen resumes without duplicate push or blank state. | Session fix: route guards |
| 117 | Verify **no "Personal"/"Standard"/"Custom"/"אישי"** text on any scheduler screen. | Inspect every text element across all task cards, group headers, AppBar titles, empty states, goal form labels. | No track-type label rule |
| 118 | Verify **chazara-disabled track**: open SchedulerScreen, StudyDayConfigScreen, and GoalSetupScreen. | No "review", "chazara", "חזרה", or review-day toggle appears for a single-stage track. Summary says "N today tasks", not "N chazara tasks". | Chazara gating (per-track) |
| 119 | Verify **adult profile** sees no XP, level, or streak on SchedulerScreen. | Open Scheduler under an ADULT profile. No points/gamification widgets visible. | Adults no gamification |
| 120 | Verify **bulk/lifetime sentinel** (completedAt = 2000-01-01-00:00 UTC) does NOT remove items from today's scheduler. | Mark prior completions via bulk-mark; open Scheduler. Bulk-marked items still appear in the due-today list. | Bulk/lifetime sentinel not in streak/activity |
| 121 | Back-date track to today−30; verify **catch-up overdue tasks** appear in overdue section. Program track only. | Open via "Overdue" mission card; count should match days behind × daily pace. | Back-dating generates catch-up tasks |
| 122 | In tutor mode with **`canMarkLiveCompletion = false`**: tap a task card, reach TextDisplay. | Mark-complete button absent or disabled on TextDisplay. Return to Scheduler; task still in the list. | Tutor canMarkLiveCompletion = FALSE |
| 123 | Verify **skip persists after app restart same day**. | Skip a task; force-kill app; reopen. Task absent from Scheduler list. Next day task reappears with priority boost. | Skip persistence; previously-skipped boost |


# Cluster: Gamification / Rewards / Points

## Overview and Product-Rule Reminders

The following product rules are cited in individual steps below:

- **RULE-ADULT-NO-POINTS**: Adults have no points/gamification. `PointsDisplayWidget` returns `SizedBox.shrink()` for `ProfileMode.adult`. The `ChildPointsRewardsTabCard` on the Dashboard is only rendered when `userMode == ProfileMode.child`. The ⭐ counter tile in `ProgressTierCounterRow` is only shown when `showPoints: true`, which is only passed in child mode.
- **RULE-FULFIL-DECLINE-GUARD**: Fulfil and Decline buttons on `ParentPendingRedemptionsScreen` are single-tap guarded via `_RedemptionCardState._busy`. While a request is in-flight BOTH buttons are disabled (`onPressed: _busy ? null : …`). The guard resets only after the async action completes. No double-fire possible.
- **RULE-CHILD-GUARD**: Routes `/gamification`, `/redeem`, `/parent-mode/*` are guarded by `ChildModeGuard` which passes only when the active profile's `mode == 'child'`. Adult profiles cannot access these routes.
- **RULE-NO-TRACK-LABEL**: No track-type label ("Personal"/"Standard"/"Custom") should appear anywhere in gamification UI.
- **RULE-TUTOR-READONLY**: `canMarkLiveCompletion` is always `false` for tutors. Tutors may or may not have `canEditPoints` / `canEditRewards` depending on the grant.
- **RULE-SPEND-ECONOMY**: Every reward is a single global spend-item against the debitable balance. There is no per-track vs Global split in the UI (removed per DEC-32). No `RewardTypeSegmented` control is shown in `RewardConfigurationScreen`.

---

## 1. GamificationScreen — `/gamification`

### How to Reach

**Precondition**: Active profile must be a **child** profile (ProfileMode.child). The `ChildModeGuard` will block adult profiles and navigate them away.

**Path A — Notification tap**: Receive a "reward earned" push notification (payload `reward_earned`) on a child profile → tap the notification → `router.navigate(GamificationRoute())`.

**Path B — Deep-link / direct URL**: While signed in with an active child profile, navigate directly to `/gamification` (e.g. via ADB or link). The `authGuard` and `ChildModeGuard` must both pass.

**Alternate reach verification**: Confirm that tapping the `/gamification` path with an adult active profile navigates away (guard fires) rather than displaying the screen.

### Interactive Elements

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 1 | Pull-to-refresh (drag down) | `RefreshIndicator` on the scrollable body | Invalidates `achievementsOverviewProvider`, `dashboardStreakProvider`, `streakCalendarProvider`; spinner shows; list and streak data reload | Offline-first: pull-refresh may show cached data offline | |
| 2 | Observe on load | `AchievementsHeader` — centered title bar | Title text shows localised `l10n.myAchievementsTitle`; no track-type label visible | RULE-NO-TRACK-LABEL | |
| 3 | Observe | `ProgressSummaryCard` (blue card, top of list) | Shows `unlocked / total rewards` fraction in white on blue; shows encouragement text; no interactive elements on the card itself | Display only | |
| 4 | Tap | `AchievementFilterChip` labelled "All" in `TrackFilterRow` | Selected chip turns to filled blue; all achievement rows shown; `_trackFilterId` set to `null` | Filter resets to show all tracks | |
| 5 | Tap | Individual track filter chip (one per active track) in `TrackFilterRow` | Selected chip fills blue; previous chip deselects; list filters to only show rows for that `trackId`; empty message shown if no milestones for that track | RULE-NO-TRACK-LABEL: chip label is curriculum name, never "Personal"/"Standard" | |
| 6 | Scroll horizontal | `TrackFilterRow` chip row | Row scrolls horizontally when more tracks than fit on screen | Horizontal scroll | |
| 7 | Observe each | `AchievementTierCard` for an **unlocked** reward | Card shows reward title, "Unlocked" status label, progress bar at 100%, track tag chip (top-right), milestone threshold points; NO blur/lock overlay | isUnlocked = true → no `LockedAchievementShell` | |
| 8 | Observe each | `AchievementTierCard` for a **"coming soon"** (next-up) reward | Light blur overlay (sigma = 3.0); lock icon + hint text showing points needed; status label reads "Coming Soon"; no tap action | isNextUp = true → light blur | |
| 9 | Observe each | `AchievementTierCard` for a **locked** (not next-up) reward | Heavier blur overlay (sigma = 6.0); lock icon; darker overlay; no tap action | isLocked → heavy blur | |
| 10 | Observe | **Legend Star** tier card (if present) | Dark navy-purple gradient background; "Ultimate Goal" italic text; golden/green progress bar; behaves like other locked cards in `LockedAchievementShell` if not unlocked | isLegendTier = true | |
| 11 | Scroll vertical | Main `CustomScrollView` | All sliver sections scroll smoothly: `ProgressSummaryCard` → `TrackFilterRow` → achievement cards → `ProTipCard` → `ExpansionTile`; pull-to-refresh triggers only when overscrolled at the top | Smooth scroll | |
| 12 | Observe | `ProTipCard` (amber card below achievement list) | Shows lightbulb icon, "Pro Tip:" bold label in orange-red, body text; static display only, no tap | Display only | |
| 13 | Tap | `ExpansionTile` — "Activity & Points" section header | Tile expands to show: `StreakWidget`, activity calendar label, `StreakCalendar` (30-day), `PointsDisplayWidget`; second tap collapses | Expand/collapse | |
| 14 | Observe (expanded) | `StreakWidget` in child mode | Shows animated fire icon (bounce animation on load if streak > 0), current streak count "N day streak!", "Best: M days" | Child mode: `_AnimatedStreakDisplay` renders; fire icon bounces | |
| 15 | Observe (expanded) | `PointsDisplayWidget` in child mode (userMode = ProfileMode.child) | Shows total points as large headline number, "Total Points" label below, curriculum breakdown chips (one per curriculum with points) | RULE-ADULT-NO-POINTS: must NOT be visible in adult mode | |
| 16 | Observe (expanded) | `StreakCalendar` — 30-day grid | Shows 30 days (4–5 rows × 7 columns); active days filled with dark blue circle; today has an additional outline border; weekday labels at top; no tap interactions | Display only | |
| 17 | Switch to adult profile | Navigate away; switch to adult profile; attempt `/gamification` | `ChildModeGuard` blocks navigation; screen not shown; no crash | RULE-ADULT-NO-POINTS; RULE-CHILD-GUARD; fix: route guards never lock/hang | |
| 18 | Test error state | Force `achievementsOverviewProvider` error (disconnect network + disable offline cache) | Error ListView renders with `l10n.errorLoadingCalendar` text; pull-to-refresh retries; no crash | Error state handled | |
| 19 | Test loading state | Observe initial load | `CircularProgressIndicator` centred while data loads | Loading state | |
| 20 | Test empty state | Log in with child profile that has no active tracks with reward milestones | `l10n.noRewardsYet` text shown in coral/orange colour; filter row shows only "All" chip | Empty state | |
| 21 | RTL / Hebrew locale | Switch app to Hebrew locale | Layout flips RTL; `Directionality.ltr` wrapper on points/percentage row preserves LTR number formatting; track tag chips render correctly; chip label uses Hebrew curriculum name if applicable | RTL layout; number formatting stays LTR inside `Directionality.ltr` | |
| 22 | Dark mode | Switch to dark theme | Card backgrounds, text colours adapt; progress bars, blur overlays visible; no white-on-white or black-on-black elements | Dark mode | |
| 23 | Tap system Back | Android back gesture/button | Navigates back to previous route (notification handler used `router.navigate`); no hang | Fix: route guards never lock/hang navigation | |

### States to Verify

| State | How to Reach |
|-------|-------------|
| Loading | Fresh open on slow device / throttled connection |
| Error | Force provider error (network off, cache cleared) |
| Empty (no milestones) | Child with tracks that have no enabled milestones |
| Data — unlocked milestones | Child with completed points ≥ at least one milestone threshold |
| Data — all locked | Child with 0 points earned |
| Data — mixed | Child with some unlocked, some locked, one "next-up" |
| Child mode | Active profile `mode = 'child'` |
| Adult mode | Should be blocked by guard; confirm guard fires |
| Tutor mode | Guard blocks; tutor cannot access this child-gated route |
| Hebrew/RTL | Device or app locale set to Hebrew |
| Dark mode | Theme set to dark |
| Offline | Airplane mode on; data must render from local DB |

---

## 2. ChildRedemptionScreen — `/redeem`

### How to Reach

**Precondition**: Active profile is a **child** profile. `ChildModeGuard` blocks adult profiles.

**Path**: Dashboard (child mode) → `ChildPointsRewardsTabCard` → tap **"Redeem Prizes"** `FilledButton` → `context.router.push(ChildRedemptionRoute())`.

Note: `ChildPointsRewardsTabCard` is only rendered when `userMode == ProfileMode.child`.

### Interactive Elements

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 24 | Navigate to screen | Tap "Redeem Prizes" on dashboard | `ChildRedemptionScreen` opens; `AppBar` title shows `l10n.redeemScreenTitle`; balance card visible at top; reward list below | RULE-CHILD-GUARD: only accessible in child mode | |
| 25 | Observe | `_BalanceCard` (blue gradient card) | Shows `l10n.redeemScreenBalance` label and current points balance in large white bold text; gradient goes from `0xFF1E52D4` (top-left) to `AppColors.blueLight` (bottom-right) | Display only | |
| 26 | Observe | `AppBar` leading back button (auto-generated by navigator) | Tapping navigates back to dashboard | Back navigation | |
| 27 | Observe each | `_RewardCard` when `balance >= reward.pointsCost` (can afford) | Card shows reward icon (circle avatar), reward title, cost label in blue (`0xFF1E52D4`), FilledButton dark blue (`0xFF00218D`) with "Redeem" text enabled | canAfford = true | |
| 28 | Observe each | `_RewardCard` when `balance < reward.pointsCost` (cannot afford) | FilledButton shows grey disabled background (`0xFFE5E7EB`), grey button text with "Cannot Afford" (or localised equivalent) text, `onPressed: null`; cost label colour grey (`0xFF9CA3AF`) | canAfford = false; button disabled | |
| 29 | Tap | **"Redeem"** `FilledButton` on an affordable reward card | `AlertDialog` opens with title `l10n.redeemScreenConfirmTitle(reward.title)` and body `l10n.redeemScreenConfirmBody(reward.pointsCost)` | Confirmation dialog appears | |
| 30 | Tap | **Cancel** `TextButton` in confirmation `AlertDialog` | Dialog dismisses; no points deducted; no redemption record created; balance unchanged | Cancel path | |
| 31 | Tap outside dialog (barrier) | Tap dark barrier outside `AlertDialog` | Dialog dismisses (barrierDismissible: by default AlertDialog is dismissible); no redemption | Dismiss by barrier | |
| 32 | Tap | **Confirm** `FilledButton` in confirmation `AlertDialog` | Dialog closes; `db.pointsBalanceDao.createRedemption(...)` called; if successful: `SnackBar` shows `l10n.redeemScreenRequestedSnackbar(reward.title)`; `childRedemptionBalanceProvider` invalidated; balance card refreshes with new (lower) balance | Successful redemption; balance decrements | |
| 33 | Test insufficient balance race | Manually set balance below cost between dialog open and confirm (edge case — cannot easily trigger on device; confirm no crash) | `createRedemption` returns `null`; `SnackBar` shows `l10n.redeemScreenInsufficientSnackbar`; no crash | Error path | |
| 34 | Observe post-redemption | Balance card after a successful redemption | Balance shows updated (lower) value; list still shows rewards; affordable/unaffordable states may change | Balance invalidation | |
| 35 | Test empty rewards state | Child profile with no enabled reward milestones configured by parent | Centred text `l10n.redeemScreenNoRewards`; no list shown | Empty state | |
| 36 | Test loading state | Observe initial load | `CircularProgressIndicator` centred while `childRedemptionRewardsProvider` loads | Loading state | |
| 37 | Test error state | Force provider error | `Center(child: Text(e.toString()))` shown | Error state | |
| 38 | Tap system Back | Android back | Returns to Dashboard; no crash | Route guard never hangs | |
| 39 | Adult profile attempt | Switch to adult profile; navigate to `/redeem` | `ChildModeGuard` blocks; screen not shown; RULE-ADULT-NO-POINTS | RULE-CHILD-GUARD | |
| 40 | Observe RULE-ADULT-NO-POINTS | Adult profile on dashboard | `ChildPointsRewardsTabCard` is NOT rendered; "Redeem Prizes" button does not exist | RULE-ADULT-NO-POINTS | |
| 41 | RTL layout | Hebrew locale | AppBar title right-justified; balance card text direction adapts; reward cards adapt | RTL | |
| 42 | Dark mode | Dark theme | Cards, buttons, balance card visible; no contrast issues | Dark mode | |
| 43 | Offline | Airplane mode | Screen still loads from local DB; redemption write succeeds locally and queues outbox sync | Offline-first | |

### States to Verify

| State | How to Reach |
|-------|-------------|
| Loading | Slow device open |
| Empty | No enabled rewards |
| Error | Force provider exception |
| Zero balance — no affordable | Child with 0 points; all rewards show "Cannot Afford" |
| Non-zero balance — some affordable | Child with > 0 points; some rewards have cost ≤ balance |
| Post-redemption | After successfully confirming a redemption |

---

## 3. ParentPendingRedemptionsScreen — `/parent-mode/pending-redemptions`

### How to Reach

**Preconditions**: Active profile is a **child** profile. Must pass `ChildModeGuard` AND `PinGuard` (PIN entry required).

**Path**: `ParentSettingsScreen` (accessed via Dashboard → profile/role switcher → parent mode → parent settings) → tap **"Pending Prizes"** row → PIN prompt (if PIN set) → `ParentPendingRedemptionsScreen`.

Alternatively: Enter parent-mode PIN and navigate directly from parent settings tile.

### Interactive Elements

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 44 | Observe on load | `AppBar` title | Shows `l10n.pendingRedemptionsTitle`; back arrow present | Correct title | |
| 45 | Tap | `AppBar` back arrow (or Android Back) | Returns to `ParentSettingsScreen` | Back navigation | |
| 46 | Observe loading state | Initial data fetch | `CircularProgressIndicator` centred | Loading state | |
| 47 | Observe empty state | No pending redemptions | Centred text `l10n.pendingRedemptionsEmpty`; no list shown | Empty state | |
| 48 | Observe each card | `_RedemptionCard` for each pending redemption | Shows: circular icon avatar (reward icon), reward title in bold, cost label in blue (`0xFF1E52D4`), **"Approve"** `FilledButton` (navy `0xFF00218D`) at top-right, **"Decline"** `TextButton` (grey) below Approve | Cards render correctly | |
| 49 | Tap | **"Approve" (Fulfil)** `FilledButton` on a redemption card — FIRST tap | While `_busy = false`: `_run(widget.onFulfil)` called; `_busy` set to `true`; BOTH Approve and Decline buttons disabled (`onPressed: null`) during flight; `fulfilRedemption(id)` called; `pendingRedemptionsProvider` invalidated; `SnackBar` shows `l10n.pendingRedemptionsFulfilledSnackbar`; card disappears from list | RULE-FULFIL-DECLINE-GUARD: single-tap guard; no double-fire | |
| 50 | Rapid double-tap | **"Approve"** button — tap twice in rapid succession | Second tap is silently ignored because `_busy == true`; only one `fulfilRedemption` DB call occurs; no double-credit | RULE-FULFIL-DECLINE-GUARD: regression confirm fix "Redemption Fulfil/Decline are single-tap guarded (no double-fire)" | |
| 51 | Tap | **"Decline"** `TextButton` on a redemption card — FIRST tap | While `_busy = false`: `_run(widget.onDecline)` called; `_busy` set to `true`; BOTH Approve and Decline disabled; `declineRedemption(id)` called; points refunded to child balance; `pendingRedemptionsProvider` invalidated; `SnackBar` shows `l10n.pendingRedemptionsDeclinedSnackbar`; card disappears | RULE-FULFIL-DECLINE-GUARD | |
| 52 | Rapid double-tap | **"Decline"** button — tap twice in rapid succession | Second tap ignored (`_busy == true`); only one `declineRedemption` call; no double-refund | RULE-FULFIL-DECLINE-GUARD | |
| 53 | Tap Approve then immediately Decline | On the same card, tap Approve then immediately try Decline | After Approve fires, `_busy = true`; Decline button `onPressed = null`; Decline does NOT fire concurrently; after action completes `_busy` resets; card is gone from list anyway | RULE-FULFIL-DECLINE-GUARD: cross-action guard | |
| 54 | Verify point refund | After Decline: navigate to child's `ChildRedemptionScreen` | Child's balance has increased by the declined reward's `pointsCost` | Refund logic | |
| 55 | Multiple redemptions | Screen with 3+ pending redemptions | Each card has independent `_RedemptionCardState`; approving card A does not affect card B's `_busy` state | Independent state per card | |
| 56 | Observe error state | Force provider exception | `Center(child: Text(e.toString()))` rendered | Error state | |
| 57 | Tutor with canEditRewards = false | Access as tutor without canEditRewards permission | Parent settings does NOT show "Pending Prizes" row when `canEditRewards = false` (confirm from `parent_settings_screen.dart` guard); if somehow accessed, redemption actions still fire (no explicit tutor block in the screen itself) | Tutor permission gating | |
| 58 | Offline | Airplane mode; approve a pending redemption | Write succeeds locally; outbox queued; snackbar shown; card removed | Offline-first | |
| 59 | RTL / Hebrew | Hebrew locale | Card layout adapts; buttons stack correctly in RTL; cost label text direction | RTL | |
| 60 | Dark mode | Dark theme | Cards, buttons, text visible | Dark mode | |

### States to Verify

| State | How to Reach |
|-------|-------------|
| Loading | Slow device |
| Empty | All redemptions fulfilled or declined, or no child redemptions made |
| 1 pending | One child redemption pending |
| 3+ pending | Multiple children or multiple redemptions |
| Error | Force provider error |
| Post-fulfil | After approving one card |
| Post-decline | After declining one card |

---

## 4. PointConfigScreen — `/parent-mode/point-config`

### How to Reach

**Preconditions**: Active profile is a **child** profile. Must pass `ChildModeGuard` AND `PinGuard`.

**Path**: `ParentSettingsScreen` → **"Point Configuration"** row (only shown if `canEditPoints == true`, which it always is for real parents; tutors: depends on `tutorPerms.canEditPoints`) → `PointConfigRoute`.

### Interactive Elements

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 61 | Observe on load | `AppBar` | Back arrow (iOS chevron), centred title `l10n.pointSettingsTitle` in brand blue; no elevation; white background | Correct AppBar | |
| 62 | Tap | `AppBar` back button (arrow_back_ios_new_rounded) | `context.maybePop()` called; returns to parent settings | Back navigation | |
| 63 | Observe | `_HeroHeader` (blue gradient card) | Shows "CONFIGURATION" label, headline "Rewards Strategy" title, subtitle body text; decorative circles; no tappable elements | Display only | |
| 64 | Observe | "Active Curricula" section header | Orange book icon, "Active Curricula" label | Display only | |
| 65 | Observe each | `_CurriculumPointsCard` per active track | Shows: curriculum name (`CurriculumLabel.curriculum()`), Hebrew subtitle below if locale is not Hebrew; "ACTIVE" badge (orange-brown); stepper row showing current points value with stage name below | RULE-NO-TRACK-LABEL: curriculum name only, no "Personal"/"Standard" label | |
| 66 | Tap | **"−"** decrement `_RoundStepButton` (grey circle, left of stepper) | When `canEdit == true` AND `primaryPoints > 1`: pending value decrements by 1; value in stepper display updates; `_hasPendingEdits` becomes true; Save bar activates | Decrement by 1 | |
| 67 | Tap | **"−"** at minimum value (1) | Button rendered with `opacity: 0.45` (`onDecrement` is `null` when value == 1); tap does nothing | Floor at 1 | |
| 68 | Tap | **"+"** increment `_RoundStepButton` (blue circle, right of stepper) | When `canEdit == true`: pending value increments by 1; value updates; `_hasPendingEdits` becomes true; Save bar activates | Increment by 1 | |
| 69 | Tap rapidly | **"+"** many times | Value climbs but never exceeds 9999 (`math.min(9999, ...)`) | Max cap at 9999 | |
| 70 | Observe | **Save All** `FilledButton.icon` in `_SaveBar` when NO pending edits | Button still tappable (always tappable per `_SaveBar` impl); tap shows `l10n.pointSettingsNothingToSaveSnackbar` snackbar | No false "saved" toast on unchanged values | |
| 71 | Tap | **Save All** with pending edits | While `_saving = false` and `_hasPendingEdits = true` and `canEdit = true`: saves all pending values to DB; shows spinner in button; `SnackBar` shows `l10n.pointSettingsSavedSnackbar`; pending map cleared; provider invalidated | Save succeeds | |
| 72 | Observe busy state | During save | Save button shows `CircularProgressIndicator` (22×22) instead of save icon; `onPressed` returns early if `busy` | Save in-flight | |
| 73 | Multiple tracks | 2+ active curricula | Each curriculum gets its own `_CurriculumPointsCard` with independent stepper; save applies all changed tracks atomically | Multi-track | |
| 74 | Tutor with canEditPoints = false | Open as tutor whose `tutorPerms.canEditPoints = false` | `canEdit = false`; both `−` and `+` buttons have `null` onPressed callbacks (rendered at 0.45 opacity); tap on Save All shows `l10n.tutorPermissionDenied` snackbar | Tutor permission denied | |
| 75 | Empty state | Child with no active tracks | `l10n.pointConfigNoActiveTracksBody` centred text; no hero header; no Save bar | Empty state | |
| 76 | Loading state | Initial load | `CircularProgressIndicator` centred | Loading | |
| 77 | Error state | Force provider error | `l10n.errorGeneric(error)` centred text | Error | |
| 78 | RTL / Hebrew | Hebrew locale | Layout RTL; Hebrew subtitle HIDDEN (only shown when `!terms.isHebrew`); numbers remain LTR | RTL; Hebrew subtitle logic | |
| 79 | Dark mode | Dark theme | Cards, steppers, hero header visible | Dark mode | |
| 80 | Offline | Airplane mode; change and save points | DB write succeeds locally; sync snapshot queued; snackbar shown | Offline-first | |
| 81 | System Back | Android back | Returns to parent settings | Back | |

### States to Verify

| State | How to Reach |
|-------|-------------|
| Loading | Slow device |
| Empty (no tracks) | Child profile with no active tracks |
| Data, unmodified | Default view with any active track |
| Data, pending edits | Tap +/− at least once |
| Save in-flight | Tap Save after making edits on slow device |
| Tutor (canEditPoints = false) | Tutor access with canEditPoints = false |
| Error | Force provider error |

---

## 5. RewardConfigurationScreen — `/parent-mode/reward-config`

### How to Reach

**Preconditions**: Active profile is a **child** profile. Must pass `ChildModeGuard` AND `PinGuard`.

**Path A**: `ParentSettingsScreen` → **"Reward Configuration"** row (only shown if `canEditRewards == true`) → `RewardConfigurationRoute`.

**Path B**: `parent_portal_bottom_nav.dart` uses `router.replace(const RewardConfigurationRoute())` (bottom nav).

### Interactive Elements

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 82 | Observe on load | `RewardConfigHeader` — custom app bar | Back button (navy arrow_back_ios_new_rounded left); centred title `l10n.rewardConfigScreenContextLabel`; three-dot menu (more_vert_rounded) right | Header renders | |
| 83 | Tap | **Back button** in `RewardConfigHeader` | `context.maybePop()` | Back navigation | |
| 84 | Tap | **Three-dot menu** (more_vert_rounded) in `RewardConfigHeader` | `PopupMenu` opens with single item: `l10n.rewardConfigMenuManageRewards` | Menu opens | |
| 85 | Tap | **"Manage Rewards"** popup menu item | `_openManageRewardsSheet(l10n)` called; modal bottom sheet opens showing `ManageRewardsList` | Bottom sheet opens | |
| 86 | Dismiss popup menu | Tap outside menu | Menu closes without action | Dismiss | |
| 87 | Observe loading state | While `bootstrap()` runs | Full-screen `CircularProgressIndicator` (Scaffold body) | Loading state | |
| 88 | Observe error state | If `form.error != null` | `AppBar` + `Center(child: Text(form.error!))` | Error state | |
| 89 | Observe | **Avatar picker row** (`AvatarPickerRow`) — 17 icon tiles horizontal | Horizontal scroll of 17 icon tiles; first (index 0, emoji_events_rounded) is selected by default (filled navy border); tappable | 17 choices in `RewardMilestoneIcons.choices` | |
| 90 | Scroll horizontal | `AvatarPickerRow` | Scrolls to reveal all 17 icons | Horizontal scroll | |
| 91 | Tap | Each of the 17 **`AvatarTile`** icon tiles | Tapped tile gets dark navy border (selected); previously selected tile deselects; `notifier.setIconIndex(i)` called; live preview card below updates icon | Icon selection | |
| 92 | Tap | **Reward Name `TextField`** | Keyboard opens; `TrimLeadingSpaceFormatter` prevents leading spaces; `textCapitalization: sentences` | Text input | |
| 93 | Type | Reward name — empty string | `saveReward()` returns `RewardSaveInvalidInput`; Save button effectively disabled (though button is always tappable if `canEdit == true`; no feedback for empty title per code inspection) | Validation: empty name | |
| 94 | Type | Reward name — valid text (e.g. "Ice Cream") | Live preview card title updates to typed text | Live preview | |
| 95 | Type | Reward name — very long text (200+ chars) | Text field accepts it; preview truncates if needed; no input length limit visible in source | Long input | |
| 96 | Tap | **Points `TextField`** | Numeric keyboard opens; `FilteringTextInputFormatter.digitsOnly` prevents non-digit input | Numeric input | |
| 97 | Type | Points — "0" or empty string | `saveReward()` returns `RewardSaveInvalidInput`; no save action; no error feedback visible (button fires but result is invalid input) | Validation: zero/empty points | |
| 98 | Type | Points — valid positive integer (e.g. "100") | Live preview updates to show "100 pts"; `form.previewPoints` reflects the value | Live preview update | |
| 99 | Observe | **`_RewardPreview`** card (blue background) | Shows "PREVIEW" label (navy), icon circle (white circle, 56×56), reward title text, orange dot + points value; updates live as name/points/icon change | Live preview; no interaction | |
| 100 | Tap | **"Cancel"** `TextButton` (grey, below preview) | `notifier.clearForm()` called; name field clears, points field clears, icon resets to index 0; `_lastSyncedName`/`_lastSyncedPoints` sync prevents infinite loops | Clear form | |
| 101 | Tap | **"Save Reward"** `FilledButton` (navy, bottom) when `canEdit == true` and valid input | `_saveReward(l10n)` called; if `RewardSaved`: `AlertDialog` opens with "Reward Created" title and body `l10n.rewardConfigRewardCreatedBody(title)`; form clears; `achievementsOverviewProvider` invalidated | New reward saved | |
| 102 | Tap | **OK** button in success `AlertDialog` | Dialog dismisses; form stays cleared | Dialog dismiss | |
| 103 | Tap Save | When name is provided but points empty/0 | `RewardSaveInvalidInput` returned; no dialog; no snackbar; button appears to do nothing (silent fail — executor should note this) | Validation silent fail — UNCLEAR BEHAVIOUR: executor should probe whether there is visual feedback | |
| 104 | Tap Save | Duplicate `thresholdPoints` value (same points cost as existing reward on same ladder) | `RewardSaveDuplicateThreshold` returned; `SnackBar` shows `l10n.rewardConfigDuplicateThreshold` | Duplicate threshold guard | |
| 105 | Tap Save | No active tracks (edge case — global rewards should still save) | If `state.usesGlobalLadder == true` (which it always is after DEC-32 removal): should save; if `RewardSaveNoTrack` returned: `SnackBar` shows `l10n.rewardConfigNoActiveTracks` | RULE-SPEND-ECONOMY: no per-track split | |
| 106 | Open Manage Rewards sheet | Tap three-dot menu → "Manage Rewards" | Bottom sheet opens; `ManageRewardsList` loads existing milestones via `notifier.milestonesForCurrentLadder()`; list sorted by `thresholdPoints` ascending; loading spinner shows briefly | Sheet opens | |
| 107 | Observe empty manage sheet | No milestones configured yet | `l10n.rewardConfigEmptyMilestones` centred text | Empty list | |
| 108 | Observe each row in `ManageRewardsList` | Each `RewardCard` | Shows: title text, `thresholdPoints` label, `Switch.adaptive` (enabled state), pencil edit `IconButton`, delete (red trash) `IconButton` | Manage row layout | |
| 109 | Tap | **`Switch.adaptive`** toggle on a reward in `ManageRewardsList` | `notifier.toggleEnabled(m)` called; switch state updates; list refreshes via `_refresh()`; if tutor permission denied: sheet closes, error snackbar shown | Toggle enabled/disabled | |
| 110 | Tap | **Edit pencil** `IconButton` on a reward in manage list | Sheet closes (`Navigator.pop(ctx)`); `notifier.applyMilestoneToForm(m)` fills form with reward data (icon, name, points text); form now in "edit" mode (`editingMilestoneId != null`) | Edit mode | |
| 111 | Tap Save after editing | Edit existing reward → change name → Save | `RewardSaved(wasEditing: true)` returned; `AlertDialog` shows "Reward Updated" title/body; form clears | Edit save dialog | |
| 112 | Tap | **Delete (trash)** `IconButton` on a reward in manage list | Sheet closes; `_confirmDelete(m, l10n)` called; `AlertDialog` opens: title `l10n.deleteReward`, content `l10n.deleteRewardConfirm(milestone.title)`, Cancel + Delete buttons | Delete confirmation dialog | |
| 113 | Tap | **Cancel** in delete `AlertDialog` | Dialog dismisses; milestone NOT deleted; form unchanged | Delete cancel | |
| 114 | Tap | **Delete** `FilledButton` in delete `AlertDialog` | `notifier.deleteMilestone(m)` called; milestone removed from DB; if form was editing that milestone: `clearForm()` called; `achievementsOverviewProvider` invalidated | Delete confirmed | |
| 115 | Tutor with canEditRewards = false | Access as tutor with `canEditRewards = false` | Save button fires `ScaffoldMessenger.showSnackBar(l10n.tutorPermissionDenied)` instead of saving; toggle in manage sheet also shows error snackbar; delete also shows error snackbar | RULE-TUTOR-READONLY: `canEdit = tutorPerms == null || tutorPerms.canEditRewards` | |
| 116 | Observe RULE-SPEND-ECONOMY | Inspect the form | No `RewardTypeSegmented` control visible; no track dropdown visible; every reward is global (DEC-32) | RULE-SPEND-ECONOMY | |
| 117 | Offline | Save a new reward offline | DB write succeeds; outbox sync queued; success dialog shown | Offline-first | |
| 118 | RTL / Hebrew | Hebrew locale | Form fields and buttons adapt to RTL; avatar picker scrolls RTL | RTL | |
| 119 | Dark mode | Dark theme | Form card, fields, buttons visible with correct contrast | Dark mode | |
| 120 | System Back | Android back | `context.maybePop()` | Back navigation | |

### States to Verify

| State | How to Reach |
|-------|-------------|
| Loading | `form.loading = true` during `bootstrap()` |
| Error | `form.error != null` (injected error) |
| Empty form (new reward) | Fresh open or after Cancel |
| Edit mode | Open manage sheet → tap edit pencil |
| Manage sheet empty | No milestones exist |
| Manage sheet with milestones | After saving at least one reward |
| Tutor (canEditRewards = false) | Tutor without reward edit permission |
| Duplicate threshold | Enter same points cost as existing reward |
| Post-save success dialog | After valid save |

---

## 6. AchievementUnlockCelebration Widget (Full-screen Dialog)

### How to Reach

`AchievementUnlockCelebration.showForUnlockedMilestones()` is called from the learning completion flow (in `completion_repository_impl.dart`) when `newUnlocks.isNotEmpty`. It fires on the reading/learning screen immediately after marking a task complete for the first time that crosses a milestone threshold.

**Precondition**: Child profile; at least one enabled reward milestone configured; child's points total (from marking a task complete) crosses a milestone `thresholdPoints` for the first time.

**How to trigger**: In child mode, mark a learning task complete when you know the post-completion points total will equal or exceed a milestone threshold that has not been celebrated before (SharedPreferences `done` key not set).

The `_celebrationInFlightProvider` (Riverpod `NotifierProvider<bool>`) guards against concurrent dialogs.

### Interactive Elements

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 121 | Observe on open | `_UnlockPartyDialog` overlay | Full-screen transparent `Dialog` (insetPadding = EdgeInsets.zero); two `ConfettiWidget` layers (burst from centre + shower from top); centred modal card (width 340) with rounded corners and gradient background | Confetti fires immediately via `addPostFrameCallback` | |
| 122 | Observe | Confetti animation | Two controllers: `_burstCenter` (explosive, 36 particles) + `_shower` (directional from top, 14 particles); both play for 5 seconds; 7 party colours used | Visual spectacle | |
| 123 | Observe | `🎉` emoji heading | Large emoji (fontSize 52) at top of modal card | Display | |
| 124 | Observe | Title text | `l10n.achievementsUnlockPartyTitle` — bold orange-red headline | Display | |
| 125 | Observe | Body message | `l10n.achievementsUnlockPartyMessage(displayName, milestoneTitle, trackLabel)` — uses child's display name (or fallback `l10n.achievementsUnlockPartyNameFallback`), the milestone title, and the track label | Personalised message | |
| 126 | Tap | **"🎉 Claim!"** (or localised equivalent) `FilledButton` (brand blue) | `Navigator.of(context).pop()` — dialog dismisses; confetti controllers stopped in `dispose()`; `_celebrationInFlightProvider.finish()` called; milestone ID added to SharedPreferences `done` set so it won't show again | Dismiss by button | |
| 127 | Wait 5 seconds without tapping | Auto-close `Timer` | Dialog auto-closes after 5 seconds (`_autoClose` Timer); same `pop()` path | Auto-dismiss | |
| 128 | Tap | Barrier (outside modal card, dark overlay) | `barrierDismissible: true` → dialog dismisses; same `pop()` path | Dismiss by barrier | |
| 129 | Trigger twice rapidly | Unlock two milestones at once (or trigger before in-flight finishes) | `_celebrationInFlightProvider` guard: if `inFlight == true`, second call returns early; only one dialog shown at a time | In-flight guard | |
| 130 | Verify no re-show | After dismissal, navigate back to GamificationScreen | Milestone ID in SharedPreferences `done` set; `migrateDoneKeysIfNeeded` seeds it; celebration does NOT re-appear | SharedPrefs persistence | |
| 131 | Profile switch | Switch profiles while dialog is in-flight | `_celebrationInFlightProvider` is auto-disposed on profile context reset; no crash; dialog completes or is dismissed by route pop | Profile switch safety | |
| 132 | Adult mode | Complete task as adult | `AchievementUnlockCelebration.showForUnlockedMilestones` is only called from completion handler when the profile earns points; adults do not earn points (confirmed by `PointsDisplayWidget.userMode.isAdult` guard and dashboard logic); celebration should never fire for adults | RULE-ADULT-NO-POINTS | |
| 133 | RTL | Hebrew locale | Modal card text RTL; title/body use RTL; confetti unaffected | RTL | |
| 134 | Dark mode | Dark theme | Modal card gradient is hardcoded (not theme-dependent); confetti colours hardcoded; card renders correctly in dark mode | Dark mode | |

### States to Verify

| State | How to Reach |
|-------|-------------|
| Fresh unlock (first time) | Points cross milestone threshold for first time |
| Already seen (no re-show) | Same milestone — celebration suppressed by SharedPrefs |
| Auto-close | Wait 5 s without interaction |
| Manual dismiss (button) | Tap claim button |
| Barrier dismiss | Tap outside modal |
| In-flight guard (no double dialog) | Two milestones crossed in same session |

---

## Cross-Cutting Checks (All Gamification Screens)

| # | Check | How to Verify | Product Rule |
|---|-------|---------------|-------------|
| 135 | Adults have NO points UI | Switch to adult profile; open Dashboard, Progress screen | RULE-ADULT-NO-POINTS: `PointsDisplayWidget` hidden; ⭐ counter tile absent; `ChildPointsRewardsTabCard` absent |
| 136 | No track-type label | Inspect all filter chips, card labels, manage list rows, point config cards | RULE-NO-TRACK-LABEL: never "Personal", "Standard", "Custom", "אישי" |
| 137 | Route guards fail-safe | Corrupt DB mode value; attempt to open child-guarded routes | ChildModeGuard catches exception and calls `resolver.next(false)`; no permanent hang |
| 138 | PIN guard on parent routes | Access `/parent-mode/pending-redemptions`, `/parent-mode/point-config`, `/parent-mode/reward-config` | PinGuard prompts for PIN; cannot bypass |
| 139 | Tutor RULE-TUTOR-READONLY | Tutor session; attempt live-mark from learning screen | `canMarkLiveCompletion` always false; mark-complete affordance absent |
| 140 | Offline sync | All gamification write operations (redemption, point config save, reward save, fulfil/decline) | Writes succeed locally; outbox queued; sync status informational only |
| 141 | No progress-bar crash for 0-threshold milestone | Edge case: `thresholdPoints == 0` | `_progressFraction` guards `th <= 0 → 0`; `_percentRounded` guards `th <= 0 → 0`; no division-by-zero |



## Cluster: Progress / Siyumim / Lifetime

### Navigation topology

```
Bottom nav tab 2 (Progress icon, l10n.tabBarProgress)
  └── ProgressScreen                          /progress
        ├── _RecentActivityLensTile  ──────►  RecentActivityScreen            /progress/recent
        ├── _SiyumimMilestonesLensTile ─────► SiyumimMilestonesScreen         /progress/siyumim
        │         └── (SiyumimGroupedView / SiyumimTimelineView sub-widgets)
        ├── _LifetimeKnowledgeLensTile ─────► LifetimeKnowledgeScreen         /progress/lifetime
        │         └── _LifetimeMarkingCta ──► LifetimeMarkingScreen           /settings/lifetime-marking
        └── _PerTrackRow (one per active track) ─► CurriculumProgressScreen   /curriculum/:id/progress
```

Tutor access path: an adult account granted tutor role may deep-link to
`SiyumimMilestonesScreen?profileId=<child>` via parent management surfaces.
The AppBar then reads `l10n.journeyTitleNamed(profileName)`.

---

## Screen 1: ProgressScreen (ProgressRoute — `/progress`)

### How to reach
Launch the app while signed in with any profile → tap the **Progress** bottom-nav tab (index 2, fire-graph icon). Profile must have at least one active track to see content; zero active tracks shows the EmptyState.

### Test-step table

| # | Action | Element | Expected result | Product rule / fix | P/F/Notes |
|---|--------|---------|-----------------|-------------------|-----------|
| 1 | Observe screen on first land (≥1 active track, child profile) | Entire screen | Four counter cells visible in ProgressTierCounterRow: 🔥 Streak · 🏆 Siyumim · 📚 Lifetime · ⭐ Points. Points cell present only for CHILD profile. | Adults have no points/gamification rule. |  |
| 2 | Observe screen (adult profile, ≥1 active track) | ProgressTierCounterRow | Only 3 counter cells: 🔥 🏆 📚 — no ⭐ Points cell. | Adults have no points/gamification rule. |  |
| 3 | Observe counters while providers are loading | Counter cells | Each cell displays "…" (ellipsis placeholder) until ALL providers resolve; no cell shows "0" while another has real data. | Redesign brief §2 — no "1336 vs 0" flash. |  |
| 4 | Observe counters after data loads | All three (or four) cells | Numbers are locale-formatted (thousands separator "," in en-US; same in he-IL). | Locale-aware format. |  |
| 5 | Observe "ACTIVE TRACKS" section label | Section header | Text reads "ACTIVE TRACKS" (uppercase, muted) with no track-type qualifier ("Personal", "Standard", "Custom"). | No track-type label rule. |  |
| 6 | Observe each _PerTrackRow card | Per-track row | Shows curriculum icon + curriculum name (via `curriculumLabelText`) + "Track progress: N%" + "Lifetime: N%" — no track type label. | No track-type label rule. |  |
| 7 | Tap **Recent Activity** lens tile (fire icon) | _RecentActivityLensTile InkWell | Navigates to RecentActivityScreen. | Route guard must not hang. |  |
| 8 | System Back from RecentActivityScreen | Android back gesture/button | Returns to ProgressScreen; no crash, no stuck navigation. | Route guards fail-safe fix. |  |
| 9 | Tap **Siyumim & Milestones** lens tile (trophy icon) | _SiyumimMilestonesLensTile InkWell | Navigates to SiyumimMilestonesScreen. |  |  |
| 10 | System Back from SiyumimMilestonesScreen | Android back | Returns to ProgressScreen cleanly. |  |  |
| 11 | Tap **Lifetime Knowledge** lens tile (book icon) | _LifetimeKnowledgeLensTile InkWell | Navigates to LifetimeKnowledgeScreen. |  |  |
| 12 | System Back from LifetimeKnowledgeScreen | Android back | Returns to ProgressScreen cleanly. |  |  |
| 13 | Tap first _PerTrackRow card (e.g. Mishnayos) | _PerTrackRow InkWell | Navigates to CurriculumProgressScreen with matching curriculumId path param. |  |  |
| 14 | Tap second _PerTrackRow card (different curriculum) | Second _PerTrackRow | Navigates to the correct CurriculumProgressScreen for that curriculum. |  |  |
| 15 | System Back from CurriculumProgressScreen | Android back | Returns to ProgressScreen cleanly. |  |  |
| 16 | Pull-to-refresh on ProgressScreen (scroll down, pull) | RefreshIndicator | Spinner appears; on release, `progressLensRefreshTickProvider` is bumped, `dashboardActiveCurriculaStreamProvider`, `dashboardStreakProvider`, `dashboardGlobalPointsProvider`, `journeyViewModelProvider`, `lifetimeTotalsAcrossAllCurriculaProvider`, and `trackDualProgressMetricsProvider` are invalidated and re-fetched. Counters reload. | Refresh fix F25. |  |
| 17 | Pull-to-refresh while offline | RefreshIndicator | Spinner completes; cached data remains displayed; no crash. | Offline-first guarantee. |  |
| 18 | Observe in zero-active-tracks state | Whole body | EmptyState widget shown with `progressNoDataTitle` + `progressNoDataSubtitle` + trending-up icon. No counter row, no lens tiles, no per-track section. | |  |
| 19 | Observe error state (provider fails) | activeCurriculaAsync error branch | Error text with `l10n.errorWithMessage(...)` shown centered. | |  |
| 20 | Observe loading state (provider loading) | activeCurriculaAsync loading branch | `CircularProgressIndicator` shown centered. | |  |
| 21 | Verify no "Personal"/"Standard"/"Custom" text anywhere | Entire screen (visual scan) | No track-type label visible anywhere on the screen including per-track rows. | No track-type label rule. |  |

### States to verify

| State | How to reach | What to assert |
|-------|-------------|---------------|
| Loading | Fresh install / clear cache, open Progress tab | CircularProgressIndicator in center; counters show "…" |
| Empty | Profile with no active tracks | EmptyState widget with icon + message |
| Error | Cut network + force-clear DB; open Progress tab | `errorWithMessage` text in center |
| Offline (data present) | Toggle airplane mode; open Progress tab | Cached data displays normally |
| Child mode | Sign in as CHILD profile | 4-counter row including ⭐ Points |
| Adult mode | Sign in as ADULT profile | 3-counter row, no ⭐ |
| Hebrew/RTL | Device locale = Hebrew | Layout mirrors; counter labels use Hebrew terms |
| Dark mode | Enable dark theme | Colors invert correctly; white card shadows visible |

---

## Screen 2: RecentActivityScreen (RecentActivityRoute — `/progress/recent`)

### How to reach
Progress tab → tap **Recent Activity** lens tile. Alternatively, from the Learning screen (a separate shortcut path exists in `learning_screen.dart`).

### Preconditions
At least one active track. The chazara UI elements (second bar colour, "& Chazaros" in chart title, chazara tile in AllTimeSummaryCard) appear only when `anyActiveTrackHasChazaraProvider` resolves `true`. Test both states explicitly.

### Test-step table

| # | Action | Element | Expected result | Product rule / fix | P/F/Notes |
|---|--------|---------|-----------------|-------------------|-----------|
| 1 | Observe screen on open | Entire screen | AppBar-style row shows back button (left), centred title "Recent Activity", right spacer. Time-range pills row below. Curriculum filter chips row. Streak header card. Charts section. | |  |
| 2 | Tap back button (left `IconButton`) | `Icons.arrow_back_ios_new_rounded` | Navigates back to ProgressScreen via `context.maybePop()`. | Route guards fail-safe fix. |  |
| 3 | System Back gesture | Android back | Same as above; no stuck navigation. |  |  |
| 4 | Observe time-range selector default | Three range pills | "Last 7 days" is selected (highlighted in `AppColors.blueMid`). |  |  |
| 5 | Tap **Last 7 days** pill | GestureDetector | Already selected; _timeRange = last7Days; charts reload with 7-day window. |  |  |
| 6 | Tap **Last 30 days** pill | GestureDetector | Selected state switches; charts reload with 30-day window (29-day lookback). |  |  |
| 7 | Tap **All time** pill | GestureDetector | Selected state switches; charts reload with `kChartAllTimeFloor` start; streak section shows `_AllTimeSummaryCard` (three stat cells: Active days, Limudim done, Chazaros done) instead of the `StreakCalendar` grid. | F18 — All Time cap prevents ~9,600 widget explosion. |  |
| 8 | Observe AllTimeSummaryCard with chazara-disabled track | AllTimeSummaryCard | Only two stat cells: "Active days" + "Limudim done" — "Chazaros done" cell absent. | Chazara UI renders ONLY when track has chazaraEnabled rule. |  |
| 9 | Observe AllTimeSummaryCard with chazara-enabled track | AllTimeSummaryCard | Three stat cells visible including Chazaros done. | Chazara rule. |  |
| 10 | Tap **All** curriculum chip | _FilterPill "All" | `_curriculum = null`; all curriculum chips deselected; charts reload unfiltered. |  |  |
| 11 | Tap a specific curriculum chip (e.g. Mishnayos) | _FilterPill for that curriculum | That chip selected; charts reload filtered by that curriculum; note on streak card appears: "Streak is shown across all curricula" (`labelStreakAcrossAllCurricula`). | F11 — curriculum filter wired end-to-end into calendar. |  |
| 12 | Tap same curriculum chip again | Same _FilterPill | Chip deselects (toggling behaviour); `_curriculum = null` again. |  |  |
| 13 | Tap a different curriculum chip while one is already selected | Different _FilterPill | Switches to new curriculum; previous chip deselects. |  |  |
| 14 | Scroll the curriculum chip row horizontally | SingleChildScrollView | All curriculum chips accessible without layout overflow. |  |  |
| 15 | Observe streak header card — Last 7 / Last 30 states | _StreakHeaderCard | Current streak number and day label, personal best on the right, streak pill badge (red) top-right. StreakCalendar dot grid shows days in range. |  |  |
| 16 | Observe streak number | Streak display text | The large number is the profile-global live streak (from `dashboardStreakProvider`) regardless of which curriculum chip is active. | Global streak rule (F11). |  |
| 17 | Observe "STREAK" label | Label text | Shown in uppercase muted letterSpacing style. |  |  |
| 18 | Observe StreakCalendar dot colours | StreakCalendar grid | Days with live completions (within curriculum filter if active) are highlighted; bulk-marked/sentinel-date items do NOT appear as active dots. | Sentinel-date / bulk-mark NOT in streak/recent activity rule. |  |
| 19 | Observe Limudim & Chazaros chart section title (chazara-enabled track) | _ChartSection title | Title = "{Limud term} & {Chazaros term}". Both terms follow the Hebrew Terms toggle. | Chazara rule; Hebrew terms toggle. |  |
| 20 | Observe Limudim chart section title (no chazara track) | _ChartSection title | Title = just "{Limud term}" — no "& Chazaros" suffix. | Chazara UI renders ONLY when track has chazaraEnabled rule. |  |
| 21 | Observe subtitle under each chart section | _ChartSection subtitle | Reads `l10n.recentActivityLiveOnlyDisclaimer` (e.g. "Live learning only"). | Sentinel/bulk NOT in recent activity rule. |  |
| 22 | Observe loading state of Limudim chart | `_LimudChazaraChartBody` loading | `LoadingIndicator` with loading message shown inside the 200px height box. |  |  |
| 23 | Observe error state of Limudim chart | `_LimudChazaraChartBody` error | `ErrorDisplay` with `chartFailedToLoad` message + Retry button. |  |  |
| 24 | Tap **Retry** on Limudim chart error | ErrorDisplay onRetry | `recentActivityLimudimChazarosProvider(window)` is invalidated; chart re-fetches. |  |  |
| 25 | Observe loading state of Cumulative chart | `_CumulativeChartBody` loading | `LoadingIndicator` inside 150px box. |  |  |
| 26 | Observe error state of Cumulative chart + retry | `_CumulativeChartBody` error | ErrorDisplay + Retry invalidates `recentActivityCumulativeProvider(window)`. |  |  |
| 27 | Observe streak error state | `_StreakHeaderCard` error | `chartFailedToLoad` text shown. |  |  |
| 28 | Tap Retry on streak error (Last 7 / Last 30 only) | ErrorDisplay in streak card | Invalidates `recentActivityStreakDatesProvider(window)`. |  |  |
| 29 | Observe Points chart section visibility (CHILD mode) | `if (userMode.isChild)` guard | Points chart and `_PointsTotalLabel` visible; section title `chartPointsEarned` shown. | Adults have no points/gamification rule. |  |
| 30 | Observe Points chart section visibility (ADULT mode) | Same guard | Entire Points section absent. | Adults have no points/gamification rule. |  |
| 31 | Observe `_PointsTotalLabel` value | Label text (CHILD mode) | Shows `l10n.tierCounterPoints(total)` total for window; shows "--" while loading. |  |  |
| 32 | Observe bulk-marked items in Last 7 days bar chart | LimudimChazarosBarChart | Items marked via bulk-marking sentinel date (2000-01-01) do NOT create a bar on the 7-day or 30-day windows. They would only appear in "All time" at the year-2000 bucket. | Sentinel-date NOT in streak/recent activity rule. |  |
| 33 | Pull-to-refresh the screen | ListView + `progressLensRefreshTickProvider` | No explicit RefreshIndicator on this screen (it uses a plain ListView). Refresh is triggered via `progressLensRefreshTickProvider.bump()` from the hub's pull-to-refresh instead. VERIFY: after bumping the tick from ProgressScreen, navigating to RecentActivity shows fresh data. | F25 — lens providers watch the tick. |  |
| 34 | Observe entire screen offline | All providers | Cached data displayed; no crash; charts show last-known values. | Offline-first guarantee. |  |

### States to verify

| State | How to reach |
|-------|-------------|
| Loading | Invalidate providers + re-open |
| Error | Kill DB access; retry buttons present |
| Offline | Airplane mode; cached data shown |
| No-chazara tracks | Profile with only non-chazara tracks — Chazaros column/cell absent |
| Chazara-enabled tracks | Profile with chazara track — Chazaros column present |
| Child mode | CHILD profile — Points section visible |
| Adult mode | ADULT profile — Points section absent |
| Hebrew/RTL | he locale — chart labels in Hebrew terms |
| Dark mode | Dark theme enabled |

---

## Screen 3: SiyumimMilestonesScreen (SiyumimMilestonesRoute — `/progress/siyumim`)

### How to reach
Progress tab → tap **Siyumim & Milestones** lens tile.

Tutor path: adult in tutor mode for a child account may navigate via parent management; AppBar title becomes `journeyTitleNamed(profileName)` when `?profileId=N` query param is present.

Preconditions: profile must have at least one ledger entry for any siyum to appear. Without entries the screen shows `_EmptyState`.

### Test-step table

| # | Action | Element | Expected result | Product rule / fix | P/F/Notes |
|---|--------|---------|-----------------|-------------------|-----------|
| 1 | Observe AppBar on own profile | AppBar title | Title = `l10n.tierLensSiyumimMilestones` ("Siyumim & Milestones" / "סיומים והישגים"). |  |  |
| 2 | Observe AppBar when profileId param provided (tutor/parent view) | AppBar title | Title = `l10n.journeyTitleNamed(profileName)` — person's name in the title. |  |  |
| 3 | Tap back button (AppBar leading) | AppBar back | Returns to ProgressScreen cleanly. | Route guards fail-safe fix. |  |
| 4 | Observe loading state | Entire body | `LoadingIndicator` centered. |  |  |
| 5 | Observe error state | Error widget | `ErrorDisplay` with `failedToLoadJourney(error)` message + Retry button. |  |  |
| 6 | Tap **Retry** in error state | ErrorDisplay onRetry | Invalidates `journeyViewModelProvider(effectiveProfileId)`. |  |  |
| 7 | Observe empty state (no milestones) | _EmptyState | `auto_stories` icon (80px) + `journeyEmptyTitle` + `journeyEmptyBody` text. |  |  |
| 8 | Observe top counters card (_LevelCountersCard) with data | Card with 3 rows | Three rows in order: 🏆 curriculum-level count (titleLarge, primary colour), workspace_premium aggregate count (titleMedium, secondary), ⭐ unit-level count (titleMedium, tertiary). |  |  |
| 9 | Observe counter rows when count = 0 | _CounterRow | Rows with count = 0 are rendered at opacity 0.38 (dimmed), NOT hidden. Spatial three-row layout preserved. | F15 — zero rows dimmed not hidden. |  |
| 10 | Observe counter rows when count > 0 | _CounterRow | Full opacity. Correct numeric value displayed. |  |  |
| 11 | Observe counter labels | _CounterRow labels | Labels are pluralised via l10n ARB template (`siyumimLevelCurriculum(n)`, etc.). |  |  |
| 12 | Observe default SegmentedButton state | SegmentedButton | "By curriculum" (grid icon) segment is selected by default. |  |  |
| 13 | Tap **Timeline** segment | SegmentedButton chronological | `journeySortModeProvider` set to `chronological`; body switches to `SiyumimTimelineView`. |  |  |
| 14 | Tap **By curriculum** segment | SegmentedButton grouped | `journeySortModeProvider` set to `grouped`; body switches to `SiyumimGroupedView`. |  |  |
| 15 | Pull-to-refresh from either view | RefreshIndicator | Invalidates `journeyViewModelProvider(effectiveProfileId)`; data reloads. |  |  |
| --- | **SiyumimGroupedView (Grouped mode)** | | | |  |
| 16 | Observe grouped view with milestones | SiyumimGroupedView | One `_CurriculumSection` card per curriculum that has milestones. Curricula with no milestones are hidden. |  |  |
| 17 | Observe curriculum card header | Container in Card | Background colour = `curriculumColor.withAlpha(0.08)`. Curriculum name rendered via `CurriculumLabel.curriculum(...)`. No track-type label. | No track-type label rule. |  |
| 18 | Observe curriculum-complete hero card (if earned) | _CurriculumCompleteHero | Gold border, gradient background, `emoji_events` icon, localised siyum label (e.g. "Siyum HaShas"), date in `DateFormat.yMMMd` format. |  |  |
| 19 | Observe aggregate-level tile | _AggregateMilestoneTile ExpansionTile | `workspace_premium` icon in accent colour, "Siyum Seder {name}" label, subtitle with contained unit count + date. |  |  |
| 20 | Tap aggregate ExpansionTile header | ExpansionTile | Expands to show `containedUnitKeys` list with `check_circle_outline` icons. |  |  |
| 21 | Tap expanded aggregate ExpansionTile again | ExpansionTile | Collapses. |  |  |
| 22 | Observe unit-level standalone tile | _UnitMilestoneTile ListTile | `star` icon in accent colour, `siyumMasechta(name)` / `siyumSefer(name)` / `siyumSiman(name)` / `siyumHilchos(name)` label depending on entryScope; date in `DateFormat.yMMMd`. |  |  |
| 23 | Observe date format on all milestone tiles | All date labels | Locale-aware format via `DateFormat.yMMMd(locale)`: "May 11, 2026" in en-US, "11 May 2026" in en-GB/he-IL. No "d/M/yyyy" numeric form. |  |  |
| 24 | Observe no provenance label on any tile | All milestone tiles | No "via bulk-mark", "Live", "Bulk-marked" text anywhere on this screen. | IA brief §4 — no provenance label on siyumim screen. |  |
| 25 | Observe unit milestone label for Bavli masechta | Unit tile | "Siyum Masechta Berakhot" (or Hebrew equivalent if Hebrew Terms on). |  |  |
| 26 | Observe curriculum-complete label for Bavli | Hero card | "Siyum HaShas" (or Hebrew). |  |  |
| 27 | Observe curriculum-complete label for Chumash | Hero card | "Siyum HaTorah" (or Hebrew). |  |  |
| 28 | Observe grouped view empty state | No visible curricula | `siyumimEmptyState` text centered. |  |  |
| --- | **SiyumimTimelineView (Timeline mode)** | | | |  |
| 29 | Observe timeline view structure | SiyumimTimelineView | Month headers ("May 2026") then `_TimelineCard` rows within each month, newest-first overall sort. |  |  |
| 30 | Observe timeline card | _TimelineCard | Leading icon (🏆 curriculum / workspace_premium aggregate / ⭐ unit), `CurriculumLabel.curriculum(...)` subtitle + " · {date}", title = localised siyum label. |  |  |
| 31 | Observe timeline date format | _TimelineCard subtitle | Same `formatMilestoneDate` locale-aware format as grouped view. |  |  |
| 32 | Observe sentinel/bulk-marked milestone achievedAt date | Any bulk-marked milestone in timeline | achievedAt = 2000-01-01 (sentinel) — will appear in the "January 2000" month group, not in a recent month. It IS visible here (siyumim are credited regardless of source) but grouped in year 2000. | Bulk/lifetime marking credits siyumim rule. |  |
| 33 | Scroll timeline with many milestones | ListView | Smooth scroll; no duplicate months; each milestone appears exactly once. |  |  |
| 34 | Observe timeline empty state | No entries | "No siyumim to show" text centered. |  |  |
| 35 | Verify siyum count in top counter matches visible milestone rows | Counter card vs body | Sum of rows in grouped/timeline view equals the total from unit + aggregate + curriculum counter numbers. |  |  |

### Sentinel-date marks — critical assertions

| # | Scenario | Expected |
|---|----------|---------|
| S1 | Profile has bulk-marked items (via Lifetime Marking) in Mishnayos | Siyum Masechta rows for those masechtot appear in grouped and timeline views with `achievedAt = 2000-01-01` (sentinel). Month header = "January 2000". |
| S2 | Same bulk-marked items on RecentActivityScreen | Those items do NOT appear as streak dots in Last 7 / Last 30 calendar. They do NOT appear as bars in the Limudim bar chart within Last 7 / Last 30 windows. They MAY appear in the All Time window under year 2000 bucket. |
| S3 | Top counters include sentinel siyumim | The unit-level siyumim counter includes siyumim earned via bulk/lifetime marking (because siyumim credit is source-agnostic). |

### States to verify

| State | How to reach |
|-------|-------------|
| Loading | Invalidate journeyViewModelProvider; re-open |
| Empty | Profile with no ledger entries |
| Error | DB access failure; Retry button present |
| Own profile | Normal navigation |
| Other profile (tutor/parent) | Append ?profileId=N; AppBar title shows name |
| Grouped view | Default / tap "By curriculum" segment |
| Timeline view | Tap "Timeline" segment |
| Offline | Airplane mode; cached data shown |
| Hebrew/RTL | he locale; siyum labels in Hebrew |
| Dark mode | Dark theme |

---

## Screen 4: LifetimeKnowledgeScreen (LifetimeKnowledgeRoute — `/progress/lifetime`)

### How to reach
Progress tab → tap **Lifetime Knowledge** lens tile.

### Test-step table

| # | Action | Element | Expected result | Product rule / fix | P/F/Notes |
|---|--------|---------|-----------------|-------------------|-----------|
| 1 | Observe AppBar | AppBar title | "Lifetime Knowledge" / "ידע כולל". Cream background, no elevation, no surface tint. |  |  |
| 2 | Tap AppBar back arrow | AppBar leading back | Returns to ProgressScreen. | Route guards fail-safe fix. |  |
| 3 | Observe header card (_LifetimeHeaderCard) | DecoratedBox card | Shows `menu_book_outlined` icon, items-learned count (via `terms.itemsLearnedCount`), total chazaros count (via `terms.totalChazaros`). Both numbers reflect current toggle state. | F3 — header counters follow source toggle. |  |
| 4 | Observe header card loading state | AsyncValue loading | `LoadingIndicator(size: 24)` shown inside 48px height SizedBox. |  |  |
| 5 | Observe header card error state | AsyncValue error | Error text + "Retry" TextButton. |  |  |
| 6 | Tap **Retry** in header error | TextButton | Invalidates `lifetimeHeaderCountersProvider` or `trackOnlyHeaderCountersProvider` depending on current toggle. |  |  |
| 7 | Observe default toggle state | _LifetimeSourceToggle SegmentedButton | "All sources" (public_outlined icon) segment selected. |  |  |
| 8 | Tap **Track learning only** segment | SegmentedButton | `_filter` → `trackOnly`; body re-fetches `itemsLearnedSummariesProvider`; header counters re-fetch `trackOnlyHeaderCountersProvider`. Body excludes `lifetimeOnly` items. | B1 lifetime tier: "Track only" excludes lifetimeOnly. |  |
| 9 | Tap **All sources** segment | SegmentedButton | `_filter` → `allSources`; body re-fetches `lifetimeViewSummariesProvider`; header counters re-fetch `lifetimeHeaderCountersProvider`. Body includes lifetimeOnly items. |  |  |
| 10 | Observe header numbers change on toggle | Header card values | Items-learned and total-chazaros numbers update when switching toggle; "All sources" ≥ "Track only" for items-learned. | F3. |  |
| 11 | Observe body loading state | Expanded body area | `LoadingIndicator` with `lifetimeKnowledgeLoading` message centered at top: 48 padding. |  |  |
| 12 | Observe body error state + retry | ErrorDisplay in body | `lifetimeKnowledgeLoadError(error)` + Retry invalidates the right summaries provider for the active toggle. |  |  |
| 13 | Observe body empty state | EmptyState | `itemsLearnedNoCurricula` + subtitle + `menu_book_outlined` icon when no progress exists. |  |  |
| 14 | Observe CurriculumBreakdownList | Scrollable list | One `_CurriculumCard` per curriculum that has `learnedLeafCount > 0`, sorted by `curriculumId.index`. Curricula with 0 progress are hidden. |  |  |
| 15 | Observe a curriculum card | _CurriculumCard | Progress circle with percentage text (small, bold) + curriculum label + Hebrew name (if Hebrew Terms off) + "N of M" count + expand/collapse chevron + linear progress bar. No track-type label. | No track-type label rule. |  |
| 16 | Tap a curriculum card to expand | _CurriculumCard InkWell | Tree expands showing `CurriculumBreakdownTreeNode` rows. Chevron flips to up arrow. |  |  |
| 17 | Tap same curriculum card to collapse | _CurriculumCard InkWell | Tree collapses. Chevron flips to down arrow. |  |  |
| 18 | Observe tree node (parent node with children) | CurriculumBreakdownTreeNode | State dot: gold = full, blue-50% = partial, outline = none. Expand/collapse arrows on parent nodes. |  |  |
| 19 | Tap a parent tree node | CurriculumBreakdownTreeNode InkWell | Expands to show child nodes. |  |  |
| 20 | Tap same parent tree node | Same InkWell | Collapses. |  |  |
| 21 | Observe provenance label on terminal leaf ("All sources" toggle) | CurriculumBreakdownTreeNode terminal | Small italic label: "Live", "Live · N chazaros" (N > 1), "Bulk-marked", or "Lifetime · imported". | Provenance labels shown on Lifetime Knowledge (NOT on siyumim screen). |  |
| 22 | Observe provenance "Live · N chazaros" with N > 1 | Terminal leaf | Label shows "Live · {chazarosCount} {terms.chazaros}" — count > 1 needed for this variant. |  |  |
| 23 | Observe provenance label ("Track only" toggle) | Terminal leaf in Track-only view | Only "Live" or "Bulk-marked" provenance labels — never "Lifetime · imported" since lifetimeOnly excluded. |  |  |
| 24 | Observe chazara columns in Track-only view (no-chazara track) | `terms.totalChazaros` in header | When active track has chazaraEnabled = false, the chazaros count is 0 / hidden. | Chazara UI renders ONLY when track has chazaraEnabled rule. |  |
| 25 | Observe bottom CTA (_LifetimeMarkingCta) | InkWell row | Always visible (not inside scroll, anchored at bottom). Shows `add_circle_outline_rounded` icon + `lifetimeKnowledgeAddCta` title + `lifetimeKnowledgeAddCtaSubtitle` subtitle + chevron. |  |  |
| 26 | Tap **Lifetime Marking CTA** | _LifetimeMarkingCta InkWell | Navigates to `LifetimeMarkingRoute` (Settings lifetime-marking screen). |  |  |
| 27 | System Back from LifetimeMarkingScreen | Android back | Returns to LifetimeKnowledgeScreen with filter state intact (allSources or trackOnly unchanged). |  |  |
| 28 | Verify "All sources" includes bulk/lifetime-only items | Compare toggle states | When toggle = "All sources", a profile with Lifetime Marking items shows higher items-learned count than "Track only". | Sentinel-date credits lifetime but NOT streak/recent activity. |  |
| 29 | Verify "Track only" excludes lifetime-only items | Body with track-only toggle | Items learned via Settings → Lifetime Marking (`lifetimeOnly` source) do NOT appear in the "Track learning only" tree. | B1 tier policy. |  |
| 30 | Verify no "Personal"/"Standard"/"Custom" text | Entire screen | No track-type label anywhere including curriculum cards. | No track-type label rule. |  |

### States to verify

| State | How to reach |
|-------|-------------|
| Loading | Invalidate summaries provider; reopen |
| Error | DB failure; retry buttons present |
| Empty | Profile with no completions at all |
| All sources | Default toggle (lifetimeOnly included) |
| Track only | Toggle to "Track learning only" |
| Expanded tree | Tap curriculum card |
| Offline | Airplane mode; cached data |
| Hebrew/RTL | he locale |
| Dark mode | Dark theme |

---

## Screen 5: CurriculumProgressScreen (CurriculumProgressRoute — `/curriculum/:curriculumId/progress`)

### How to reach
Progress tab → tap any _PerTrackRow card. Path param `curriculumId` = curriculum storageKey (e.g. "mishnayos").

### Test-step table

| # | Action | Element | Expected result | Product rule / fix | P/F/Notes |
|---|--------|---------|-----------------|-------------------|-----------|
| 1 | Observe AppBar title (English terms off) | AppBar title column | Primary: curriculum name (via `CurriculumLabel.curriculum`). Secondary: Hebrew name (via `curriculumHebrewName`). Secondary line absent when Hebrew Terms are ON. |  |  |
| 2 | Observe AppBar title (Hebrew terms on) | AppBar title | Only one text line — Hebrew name used as primary, secondary line absent. |  |  |
| 3 | Tap AppBar back | AppBar leading back | Returns to ProgressScreen. |  |  |
| 4 | Observe loading state | Body | `LoadingIndicator(message: 'Loading progress...')` centered with 48 top padding. |  |  |
| 5 | Observe error state | ErrorDisplay | "Failed to load progress: {error}" + Retry button. |  |  |
| 6 | Tap **Retry** on error | ErrorDisplay onRetry | Invalidates `curriculumProgressProvider(curriculumId)`. |  |  |
| 7 | Observe PaceIndicator (when pace data available) | PaceIndicator | Pace indicator shown above OverallStatsCard with `paceLiveLearningOnlyCaption` subtitle. When pace is null/loading/error → SizedBox.shrink() (silently hidden). |  |  |
| 8 | Observe OverallStatsCard | Gradient blue card | "Overall Progress" title. DualStatsRow: "Track progress: X%" and "Lifetime: Y%" side-by-side. Divider. Then: Total items, Completed all stages, In progress, Not started counts. |  |  |
| 9 | Observe DualStatsRow Track progress fraction | DualStatsRow left cell | Value = `completedAllStages / totalItems` (current cycle, achieves-all-stages gate). |  |  |
| 10 | Observe DualStatsRow Lifetime fraction | DualStatsRow right cell | Value = `learnedLeafCount / totalLeafCount` from `lifetimeDataProvider` (includes bulk + lifetimeOnly). Shows "—" while loading. |  |  |
| 11 | Observe "Breakdown by Level" section | Section heading | "Breakdown by Level" text (hardcoded English — CANNOT DETERMINE if this is localized from source; executor should check). |  |  |
| 12 | Observe HierarchyProgressCard (flat, no sublevels) | _HierarchySurfaceCard | Single card with level name, progress bar, completion stats. No expand control. |  |  |
| 13 | Observe HierarchyProgressCard (with sublevels) | _ExpandableHierarchyCard | ExpansionTile-style card; tap to expand sub-levels. |  |  |
| 14 | Tap expandable HierarchyProgressCard | ExpansionTile | Expands to show sub-level rows with their own progress bars. |  |  |
| 15 | Tap expanded card again | ExpansionTile | Collapses. |  |  |
| 16 | Observe no track-type label on any element | Full scroll | No "Personal", "Standard", "Custom" text visible. | No track-type label rule. |  |
| 17 | Verify track-progress % ≠ lifetime % (profile with bulk marks) | DualStatsRow | Track progress < Lifetime when there are lifetimeOnly / bulkInTrack items beyond the current-cycle window. |  |  |

### States to verify

| State | How to reach |
|-------|-------------|
| Loading | Invalidate curriculumProgressProvider; navigate in |
| Error | DB failure; retry present |
| No pace data | Track without a schedule → PaceIndicator absent |
| Pace data present | Program track → PaceIndicator shown |
| Expandable levels | Multi-level curriculum (Mishnayos) |
| Flat levels | Single-level curriculum (Mussar) |
| Offline | Airplane mode; cached data |
| Hebrew/RTL | he locale |
| Dark mode | Dark theme |

---

## Widget: ProgressTierCounterRow

Used on ProgressScreen (and Dashboard). Key assertions already listed in Screen 1 steps 1–4. Additional standalone assertions:

| # | Action | Expected |
|---|--------|---------|
| W1 | Observe all four counters in CHILD mode before data loads | All show "…" — none show "0" while others have resolved values |
| W2 | Observe total-siyumim counter value | = sum of unit + aggregate + curriculum level counts |
| W3 | Observe lifetime counter value | = distinct sefariaRefs from `lifetimeTotalsAcrossAllCurriculaProvider` |
| W4 | Tap any counter cell | No tap handler exists — these are display-only; NO navigation on tap |

---

## Cross-cutting assertions for this cluster

### Sentinel-date verification (product rule: "bulk/lifetime marking uses a sentinel date — credits siyumim/lifetime but does NOT appear in streak/recent activity")

| Check | Where to look | Expected |
|-------|--------------|---------|
| Sentinel NOT in streak dots | RecentActivityScreen StreakCalendar | Bulk-marked items (completedAt ~= 2000-01-01) absent from 7-day and 30-day calendar dot grids |
| Sentinel NOT in Limudim bar | RecentActivityScreen bar chart (7-day, 30-day) | Bulk-marked items absent from both date windows; may appear as a tiny 2000-era bucket in All Time |
| Sentinel IS counted in siyumim | SiyumimMilestonesScreen counters + body | Bulk-marked unit siyumim appear in the counters and as rows with achievedAt = 2000-01-01 ("January 2000" month group) |
| Sentinel IS counted in lifetime | LifetimeKnowledgeScreen "All sources" | Items marked via Lifetime Marking increase items-learned counter and appear in tree as "Lifetime · imported" |
| Sentinel NOT in "Track only" | LifetimeKnowledgeScreen "Track only" toggle | Items marked via Settings → Lifetime Marking (source = lifetimeOnly) absent from Track-only view |

### No track-type label rule

Scan all five screens for any occurrence of "Personal", "Standard", "Custom", "אישי" — must be zero.

### Chazara rule

On every screen (Recent Activity chart title, AllTimeSummaryCard, LifetimeKnowledgeScreen header chazaros count, provenance labels): chazara references present ONLY when `anyActiveTrackHasChazaraProvider` = true.

### Route guards / navigation fail-safe

Use the Back button on every screen in this cluster and verify no hang, no routing loop, no crash. This confirms the route guards fail-safe fix.

### Adults have no points/gamification

On ProgressScreen and RecentActivityScreen under an ADULT profile: no ⭐ counter cell and no Points-over-time chart section.

### Hebrew/RTL

On all screens with Hebrew locale: layout mirrors (RTL), siyum labels use Hebrew terms when Hebrew Terms toggle is ON, `CurriculumLabel.curriculum` renders Hebrew name.

---

## Element count summary

| Screen / Widget | Interactive elements counted |
|----------------|------------------------------|
| ProgressScreen | 10 (back ×0 — no back; pull-to-refresh; 3 lens tiles; N per-track row taps) = ~8 base + N |
| RecentActivityScreen | 3 time-range pills + N curriculum chips + back button + chart retry buttons × 3 + streak retry = ~15+ |
| SiyumimMilestonesScreen | Back + 2 segmented buttons + pull-to-refresh + retry + N expansion tiles (aggregate) = ~12+ |
| LifetimeKnowledgeScreen | Back + 2 segmented buttons + retry (header + body) + N curriculum card taps + N tree node taps + CTA = ~15+ |
| CurriculumProgressScreen | Back + retry + N expandable cards = ~8+ |
| Sub-widgets | SiyumimTimelineView (display only), SiyumimGroupedView (expansion tiles), LifetimeFolderTreeNode (tap-to-expand), CurriculumBreakdownTreeNode (tap-to-expand) |

Total enumerated interactive elements across all steps: **97**




# Cluster: Settings + Curriculum / Lifetime / Scope

## Preconditions and global notes

- **Adult own-learner** = signed-in cloud account, active profile is adult (`ProfileMode.adult`).
- **Child profile active** = active profile has `ProfileMode.child`; parental-controls section is visible.
- **Tutor session** = adult account; `activeTutoredProfileSelectionProvider` is non-null (entered via TALMID PROFILES tile).
- **Local-born** = account created offline (no Firebase UID); BackupSyncSection shows LOCAL ONLY card with "Upgrade" button.
- **Cloud-born** = signed in with email/Google; sync status card varies by network.
- No screen in this cluster shows any track-type label ("Personal"/"Standard"/"Custom"/אישי). Assert throughout.
- All screens must remain reachable without hang even when route guards (auth / restore / pin / childMode / profile) encounter errors — they fail closed but never hang.

---

## 1. SettingsScreen (`/settings`)

### How to reach
App bottom-nav → **Settings** (gear icon), any profile, any mode. No preconditions beyond being signed in and having an active profile. Tutor sessions also land here (Settings tab of the AppShell).

### Test-step table

| # | Action | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|--------|-----------------|-------------------|-----------------|
| 1 | Launch app → tap Settings bottom-nav tab | SettingsScreen renders; first child is `UserProfileHeaderCard` (avatar + name + badge + email for self-learner adult) | Rule: persistent profile/role switcher context visible at top | |
| 2 | Observe header card — confirm it shows account email for adult own-learner | Email is visible below the name | Rule: account/profile separation — header is ACCOUNT-only | |
| 3 | Observe header card with active CHILD profile | Email is NOT shown (contextRole = selfLearner but child; actually email still shown if user.email non-null — verify vs source) | Rule: showEmail = (contextRole == selfLearner && user.email != null) | |
| 4 | Tap the `UserProfileHeaderCard` header card (anywhere on it) | `AccountActionsSheet` bottom sheet slides up | Rule: top header = ACCOUNT-only sheet; product rule — single home for account actions | |
| 5 | Dismiss sheet by swiping down or tapping outside | Sheet closes; SettingsScreen still visible | Route guards: no hang/lockout | |
| 6 | Observe DEVICE section header text | Section label "DEVICE" (or localised) rendered above App Permissions tile | Layout check | |
| 7 | Tap **App Permissions** tile (`Icons.security_rounded`) | Navigates to `PermissionPromptRoute` | Device-scoped setting | |
| 8 | Return to SettingsScreen (system Back) | SettingsScreen intact; no crash | Route guard fail-safe | |
| 9 | Observe **SacredTimeSettingsCard** (in DEVICE section) | Card visible; header reads "SHABBOS MODE" + "Always on" label; shows location row, two action buttons, In-Israel toggle | DEC-26: sacred time card is DEVICE-scoped | |
| 10 | Observe PROFILE section header | "PROFILE" label rendered | Layout check | |
| 11 | Tap **Manage Tracks** tile (adult own-learner) | Navigates to `TrackManagementHubRoute` | Profile-scoped | |
| 12 | Return; tap **Manage Profiles** tile (adult own-learner, not tutor) | Navigates to `ManageLearnersRoute` | Rule: profile management ONLY in PROFILE section; no duplicate elsewhere | |
| 13 | Return; verify **Manage Profiles** tile is NOT present in tutored session | Tile absent when `isTutorElevated = true` | T3.gating rule | |
| 14 | Tap **Hebrew Date** segmented tile — "English" segment | `useHebrewDateProvider` set to false; segment highlights | Device pref persists | |
| 15 | Tap **Hebrew Date** segmented tile — "Hebrew" segment | `useHebrewDateProvider` set to true; segment switches | Device pref persists | |
| 16 | Confirm **Hebrew Terms** switch tile is HIDDEN when app locale == Hebrew (`languageCode == 'he'`) | Switch not rendered; no visible Hebrew-terms row when in Hebrew locale | Layout rule: hidden for Hebrew locale | |
| 17 | (English locale) Toggle **Hebrew Terms** switch from ON to OFF | Switch flips; `useHebrewTermsProvider` set false; transliteration-variant row APPEARS below | Conditional row visibility | |
| 18 | With Hebrew Terms OFF — tap **Sephardi** option in transliteration segmented tile | `currentTransliterationVariantProvider` set to Sephardi | Pref saved | |
| 19 | With Hebrew Terms OFF — tap **Ashkenazi** option | Provider set to Ashkenazi | Pref saved | |
| 20 | Toggle Hebrew Terms back ON | Transliteration variant row DISAPPEARS | `_TransliterationVariantTileSection` hides when hebrewTerms=true | |
| 21 | Tap **Nikud** segmented tile — "Without" option | `showNikudProvider` set to false | Pref saved | |
| 22 | Tap **Nikud** segmented tile — "With" option | `showNikudProvider` set to true | Pref saved | |
| 23 | Verify **Add What You Learned** tile is visible for adult own-learner (not child, not tutor) | Tile visible with `Icons.menu_book_rounded` | Hidden for child + tutor per source comment | |
| 24 | Tap **Add What You Learned** tile | Pushes `LifetimeMarkingScreen` via `MaterialPageRoute` | Lifetime marking only for adult own-learner | |
| 25 | Return; confirm **Add What You Learned** is ABSENT in tutored session | Tile not rendered (`!isChildProfile && !isTutoredSession`) | T3.gating | |
| 26 | Confirm **Add What You Learned** is ABSENT for child profile | Tile not rendered | Child protection | |
| 27 | Tap **Notification Settings** tile | Navigates to `NotificationsRoute` | Profile-scoped notification pref | |
| 28 | Return; confirm **BackupSyncSection** is PRESENT for adult own-learner | Blue card rendered below notifications | Sync card visible for adult | |
| 29 | Confirm **BackupSyncSection** is ABSENT in tutored session (`isTutoredSession = true`) | Card not rendered | T3.gating | |
| 30 | Confirm **BackupSyncSection** is ABSENT for child profile | Card not rendered (`!isChildProfile && !isTutoredSession`) | Child protection | |
| 31 | Confirm **Parental Controls** section is ABSENT in tutored session | `_ParentalControlsSection` not rendered | T3.gating | |
| 32 | With child profile and no parent PIN — confirm **Parent Mode** tile shows `Icons.lock_open` trailing | Trailing icon is `lock_open` | PIN state reflected | |
| 33 | With child profile and parent PIN set — confirm **Parent Mode** tile shows `Icons.lock` trailing | Trailing icon is `lock` | PIN state reflected | |
| 34 | Tap **Parent Mode** tile (child profile) | Navigates to `ParentSettingsRoute` (PIN guard prompts if not already elevated) | Parent mode gating | |
| 35 | Return from parent mode; **Parent Mode** tile subtitle reflects elevated state if `inParentMode` | Subtitle changes to "parent mode active" copy | Parent mode state badge | |
| 36 | Tap **Parent PIN** tile (no PIN set) | Navigates to `PinFlowSetupRoute` | PIN setup | |
| 37 | Tap **Parent PIN** tile (PIN already set) | Shows `showParentPinChangeDialog` | PIN change | |
| 38 | Confirm **TALMID PROFILES** section appears when `incomingTutorGrantsProvider` has active or pending grants | Tiles visible with amber (pending) or green (active) styling | Tutor invite auto-discovery | |
| 39 | Tap **Accept** button on a pending invite tile | Navigates to `AcceptInviteRoute(token: grant.grantId)` | Accept invite path | |
| 40 | Tap **Send Diagnostic Logs** tile | Calls `sendLogsToFirebase`; snackbar shows "Logs sent (N entries)" on success; "Must be signed in" snackbar if no UID; "No gateway" snackbar if offline-only | send_logs_service | |
| 41 | Observe version label at bottom (FutureBuilder<PackageInfo>) | Version string rendered (e.g., "v1.2.3 (45)") when package info available | Version display | |
| 42 | Press system Back button | Exits SettingsScreen (bottom-nav context; tab stays selected, doesn't crash) | Route guard fail-safe | |
| 43 | Verify NO track-type labels ("Personal"/"Standard"/"Custom"/אישי) appear anywhere on SettingsScreen | None present | Product rule: no track-type labels | |

### States to verify

| State | How to reach | What to assert |
|-------|-------------|----------------|
| **Adult own-learner, cloud-synced** | Sign in with email account; wait for sync | Header shows email; BackupSync shows cloud-done card |
| **Adult own-learner, local-born** | Create account offline (local tier) | Header shows "No backup" warning row; BackupSync shows LOCAL ONLY blue card with "Upgrade" button |
| **Child profile active** | Switch to a child profile via profile switcher | Parental controls section visible; no lifetime/backup tile |
| **Tutored session** | Enter tutored session from TALMID PROFILES | Manage Profiles, backup, parental controls, lifetime all absent |
| **Offline** | Enable airplane mode | BackupSync shows offline card; all other settings still tappable |
| **Pending tutor invites** | Have another account send a tutor invite to this email | TALMID PROFILES section appears above DEVICE section |
| **Hebrew/RTL** | Set device locale to Hebrew | RTL layout; Hebrew Terms tile hidden; section headers in Hebrew |
| **Dark mode** | System dark mode | Cards maintain white surface on dark background |

---

## 2. UserProfileHeaderCard + AccountActionsSheet (modal)

### How to reach
SettingsScreen → tap the profile header card at the top. Also reachable from ParentSettingsScreen (`surface = parent`).

### Test-step table — AccountActionsSheet

| # | Action | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|--------|-----------------|-------------------|-----------------|
| 44 | Open sheet (tap header card in Settings) | Bottom sheet slides up; "ACCOUNT" section label shown; drag handle visible at top | Rule: top header = ACCOUNT-only sheet; no profile-management actions here | |
| 45 | Observe sheet title/subtitle | "ACCOUNT" label + current email as subtitle on Switch Account tile | Account context shown | |
| 46 | Tap **Switch Account** list tile | Sheet closes; navigates to `AccountPickerRoute` | Rule: account switching needs NO sign-out (instant switch to Dashboard) | |
| 47 | In AccountPicker: switch to a different account | Returns to Dashboard for new account without sign-out | Fix: account-merge "discard local" path no longer crashes | |
| 48 | Re-open sheet; tap **Add Another Account** tile (visible for adult own-learner or parent-elevated child) | Sheet closes; navigates to `SignupRoute` | Add account flow | |
| 49 | Confirm **Add Another Account** tile is ABSENT for child profile NOT in parent mode | Tile not shown (`showAddAccount = !isChildProfile || inParentMode`) | Child protection | |
| 50 | (password-auth account) Tap **Change Password** tile | Sheet closes; `ReauthenticateDialog` opens | Change password flow gated by re-auth | |
| 51 | Confirm **Change Password** tile is ABSENT for Google-only account | Tile not shown (`hasPasswordProvider = user.providers.contains('password')`) | Google auth: no password change | |
| 52 | Observe divider before Sign Out / Delete Account | Divider renders when `showSignOut || showDelete` | Visual separation | |
| 53 | Tap **Sign Out** tile | Sheet closes; `showSignOutConfirmation` dialog opens | Sign-out confirmation required | |
| 54 | Confirm **Sign Out** is ABSENT for child profile (not parent-elevated) | Tile not shown (`showSignOut = !isChildProfile`) | Child protection | |
| 55 | Tap **Delete Account** tile (adult own-learner, cloud) | Sheet closes; `showDeleteAccountDialog` opens | Delete flow | |
| 56 | Confirm **Delete Account** is ABSENT for child profile | Tile not shown (`showDelete = !isChildProfile && (user != null || authState.isLocalBorn)`) | Child protection | |
| 57 | Swipe down to dismiss sheet without tapping anything | Sheet closes; SettingsScreen intact | Dismiss behavior | |
| 58 | Verify **NO** profile-management actions (add/edit/delete learner) appear in this sheet | None present | Rule: profile management ONLY in PROFILE section, never in account header sheet | |

### ReauthenticateDialog

| # | Action | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|--------|-----------------|-------------------|-----------------|
| 59 | Dialog opens (from Change Password flow) | Title shows reauth copy; password TextField with "Current Password" label; Cancel + Verify buttons | |
| 60 | Type correct current password → tap **Verify** | Dialog closes with `true`; ChangePasswordDialog opens | Success path | |
| 61 | Type wrong password → tap **Verify** | Error text "Invalid password. Please try again." shown inline; loading spinner then re-enabled | Error display | |
| 62 | Tap **Cancel** | Dialog closes with `false`; no further action | Cancellation | |
| 63 | Submit via keyboard (onSubmitted) | Same as tapping Verify | Keyboard submit | |
| 64 | While loading (Verify in-flight) — tap Cancel | Cancel button disabled; no double-submission | Loading guard | |
| 65 | Type password containing spaces | No-space formatter strips spaces (`NoSpaceFormatter`) | Input sanitization | |

### ChangePasswordDialog

| # | Action | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|--------|-----------------|-------------------|-----------------|
| 66 | Dialog opens after successful re-auth | New Password + Confirm New Password fields; Cancel + Change Password buttons | |
| 67 | Leave both fields empty → tap **Change Password** | Validation: "Password must be at least 6 characters" error on New Password field | Validation | |
| 68 | Type 5-char password → tap **Change Password** | Same validation error | Min length = 6 | |
| 69 | Type 6+ char password; Confirm = different value → tap **Change Password** | Validation: "Passwords do not match" on Confirm field | Match validation | |
| 70 | Type matching 6+ char passwords → tap **Change Password** | Loading spinner shows; on success dialog closes with `true`; SnackBar "Password changed successfully" | Success path | |
| 71 | Service throws error → error text "Failed to change password. Please try again." shown | Error state displayed inline | Error handling | |
| 72 | Tap **Cancel** | Dialog closes with `false` | Cancellation | |
| 73 | While loading — both buttons disabled | No double-fire | Loading guard | |
| 74 | Type password with spaces | Spaces stripped (`NoSpaceFormatter`) | Input sanitization | |

### DeleteAccountDialog

| # | Action | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|--------|-----------------|-------------------|-----------------|
| 75 | Dialog opens (cloud account with password auth) | Warning text in red; "You will be asked to re-enter your password" note; type-DELETE text field; Cancel + Delete Account buttons | needsReauth path | |
| 76 | Dialog opens (Google account) | "You will be asked to sign in with Google" note | reauthProvider = 'Google' | |
| 77 | Leave field empty → tap **Delete Account** | Button disabled (`_canDelete = false`); no navigation | Empty-field guard | |
| 78 | Type "DELETE" (exact uppercase) | Delete Account button becomes active | Case-sensitive match | |
| 79 | Type "delete" (lowercase) | Button stays disabled | Case-sensitive | |
| 80 | With "DELETE" typed → tap **Delete Account** | Dialog closes with `true`; re-auth flow proceeds | Confirmed deletion | |
| 81 | Tap **Cancel** | Dialog closes with `false` | Cancellation | |
| 82 | For local-born account: `showDeleteLocalAccountFlow` called; no re-auth dialog | Local deletion flow | Local-born path | |

### SignOutConfirmation dialog

| # | Action | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|--------|-----------------|-------------------|-----------------|
| 83 | Dialog opens | Custom rounded dialog; Sign Out / Cancel buttons; "Your data will be preserved" copy | |
| 84 | Tap **Sign Out** (FilledButton) | Dialog pops with `true`; tutored mirrors wiped; Firebase session cleared; router navigates to AccountPicker (if other accounts) or SignIn | Fix: sign-in connectivity routing works correctly | |
| 85 | Tap **Cancel** (TextButton) | Dialog pops with `false`; nothing else happens | Cancellation | |
| 86 | Sign-out throws error | SnackBar "Sign out failed" shown; app not hung | Error handling | |

### _DeletingAccountOverlay

| # | Action | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|--------|-----------------|-------------------|-----------------|
| 87 | Deletion in progress | Full-screen black overlay; CircularProgressIndicator; "Deleting account…" copy; `canPop = false` (back button disabled) | Blocking overlay | |
| 88 | Deletion succeeds | Overlay dismissed; app navigates to SignIn | Success path | |
| 89 | Deletion fails (network error) | Error icon + error message + **Retry** button + **Cancel** button visible | Error state | |
| 90 | Tap **Retry** in error state | `_runDeletion()` re-invoked; loading state shown again | Retry path | |
| 91 | Tap **Cancel** in error state | Overlay dismissed; app navigates to SignIn (auth state cleared even on failure) | Cancel after error | |

---

## 3. BackupSyncSection (widget, within SettingsScreen)

### Precondition
Adult own-learner; NOT child profile; NOT tutored session.

### Test-step table

| # | Action | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|--------|-----------------|-------------------|-----------------|
| 92 | Local-born account (offline/local) — observe card | Blue "Backup & Sync" card; "LOCAL ONLY" text; "Upgrade to cloud" `FilledButton` visible | Local-only state | |
| 93 | Tap **Upgrade to cloud** FilledButton | Navigates to `UpgradeToCloudRoute` | Upgrade CTA | |
| 94 | Cloud-born account, synced — observe card | Blue card; `cloud_done` icon; "Last synced: Xm ago" subtitle | Synced state | |
| 95 | Cloud-born account, offline — observe card | Blue card; `cloud_off` icon; "Offline" or "N pending" subtitle | Offline state | |
| 96 | Cloud-born account, sync error — observe card | Blue card; `warning_amber` icon; error message + "Tap to retry" | Error state | |
| 97 | Tap sync-error card (onTap provided) | Calls `syncOrchestratorProvider.retryPull()` | Error → retry | |
| 98 | Cloud-born account initialising (brief window) — observe "Connecting…" state | Neutral card shown, not "LOCAL ONLY" card | Fix: cloud-born user briefly sees local-only — should show "Connecting…" not upgrade prompt | |
| 99 | Cloud-born account, pending changes — observe card | `schedule` icon; "N queued" subtitle | Pending state | |
| 100 | Syncing in progress — observe card | `sync` icon; "Syncing…" subtitle | Syncing state | |

---

## 4. SacredTimeSettingsCard (widget, within SettingsScreen DEVICE section)

### Test-step table

| # | Action | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|--------|-----------------|-------------------|-----------------|
| 101 | Observe card header | "SHABBOS MODE" + lock-clock icon; "Always on" label | Always-on; no disable toggle | |
| 102 | Observe location row when no location set | "No location set" label; no source subtitle | Empty state | |
| 103 | Tap **Detect Location** button (`my_location` icon) | `_detecting = true`; spinner replaces icon; calls `sacredLocationProvider.notifier.detect()` | Location detection | |
| 104 | Detection succeeds (location permission granted) | SnackBar "Location updated."; location row updates with city/coordinates + "Detected automatically" | Success path | |
| 105 | Detection fails — permission denied | SnackBar "Location permission denied." or "permanently denied. Open system settings." | Permission error | |
| 106 | Detection fails — services disabled | SnackBar "Location services are turned off on this device." | Service disabled error | |
| 107 | While detecting — both location buttons disabled | No double-tap during detection | Loading guard | |
| 108 | Tap **Choose City** button (`search` icon) | Navigates to `CityPickerRoute` | City picker | |
| 109 | Pick a city from city picker | Returns; location row updates with city name + "Chosen from city list"; In-Israel toggle auto-set based on country code | Manual city | |
| 110 | Observe **In Israel** toggle | Switch reflects `inIsraelProvider` value | Toggle state | |
| 111 | Toggle **In Israel** switch ON | `inIsraelProvider.notifier.setInIsrael(true)`; switch flips; prefs written | Fix: "in Israel" manual toggle sticks (not reverted by reload) | |
| 112 | Toggle **In Israel** switch OFF | Switch flips; prefs written | Fix: toggle persists | |
| 113 | After toggling In Israel manually, force-restart app | In-Israel value is SAME as set (not reverted by prefs reload; `_explicitlySet` guard means reload only fires if not yet explicitly set since last invalidation) | Fix: sacred-time "in Israel" manual toggle sticks | |
| 114 | Detect location in IL city → In Israel auto-sets to ON → manually flip to OFF → hot-restart | Off state persists until next detect or city pick | Visitor two-day-chag scenario | |

---

## 5. CurriculumSettingsScreen (`/curriculum/:curriculumId/settings`)

### How to reach
Source shows this screen is pushed via deep URL `/curriculum/:curriculumId/settings`; it is guarded by `authGuard` only (no childModeGuard). The typical path is from the Track Detail screen or a curriculum navigation action. No route-push call found in the main settings surfaces — likely reached from content browsing or track management.

### Test-step table

| # | Action | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|--------|-----------------|-------------------|-----------------|
| 115 | Screen opens for a curriculum | AppBar title: "Settings - [CurriculumLabel]" (uses `CurriculumLabel` renderer, not raw `.displayNameEn`) | No `.displayNameEn` bypass | |
| 116 | Observe program display list tile | `school` icon; if program enrolled: "Program: [name]" + description; if no program: "Custom schedule" | Program state | |
| 117 | Loading state (async data pending) | `school` icon + "Loading program…" text | Loading state | |
| 118 | Error state (program load fails) | `school` icon + "Program" title + error message | Error state | |
| 119 | Tap **Change Program** tile | Opens `LearningProcessWizardScreen` via `MaterialPageRoute` | Program change flow | |
| 120 | Complete wizard → wizard result applied → `BulkMarkScreen` pushed | After wizard: stages deleted/recreated; bulk mark screen opens for new stages | Program change flow end-to-end | |
| 121 | Cancel wizard (null result) | No change; no crash; back to CurriculumSettingsScreen | Wizard cancel | |
| 122 | Tap **Don't see your program? Request** tile (`mail_outline` + `open_in_new`) | Opens mail app with pre-populated subject and body to support email | External link | |
| 123 | When no email app installed → tap request tile | SnackBar error + "Copy" action that copies support email to clipboard | No email app fallback | |
| 124 | Verify NO track-type labels ("Personal"/"Standard"/"Custom") in title or anywhere on screen | None present | Product rule: no track-type labels | |
| 125 | Press system Back | Returns to previous screen; no crash | Navigation | |

### States to verify

| State | How to reach | What to assert |
|-------|-------------|----------------|
| **Has preset program** | Profile enrolled in e.g. "Daf Yomi" | Tile shows program name + description |
| **Custom schedule** | Profile has custom stages, no preset | Tile shows "Custom schedule" |
| **Loading** | Slow DB / cold start | Spinner tile |
| **Error** | DB corrupt / provider error | Error tile |

---

## 6. LifetimeMarkingScreen (`/settings/lifetime`)

### How to reach
**Adult own-learner only** (not child, not tutored): SettingsScreen → Profile section → **Add What You Learned** tile → `MaterialPageRoute` push. Also accessible via deep link `/settings/lifetime` (guarded by `authGuard`, `childModeGuard`, `pinGuard`).

Precondition: active profile is **adult** and NOT in a tutored session.

### Test-step table

| # | Action | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|--------|-----------------|-------------------|-----------------|
| 126 | Screen opens | AppBar title "Add What You Learned"; subtitle paragraph explaining lifetime-only sourcing; 9 curriculum cards (Chumash, Nach, Tanach, Mishnayos, Talmud Bavli, Yerushalmi, Mishneh Torah, Mishna Berurah, Mussar) | All CurriculumId.values listed | |
| 127 | Observe curriculum card labels | Labels use `CurriculumLabel.curriculum()` (renderer); no raw `.displayNameEn` call | No display-name bypass | |
| 128 | Observe card for a curriculum with 0 learned leaves | "Not started" text row; no progress bar; percentage omitted | Empty/not-started state | |
| 129 | Observe card for a curriculum with > 0 learned leaves | Linear progress bar shown; percentage text ("X%") rendered at top right | Progress state | |
| 130 | Tap a curriculum card (e.g., Mishnayos) | Opens `LifetimeCurriculumMarkingScreen` for that curriculum | Navigation | |
| 131 | With `useHebrewTerms = false` — observe card | Hebrew name shown below transliterated name | Hebrew sub-label | |
| 132 | With `useHebrewTerms = true` — observe card | Hebrew sub-label row hidden | Hebrew-terms pref | |
| 133 | Verify NO track-type labels on any card | None present | Product rule: no track-type labels | |
| 134 | Press system Back | Returns to SettingsScreen | Navigation | |

### States to verify

| State | How to reach | What to assert |
|-------|-------------|----------------|
| **All curricula at 0 learned** | Fresh profile | All cards show "Not started" |
| **Mixed progress** | Profile has some lifetime marks | Some cards show progress bar |
| **Loading (summaries async)** | Slow DB | Cards show without crash (summary defaults to 0-valued object) |

---

## 7. LifetimeCurriculumMarkingScreen (`/settings/lifetime/:curriculumId`)

### How to reach
LifetimeMarkingScreen → tap any curriculum card. Also routable via deep link.

### Test-step table

| # | Action | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|--------|-----------------|-------------------|-----------------|
| 135 | Screen opens for e.g. Mishnayos | AppBar title = curriculum label; HierarchySelectionPanel shows top-level nodes | |
| 136 | AppBar back button not visible when `_hasNavStack = false` (root level) | Back button absent; default leading (system back) available | Nav stack state | |
| 137 | Drill into a node (e.g., tap a Seder) | `HierarchySelectionPanel` navigates; `_hasNavStack = true`; AppBar back button appears (`arrow_back_ios_new_rounded`) | Panel navigation | |
| 138 | Tap AppBar back button when `_hasNavStack = true` | `_panelKey.currentState?.navigateBack()` called; returns to parent level; back button disappears if at root | Panel back navigation | |
| 139 | Observe info box | "Mark as Learned" box with selection count label | Summary info | |
| 140 | Tap **Select All in This List** button when items present | All visible items at current level toggled selected | Bulk selection | |
| 141 | **Select All** button disabled when `_currentDisplayItems.isEmpty` | Button has `onPressed = null` (disabled) | Empty-list guard | |
| 142 | Tap individual item row (toggle) | Item checkmark appears; count increments | Single-item toggle | |
| 143 | Tap again (deselect) | Checkmark removed; count decrements | Toggle off | |
| 144 | Item already persisted in ledger — observe visual | `MarkingRowVisual.direct` styling; `isPersisted = true` flag | Already-learned indicator | |
| 145 | Implicit selection (ancestor selected) — observe row | `MarkingRowVisual.implicit` styling | Implicit selection visual | |
| 146 | Tap a parent node when already selected (deselect at parent level) | Parent removed from selections; children lose implicit state | Deselect propagation | |
| 147 | **Clear** button disabled when `_selections.isEmpty` | `onPressed = null` | Empty-selection guard | |
| 148 | **Save** button disabled when `_selections.isEmpty` | `onPressed = null` | Fix: Save disabled for empty subset (analogous to scope-selection rule) | |
| 149 | Select ≥1 item → tap **Clear** | `_selections.clear()`; count resets to 0; Clear + Save both re-disable | Clear functionality | |
| 150 | Select ≥1 item → tap **Save** | `_saving = true`; spinner in Save button; `repo.recordCompletionsBatch()` called; SnackBar "Saved N entries" | Bulk lifetime marking | |
| 151 | After Save: SnackBar shows count | SnackBar text contains N (number of items saved) | Fix: bulk/lifetime marking uses sentinel date — credits siyumim/lifetime but does NOT appear in streak/recent activity | |
| 152 | Save throws error | SnackBar error message shown; `_saving = false` | Error handling | |
| 153 | Double-tap Save quickly | Second tap ignored while `_saving = true` | No double-fire | |
| 154 | Verify NO track-type labels anywhere | None present | Product rule: no track-type labels | |
| 155 | Press system Back (no `_hasNavStack`) | Returns to LifetimeMarkingScreen | Navigation | |

### States to verify

| State | How to reach | What to assert |
|-------|-------------|----------------|
| **No prior lifetime records** | Fresh profile | No items show `isPersisted = true` |
| **Some records already saved** | Prior lifetime marks exist | Some items display persisted styling |
| **Saving in progress** | Tap Save | Spinner in button; both action buttons disabled |
| **Save error** | Simulate network/DB failure | Error snackbar; buttons re-enabled |

---

## 8. ScopeSelectionScreen (reached from track-setup scope step during add-track flow)

### How to reach
Note: `ScopeSelectionScreen` is NOT currently pushed from any screen in this cluster via a navigation call found in the production code — it is instantiated directly by the test suite and by the track-setup scope step (`ScopeStepContent` via `add_track_flow_screen`). To reach it: **Settings → Manage Tracks → Add Track → Scope step** (if scope selection step is reached during track creation wizard). A `curriculumId` parameter is required.

### Test-step table

| # | Action | Expected result | Product rule / fix | Pass/Fail/Notes |
|---|--------|-----------------|-------------------|-----------------|
| 156 | Screen opens for a curriculum | AppBar: "Learning Scope — [CurriculumLabel]"; **Save** action button in AppBar; SwitchListTile "Track entire curriculum" defaulting to ON (`_selectAll = true`) | |
| 157 | **Save** button enabled when `_selectAll = true` | Button active; `_canSave = true` | Fix: Save disabled for EMPTY subset; "select all" is valid | |
| 158 | Toggle **Track Entire Curriculum** switch OFF | Switch flips; level-selection rows appear; `_selectAll = false`; `_selectedValues.clear()` | Level chooser shows | |
| 159 | After toggle OFF, observe Save button | **Save button is DISABLED** (`_canSave = _selectAll || _selectedValues.isNotEmpty` = false) | Fix: Scope-selection Save is disabled for an empty subset | |
| 160 | Attempt to tap disabled Save button | Nothing happens; no "saved" toast | Fix: no false "saved" toast for empty subset | |
| 161 | Observe level-selection tiles | Each valid hierarchy level (1..maxLevels-1) shown with label + "N options" count; `chevron_right` trailing | Level chooser | |
| 162 | Tap a level tile (e.g., "Seder" for Mishnayos) | `_selectedLevel = level`; level tiles replaced by checkbox tiles for values at that level; header shows count "0 selected" | Level drill | |
| 163 | Tap **Change Level** TextButton in header | `_selectedLevel = null`; `_selectedValues.clear()`; returns to level chooser | Level reset | |
| 164 | Check one checkbox value | `_selectedValues.add(value)`; count updates; Save button enables | Selection enables Save | |
| 165 | Uncheck the last checkbox value | `_selectedValues` empty; Save button disabled again | Empty-subset re-disable | |
| 166 | Check multiple values (e.g., 3 sedarim) | All 3 show checked; count shows "3 selected" | Multi-select | |
| 167 | With values selected — observe Summary section | Divider + "Summary" tile + joined value names + "N items will be tracked" count | Summary display | |
| 168 | With `_selectAll = true` — toggle back ON (from some selected) | `_selectedLevel = null`; `_selectedValues.clear()`; summary section disappears | Reset to all | |
| 169 | Tap **Save** with `_selectAll = true` | `db.curriculumScopeDao.clearScopes()` called; pops screen; SnackBar "Scope set to entire curriculum" | Save entire curriculum | |
| 170 | Tap **Save** with ≥1 value selected (subset) | `db.curriculumScopeDao.setScopes()` called; pops screen; SnackBar "Scope updated: [values]" | Save subset | |
| 171 | Load screen for a curriculum that already has saved scopes | `_selectAll = false`; `_selectedLevel` and `_selectedValues` pre-populated from DB | Pre-populated from DB | |
| 172 | Loading state (content async loading) | `CircularProgressIndicator` shown in body | Loading state | |
| 173 | Error state (content load fails) | `AppErrorView` shown with **Retry** button; tap Retry calls `ref.refresh(curriculumContentProvider(...))` | Error state + retry | |
| 174 | Verify NO track-type labels ("Personal"/"Standard"/"Custom") anywhere | None present | Product rule: no track-type labels | |
| 175 | Hebrew/RTL locale — observe layout | Title is RTL-mirrored; value tiles still legible | RTL smoke | |
| 176 | Press system Back without saving | Pops without writing DB; no snackbar | Cancel without save | |

### States to verify

| State | How to reach | What to assert |
|-------|-------------|----------------|
| **Select-all ON (default)** | Fresh open | Save enabled; no level chooser |
| **Select-all OFF, no values** | Toggle off | Save disabled (empty-subset rule) |
| **Select-all OFF, ≥1 value** | Toggle off + check box | Save enabled |
| **Pre-existing scopes** | Open after prior Save | Values pre-populated |
| **Loading** | Slow content provider | Spinner |
| **Error** | Provider throws | AppErrorView + retry |

---

## Cross-cutting regression checks

| Check | How to trigger | What to confirm |
|-------|---------------|----------------|
| **Route guards fail-safe** | Kill app mid-navigation; also test with corrupt profile row | Guards resolve (pass or block); never hang; SettingsScreen always reachable | Fix: Route guards never lock user out / hang navigation |
| **Account-merge "discard local" path** | On sign-in with existing local data, choose "discard local" | No crash; routes correctly to Dashboard | Fix: discard-local path no longer crashes |
| **Sacred-time toggle persists** | Toggle In-Israel, force-restart | Value matches what was set | Fix: in-Israel manual toggle sticks |
| **Scope-selection Save disable** | Open ScopeSelectionScreen, toggle "select all" OFF, tap Save | Button disabled; no snackbar | Fix: Save disabled for empty subset |
| **No track-type labels** | All screens in this cluster | Zero instances of "Personal"/"Standard"/"Custom"/אישי | Product rule |
| **Adults: no points/gamification** | Browse Settings as adult | No points, streaks, gamification surfaces | Product rule: adults have no points/gamification |
| **Lifetime sentinel date** | Mark items via LifetimeCurriculumMarkingScreen; check streak/recent-activity screens | Marks credited in Lifetime view; NOT in streak or Recent Activity | Product rule: bulk/lifetime marking uses sentinel date |
| **Magic-link / deep-link** | Open malformed deep link `learning-tracker://…` | No crash; safe fallback routing | Fix: deep-link handling doesn't crash on malformed links |



## Cluster: Sacred Time + Notifications

### Scope

This section covers five surfaces sourced directly from their `.dart` implementations:

1. `SacredTimeSettingsCard` — embedded widget on the Settings screen (DEVICE section)
2. `CityPickerScreen` — route `/sacred-time/city`
3. `SacredTimeLockOverlay` — full-screen overlay wrapping every route in `AppShellScreen`
4. `NotificationsScreen` — route `/notifications`
5. `DeviceNotificationToggle` — widget inside `NotificationsScreen`

Session fix under explicit scrutiny throughout: **"sacred-time 'in Israel' manual toggle sticks (not reverted by a reload)"** (`InIsraelNotifier._explicitlySet` guard).

---

### 1. SacredTimeSettingsCard

#### How to reach

App launch → sign in → tap **Settings** bottom-nav tab (index 3) → scroll to the **DEVICE** section → locate the **SHABBOS MODE** card. No profile-type precondition; the card is always visible (child, adult, tutor-elevated, tutor session all show it, because it is device-scoped).

#### Interactive elements

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|----------------|--------------------|-----------------|
| 1 | Observe | Blue header bar ("SHABBOS MODE" + "Always on" label) | Header is visible with dark-blue background (#11389F), lock-clock icon, "SHABBOS MODE" text, "Always on" label. No enable/disable toggle exists — the feature is always on. | No disable toggle in source (`SacredTimeSettingsCard` has no global on/off switch) | |
| 2 | Observe | Description text | Shows "App is silenced and locked during Shabbos and Yom Tov. Times computed locally from your location with a 15-minute cushion." | Static informational text | |
| 3 | Observe (no location set) | Location row | Shows "No location set" with no source sub-label | `_LocationRow`: location == null path | |
| 4 | Observe (location set via detect) | Location row | Shows city/coordinate label and "Detected automatically" sub-label | `SacredLocationSource.detected` label | |
| 5 | Observe (location set via city pick) | Location row | Shows formatted "City, State, CC" label and "Chosen from city list" sub-label | `SacredLocationSource.manualCity` label | |
| 6 | Tap | **Detect** button (`OutlinedButton.icon` with `Icons.my_location`) | Spinner appears inside button; both action buttons become disabled. On success → snackbar "Location updated." Location row updates to new coordinates. inIsrael toggle auto-updates to `true` if detected country code == 'IL', `false` otherwise. | `_detect()` → `sacredLocationProvider.notifier.detect()` → `ref.invalidate(inIsraelProvider)`. Session fix: in-Israel value should survive subsequent hot-restarts. | |
| 7 | Tap **Detect** | GPS permission denied (first time — transient) | Snackbar: "Location permission denied." Location row unchanged. | `LocationFetchPermissionDenied(permanentlyDenied: false)` | |
| 8 | Tap **Detect** | GPS permission permanently denied | Snackbar: "Location permission permanently denied. Open system settings to allow." | `LocationFetchPermissionDenied(permanentlyDenied: true)` | |
| 9 | Tap **Detect** | Location services disabled at OS level | Snackbar: "Location services are turned off on this device." | `LocationFetchServiceDisabled` | |
| 10 | Tap **Detect** | GPS timeout / error | Snackbar: "Could not detect location: <message>" | `LocationFetchError` | |
| 11 | Tap | **Choose city** button (`OutlinedButton.icon` with `Icons.search`) | Navigates to `CityPickerScreen` (`/sacred-time/city`). Both action buttons were not disabled (no detect in flight). | `_pickCity()` → `context.pushRoute(CityPickerRoute())` | |
| 12 | Return from CityPickerScreen after city selection | Location row | Immediately shows the chosen city label ("City, State, CC") with source "Chosen from city list". inIsrael auto-set from country code. | `setManualCity()` → `ref.invalidate(inIsraelProvider)` | |
| 13 | Observe | **"I am in Israel"** row (flag icon + title + subtitle + Switch) | Row always visible. Switch reflects persisted `inIsraelProvider` value. Subtitle: "One-day chag if on. Auto-set when you detect or choose a city, flip if you are visiting." | `_InIsraelRow` always shown (no guard on location existence) | |
| 14 | Toggle | **"I am in Israel"** Switch → ON | Switch turns ON. `inIsraelProvider.notifier.setInIsrael(true)` called. `sacred_time_in_israel` SharedPrefs key written `true`. `sacredWindowsProvider` recomputes (one-day chag windows). | Session fix: `_explicitlySet = true` prevents subsequent async `_load()` clobbering this value. Toggling then backgrounding/killing/relaunching must preserve ON state. | |
| 15 | Toggle | **"I am in Israel"** Switch → OFF | Switch turns OFF. `sacred_time_in_israel` written `false`. Windows recompute to two-day chag. Same persistence guarantee. | Same session fix | |
| 16 | Toggle inIsrael ON → kill app → relaunch → observe | inIsrael Switch | Switch is still ON (persisted value loaded from SharedPrefs). | SESSION FIX: in-Israel toggle stickiness. **Critical regression check.** | |
| 17 | Toggle inIsrael ON → choose non-IL city (e.g. New York, US) → observe | inIsrael Switch | Switch resets to OFF because `setManualCity()` calls `writeInIsrael(false)` for non-IL country and `ref.invalidate(inIsraelProvider)` rebuilds from prefs. | Auto-set from country code; user must manually re-enable for "visiting non-IL but keeping two-day chag" | |
| 18 | Toggle inIsrael OFF → choose IL city (e.g. Jerusalem, IL) → observe | inIsrael Switch | Switch sets to ON (country code 'IL'). | Auto-set from country code | |
| 19 | Toggle inIsrael ON for non-IL city → background app → resume | inIsrael Switch | Still ON. `_explicitlySet` guard in `InIsraelNotifier` prevents `_load()` overwrite after explicit set. | SESSION FIX: stickiness across app resume | |

#### States to verify

| State | How to reach | What to verify |
|-------|-------------|----------------|
| No location | Fresh install or clear app data | "No location set", no source label, both action buttons enabled |
| Detected location | Tap **Detect** with GPS permitted | Source label "Detected automatically", inIsrael auto-set |
| Manual city location | Use **Choose city** | Source label "Chosen from city list" |
| inIsrael=true, non-IL city | Manually toggle ON after selecting a non-IL city | One-day chag active; user must have consciously toggled |
| Dark mode | OS dark mode → Settings | Card renders with white background per explicit `Colors.white` hard-code — verify no invisible-text clash on dark background |
| Hebrew/RTL | OS language Hebrew | Layout should mirror; flag icon + switch alignment correct in RTL |
| Child profile | Select child profile, open Settings | Card is still present (device-scoped, no child-mode gate in source) |
| Tutor session | Enter a talmid context, open Settings | Card is still present; inIsrael toggle should still work (device-global) |

---

### 2. CityPickerScreen

#### How to reach

Settings → DEVICE section → SHABBOS MODE card → tap **Choose city** button → navigates to `/sacred-time/city`. Precondition: user must be signed in (authGuard on route).

#### Interactive elements

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|----------------|--------------------|-----------------|
| 20 | Observe on screen open | AppBar title | "Choose a city" | `cityPickerTitle` l10n string | |
| 21 | Observe on screen open | Search text field | Focused immediately (`autofocus: true`). Hint text "Type a city name…". Search prefix icon. Filled style with rounded border. | `autofocus: true`; `cityPickerHint` l10n | |
| 22 | Observe on screen open | Body area (before any input) | Shows idle hint: "Start typing to search ~33,000 cities.\nType at least 2 letters." centred. No list shown. | `_query.length < 2` guard | |
| 23 | Type 1 character (e.g. "J") | Search text field | Idle hint still shown. No results list. No loading indicator. | `_query.length < 2` — provider returns empty list immediately | |
| 24 | Type 2+ characters (e.g. "Je") | Search text field | Loading spinner appears while `citySearchProvider` resolves. | `results.loading` state → `CircularProgressIndicator` | |
| 25 | Type 2+ characters resulting in matches (e.g. "Jer") | Search text field | List of city rows appears, separated by 1px dividers. Each row: title = city name, subtitle = "State · CC" (or just "CC" if no admin1). | `_CityRow`: `city.name`, `_subtitleFor` showing admin1 + countryCode | |
| 26 | Type 2+ characters with no matches (e.g. "zzz") | Search text field | Centre message: `No matches for "zzz".` in `onSurfaceVariant` colour. | `cities.isEmpty` path | |
| 27 | Tap a city row | Any `_CityRow` ListTile | Row tapped → `_select(city)` called → `sacredLocationProvider.notifier.setManualCity(...)` persists location + inIsrael → router pops, returning the `City` object → `SacredTimeSettingsCard` updates location row and inIsrael toggle. | `setManualCity()` writes both location and inIsrael key; `ref.invalidate(inIsraelProvider)` triggers rebuild | |
| 28 | Tap city row for Israeli city (e.g. "Jerusalem, IL") | `_CityRow` for Jerusalem | After pop, SacredTimeSettingsCard inIsrael Switch is ON. | countryCode == 'IL' → `writeInIsrael(true)` | |
| 29 | Tap city row for non-Israeli city (e.g. "New York, US") | `_CityRow` for New York | After pop, SacredTimeSettingsCard inIsrael Switch is OFF. | countryCode != 'IL' → `writeInIsrael(false)` | |
| 30 | Clear search field to empty | Search text field via backspace | Idle hint reappears. No results. | `_query.length < 2` path | |
| 31 | Type leading space(s) | Search text field | Leading spaces stripped by `TrimLeadingSpaceFormatter`. Effective query not artificially padded. | `TrimLeadingSpaceFormatter` input formatter | |
| 32 | Tap system Back button | Android back gesture / hardware back | Pops `CityPickerScreen`. No city selected; `SacredTimeSettingsCard` location unchanged. | `context.router.pop(city)` only called on explicit city tap | |
| 33 | Tap AppBar back arrow | Leading back button (auto-added by AppBar) | Same as system back: pops without selecting. | | |
| 34 | Search produces error state | (Network/data error from `citySearchProvider`) | Center error text: "Search failed: <error_message>". | `results.error` path → `AppLocalizations.errorSearchFailed` | |
| 35 | Type very long string (>50 chars) | Search text field | Text field accepts it (no maxLength); query sent to provider. If no matches, "No matches" message appears. No crash. | No explicit length cap in source; behaviour depends on CitiesRepository | |

#### States to verify

| State | How to reach | What to verify |
|-------|-------------|----------------|
| Initial (idle) | Open screen | Autofocused field, idle hint, no results |
| Typing < 2 chars | Type 1 char | Idle hint persists |
| Typing ≥ 2 chars (loading) | Type 2+ chars, fast network | Loading spinner visible briefly |
| Results available | Type "Tel Aviv" | Multiple rows, admin1 + countryCode in subtitle |
| No results | Type "zzzzzz" | No-matches message, no list |
| Error | Cannot determine from source; executor should observe on degraded device | "Search failed:" message should appear, not crash |
| Dark mode | OS dark mode | Filled field uses `surfaceContainerHighest` token — verify legible |
| Hebrew/RTL | OS language Hebrew | Text field, list tiles, AppBar should RTL mirror |

---

### 3. SacredTimeLockOverlay

#### How to reach

The overlay is mounted in `AppShellScreen.build()` via `SacredTimeLockOverlay(child: AutoTabsScaffold(...))`. It activates automatically when `currentSacredWindowProvider` returns a non-null window (i.e., the current UTC time falls within a pre-computed Sacred Time block for the user's location). It covers **every route** including Settings, Dashboard, Learning, and Progress.

**To trigger on a test device:** Set the device clock (via ADB) to a known Shabbos/Yom Tov window time for the configured location (15-minute cushion before sunset Friday → 50-minute cushion after dark Saturday). Alternatively, temporarily configure a location with a sunset time minutes away from now.

```
adb shell date <timestamp-that-falls-in-shabbos-window>
```

Four `SacredWindowKind` values exist: `shabbos`, `yomTov`, `shabbosYomTov`, `yomKippur`.

#### Interactive elements

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|----------------|--------------------|-----------------|
| 36 | Enter active Shabbos window (device time manipulation) | Observe entire screen | Full-screen lock overlaid on top of whatever route was active. Dark navy background (#11215C). Flame icon. Greeting: "Good Shabbos". Subtitle: "The app is closed for Shabbos." No zmanim times visible. | Overlay shows only greeting — "no zmanim are exposed to the UI" per source comment | |
| 37 | Attempt system Back gesture while lock is showing | Android back | Back gesture blocked. `PopScope(canPop: false)` prevents dismissal. | `canPop: false` — user cannot dismiss lock | |
| 38 | Tap anywhere on lock screen | Any point | No interactive elements present. No button, no dismiss, no timer. Taps swallowed by the `Material` widget. | Fully passive; exits only when provider returns null | |
| 39 | Wait for window to end (or advance device clock past tzais + cushion) | Lock screen | Lock screen disappears silently. Child widget (normal app UI) re-appears. | `currentSacredWindowProvider` re-evaluates every 30 seconds via internal timer | |
| 40 | Enter active Yom Tov window | Observe lock screen | Purple background (#4A2A8A). Celebration icon. Greeting: "Good Yom Tov". Subtitle: "The app is closed for Yom Tov." | `SacredWindowKind.yomTov` spec | |
| 41 | Enter Shabbos + Yom Tov coinciding window | Observe lock screen | Dark purple background (#31246C). Celebration icon. Greeting: "Good Shabbos & Good Yom Tov". Subtitle: "The app is closed for Shabbos and Yom Tov." | `SacredWindowKind.shabbosYomTov` spec | |
| 42 | Enter Yom Kippur window | Observe lock screen | Very dark background (#1A2333). Book icon. Greeting: "Have an easy and meaningful fast". Subtitle: "The app is closed for Yom Kippur." | `SacredWindowKind.yomKippur` spec | |
| 43 | Enter lock, navigate to Notifications screen (before clock change) | Observe | Lock screen should still be visible above Notifications screen — overlay is at `Stack` level above the entire router. | `SacredTimeLockOverlay` wraps `AutoTabsScaffold`, so all child routes are covered | |
| 44 | Enter lock screen without any location configured | Observe | Lock screen should still appear if a Sacred Window was computed. (Windows list is empty when location is null, so no lock without location.) Verify: no crash when `currentSacredWindowProvider` is null. | `sacredWindowsProvider` returns `[]` when `sacredLocationProvider` is null → `currentSacredWindowProvider` returns null → no overlay | |
| 45 | Notifications suppressed during lock | Check notification tray | No Daily Reminder or Streak Alert notifications fire during an active Sacred Time window. Both `reminderSyncEffect` and `streakAlertSyncEffect` cancel under `sacredTimeActive`. | Story 27.14 (DNI-390): sacred-time notification suppression | |
| 46 | Resume app from background during active window | Overlay state | Overlay still shown. `currentSacredWindowProvider` timer-driven re-evaluation continues. `TimezoneLifecycleObserver` triggers reschedule on resume. | Timer survives background/foreground cycle | |

#### States to verify

| State | How to reach | What to verify |
|-------|-------------|----------------|
| No lock (no location) | Fresh install, no location set | App works normally, no overlay |
| No lock (outside window) | Normal daytime usage | App works normally |
| Shabbos lock | ADB clock to Shabbos window | Navy, flame, "Good Shabbos" |
| Yom Tov lock | ADB clock to Yom Tov window | Purple, celebration, "Good Yom Tov" |
| Combined Shabbos+YT lock | ADB clock to overlap | Dark purple, celebration, combined greeting |
| Yom Kippur lock | ADB clock to Yom Kippur window | Dark, book, fast greeting |
| inIsrael=true effect | Israel location + inIsrael=true vs false | One-day vs two-day chag windows; verify lock lifts a day earlier with inIsrael=true |
| Hebrew/RTL | OS Hebrew | Lock screen text RTL; greeting and subtitle centre-aligned |
| Dark mode | OS dark | Background colours are custom hex values; verify they render correctly |

---

### 4. NotificationsScreen

#### How to reach

Settings → scroll to PROFILE section → tap **Notification Settings** tile (notifications icon, subtitle "Push, email, and study sound alerts") → navigates to `/notifications`.

Precondition: user must be signed in (authGuard). The route is accessible from any profile type (child, adult, tutor-elevated, own adult — no additional gate in the route definition). Note: `notifRewardMilestones` is visible regardless of profile type per source, but reward-points UI is adult-only per product rules — executor should confirm whether the Reward Notifications card appears for a child profile.

#### Interactive elements

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|----------------|--------------------|-----------------|
| 47 | Observe | AppBar title | "Notifications" | `notifAppBarNotifications` l10n | |
| 48 | Observe | AppBar leading back arrow | Tapping pops back to Settings. | Standard AppBar back behaviour | |
| 49 | Observe | **DeviceNotificationToggle** card (key: `device_notification_toggle`) | Shows `SwitchListTile` with title "Device notifications" and subtitle: "Checking permission…" while async check runs, then "Notifications allowed on this device" (if granted) or "Notifications blocked — tap to open Settings" (if denied). | `DeviceNotificationToggle` — layer 1 of two-layer model (DEC-27) | |
| 50 | Toggle **Device notifications** Switch → OFF (currently ON) | `DeviceNotificationToggle` Switch | Cannot programmatically disable OS notifications. Snackbar shown: "To disable notifications, go to Settings > Apps > Learning Tracker." Toggle does NOT actually turn off. | `_onToggleChanged(false)` path — snackbar, returns without action | |
| 51 | Toggle **Device notifications** Switch → ON (currently OFF / blocked) | `DeviceNotificationToggle` Switch | Triggers `gateway.requestPermission()`. If granted: subtitle updates to "allowed". If denied: snackbar "Notifications blocked. Enable them in Settings > Apps > Learning Tracker > Notifications." | `_onToggleChanged(true)` path | |
| 52 | Background app, grant notifications in OS settings, foreground app | `DeviceNotificationToggle` | `didChangeAppLifecycleState(resumed)` triggers `_checkPermission()`. Subtitle updates to "allowed" without user interaction. | `WidgetsBindingObserver` lifecycle hook | |
| 53 | Observe | **Daily Reminder** toggle row (key: `reminder_toggle`) | Icon (calendar), title "Daily Reminder", subtitle "Don't forget to learn today!", Switch. Default state = ON (provider default `true`). | `ReminderEnabled` provider default = `true` | |
| 54 | Toggle **Daily Reminder** Switch → OFF | `reminder_toggle` Switch | Switch turns OFF. `reminderEnabledProvider.notifier.toggle()` called. SharedPrefs key `reminder_enabled_<profileId>` written `false`. Reminder Time row immediately dims (disabled). | `onChanged: (willEnable) async { ... await ref.read(reminderEnabledProvider.notifier).toggle() }` — note: `requestPermission()` only called when `willEnable == true` | |
| 55 | Toggle **Daily Reminder** Switch → ON | `reminder_toggle` Switch | `gateway.requestPermission()` called first. Then toggle. Switch turns ON. Reminder Time row becomes enabled (active colour). `reminderSyncEffect` reschedules notification. | `willEnable == true` path: permission request before toggle | |
| 56 | Toggle **Daily Reminder** OFF → kill app → relaunch → return to Notifications screen | `reminder_toggle` Switch | Switch still OFF. Provider reloads from SharedPrefs on rebuild. | Per-profile persistence (`activeProfileIdProvider`-namespaced key) | |
| 57 | Observe (reminder disabled) | **Reminder Time** row (key: `reminder_time`) | Row visually disabled: text and chevron in grey (#9CA3B4). `onTap` is null (no tap action). Default time "7:00 PM". | `enabled: reminderEnabled` → `onTap: null` when disabled | |
| 58 | Tap **Reminder Time** row (reminder enabled) | `reminder_time` ListTile | Native Android `TimePickerDialog` opens with current time pre-selected (default 7:00 PM or persisted value). | `showTimePicker(initialTime: reminderTime)` | |
| 59 | Select a new time in TimePickerDialog → OK | TimePickerDialog | Dialog closes. Time row trailing text updates to newly picked time immediately. `reminderTimeProvider.notifier.setTime(picked)` persists hour+minute to SharedPrefs under per-profile keys. `reminderSyncEffect` reschedules. | SESSION FIX: reminder time persistence. Relaunch must show same time. | |
| 60 | Dismiss TimePickerDialog → Cancel/back | TimePickerDialog dismiss | Dialog closes. Time row unchanged (no `setTime` called because `picked == null`). | `if (picked != null)` guard | |
| 61 | Set reminder time → kill app → relaunch → open Notifications | `reminder_time` row | Shows persisted time, not the default 7:00 PM. | `ReminderTime._loadFromPrefs()` restores from per-profile SharedPrefs | |
| 62 | Switch profile → open Notifications | Per-profile isolation | Different profile may have different reminder time and enabled state. Providers rebuild with new `activeProfileIdProvider` value. | Per-profile namespace; `ReminderEnabled` and `ReminderTime` rebuild on profile switch | |
| 63 | Observe | **Streak Alert** toggle row (key: `streak_alert_toggle`) | Icon (fire), title "Streak Alert", subtitle "Keep your fire burning!", "HOT STREAK" pink badge chip at top-right, Switch. Default = ON. | `trailingTopBadge: _TopBadge(text: l10n.notifHotStreakBadge)` only on streak row | |
| 64 | Toggle **Streak Alert** Switch → OFF | `streak_alert_toggle` Switch | Switch turns OFF. `streakAlertEnabledProvider.notifier.toggle()`. Streak Alert Time row dims. | Same toggle pattern as reminder | |
| 65 | Toggle **Streak Alert** Switch → ON | `streak_alert_toggle` Switch | `gateway.requestPermission()` first, then toggle. Streak Alert Time row re-enables. `streakAlertSyncEffect` reschedules. | Permission requested on enable | |
| 66 | Observe (streak disabled) | **Streak Alert Time** row (key: `streak_alert_time`) | Disabled visual. `onTap` null. Default "9:00 PM". | `enabled: streakAlertEnabled` | |
| 67 | Tap **Streak Alert Time** row (streak enabled) | `streak_alert_time` ListTile | `TimePickerDialog` opens with current streak alert time pre-selected (default 9:00 PM or persisted). | `showTimePicker(initialTime: streakAlertTime)` | |
| 68 | Select a new time → OK (streak alert) | TimePickerDialog | Time row updates. `streakAlertTimeProvider.notifier.setTime(picked)` persists per-profile. `streakAlertSyncEffect` re-evaluates. | SESSION FIX: streak alert time persistence. Verify time survives relaunch. | |
| 69 | Dismiss TimePickerDialog (streak) → Cancel/back | TimePickerDialog dismiss | Time unchanged. | `if (picked != null)` guard | |
| 70 | Observe | **Reward Notifications** toggle row (key: `reward_notification_toggle`) | Icon (auto_awesome), title "Reward Notifications", subtitle "When you earn Learning Points!", Switch. Default = ON. No time row (reward notifications have no time picker). | `_NotificationSwitchRow` with no `_SettingsTimeRow` below it in this card | |
| 71 | Toggle **Reward Notifications** Switch → OFF | `reward_notification_toggle` Switch | Switch turns OFF. `rewardNotificationEnabledProvider.notifier.toggle()`. Persisted per-profile. | No time picker for reward notifications | |
| 72 | Toggle **Reward Notifications** Switch → ON | `reward_notification_toggle` Switch | `gateway.requestPermission()` first, then toggle. | Permission requested on enable | |
| 73 | Tap system Back button | Android back gesture | Pops to Settings screen. No unsaved state (all changes are immediately persisted). | Immediate-persist model | |
| 74 | Observe during active Sacred Time window | Notification switches | Switches remain interactive. Turning on a switch still calls `requestPermission()` and writes prefs. However `reminderSyncEffect` and `streakAlertSyncEffect` will cancel notifications because `isSacredTimeActiveProvider` is `true`. Visual state of switches does NOT reflect suppression — they show user intent, not OS schedule state. | Sacred time suppression is transparent to the UI toggles | |

#### States to verify

| State | How to reach | What to verify |
|-------|-------------|----------------|
| All defaults (first visit) | First-time install or clear prefs | All 3 switches ON, reminder time 7:00 PM, streak time 9:00 PM |
| Reminder disabled, time row dimmed | Toggle reminder OFF | `reminder_time` onTap null, grey text |
| Streak disabled, time row dimmed | Toggle streak OFF | `streak_alert_time` onTap null, grey text |
| OS notifications blocked | Deny notifications at OS level | DeviceNotificationToggle subtitle "blocked", toggle shows OFF, enabling shows "blocked" snackbar |
| OS notifications permitted | Grant OS permission | Subtitle "allowed", toggle shows ON |
| Permission checking in-progress | Open screen cold | Briefly shows "Checking permission…" subtitle |
| Profile switch | Switch profiles mid-session | All three toggle states and times reload for new profile |
| Sacred time active | During a Shabbos/YT window | Toggles still interactive; notifications suppressed at scheduler level, not UI |
| Child profile | Select child profile, navigate to Notifications | Reward Notifications card visible in source (no child-mode gate). If product rules state adults-only for rewards/gamification (product rule: "Adults have no points/gamification"), executor should verify whether the Reward card is hidden for a child or not — this cannot be determined from `notifications_screen.dart` alone, which shows the card unconditionally. |
| Dark mode | OS dark mode | Cards use `Colors.white` hard-coded background — verify no text contrast issue |
| Hebrew/RTL | OS Hebrew | Switches, time rows, AppBar title in RTL layout |
| Tutor session | Enter talmid context, open Notifications | Screen accessible (no tutor gate in route). Preferences would apply to the active (tutored-child) profile ID. Executor should note whether this is correct per product intent. |

#### Additional product-rule assertions

- **Adults have no points/gamification (product rule):** Check whether **Reward Notifications** toggle appears when the active profile is an adult profile (not a child). Source shows no profile-type gate — it always renders. Confirm on-device.
- **Persistent profile/role switcher (product rule):** The persistent switcher (top of every context) must still be reachable from inside `NotificationsScreen` via Settings nav → back.

---

### 5. Cross-Cutting: inIsrael Toggle Stickiness (Session Fix)

This is the primary regression test for the cluster. Execute the following sequence as a dedicated regression run:

| # | Step | Expected |
|---|------|---------|
| A | Open Settings, locate SacredTimeSettingsCard | Observe current inIsrael state |
| B | Toggle **"I am in Israel"** ON | Switch shows ON |
| C | Force-stop the app via ADB (`adb shell am force-stop com.jcom.torah.learning_tracker`) | App closed |
| D | Relaunch app | Navigate back to Settings |
| E | Observe inIsrael Switch | **Must still be ON.** Failure = regression of the sticky-toggle bug. |
| F | Toggle inIsrael OFF | Switch shows OFF |
| G | Background app (home button) | App in background |
| H | Foreground app | Resume |
| I | Observe inIsrael Switch | **Must still be OFF.** `_explicitlySet` should prevent `_load()` overwriting it during the async gap on resume. |
| J | Choose a non-IL city from CityPickerScreen | inIsrael auto-resets to OFF from country code |
| K | Manually toggle inIsrael ON | Switch ON |
| L | Background and foreground without reopening Settings | - |
| M | Re-open Settings | **inIsrael still ON** (visitor "two-day chag" scenario). |

---

### 6. Cross-Cutting: Reminder + Streak Time Persistence (Session Fix)

| # | Step | Expected |
|---|------|---------|
| A | Open Notifications screen | Note current reminder time |
| B | Tap Reminder Time row, set to 08:30 AM → OK | Time row shows "8:30 AM" |
| C | Tap Streak Alert Time row, set to 10:15 PM → OK | Time row shows "10:15 PM" |
| D | Force-stop app, relaunch, open Notifications | Reminder time = 8:30 AM, streak time = 10:15 PM. **Must not revert to defaults.** |
| E | Switch to a different profile, open Notifications | Times are that profile's own values (or defaults if never set) |
| F | Switch back to original profile, open Notifications | Times still 8:30 AM / 10:15 PM |

---

### 7. Elements I Cannot Fully Determine from Source (Executor: Probe Carefully)

1. **Reward Notifications for child profiles:** `NotificationsScreen` renders the Reward Notifications card unconditionally. Product rule states "Adults have no points/gamification." It is unclear whether the child profile should see this card or not. Executor: open Notifications as a child profile and record whether the card is present.

2. **"HOT STREAK" badge on non-English locale:** The badge text comes from `l10n.notifHotStreakBadge`. Executor: switch to Hebrew locale and confirm the badge renders in Hebrew without overflow.

3. **Snackbar overlap with lock overlay:** During Sacred Time lock, if the Detect button is somehow accessible pre-lock and a snackbar is enqueued, what happens when the lock overlay activates? The overlay uses a plain `Material`, not a `Scaffold`, so `ScaffoldMessenger` snackbars from the child widget may not surface through it. Executor: note whether snackbars from `_showOutcome` are visible during an active lock.

4. **`citySearchProvider` error path in practice:** The city search is backed by a local bundled dataset (`CitiesRepository.searchByPrefix`). It is unclear what conditions trigger the `error` state. Executor: test on a very low-memory device or observe the error path.

5. **Lock screen accessibility:** `PopScope(canPop: false)` blocks Flutter back. Verify ADB back key also cannot dismiss the lock (should be blocked by `PopScope`).



# Cluster: Tutoring (Invite / Grants / Audit / Tutor PIN)

## Preconditions and Test Account Setup

Before executing any test in this cluster:

- **Account A** — Adult profile + at least one Child profile ("Yosef"). This is the parent/owner side.
- **Account B** — Adult profile only (or no profile). This is the tutor side. Must use a real email address reachable in testing.
- Both accounts must be cloud-authenticated (Firebase signed in).
- The app must be installed on a real Android device with ADB access.
- Deep-link testing requires ADB intent injection: `adb shell am start -a android.intent.action.VIEW -d "https://app.learningtracker.app/invite?token=<grantId>"`.

---

## Screen 1: InviteTutorScreen

**Route:** `/tutor/invite` (InviteTutorRoute, requires `childProfileId` param)

**How to reach:**
- Precondition: signed in as Account A (adult with ≥1 child profile), in Adult mode.
- Path A (primary): Settings → Profile section → "Manage Tutors" → tap the "Invite a tutor" OutlinedButton under the target child's section.
- Path B (from ManageTutorsScreen): same screen, per-child "Invite a tutor" button.
- Confirm role-switcher at top of every context shows Learner/Adult/Tutor tabs before entering.

### Test-Step Table

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 1 | Observe | AppBar title | Displays invite-tutor title string (e.g. "Invite Tutor") | Persistent role switcher present at top of context screen that launched this | |
| 2 | Observe | Screen background | brandCream colour, no track-type label visible anywhere on screen | Rule: no "Personal"/"Standard"/"Custom"/אישי label | |
| 3 | Observe | Email TextFormField (empty state) | Field empty, label "Email" (or Hebrew equivalent), email keyboard shown on focus, send button disabled | Send button `onPressed` is null when `!_emailValid` | |
| 4 | Tap | Email TextFormField | Keyboard opens, field focused with blue border | TrimLeadingSpaceFormatter active | |
| 5 | Type | Email field: `invalidemail` (no @ or .) | Send button remains disabled | `_emailValid` requires `@` and `.` | |
| 6 | Type | Email field: `@nodot` | Send button remains disabled | | |
| 7 | Type | Email field: `no@domain` (no TLD dot) | Send button remains disabled | | |
| 8 | Type | Email field: `tutor@example.com` | Send button becomes enabled (filled blue, icon active) | | |
| 9 | Clear field then tap Send | Send button (disabled state) | Button does not fire; no crash | onPressed is null guard | |
| 10 | Type valid email; tap | "Send invite" FilledButton | Button shows spinner (`CircularProgressIndicator`) and "Sending…" label; `_isLoading = true`; button disabled during load | Two-phase invite: step 1 of 2 | |
| 11 | Await success response | Snackbar + share-link section | Green snackbar "Invite sent to tutor@example.com"; share-link Card appears below divider | `outgoingTutorGrantsProvider` invalidated so ManageTutors refreshes | |
| 12 | Observe | Share-link Card | URL text `https://app.learningtracker.app/invite?token=…` visible (monospace), truncated with ellipsis | Phase 2: link shown post-invite | |
| 13 | Tap | Copy icon inside share-link Card (IconButton) | Snackbar "Link copied" appears; clipboard contains the URL | `Clipboard.setData` called | |
| 14 | Tap | "Copy share link" OutlinedButton (below card) | Same as step 13; clipboard updated | Second affordance for copy | |
| 15 | Navigate back; re-open InviteTutorScreen | — | Email field empty again; share-link section absent (new instance) | State is not persisted across navigations | |
| 16 | Simulate network error (airplane mode; type email; tap Send) | Send button | Error message appears inline in email field's `errorText`; spinner stops; button re-enabled | Error renders inline, no crash; session-fix: route guards fail-safe | |
| 17 | Send invite while offline; check ManageTutors | ManageTutors screen | New pending invite row appears after `ref.invalidate(outgoingTutorGrantsProvider)` | Cache invalidation on success | |
| 18 | Tap Back / system back | AppBar back arrow or system back | Returns to ManageTutors screen; no hang | Route guards never lock user out | |

### States to Verify

| State | How to Reach | What to Assert |
|-------|-------------|----------------|
| Loading (send in progress) | Tap Send with valid email | Spinner in button, label "Sending…", button disabled |
| Error (invalid email) | Type `bad` then tap Send (or remove @ after typing valid email) | Inline errorText in field; no navigation |
| Error (network/CF failure) | Airplane mode, valid email, tap Send | Inline error message; no crash |
| Share-link shown | Successful send | Card + copy button rendered below divider |
| Hebrew/RTL | Device locale = Hebrew | All text RTL-mirrored; email field LTR keyboard still shows |
| Dark mode | System dark mode enabled | brandCream background adapts; text readable |

---

## Screen 2: AcceptInviteScreen

**Route:** `/invite?token=<grantId>` (deep-link, AcceptInviteRoute)

**How to reach:**
- Precondition: Account B receives an invite sent from Account A. The `grantId` is the Firestore document ID of the pending grant.
- Path A (primary): tap the emailed deep-link URL on the device.
- Path B (in-app): ADB intent — `adb shell am start -a android.intent.action.VIEW -d "https://app.learningtracker.app/invite?token=<grantId>"`.
- Path C: In Settings screen, pending invitations tile → tap invite row → routes to AcceptInviteScreen.
- Path D: Profile Picker screen → pending invite row → routes to AcceptInviteScreen.
- If Account B is NOT signed in, the screen pushes SignInRoute first, then re-delivers the deep-link.

### Test-Step Table

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 1 | Open deep-link while signed out | App launch with token URL | App shows SignIn screen; after sign-in, AcceptInviteScreen is re-delivered with same token | Session-fix: deep-link handling doesn't crash on re-delivery | |
| 2 | Open deep-link while signed in | AcceptInviteScreen (_AcceptStep.loading) | Full-screen spinner shown while auth check + grant load runs | `_initialize()` async gate | |
| 3 | Await loading → readyToAccept | Screen body | Handshake icon, heading, body text, 4 permission rows, Accept button, Decline text button | | |
| 4 | Observe | Permission row: "View data" | Check-circle icon (green); text describing view access | | |
| 5 | Observe | Permission row: "Configure" | Check-circle icon (green) | WS3.3h corrected copy — reflects actual default grant | |
| 6 | Observe | Permission row: "Bulk-mark" | Check-circle icon (green); canBulkPriorCompletion = true by default | Rule: canMarkLiveCompletion = false; bulk allowed | |
| 7 | Observe | Permission row: "No live mark" | Cancel icon (red); text explicitly states live marking not allowed | **Key product rule: canMarkLiveCompletion always false** | |
| 8 | Observe | Screen | No "Personal"/"Standard"/"Custom"/אישי label anywhere | Rule: no track-type label | |
| 9 | Tap | "Accept" FilledButton | Screen transitions to _AcceptStep.accepting (spinner + "Accepting…" text) | | |
| 10 | Await acceptance; no PIN set | TutorPinSetupScreen embedded | Screen transitions to _AcceptStep.pinSetup; TutorPinSetupScreen renders inline (W6.4) | Two-phase invite complete; PIN setup required before access | |
| 11 | Set PIN in embedded setup (steps per TutorPinSetupScreen) | PinSetup inline | After PIN set, `_step → success` | `onPinSet` callback fires → success step | |
| 12 | Await success state | Success screen | Green check icon, success heading, "Go to Dashboard" button | | |
| 13 | Tap | "Go to Dashboard" FilledButton | `context.router.replaceAll([AppShellRoute()])` — navigates to dashboard; no hang | Session-fix: route guard doesn't lock out | |
| 14 | Acceptance; PIN already set | AcceptInviteScreen with existing PIN | Skips PIN setup; goes directly to _AcceptStep.success | `hasTutorPin` returns true → skips setup | |
| 15 | Tap | "Decline" TextButton (readyToAccept state) | Navigates to DeclineInviteScreen (C3 path); real `DeclineTutorInviteUseCase` called on confirm | C3: real decline flow, not stub | |
| 16 | Simulate acceptance failure | Network off; tap Accept | Error state: red error icon, error message, "Try Again" button | | |
| 17 | Tap | "Try Again" OutlinedButton (error state) | Returns to _AcceptStep.readyToAccept; can retry | `setState(() => _step = _AcceptStep.readyToAccept)` | |
| 18 | Tap | AppBar back arrow | Returns to previous screen (profile picker or launcher) | | |
| 19 | Open malformed deep-link | `/invite?token=` (empty token) | App does not crash; AcceptInviteScreen renders; acceptance attempt returns error | Session-fix: malformed deep-link handling | |
| 20 | Open already-accepted token | Re-use accepted grantId | Error state shown (server rejects non-pending grant) | `canAccept` precondition: only PendingGrant | |

### States to Verify

| State | How to Reach | What to Assert |
|-------|-------------|----------------|
| Loading | Any entry to AcceptInviteScreen | Full-screen spinner while `_initialize()` runs |
| readyToAccept | Normal flow after loading | Permission rows, Accept, Decline buttons |
| Accepting | Tap Accept | Spinner + "Accepting…" text; no buttons |
| pinSetup | Accept succeeds; no PIN set | TutorPinSetupScreen renders inline |
| Success | PIN set or PIN already existed | Green check, "Go to Dashboard" button |
| Error | Network off or invalid token | Red error icon, message, "Try Again" |
| Unsigned-in | Deep-link from cold start while signed out | SignIn pushed first; re-delivered after sign-in |

---

## Screen 3: DeclineInviteScreen

**Route:** `/tutor/decline` (DeclineInviteRoute)

**How to reach:**
- Path A (from AcceptInviteScreen): tap "Decline" TextButton on readyToAccept state → `_openDecline()` pushes DeclineInviteScreen with `grant` or `token` parameter.
- Path B (from ManageGrantsScreen): tap a pending grant row's decline affordance (if wired — check at runtime; source shows resignation path for active grants, not explicit decline row, so Path A is the primary path).
- Precondition: a pending invite exists for the signed-in tutor.

### Test-Step Table

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 1 | Arrive at DeclineInviteScreen | Initial state (_DeclineStep.confirm) | Warning icon (amber), confirm heading, body text, red "Decline" FilledButton, "Cancel" OutlinedButton | | |
| 2 | Observe | Screen background | brandCream; no track-type label | Rule: no track-type label | |
| 3 | Observe | AppBar | Decline invite title; back arrow | | |
| 4 | Tap | AppBar back arrow | Returns to AcceptInviteScreen (or caller); no crash | Session-fix: route guard fail-safe | |
| 5 | Tap | "Cancel" OutlinedButton | `context.router.pop()` — returns to caller without declining | | |
| 6 | Tap | System back button | Same as Cancel; returns to caller | | |
| 7 | Tap | "Decline" FilledButton (error-styled, red background) | Transitions to _DeclineStep.declining; spinner + "Declining…" text visible | | |
| 8 | Await success | _DeclineStep.success state | Green check icon, success heading/body, "Go to Dashboard" button | DEC-23: parent notification fired fire-and-forget | |
| 9 | Tap | "Go to Dashboard" FilledButton | `context.router.replaceAll([AppShellRoute()])` — no hang | `onDeclined` callback then replaceAll | |
| 10 | Simulate network failure | Airplane mode; tap Decline | _DeclineStep.error: red error icon, error message, "Try Again" button | | |
| 11 | Tap | "Try Again" OutlinedButton (error state) | Returns to _DeclineStep.confirm | `setState(() => _step = _DeclineStep.confirm)` | |
| 12 | Navigate from AcceptInviteScreen with grant=null | Token-only path (stub grant built) | Screen renders and functions identically; server validates | Token-stub path for deep-link origin | |
| 13 | Navigate from ManageGrantsScreen with real grant | Grant-object path | `childProfileId` and `parentUid` populated from grant; DEC-23 notification uses real tutorEmail | | |
| 14 | Verify DEC-23 notification (fire-and-forget) | After successful decline | No UI freeze; notification dispatched asynchronously; screen transitions to success immediately | Session-fix: notifications don't block navigation | |

### States to Verify

| State | How to Reach | What to Assert |
|-------|-------------|----------------|
| Confirm | First entry | Warning icon, Decline + Cancel buttons |
| Declining | Tap Decline | Spinner, no buttons |
| Success | Decline accepted by server | Green check, "Go to Dashboard" |
| Error | Network failure | Red error, "Try Again" |

---

## Screen 4: ManageTutorsScreen

**Route:** `/tutor/manage-tutors` (ManageTutorsRoute)

**How to reach:**
- Precondition: signed in as Account A (adult/owner), Adult mode; ≥1 child profile exists.
- Path A: Settings → Profile section → "Manage Tutors" tile → `context.pushRoute(ManageTutorsRoute())`.
- Path B: Parent Settings screen → Tutors tile (context-aware; hidden in tutored context per WS3.3a).

### Test-Step Table

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 1 | Arrive at ManageTutorsScreen | Initial state (profileListProvider loading) | Full-screen CircularProgressIndicator | | |
| 2 | Await data load | Screen body | Per-child section headers in brandBlue, "Invite a tutor" button per child | | |
| 3 | Observe | Screen | No "Personal"/"Standard"/"Custom"/אישי label visible anywhere | Rule: no track-type label | |
| 4 | Observe | AppBar | "Manage Tutors" title; back arrow | | |
| 5 | Observe (no child profiles) | Empty state | School outlined icon, empty heading, empty body text (no child sections, no invite buttons) | `_EmptyProfilesView` rendered | |
| 6 | Observe (child has no tutors) | Per-child section | Child name in blue header; "No tutors yet" body text; "Invite a tutor" button visible | `manageTutorsNoTutors` l10n | |
| 7 | Tap | "Invite a tutor" OutlinedButton (per-child section) | Navigates to InviteTutorScreen with correct `childProfileId` | Routes to `/tutor/invite` | |
| 8 | Observe (child has active tutor) | Active section header | "ACTIVE (N)" label; `_TutorGrantRow.active` with school icon (green), tutor email, "Active" badge | | |
| 9 | Observe | Active grant row trailing | History icon button (audit log) AND "Revoke" TextButton (red) | Only active grants show history icon | |
| 10 | Tap | History (audit log) IconButton on active grant row | Navigates to TutorAuditLogScreen with correct `grantId` and `tutorEmail` | `/tutor/audit-log` | |
| 11 | Observe (child has pending invite) | Pending section header | "PENDING (N)" label; `_TutorGrantRow.pending` with hourglass icon (orange), tutor email, "Pending" badge | | |
| 12 | Observe | Pending grant row trailing | "Rescind" TextButton only (no history icon) | History only for active grants | |
| 13 | Tap | "Revoke" TextButton on active grant | Confirmation AlertDialog opens with tutor email in message body | `_showConfirmation` called | |
| 14 | Observe | Revoke confirmation dialog | Title = revoke title; message includes tutor email; "Cancel" button; "Revoke" button (red text) | | |
| 15 | Tap | "Cancel" in revoke dialog | Dialog dismissed; grant row unchanged; no network call | | |
| 16 | Tap | Back outside dialog (system back) | Dialog dismissed; no action | | |
| 17 | Tap | "Revoke" in revoke dialog | Dialog dismissed; spinner replaces Revoke button on row; revocation in progress | `_acting = true` during call | |
| 18 | Await revoke success | Grant row | Row disappears from active section; `outgoingTutorGrantsProvider` invalidated; mirror wiped + talmid session exited; notification fired | R4-M3: mirror wipe + session exit; WS3.3g notification | |
| 19 | Tap | "Rescind" TextButton on pending grant | Confirmation AlertDialog opens | | |
| 20 | Observe | Rescind confirmation dialog | Title = rescind title; message includes tutor email; "Cancel" + "Rescind" buttons (non-destructive styling) | | |
| 21 | Tap | "Cancel" in rescind dialog | Dialog dismissed; no network call | | |
| 22 | Tap | "Rescind" in rescind dialog | Spinner replaces Rescind button; row disappears after success | `outgoingTutorGrantsProvider` invalidated | |
| 23 | Simulate revoke failure | Network off; tap Revoke → confirm | Snackbar error message; `_acting` reset to false; row still visible | `manageTutorsRevokeError` snackbar | |
| 24 | Simulate rescind failure | Network off; tap Rescind → confirm | Snackbar error message; row still visible | `manageTutorsRescindError` snackbar | |
| 25 | Pull-to-refresh | ListView | No explicit pull-to-refresh in source — confirm this; if present test it | Executor: probe this gesture carefully | |
| 26 | Tap | AppBar back arrow | Returns to Settings/caller | | |
| 27 | Tap | System back | Returns to caller | | |
| 28 | Error loading profileList | Simulate DB error | AppErrorView with retry button | `AppErrorView` with `onRetry: () => ref.refresh(profileListProvider)` | |
| 29 | Tap | "Retry" in AppErrorView | Re-fetches profileListProvider | | |
| 30 | Observe | ManageTutors in tutored context | Tile should be HIDDEN (owner-only per WS3.3a/WS3.3d) — navigate as tutor and confirm tile absent from Settings | Rule: tutors cannot manage other tutors | |

### States to Verify

| State | How to Reach | What to Assert |
|-------|-------------|----------------|
| Loading | Slow network; profileListProvider loading | Full-screen spinner |
| Empty (no children) | Account with no child profiles | `_EmptyProfilesView` icon + text |
| No tutors per child | Child with no grants | "No tutors yet" text + Invite button |
| Active grants | Child with active tutor | Green active section |
| Pending invites | Child with pending invite | Orange pending section |
| Error | Crash DB / network error | AppErrorView + Retry |
| Acting (row in-progress) | Tap Revoke/Rescind → confirm | Spinner on row |
| Dark mode | System dark | Readable colours |
| Hebrew/RTL | Hebrew locale | RTL layout, per-child names RTL |

---

## Screen 5: ManageGrantsScreen

**Route:** `/tutor/my-grants` (ManageGrantsRoute)

**How to reach:**
- Precondition: signed in as Account B (tutor), ≥1 active grant exists OR the PIN entry gate leads here.
- Path A (primary): Profile Picker → "Talmid Profiles" section → tap active `_TutoredChildRow` → PIN gate passes → `ManageGrantsRoute` pushed.
- Path B: Profile Picker → "View invitations" row → PIN gate → `ManageGrantsRoute` pushed.
- Note: `PopScope.onPopInvokedWithResult` clears `activeTutoredProfileSelectionProvider` on back-pop to prevent DEC-21 dual-role bug.

### Test-Step Table

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 1 | Arrive at ManageGrantsScreen | incomingTutorGrantsProvider loading | Full-screen CircularProgressIndicator | | |
| 2 | Await data load (active grants) | Screen body | "ACTIVE (N)" header; per-grant `_GrantRow` with child name + parent display label + green "Active" badge + "Resign" button (red) | M3: child and parent names shown (never raw Firestore IDs) | |
| 3 | Await data load (pending grants) | Screen body | "PENDING (N)" header; per-grant rows with orange badge; no Resign button for pending | `canResign: false` → no resign button | |
| 4 | Observe | Screen | No "Personal"/"Standard"/"Custom"/אישי label | Rule: no track-type label | |
| 5 | Observe | Grant row child name | Displays denormalised child name (e.g. "Yosef") not raw Firestore profile ID | M3: `childDisplayLabel` uses `childName` then fallback "Talmid" | |
| 6 | Observe | Grant row parent label | Displays denormalised parent name not raw UID | M3: `parentDisplayLabel` uses `parentName` then fallback "Parent account" | |
| 7 | Observe (empty grants) | Empty state | School outlined icon, empty heading + body text | `_EmptyGrantsView` | |
| 8 | Tap | "Resign" TextButton on active grant | AlertDialog: resign title, body with child name + parent name, "Cancel" + "Resign" (red) buttons | | |
| 9 | Observe | Resign dialog | `childDisplayLabel` and `parentDisplayLabel` in message body (human-readable) | | |
| 10 | Tap | "Cancel" in resign dialog | Dialog dismissed; no action | | |
| 11 | Tap | System back while dialog open | Dialog dismissed | | |
| 12 | Tap | "Resign" in resign dialog | Spinner replaces Resign button; resignation API called | `_acting = true` | |
| 13 | Await resign success | Grant row | Row removed; `incomingTutorGrantsProvider` invalidated; mirror wiped + `activeTutoredProfileSelectionProvider.exit()` called; parent notified | R4-M3: wipe + exit; WS3.3g notification | |
| 14 | Simulate resign failure | Network off; resign → confirm | Snackbar error; row remains; `_acting = false` | `manageGrantsResignError` snackbar | |
| 15 | Tap | AppBar back arrow | Pops route; `onPopInvokedWithResult` clears `activeTutoredProfileSelectionProvider` | H1: DEC-21 fix — no dual-role after talmid view exit | |
| 16 | Tap | System back | Same as step 15 | | |
| 17 | Verify after pop | Role switcher | User is back in their own context (not still showing talmid data) | DEC-21 dual-role regression check | |
| 18 | Observe (offline with cached mirror) | Active grant row | Grant reconstructed from local mirror with "Talmid" label if no denormalised name; `TutorPermissions.defaults()` used | Offline-first: mirror union with CF result | |
| 19 | Error loading grants | AppErrorView | Retry button visible | `onRetry: () => ref.refresh(incomingTutorGrantsProvider)` | |
| 20 | Tap | Retry in AppErrorView | Re-fetches `incomingTutorGrantsProvider` | | |
| 21 | Account switch | Switch to a different account | `incomingTutorGrantsProvider` re-resolves for new user (keyed on Firebase UID) | Auth-scoped cache; no prior tutor's talmidim leaking through | |

### States to Verify

| State | How to Reach | What to Assert |
|-------|-------------|----------------|
| Loading | Slow network | Spinner |
| Empty | No grants at all | `_EmptyGrantsView` |
| Active grants only | Active grant exists | Green section, Resign button |
| Pending grants only | Pending invite exists | Orange section, no Resign |
| Mixed | Both active + pending | Both sections rendered in order |
| Offline (mirror) | Airplane mode + cached mirror | Active grants reconstructed from Drift mirror |
| Acting | Resign confirmed | Spinner in trailing |
| Error | AppErrorView shown | Retry works |

---

## Screen 6: TutorAuditLogScreen

**Route:** `/tutor/audit-log` (TutorAuditLogRoute, requires `grantId` + `tutorEmail` params)

**How to reach:**
- Precondition: signed in as Account A (owner), ManageTutorsScreen open, active grant visible.
- Path: ManageTutorsScreen → active grant row → tap history IconButton (clock icon) → `TutorAuditLogRoute(grantId: ..., tutorEmail: ...)`.

### Test-Step Table

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 1 | Arrive | AppBar | Two-line title: "Audit Log" (16pt) + tutor email (12pt, normal weight) | | |
| 2 | Observe | Filter bar (horizontal scroll) | Action FilterChips for each `TutorAuditAction` value (9 chips); "From" ActionChip; "To" ActionChip | All 9 action types: configChanged, completionBulkPrior, completionReset, bookmarkAdvanced, profileEdited, goalChanged, stageChanged, rewardChanged, studyDayChanged | |
| 3 | Observe | AppBar actions | No clear-filters icon (no active filters) | `_hasActiveFilters = false` | |
| 4 | Observe | Screen | No "Personal"/"Standard"/"Custom"/אישי label | Rule: no track-type label | |
| 5 | Scroll filter bar | Horizontal scroll | All 9 action chips + 2 date chips accessible by horizontal scroll | | |
| 6 | Tap | "Config Changed" FilterChip | Chip becomes selected (branded blue fill + checkmark); list filters to configChanged entries only | `_filterAction = TutorAuditAction.configChanged` | |
| 7 | Observe | AppBar after filter applied | Clear-filters IconButton (`filter_alt_off_rounded`) appears | `_hasActiveFilters = true` | |
| 8 | Tap | Same FilterChip again (selected → deselect) | Chip deselects; all entries shown again | `onActionChanged(selected ? action : null)` | |
| 9 | Tap | Each of the 9 action FilterChips in sequence | Each filters correctly to matching action type | Verify each of: configChanged, completionBulkPrior, completionReset, bookmarkAdvanced, profileEdited, goalChanged, stageChanged, rewardChanged, studyDayChanged | |
| 10 | Tap | "From" ActionChip (no filter set) | System date picker opens; `helpText` shows auditLogFilterFromDate; `lastDate` = _filterTo or today; `firstDate` = 2020 | | |
| 11 | Select a past date in date picker | Date picker | Picker closes; "From" chip label updates to `d/m/yyyy` format (no leading zeroes) | Date format: `${filterFrom!.day}/${filterFrom!.month}/${filterFrom!.year}` | |
| 12 | Observe | "From" chip after date set | Background changes to `brandBlue.withAlpha(0.1)` | | |
| 13 | Tap | "To" ActionChip | Date picker opens; `firstDate` = _filterFrom; `lastDate` = today | | |
| 14 | Select a date after "From" date | Date picker | Picker closes; "To" chip shows `d/m/yyyy` | Same format as From | |
| 15 | Tap | Clear-filters IconButton in AppBar | All filters cleared (`_filterAction = null`, `_filterFrom = null`, `_filterTo = null`); full unfiltered list shown; clear button disappears | `_clearFilters()` | |
| 16 | Observe (no entries matching filter) | Empty state with active filter | Filter icon, "No entries for this filter" heading + body | `_EmptyLogView(hasFilters: true)` | |
| 17 | Observe (no entries at all) | Empty state without filters | History icon, "No activity yet" heading + body | `_EmptyLogView(hasFilters: false)` | |
| 18 | Observe audit entry tile | `_AuditEntryTile` | Coloured action badge (left), action label, tutor name snapshot, target string (monospace), before/after values if present, timestamp (right) | | |
| 19 | Observe timestamp format — today | Entry from today | `HH:MM` (two-digit hours and minutes, no date) | `_formatTimestamp`: today → `pad2(hour):pad2(minute)` | |
| 20 | Observe timestamp format — past date | Entry from a previous day | `d/m\nHH:MM` (day/month newline then time, no year) | `_formatTimestamp`: not today → `${dt.day}/${dt.month}\n${pad2(dt.hour)}:${pad2(dt.minute)}` — confirm no leading zero on day/month | |
| 21 | Observe | Before/after row in entry | "before:" in red monospace, "after:" in green monospace; only rendered when values present | `_BeforeAfterRow` renders only non-null values | |
| 22 | Observe | Entry for `completionBulkPrior` | Green colour scheme; `playlist_add_check_rounded` icon | Colour and icon mapping per source | |
| 23 | Observe | Entry for `completionReset` | Orange colour; `restart_alt_rounded` icon | | |
| 24 | Observe | Entry for `bookmarkAdvanced` | Purple colour; `bookmark_added_rounded` icon | | |
| 25 | Pull-to-refresh | ListView | No explicit pull-to-refresh in source — probe carefully; if present, verify `ref.refresh(tutorAuditLogProvider(grantId))` called | Executor: test this gesture | |
| 26 | Error loading entries | AppErrorView shown | Retry button visible | `onRetry: () => ref.refresh(tutorAuditLogProvider(grantId))` | |
| 27 | Tap | Retry in AppErrorView | Re-fetches log | | |
| 28 | Tap | AppBar back arrow | Returns to ManageTutorsScreen | | |
| 29 | Tap | System back | Returns to ManageTutorsScreen | | |
| 30 | Offline (unauthenticated gateway) | No Firestore session | Fallback `_UnauthenticatedAuditLogRepository` returns `[]`; empty state shown cleanly | No crash; offline-first | |
| 31 | Apply date filter before From | Set "To" earlier than "From" | Date picker `firstDate` = _filterFrom prevents selecting invalid range | | |
| 32 | Set To = today, From = today | Both chips same date | Entries from today shown | Inclusive bounds: endOfDay = 23:59:59 | |

### States to Verify

| State | How to Reach | What to Assert |
|-------|-------------|----------------|
| Loading | Slow network | Spinner in list area |
| Empty (no entries) | Fresh grant with no tutor activity | `_EmptyLogView(hasFilters: false)` |
| Empty (filtered) | Active filter returns no matches | `_EmptyLogView(hasFilters: true)` |
| Data (entries present) | Grant with audit history | Tiles with coloured badges, timestamps |
| Error | AppErrorView | Retry button |
| Offline (unauth) | No cloud session | Empty state, no crash |

---

## Screen 7: TutorPinSetupScreen

**Route:** Embedded in AcceptInviteScreen OR standalone Scaffold pushed by TutorPinEntryGate.

**How to reach:**
- Path A (inline): Accept invite → server success → `tutorPinService.hasTutorPin` returns false → `_buildPinSetup()` embeds TutorPinSetupScreen as child widget.
- Path B (gate redirect): Profile Picker → tap talmid row → `TutorPinEntryGate` → `tutorPinIsSetProvider` = false → shows TutorPinSetupScreen.
- Path C (after reset): TutorPinResetScreen → email sent → `onResetComplete` → `_showSetupScreen = true` → TutorPinEntryGate shows TutorPinSetupScreen.

### Test-Step Table

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 1 | Arrive | Screen | AppBar "Set up Tutor PIN"; lock-person icon (purple); "Create your Tutor PIN" heading; "Enter a 4-digit PIN" body | Step 1 of 2 | |
| 2 | Observe | PinEntryWidget inside Card | 4 dot indicators (empty); digit keypad 1–9, 0; backspace key | PinEntryWidget from core/widgets | |
| 3 | Tap | Digits 1, 2, 3 | 3 dots fill; 4th dot remains empty | | |
| 4 | Tap | Backspace | One dot empties; digit removed | | |
| 5 | Tap | Digits 1, 2, 3, 4 (complete PIN) | All 4 dots fill; `onPinComplete` fires; step transitions to confirmPin | `_onFirstPinEntered("1234")` | |
| 6 | Observe (confirm step) | Screen | "Confirm your Tutor PIN" heading; "Re-enter your PIN" body; keypad reset (4 empty dots) | | |
| 7 | Enter same PIN as step 5 | Confirm PIN | Saving spinner visible; `_isSaving = true` | `_onConfirmPinEntered` called | |
| 8 | Await PIN save success | Screen | `onPinSet` callback called; navigates to next destination (success state or gate re-evaluation) | `TutorPinService.setTutorPin` → `TutorPinSuccess` | |
| 9 | Enter DIFFERENT PIN in confirm step | Confirm PIN | Error message "PINs do not match" (mismatch); step resets to enterPin; first PIN cleared | `tutorPinSetupMismatch` l10n | |
| 10 | Enter non-numeric or <4 digits | Keypad (digits only) | Keypad only offers 0–9 and backspace; cannot enter non-digit chars | PinEntryWidget is digit-only | |
| 11 | Observe | `onSkip` button | Only visible if `onSkip != null` — confirm presence/absence in each entry path (AcceptInviteScreen and TutorPinEntryGate do NOT pass `onSkip`) | FR-5.3: PIN mandatory | |
| 12 | Simulate save error | CF/service failure during save | Error message displayed; step resets to enterPin | `tutorPinSetupSaveError` l10n | |
| 13 | Observe after PIN set | AppBar back arrow (if standalone) | Tapping back should not re-enter setup unless PIN was not saved | | |

---

## Screen 8: TutorPinResetScreen

**Route:** Pushed via `MaterialPageRoute` from `TutorPinEntryGate._openResetFlow()`.

**How to reach:**
- Precondition: Account B (tutor) with PIN set; TutorPinEntryGate is showing (entry via talmid row tap).
- Path: TutorPinEntryGate → tap "Forgot your Tutor PIN?" TextButton → `TutorPinResetScreen` pushed.

### Test-Step Table

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 1 | Arrive | Screen (_ResetStep.confirm) | AppBar "Reset Tutor PIN"; amber lock-reset icon; heading; "Sending to:" label; tutor's email address in bold; hint text; "Send reset email" FilledButton | Email pre-filled from Firebase Auth `currentUser.email` | |
| 2 | Observe | Email displayed | Shows actual authenticated email; fallback label if no email (rare) | `_currentEmail` from `authRepositoryProvider` | |
| 3 | Tap | "Send reset email" FilledButton | Spinner replaces button text; `_isSending = true` | `authRepo.sendPasswordResetEmail(email)` called | |
| 4 | Await success | _ResetStep.emailSent | Green mail icon; "Check your email" heading; body mentions email address; "Set new PIN" button | `pinService.clearTutorPin(profileId)` called; `tutorPinIsSetProvider` invalidated | |
| 5 | Tap | "Set new PIN" FilledButton | `onResetComplete()` fires; pops this screen; back in TutorPinEntryGate which now shows TutorPinSetupScreen (PIN cleared) | `ref.invalidate(tutorPinIsSetProvider)` then setup screen shown | |
| 6 | Simulate send failure | Network off; tap Send | Error message in red under hint text; button re-enabled | `tutorPinResetSendFailed` l10n | |
| 7 | No email address on account | Edge case: account with no email | Error message "No email address" shown; button stays enabled to retry after fixing account | `tutorPinResetNoEmail` l10n | |
| 8 | Tap | AppBar back arrow (confirm step) | Returns to TutorPinEntryGate; PIN NOT cleared (only cleared on successful send) | | |
| 9 | Tap | System back (confirm step) | Same as step 8 | | |
| 10 | Tap | AppBar back (emailSent step) | Returns to TutorPinEntryGate; PIN IS already cleared; gate shows setup screen | PIN cleared on successful send at step 4 | |

---

## Screen 9: TutorPinEntryGate

**Type:** Fullscreen modal (MaterialPageRoute, fullscreenDialog: false in _ViewInvitationsRow but fullscreenDialog: true for talmid entry — check at runtime).

**How to reach:**
- Path A: Profile Picker → active `_TutoredChildRow` → `_enterTalmidView()` pushes TutorPinEntryGate.
- Path B: Profile Picker → `_ViewInvitationsRow` → `_openInvitations()` pushes TutorPinEntryGate.
- Precondition: Account B has ≥1 active grant and Tutor PIN is already set.

### Test-Step Table

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 1 | Arrive (PIN is set) | Gate body (_buildPinEntry) | Close (×) button in AppBar; lock-person icon (purple); "Enter Tutor PIN" heading; body text; Card with PinEntryWidget; "Forgot your Tutor PIN?" TextButton below card | | |
| 2 | Observe | AppBar | Leading × (`Icons.close_rounded`), not back arrow; tap × calls `onCancel` | `onCancel: () => Navigator.of(context).pop()` | |
| 3 | Tap | × (close) button | Gate pops; returns to profile picker; NO talmid session started; `activeTutoredProfileSelectionProvider` NOT modified | `onCancel` does not enter selection | |
| 4 | Tap | System back | Same as × button (gate pops, no session) | | |
| 5 | Enter incorrect PIN | PinEntryWidget (4 digits) | Error message "Incorrect PIN" shown; digits cleared; can retry | `TutorPinIncorrect → _errorMessage = tutorPinIncorrect` | |
| 6 | Enter PIN 5 times incorrectly | PinEntryWidget | Lockout error message showing remaining minutes | `TutorPinLockedOut(:final remainingMinutes)` | |
| 7 | Observe (locked out) | PinEntryWidget | Error message with minutes remaining; PIN entry still rendered but verify disabled state | Lockout from `PinLockoutException` | |
| 8 | Enter correct 4-digit PIN | PinEntryWidget | `onPinVerified()` fires; PIN scope marked authenticated; `activeTutoredProfileSelectionProvider.enter(selection)` called | C1/C2: same namespace as verification dialog; scope marked | |
| 9 | Await PIN success → talmid entry | Screen | Loading dialog shown (non-dismissible); tutored pull fires; on success → `context.router.replaceAll([AppShellRoute()])` | T2.entry-pull; 15s timeout cap | |
| 10 | Talmid entry: cached mirror exists | Offline + prior session | Navigates immediately without network; delta listeners attach | Offline-first: cached mirror path | |
| 11 | Talmid entry: network pull timeout | Airplane mode + no prior mirror | After 15s timeout: snackbar error; session cleared; user back at picker | Timeout cap prevents indefinite spinner | |
| 12 | Talmid entry: permission denied | Revoked grant | Snackbar "Access denied — grant may have been revoked"; session cleared | R4-M2: mirror wiped on permissionDenied | |
| 13 | Talmid entry: pull error | Server error | Snackbar "Could not load talmid data. Please try again."; session cleared | | |
| 14 | Tap | "Forgot your Tutor PIN?" TextButton | Pushes `TutorPinResetScreen` via MaterialPageRoute | `_openResetFlow()` | |
| 15 | After reset complete | Gate re-evaluates | `tutorPinIsSetProvider` invalidated → PIN unset → gate shows TutorPinSetupScreen inline | `_showSetupScreen = true` | |
| 16 | Arrive (PIN NOT set) | Gate body | TutorPinSetupScreen renders inline (no close button, no PIN entry) | `!pinIsSet → TutorPinSetupScreen` | |
| 17 | After setup in gate | Gate re-evaluates | `ref.invalidate(tutorPinIsSetProvider)` → `_showSetupScreen = false` → PIN entry shown | Lifecycle: setup → entry | |
| 18 | Loading state | `tutorPinIsSetProvider` loading | Full-screen spinner Scaffold | | |
| 19 | Error state | `tutorPinIsSetProvider` error | Scaffold with error text (prefix message) | | |

---

## Screen 10: TutorPinEntryDialog (showTutorPinVerificationDialog)

**Type:** Dialog (not a screen/route) — shown via `showDialog` from route PinGuard when a tutor navigates to a tutor-scoped guarded route.

**How to reach:**
- Precondition: In a tutored session (talmid active); navigate to a tutor-guarded route (e.g. edit a stage) that triggers the PinGuard.
- `barrierDismissible: false` — cannot dismiss by tapping outside.

### Test-Step Table

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 1 | Dialog opens | PinKeypadDialogFrame | Title "Enter Tutor PIN"; subtitle text; 4 dot indicators; digit keypad 0–9; backspace; Cancel button | C2: same namespace as TutorPinEntryGate | |
| 2 | Tap outside dialog | Barrier | Dialog does NOT dismiss (`barrierDismissible: false`) | | |
| 3 | Tap digits 1–4 | Keypad | Dots fill; auto-submits when 4th digit entered | `_appendDigit` → `_submitIfComplete` on length 4 | |
| 4 | Enter correct PIN | Keypad | Dialog closes; returns `true` to caller | `TutorPinSuccess → Navigator.pop(true)` | |
| 5 | Enter incorrect PIN | Keypad | Error message "Incorrect PIN"; digits cleared; can retry | `TutorPinIncorrect` | |
| 6 | Tap backspace | Backspace key | Last digit removed; error cleared | `_backspace()` | |
| 7 | Enter PIN 5 times incorrectly | Keypad | Locked-out state; `_lockedOut = true`; `_lockoutMinutes` shown | `TutorPinLockedOut` | |
| 8 | Observe (locked out) | Dialog | Keypad disabled; lockout message with minutes | `_busy || _lockedOut` guards input | |
| 9 | Tap | Cancel button | `Navigator.pop(false)` — dialog closes; returns false; tutor NOT given access | `_cancel()` | |
| 10 | Tap | System back (while dialog open) | Dialog uses `useRootNavigator: true`; back may close — test behaviour; expect it does NOT close due to `barrierDismissible: false` | Executor: probe carefully | |

---

## Widget: TutoredChildrenSection (Profile Picker)

**Type:** Embedded widget within the profile picker screen.

**How to reach:**
- Profile Picker screen → "Talmid Profiles" section (visible only when `activeGrants.isNotEmpty || pendingGrants.isNotEmpty`, per DEC-8).

### Test-Step Table

| # | Action | Element | Expected Result | Product Rule / Fix | Pass/Fail/Notes |
|---|--------|---------|-----------------|-------------------|-----------------|
| 1 | View profile picker (no grants) | Talmid section | Section entirely absent (SizedBox.shrink) | DEC-8: only shown with ≥1 active OR ≥1 pending | |
| 2 | View profile picker (pending only) | "View invitations" row + "Talmid Profiles" header | Header visible; mail icon card with orange badge showing pending count; "Pending invitations (N)" subtitle | DEC-8 extended to include pending | |
| 3 | Observe | Pending count badge | Small orange circle with count number | `_ViewInvitationsRow(pendingCount: N)` | |
| 4 | Tap | "View invitations" card | TutorPinEntryGate presented as fullscreen dialog | H3: PIN gate on every entry path | |
| 5 | PIN entry success (invitations path) | TutorPinEntryGate | `PinScope.tutor(tutorOwnProfileId)` marked; pops gate; pushes ManageGrantsRoute | PIN scope primed | |
| 6 | PIN cancel (invitations path) | Gate × button | Gate pops; user stays on profile picker | | |
| 7 | View profile picker (active grant) | `_TutoredChildRow` card | School icon (blue); child display name; "Tutoring" subtitle (green); "Tutor" role badge (green pill) | M3: denormalised child name displayed | |
| 8 | Observe | Child display label | Shows `grant.childDisplayLabel` — denormalised name if available, "Talmid" as fallback | M3: never raw Firestore ID | |
| 9 | Tap | Active talmid card | TutorPinEntryGate presented | WS3.3c: PIN gate on talmid row tap | |
| 10 | PIN entry success (talmid path) | TutorPinEntryGate | `activeTutoredProfileSelectionProvider.enter(selection)` called; pull fires; navigates to AppShell in talmid context | T2.entry-pull + T2.nav | |
| 11 | Verify talmid AppShell | Dashboard in talmid context | Child's parent-management view shown (NOT child mode); adult-equivalent surfaces visible | **Key product rule: tutored session shows parent-management view, not child mode** | |
| 12 | Verify live-mark absence | Talmid's learning surface | No "Mark complete today" live-mark affordance visible | **Key product rule: canMarkLiveCompletion = false; live mark absent/disabled** | |
| 13 | Verify role switcher | AppShell in talmid context | Persistent role switcher at top shows Tutor context | Rule: persistent role switcher in every context | |
| 14 | Navigate within talmid context | Any edit screen requiring PIN | TutorPinEntryDialog (keypad dialog) shown for guarded routes | C2: verification dialog, not full gate re-prompt | |
| 15 | Adults have no points | Any adult profile in picker | No points/gamification shown for adult profiles | Rule: adults have no points/gamification | |

---

## Cross-Screen: Two-Phase Invite Flow (Regression Checklist)

| # | Verification | Where to Check | Expected | Pass/Fail/Notes |
|---|-------------|----------------|----------|-----------------|
| 1 | Phase 1 — invite sent | InviteTutorScreen → successful send | Snackbar confirmation + share link shown; ManageTutors cache invalidated | |
| 2 | Phase 2 — tutor accepts | AcceptInviteScreen → Accept → PIN setup | PIN gate enforced before grant becomes usable; PIN keyed on tutor's own profile ID | |
| 3 | PIN namespace separation | TutorPinEntryGate vs parent PIN dialog | Entering tutor PIN does not satisfy parent PIN guard and vice versa | C1: independent namespaces | |
| 4 | Tutor sees child's parent-management view | After successful talmid entry | Adult management surfaces (settings tiles, tracks, goals) visible — not the child gamification view | Product rule: tutor = parent-management view | |
| 5 | Live-mark barred everywhere | Any completion affordance in tutored session | No "mark complete now/today" button; only bulk/prior affordances present | Product rule: canMarkLiveCompletion = false | |
| 6 | Audit log date format | TutorAuditLogScreen entries | Today's entries → `HH:MM`; past entries → `d/m\nHH:MM` (no leading zeros on d/m; no year) | Source: `_formatTimestamp` | |
| 7 | Audit log — tutor name snapshot preserved | After tutor account deletion scenario | `tutorNameSnapshot` shown even if account gone | FR-7.2 | |
| 8 | Session-fix: route guards | Any tutoring navigation | No screens hang, lock out, or crash; graceful fallback on all auth/PIN failures | Session-fix | |
| 9 | Session-fix: account switch in tutor context | Switch account while in talmid session | Previous talmid data does not appear on new account; `incomingTutorGrantsProvider` re-keys on Firebase UID | Session-fix | |
| 10 | No track-type label | Every screen in cluster | "Personal", "Standard", "Custom", "אישי" absent from all rendered strings | Product rule | |



---

# Section D — Defect log (fill during the sweep)

| # | Screen / flow | Step | Severity | Symptom (with after-screenshot) | Repro | Root cause | Fix commit / status |
|---|---|---|---|---|---|---|---|
| | | | | | | | |

# Section S — Sign-off checklist

- [ ] Current code built + installed on device (debug, `-r`, no data loss); app version confirmed in `dumpsys`.
- [ ] Every screen in §1–§12 walked; every interactive element exercised; Pass/Fail recorded per step.
- [ ] Every State row (loading/empty/error/offline/child/adult/tutor/Hebrew-RTL/dark) verified per screen.
- [ ] All 14 cross-cutting flows (§F1–F14) run end-to-end and passed.
- [ ] All 11 product rules (§2) confirmed; all session fixes (§3) regression-confirmed on-device.
- [ ] BulkMarkScreen + LearningProcessWizardScreen covered; dead/non-routed items (§0) resolved.
- [ ] Every Fail in §D root-caused + fixed + regression-tested (or escalated with a decision needed).
- [ ] `make ci` still green after any fixes; on-device re-verified.

**Total enumerated surface:** 126 screen-entries · 1,353 interactive elements · 14 end-to-end flows.
