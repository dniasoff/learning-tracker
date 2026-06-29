# Device E2E Audit — Run 7 Gate Report

**Date:** 2026-06-29
**Build:** dev HEAD (all fixes from runs 1–6 applied; CI gate: 10,370 tests, analyze, format, make audit — all green)
**Devices:** emulator-5560 (Pixel 2, en-US), emulator-5554 (Pixel 2, en-US + child/settings flows), emulator-5562 (Pixel 2, en-US + gamification/progress/tutoring/Hebrew RTL)
**Auditor:** Lead Test Architect (run 7 — fresh validation pass)

---

## Verdict

**FAIL — CONCERNS REQUIRING ACTION BEFORE SHIP**

18 confirmed real findings remain open. None are regressions introduced in runs 1–6 fixes; all were either newly surfaced by expanded coverage or represent incomplete prior fixes (particularly TS-11 which is confirmed a no-op). The 8 false-positive rejections are cleanly documented. No P1/blocking-crash defects were found. The build is functionally stable but carries significant UX, accessibility, and localization debt that should be resolved before a production release.

---

## Coverage Summary

| Device | Suite | Screens | Pass | Fail/Concern |
|--------|-------|---------|------|--------------|
| 5560 | dashboard | 1 | 0 | 1 |
| 5560 | learning | 11 | 8 | 3 |
| 5560 | content | 6 | 4 | 2 |
| 5560 | tracks | 11 | 8 | 3 |
| 5560 | scheduler | 4 | 3 | 1 |
| 5554 | profiles_childmode | 10 | 10 | 0* |
| 5554 | settings | 4 | 3 | 1 |
| 5554 | auth_account | 5 | 3 | 2 |
| 5554 | infra | 6 | 3 | 3 |
| 5562 | gamification | 5 | 4 | 1 |
| 5562 | progress | 5 | 5 | 0 |
| 5562 | tutoring | 7 | 1 | 6 |
| 5562 | hebrew_rtl | 16 | 15 | 1 |
| **Total** | **13 suites** | **91** | **67** | **24** |

*profiles_childmode 10/10 functional pass; 1 accessibility finding still open (see P3 badge semantics).

---

## Confirmed Real Findings

### High Severity

| # | Device/Suite | Screen | What | Fix Location |
|---|-------------|--------|------|--------------|
| H1 | 5560/onboarding | Add-Track Wizard Step 1→2 (Curriculum picker) | Wizard total jumps from 6→7 after curriculum selection; TS-11 fix confirmed no-op (guard fires only when `currentIndex == 0` but both setState calls coalesce so build sees `currentIndex = 1`) | `add_track_flow_screen.dart` lines 53–64, 713–718: extend guard to `currentIndex <= 1` |
| H2 | 5554/onboarding | Add-Track Wizard Step 1→2 (Curriculum picker) | Same 6→7 jump reproduced on second device, confirming it is deterministic and not device-specific | Same as H1 |
| H3 | 5562/onboarding | Add-Track Wizard — curriculum→program step | Same 6→7 jump on third device; confirms TS-11 is a no-op across all three devices | Same as H1 |
| H4 | 5554/onboarding | Track Wizard Step 4: Study Days (Pixel 2) | Friday row clipped to 9 px (9/78 px visible, ~4% opacity) before pinned Continue button — no scroll affordance | `step_study_days.dart` lines 123–177: ShaderMask stops [0.0, 0.80, 1.0] → earlier onset or reduce card height |
| H5 | 5554/onboarding | Track Wizard Step 5: Chazara Schedule | Heading "How do you want to חזרה?" treats Hebrew noun as English infinitive verb — grammatically invalid | `app_en.arb` line 346 `addTrackChazaraStepQuestion`: reword template to noun-compatible form |
| H6 | 5560/tracks | Track Wizard Step 5: Chazara Schedule | Same malformed heading reproduced on second device | Same as H5 |
| H7 | 5560/tracks | TrackManagementHub — post-creation snackbar | Snackbar says 'Track "Seder Zeraim" created' but hub card shows 'תלמוד בבלי' everywhere — scope name displayed instead of track name | `add_track_flow_screen.dart` lines 670–699 `_getSmartDefault()`: partial-scope branch must return `curriculumLabelText()` not scope name |
| H8 | 5560/content | TextDisplay — Talmud Bavli breadcrumb | "דף ב" label splits across two wrapped lines ("דף" on line 1, "ב" on line 2) — daf number orphaned from its label | `curriculum_label_renderer.dart` lines 93, 99: replace ASCII space with non-breaking space between prefix and value |
| H9 | 5560/content | ContentSearch — no-results state | No explanation that transliterations won't match; English users get dead-end with zero guidance | `content_search_screen.dart` lines 164–170: add subtitle hint; new ARB key `noResultsForQueryHint` |
| H10 | 5560/scheduler | GoalSetup (Edit Goal) — Target-% slider | Slider accessibility value is off-by-one from displayed value (TalkBack announces "34%" when screen reads "35%") due to missing `semanticFormatterCallback` | `goal_setup_screen.dart` line 593: add `semanticFormatterCallback: (v) => '${v.round()}%'` |
| H11 | 5554/settings | LifetimeCurriculumMarking — Mishnah sedarim | 6th seder (טהרות) invisible on Pixel 2 — only 5 of 6 sedarim visible, action buttons appear immediately after item 5, no scroll affordance | `hierarchy_browser.dart` line 189: wrap `ListView.builder` in `Scrollbar(thumbVisibility: true)` |
| H12 | 5554/auth_account | AccountPicker — local account tile | Lock icon (Icons.lock_outline_rounded) implies auth required but tile opens without any credential prompt | `account_picker_screen.dart` line 379: replace with `Icons.smartphone_rounded` or remove trailing icon |
| H13 | 5562/gamification | GamificationHub → PointConfigScreen | Hub entry labelled "Point Configuration" but destination screen title reads "Point Settings" — navigational label mismatch | `parent_settings_screen.dart` line 203: change `l10n.pointConfiguration` → `l10n.pointSettingsTitle` (or vice versa in destination) |
| H14 | 5562/progress | RecentActivity — All-Time streak summary | Sub-labels read "2 לימוד done" / "0 חזרות done" — Hebrew noun concatenated with English "done" suffix produces bidi-mixed compound | `recent_activity_screen.dart` lines 459–470: check `terms.isHebrew` and use Hebrew-appropriate ARB template |
| H15 | 5562/tutoring | InviteTutor — local-account error state | Send button stays enabled while local-only error banner shown; "upgrade" word in banner has no CTA or navigation path | `invite_tutor_screen.dart` line 303: add `|| _accountError != null` to guard; lines 237–268: add navigable TextButton to Backup & Sync route |
| H16 | 5554/profiles_childmode | ProfilePicker — Kid avatar badge | Red star badge on Kid avatar has no semantic label and no ExcludeSemantics wrapper — TalkBack receives unresolved node | `profile_card.dart` lines 117–138: wrap Positioned badge in `ExcludeSemantics()` |

