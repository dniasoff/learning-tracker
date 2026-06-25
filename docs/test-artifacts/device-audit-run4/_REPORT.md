# Device Audit Run 4 — Gate Report

**Date:** 2026-06-25
**Build:** dev HEAD (includes all 49 fixes from runs 1–3)
**Purpose:** Fresh validation pass — confirm prior fixes hold and surface any remaining defects
**Auditor:** Lead Test Architect (automated 3-device parallel on-device E2E)

---

## Verdict: CONCERNS

The build is substantially improved over prior runs. The 49 fixes from runs 1–3 appear to hold across all validated screens. However, **12 confirmed real findings remain open**, including 5 high-severity defects with direct user-facing impact (cold-start blocking, a content breadcrumb collision, near-invisible empty-state text, and a bar chart locale mismatch). None of the remaining findings are regressions introduced by the run 1–3 fix batch. The build is **not yet ready for production release** but is suitable for continued internal testing.

---

## Coverage Summary

| Device | Domain | Screens audited | Screens passing |
|--------|--------|----------------|----------------|
| 5560 | dashboard | 8 | 7 |
| 5560 | learning | 10 | 10 |
| 5560 | content | 4 | 2 |
| 5560 | tracks | 15 | 15 |
| 5560 | scheduler | 3 | 2 |
| 5554 | profiles_childmode | 11 | 11 |
| 5554 | settings | 4 | 3 |
| 5554 | auth_account | 5 | 3 |
| 5554 | infra | 6 | 4 |
| 5562 | gamification | 6 | 2 |
| 5562 | progress | 5 | 4 |
| 5562 | tutoring | 9 | 4 |
| 5562 | hebrew_rtl | 15 | 14 |
| **Total** | | **101** | **81** |

Overall screen-pass rate: **80.2 %** (81/101).

---

## Confirmed Real Findings

### P2 — High severity (action required before release)

