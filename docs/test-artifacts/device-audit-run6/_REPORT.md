# Device Audit Run 6 — Gate Report

**Date:** 2026-06-28
**Build:** dev HEAD (all run 1-5 fixes + deferred items applied; clean test suite: 10,370 passing)
**Audit type:** Comprehensive 3-device parallel on-device E2E re-audit (fresh validation pass)
**Devices:** emulator-5554 (Pixel 2 / API 28), emulator-5560 (API 34 LTR), emulator-5562 (API 34 RTL/Hebrew)
**Verdict:** FAIL — 22 confirmed real findings remain, 6 of severity P2 (high priority), blocking release

---

## Verdict Reasoning

The build passes all automated tests (10,370 green) and clears all issues deferred from runs 1-5. However, the on-device pass surfaced 22 real defects not caught by the automated suite. Six P2 findings are usability and accessibility blockers — two IME-keyboard CTA-hiding defects on a physical small-screen form factor, two missing accessibility labels, one reward-configuration discoverability failure, and one RTL numeric keypad mirror. No finding was uncovered that contradicts the existing architecture; all 22 are implementation gaps, missing l10n plural rules, BiDi handling oversights, or absent affordances. The 12 rejected items are all confirmed false positives or by-design behaviour (many stemming from misunderstanding of the Hebrew Terms toggle defaulting to ON). A follow-up fix sprint is required before a release gate can be passed.

---

## Confirmed Real Findings

### High / P2 (blocking — usability, accessibility, or data-integrity risk)

| # | Device | Feature area | Screen | What | Fix location |
|---|--------|-------------|--------|------|-------------|
| 1 | 5554 | auth_account | UpgradeToCloud | CTA button hidden below IME keyboard when email field focused (Pixel 2/API 28); UIAutomator confirms button node absent from tree | `upgrade_to_cloud_screen.dart` lines 466-658 — lift FilledButton outside SingleChildScrollView |
| 2 | 5554 | auth_account | SignIn | Sign In button, Keep-me-signed-in checkbox, and Forgot-key link all hidden below IME keyboard when email focused; checkbox inaccessible during credential entry | `sign_in_screen.dart` lines 257-263 — subtract `viewInsets.bottom` from ConstrainedBox minHeight |
| 3 | 5554 | profiles_childmode | ProfilePicker | PIN dialog subtitle reads "Enter the PIN to switch profiles." for Edit and Delete actions; single shared subtitle with no contextual branching | `profile_switcher_sheet.dart:_guardEscalating` — add contextual subtitle parameter and new l10n keys |
| 4 | 5554 | profiles_childmode | PinFlowVerify | PIN keypad backspace button has no accessibility content-description; TalkBack cannot identify primary edit action | `parent_pin_keypad_dialog.dart` line 599 — add `semanticLabel: l10n.pinBackspace` to Icon; add l10n key |
| 5 | 5560 | content | ContentSearch | Search floods all descendants of first matching book, burying every other match; querying 'b' returns 1,325 Numbers items and 0 from any other book because `displayNameEn` stores full ancestor-qualified path | `content_repository_impl.dart` search() lines 145-177 — match only leaf segment name |
| 6 | 5560 | tracks | TrackLearningOrder | Reorder list items render blank on first arrival; text labels invisible until scroll-recycle; data is present but async `CurriculumLabel.local` loading placeholder wins the first frame | `draggable_order_item.dart` — replace `CurriculumLabel.local(item.sefariaRef)` with synchronous `item.displayNameHe`/`item.displayNameEn` |
| 7 | 5562 | gamification | RewardConfig | Configured rewards list not visible on primary screen; hidden behind ⋮ overflow → "Manage rewards"; no inline count or affordance after save | `reward_configuration_screen.dart` build() — embed ManageRewardsList or count summary above the Configure New Reward form when rewards exist |
| 8 | 5562 | profiles | ManageLearners | Add Profile FAB absent from accessibility/semantics tree; TalkBack cannot discover or activate primary screen action | `manage_learners_screen.dart` line 30 FloatingActionButton — add `tooltip: AppLocalizations.of(context)!.addProfile` |
| 9 | 5562 | progress | LifetimeKnowledge | Seder-level tree rows: progress dot stranded far-left, Hebrew label+chevron flush-right, 1200px blank gap — RTL text-direction absorbed by LTR Row inside CurriculumBreakdownTreeNode | `curriculum_breakdown_list.dart` lines ~285-295 — add `textAlign: TextAlign.left` to CurriculumLabel.level |
| 10 | 5562 | tutoring | AcceptInvite + DeclineInvite | Raw gRPC error code "UNAVAILABLE" displayed verbatim as error body text; `_friendlyInviteError()` exists in InviteTutor but was never ported to accept/decline paths | `accept_invite_screen.dart` line 197; `decline_invite_screen.dart` line 136 — add `_friendlyError()` mapper |
| 11 | 5562 | hebrew_rtl | pin_entry_dialog | Numeric PIN keypad columns RTL-mirrored (3-2-1 instead of 1-2-3) in Hebrew locale; violates universal numeric convention | `parent_pin_keypad_dialog.dart:_PinKeypad.build()` — wrap Column in `Directionality(textDirection: TextDirection.ltr)` |