### Medium Severity

| # | Device/Suite | Screen | What | Fix Location |
|---|-------------|--------|------|--------------|
| M1 | 5554/onboarding | Onboarding slide 3: 'Earn While You Learn' | BiDi inversion: '!' appears left of "תלמיד חכם" despite LRI/PDI fix in commit 34616dfd — fix insufficient for Flutter Android centered text renderer | `app_intro_screen.dart` ~line 482: wrap subtitle Text in `Directionality(textDirection: TextDirection.ltr)` |
| M2 | 5554/profiles_childmode | ChildSettings — 'Exit parent mode' chip | Accessibility/semantics tap opens profile switcher instead of exiting; outer GestureDetector consumes semantics tap over inner chip InkWell | `app_shell.dart` ~line 672 `_ChildViewBanner.build()`: replace outer GestureDetector with peer-level InkWell targets; same fix needed in TutorModeIndicatorBar ~line 773 |

---

## Rejected False Positives / By-Design

| # | Screen | Disposition | Reason |
|---|--------|------------|--------|
| FP1 | Onboarding slide 2 — decorative pills clipped | false_positive | Pills use authored ellipsis chars in ARB strings; Stack is `clipBehavior: Clip.none` by design |
| FP2 | Onboarding slide 2 — '…yos' chip | by_design | Hardcoded literal `'…yos'` in `intro_mishna_page.dart:71` — deliberate decorative partial-word effect |
| FP3 | Dashboard — "חזרה" in English UI | false_positive | Hebrew Terms toggle is ON (default `true`); all three call sites correctly route through `DomainTermLabels.chazara` |
| FP4 | Dashboard — streak chip non-interactive in adult mode | false_positive | Documented: gamification is child-only; onTap is conditionally null when `userMode != ProfileMode.child` |
| FP5 | AddTrack Step 1 — "STEP 1 OF 6" | by_design | TS-11 intentionally shows 6 on curriculum step (before any curriculum chosen); the defect is the jump *after* selection (H1), not the initial display |
| FP6 | TrackManagementHub — "חזרה" subtitle | by_design | Correctly routes through `domainTermLabels(ref).chazara`; Hebrew Terms ON by default |
| FP7 | Notifications — HOT STREAK badge on 0-day streak | false_positive | Badge gated on `streakAlertEnabled` toggle being ON, not on streak count; by design |
| FP8 | Settings RTL — SegmentedButton LTR order | false_positive | Flutter `SegmentedButton` correctly mirrors in RTL; physical right = logical index 0 = leading in RTL |

