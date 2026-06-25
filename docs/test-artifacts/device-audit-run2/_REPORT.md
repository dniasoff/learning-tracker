# Device Audit Run 2 — Gate Report

**Build:** dev HEAD (all 5 run-1 fixes included)
**Date:** 2026-06-25
**Audit type:** Comprehensive 3-device parallel on-device E2E re-audit
**Devices:** emulator-5554 (Pixel 2), emulator-5560 (standard AVD), emulator-5562 (tablet)
**Verdict:** ⚠ FAIL — 23 confirmed defects, including 8 P1/P2 blockers across core user journeys

---

## Verdict Rationale

The build ships 5 run-1 regression fixes and passes 74 of 101 screens audited (73%). However, 23 confirmed real defects remain, including one P1 localisation regression (Hebrew UI leaks English descriptions), five P2 functional bugs (silent data corruption on deadline goal submission, unreachable CTAs behind soft keyboard, tapping container search results silently no-ops, wizard completion toast names wrong track), and accessibility gaps pervasive across auth, dashboard, and content surfaces. The product cannot be considered gate-ready until the P1 and P2 items are resolved.

---

## Coverage Summary

| Device | Suite | Screens | Pass | Fail |
|--------|-------|---------|------|------|
| 5560 | dashboard | 1 | 0 | 1 |
| 5560 | learning | 8 | 7 | 1 |
| 5560 | content | 4 | 3 | 1 |
| 5560 | tracks | 15 | 14 | 1 |
| 5560 | scheduler | 3 | 2 | 1 |
| 5554 | profiles_childmode | 15 | 13 | 2 |
| 5554 | settings | 11 | 10 | 1 |
| 5554 | auth_account | 5 | 0 | 5 |
| 5554 | infra | 6 | 3 | 3 |
| 5562 | gamification | 5 | 4 | 1 |
| 5562 | progress | 6 | 5 | 1 |
| 5562 | tutoring | 9 | 3 | 6 |
| 5562 | hebrew_rtl | 13 | 10 | 3 |
| **Total** | | **101** | **74 (73%)** | **27 (27%)** |

---

## Confirmed Real Findings

### P1 — Critical (1)

| ID | Device | Screen | Severity | What | Fix location |
|----|--------|--------|----------|------|--------------|
| F-01 | 5562 | Add Track Wizard Step 2 (schedule picker) | High | English program-schedule descriptions leak into Hebrew UI; card titles are Hebrew but all descriptions are raw English strings from seed data | `learning_tracker/lib/core/database/seed/learning_program_seeds.dart` (all `description` fields) + `program_selection_step.dart` (`_FeaturedProgramCard` line 225, `_CompactProgramCard` lines 328–329) |

### P2 — High-impact functional or layout (7)

| ID | Device | Screen | Severity | What | Fix location |
|----|--------|--------|----------|------|--------------|
| F-02 | 5554 | SignIn | High | Primary CTA (Sign In button, checkbox, register link) unreachable behind soft keyboard — `ConstrainedBox(minHeight: constraints.maxHeight - 28)` prevents scrolling when keyboard is open | `sign_in_screen.dart:254–261` — use `MediaQuery.of(context).size.height` as minHeight |
| F-03 | 5554 | UpgradeToCloud | High | Submit button unreachable behind soft keyboard; password IME action key does not submit; `onFieldSubmitted` not wired | `upgrade_to_cloud_screen.dart:550–594` — add `textInputAction` + `onFieldSubmitted` on both fields |
| F-04 | 5560 | GoalSetup (Edit Goal) | High | Update Goal button enabled when Deadline mode active but no date selected; submits goal with `null targetDate` — silent data corruption | `goal_setup_screen.dart:266, 674` — disable button or validate in `_submit()` |
| F-05 | 5554 | Track wizard step 7 (Track Ready) | High | Wizard completion toast names last-selected seder ("Seder Taharos") not the curriculum when all sedarim selected via "Select all in this list" | `add_track_flow_screen.dart:_getSmartDefault()` lines 669–685 and `add_track_controller.dart:_smartLabel` lines 332–340 |
| F-06 | 5562 | Profile creation (Learning Experience) | High | ACTIVE badge visually detached from selected mode card on tablet — `Stack` inside `Expanded` sizes to full row slot, not card width; badge anchors to far right of screen | `onboarding_profile_creation_step.dart:modeCard()` lines 201–294 — move `Stack` inside the `Material`/`InkWell` or set card `width: double.infinity` |
| F-07 | 5560 | ContentSearch | High | Container/folder results show drill-down chevron but tapping does nothing — `onTap` guarded by `if (item.isLeaf)` with no `else` branch | `content_search_screen.dart:~162` — add `else` branch pushing `ContentHierarchyRoute` for container items |
| F-08 | 5562 | RewardConfig | High | "Points needed" label l10n key `rewardConfigPointsThresholdLabel` exists but is never rendered; points field shows only placeholder, inconsistent with adjacent named field | `reward_configuration_screen.dart:391` — insert `Text(l10n.rewardConfigPointsThresholdLabel)` before points `TextField` |

