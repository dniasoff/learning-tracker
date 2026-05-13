# DNI-341 — 25.20: MaterialApp locale auto-detection + Noto Sans Hebrew + dark theme

**Status:** review
**Epic:** DNI-313 — Schema + Core Foundation (greenfield rebuild)
**Linear:** [DNI-341](https://linear.app/orvexai/issue/DNI-341/2520-materialapp-locale-auto-detection-noto-sans-hebrew-bundling)

## Story

**As a** user installing the app on a Hebrew-locale device,
**I want** the app UI to auto-resolve to Hebrew without me choosing a language,
**So that** Hebrew users get a native experience without any onboarding-time picker (FR18, UX-DR1, UX-DR2).

## Acceptance Criteria

1. Delete hardcoded `_selectedLanguage = 'en'` in `onboarding_screen.dart` (no replacement — Flutter handles locale resolution).
2. `MaterialApp.supportedLocales = [Locale('en'), Locale('he')]` with `locale: null` (auto-resolution from `WidgetsBinding.window.locale`).
3. `flutter_localizations` retains both `en` and `he`.
4. Noto Sans Hebrew font bundled in `pubspec.yaml` AND the font file is actually included.
5. `AppTextStyles` uses Noto Sans Hebrew for Hebrew script with RTL directionality.
6. `CurriculumLabel.curriculum(...)` renders Hebrew script with RTL directionality without any toggle.
7. `AppTheme.darkTheme()` returns a Material 3 dark palette distinct from `_lightTheme`.
8. The 20+ heritage*/child* color aliases are consolidated into the new theme palette (light + dark).
9. App respects `MediaQuery.platformBrightnessOf(context)` for system-driven theme selection (UX-DR4).

## Tasks/Subtasks

- [x] **Task 1 — AC1:** Delete `_selectedLanguage` field + `languageSelection` enum + `_kOnboardingLanguage` prefs key + save/load/reset paths + `appLocaleProvider.setLocale` call in `onboarding_screen.dart`.
- [x] **Task 2 — AC2, AC3, AC9:** Wire `locale: null`, add `darkTheme`, set `themeMode: ThemeMode.system` in `main.dart`. Drop the `appLocaleProvider` import + watch.
- [x] **Task 3 — AC4:** Confirmed Noto Sans Hebrew family declaration in `pubspec.yaml` (weights 300/400/500/600/700) matches `AppTextStyles.hebrewFontFamily`; all five `NotoSansHebrew-*.ttf` weights present in `assets/fonts/`.
- [x] **Task 4 — AC5:** `AppTextStyles.hebrew*` styles already use `Noto Sans Hebrew`; `getTextDirection` / `getStyleForContent` already resolve RTL correctly for Hebrew script.
- [x] **Task 5 — AC6:** `CurriculumLabel._text` now infers `TextDirection.rtl` from Hebrew code-block content when the caller doesn't specify one.
- [x] **Task 6 — AC7, AC8:** Authored a real Material 3 `_darkTheme` (distinct dark `ColorScheme`, surfaces, ink, button/input themes) in `app_theme.dart`. Removed all `heritage*` and `child*` color aliases.
- [x] **Task 7:** Added acceptance tests (`test/story_acceptance/epic_25_story_25_20_locale_theme_test.dart`); added `make test-story-25.20` target; updated `make test-epic-25` to include the new file.
- [x] **Task 8:** `dart analyze --fatal-infos` clean; full acceptance suite `flutter test test/story_acceptance/` = 551 passing / 11 skipped; full `flutter test` = 1820 passing / 103 skipped; 0 failing.

## Dev Notes

- **Worktree:** `/tmp/dev-dni-341`, branch `dev-dni-341`, base `origin/dev` @ 513a4a86.
- **Heritage/child aliases were already dead** — grep confirmed zero external references; deletion was safe.
- **`appLocaleProvider` provider file kept** — its only remaining caller is `language_provider.dart` (a Settings facade) and `sync_engine.dart` (cloud snapshot of UI prefs). Removing those is out of scope for this story; the MaterialApp no longer reads the provider, which is what AC2 requires.
- **`onboarding_screen.dart`:** the `calendarPreference` enum value is also unreachable (its `build` branch routes to `_buildProfileCreation`), but leaving it costs nothing and removing it is out of AC scope. The legacy migration of saved phase `'calendarPreference'` → `addTrack` was preserved.
- **Hebrew RTL inference in `CurriculumLabel`:** uses the Hebrew Unicode block U+0590–U+05FF. The override is only applied when no `textDirection` was passed by the caller, so explicit choices win.

## File List

- **Modified:**
  - `learning_tracker/lib/main.dart` — drop `appLocaleProvider` watch and import; set `locale: null`, `themeMode: ThemeMode.system`, add `darkTheme: AppTheme.darkTheme()`.
  - `learning_tracker/lib/core/theme/app_theme.dart` — author real Material 3 dark theme (`_darkTheme`, dark palette colors); remove 20+ `heritage*` / `child*` aliases; parameterize `_buildTextTheme` by brightness; route `themeFor(brightness: dark)` to `_darkTheme`.
  - `learning_tracker/lib/core/labels/curriculum_label.dart` — infer `TextDirection.rtl` when text contains Hebrew script and no explicit direction was passed.
  - `learning_tracker/lib/features/onboarding/presentation/screens/onboarding_screen.dart` — delete `_selectedLanguage` field, `_kOnboardingLanguage` prefs key, `languageSelection` phase enum + dead branches, `appLocaleProvider.setLocale` call, locale_provider import.
  - `learning_tracker/Makefile` — add `test-story-25.20` target; widen `test-epic-25` to include the new test file.
- **Added:**
  - `learning_tracker/test/story_acceptance/epic_25_story_25_20_locale_theme_test.dart` — 21 acceptance tests covering AC1–AC9.
  - `docs/stories/implementation/DNI-341-materialapp-locale-noto-hebrew-dark-theme.md` (this file).

## Dev Agent Record

- Workflow: BMAD dev-story, red-green-refactor per task. Tests authored first against the pre-implementation tree (12 failing). Implementation flipped them green in two iterations (initial pass + lint cleanup).
- Build runner regeneration was needed once at the start because the `origin/dev` base predates the DNI-322 schema generation; subsequent edits did not require regen.
- Pre-existing fixture: `firebase_options.dart` is gitignored — `dart analyze` was run with a temporary copy that was deleted before commit.

## Change Log

| Date | Note |
|------|------|
| 2026-05-13 | Story created; worktree `dev-dni-341` cut from `origin/dev` @ 513a4a86. |
| 2026-05-13 | Acceptance test suite authored (12 failing, 9 passing initially). |
| 2026-05-13 | Implementation complete: AC1 / AC2 / AC3 / AC4 / AC5 / AC6 / AC7 / AC8 / AC9 all green; analyze clean; no regressions. |
