# Bulk-Fix Plan — Vision/UX Audit Remediation

**Date:** 2026-06-11
**Author:** Lead Test Architect
**Source:** 104 root-cause clusters distilled from the multi-screen vision/UX audit
**Scope:** Merge duplicate clusters, classify, sequence, and shard for parallel execution.

---

## 1. Headline

**248 raw findings → 82 distinct fix clusters** (after merging 22 cross-cutting duplicate
pairs/groups across the two audit inputs).

The 104 input clusters carry a combined `findingCount` of **248**. Merging duplicate
clusters that share a single root cause (the persistent-switcher badge, the `MaterialApp
locale:null` gap, the `brandCoral*` theme constants, the ICU-plural sweep, the
`'Starts:'`-name binding, the sentinel-`profileId` notification race, the archive/delete
data-loss path, the gematriya thousands bug, the Firestore-exception leak, the
offline-delete resurrection, the PIN rapid-tap leak, the Edit-Learner mode toggle, the
LifetimeMarking visual-state set, the `chazaros` miscount, the duplicate `Learn` stage
column, the unreachable tutor/grant surfaces, and the large-text overflow set) collapses
the 104 clusters down to **82 distinct fix clusters**.

### Counts by classification (82 distinct clusters)

| Classification | Clusters | Notes |
|---|---|---|
| confirmed-bug | 63 | Deterministic defects with a concrete code fix. |
| product-decision | 12 | Look like bugs but may be intended; need a user answer before any change. |
| needs-investigation | 7 | Root cause or self-healing behavior unconfirmed; reproduce/diagnose first. |
| **Total** | **82** | |

### Counts by owned root (82 distinct clusters)

| Owned root | Clusters | Confirmed | Product-decision | Needs-investigation |
|---|---|---|---|---|
| account-nav | 14 | 10 | 3 | 1 |
| i18n-labels-theme | 12 | 10 | 1 | 1 |
| tracks-scheduler | 17 | 13 | 2 | 2 |
| profiles-progress-learning | 19 | 13 | 4 | 2 |
| sync | 5 | 2 | 0 | 3 (incl. 2 P0/P1 env) |
| settings | 4 | 4 | 0 | 0 |
| gamification | 11 | 9 | 2 | 0 |
| **Total** | **82** | **63** | **12** | **7** |

> Note: the per-root split above reflects the merged set; the dominant owned roots are
> `profiles-progress-learning` and `tracks-scheduler`, followed by `account-nav` and
> `i18n-labels-theme`. `sync` is small but carries the two highest-leverage blockers
> (the Firestore PERMISSION_DENIED env state and the offline-delete resurrection).

---

## 2. Confirmed-Bug Fix List

Grouped by owned root. **P0/P1 first**, then P2. Each entry: root cause → concrete fix →
screens. Merged clusters are marked `[merged]` with the inputs they absorb.

---

### ROOT: account-nav

#### P0 — AN-1. SIGN-IN-AGAIN card bypasses re-authentication
- **Root cause:** AccountPicker renders a `SIGN IN AGAIN` card (cached credential
  invalid) but tapping it switches straight into the account's profile picker with **zero
  credential challenge**, and the persisted switch survives relaunch. The re-auth gate is
  missing; the warning-triangle affordance is inert.
- **Fix:** Intercept the tap on any card whose state == `sign-in-again` and route to the
  re-authentication flow (password / Google credential challenge) before completing the
  switch. Do **not** persist the active-account selection until re-auth succeeds. Make the
  red triangle a real re-auth affordance.
- **Screens:** `account_picker`

#### P1 — AN-2. Child can leave CHILD MODE / edit/delete/switch profiles with no Parent PIN gate
- **Root cause:** From a child profile, the dashboard header chip opens the
  profile-switcher sheet with **no Parent PIN challenge** even though a PIN was configured.
  The sheet exposes per-row edit/delete, account switch, Add Profile, and lets the child
  tap an adult profile to enter ADULT MODE unguarded.
- **Fix:** Gate the switcher sheet's escalating actions (switch to an adult profile, edit,
  delete, switch account, add profile) behind the existing Parent PIN guard when the active
  profile is a child and a PIN is set.
- **Screens:** `profile_picker`, `app_shell switcher`

#### P1 — AN-3. Parent-elevated surfaces still display the active child's CHILD MODE badge `[merged: P1 + P2 sub-route variant]`
- **Root cause:** The persistent `ProfileSwitcherBar` badge (`app_shell.dart ~437-444`) is
  derived from `activeProfile.profileMode`. Entering parent mode via the PIN gate elevates
  authorization **without** switching the active profile away from the child, so every
  parent-only surface (Parent Settings, Manage Tutors, Invite a Tutor, Point Config, Reward
  Config, Pending Prizes, Rescind dialog) renders under a blue `CHILD MODE` pill. The
  green "Parent mode" banner only renders on main tab views, not pushed sub-routes.
- **Fix:** Make the persistent badge reflect the parent-elevated context (show `PARENT
  MODE` or suppress the child badge) while a PIN-guarded parent session is active, and
  propagate the parent-mode banner onto pushed parent-management sub-routes.
- **Screens:** `manage_tutors`, `parent_settings`, `invite_tutor`, `point_config`,
  `reward_configuration`, `parent_pending_redemptions`

