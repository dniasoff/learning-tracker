# DNI-328 — Story 25.7: `core/preferences/` six ProfileScopedPreference primitives

**Status:** review
**Linear:** [DNI-328](https://linear.app/orvexai/issue/DNI-328/257-corepreferences-six-profilescopedpreference-primitives)
**Parent epic:** DNI-313 (Epic 25 — Schema + Core Foundation)

## Story

As a developer needing to read user preferences without coupling to feature code, I want six `ProfileScopedPreference<T>` primitives (`HebrewTerms`, `TransliterationVariant`, `Nikud`, `AppLocale`, `TextDisplay`, `HebrewDate`) living in `core/preferences/`, so that `core/labels/` and other core modules can depend on preferences without inverting the layering (T2.2).

## Acceptance Criteria

- [x] Each preference is a class `ProfileScopedPreference<T>` with `(read, write, observe)` methods.
- [x] All six preference classes live in `lib/core/preferences/`.
- [x] The `profileId == 0 ? mirror : true` Hebrew-terms hardcode is gone — the legacy notifiers in `features/settings/presentation/providers/{hebrew_terms,hebrew_date,transliteration_variant}_provider.dart` were deleted entirely and replaced by Riverpod notifiers in `core/preferences/preference_providers.dart` that read straight from `SharedPreferences`.
- [x] New profiles default to `hebrewTerms: false` and `useHebrewDate: false` — the SharedPreferences fallbacks in `ProfileScopedPreferenceKeys.readHebrewTermsScript` / `readUseHebrewCalendar` and the `defaultValue` of `HebrewTermsPreference` / `HebrewDatePreference` are all `false`.
- [x] `grep -rn 'hebrewTermsScriptProvider' lib/ --exclude-dir=core/labels --exclude-dir=core/preferences --exclude=settings/.*_screen\.dart` returns zero results. In practice zero matches anywhere in `lib/`.
- [x] Profile switching loads each profile's own value — verified by the `profile-switch scenario` acceptance test.

## Tasks/Subtasks

- [x] Generic base class `ProfileScopedPreference<T>` with `(read, write, observe)` contract.
- [x] Six concrete primitives in `lib/core/preferences/`:
  - `HebrewTermsPreference` (bool)
  - `HebrewDatePreference` (bool)
  - `NikudPreference` (bool)
  - `AppLocalePreference` (`Locale`)
  - `TransliterationVariantPreference` (enum)
  - `TextDisplayPreference` (`FontSize` enum)
- [x] Riverpod `keepAlive` notifiers in `core/preferences/preference_providers.dart`:
  - Object providers for each `ProfileScopedPreference<T>`.
  - Value-stream notifiers (`UseHebrewTerms`, `UseHebrewDate`, `ShowNikudPref`, `CurrentAppLocale`, `CurrentTransliterationVariant`, `CurrentFontSize`) that watch the active profile and push value changes to consumers.
- [x] Delete legacy feature-layer providers and migrate all consumers to `core/preferences/`.
- [x] Wire `core/labels/curriculum_label.dart` + `curriculum_label_providers.dart` to read via the new providers (no `features/settings/...` imports).
- [x] Flip SharedPreferences defaults in `ProfileScopedPreferenceKeys` so new profiles match the AC (`hebrewTermsScript=false`, `useHebrewCalendar=false`).
- [x] Story acceptance tests (`test/story_acceptance/epic_25_schema_core_test.dart`) — defaults, per-profile isolation, round-trip, observe stream filtering, profile-switch scenario, storage-key contract.
- [x] `make test-story-25.7` Makefile target.
- [x] Update widget / acceptance tests that asserted on Hebrew labels to seed `hebrew_terms_script_p0=true` via `SharedPreferences.setMockInitialValues`.

## Dev Agent Record

### Implementation Notes

- Persistence stays on **SharedPreferences** via the existing `ProfileScopedPreferenceKeys` namespacing (`<key>_p<profileId>`) — no Drift table added, schema stays at v13. The orchestrator brief said "use SharedPreferences or Drift; no schema bump unless required," and a Drift `profile_settings` table is not needed to satisfy the AC.
- `pushUiPreferencesSnapshot()` (the Firestore mirror for the cloud-account tier) is still called after each preference write via the new notifiers' `set(...)` methods — Settings → Firestore round-trip is preserved.
- The legacy `features/settings/...` provider files were deleted outright. The `language_provider.dart` facade was rewritten to delegate to `currentAppLocaleProvider`.
- The two failed `find.text('משניות', …)` assertions in scheduler / dashboard / content-browsing widget tests were not bugs in the new code — they relied on the previous "default = Hebrew" behaviour. The fix is per-test: seed `hebrew_terms_script_p0: true` and add `await tester.pumpAndSettle()` so the async preference load propagates before the assertion.

### File List

**Added**
- `lib/core/preferences/profile_scoped_preference.dart`
- `lib/core/preferences/hebrew_terms_preference.dart`
- `lib/core/preferences/hebrew_date_preference.dart`
- `lib/core/preferences/nikud_preference.dart`
- `lib/core/preferences/app_locale_preference.dart`
- `lib/core/preferences/transliteration_variant_preference.dart`
- `lib/core/preferences/text_display_preference.dart`
- `lib/core/preferences/preference_providers.dart`
- `lib/core/preferences/preference_providers.g.dart` (generated)
- `docs/stories/implementation/DNI-328-profile-scoped-preference-primitives.md`

**Removed**
- `lib/features/settings/presentation/providers/hebrew_terms_provider.dart` (+ `.g.dart`)
- `lib/features/settings/presentation/providers/hebrew_date_provider.dart` (+ `.g.dart`)
- `lib/features/settings/presentation/providers/transliteration_variant_provider.dart` (+ `.g.dart`)
- `lib/core/providers/locale_provider.dart` (+ `.g.dart`)

**Modified**
- `lib/core/labels/curriculum_label.dart`, `curriculum_label_providers.dart` — read via `useHebrewTermsProvider` / `currentTransliterationVariantProvider`.
- `lib/core/services/{calendar_program_service,learning_program_service}.dart`, `lib/core/constants/hebrew_terms.dart` — same.
- `lib/features/content_browsing/presentation/{screens,widgets}/*` — provider rename across 4 files.
- `lib/features/dashboard/presentation/{screens,widgets}/*` — provider rename across 3 files.
- `lib/features/onboarding/presentation/screens/*` — provider rename across 3 files.
- `lib/features/parent_mode/presentation/screens/point_config_screen.dart`.
- `lib/features/progress/{domain,presentation}/...` — provider rename across 3 files.
- `lib/features/scheduler/presentation/screens/goal_setup_screen.dart`.
- `lib/features/learning_order/presentation/widgets/draggable_order_item.dart`.
- `lib/features/settings/presentation/screens/{settings_screen,lifetime_marking_screen}.dart` — call `.set(...)` instead of `.setHebrewTermsScript / .setVariant / .setUseHebrewDate`.
- `lib/features/settings/presentation/providers/language_provider.dart` — delegate to `currentAppLocaleProvider`.
- `lib/features/track_learning_order/presentation/screens/track_learning_order_screen.dart`.
- `lib/features/track_setup/presentation/{screens,widgets}/*` — provider rename across 3 files.
- `lib/features/content_browsing/presentation/providers/text_display_providers.dart` — `fontSizeProvider` + `showNikudProvider` become thin facades over `currentFontSizeProvider` / `showNikudPrefProvider`.
- `lib/features/sync/domain/profile_scoped_preference_keys.dart` — flip Hebrew-terms / Hebrew-date defaults from `true` → `false`.
- `lib/main.dart` — drop `syncHebrew*PreferenceFromPrefs` preload (no longer needed; defaults are safe and Riverpod loads async).
- `test/story_acceptance/epic_25_schema_core_test.dart` — Story 25.7 acceptance group (20 tests).
- `test/story_acceptance/epic_07_dashboard_test.dart`, `test/story_acceptance/epic_09_onboarding_test.dart` — seed SharedPreferences for Hebrew-asserting cases.
- `test/features/scheduler/presentation/widgets/{daily_schedule_widgets,daily_task_card}_test.dart`, `test/features/gamification/presentation/widgets/points_display_widget_test.dart`, `test/features/content_browsing/{presentation/screens,integration}/*_test.dart` — same seed pattern.
- `Makefile` — add `test-story-25.5`, `test-story-25.7`, `test-epic-25` targets.

### Change Log

| Date | Note |
|------|------|
| 2026-05-13 | DNI-328 — core/preferences/ ProfileScopedPreference primitives extracted from feature-layer providers; legacy provider files deleted; consumers migrated; defaults flipped; 20 acceptance tests added. |