### High / P3 (important — correctness, copy, or accessibility quality)

| # | Device | Feature area | Screen | What | Fix location |
|---|--------|-------------|--------|------|-------------|
| 12 | 5554 | onboarding | SignIn (post-onboarding) | "Welcome Back!" greeting shown to brand-new first-time users who have never created an account | `sign_in_screen.dart` line 294 — add `isFirstRun` param; `app_intro_screen.dart` line 126 — pass `SignInRoute(isFirstRun: true)` |
| 13 | 5554 | onboarding | Carousel page 3 | BiDi punctuation: "!" absorbed into RTL Hebrew run, rendering visually as "!תלמיד חכם" instead of "תלמיד חכם!" | `app_en.arb:introRewardsSubtitle` — wrap `{scholarTier}` in LTR isolate marks (⁦…⁩) |
| 14 | 5554 | onboarding | ProfileSetup | Nikud/Calendar/Hebrew Terms pill controls show no visible selected state; contrast ratio ~1.15:1, below WCAG 3:1 threshold for graphical components | `onboarding_profile_creation_step.dart` lines 154-199, `pill()` builder — use high-contrast fill for selected pill |
| 15 | 5554 | auth_account | AccountPicker | "Add another account" button renders literal "+1   " prefix before label text; ambiguous (phone country code / social +1 pattern) | `app_en.arb` line 1091 and `app_he.arb` — strip "+1   " prefix |
| 16 | 5554 | infra | CityPicker + ShabbosSettings | Numeric GeoNames admin1 codes shown verbatim (Jerusalem: "06 · IL", Abidjan: "93 · CI"); US cities happen to have 2-letter codes, creating inconsistent display | `city_picker_screen.dart` lines 159-174 — suppress admin1 values matching `^\d+$` |
| 17 | 5560 | content | TextDisplay | "Loading text…" blocking full-page spinner for ~8 s on every chapter navigation; no prefetch of adjacent chapters; root cause is auto-dispose textContentProvider | `text_display_screen.dart` line 63 — background prefetch adj?.next / adj?.prev via fire-and-forget |
| 18 | 5560 | content | ContentSearch | Placeholder "Search חומש…" mixes LTR "Search" with RTL Hebrew curriculum name without BiDi isolation; multi-word Hebrew names have visual word order reversed | `app_en.arb:searchFieldHint` — add FSI+PDI marks around `{label}`: "Search ⁨{label}⁩…" |
| 19 | 5560 | content | TextDisplay | Breadcrumb omits root curriculum name; ambiguous across shared seder names (זרעים, מועד, נזיקין exist in both משניות and תלמוד ירושלמי) | `text_display_screen.dart` lines 77-87 — prepend curriculum name or add curriculum chip widget |
| 20 | 5560 | scheduler | GoalSetup | "1 days" pluralization error in Deadline-mode pace projection; ARB key uses flat "{days} days" with no ICU plural rule | `app_en.arb` line 1739 and `app_he.arb` line 1572 — add ICU plural selector; re-run gen-l10n |
| 21 | 5562 | gamification | RewardConfig | Manage Rewards modal shows duplicate-named rewards with no disambiguation or warning; no name-uniqueness check in `saveReward()` | `reward_config_controller.dart:saveReward()` — pre-flight name-uniqueness check before `upsertMilestone()` |
| 22 | 5562 | gamification | RewardConfig | Success dialog claims child will see reward "under Achievements" but Achievements is unreachable when no active tracks exist (EmptyDashboard shown) | `app_en.arb:rewardConfigRewardCreatedBody` — qualify or remove navigation claim; optionally gate on activeTracks count |

