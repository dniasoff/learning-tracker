# On-Device E2E Audit — Run 3 Gate Report

**Date:** 2026-06-25
**Build:** dev HEAD (all 32 fixes from runs 1+2 included)
**Devices:** 3 (emulator-5560 Pixel 5 API 34, emulator-5554 Pixel 2 API 28, emulator-5562 Pixel C tablet API 34)
**Auditor:** Lead Test Architect

---

## Verdict: CONCERNS

Run 3 validates that all 32 prior fixes are present in the build and confirms broad pass rates across 13 feature areas. However, **23 confirmed real findings remain**, including **7 high-priority P2 defects** spanning layout regressions on tablet and small-screen viewports, a silent-commit data bug in GoalSetup, a dead CurriculumSettings route, a raw account-ID data leak, and an unactionable error for local-only tutoring users. None of these are regressions from the fix batch; they are newly surfaced gaps. The build is not gate-ready for release until the P2s are resolved. P3 findings should be tracked and addressed in the next sprint.

---

## Coverage Summary

| Device | Suite | Screens | Pass | Fail | Pass % |
|--------|-------|---------|------|------|--------|
| 5560 | dashboard | 6 | 6 | 0 | 100% |
| 5560 | learning | 10 | 10 | 0 | 100% |
| 5560 | content | 9 | 8 | 1 | 89% |
| 5560 | tracks | 15 | 13 | 2 | 87% |
| 5560 | scheduler | 5 | 4 | 1 | 80% |
| 5554 | profiles_childmode | 16 | 15 | 1 | 94% |
| 5554 | settings | 4 | 2 | 2 | 50% |
| 5554 | auth_account | 6 | 3 | 3 | 50% |
| 5554 | infra | 5 | 4 | 1 | 80% |
| 5562 | gamification | 5 | 3 | 2 | 60% |
| 5562 | progress | 5 | 4 | 1 | 80% |
| 5562 | tutoring | 7 | 1 | 6 | 14% |
| 5562 | hebrew_rtl | 18 | 17 | 1 | 94% |
| **TOTAL** | | **111** | **90** | **21** | **81%** |

---

## Confirmed Real Findings

### P2 — High Severity (Must Fix Before Release)

| # | Device/Suite | Screen | Finding | Fix Location |
|---|-------------|--------|---------|-------------|
| 1 | 5554 / onboarding | Wizard Step 4 — Study Days | Friday row hidden below sticky Continue button on small screen; no scroll affordance shown | `step_study_days.dart` lines 123–158: cap visible rows or add partial peek |
| 2 | 5562 / onboarding | Sign-In screen (Welcome Back!) | Sign-in card left-anchored; right ~64% of tablet screen is blank grey | `sign_in_screen.dart` line 267: wrap `ConstrainedBox` in `Center` (mirror AN-10 fix already in `signup_screen.dart:534`) |
| 3 | 5560 / content | TextDisplay | AppBar shows raw Sefaria ref (e.g. "Mishnah Berakhot 3") during Next/Previous loading instead of a neutral placeholder | `text_display_screen.dart:57`: replace `??` fallback with `.when()` loading branch |
| 4 | 5560 / tracks | EditGoal | "No deadline" label wraps to two lines in 3-segment SegmentedButton | `goal_setup_screen.dart:630–658`: add `showSelectedIcon: false` or shorten l10n string |
| 5 | 5560 / scheduler | GoalSetup — Pace mode | Empty pace field silently commits stale value instead of showing validation error | `goal_setup_screen.dart:444–449` (onChanged) and `:677–679` (submit guard) |
| 6 | 5554 / auth_account | ProfilePicker / UpgradeToCloud | Raw synthetic account ID `offline_1a95407812a2` shown in ProfileSwitcherBar instead of friendly label | `app_shell.dart:458`: add `&& !authUser.email.endsWith('@offline.local')` guard |
| 7 | 5562 / progress | RecentActivity | Streak calendar "today" circle is ~174×174px on tablet (fills entire column) | `streak_calendar.dart:_DayRow.build`: cap cell with `ConstrainedBox(maxWidth: 44, maxHeight: 44)` inside `Expanded` |
| 8 | 5562 / progress | RecentActivity | English "done" leaks into all-time stat label when Hebrew terms active: "לימוד done" | `recent_activity_screen.dart:462–469`: add toggle-aware `termDone` helper to `DomainTermLabels` |
| 9 | 5562 / tutoring | InviteTutor | Local-only users see generic "Please try again" error that can never succeed; no cloud-upgrade CTA | `invite_tutor_screen.dart:_sendInvite` + `manage_tutors_screen.dart:307`: add local-account gate |
| 10 | 5554 / settings | CurriculumSettings | Route registered but zero UI entry points; screen is completely unreachable | `curriculum_progress_screen.dart`: add AppBar gear icon calling `CurriculumSettingsRoute` |

