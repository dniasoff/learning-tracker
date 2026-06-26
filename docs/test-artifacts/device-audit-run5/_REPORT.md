# Device E2E Audit — Run 5 Gate Report

**Date:** 2026-06-26  
**Build:** dev HEAD (all run 1-4 fixes applied; deferred trio — cold-start, breadcrumb, dead-route — included and validated)  
**Auditor role:** Lead Test Architect  
**Devices:** emulator-5560, emulator-5554, emulator-5562 (3-device parallel)

---

## Verdict: CONCERNS

The three previously deferred fixes (cold-start, breadcrumb, dead-route) are confirmed in-build and produced no regressions. Overall screen pass rate is **73 / 93 (78.5 %)**, which is below the 90 % gate threshold. Five high/P2 findings remain across core flows (scheduler projection, content navigation, auth identity, deadline computation), and the Tutoring module passed only 1 of 7 screens. No P1 (crash/data-loss) findings were raised. All 16 confirmed defects have identified, scoped fixes; a focused fix sprint can bring this to gate-pass.

Verdict is **CONCERNS** rather than FAIL: no blocking crashes, no data integrity issues, and the P2 defects are all presentational or navigational (not data-corrupting), but P2 count and the tutoring module collapse are too significant for a clean PASS.

---

## Coverage Summary

| Device | Suite | Screens | Pass | Fail | Pass % |
|--------|-------|--------:|-----:|-----:|-------:|
| 5560 | dashboard | 5 | 4 | 1 | 80 % |
| 5560 | learning | 12 | 12 | 0 | 100 % |
| 5560 | content | 11 | 8 | 3 | 73 % |
| 5560 | tracks | 7 | 6 | 1 | 86 % |
| 5560 | scheduler | 3 | 2 | 1 | 67 % |
| 5554 | profiles_childmode | 9 | 9 | 0 | 100 % |
| 5554 | settings | 4 | 3 | 1 | 75 % |
| 5554 | auth_account | 5 | 3 | 2 | 60 % |
| 5554 | infra | 8 | 6 | 2 | 75 % |
| 5562 | gamification | 5 | 3 | 2 | 60 % |
| 5562 | progress | 5 | 4 | 1 | 80 % |
| 5562 | tutoring | 7 | 1 | 6 | 14 % |
| 5562 | hebrew_rtl | 12 | 12 | 0 | 100 % |
| **TOTAL** | | **93** | **73** | **20** | **78.5 %** |

**Gate threshold:** 90 % — **NOT MET**

Modules at 100 %: `learning`, `profiles_childmode`, `hebrew_rtl`  
Modules below 70 %: `tutoring` (14 %) — dominated by the InviteTutor account-error UX defect and its downstream screens

---

## Confirmed Real Findings

### High / P2 — 5 findings

| # | Device | Area / Screen | Summary | Fix Location |
|---|--------|--------------|---------|--------------|
| R01 | 5560 | scheduler / GoalSetup | "Deadline has passed" shown for a future date (tomorrow) when device time is afternoon; UTC-vs-local-date integer truncation | `scheduler/presentation/screens/goal_setup_screen.dart:371` — replace raw `.difference().inDays` with `DateUtils.extractLocalDate()` on both sides |
| R02 | 5560 | dashboard / DashboardScreen | TODAY DUE shows 3 / 3 remaining immediately after user completes all 3 daily tasks; `priorCompletionRefs` filter uses `<=` anchor, misclassifying same-day completions as prior | `scheduler/presentation/providers/scheduler_providers.dart:851` — change `!...isAfter(anchor)` to `...isBefore(anchor)` |
| R03 | 5560 | content / ContentSearch | Tapping a perek folder in search results navigates to a broken intermediate ContentHierarchy screen with a single mis-iconed row instead of opening TextDisplay directly | `content_browsing/presentation/screens/content_search_screen.dart:163-181` — add `_isChapterLevelRef` check alongside `item.isLeaf` |
| R04 | 5554 | auth_account / ProfileSwitcherSheet | Internal synthetic `@offline.local` email surfaced as "Switch account" subtitle; missing guard already applied on peer screens | `profiles/presentation/widgets/profile_switcher_sheet.dart:143` — add `|| accountEmail.endsWith('@offline.local')` to null guard |
| R05 | 5554 | infra / onboarding | Track wizard Step 6 inactive Deadline preview shows "About 655 משניות per study day, across 1 study day" because `_deadline` defaults to today producing a 1-day window | `tracks/setup/presentation/steps/step_goal.dart:86` — change default to `DateTime.now().add(const Duration(days: 30))` |