---

## Rejected False Positives / By-Design (12)

| # | Screen | Reason for rejection |
|---|--------|---------------------|
| 1 | Dashboard stat row — mixed Hebrew/English labels ("Streak\|סיומים\|Lifetime") | By-design: "סיומים" routes through the Hebrew Terms toggle (defaulting ON); "Streak"/"Lifetime" are generic ARB strings — documented architectural split |
| 2 | Add-Track wizard — Hebrew "חזרה" embedded in English sentences | False positive: Hebrew Terms default is ON; ARB strings use parameterised substitution, not hard-coded Hebrew |
| 3 | Add-Track wizard steps 1 vs 7 — trailing chevron direction inconsistency | False positive: step 7 tile is deliberately wrapped in `Directionality(rtl)` when Hebrew Terms ON (code comment present); step 1 uses a static custom card — different widget types, not a bug |
| 4 | Splash — 2m 34s cold-start ANR on API 34 emulator after `pm clear` | False positive: duration caused by ART JIT compilation of debug APK after OAT profiles deleted — not reproducible on release build or pre-warmed device |
| 5 | Track wizard step counter jumps 4→6 | False positive: E2E driver tapped through step 5 before screenshot was captured; step counter is sequential and correct |
| 6 | Onboarding slide 2 — decorative chips clipped at screen edges | By-design: `Clip.none` Stack with chips positioned at `left:0` / `right:0` for intentional edge-bleed motion design effect |
| 7 | TextDisplay — unlabeled divider icon between Hebrew and English text cards | False positive: `Icons.menu_book_rounded` is a decorative section divider; omitting semantics from decorative elements is correct accessibility practice |
| 8 | ContentSearch — soft keyboard not raised on Mishnah entry | False positive: autofocus is unconditional; apparent discrepancy is E2E screenshot timing artefact during IME animation |
| 9 | LifetimeCurriculumMarking — last item clipped by bottom action bar | False positive: layout is Column with Expanded (scrollable) + sibling action row; action row does not overlay list; partial row visibility is normal scroll affordance |
| 10 | Progress hub — "סיומים" Hebrew while "Streak"/"Lifetime" English | By-design: documented in `@tierTileLabelSiyumim` ARB description as intentional per Hebrew Terms toggle scope |
| 11 | Settings (child) — Calendar/Nikud segmented controls primary option appears at RTL-end | False positive: auditor confused selected index-1 option (left in RTL) with "primary" option; RTL SegmentedButton layout is correct |
| 12 | Learning screen streak banner — flame icon at LTR-start in RTL locale | False positive: flame is a trailing Row child (index 2); RTL auto-reversal places it at LTR-end (left), which is correct RTL mirroring of the LTR design |

---

## Coverage Summary

| Device | Feature group | Screens audited | Screens passing | Pass rate |
|--------|--------------|----------------|----------------|-----------|
| 5560 | dashboard | 1 | 1 | 100% |
| 5560 | learning | 7 | 6 | 86% |
| 5560 | content | 4 | 2 | 50% |
| 5560 | tracks | 13 | 12 | 92% |
| 5560 | scheduler | 3 | 2 | 67% |
| 5554 | profiles_childmode | 9 | 8 | 89% |
| 5554 | settings | 4 | 3 | 75% |
| 5554 | auth_account | 5 | 2 | 40% |
| 5554 | infra | 5 | 2 | 40% |
| 5562 | gamification | 5 | 3 | 60% |
| 5562 | progress | 5 | 3 | 60% |
| 5562 | tutoring | 9 | 2 | 22% |
| 5562 | hebrew_rtl | 19 | 15 | 79% |
| **Total** | | **89** | **61** | **69%** |