### P3 — High Severity (Fix in Next Sprint)

| # | Device/Suite | Screen | Finding | Fix Location |
|---|-------------|--------|---------|-------------|
| 11 | 5560 / onboarding | Wizard Step 7 — Mark Prior Learning | "Mark Completed" button wraps to two lines on Pixel 5 | `hierarchy_selection_panel.dart:318–342`: add `maxLines: 1` / `overflow: ellipsis` on button Text |
| 12 | 5560 / onboarding | Sign-In (Welcome Back!) | "Forgot password?" uses plain "password" while field is labelled "Secret Key" | `app_localizations_en.dart:2034` (`signInForgotPassword`): update to gamified phrasing |
| 13 | 5560 / onboarding | Sign-In (Welcome Back!) — offline | "Local account only" banner shown on Sign-In before user has typed anything; misleading for cloud-born users offline | `sign_in_screen.dart:137–151` (`_effectiveSignInMode`): add `SignInModeHint.offlineUnknown` variant |
| 14 | 5554 / onboarding | Wizard Step 7 — Mark Prior Learning | "Mark Completed" wraps to two lines on Pixel 2 (small screen) | Same as #11 |
| 15 | 5554 / onboarding | Onboarding page 2 — Never Forget a משנה | Progress indicator bar is near-invisible (very low contrast grey-on-white) | `intro_mishna_page.dart:151–191`: change fill color to green `0xFF1DB97D` or swap for `IntroPageIndicator` |
| 16 | 5562 / onboarding | Onboarding page 1 — Your Daily Torah Plan | Large blank dead zone (~150px) between SETUP PROGRESS bar and CTA on tablet | `app_intro_screen.dart:_buildDailyPlanBottomAnchored`: raise `maxHero` cap for tablet or add `Spacer()` |
| 17 | 5560 / tracks | MarkPriorCompletions | "siyumim" ignores Hebrew-terms toggle; shows English transliteration when Hebrew script expected | `app_localizations_en.dart:4071` + `bulk_mark_screen.dart:488`: wire `domainTermLabels(ref).siyumim` |
| 18 | 5560 / scheduler | GoalSetup — Deadline mode | "Update Goal" button stays enabled when a past Hebrew deadline is selected | `goal_setup_screen.dart:677` (button guard) and `:256` (`_pickHebrewDate` firstDate constraint) |
| 19 | 5554 / profiles_childmode | PinFlow Verify | PIN dialog subtitle says "access parent settings" when action is profile switching | `parent_pin_keypad_dialog.dart:15–36` + `profile_switcher_sheet.dart:355–363`: add optional subtitle param |
| 20 | 5554 / infra | ProfilePicker | Same raw offline account ID leak in ProfileSwitcherBar on cold-start (duplicate root cause as #6) | Same fix as #6 — `app_shell.dart:458` |
| 21 | 5562 / gamification | ChildRedemption | "Points" capitalisation inconsistent between balance header (capital P) and reward cost labels (lowercase p) | `app_en.arb:2463` (`redeemScreenCostLabel`): capitalise "points" → "Points" |
| 22 | 5562 / progress | RecentActivity | "TOTAL TORAH POINTS" subtitle implies all-time aggregate but shows date-range-scoped value | `recent_activity_screen.dart:156`: replace `chartTotalTorahPoints` with a new range-scoped l10n key |
| 23 | 5562 / hebrew_rtl | Settings | Segmented controls show default/selected segment on LEFT (visual end) in RTL; should be RIGHT | `settings_screen.dart:367–370` and `:476–479`: reverse options list order for each segmented control |

---

## Rejected Findings (False Positives / By-Design)

| Finding | Disposition | Reason |
|---------|-------------|--------|
| Wizard step count 6→7 jump mid-flow (screenshot path) | by_design | `computeWizardStepTotal` (TS-11) deliberately suppresses the program step only on index 0; revealing 7 on step 2 is accurate and regression-tested |
| Floating chip labels clipped at viewport edges on intro page 2 | by_design | Chips authored with explicit `'…yos'` and `"Review…"` strings; `Clip.none` + `Positioned` at edges is intentional decorative motif |
| ContentHierarchy AppBar "Browse Content" hardcoded | false_positive | `curriculum_list_screen.dart` is dead code; no call-site pushes `CurriculumListRoute`; on-device title comes from the correct `content_hierarchy_screen.dart` via l10n |
| AddTrack wizard denominator jump 6→7 (second reporter) | false_positive | Same as TS-11 by_design entry above; regression test at `add_track_flow_ts11_test.dart` explicitly asserts this |
| Taharos (6th seder) hidden behind action bar on small screen | false_positive | Action bar is in-flow Column child (not a Stack/overlay); item is below-fold in a bounded scrollable ListView, not occluded |
| PointConfig empty-state lacks CTA to Manage Tracks | by_design | Acceptance criteria in `docs/_archive/superseded/on-device-exhaustive-test-plan-2026-05-31.md` row 75 specifies centred text only; no button was ever designed or required |

---

## Recommended Fix Order

**Immediate (P2 — block release):**

1. `sign_in_screen.dart:267` — Center the sign-in card on tablet (one-liner, mirror of AN-10)
2. `app_shell.dart:458` — Suppress raw offline account ID in ProfileSwitcherBar (one-liner, guard already used in 3 other widgets)
3. `streak_calendar.dart` — Cap today-circle size on tablet (ConstrainedBox around AspectRatio)
4. `goal_setup_screen.dart:444–449, 677–679` — Validate empty pace field before submission
5. `step_study_days.dart` — Add scroll affordance / partial peek so Friday is discoverable on small screens
6. `text_display_screen.dart:57` — Replace raw-ref fallback with loading placeholder in AppBar title
7. `goal_setup_screen.dart:677` + `_pickHebrewDate` — Block past-deadline submission and add firstDate guard to Hebrew date picker
8. `curriculum_progress_screen.dart` — Add navigation entry point for CurriculumSettings
9. `invite_tutor_screen.dart` / `manage_tutors_screen.dart` — Gate tutoring invite on cloud account type
10. `recent_activity_screen.dart:462–469` — Fix "לימוד done" mixed-script label with toggle-aware helper

**Next sprint (P3):**

11–23: l10n string fixes (Secret Key / Forgot password, siyumim toggle, Points capitalisation, TOTAL TORAH POINTS subtitle), layout polish (button label wrapping, onboarding progress bar contrast, tablet blank gap, PIN dialog copy), RTL segmented control order, raw account ID cold-start suppression (duplicate of #2 above, same fix).

---

*Report generated by automated 3-device parallel E2E audit harness. Build: dev HEAD. Total screens audited: 111. Overall pass rate: 81% (90/111). Confirmed findings: 23 (10 × P2, 13 × P3). Rejected as false-positive or by-design: 6.*