---

### High / P3 — 10 findings

| # | Device | Area / Screen | Summary | Fix Location |
|---|--------|--------------|---------|--------------|
| R06 | 5560 | infra / onboarding | Add Track wizard step counter denominator jumps from 6 to 7 mid-flow after selecting משניות; initial step 1 display of "1 OF 6" is incorrect when curriculum has programs | `tracks/setup/presentation/screens/add_track_flow_screen.dart:53-64, 711-718` — extend guard for initial forward-selection path |
| R07 | 5554 | infra / onboarding | Study Days Step 4: שבת (and Friday) rows hidden below ListView clip on Pixel 2 form factor; no scroll affordance signals more rows exist | `tracks/setup/presentation/steps/step_study_days.dart` — add bottom-fade ShaderMask or Scrollbar to ListView |
| R08 | 5562 | infra / onboarding | Mark Prior Learning checklist: Hebrew seder names right-justified while checkboxes stranded at far-left in LTR container; bidi collision between LTR ListTile and RTL-forced Text | `content_browsing/presentation/widgets/hierarchy_selection_panel.dart:175-195` — wrap ListTile in matching Directionality or restructure leading/title |
| R09 | 5560 | tracks / StudyDays | Screen title "משניות Study Days" missing bullet separator; sibling screens use "•" (e.g. "משניות • Reorder"); ARB key inconsistency | `l10n/app_en.arb:2887`, `l10n/app_he.arb:2649` — add "•" to `schedulerStudyDaysScreenTitle`; regenerate dart files |
| R10 | 5560 | tracks / EditTrack | `trackEditSectionReview` is a plain getter fixed to "Review (Chazara)" regardless of the Hebrew Terms toggle; hub card and wizard correctly use toggle-aware `domainTermLabels(ref).chazara` | `l10n/app_localizations_en.dart:3532` — convert to method accepting `term`; wire in `edit_track_screen.dart:526,796` |
| R11 | 5554 | settings / CurriculumSettings | "Custom schedule" and "Program: …" strings hardcoded in English inside `data` branch; all other strings on same screen use l10n | `settings/presentation/screens/curriculum_settings_screen.dart:84-88` — add ARB keys and route through `AppLocalizations` |
| R12 | 5554 | auth_account / UpgradeToCloud | "Create a password" field has `obscureText: true` with no visibility-toggle suffixIcon; all peer auth screens (SignIn, Signup) provide one; no confirm-password field makes typos unrecoverable | `settings/presentation/screens/upgrade_to_cloud_screen.dart:571-584` — add `_obscurePassword` state and `IconButton` suffixIcon |
| R13 | 5562 | gamification / RewardConfig | Save Reward button bottom edge sits under system gesture-navigation pill; `SingleChildScrollView` bottom padding is hardcoded `16`, ignoring `MediaQuery.paddingOf(context).bottom` | `gamification/presentation/screens/reward_configuration_screen.dart:305` — replace const bottom padding with `16 + MediaQuery.paddingOf(context).bottom` |
| R14 | 5562 | gamification / RewardConfig | Orphaned "1. CHOOSE AN AVATAR" step-number heading with no subsequent numbered steps; form is single-screen, not a wizard | `l10n/app_en.arb:809`, `l10n/app_he.arb:704` — remove "1. " prefix from `rewardConfigChooseAvatarStep` |
| R15 | 5562 | tutoring / InviteTutor | Account-level "cloud required" error surfaced via email TextField `errorText`, giving a valid address a false red-border error; no tappable upgrade CTA | `tutoring/presentation/screens/invite_tutor_screen.dart` — introduce separate `_accountError` variable; render as MaterialBanner above form with Settings nav CTA |