---

## Recommended Fixes — Ordered by Priority

### P2 — Fix before any release candidate build

1. **[IME keyboard / SignIn]** Refactor `sign_in_screen.dart` ConstrainedBox to subtract `viewInsets.bottom`; sticky-pin SignInActions outside scroll.
2. **[IME keyboard / UpgradeToCloud]** Lift FilledButton CTA outside SingleChildScrollView in `upgrade_to_cloud_screen.dart`; test on Pixel 2 API 28 with soft keyboard open.
3. **[RTL PIN keypad]** Wrap `_PinKeypad` Column in `Directionality(textDirection: TextDirection.ltr)` in `parent_pin_keypad_dialog.dart`.
4. **[Accessibility — FAB]** Add `tooltip` parameter to ManageLearners FAB in `manage_learners_screen.dart`.
5. **[Accessibility — PIN backspace]** Add `semanticLabel` to backspace Icon in `parent_pin_keypad_dialog.dart`; add l10n key to both ARBs.
6. **[PIN dialog copy]** Add contextual subtitle parameters to `_guardEscalating` in `profile_switcher_sheet.dart`; add l10n keys for Edit/Delete/Add/Switch actions.
7. **[Content search flood]** Fix `content_repository_impl.dart` search() to match only leaf segment name; prevents 1,325-item flood for single-letter query.
8. **[ReorderableList blank render]** Replace `CurriculumLabel.local` with synchronous `item.displayNameHe`/`item.displayNameEn` in `draggable_order_item.dart`.
9. **[Reward discoverability]** Embed inline rewards list or count badge in `reward_configuration_screen.dart` build() when rewards exist.
10. **[RTL progress tree]** Add `textAlign: TextAlign.left` to CurriculumLabel.level in `curriculum_breakdown_list.dart`.
11. **[gRPC error exposure]** Port `_friendlyError()` mapper to `accept_invite_screen.dart` and `decline_invite_screen.dart`.

### P3 — Fix before public beta

12. **[First-run heading]** Add `isFirstRun` parameter to `SignInScreen`; update `AppIntroScreen._markIntroSeenAndContinue()` to pass the flag.
13. **[BiDi punctuation — carousel]** Add LTR isolate marks around `{scholarTier}` in `app_en.arb:introRewardsSubtitle`.
14. **[Pill selected state]** Update `pill()` builder in `onboarding_profile_creation_step.dart` to use high-contrast fill for selected pill.
15. **[AccountPicker "+1" prefix]** Remove "+1   " literal from `accountPickerAddAnother` in both ARB files.
16. **[GeoNames numeric codes]** Add `^\d+$` filter to `_subtitleFor`/`_formatCityLabel` in `city_picker_screen.dart`.
17. **[Chapter load spinner]** Add background prefetch for adj?.next/prev in `text_display_screen.dart`.
18. **[Search placeholder BiDi]** Add FSI+PDI marks around `{label}` in `app_en.arb:searchFieldHint`.
19. **[TextDisplay breadcrumb]** Prepend curriculum name or add curriculum chip to TextDisplay app bar in `text_display_screen.dart`.
20. **["1 days" pluralization]** Add ICU plural selector on `days` in `app_en.arb` line 1739 and `app_he.arb` line 1572; re-run gen-l10n.
21. **[Duplicate reward names]** Add name-uniqueness pre-flight in `reward_config_controller.dart:saveReward()`.
22. **[Achievements CTA copy]** Qualify or remove Achievements navigation claim in `rewardConfigRewardCreatedBody` when no active tracks exist.

---

## Automated Test Coverage Note

The 10,370 passing tests did not catch any of the 22 confirmed findings. Fourteen are UI/accessibility/copy gaps not amenable to unit tests. Eight (content search flood, chapter load spinner, BiDi issues, pluralization, reorder blank render, PIN keypad RTL, IME keyboard hiding) have clear widget-test or integration-test harness opportunities that should be added as part of each fix PR, in alignment with the project's ATDD strategy.
