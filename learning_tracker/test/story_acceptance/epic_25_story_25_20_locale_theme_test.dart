/// Story acceptance tests for Story 25.20 (DNI-341) — MaterialApp locale
/// auto-detection + Noto Sans Hebrew bundling + direction-aware CurriculumLabel
/// + real dark theme.
///
/// AC1: `_selectedLanguage = 'en'` hardcode deleted from onboarding_screen.dart.
/// AC2: MaterialApp `locale: null`, `supportedLocales: [en, he]`.
/// AC3: flutter_localizations retains both `en` and `he`.
/// AC4: Noto Sans Hebrew font bundled in pubspec.yaml AND file present.
/// AC5: AppTextStyles uses Noto Sans Hebrew for Hebrew script with RTL.
/// AC6: CurriculumLabel.curriculum(...) renders Hebrew script with RTL.
/// AC7: AppTheme.darkTheme() returns a Material 3 dark palette distinct from light.
/// AC8: 20+ heritage*/child* color aliases removed.
/// AC9: App respects platform brightness for system-driven theme selection.
@Tags(['epic_25'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, setUpAll, tearDown, tearDownAll, test;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/theme/text_styles.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

/// Cached result of [_findAppEntrySource] so the disk scan below runs once
/// per test process and is shared by every group that needs the app-entry
/// source (AC2/AC3 and AC9) — see AUD-t-story-acceptance-34.
String? _appEntrySourceCache;

/// Locates the MaterialApp configuration — it may live in
/// `lib/app/learning_tracker_app.dart` or `lib/main.dart`, and the working
/// directory when tests run may be the package root or the repo root — and
/// returns its contents, memoized after the first successful read.
String _findAppEntrySource() {
  final cached = _appEntrySourceCache;
  if (cached != null) return cached;

  final candidates = [
    File('lib/app/learning_tracker_app.dart'),
    File('learning_tracker/lib/app/learning_tracker_app.dart'),
    File('lib/main.dart'),
    File('learning_tracker/lib/main.dart'),
  ];
  for (final f in candidates) {
    if (f.existsSync()) {
      final content = f.readAsStringSync();
      if (content.contains('MaterialApp') ||
          content.contains('locale: null') ||
          content.contains('themeMode:')) {
        _appEntrySourceCache = content;
        return content;
      }
    }
  }
  throw StateError('main.dart or learning_tracker_app.dart not found');
}

void main() {
  // AUD-core-theme-01: AppTextStyles' English getters (AC5 below) now build
  // on GoogleFonts.plusJakartaSans, which checks the asset bundle via
  // ServicesBinding.instance as a side effect — needs a binding even for the
  // plain (non-widget-pumping) `test()` cases in this file, and CI runs
  // tests in randomized order (TQ-6) so this can't rely on a testWidgets()
  // call elsewhere in the file running first.
  TestWidgetsFlutterBinding.ensureInitialized();

  // ────────────────────────────────────────────────────────────────────────────
  // AC1 — _selectedLanguage hardcode removed from onboarding_screen.dart
  // ────────────────────────────────────────────────────────────────────────────

  group(
    'Story 25.20 AC1 — _selectedLanguage hardcode deleted',
    tags: ['story_25_20'],
    () {
      late String onboardingSource;

      setUpAll(() {
        final candidates = [
          File(
            'lib/features/onboarding/presentation/screens/onboarding_screen.dart',
          ),
          File(
            'learning_tracker/lib/features/onboarding/presentation/screens/onboarding_screen.dart',
          ),
        ];
        for (final f in candidates) {
          if (f.existsSync()) {
            onboardingSource = f.readAsStringSync();
            return;
          }
        }
        throw StateError('onboarding_screen.dart not found');
      });

      test('source no longer contains a `_selectedLanguage` field', () {
        expect(
          onboardingSource,
          isNot(contains('_selectedLanguage')),
          reason:
              'AC1: the hardcoded `_selectedLanguage` field must be deleted; '
              'Flutter handles locale resolution.',
        );
      });

      test('source no longer references `_kOnboardingLanguage` prefs key', () {
        expect(
          onboardingSource,
          isNot(contains('_kOnboardingLanguage')),
          reason:
              'AC1: language picker prefs key is dead with the hardcode gone.',
        );
      });

      test('source no longer has a `languageSelection` phase enum value', () {
        expect(
          onboardingSource,
          isNot(contains('languageSelection')),
          reason:
              'AC1: the languageSelection screen phase is no longer reachable; '
              'remove the enum value and its dead branches.',
        );
      });
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // AC2 / AC3 — MaterialApp locale = null + supportedLocales [en, he]
  // ────────────────────────────────────────────────────────────────────────────

  group(
    'Story 25.20 AC2/AC3 — MaterialApp locale auto-resolution',
    tags: ['story_25_20'],
    () {
      late String mainSource;

      setUpAll(() {
        mainSource = _findAppEntrySource();
      });

      test('main.dart sets MaterialApp `locale: null`', () {
        expect(
          mainSource,
          contains('locale: null'),
          reason:
              'AC2: `locale: null` lets Flutter resolve from device locale '
              'against supportedLocales.',
        );
      });

      test('main.dart no longer reads `appLocaleProvider`', () {
        expect(
          mainSource,
          isNot(contains('appLocaleProvider')),
          reason:
              'AC2: locale is no longer profile-scoped — the appLocaleProvider '
              'watch must be removed so MaterialApp can auto-resolve.',
        );
      });

      test('AppLocalizations.supportedLocales contains both en and he', () {
        expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
        expect(AppLocalizations.supportedLocales, contains(const Locale('he')));
      });
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // AC4 — Noto Sans Hebrew bundled in pubspec.yaml and file present
  // ────────────────────────────────────────────────────────────────────────────

  group(
    'Story 25.20 AC4 — Noto Sans Hebrew font bundled',
    tags: ['story_25_20'],
    () {
      test('pubspec.yaml declares Noto Sans Hebrew family', () {
        final candidates = [
          File('pubspec.yaml'),
          File('learning_tracker/pubspec.yaml'),
        ];
        String? source;
        for (final f in candidates) {
          if (f.existsSync()) {
            source = f.readAsStringSync();
            break;
          }
        }
        expect(source, isNotNull, reason: 'pubspec.yaml not found');
        expect(
          source,
          contains('family: Noto Sans Hebrew'),
          reason: 'AC4: pubspec.yaml must declare the Noto Sans Hebrew family.',
        );
      });

      test('Noto Sans Hebrew Regular TTF file is bundled', () {
        final candidates = [
          File('assets/fonts/NotoSansHebrew-Regular.ttf'),
          File('learning_tracker/assets/fonts/NotoSansHebrew-Regular.ttf'),
        ];
        final exists = candidates.any((f) => f.existsSync());
        expect(
          exists,
          isTrue,
          reason:
              'AC4: the Regular weight TTF must be present in assets/fonts/ '
              '— declaring it in pubspec without the file would crash at runtime.',
        );
      });
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // AC5 — AppTextStyles uses Noto Sans Hebrew for Hebrew script
  // ────────────────────────────────────────────────────────────────────────────

  group(
    'Story 25.20 AC5 — AppTextStyles Hebrew styles use Noto Sans Hebrew',
    tags: ['story_25_20'],
    () {
      test('hebrewBodyLarge uses Noto Sans Hebrew family', () {
        expect(AppTextStyles.hebrewBodyLarge.fontFamily, 'Noto Sans Hebrew');
      });

      test('hebrewHeadlineLarge uses Noto Sans Hebrew family', () {
        expect(
          AppTextStyles.hebrewHeadlineLarge.fontFamily,
          'Noto Sans Hebrew',
        );
      });

      // AUD-core-theme-01 AC2: getTextDirection/getStyleForContent were
      // dead code (zero callers anywhere outside test files) and have been
      // removed from AppTextStyles; their coverage here (previously
      // asserting RTL detection / Hebrew-family style selection through
      // those two helpers) is removed with them. AC5's actual claim —
      // AppTextStyles' Hebrew getters use Noto Sans Hebrew — remains
      // covered by the two tests above.
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // AC6 — CurriculumLabel.curriculum(...) renders Hebrew RTL with no toggle
  // ────────────────────────────────────────────────────────────────────────────

  group(
    'Story 25.20 AC6 — CurriculumLabel auto-RTL for Hebrew script',
    tags: ['story_25_20'],
    () {
      testWidgets(
        'CurriculumLabel.curriculum renders Hebrew with TextDirection.rtl when locale=he',
        (tester) async {
          SharedPreferences.setMockInitialValues(<String, Object>{
            // hebrewTermsScript defaults to false; the DNI-328 key naming
            // scheme is `hebrew_terms_script_p<profileId>`.
            'hebrew_terms_script_p0': true,
          });

          await tester.pumpWidget(
            const ProviderScope(
              child: MaterialApp(
                locale: Locale('he'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: Material(
                  child: Center(
                    child: CurriculumLabel.curriculum(CurriculumId.mishnayos),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final textWidget = tester.widget<Text>(find.byType(Text));
          // Hebrew content must end up RTL — either the widget set
          // textDirection: rtl explicitly, or the locale=he caused the
          // ambient Directionality to resolve to RTL.
          final BuildContext ctx = tester.element(find.byType(Text));
          final resolved = textWidget.textDirection ?? Directionality.of(ctx);
          expect(
            resolved,
            TextDirection.rtl,
            reason:
                'AC6: Hebrew-locale rendering must yield RTL directionality '
                'without any explicit toggle.',
          );

          // Content is the Hebrew curriculum name (displayNameHe).
          expect(
            RegExp('[֐-׿]').hasMatch(textWidget.data ?? ''),
            isTrue,
            reason:
                'AC6: with hebrew terms script enabled the curriculum label '
                'must render Hebrew characters.',
          );
        },
      );
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // AC7 — AppTheme.darkTheme() is a real Material 3 dark palette
  // ────────────────────────────────────────────────────────────────────────────

  group(
    'Story 25.20 AC7 — Real Material 3 dark theme',
    tags: ['story_25_20'],
    () {
      test('darkTheme brightness is dark', () {
        expect(AppTheme.darkTheme().brightness, Brightness.dark);
      });

      test('darkTheme colorScheme brightness is dark', () {
        expect(AppTheme.darkTheme().colorScheme.brightness, Brightness.dark);
      });

      test('darkTheme is distinct from lightTheme', () {
        final light = AppTheme.lightTheme();
        final dark = AppTheme.darkTheme();
        expect(
          dark.colorScheme.surface,
          isNot(equals(light.colorScheme.surface)),
          reason: 'AC7: dark surface must differ from light surface.',
        );
        expect(
          dark.scaffoldBackgroundColor,
          isNot(equals(light.scaffoldBackgroundColor)),
          reason: 'AC7: dark scaffold background must differ from light.',
        );
        expect(
          dark.colorScheme.onSurface,
          isNot(equals(light.colorScheme.onSurface)),
          reason: 'AC7: dark on-surface must differ from light.',
        );
      });

      test('darkTheme uses Material 3', () {
        expect(AppTheme.darkTheme().useMaterial3, isTrue);
      });
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // AC8 — heritage*/child* aliases removed
  // ────────────────────────────────────────────────────────────────────────────

  group(
    'Story 25.20 AC8 — heritage*/child* color aliases consolidated',
    tags: ['story_25_20'],
    () {
      late String appThemeSource;

      setUpAll(() {
        final candidates = [
          File('lib/core/theme/app_theme.dart'),
          File('learning_tracker/lib/core/theme/app_theme.dart'),
        ];
        for (final f in candidates) {
          if (f.existsSync()) {
            appThemeSource = f.readAsStringSync();
            return;
          }
        }
        throw StateError('app_theme.dart not found');
      });

      test('app_theme.dart no longer declares `heritage*` color aliases', () {
        expect(
          appThemeSource,
          isNot(contains('heritageGold')),
          reason: 'AC8: heritage* aliases must be removed.',
        );
        expect(appThemeSource, isNot(contains('heritageNavy')));
        expect(appThemeSource, isNot(contains('heritageParchment')));
        expect(appThemeSource, isNot(contains('heritageInk')));
        expect(appThemeSource, isNot(contains('heritageDarkInk')));
      });

      test('app_theme.dart no longer declares `child*` color aliases', () {
        expect(
          appThemeSource,
          isNot(contains('childBackground')),
          reason: 'AC8: child* aliases must be removed.',
        );
        expect(appThemeSource, isNot(contains('childSurface')));
        expect(appThemeSource, isNot(contains('childCard')));
        expect(appThemeSource, isNot(contains('childOutline')));
        expect(appThemeSource, isNot(contains('childPrimary')));
        expect(appThemeSource, isNot(contains('childStreakAccent')));
        expect(appThemeSource, isNot(contains('childPointsAccent')));
        expect(appThemeSource, isNot(contains('childTrophyAccent')));
        expect(appThemeSource, isNot(contains('childText')));
        expect(appThemeSource, isNot(contains('childTextMuted')));
      });
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // AC9 — MaterialApp uses ThemeMode.system + provides darkTheme
  // ────────────────────────────────────────────────────────────────────────────

  group(
    'Story 25.20 AC9 — MaterialApp themeMode = ThemeMode.system + darkTheme set',
    tags: ['story_25_20'],
    () {
      test('main.dart wires `themeMode: ThemeMode.system`', () {
        // weaken-ok: the standalone `expect(source, isNotNull)` is gone
        // because _findAppEntrySource() now throws StateError (an equally
        // loud, equally test-failing signal) instead of returning null when
        // no candidate file is found — see AUD-t-story-acceptance-34.
        final source = _findAppEntrySource();
        expect(
          source,
          contains('themeMode: ThemeMode.system'),
          reason:
              'AC9: ThemeMode.system makes MaterialApp pick light/dark by '
              'MediaQuery.platformBrightnessOf(context) automatically.',
        );
      });

      test('main.dart passes `darkTheme: AppTheme.darkTheme()`', () {
        // weaken-ok: same as above — StateError from _findAppEntrySource()
        // replaces the standalone isNotNull check with an equally-loud
        // not-found failure (AUD-t-story-acceptance-34).
        final source = _findAppEntrySource();
        expect(
          source,
          contains('darkTheme: AppTheme.darkTheme()'),
          reason:
              'AC9: passing a darkTheme alongside theme is what enables '
              'system-driven theme selection.',
        );
      });
    },
  );
}