### P3 — Accessibility, usability, and cosmetic (15)

| ID | Device | Screen | Severity | What | Fix location |
|----|--------|--------|----------|------|--------------|
| F-09 | 5560 | Manage Tracks / track card | High | `LinearProgressIndicator` emits raw fractional value "0" into semantics tree; TalkBack announces "0, משניות" — the "0" is the indicator value, not a count | `learning_track_card.dart:162–172` — wrap in `ExcludeSemantics`; same fix in `track_detail_screen.dart:436–443` |
| F-10 | 5554 | Manage Tracks / track card | High | Track card a11y label leaks list ordinal ("0, …") due to `ListView` ordinal sort key merging into `InkWell` semantics; no `Semantics` override present | `learning_track_card.dart` — add `Semantics(label: …, button: true)` wrapper to override ordinal prefix |
| F-11 | 5560 | Dashboard | High | Streak chip raw count ("1") merged into greeting semantics node with no context label; TalkBack announces unexplained number after date | `dashboard_body.dart:304–370` — wrap `GestureDetector` in `Semantics(label: l10n.streakDaysCount(n))` + `excludeSemantics: true` on child |
| F-12 | 5560 | TextDisplayScreen | High | Back button in reader `AppBar` has empty content-desc (`""`) — `automaticallyImplyLeading: false` suppresses auto-semantics; no `tooltip` set | `text_display_screen.dart:69–72` — add `tooltip: MaterialLocalizations.of(context).backButtonTooltip` |
| F-13 | 5560 | ContentSearch | High | Search results show no parent breadcrumb; multiple rows named "משנה ו" are indistinguishable | `content_item_tile.dart:ListTile build` — add `subtitle: CurriculumLabel.parent(item)` when used in search context |
| F-14 | 5560 | TrackLearningOrderScreen | High | Section headers "סדרים"/"מסכתות" left-aligned (LTR default) while Hebrew list items auto-detect RTL and right-align — visually broken column | `track_learning_order_screen.dart:_buildSectionHeader` line 148 — add `textDirection` RTL inference matching DNI-341 pattern |
| F-15 | 5560 | GoalSetup (Edit Goal) | High | Clear-date `IconButton` (Icons.clear) has no `tooltip` or semantic label; content-desc is empty | `goal_setup_screen.dart:314` — add `tooltip:` with new l10n key `goalClearDeadlineTooltip` in both ARB files |
| F-16 | 5554 | ParentSettingsHub | High | Sign Out row shows duplicate logout icon — leading container uses `Icons.logout_rounded`, trailing uses `Icons.logout_outlined`; Delete Account row correctly uses `SizedBox.shrink()` | `parent_settings_screen.dart:335–339` — change `trailing` to `const SizedBox.shrink()` |
| F-17 | 5554 | SignIn | High | Password visibility toggle `IconButton` has no `tooltip`; TalkBack announces "Button" with no purpose | `sign_in_form.dart:92–100` + `signup_screen.dart:619–630`; add showPassword/hidePassword l10n keys in both ARB files |
| F-18 | 5554 | SignIn | High | "Keep me signed in" `Checkbox` missing accessible label — no `MergeSemantics` or `semanticLabel`; TalkBack announces "Checkbox, checked" without context | `sign_in_form.dart:129–145` — wrap `Row` in `MergeSemantics` or add `semanticLabel` to `Checkbox` |
| F-19 | 5554 | AccountPicker | High | "Add another account" `_DashedOutlineButton` has no `Semantics(button: true)`; announced as generic `android.view.View` | `account_picker_screen.dart:_DashedOutlineButton` lines 189–209 — add `Semantics(button: true)` wrapper |
| F-20 | 5554 | Notification Settings (Settings tile) | High | Subtitle claims "Push, email, and study sound alerts"; actual screen has only 3 push-notification toggles, no email or sound controls | `app_en.arb:653` + `app_he.arb:558` — update `notificationSettingsSubtitle` to describe only push notifications |
| F-21 | 5562 | Track wizard step 7 (Track Ready) | High | Same smart-label bug as F-05 observed independently on 5562; "Seder Taharos" shown as track name when all sedarim selected | Same fix as F-05 |
| F-22 | 5562 | RecentActivity | High | "Last 30 Days" tab wraps to 2 lines (`\n` hardcoded in ARB string `chartLast30Days`), making middle tab 47% taller than flanking tabs | `app_en.arb:926` + `app_he.arb:821` — remove `\n`; drop `maxLines: 2` at `recent_activity_screen.dart:193` |
| F-23 | 5562 | Profile creation / Add Profile dialog | Medium | Child Mode and Adult Mode cards have ~700 px dead-zone gap between them on tablet; `Stack` inside `Expanded` does not propagate tight width constraints to `Material`/`Container` child | `onboarding_profile_creation_step.dart:modeCard()` — add `width: double.infinity` to the inner `Container` or wrap `Stack` in `SizedBox.expand` |