| # | Device | Screen | What | Fix location |
|---|--------|--------|------|-------------|
| 1 | 5560 | onboarding/seed — Splash / cold start | Cold-start splash blocks all UI for 15+ seconds after `pm clear`; accessibility tree is empty throughout | `learning_tracker/lib/main.dart` + `learning_tracker/lib/app/bootstrap/bootstrap.dart` — call `runApp()` immediately with a loading widget; complete Firebase init + seed extraction asynchronously |
| 2 | 5560 | dashboard — STATS card OVERDUE circle tap | Empty-state subtitle falsely says "no tasks remaining for today" on the overdue-filtered view when today tasks still exist | `learning_tracker/lib/features/scheduler/presentation/screens/scheduler_screen.dart` lines 65–74 — make empty-state copy switch on `section`; add `tasksNoOverdueTasksSubtitle` l10n key |
| 3 | 5562 | gamification — PointConfig | Empty state has no icon, no heading, and no CTA to navigate to Manage Tracks | `learning_tracker/lib/features/gamification/presentation/screens/point_config_screen.dart` lines 269–279 — replace bare `Center/Padding/Text` with shared `EmptyState` widget + action button |
| 4 | 5562 | progress — RecentActivity bar chart | Bar chart weekday axis shows English labels (FRI SAT …) while adjacent streak calendar shows Hebrew when Calendar Preference = Hebrew on en-US device | `learning_tracker/lib/features/progress/presentation/widgets/limudim_chazaros_bar_chart.dart` line 58 — OR in `ref.watch(useHebrewDateProvider)` matching `streak_calendar.dart` pattern |
| 5 | 5562 | tutoring — ManageTutors | "No tutors invited." empty-state text uses `colorScheme.outline` (#ECECEF) on brandCream (#FAFAFB) background — contrast ≈ 1.12:1, far below WCAG AA 4.5:1 | `learning_tracker/lib/features/tutoring/presentation/screens/manage_tutors_screen.dart` line 241 — change `color:` to `theme.colorScheme.onSurfaceVariant` |

### P3 — High severity (fix before release, not blocking day-1)

| # | Device | Screen | What | Fix location |
|---|--------|--------|------|-------------|
| 6 | 5562 | onboarding — Add Profile dialog | Android Back key dismisses dialog and silently discards typed name instead of closing keyboard | `learning_tracker/lib/features/profiles/presentation/widgets/add_profile_dialog.dart` — add `barrierDismissible: false` and wrap content in `PopScope(canPop: false)` |
| 7 | 5560 | content — TextDisplay | Breadcrumb shows "תורה" (Tanach internal node) instead of "חומש" when user enters via Chumash curriculum | `learning_tracker/lib/core/content/content_index.dart` — key `_byRef` by `(curriculumId, sefariaRef)` or add preferred-curriculum hint to `lookup()` |
| 8 | 5560 | content — ContentSearch | Search result subtitles show English organizational labels ("Torah", "Genesis") even when Hebrew Terms preference is on | `learning_tracker/lib/core/labels/curriculum_label_renderer.dart` `renderParentForItem` — fetch `hebrewNamesPerSegment` for ancestors as `renderedDisplayForRef` already does |
| 9 | 5554 | profiles_childmode — PinFlow_Verify | PIN dialog subtitle says "access parent settings" when the actual action is switching profiles | `learning_tracker/lib/features/profiles/presentation/widgets/profile_switcher_sheet.dart` line 356 — pass `subtitle: l10n.pinDialogSubtitleSwitchProfile` (key and string already exist) |
| 10 | 5554 | profiles_childmode — ManageLearners / ProfilePicker_BottomSheet | Mode label reads "Adult mode" / "Child mode" in Manage Profiles vs "Adult" / "Child" in the Profile Picker sheet | `learning_tracker/lib/features/profiles/presentation/screens/manage_learners_screen.dart` lines 84–86 — standardize on `profileTypeChild` / `profileTypeAdult`; retire `childMode` / `adultMode` |
| 11 | 5554 | auth_account — AccountPicker | Large blank whitespace gap between account list and "Add another account" CTA on single-account device | `learning_tracker/lib/features/account/presentation/screens/account_picker_screen.dart` — move `_BottomAddAccountSection` inside `ListView` children; remove outer `Column/Expanded` wrapper |
| 12 | 5562 | gamification — RewardConfig | PREVIEW card renders placeholder name in bold navy — visually identical to real content / looks like a link | `learning_tracker/lib/features/gamification/presentation/screens/reward_configuration_screen.dart` `_RewardPreview` widget (lines ~491–570) — apply muted/italic style when rendering placeholder |

---

## Rejected Findings (False Positives / By Design)

| Finding | Disposition | Reason |
|---------|-------------|--------|
| Add Track wizard step counter jumps 6→7 after curriculum selection | **By design** | `computeWizardStepTotal` intentionally shows full count once program step activates; `add_track_flow_ts11_test.dart` explicitly mandates this |
| Offline account creation hidden behind "Register Here" | **False positive** | SignupScreen renders offline-only CTA (no cloud form) when connectivity is absent; design is per documented onboarding-offline-account-model |
| Feature-chip decorations clip at screen edges on tablet (onboarding page 2) | **By design** | Clips are intentional partial-text decorations; `clipBehavior: Clip.none`, trailing/leading ellipses hardcoded in ARB strings, `Positioned(left:0)/right:0` is the explicit design |
| Reward Configuration — saved reward list does not appear above form | **False positive** | Form is creation-only by design; existing rewards accessed via 3-dot menu → `ManageRewardsList` bottom sheet |
| Scheduler skip-Undo triggers second skip / persistent snackbar | **False positive** | `Dismissible.onDismissed` fires once per swipe gesture; parent rebuild with fresh `Dismissible` does not re-fire; screenshot shows normal single-snackbar UI |
| GoalSetup Slider content-desc duplicates percentage ('100%, 100%') | **False positive** | Flutter 3.x Slider uses `label:` only for visual tooltip; semantic `config.value` is set independently to one percentage string; no duplication occurs |

---

## Recommended Fixes — Ordered by Severity

1. **[P2 #1]** Cold-start splash blocking — `main.dart` + `bootstrap.dart`: decouple `runApp()` from async bootstrap chain.
2. **[P2 #3]** OVERDUE empty-state misleading subtitle — `scheduler_screen.dart` lines 65–74: section-aware copy.
3. **[P2 #5]** PointConfig empty state — `point_config_screen.dart` lines 269–279: use `EmptyState` widget with CTA.
4. **[P2 #10]** Bar chart locale mismatch — `limudim_chazaros_bar_chart.dart` line 58: one-line OR fix.
5. **[P2 #12]** ManageTutors contrast failure — `manage_tutors_screen.dart` line 241: swap color token.
6. **[P3 #6]** Add Profile dialog Back-key data loss — `add_profile_dialog.dart`: `barrierDismissible: false` + `PopScope`.
7. **[P3 #7]** Breadcrumb curriculum collision (תנ"ך vs חומש) — `content_index.dart`: keyed lookup by `(curriculumId, sefariaRef)`.
8. **[P3 #8]** Search result English subtitles with Hebrew content — `curriculum_label_renderer.dart`: fetch Hebrew ancestor names.
9. **[P3 #9]** PIN dialog subtitle wrong context — `profile_switcher_sheet.dart` line 356: one-argument addition.
10. **[P3 #10]** Mode label inconsistency across surfaces — `manage_learners_screen.dart` lines 84–86: one key-pair swap.
11. **[P3 #11]** AccountPicker whitespace gap — `account_picker_screen.dart`: move CTA inside `ListView`.
12. **[P3 #12]** RewardConfig placeholder styled as real content — `reward_configuration_screen.dart` `_RewardPreview`: conditional muted style.

---

## Notes

- All 49 fixes from runs 1–3 appear to hold; no regressions were detected in the pass/fail delta.
- Findings #7 and #8 share a common root in `ContentIndex._byRef` last-writer-wins collision; fixing #7 first may simplify or eliminate #8.
- Finding #1 (cold-start) interacts with the App Check debug-token invalidation-on-wipe behavior documented in project memory; the async bootstrap fix should include a non-blocking error path for App Check failures.
- The 6 rejected findings are documented in sufficient detail that they can be closed in the issue tracker with the rejection rationale.