#### P1 — AN-4. AccountPicker ordering / rapid-tap / back-stack defects route to wrong account or out of app
- **Root cause:** The account list is not deterministically ordered and the active account
  is not pinned, so cards reorder between visits; tap targets (account cards + "Add another
  account") have no debounce/re-entrancy guard, so rapid taps during reflow switch the
  wrong account; and the account-picker→profile-picker path has no back stack, so system
  Back ejects to the OS launcher. Compounds the AN-1 auth-bypass risk.
- **Fix:** Pin/highlight the active account at a stable position with deterministic
  ordering; add debounce/in-flight guards to account cards and the Add-account button;
  keep the account picker on the back stack so Back returns there instead of exiting.
- **Screens:** `account_picker`, `profile_picker`

#### P1 — AN-5. UpgradeToCloud collision "Cancel — keep offline account" neither keeps offline nor exits
- **Root cause:** In `_CollisionBlock` the `upgradeToCloudCancelKeepOffline` button's
  `onCancel` resets `_phase` to `const _PhaseCollision()` — it stays inside the collision
  block (only clearing the chosen option / password). It does nothing observable to "keep
  the offline account"; the only escape is the AppBar back arrow.
  `_VerificationRequiredBlock`'s cancel correctly returns to `_PhaseForm`.
- **Fix:** Make the collision-phase `onCancel` return to `_PhaseForm` (or exit the upgrade
  flow keeping the offline account intact), matching the verification-phase cancel.
- **Screens:** `upgrade_to_cloud`

#### P2 — AN-6. Bottom-nav "DASHBOARD" label truncates to "DASHBOA…" at font_scale 1.3
- **Root cause:** The shared bottom nav gives the active tab extra horizontal pill padding
  squeezing its own label; "DASHBOARD" (9 chars) has no auto-size/min-width handling.
- **Fix:** In `app_shell.dart`'s `NavigationBar`, remove/shrink the selected-pill padding,
  allow the label to auto-size/down-scale, and/or shorten the "DASHBOARD" label.
- **Screens:** `dashboard`, `learning`, `scheduler`, `curriculum_settings`

#### P2 — AN-7. Destructive-action icons render as blank solid-red discs
- **Root cause:** In the account bottom sheet, Sign Out / Delete Account use the error/red
  icon variant where the glyph foreground equals the container fill, so the icon is invisible.
- **Fix:** Set destructive-row icon foreground to a contrasting color (white/dark) against
  the red fill.
- **Screens:** `settings`, `account_picker`

#### P2 — AN-8. Stale/wrong-account chrome shown on unauthenticated auth surfaces
- **Root cause:** The shell's persistent `ProfileSwitcherBar`/app bar remains visible over
  auth surfaces pushed onto the shell stack: a logged-in account chip overlays the sign-in
  card and the signup form (a different identity); after a switch, Settings/account-sheet
  email mismatches the top bar.
- **Fix:** Suppress the persistent `ProfileSwitcherBar`/account chip on unauthenticated
  routes (sign-in/signup/account-picker), and consistently resolve the active-account
  identity across Settings/account-sheet/top-bar after a switch.
- **Screens:** `sign_in`, `Signup`, `account_picker`

#### P2 — AN-9. Form validation errors are stale until next submit
- **Root cause:** Sign-in and signup Forms set no `autovalidateMode`, so empty-submit
  errors linger after the user types valid values.
- **Fix:** Set `AutovalidateMode.onUserInteraction` on both forms.
- **Screens:** `sign_in`, `Signup`

#### P2 — AN-10. Create Account form left-anchored on tablet; AccountPicker ignores font scaling
- **Root cause:** On wide tablet the CreateAccount form renders as a narrow phone-width
  column pinned left; AccountPicker clamps/ignores system `textScaler` (1.3) while
  CreateAccount honors it.
- **Fix:** Center/constrain CreateAccount on wide viewports (max-width centered column) and
  remove the `textScaler` clamp on AccountPicker.
- **Screens:** `account_picker`, `Signup`

#### P2 — AN-11. No Forgot Password / recovery affordance on sign-in
- **Root cause:** Sign-in offers email + Secret Key, Sign In, Google, Keep-signed-in,
  Register — but no "Forgot password" link and no l10n string.
- **Fix:** Add a "Forgot password?" affordance wired to the password-reset flow (+ l10n).
- **Screens:** `sign_in`

#### P2 — AN-12. Empty password fields show masked-dot placeholder; reveal toggle doesn't unmask
- **Root cause:** On a fresh install the Sign In "Secret Key" and Create Account "Create
  Password" fields render 8 masked dots on an empty form; tapping the eye toggle flips the
  icon but the dots remain, so reveal looks broken.
- **Fix:** Remove the masked-dot placeholder from empty password fields (use a normal grey
  hint like the email field).
- **Screens:** `onboarding`, `sign_in`, `Signup`

---

### ROOT: sync

#### P0 — SY-1. DeviceRestore unreachable — every Firestore read returns PERMISSION_DENIED (test-env / rules)
- **Root cause:** On the audit account every Firestore pull fails with
  `FirestorePermissionDeniedException` (plus App-Check "Too many attempts"), so
  `SignInController` sees `cloudAccountHasProfiles=false` / `finalProfileCount=0` and
  `replaceAll([OnboardingRoute])` before `RestoreGuard` can engage the new-device path.
  Blocks live re-verification of the restore UI.
- **Classification note:** Carried as **needs-investigation** but listed here because it is
  a P0 blocker: it gates SY-2, the device_restore audit, and the Backup&Sync exception
  surfaces. Confirm whether permission-denied is purely test-env or a real rules regression
  affecting **production** reads.
- **Fix:** Restore valid Firestore security rules / App-Check config for the audit account
  so cloud reads succeed and the new-device restore path engages; or add a debug hook to
  force `DeviceRestoreRoute`.
- **Screens:** `device_restore`

#### P1 — SY-2. DeviceRestore idle state renders a literal blank screen
- **Root cause:** `DeviceRestore.build()`'s idle branch returns `SizedBox.shrink()` (fully
  blank Scaffold). The only guard (`_startRestore()` calling `_navigateToApp()` when
  `restore()` returns false and status is idle) is fragile: a non-idle→idle emission, an
  uncovered false reason, or a null `deviceRestoreServiceProvider` (early return at line 31)
  all leave a permanently blank screen with no spinner, text, or exit.
- **Fix:** Render a visible fallback (spinner + "Preparing…") from the idle branch instead
  of `SizedBox.shrink()`, and ensure the null-service early-return navigates away.
- **Screens:** `device_restore`

#### P1 — SY-3. Raw FirestorePermissionDeniedException leaked verbatim into Backup & Sync card `[merged: P1 + P2]`
- **Root cause:** `sync_orchestrator.dart:959-961` sets `message = e.toString()` for any
  non-Timeout exception, and `backup_sync_section.dart:115-119` renders
  `l10n.backupSyncError(message)` directly — exposing class name, internal collection
  (`completions`), op (`read`), and error code `[cloud_firestore/permission-denied]`
  verbatim. "Tap to retry" re-runs and re-surfaces the same raw text. The un-flushable
  outbox also makes the backlog counter climb on every settings change.