---

## Rejected Findings — False Positives / By Design (5)

| Finding | Disposition | Reason |
|---------|-------------|--------|
| Wizard Step 6 — deadline "655/day" alarming pace text | **By design** | Text is rendered under `BlurInactiveGoalOption` (40% opacity + blur + `AbsorbPointer`); never readable or actionable; tapping immediately opens date picker |
| Onboarding slide 2 — decorative chip labels truncated | **By design** | Ellipsis is part of the ARB string value (`'Review…'`, `'…yos'`); intentional partial-pill animation decoration confirmed in code |
| LifetimeCurriculumMarking — last sedarim hidden behind action bar | **False positive** | Action bar is a Column sibling below `Expanded(ListView)`, not a floated overlay; partial row is standard scroll affordance on small screen |
| Settings segmented controls not mirrored in RTL | **False positive** | Flutter `SegmentedButton` inside `Row` correctly mirrors in RTL via `Directionality`; active item on left is a consequence of which index is selected, not a layout bug |
| Settings footer icons missing a11y labels | **False positive** | Icons are non-interactive decorative `Icon` widgets (no `GestureDetector`/`InkWell`), 14dp, 50% opacity; correctly excluded from semantics tree |

---

## Recommended Fix Order

Priority order based on severity, user-impact, and blast radius:

1. **[P1] F-01** — Hebrew UI English description leak (l10n gap in seed data + render sites)
2. **[P2] F-02** — SignIn CTA unreachable behind soft keyboard (auth flow blocker)
3. **[P2] F-03** — UpgradeToCloud CTA unreachable + missing IME submission (auth flow blocker)
4. **[P2] F-04** — GoalSetup deadline goal submits with null `targetDate` (data integrity)
5. **[P2] F-05 / F-21** — Wizard toast shows wrong track name (duplicate across devices, single fix)
6. **[P2] F-06** — ACTIVE badge detached from card on tablet (layout regression)
7. **[P2] F-07** — ContentSearch container tap is a silent no-op (navigation dead-end)
8. **[P2] F-08** — RewardConfig points field missing label (form usability)
9. **[P3] F-16** — Sign Out duplicate icon (cosmetic, 1-line fix)
10. **[P3] F-22** — "Last 30 Days" tab double-height (1-line ARB fix)
11. **[P3] F-14** — Section headers wrong text direction (RTL polish)
12. **[P3] F-20** — Notification subtitle copy overpromises (copy fix)
13. **[P3] F-09 / F-10** — Progress bar semantics in track cards (a11y)
14. **[P3] F-11** — Streak chip unlabelled in semantics (a11y)
15. **[P3] F-12** — Back button empty content-desc in reader (a11y)
16. **[P3] F-13** — ContentSearch missing breadcrumb subtitle (a11y/usability)
17. **[P3] F-15** — Clear-date button empty content-desc (a11y)
18. **[P3] F-17** — Password toggle empty content-desc (a11y)
19. **[P3] F-18** — Keep-me-signed-in checkbox unlabelled (a11y)
20. **[P3] F-19** — Add-account button missing button semantic role (a11y)
21. **[P3] F-23** — Mode card dead-zone gap on tablet (layout, medium confidence)

---

*Generated by automated E2E device audit harness — run 2 of 2. Report path: `docs/test-artifacts/device-audit-run2/_REPORT.md`*