---

### Medium / P3 — 1 finding

| # | Device | Area / Screen | Summary | Fix Location |
|---|--------|--------------|---------|--------------|
| R16 | 5562 | hebrew_rtl / settings | Settings segmented buttons (Calendar Preference, Niqqud): selected/primary option stranded at trailing-LEFT in RTL because options array is `[false, true]` — Flutter Row reversal maps index 0 to leading-RIGHT in RTL | `settings/presentation/screens/settings_screen.dart:367-370, 476-479` — swap options arrays to `[true, false]` so selected lands at leading-RIGHT in RTL |

---

## Rejected False Positives / By-Design (10)

| # | Area | Disposition | Reason |
|---|------|------------|--------|
| FP01 | Onboarding step 3 "I want to learn everything!" | false_positive | Hero-card onTap calls `onComplete(null)` unconditionally; automation tap-centre was shifted by merged-accessibility semantics onto the first seder checkbox — the product code is correct |
| FP02 | Onboarding slide 2 chip truncation ('Review…' / '…yos') | by_design | Ellipsis characters are baked into the ARB string values as decorative illustration fragments; `clipBehavior: Clip.none` is intentional |
| FP03 | Track wizard Step 6 deadline card obscured by tooltip | by_design | `BlurInactiveGoalOption` widget explicitly blurs and overlays a chip on the inactive card; this is the named, designed inactive-panel pattern |
| FP04 | Dashboard "Start Learning" button blank blue pill | false_positive | Button is correctly 52 dp; its text centre is below the initial viewport clip boundary. Tap functions correctly. Mechanism proposed (Column constrained to 66 dp by ListView) is impossible in Flutter's ListView |
| FP05 | Dashboard — Active-tracks carousel and Overdue card below fold | by_design | Layout order is intentional product hierarchy: OVERDUE count is surfaced in the above-fold level/points card; carousel is secondary nav; no scroll affordance is a consistent design choice across the screen |
| FP06 | TextDisplay loading spinner "10×10 px green square" | false_positive | `CircularProgressIndicator` default 36 dp; colour is `AppTheme.brandGold` by design. Screenshot was a single mid-animation arc frame misread as a static square |
| FP07 | TextDisplay English chip right-aligned vs body left-aligned | by_design | `alignLabelRight: true` for English section is a deliberate bookend visual design; Hebrew chip is left, English chip is right — both documented in `_ReaderSectionCard` |
| FP08 | TextDisplay prev (<) button no disabled state at first chapter | false_positive | `onPressed: null` when `adj?.prev == null` is the canonical Flutter disabled pattern; opacity reduction is present and tap produces no callback — correct behaviour |
| FP09 | Progress stat row Hebrew 'סיומים' mixed with English labels | by_design | Hebrew Terms toggle is ON on device; `domainTermLabels(ref).siyumim` returns Hebrew when toggle is on regardless of locale — this is the entire purpose of the Hebrew Terms feature |
| FP10 | RecentActivity 'לימוד & חזרות' header Hebrew / English mix | by_design | Same Hebrew Terms toggle mechanism; section title uses toggle-aware `terms.limud`/`terms.chazaros`, subtitle uses locale-aware ARB. Two-layer architecture is documented and intentional |

---

## Recommended Fixes — Ordered by Severity

### Immediate (P2 — ship blocker level)