- **Fix:** Map sync exceptions to friendly localized messages (e.g. "Cloud backup is
  temporarily unavailable. Tap to retry.") in the orchestrator/section before rendering;
  never pass `exception.toString()` into the `backupSyncError` template. Surface retry
  progress/feedback. (Outbox-flush root cause overlaps SY-1.)
- **Screens:** `parent_settings`, `settings`

> The remaining sync clusters (offline-delete resurrection) are **needs-investigation** —
> see §4 callout and §3 is not applicable; they are listed in the investigation queue below.

---

### ROOT: settings

#### P1 — ST-1. Notification preferences not restored / Daily Reminder toggle shows wrong state (sentinel profileId race) `[merged: P1 + P2 + P2 toggle-state]`
- **Root cause:** `notification_providers.dart` returns hard-coded defaults
  (`enabled=true`, reminder 7PM, streak/reward ON) **synchronously** in `build()` and
  async-loads prefs keyed on `activeProfileIdProvider`, which returns **sentinel 0** while
  the profile resolves. `_loadFromPrefs(0)` reads non-existent `*_0` keys → falls back to
  defaults, and the reload under the real id does not land in displayed state. Net: saved
  prefs (reminder time, streak/reward OFF) revert to all-ON defaults on every cold restart;
  the Daily Reminder toggle displays ON while the backing pref is false / permission denied
  and snaps back to ON after a denial.
- **Fix:** Defer the notification providers until `activeProfileIdProvider` resolves a real
  (non-sentinel) id before loading prefs; show a loading state instead of synchronous
  defaults; ensure the post-resolution prefs read updates displayed switch/time state.
  Reflect true enabled state (pref + OS permission) in the Daily Reminder toggle.
- **Screens:** `settings`, `Notifications`

#### P2 — ST-2. HOT STREAK badge stays shown when Streak Alert toggle is OFF
- **Root cause:** The "HOT STREAK" badge is a static label that stays visible even when the
  Streak Alert toggle is OFF and its time row is greyed.
- **Fix:** Conditionally hide/grey the "HOT STREAK" badge when Streak Alert is OFF.
- **Screens:** `settings`, `Notifications`

#### P2 — ST-3. Switch/stepper/FAB/field controls expose no accessibility labels
- **Root cause:** Focusable controls lack their own `Semantics` labels (text lives on a
  sibling node): Daily Reminder / Streak Alert switches, Hebrew-Terms switch, Point Config
  +/- steppers, add-learner FAB and avatar targets, Invite-Tutor email field all announce
  as unlabeled.
- **Fix:** Attach `Semantics`/label (or tooltip) directly to each focusable control:
  associate switch labels with the Switch nodes, give steppers "Increase/Decrease points",
  label the FAB (`l10n.addProfile`) and avatar targets, ensure the email field's `labelText`
  reaches the a11y node.
- **Screens:** `Notifications`, `curriculum_settings`, `point_config`, `manage_learners`,
  `invite_tutor`

#### P2 — ST-4. Backup & Sync status template leaves raw English status remainder under Hebrew
- **Root cause:** The Backup & Sync status template only localizes the prefix, leaving raw
  English status ("outbox has N row(s) stuck…") under Hebrew UI.
- **Fix:** Localize the full sync-status template (not just the prefix). (Pairs with the
  i18n Shabbos-mode / breadcrumb literal-leak cluster — see IL-9.)
- **Screens:** `settings`

---

### ROOT: i18n-labels-theme

#### P1 — IL-1. Hebrew-Terms = English ignored across the curriculum/goal wizard — all domain labels render Hebrew-script
- **Root cause:** Setting Hebrew-Terms to English on onboarding persists
  `useHebrewTermsProvider.set(false)`, but every track-wizard step renders domain terms in
  Hebrew script with no transliteration (`curriculum_picker_step.dart:185` only shows the
  English subtitle `if (!terms.isHebrew)`, proving `terms.isHebrew` evaluated TRUE). The
  provider appears reset when the offline signup invalidates `userDatabaseProvider` /
  switches DB, so the explicit English choice is silently discarded.
- **Fix:** Persist/propagate the Hebrew-Terms preference so it survives the offline-signup
  DB switch / `userDatabaseProvider` invalidation and is read correctly by the wizard steps.
- **Screens:** `onboarding`
- **⚠ Foundational — see §4.**

#### P1 — IL-2. Nusach/transliteration leaks on path-specific render paths `[merged: P1 nusach + P2 nusach gaps + P2 siyum/Genesis scope]`
- **Root cause:** Domain-term rendering is inconsistent across render paths and ignores
  nusach in places: the track-created toast surfaces raw English "Genesis" instead of the
  transliterated sefer name; the compact daily-task tile leaks "Berakhot" (sephardi) while
  the breadcrumb correctly shows "Berakhos"; the review-count subtitle is hardcoded
  "chazaros" (no `chazarot` under Sephardi); `chazaros` getter takes no
  `TransliterationVariant`; the Ashkenazi table has gaps (Beitzah/Rosh Hashanah);
  `aggregateSiyumLabel` builds "Siyum Seder Seder Zeraim" because the level-1 key already
  contains "Seder"; and מ-ש-נ-ה transliterates three inconsistent ways.
- **Fix:** Route all domain-term render paths (toast/snackbar, compact daily-task tile,
  review-count subtitle, siyum aggregate label, program names) through the same
  nusach/Hebrew-Terms-aware resolver used by the breadcrumb/tree. Make all domain-term
  getters accept/honor `TransliterationVariant` like `shabbos()`/`havdalah()`; complete the
  Ashkenazi masechta table; strip the duplicated level word in `aggregateSiyumLabel`.
- **Screens:** `progress`, `curriculum_progress`, `siyumim_milestones`, `content_hierarchy`,
  `lifetime_knowledge`, `parent_track_management`, `learning`

#### P1 — IL-3. Missing ICU plural handling → wrong singular/plural on count-bearing labels `[merged: P1 siyumim/lifetime + P2 full sweep + P2 he-mode gematriya]`
- **Root cause:** Many ARB strings hard-concatenate the noun with no ICU `{count, plural,
  …}` selector: `siyumimLevel*` render "1 …-level siyumim" (should be "siyum"); lifetime
  header/tier counters render "1 items learned", "1 total chazaros", "1 Siyimim earned";
  `streakWidgetDayStreak` other="day"; "1 PTS"/"1 Points"/"1 study days"/"1 DAYS"/"1
  selection(s)"/"All 1 complete"; and counts>1 keep singular units ("50 Perek", "11
  Masechta", "697 סימן"). In Hebrew-script mode counts render Arabic integers glued to
  singular Hebrew units with no space ("מסכת1", "50 פרק") instead of gematriya + plural.
- **Fix:** Single l10n sweep: convert affected templates to ICU `{count, plural, one{…}
  other{…}}` with correct domain forms (siyum/siyumim, item/items, chazara/chazaros,
  Perek/Perakim, Masechta/Masechtos, סימן/סימנים, פרק/פרקים); drop the "(s)" anti-pattern.
  In Hebrew-script mode, render gematriya, add a space between number and unit, and select
  the correct plural Hebrew noun via the gematriya/plural-aware label helper.
- **Screens:** `siyumim_milestones`, `lifetime_knowledge`, `progress`, `addtrack`,
  `gamification`, `recent_activity`, `point_config`, `reward_configuration`,
  `lifetime_marking`, `onboarding`

#### P1 — IL-4. Offline destructive warnings render slate-grey — `brandCoral*` constants mis-defined as SlateGray `[merged: P1 + P2 + P2]`
- **Root cause:** `app_theme.dart:29-31` defines `brandCoral=0xFF708090` (CSS SlateGray),
  `brandCoralSoft=0xFFD8DEE3`, `brandCoralDeep=0xFF4E5E70` — the constants *named* coral are
  muted blue-grey. Signup's `_showError()` and `_buildAccountModeCard`, all error
  snackbars, and the offline "data stays only on this device" destructive cards use these,
  so warnings carry zero red/urgency. A genuine red exists elsewhere (AccountPicker "SIGN
  IN AGAIN" badge), proving the mismatch.
- **Fix:** Introduce a real error/warning color and repoint `_showError()` snackbars and the
  signup data-loss cards to it; correct or rename the mis-named `brandCoral*` constants.
- **Screens:** `Signup`, `sign_in`

#### P1 — IL-5. Stage-name mapping: stage 1 shows "Learn"/two stages collapse to identical "Learn:" columns `[merged: P1 curriculum-progress + P2 point_config]`
- **Root cause:** The stage path renders the stored legacy English translation "Learn"
  (`stageLearnEn='Learn'`; `resolveStoredStageName` returns it verbatim) instead of the
  canonical transliteration "Limud" (`limud` getter). The curriculum-progress expanded
  breakdown shows two identical "Learn: N" columns (both "לימוד" in Hebrew) instead of four
  distinct SRS stage names.
- **Fix:** Normalize `resolveStoredStageName` to emit "Limud" in Hebrew-Terms-OFF mode, and
  fix the stage-definition mapping so the four SRS stages render distinct labels (Learn,
  Review 1/2/3 or configured names).
- **Screens:** `point_config`, `curriculum_progress`

#### P2 — IL-6. No in-app UI-language switcher; per-profile `app_locale` does not drive `MaterialApp` locale
- **Root cause:** `learning_tracker_app.dart` sets `MaterialApp locale:null` (DNI-341), so
  the visible UI locale resolves only from the OS device locale. The per-profile
  `AppLocalePreference` (`app_locale_pN`) is written/consumed out-of-band (notifications)
  but never wired into `MaterialApp.locale`; there is no in-app control. A profile set to
  Hebrew gets no Hebrew UI; the `he` UI-locale audit lever is unexercisable.
- **Fix:** Wire `currentAppLocaleProvider` (`app_locale_pN`) into `MaterialApp.locale` (or a
  `Localizations` override), and add a user-facing UI-language switcher in Settings.
- **Screens:** `dashboard`, `trackdetail`, `progress`, `Child prize redemption screen`
- **⚠ Foundational — see §4.**

#### P2 — IL-7. Hebrew/RTL breadcrumb laid out LTR, orphans gematriya, clips/scrambles active segment
- **Root cause:** The breadcrumb/hint container is not direction-aware for RTL: in
  Hebrew-terms mode it keeps LTR layout with right-pointing chevrons (broadest term on the
  left, inverting the hierarchy); "פסוק/משנה `<gematriya>`" wraps with the single gematriya
  letter orphaned; the chip breadcrumb clips the active RTL segment at 1.3 with no
  auto-scroll; the search-hint fragments under bidi with the ellipsis floated left. No
  `Directionality`/bidi-isolate and no non-breaking grouping.
- **Fix:** Wrap the container in `Directionality`/RTL when terms are Hebrew, flip chevron
  direction, wrap injected labels in bidi isolates (FSI/PDI), keep "פסוק/משנה `<n>`" as a
  non-breaking unit, and auto-scroll to reveal the active segment at large text.
- **Screens:** `scheduler`, `content_hierarchy`, `content_search`, `text_display`

#### P2 — IL-8. Disabled/low-emphasis controls below WCAG AA; low-contrast footer/decorative icons
- **Root cause:** "Not enough points" disabled button label (#9CA3AF on #E5E7EB ≈2:1);
  settings footer feedback icons (light-gray on white); first curriculum-row icon (Chumash)
  washed-out gray disc; "Decline" refund action borderline #6B7280 gray.
- **Fix:** Darken disabled/secondary labels to meet AA (≥#6B7280 darker), fix the Chumash
  icon color assignment, raise contrast on footer icons and the Decline button.
- **Screens:** `Child prize redemption screen`, `settings`, `content_hierarchy`,
  `parent_pending_redemptions`

#### P2 — IL-9. Hebrew locale leaks untranslated Latin literals (SHABBOS, "selection", duplicated breadcrumb)
- **Root cause:** Shabbos-mode banner title "מצב SHABBOS" and body "בShabbos"; the scope
  breadcrumb emits untranslated "selection" + an LTR "→" + duplicated curriculum name
  ("חומש › חומש → חומש selection").
- **Fix:** Translate the Shabbos-mode strings ("מצב שבת", "בשבת"); fix the scope-step
  breadcrumb to drop the duplicated curriculum, use a direction-neutral separator, and
  localize "selection". (Pairs with ST-4 sync-status localization.)
- **Screens:** `settings`, `addtrack`

#### P2 — IL-10. Independent-axes mixed-script rows (Hebrew domain term among English chrome) — *see §3 PD-1; tracked as product-decision*

---

### ROOT: tracks-scheduler

#### P1 — TS-1. "Starts:" program card field renders the program NAME instead of a start date `[merged: P1 + P2]`
- **Root cause:** `program_selection_step.dart:227` interpolates the program name into the
  "Starts:" label (`'Starts: $name'`). The calendar-icon row is bound to the program's own
  name rather than its cycle/track start date. Reproduces on every "Join a Program?" step
  (Dirshu Amud HaYomi, Mishnah Yomis, Halacha Yomis) in both term modes, across add-track
  hub, track management, and onboarding. Sibling cards (Daf Yomi → "DAILY CALENDAR") are fine.
- **Fix:** Bind the "Starts:" value to the program's actual start/cycle date (or the
  localized "DAILY CALENDAR" descriptor); remove the program-name fallback at
  `program_selection_step.dart:227`; hide the line when no start date applies.
- **Screens:** `addtrack`, `track_management_hub`, `parent_track_management`, `onboarding`,
  `dashboard`

#### P1 — TS-2. Add-Track scope/pace/deadline math uses full-curriculum total instead of selected section `[merged: P1 + P2 deadline-of-today]`
- **Root cause:** The wizard computes per-study-day pace and item count against the entire
  curriculum total (~5846 pesukim for all 5 Chumash books) rather than the selected scope
  (Bereishis alone, ~1533). Wrong in both `en` and `he`. The deadline mode also defaults the
  date to today, yielding "17397 items per study day, across 1 study day" degenerate plans
  with no floor or warning.
- **Fix:** Drive pace/deadline/item-count math from the selected scope's item total; thread
  the chosen scope into the goal-feasibility calculation; add a floor/validation so a
  deadline-of-today (or impossibly short horizon) warns instead of producing absurd figures.
- **Screens:** `addtrack`, `parent_track_management`, `onboarding`

#### P1 — TS-3. "Archive (keep history)" destroys goal/pace/program config yet leaves the track active `[merged: P1 + P2 confirmed + P2 needs-investigation duplicate]`
- **Root cause:** `parent_track_management_screen.dart _showDeleteDialog` with
  `choice=='archive'` calls `dao.deleteTrackAndData(track.id)` then invalidates. Observed
  effect is a **partial delete**: goal/required-pace/est-finish/completion-mode config is
  wiped (subtitle degrades to "Track progress", action flips "Edit Goal"→"Set Goal") while
  the track reappears as active after any rebuild — the opposite of "keep history". On a
  child's record.
- **Fix:** Implement "Archive (keep history)" as a true archive that flags the track
  inactive while preserving goal/pace/program/completion-mode rows, rather than calling
  `deleteTrackAndData`; ensure the active-list query excludes archived tracks so the empty
  render is not stale.
- **Screens:** `parent_track_management`

#### P1 — TS-4. Study-day weekday labels hardcoded ("Sat"), ignore Nusach; config UI unreachable; Shabbos defaults ON `[merged: P1 + P2]`
- **Root cause:** `StudyDayConfig` labels weekdays via a const map (Saturday hardcoded
  "Sat") with no Nusach/Hebrew-Terms awareness, so six days render English and only Saturday
  follows the toggle (mixed-script list); Shabbos defaults ON (a conflict for a Shabbos-lock
  app) and the Shabbos avatar "S" duplicates Sunday's. Separately the full weekday grid only
  renders for a self-paced AND multi-stage track, which doesn't exist in the build (the
  multi-stage track has a program enrollment that hides the Study Days tile) — so the surface
  is unreachable.
- **Fix:** Route weekday labels (especially Saturday → Shabbos/Shabbat/שבת) through the
  Nusach/Hebrew-Terms resolver; fix the duplicate Shabbos/Sunday avatar initial; reconsider
  the Shabbos-ON default; and provide a reachable entry to the weekday config (allow the
  Study Days tile for the qualifying state, or seed a self-paced multi-stage track).
- **Screens:** `study_day_config`, `addtrack`, `onboarding`

#### P1 — TS-5. Onboarding goal-step (STEP 6) Continue button blocked by overlapping "Set Deadline" tap region
- **Root cause:** The Continue button and the "Set Deadline" card occupy colliding hit
  zones; taps on the visually-enabled Continue button land on the deadline card — flipping
  goal type to Deadline and opening the date picker (even when dimmed in target-pace mode).
  A functional blocker that also silently mutates goal config.
- **Fix:** Fix the layout so Continue's tap target does not overlap the deadline card
  (constrain bounds / add spacing / disable the deadline card's hit-test when dimmed).
- **Screens:** `onboarding`

#### P1 — TS-6. Estimated-finish gematriya year drops the thousands component for far-future years `[merged: P1 + P2]`
- **Root cause:** For finish dates beyond Hebrew year 6000 the gematriya renderer drops the
  thousands component (year 6120 → "ק״כ"=120 → reads 5120, ~666 years in the past). At low
  pace / long horizon the estimated-finish year is a nonsensical far-past date; mid-range
  dates look plausible and mask the bug.
- **Fix:** Fix the gematriya year formatter to include the geresh-marked thousands
  component for Hebrew years ≥6000.
- **Screens:** `onboarding`

#### P1 — TS-7. City picker shows raw GeoNames admin1 CODE instead of region name for non-US countries
- **Root cause:** `_subtitleFor()` builds "admin1 · countryCode" from `cities.sqlite`, but
  the DB build (`tool/build_cities_db.dart:81`) stored GeoNames field index 10 = the admin1
  **code**, never joining `admin1CodesASCII` for the name. US codes coincide with postal
  abbreviations so they read fine; every other country shows an opaque number (Jerusalem "06
  · IL", Paris "11 · FR"). The raw code persists into the saved Sacred Time location label
  and the a11y content-desc.
- **Fix:** Join admin1 code → readable name via `admin1CodesASCII` at DB-build time, or fall
  back to the bare `countryCode`; persist and display the resolved region name.
- **Screens:** `city_picker`

#### P2 — TS-8. "Same start/anchor date rendered in two calendar systems on one screen
- **Root cause:** `TrackInfoCard._formatDate` honors `useHebrewCalendar` for the "Started"
  row, but `track_detail_screen.dart` computes the header "Since" date with
  `DateFormat.yMMMd(locale)` unconditionally in Gregorian (and "Est. finish" likewise), so
  under Calendar Preference=Hebrew the same activation date appears twice in incompatible
  calendars.
- **Fix:** Make the header "Since {date}" and "Est. finish" lines respect `useHebrewCalendar`
  (use the same `_formatDate` path as `TrackInfoCard`).
- **Screens:** `trackdetail`, `curriculum_settings`, `track_management_hub`,
  `parent_track_management`

#### P2 — TS-9. "Elapsed" row value duplicates its own label ("Elapsed | Elapsed 0 days")
- **Root cause:** `track_info_card.dart` passes label `l10n.trackInfoElapsed` for the row
  AND `_elapsedRemainingLabel` prepends it again, producing value "Elapsed 0 days".
- **Fix:** In `_elapsedRemainingLabel` drop the leading `l10n.trackInfoElapsed` so the value
  renders just "$elapsedDays days".
- **Screens:** `trackdetail`, `curriculum_settings`, `track_management_hub`,
  `parent_track_management`

#### P2 — TS-10. Multi-step wizard discards prior state on Back; no "discard changes?" guard
- **Root cause:** Backing through the Add-Track wizard resets earlier steps (deadline
  reverts to Target Pace, sefer cleared); Point Config back silently discards a pending
  unsaved edit; Lifetime Marking back discards a pending bulk selection — none prompt or
  preserve config.
- **Fix:** Persist wizard step state so Back preserves selections/deadline, and add a
  "discard unsaved changes?" `PopScope` guard on Point Config and Lifetime Marking.
- **Screens:** `addtrack`, `point_config`, `lifetime_marking`

#### P2 — TS-11. Add-Track step-count denominator is unstable/stale (1 OF 6 → 1 OF 7)
- **Root cause:** Selecting a curriculum with programs (Talmud Bavli) inserts the program
  step and grows total 6→7; Back doesn't revert the denominator, so curriculum-select is
  mislabeled "STEP 1 OF 7" before any program is chosen.
- **Fix:** Compute the denominator from the actual current path (recompute on Back, or
  compute total upfront from curriculum selection) so "STEP n OF N" is stable.
- **Screens:** `track_management_hub`

#### P2 — TS-12. Siyum aggregate label duplicates "Seder"; scope persisted as English "Genesis"
- **Root cause:** Curriculum scope is seeded with the Sefaria English translation
  (`scope_value='Genesis'`) rather than a transliteration key, and the Bavli level-1 key is
  stored WITH the level word ("Seder Zeraim"). `aggregateSiyumLabel()` builds "Siyum Seder "
  + "Seder Zeraim" = "Siyum Seder Seder Zeraim" in transliteration mode.
- **Fix:** Normalize the aggregate seder key (strip leading "Seder " before composing the
  label in `siyum_milestone_label.dart`); ensure `scope_value` stores a transliteration/
  content key (or resolves through the transliteration map at render) so it never surfaces
  "Genesis". (Overlaps IL-2 nusach resolver.)
- **Screens:** `siyumim_milestones`

#### P2 — TS-13. Timeline month headers use hardcoded English months (latent localization divergence)
- **Root cause:** `SiyumimTimelineView._monthKey()` indexes a hardcoded English `months[]`
  array instead of `DateFormat.yMMM(locale)`, while per-card dates use locale-aware
  `formatMilestoneDate()`. Masked by the force-English locale bug; diverges once IL-6 lands.
- **Fix:** Replace the hardcoded `months[]` with `DateFormat`-based locale-aware formatting.
- **Screens:** `siyumim_milestones`
- **Re-test dependency:** verify after IL-6 (locale wiring).

#### P2 — TS-14. Parent track-management copy uses own-profile "your" wording in parent-manages-child context
- **Root cause:** The empty-state subtitle is `manageTracksDetail` ("Create and edit YOUR
  learning tracks") and the archive/wipe dialog body says "What should happen to YOUR
  completion history?" — own-profile wording leaks into the child-management surface.
- **Fix:** Use child-management copy ("your child's learning tracks" / "your child's
  completion history").
- **Screens:** `parent_track_management`

#### P2 — TS-15. Delete Track dialog inverts safety hierarchy; destructive action most prominent; ragged alignment
- **Root cause:** The dialog stacks "Cancel" / "Archive (keep history)" as low-emphasis text
  links above a large solid-red "Delete and wipe history" button (irreversible action draws
  the eye), at three horizontal offsets, with the red label wrapping at 1.3.
- **Fix:** De-emphasize the destructive option (outline/text), give Cancel/Archive
  equal-or-greater prominence, align all three actions consistently, and prevent the red
  label wrapping at large text.
- **Screens:** `track_management_hub`, `parent_track_management`

#### P2 — TS-16. Archive/Delete dialog offers an action the app refuses post-commit (last active curriculum)
- **Root cause:** With a single active track the Delete dialog still offers Archive/Delete;
  tapping Archive shows a snackbar "At least one curriculum must remain active" — the guard
  is correct but surfaced only AFTER the user commits in the destructive dialog.
- **Fix:** Disable/annotate the Archive/Delete options up front (with the "last active
  curriculum" reason) when the track is the only active one.
- **Screens:** `track_management_hub`

---

### ROOT: profiles-progress-learning

#### P1 — PP-1. Setup/change Parent-PIN keypad lacks a busy guard on enter→confirm (rapid-tap digit leak) `[merged: P1 + P2 + P2 partial-entry-on-resume]`
- **Root cause:** In `parent_pin_setup_dialog.dart _onFourDigits()` (and
  `pin_flow_controller.dart _handleSetup/_handleChange`) the enterNew→confirm transition
  does `setState({_isConfirmStep=true; _digits=''})` WITHOUT setting `_busy=true`, while
  `appendDigit` only guards on `_busy` and `length>=4`. A 5th queued tap after the buffer
  resets to '' is appended as digit 1 of the confirm PIN → spurious "PINs do not match" or an
  unintended leading digit. Verify mode sets busy synchronously and is unaffected.
  Separately, a partial masked PIN entry survives HOME/resume on the verify gate.
- **Fix:** Raise `_busy` (or a transition lock) synchronously during the enter→confirm
  transition before resetting `_digits`, mirroring the verify-mode keypad; and clear partial
  PIN entry (or dismiss) on app pause/background for the verify gate.
- **Screens:** `pin_flow`

#### P1 — PP-2. Edit Learner Child/Adult mode toggle is interactive but silently discarded on Save `[merged: P1 + P2]`
- **Root cause:** `editProfileFlow()` in `profile_edit_delete_actions.dart` calls
  `repo.updateProfile(id, displayName, avatarIndex)` and never passes the selected mode. The
  `SegmentedButton` visibly toggles `_mode` but the value is dropped on Save (avatar IS
  persisted, mode is NOT). A code comment says "Mode is shown but not editable" yet the
  control is not disabled. A parent can believe they demoted an adult to child (which gates
  adult surfaces behind a PIN) when nothing changed — a safety concern.
- **Fix:** Persist the selected mode through `editProfileFlow`/`updateProfile` on Save
  (preferred, since the control implies editability), or disable the control with a clear
  non-editable cue. Unify the Add (cards) vs Edit (segmented pill) mode-selection UIs.
- **Screens:** `manage_learners`

#### P1 — PP-3. LifetimeMarking exposes internal "level N" id and gives no persisted-vs-selected distinction `[merged: P1 + P2 + P2 internal-data-leak]`
- **Root cause:** The "Mark as lifetime learned" header renders "Selected: {count} • level
  {level}" where `_currentLevel` returns `_currentDisplayItems.length` (folder size, not
  hierarchy depth), so the user sees a nonsense "level" that jumps 1→6→11. Persisted rows
  render with the identical green checkbox/highlight as new selections; selection lingers
  after Save; "Clear selection" leaves persisted rows green; leaf completion status renders
  the internal enum "Live" instead of a learner-facing label.
- **Fix:** Remove the "level {N}" token from the header; give persisted/already-learned rows
  a distinct visual treatment from session selections; clear the selection after a successful
  Save; make "Clear selection" visibly reset session-selected rows while preserving
  persisted state; map the leaf status enum "Live" → "Learned"/date.
- **Screens:** `lifetime_marking`, `curriculum_progress`, `progress`, `settings`

#### P1 — PP-4. Lifetime header mislabels initial LEARN events as "chazaros" (reviews) `[merged: P1 + P2]`
- **Root cause:** `lifetime_knowledge_providers.dart:471` sets `totalChazaros =
  completions.length`, counting EVERY completion (limud + chazara), rendered via "{count}
  total chazaros". Learned-but-never-reviewed users see a non-zero "total chazaros" that is
  actually their learn count, while every leaf shows "Live" with zero chazaros — the screen
  self-contradicts (also "7 chazaros" vs per-stage "Review 1: 0, Review 2: 0").
- **Fix:** Count only chazara (review) completions for `totalChazaros` (exclude the initial
  limud), or relabel the header to "items learned / completions"; align with the leaf "Live"
  state.
- **Screens:** `lifetime_knowledge`, `curriculum_progress`

#### P1 — PP-5. Curriculum-progress expanded breakdown shows two identical "Learn" stage columns
- **Root cause:** Expanding any level/perek shows a four-stage row whose first two labels are
  both "Learn:" ("לימוד") with the same value, instead of four distinct stage names.
  Reproduced on every row and both modes — a stage-name/mapping defect.
- **Fix:** Fix the stage-name mapping so each of the four SRS stages renders a distinct label
  (Learn, Review 1/2/3 or configured names). (Closely related to IL-5; fix together.)
- **Screens:** `curriculum_progress`

#### P1 — PP-6. Large-text (font 1.3) layout breaks: overflow + ellipsized profile/breadcrumb content `[merged: P1 + P2 overflow stripes + P2 long-label set]`
- **Root cause:** Profile-picker cards overflow ("BOTTOM OVERFLOWED BY 1.2 PIXELS") and clip
  "Tap to continue" at 1.3; the onboarding scope-step breadcrumb Row overflows ("RIGHT
  OVERFLOWED BY 37 PIXELS", "selection" clipped); the profile display name is hard-truncated
  (`maxLines:1` + ellipsis at fontSize 22) → "Menache…"; reward titles wrap mid-word
  ("IceCre/am"), "Mark Completed" splits, goal-pace labels ellipsize, "Completion (with
  Chazara)" collides with "0%".
- **Fix:** Give profile cards flexible/auto-sizing height (or scrollable content); wrap the
  breadcrumb Row in `Flexible`/`Wrap`/`FittedBox`; allow the profile name to wrap (maxLines 2
  / auto-size); give competing labels `FittedBox`/min-width and Row spacing/`Flexible`
  between subtitle and trailing value. Verify at font_scale 1.3.
- **Screens:** `profile_picker`, `Signup`, `onboarding`, `learning`,
  `Child prize redemption screen`, `addtrack`, `trackdetail`, `parent_track_management`

#### P1 — PP-7. EmptyLogin / PermissionPrompt unreachable; AcceptInvite `/invite` deep link unregistered `[merged: P1 + P2 accept_invite/manage_grants]`
- **Root cause:** Several documented surfaces have no reachable path: `EmptyLoginScreen` is
  pre-empted because every zero-profile sign-in auto-creates a default learner and lands on
  the dashboard (its `finalProfileCount==0` branch and "I'm a tutor" button are dead);
  `ManageGrants`/`AcceptInvite` only render when a grant exists, so `_EmptyGrantsView` is
  dead code; Onboarding's `PermissionPrompt` route is registered with `authGuard` which
  rejects it during first-run and diverts to SignIn (permissions stay denied); the
  AcceptInvite `/invite` deep link is advertised but only `/sign-in` is registered in
  `AndroidManifest`.
- **Fix:** Stop auto-creating a default profile so the EmptyLogin branch can fire (or remove
  the dead surface); add a non-conditional entry (menu/deep-link) to `ManageGrants`; relax
  `authGuard` for `PermissionPrompt` during first-run (or push post-profile-creation);
  register an intent-filter for the `/invite` pathPrefix in `AndroidManifest.xml`.
- **Screens:** `empty_login`, `manage_grants`, `permission_prompt`, `accept_invite`
- **Note:** the *product* question of which surfaces are intended to be live is tracked as
  PD-9; the code fixes above are unconditional.

#### P2 — PP-8. Internal "level N" id + "Live" enum leaked into UI — *folded into PP-3.*

#### P2 — PP-9. Lifetime Marking: persisted vs selected identical; Clear/Save don't update selection — *folded into PP-3.*

#### P2 — PP-10. "Select all in this list" never toggles to deselect-all
- **Root cause:** After "Select all in this list" checks all rows, the label stays the same
  and re-tapping is a no-op; a `deselectAllInThisList` string exists in `app_en.arb` but is
  not wired.
- **Fix:** Toggle the button to `deselectAllInThisList` when all rows are selected.
- **Screens:** `lifetime_marking`

#### P2 — PP-11. Edit Learner dialog hides the avatar picker behind the autofocus keyboard at 1.3
- **Root cause:** The dialog autofocuses the name field (keyboard up); at 1.3 the enlarged
  content + keyboard push the fixed-height (`SizedBox height:60`) "Choose Avatar" row and the
  mode toggle below the fold.
- **Fix:** Make the dialog content scrollable within the viewport (or don't autofocus), so
  the avatar picker and mode toggle stay reachable with the keyboard up.
- **Screens:** `manage_learners`

#### P2 — PP-12. PIN change flow reuses the verify-gate subtitle ("to access parent settings")
- **Root cause:** `parent_pin_keypad_dialog._subtitle` returns `l10n.enterParentPinSubtitle`
  for the `verifyCurrent` step of the Change-PIN flow, so "Enter Current PIN" reads "…to
  access parent settings" even though the user is confirming identity to change the PIN.
- **Fix:** Add a dedicated subtitle string ("Enter your current PIN to change it").
- **Screens:** `pin_flow`

#### P2 — PP-13. New-profile context not reflected during PIN setup (stale header shows previous profile)
- **Root cause:** After creating a child, the forced Set Parent PIN dialog names the new
  child but the app-shell header chip behind it still shows the previously-active
  profile/mode (active profile isn't switched to the new one during setup).
- **Fix:** Update the active-profile/header context to the newly-created profile during the
  forced PIN setup.
- **Screens:** `pin_flow`

#### P2 — PP-14. Empty states are bare unstyled placeholders or missing entirely
- **Root cause:** Pending Prizes, Manage Tutors ("No tutors invited." node absent), the
  tutor profile-switcher "Profiles" header with no rows, Recent Activity filtered charts
  (blank plot), the Study Days fallback, and the reward "Tap below to add one" pointing at a
  non-existent button all render bare/missing.
- **Fix:** Add designed empty states (icon + copy); ensure the "No tutors invited."/empty
  nodes render (investigate the unresolved grants provider — overlaps SY needs-investigation
  and PP-7); suppress the "Profiles" header at zero profiles; add "No activity in this
  range"; fix the reward empty-state copy.
- **Screens:** `parent_pending_redemptions`, `manage_tutors`, `manage_grants`,
  `recent_activity`, `study_day_config`, `reward_configuration`

#### P2 — PP-15. Transient load/resume frames flash real zeros, blank bodies, or paint artifacts
- **Root cause:** The dashboard STATS panel shows real zeros (OVERDUE 0, "0 of 0 sections",
  0%) for 1-2s — indistinguishable from caught-up — while sibling cards show "…"; Point
  Config flashes a blank grey body with a green-square paint artifact for 1-3s after resume
  (`autoDispose FutureProvider` re-fetch).
- **Fix:** Render a skeleton/spinner consistent with the sibling cards while the STATS panel
  and Point Config body load/re-fetch (keep last content or a placeholder).
- **Screens:** `scheduler`, `dashboard`, `point_config`

#### P2 — PP-16. Profile cards grotesquely tall on tablet/landscape (phone-tuned childAspectRatio)
- **Root cause:** `ProfileGrid` (`profile_grid.dart:34-38`) uses
  `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.67)`. On
  a wide tablet each column is ~1180px → card height forced to ~1760px while content is
  ~300px (~60% whitespace, one row per screen).
- **Fix:** Use a width-aware aspect ratio / `SliverGridDelegateWithMaxCrossAxisExtent` / cap
  max-height so cards size sensibly on wide layouts.
- **Screens:** `profile_picker`

#### P2 — PP-17. Search does not alias Ashkenazi transliteration or Hebrew script ("shabbos" → No results)
- **Root cause:** The ContentHierarchy search index only carries the Sephardi
  transliteration alias, so "shabbos"/"taanis" return false-empty while "shabbat" matches.
- **Fix:** Add Ashkenazi-transliteration aliases (and ideally the Hebrew-script form) to the
  content search index.
- **Screens:** `content_hierarchy`

#### P2 — PP-18. No clear (X) affordance in the content-search field
- **Root cause:** The search `TextField` uses `InputBorder.none` and defines no
  `suffixIcon`/clear button; a query can only be erased with backspace.
- **Fix:** Add a suffix clear (X) icon that resets the query in one tap.
- **Screens:** `content_search`

#### P2 — PP-19. No-results query echo and long titles render unbounded (latent clip/wrap on narrow widths)
- **Classification:** needs-investigation (borderline on tablet — see §4 investigation queue).
- **Root cause:** The no-results message echoes the raw query verbatim with no clamp; the
  pending-redemption reward title uses an `Expanded Text` with no `maxLines`/ellipsis. Fit on
  the 2560px tablet but would wrap/clip on a narrow phone.
- **Fix:** Add `maxLines`/`overflow:ellipsis` and a clamp; verify on a phone-width device.
- **Screens:** `content_search`, `parent_pending_redemptions`

---

### ROOT: gamification

#### P1 — GA-1. Dashboard STATS panel shows real-looking zeros during load instead of a skeleton — *folded into PP-15* (cross-root; tracked under profiles-progress-learning).

#### P2 — GA-2. Input fields accept unbounded values (no max cap / max-length)
- **Root cause:** Adjust Points accepts 999,999,999,999; reward cost ~10 billion; reward
  name (70 chars) and learner/display names (60-64 chars) have no length cap. Validators
  only check `amount>0` / non-empty.
- **Fix:** Add sane maximum-value clamps (points adjustment, reward cost) and `maxLength`
  caps (reward names, profile/display names), with optional confirmation for very large
  values.
- **Screens:** `parent_settings`, `reward_configuration`, `manage_learners`, `Signup`

#### P2 — GA-3. Spend-economy reward model still uses legacy earn/unlock/threshold/ladder framing + threshold-uniqueness constraint
- **Root cause:** Per DEC-32/R4o-C1 the auto-unlock ladder was replaced by a spend economy
  (priced redeemable items debited against a balance), but copy/logic still reflect the old
  model ("No rewards earned yet", "reward ladder", "0/0 Rewards", "Points needed: N", "locked
  and blurred until they reach the points goal"), and `saveReward()` rejects two rewards at
  the same cost (`_hasDuplicateThreshold`) — a holdover ladder constraint.
- **Fix:** Rewrite achievements/reward copy to spend-economy framing (redeem/spend/price),
  and remove `_hasDuplicateThreshold` so a parent can offer multiple distinct rewards at one
  price.
- **Screens:** `gamification`, `reward_configuration`

#### P2 — GA-4. Rapid double-tap / re-entrancy races on navigation push and Send
- **Root cause:** The dashboard flame chip pushes `GamificationRoute` twice
  (`dashboard_body.dart`, no duplicate-route check); Invite-Tutor Send awaits `maybePop()` on
  success with the button guarded only by `_isLoading/_emailValid`, so a second tap pops an
  extra level (lands on Parent Settings, not Manage Tutors).
- **Fix:** Check for an existing route before pushing `GamificationRoute`; set a busy/disabled
  flag synchronously on Send before the await. (PIN step-transition leak is PP-1.)
- **Screens:** `gamification`, `invite_tutor`

#### P2 — GA-5. Tutor-grant resignation notification passes raw childProfileId as the child name
- **Root cause:** The on-screen resign dialog uses `childDisplayLabel`, but the
  fire-and-forget parent resignation notification passes `grant.childProfileId` (raw
  Firestore id) as `childName`.
- **Fix:** Pass the resolved child display label into the resignation notification's
  `childName`.
- **Screens:** `manage_grants`

#### P2 — GA-6. AcceptInvite/ManageGrants unreachable; `/invite` deep link unregistered — *folded into PP-7* (cross-root; code fix is unconditional).

#### P2 — GA-7. Reward edit mode indistinguishable from create; empty-name save is a silent no-op
- **Root cause:** Opening edit loads the reward but heading stays "Configure New Reward",
  subtitle/button stay new-reward copy; Save is always enabled and tapping with empty
  name/cost returns `RewardSaveInvalidInput`, handled as a silent no-op.
- **Fix:** Switch header/subtitle/button to edit-mode copy ("Edit Reward"/"Update Reward")
  when editing, and disable Save until name+cost are valid (or surface inline validation).
- **Screens:** `reward_configuration`

#### P2 — GA-8. Inconsistent tile/section/title capitalization
- **Root cause:** Parent Settings "Reward configuration" (lowercase c) breaks the Title Case
  pattern and its own destination header; Manage Tutors mixes "ACTIVE (n)" all-caps with
  "Pending (n)" title-case.
- **Fix:** Normalize l10n: title-case "Reward Configuration" on the tile; make Active/Pending
  headers share one casing style.
- **Screens:** `parent_settings`, `manage_tutors`

---

## 3. Product-Decision List

These look like bugs but may be intended. **Do not change anything until the user answers
each question.** Phrased as crisp decisions.

- **PD-1 (i18n / mixed-script rows) —** Hebrew-Terms ON Hebraizes only configured domain
  terms (siyumim/chazara/curriculum names) while generic chrome (Streak, Lifetime, Points,
  OVERDUE, TODAY DUE, done) follows the `en` device locale, producing rows like
  "Streak | סיומים | Lifetime" and "Completion (with חזרה)" that read as half-translated.
  **Q: Harmonize sibling labels in a row (translate the chrome OR keep domain terms in Latin
  transliteration so the row is one script), or accept the documented split and add a visual
  grouping/separation so mixed-script rows don't read as a defect?**
  *(13 findings — the largest product-decision cluster; several auditors hedged "arguably
  by-design".)*

- **PD-2 (daily due counter) —** Completing a daily task pulls the next item into the list so
  "N Items" and dashboard "TODAY DUE" stay constant (5 stays 5); the user never sees the due
  count fall toward "caught up". **Q: Should the daily due count be a fixed daily target that
  decrements to a reachable zero-due/caught-up state, or remain a rolling queue with a label
  that says so ("rolling queue" / "next up")?**

- **PD-3 (daf-granular completion) —** Completing one amud tile cleared BOTH amudim of the daf
  (2→0). **Q: Is daf-granular completion intended? If so, should the two amudim be presented
  as one tile (not two separately-completable tiles) so completing one doesn't appear to
  silently clear the other?** *(Pairs with PD-2; both on `learning`/`scheduler`.)*

- **PD-4 (points-but-no-rewards dead end) —** A child has 250 spendable points but zero
  parent-configured rewards; Achievements/Redeem correctly read empty while the card says
  "you're doing great!". **Q: Should the empty state prompt/guide the parent to set up
  rewards (and adjust the "doing great" copy) instead of presenting an inert dead-end?**

- **PD-5 (single-member siyum aggregate) —** In timeline mode a single masechta completion
  (Berakhos, sole gemara masechta in Seder Zeraim) appears as both a unit milestone and an
  aggregate (Siyum Seder Zeraim) on the same date. **Q: Should the timeline suppress the
  aggregate row when the aggregate has a single member, or keep the documented flat
  representation?** *(Auditor flagged "likely by-design".)*

- **PD-6 (filtered streak headline) —** Under a curriculum filter with no completions the
  headline still shows "1 Day Streak" / "Personal Best: 1" (streak is global) while the
  filtered calendar shows today as hollow. **Q: Should the streak headline reflect the
  filter, or be visually subordinated / re-framed as "across all curricula" so it doesn't
  contradict the empty filtered calendar?**

- **PD-7 (Manage Goals vs Manage Tracks) —** Both Parent Settings tiles push the same
  `ParentTrackManagementRoute` ("Tracks & Goals") with no goals landing until you drill into
  a track (acknowledged in a code comment). **Q: Give "Manage Goals" a dedicated
  goals-focused view, merge the two tiles, or relabel so the destination matches the IA?**

- **PD-8 (prev-chevron after completion) —** On TextDisplay the prev-chevron is enabled when a
  Mishna is reached by browsing but disabled after Mark-complete auto-advance (the completed
  item is dropped from the remaining-daily-tasks set). **Q: Should the prev-chevron allow
  paging back to a just-completed item so the affordance is consistent regardless of how the
  screen was reached?**

- **PD-9 (which dead surfaces are intended live) —** EmptyLogin, ManageGrants empty state,
  PermissionPrompt, AcceptInvite are unreachable in their target state (code fixes tracked in
  PP-7). **Q: Confirm which of these surfaces are intended to be live (so we wire entry
  points) vs. dead code to remove.**

- **PD-10 (TextDisplay controls / Chumash leaf) —** The TextDisplay app bar has only Back +
  chevrons (no per-text nikud/script toggle, no Share — all global in Settings); action/badge
  labels stay English under Hebrew-Terms; the Chumash browse-leaf has no translation pane and
  no Mark-complete path unlike the Mishna view. **Q: Are per-text nikud/script toggles and
  Share intended on TextDisplay? Should action/section labels localize? Should the Chumash
  leaf get a translation pane and a mark-as-learned path like the Mishna view?**

- **PD-11 (auth-pair voice/labels) —** Sign In uses playful copy ("Your Email"/"Secret Key",
  "Welcome Back!", "New to the Quest? Register Here") while Signup uses plain copy ("Email
  Address"/"Create Password", "Already exploring? Log In"). **Q: Align field labels and copy
  voice across the auth pair (one term for email/password, consistent sync wording)?**

- **PD-12 (signup confirm-password / terms; large-text field clipping; tutor-invite
  affordances) —** Combined auth/onboarding decisions:
  - The audit brief lists confirm-password and terms controls that don't exist (single
    password field, no terms checkbox). **Q: Are confirm-password and terms-of-service
    acceptance required (add them) or is the control list stale (update the spec)?**
  - At font 1.3 a focused field with a long value horizontal-scrolls and clips mid-character
    with no ellipsis (standard `TextField` behavior). **Q: Accept the standard scroll-to-cursor
    clipping, or improve large-text legibility (grow the field / reduce in-field text scale)?**
  - Invite/tutor flows omit a confirmation before granting a stranger access, differentiated
    "already invited" feedback, strict email validation (`_emailValid` is just `contains('@')
    && contains('.')`), and actionable pending invites on ManageGrants. **Q: Which of these
    are required for this parental-control access-granting surface — add a confirm step,
    "already invited" feedback, tighter validation, accept/decline on pending invites?**

---

## 4. Foundational-First Callout

Fix these **before** the dependent screen-level work, because they change what downstream
screens render or how they are reached — re-test the dependents **after** each lands.

1. **IL-6 — Wire `MaterialApp.locale` to the per-profile `app_locale_pN` pref (DNI-341),
   add an in-app UI-language switcher.** *This must come first.* Today `locale:null` means the
   `he` UI lever is unexercisable; once wired, **every** `he`/RTL screen re-renders. It will
   (a) un-mask **TS-13** (timeline month headers fall back to a hardcoded English array the
   moment locale is honored), (b) change how **IL-7** (RTL breadcrumb), **IL-9** (Hebrew
   literal leaks), **ST-4** (sync-status remainder), and **IL-3** (he-mode gematriya/plural)
   actually present, and (c) make the entire `he`-RTL audit re-runnable. **Re-test all
   i18n/RTL clusters after IL-6.**

2. **IL-1 — Persist/propagate the Hebrew-Terms preference across the offline-signup DB
   switch.** The wizard currently reads `terms.isHebrew` as TRUE regardless of the user's
   English choice. Until this is fixed, you cannot trust *any* Hebrew-Terms-OFF rendering in
   the wizard (TS-1 "Starts:", IL-2 nusach leaks, IL-3 plurals, IL-5 stage names all read
   through the same term axis). Fix IL-1 before validating those en-mode renders.

3. **IL-4 — Correct the `brandCoral*` theme constants (or repoint to a real error color).**
   This is a one-line-of-constants change that immediately restores warning/error urgency to
   every `_showError()` snackbar and every offline data-loss card across `Signup`/`sign_in`.
   Do this early so destructive-warning screens are re-auditable with correct color semantics
   (relevant when re-testing AN-1, the offline-account and upgrade flows).

4. **AN-3 / persistent-switcher badge — Make the badge reflect parent-elevated context.**
   This single `ProfileSwitcherBar` change clears the "CHILD MODE on a parent surface"
   contradiction across **six** parent-management screens at once. Land it before
   re-auditing any parent sub-route so testers aren't re-filing the same chrome defect per
   screen.

5. **SY-1 — Restore Firestore rules / App-Check for the audit account (or add a debug hook
   to force `DeviceRestoreRoute`).** PERMISSION_DENIED on every read currently blocks live
   verification of **SY-2** (device_restore), **SY-3** (the Backup&Sync exception surface,
   because the outbox can't flush), and the cloud-pull half of the offline-delete
   investigation. Unblock this before the `sync`-root and `device_restore` work, and confirm
   whether the denial is test-env or a production rules regression.

6. **IL-3 — The ICU-plural l10n sweep.** A single pass over `app_en.arb` /
   `app_localizations` regenerates many count strings touched by `siyumim_milestones`,
   `lifetime_*`, `progress`, `point_config`, `reward_configuration`, `gamification`,
   `recent_activity`, `onboarding`, `addtrack`. Doing it once, centrally, prevents per-screen
   duplicate edits and merge churn — run it as one foundational sweep, then re-test count=1
   and counts>1 on each surface (and gematriya/space in he-mode after IL-6).

> **Investigation queue (run before committing fixes):** the `sync` offline-delete
> resurrection (tombstone-vs-pull ordering; confirm self-heal vs durable), the
> `study_day_config` per-track term-resolution divergence (same sedarim render different
> script/nusach across tracks under identical settings), PP-19 narrow-width clip (verify on a
> phone), the greeting time-of-day thresholds (GA "Good morning" at 12:49 PM), and the
> unresolved grants provider behind the missing "No tutors invited." empty node (PP-14/PP-7).

---

## 5. Suggested Fix-Wave Sharding (parallel execution)

Seven shards aligned to owned roots. **Wave 0 (foundational) lands first and serially**;
Waves 1-2 then run in parallel per root, with the re-test gates noted.

### Wave 0 — Foundational (serial, blocks the rest)
- IL-6 (locale wiring + switcher) · IL-1 (Hebrew-Terms persistence) · IL-4 (theme colors) ·
  AN-3 (switcher badge) · SY-1 (Firestore rules / debug hook) · IL-3 (ICU-plural sweep).
- **Gate:** after Wave 0, re-run the `he`/RTL audit and the parent-sub-route chrome audit;
  feed regressions back before Wave 1.

### Wave 1 — Confirmed P0/P1 per root (parallel across shards)

| Shard | Root | Wave-1 clusters (P0/P1) |
|---|---|---|
| A | account-nav | AN-1 (P0), AN-2, AN-4, AN-5 |
| B | sync | SY-2, SY-3 *(after SY-1)* |
| C | settings | ST-1 |
| D | i18n-labels-theme | IL-2, IL-5 *(IL-1/3/4/6 already in Wave 0)* |
| E | tracks-scheduler | TS-1, TS-2, TS-3, TS-4, TS-5, TS-6, TS-7 |
| F | profiles-progress-learning | PP-1, PP-2, PP-3, PP-4, PP-5, PP-6, PP-7 |
| G | gamification | *(no standalone P1 — GA-1 folded into PP-15; starts Wave 2)* |

> Cross-root pairing: IL-5 ↔ PP-5 (stage-name mapping) — assign to **one** owner (Shard D or
> F) to avoid double edits. PP-7 ↔ GA-6 (deep link / grants) — one owner (Shard F).

### Wave 2 — Confirmed P2 per root (parallel; after Wave 1 of the same shard)

| Shard | Root | Wave-2 clusters (P2) |
|---|---|---|
| A | account-nav | AN-6, AN-7, AN-8, AN-9, AN-10, AN-11, AN-12 |
| C | settings | ST-2, ST-3, ST-4 |
| D | i18n-labels-theme | IL-7, IL-8, IL-9 |
| E | tracks-scheduler | TS-8, TS-9, TS-10, TS-11, TS-12, TS-13, TS-14, TS-15, TS-16 |
| F | profiles-progress-learning | PP-10, PP-11, PP-12, PP-13, PP-14, PP-15, PP-16, PP-17, PP-18, PP-19 |
| G | gamification | GA-2, GA-3, GA-4, GA-5, GA-7, GA-8 |

> Re-test gates: TS-13 after IL-6; all of Shard D/E i18n P2 after IL-6 + IL-1; PP-15 STATS
> skeleton verified against the dashboard load path (shared with the gamification chip).

### Wave 3 — Product decisions (blocked on user answers; no code until answered)
- PD-1 … PD-12. Triage owner: route each answered decision back to its owning shard
  (PD-1/PD-10 → D/F i18n+text_display; PD-2/PD-3 → F learning; PD-4/PD-5/PD-6 → G/E
  gamification+siyumim; PD-7 → E; PD-8/PD-10 → F text_display; PD-9 → F; PD-11/PD-12 → A
  auth).

### Investigation track (parallel, feeds Waves 1-2)
- Owned by whichever shard owns the screen: sync offline-delete resurrection (Shard B),
  study_day_config term divergence (Shard D/E), PP-19 narrow-width (Shard F), greeting
  thresholds (Shard G), unresolved grants provider (Shard F). Resolve classification →
  promote to a confirmed fix or a product decision.

---

*End of plan.*