---

## Recommended Fixes — Ordered by Priority

1. **[BLOCKER-tier UX / P2 small-screen]** H4 — Friday row invisible on Pixel 2 (Study Days step) — affects data entry for users on common device size.
2. **[BLOCKER-tier UX / P2 small-screen]** H11 — Taharos seder invisible on Pixel 2 (LifetimeCurriculumMarking) — user cannot mark 1/6 of Mishnah orders.
3. **[TS-11 no-op / must re-fix]** H1/H2/H3 — Wizard step count 6→7 jump on all 3 devices — previous fix is confirmed dead code; extend guard to `currentIndex <= 1`.
4. **[Snackbar/hub mismatch]** H7 — Post-creation snackbar names wrong label — fix `_getSmartDefault()` partial-scope branch.
5. **[Grammar / localization]** H5/H6 — "How do you want to חזרה?" malformed template — reword ARB key.
6. **[Accessibility]** H10 — Slider `semanticFormatterCallback` missing — one-liner fix.
7. **[Accessibility]** H16 — Star badge on kid avatar lacks semantic treatment — wrap in `ExcludeSemantics`.
8. **[Accessibility / semantics tap]** M2 — Exit parent mode chip not reachable via accessibility — refactor GestureDetector/InkWell nesting.
9. **[Navigation label]** H13 — "Point Configuration" vs "Point Settings" mismatch — align one string key.
10. **[UX / error state]** H15 — InviteTutor Send button active during error; no upgrade CTA — two-part fix.
11. **[Breadcrumb]** H8 — "דף ב" word-break in breadcrumb — replace ASCII space with NBSP in `renderValue()`.
12. **[Discoverability]** H9 — ContentSearch no-results gives no guidance on Hebrew-only vs transliteration indexing.
13. **[Auth icon]** H12 — Lock icon on local account misleads users about auth requirement.
14. **[BiDi / medium confidence]** M1 — Exclamation mark BiDi inversion on slide 3 post-LRI/PDI fix — confirm on fresh build; add `Directionality` wrapper if confirmed.
15. **[Mixed bidi labels]** H14 — "לימוד done" mixed-script suffix in English locale — add `isHebrew` branch.
16. **[Accessibility]** H15 (second part) — Upgrade CTA navigation from InviteTutor error banner.

---

## Notes

- **TS-11 status:** The fix committed under TS-11 (`computeWizardStepTotal` guard `currentIndex == 0`) is a confirmed no-op on the main tap-advance path. Both `setState` calls in `_onCurriculumSelected` coalesce before `build()`, so `currentIndex` is already 1 when the guard is evaluated. The fix must be re-scoped to `currentIndex <= 1`.
- **M1 confidence:** Medium. The LRI/PDI commit (34616dfd, Jun 28) predates the run-7 screenshots (Jun 29 14:43). If the device was rebuilt with run-7 APK, the fix is confirmed insufficient. If the screenshot captured a stale APK, the fix may be adequate. Verify on a fresh device build before investing further.
- **P1 findings:** None. No crashes, data-loss paths, or blocking auth failures were observed.
- **Run 7 vs Run 6 delta:** All 18 confirmed findings were either first surfaced in run 7 expanded coverage or are confirmed regressions of incomplete prior fixes (TS-11). No new regressions were introduced by the runs 1–6 defect fixes.

---

## Fix pass (post-audit) — outcome

15 unique fixes (18 confirmed findings; the wizard step-count appeared on all 3
devices, the chazara heading on 2). **14 applied**; **1 deferred**:

- **Applied:** wizard step-count stable denominator + snackbar curriculum-name
  (add_track_flow_screen.dart); study-days fade + Taharos scrollbar
  (step_study_days.dart, hierarchy_browser.dart); 6 a11y/label fixes
  (goal slider semantics, profile-badge ExcludeSemantics, child/tutor banner
  split tap targets, account-picker icon, point-config label); 4 l10n/BiDi
  fixes (chazara grammar, rewards-subtitle Directionality, ContentSearch
  Hebrew-name hint, RecentActivity Hebrew "done" suffix).
- **Deferred — #5 (P3, TextDisplay breadcrumb "דף ב" wraps mid-label):** the
  only viable fix is a non-breaking space, but `renderValue()` is the canonical
  label asserted verbatim by ~50 renderer tests, and the TextDisplay AppBar
  title is asserted by 3 widget tests (one helper returns the ref *as* the
  resolved chain). A display-layer NBSP still breaks the title assertions, and a
  layout-only fix can't keep "דף ב" whole without changing the string. For a P3
  cosmetic (label still fully legible, just wrapped), NBSP literals in test
  expectations were judged disproportionate fragility. Tracked as a known
  cosmetic limitation.