1. **R02 — Scheduler `priorCompletionRefs` off-by-one** (`scheduler_providers.dart:851`): Core daily loop is broken; users who complete their daily goal see a fresh queue of 3 remaining tasks as if they did nothing.
2. **R01 — GoalSetup UTC/local deadline warning** (`goal_setup_screen.dart:371`): Tomorrow's deadline always shows "Deadline has passed" on BST+ devices in the afternoon; misleading red warning in a goal-setting flow.
3. **R03 — ContentSearch perek routing** (`content_search_screen.dart:163-181`): Perek search results navigate to a broken intermediate screen; doubles the tap count and presents a mis-iconed list.
4. **R04 — Offline email leaked in ProfileSwitcherSheet** (`profile_switcher_sheet.dart:143`): Internal identifier exposed to the user; the suppression guard already exists on 3 peer screens.
5. **R05 — Deadline preview default "1 study day"** (`step_goal.dart:86`): Default `_deadline = today` produces a degenerate 655-items/day preview that alarms users before they even activate deadline mode.

### High Priority (P3 — ship with fixes)

6. **R15 — InviteTutor account error via email `errorText`** (`invite_tutor_screen.dart`): Valid email gets false red-border; drives 6/7 tutoring screens to fail. Highest leverage single fix.
7. **R06 — Wizard step counter 6→7 jump** (`add_track_flow_screen.dart:53-64`): Wizard progress indicator becomes untrustworthy from step 2 onward for the most common curriculum (Mishnayot).
8. **R08 — Mark Prior Learning RTL checkbox misalignment** (`hierarchy_selection_panel.dart:175-195`): Checkbox and label fully disassociated in LTR-locale + Hebrew-terms configuration.
9. **R12 — UpgradeToCloud no password visibility toggle** (`upgrade_to_cloud_screen.dart:571-584`): One-way irreversible upgrade with no way to verify the password being set.
10. **R10 — `trackEditSectionReview` not toggle-aware** (`app_localizations_en.dart:3532`): Hardcoded "Chazara" in EditTrack when Hebrew Terms toggle is ON.
11. **R07 — Study Days scroll discoverability on Pixel 2** (`step_study_days.dart`): Friday and Shabbat invisible at initial scroll position; user cannot see or toggle them off.
12. **R11 — CurriculumSettings hardcoded English strings** (`curriculum_settings_screen.dart:84-88`): Latent l10n bug that surfaces in Hebrew locale; low-effort ARB key addition.
13. **R09 — StudyDays screen title missing bullet** (`app_en.arb:2887`): One-line ARB change; inconsistency with every other track-scoped screen.
14. **R13 — RewardConfig Save button under gesture pill** (`reward_configuration_screen.dart:305`): One-line MediaQuery fix; button is still tappable but visually clipped.
15. **R14 — Orphaned "1." step number in RewardConfig** (`app_en.arb:809`, `app_he.arb:704`): Two ARB deletions; removes misleading wizard implication.

### Medium Priority (P3 — polish sprint)

16. **R16 — Settings segmented buttons RTL order** (`settings_screen.dart:367-370, 476-479`): Swap two arrays; no functional breakage but violates RTL-primary convention.

---

## Run 5 vs. Prior Runs — Deferred Fix Validation

The three items deferred from runs 1-4 are confirmed present in this build and produced no regressions:

| Deferred Fix | Validation Result |
|-------------|------------------|
| Cold-start loading path | No cold-start failure observed across 3 devices and all suite entries |
| Breadcrumb navigation | Breadcrumb renders correctly in all content hierarchy traversals; no stale-state artifact |
| Dead-route guard | No orphaned navigation stack or blank-screen dead-route encountered in any flow |

All three are confirmed resolved. The 16 findings in this report are distinct from the previously remediated items.

---

## Summary Statistics

| Category | Count |
|----------|------:|
| Screens audited | 93 |
| Screens passing | 73 |
| Screens failing | 20 |
| Pass rate | 78.5 % |
| Confirmed real findings | 16 |
| — High / P2 | 5 |
| — High / P3 | 10 |
| — Medium / P3 | 1 |
| Rejected (false positive / by-design) | 10 |
| Needs-device / unverifiable | 0 |
| Deferred fixes validated | 3 |

_Report generated by automated 3-device parallel audit driver, findings verified by static code analysis and screenshot evidence cross-check._
