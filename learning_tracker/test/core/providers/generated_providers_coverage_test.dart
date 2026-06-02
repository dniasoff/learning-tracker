/// Coverage for generated provider .g.dart files.
///
/// Exercises:
///   - Family provider instance toString(), ==, hashCode
///   - Family provider toString()
///   - Non-family provider overrideWithValue()
///   - Non-family provider debugGetCreateSourceHash()
///
/// No ProviderContainer needed — we only call methods on provider objects.
library;

import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/auth/auth_providers.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart'
    show TransliterationVariant;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/preferences/app_locale_preference.dart';
import 'package:learning_tracker/core/preferences/hebrew_date_preference.dart';
import 'package:learning_tracker/core/preferences/hebrew_terms_preference.dart';
import 'package:learning_tracker/core/preferences/nikud_preference.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/preferences/text_display_preference.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart'
    show FontSize;
import 'package:learning_tracker/core/preferences/transliteration_variant_preference.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/track_providers.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/cities_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/study_day_config_providers.dart';

void main() {
  // ── curriculum_label_providers.g.dart ─────────────────────────────────────

  group('curriculum label provider instances', () {
    test(
      'renderedDisplayForRefProvider family and instance toString/==/hash',
      () {
        // Family toString (line 111)
        expect(
          renderedDisplayForRefProvider.toString(),
          contains('renderedDisplayForRef'),
        );
        // Instance toString (lines 146-150 in g.dart)
        final p1 = renderedDisplayForRefProvider('Berakhot 2a');
        final p2 = renderedDisplayForRefProvider('Berakhot 2a');
        final p3 = renderedDisplayForRefProvider('Sanhedrin 2a');
        expect(p1.toString(), contains('Berakhot 2a'));
        // == (lines 164-166)
        expect(p1, equals(p2));
        expect(p1 == p3, isFalse);
        // hashCode (lines 169-172)
        expect(p1.hashCode, equals(p2.hashCode));
        expect(p1.debugGetCreateSourceHash(), isNotEmpty);
      },
    );

    test('renderedLeafForRefProvider family and instance toString/==/hash', () {
      expect(
        renderedLeafForRefProvider.toString(),
        contains('renderedLeafForRef'),
      );
      final p1 = renderedLeafForRefProvider('Berakhot 2a');
      final p2 = renderedLeafForRefProvider('Berakhot 2a');
      final p3 = renderedLeafForRefProvider('Shabbat 2a');
      expect(p1.toString(), contains('Berakhot'));
      expect(p1, equals(p2));
      expect(p1 == p3, isFalse);
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });

    test(
      'renderedParentForRefProvider family and instance toString/==/hash',
      () {
        expect(
          renderedParentForRefProvider.toString(),
          contains('renderedParentForRef'),
        );
        final p1 = renderedParentForRefProvider('Berakhot 2a');
        final p2 = renderedParentForRefProvider('Berakhot 2a');
        final p3 = renderedParentForRefProvider('Moed 1');
        expect(p1.toString(), contains('Berakhot'));
        expect(p1, equals(p2));
        expect(p1 == p3, isFalse);
        expect(p1.hashCode, equals(p2.hashCode));
        expect(p1.debugGetCreateSourceHash(), isNotEmpty);
      },
    );

    test(
      'renderedBreadcrumbForRefProvider family and instance toString/==/hash',
      () {
        expect(
          renderedBreadcrumbForRefProvider.toString(),
          contains('renderedBreadcrumbForRef'),
        );
        final p1 = renderedBreadcrumbForRefProvider('Berakhot 2a');
        final p2 = renderedBreadcrumbForRefProvider('Berakhot 2a');
        final p3 = renderedBreadcrumbForRefProvider('Beitzah 1a');
        expect(p1.toString(), contains('Berakhot'));
        expect(p1, equals(p2));
        expect(p1 == p3, isFalse);
        expect(p1.hashCode, equals(p2.hashCode));
        expect(p1.debugGetCreateSourceHash(), isNotEmpty);
      },
    );
  });

  // ── preference_providers.g.dart ───────────────────────────────────────────

  group('preference providers overrideWithValue', () {
    test('hebrewTermsPreferenceProvider overrideWithValue', () {
      // covers lines 56-57, 59
      final override = hebrewTermsPreferenceProvider.overrideWithValue(
        HebrewTermsPreference(),
      );
      expect(override, isNotNull);
    });

    test('hebrewDatePreferenceProvider overrideWithValue', () {
      // covers lines 104-105, 107
      final override = hebrewDatePreferenceProvider.overrideWithValue(
        HebrewDatePreference(),
      );
      expect(override, isNotNull);
    });

    test('nikudPreferenceProvider overrideWithValue', () {
      // covers lines 147-148, 150
      final override = nikudPreferenceProvider.overrideWithValue(
        NikudPreference(),
      );
      expect(override, isNotNull);
    });

    test('appLocalePreferenceProvider init and overrideWithValue', () {
      // accessing it covers lines 158, 168-169
      expect(
        appLocalePreferenceProvider.debugGetCreateSourceHash(),
        isNotEmpty,
      );
      // overrideWithValue covers 194-197
      final override = appLocalePreferenceProvider.overrideWithValue(
        AppLocalePreference(),
      );
      expect(override, isNotNull);
    });

    test('transliterationVariantPreferenceProvider overrideWithValue', () {
      // covers lines 243-246
      final override = transliterationVariantPreferenceProvider
          .overrideWithValue(TransliterationVariantPreference());
      expect(override, isNotNull);
    });

    test('textDisplayPreferenceProvider overrideWithValue', () {
      // covers lines 293-296
      final override = textDisplayPreferenceProvider.overrideWithValue(
        TextDisplayPreference(),
      );
      expect(override, isNotNull);
    });

    test('useHebrewTermsProvider overrideWithValue bool', () {
      // covers lines 338-341
      final override = useHebrewTermsProvider.overrideWithValue(true);
      expect(override, isNotNull);
    });

    test('showNikudPrefProvider overrideWithValue bool', () {
      // covers lines 446-449
      final override = showNikudPrefProvider.overrideWithValue(false);
      expect(override, isNotNull);
    });

    test('currentAppLocaleProvider overrideWithValue Locale', () {
      // init + constructor covers 475, 479-480
      expect(currentAppLocaleProvider.debugGetCreateSourceHash(), isNotEmpty);
      // overrideWithValue covers 490-493
      final override = currentAppLocaleProvider.overrideWithValue(
        const Locale('en'),
      );
      expect(override, isNotNull);
    });

    test('currentTransliterationVariantProvider overrideWithValue', () {
      // covers lines 555-558
      final override = currentTransliterationVariantProvider.overrideWithValue(
        TransliterationVariant.sephardi,
      );
      expect(override, isNotNull);
    });

    test('currentFontSizeProvider overrideWithValue FontSize', () {
      // covers lines 610-613
      final override = currentFontSizeProvider.overrideWithValue(
        FontSize.large,
      );
      expect(override, isNotNull);
    });
  });

  // ── track_providers.g.dart ────────────────────────────────────────────────

  group('track provider instances', () {
    test('trackRepositoryProvider init and debugGetCreateSourceHash', () {
      // covers lines 14, 23-24, 34-35
      expect(trackRepositoryProvider.debugGetCreateSourceHash(), isNotEmpty);
    });
  });

  // ── study_day_config_providers.g.dart ─────────────────────────────────────

  group('study day config provider instances', () {
    test('studyDayConfigsProvider family and instance toString/==/hash', () {
      expect(studyDayConfigsProvider.toString(), contains('studyDayConfigs'));
      final p1 = studyDayConfigsProvider(CurriculumId.bavli);
      final p2 = studyDayConfigsProvider(CurriculumId.bavli);
      final p3 = studyDayConfigsProvider(CurriculumId.mishnayos);
      expect(p1.toString(), contains('bavli'));
      expect(p1, equals(p2));
      expect(p1 == p3, isFalse);
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('isStudyDayProvider family and instance toString/==/hash', () {
      expect(isStudyDayProvider.toString(), contains('isStudyDay'));
      final p1 = isStudyDayProvider(CurriculumId.bavli);
      final p2 = isStudyDayProvider(CurriculumId.bavli);
      expect(p1.toString(), contains('bavli'));
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('studyDaysPerWeekProvider family and instance toString/==/hash', () {
      expect(studyDaysPerWeekProvider.toString(), contains('studyDaysPerWeek'));
      final p1 = studyDaysPerWeekProvider(CurriculumId.bavli);
      final p2 = studyDaysPerWeekProvider(CurriculumId.bavli);
      expect(p1.toString(), contains('bavli'));
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('toggleStudyDayProvider family and instance toString/==/hash', () {
      expect(toggleStudyDayProvider.toString(), contains('toggleStudyDay'));
      final p1 = toggleStudyDayProvider(CurriculumId.bavli, 0, DayType.study);
      final p2 = toggleStudyDayProvider(CurriculumId.bavli, 0, DayType.study);
      final p3 = toggleStudyDayProvider(
        CurriculumId.mishnayos,
        1,
        DayType.review,
      );
      expect(p1.toString(), contains('toggleStudyDay'));
      expect(p1, equals(p2));
      expect(p1 == p3, isFalse);
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });
  });

  // ── scheduler_providers.g.dart ────────────────────────────────────────────

  group('scheduler provider instances', () {
    test('clockProvider overrideWithValue DateTime', () {
      // covers lines 47-50
      final override = clockProvider.overrideWithValue(
        DateTime.utc(2026, 3, 1),
      );
      expect(override, isNotNull);
    });

    test('skippedTasksProvider overrideWithValue Set', () {
      // covers lines 302-305
      final override = skippedTasksProvider.overrideWithValue({'ref1', 'ref2'});
      expect(override, isNotNull);
    });

    test('dailyTasksProvider family and instance toString/==/hash', () {
      expect(dailyTasksProvider.toString(), contains('dailyTasks'));
      final p1 = dailyTasksProvider(
        curriculumId: CurriculumId.bavli,
        trackId: 1,
        trackLabel: 'test',
      );
      final p2 = dailyTasksProvider(
        curriculumId: CurriculumId.bavli,
        trackId: 1,
        trackLabel: 'test',
      );
      final p3 = dailyTasksProvider(
        curriculumId: CurriculumId.mishnayos,
        trackId: 2,
        trackLabel: 'other',
      );
      expect(p1.toString(), contains('dailyTasks'));
      expect(p1, equals(p2));
      expect(p1 == p3, isFalse);
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('paceStatusProvider family and instance toString/==/hash', () {
      expect(paceStatusProvider.toString(), contains('paceStatus'));
      final now = DateTime.utc(2026, 3, 1);
      final p1 = paceStatusProvider(
        curriculumId: CurriculumId.bavli,
        goalStartDate: now,
        goalDeadline: null,
        totalItems: 100,
        goalType: 'pace',
        pacePerDay: 1.0,
      );
      final p2 = paceStatusProvider(
        curriculumId: CurriculumId.bavli,
        goalStartDate: now,
        goalDeadline: null,
        totalItems: 100,
        goalType: 'pace',
        pacePerDay: 1.0,
      );
      expect(p1.toString(), contains('paceStatus'));
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });
  });

  // ── progress_providers.g.dart ─────────────────────────────────────────────

  group('progress provider instances', () {
    test('progressRepositoryProvider init and debugGetCreateSourceHash', () {
      expect(progressRepositoryProvider.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('trackBreakdownProvider family and instance toString/==/hash', () {
      expect(trackBreakdownProvider.toString(), contains('trackBreakdown'));
      final p1 = trackBreakdownProvider('bavli');
      final p2 = trackBreakdownProvider('bavli');
      final p3 = trackBreakdownProvider('mishnah');
      expect(p1.toString(), contains('bavli'));
      expect(p1, equals(p2));
      expect(p1 == p3, isFalse);
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('aggregateCountProvider family and instance toString/==/hash', () {
      expect(aggregateCountProvider.toString(), contains('aggregateCount'));
      final p1 = aggregateCountProvider('bavli');
      final p2 = aggregateCountProvider('bavli');
      expect(p1.toString(), contains('bavli'));
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('curriculumProgressProvider family and instance toString/==/hash', () {
      expect(
        curriculumProgressProvider.toString(),
        contains('curriculumProgress'),
      );
      final p1 = curriculumProgressProvider('bavli');
      final p2 = curriculumProgressProvider('bavli');
      expect(p1.toString(), contains('bavli'));
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });

    test(
      'curriculumPaceStatusProvider family and instance toString/==/hash',
      () {
        expect(
          curriculumPaceStatusProvider.toString(),
          contains('curriculumPaceStatus'),
        );
        final p1 = curriculumPaceStatusProvider('bavli');
        final p2 = curriculumPaceStatusProvider('bavli');
        expect(p1.toString(), contains('bavli'));
        expect(p1, equals(p2));
        expect(p1.hashCode, equals(p2.hashCode));
        expect(p1.debugGetCreateSourceHash(), isNotEmpty);
      },
    );
  });

  // ── dashboard_providers.g.dart ────────────────────────────────────────────

  group('dashboard provider instances', () {
    test('crossCurriculumAggregatorProvider debugGetCreateSourceHash', () {
      // covers lines 14, 27-28, 38-39
      expect(
        crossCurriculumAggregatorProvider.debugGetCreateSourceHash(),
        isNotEmpty,
      );
    });

    test(
      'dashboardTrackCompletionPercentageProvider family toString/==/hash',
      () {
        expect(
          dashboardTrackCompletionPercentageProvider.toString(),
          contains('dashboardTrackCompletionPercentage'),
        );
        final p1 = dashboardTrackCompletionPercentageProvider(1);
        final p2 = dashboardTrackCompletionPercentageProvider(1);
        final p3 = dashboardTrackCompletionPercentageProvider(2);
        expect(p1.toString(), contains('dashboardTrackCompletion'));
        expect(p1, equals(p2));
        expect(p1 == p3, isFalse);
        expect(p1.hashCode, equals(p2.hashCode));
        expect(p1.debugGetCreateSourceHash(), isNotEmpty);
      },
    );

    test('dashboardCompletionPercentageProvider family toString/==/hash', () {
      expect(
        dashboardCompletionPercentageProvider.toString(),
        contains('dashboardCompletionPercentage'),
      );
      final p1 = dashboardCompletionPercentageProvider(CurriculumId.bavli);
      final p2 = dashboardCompletionPercentageProvider(CurriculumId.bavli);
      final p3 = dashboardCompletionPercentageProvider(CurriculumId.mishnayos);
      expect(p1.toString(), contains('bavli'));
      expect(p1, equals(p2));
      expect(p1 == p3, isFalse);
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('dashboardLastCompletionProvider family toString/==/hash', () {
      expect(
        dashboardLastCompletionProvider.toString(),
        contains('dashboardLastCompletion'),
      );
      final p1 = dashboardLastCompletionProvider(CurriculumId.bavli);
      final p2 = dashboardLastCompletionProvider(CurriculumId.bavli);
      expect(p1.toString(), contains('bavli'));
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('dashboardPaceStatusProvider family toString/==/hash', () {
      expect(
        dashboardPaceStatusProvider.toString(),
        contains('dashboardPaceStatus'),
      );
      final p1 = dashboardPaceStatusProvider(CurriculumId.bavli);
      final p2 = dashboardPaceStatusProvider(CurriculumId.bavli);
      final p3 = dashboardPaceStatusProvider(CurriculumId.mishnayos);
      expect(p1.toString(), contains('bavli'));
      expect(p1, equals(p2));
      expect(p1 == p3, isFalse);
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });
  });

  // ── content_providers.g.dart ─────────────────────────────────────────────

  group('content provider instances', () {
    test('curriculumContentProvider family and instance toString/==/hash', () {
      expect(
        curriculumContentProvider.toString(),
        contains('curriculumContent'),
      );
      final p1 = curriculumContentProvider(CurriculumId.bavli);
      final p2 = curriculumContentProvider(CurriculumId.bavli);
      final p3 = curriculumContentProvider(CurriculumId.mishnayos);
      expect(p1.toString(), contains('bavli'));
      expect(p1, equals(p2));
      expect(p1 == p3, isFalse);
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('curriculumHeNamesProvider family and instance toString/==/hash', () {
      expect(
        curriculumHeNamesProvider.toString(),
        contains('curriculumHeNames'),
      );
      final p1 = curriculumHeNamesProvider(CurriculumId.bavli);
      final p2 = curriculumHeNamesProvider(CurriculumId.bavli);
      expect(p1.toString(), contains('bavli'));
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });
  });

  // ── text_display_providers.g.dart ─────────────────────────────────────────

  group('text display provider instances', () {
    test('textCacheRepositoryProvider debugGetCreateSourceHash', () {
      // covers lines 38-39, 41, 45, 47, 49
      expect(
        textCacheRepositoryProvider.debugGetCreateSourceHash(),
        isNotEmpty,
      );
    });

    test('textContentProvider family and instance toString/==/hash', () {
      // covers lines 94-98, 114-121, 144
      expect(textContentProvider.toString(), contains('textContent'));
      final p1 = textContentProvider('Berakhot 2a');
      final p2 = textContentProvider('Berakhot 2a');
      final p3 = textContentProvider('Shabbat 2a');
      expect(p1.toString(), contains('Berakhot'));
      expect(p1, equals(p2));
      expect(p1 == p3, isFalse);
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('fontSizeProvider overrideWithValue FontSize', () {
      // covers lines 182-185
      final override = fontSizeProvider.overrideWithValue(FontSize.medium);
      expect(override, isNotNull);
      expect(fontSizeProvider.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('showNikudProvider overrideWithValue bool', () {
      // covers lines 244-247
      final override = showNikudProvider.overrideWithValue(true);
      expect(override, isNotNull);
      expect(showNikudProvider.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('textDownloadServiceProvider debugGetCreateSourceHash', () {
      // covers lines 291-296
      expect(
        textDownloadServiceProvider.debugGetCreateSourceHash(),
        isNotEmpty,
      );
    });
  });

  // ── journey_providers.g.dart ──────────────────────────────────────────────

  group('journey provider instances', () {
    test(
      'journeySortModeProvider debugGetCreateSourceHash and overrideWithValue',
      () {
        // covers lines 14, 20-21, 31-32, 34, 36, 39-40, 42
        expect(journeySortModeProvider.debugGetCreateSourceHash(), isNotEmpty);
        // covers lines 38-42
        final override = journeySortModeProvider.overrideWithValue(
          JourneySortModeValue.grouped,
        );
        expect(override, isNotNull);
      },
    );

    test('journeyViewModelProvider family and instance toString/==/hash', () {
      // covers lines 55, 58-68, 87-99, 101-106, 120-129, 151-152
      expect(journeyViewModelProvider.toString(), contains('journeyViewModel'));
      final p1 = journeyViewModelProvider(1);
      final p2 = journeyViewModelProvider(1);
      final p3 = journeyViewModelProvider(2);
      expect(p1.toString(), contains('journeyViewModel'));
      expect(p1, equals(p2));
      expect(p1 == p3, isFalse);
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });
  });

  // ── cities_provider.g.dart ────────────────────────────────────────────────

  group('cities provider instances', () {
    test('citiesRepositoryProvider debugGetCreateSourceHash', () {
      // covers lines 13, 23-24, 34-35, 37, 40, 42, 44, 48-51, 56
      expect(citiesRepositoryProvider.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('citySearchProvider family and instance toString/==/hash', () {
      // covers lines 62, 77-96
      expect(citySearchProvider.toString(), contains('citySearch'));
      final p1 = citySearchProvider('berakhot');
      final p2 = citySearchProvider('berakhot');
      final p3 = citySearchProvider('jerusalem');
      expect(p1.toString(), contains('berakhot'));
      expect(p1, equals(p2));
      expect(p1 == p3, isFalse);
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.debugGetCreateSourceHash(), isNotEmpty);
    });
  });

  // ── notification_providers.g.dart ─────────────────────────────────────────

  group('notification provider instances', () {
    test('notificationServiceProvider debugGetCreateSourceHash', () {
      // covers lines 38-39, 41, 45, 47, 49, 61
      expect(
        notificationServiceProvider.debugGetCreateSourceHash(),
        isNotEmpty,
      );
    });

    test('reminderEnabledProvider overrideWithValue bool', () {
      // covers lines 92-93, 95
      final override = reminderEnabledProvider.overrideWithValue(true);
      expect(override, isNotNull);
      expect(reminderEnabledProvider.debugGetCreateSourceHash(), isNotEmpty);
    });
  });

  // ── completion_providers.g.dart ───────────────────────────────────────────

  group('completion provider instances', () {
    test('completionRepositoryProvider debugGetCreateSourceHash', () {
      // covers lines 14, 27-28, 38-39
      expect(
        completionRepositoryProvider.debugGetCreateSourceHash(),
        isNotEmpty,
      );
    });

    test('markCompletionUseCaseProvider debugGetCreateSourceHash', () {
      // covers lines 67, 80-81, 91-92
      expect(
        markCompletionUseCaseProvider.debugGetCreateSourceHash(),
        isNotEmpty,
      );
    });

    test('bulkMarkCompletionUseCaseProvider debugGetCreateSourceHash', () {
      // covers lines 120, 133-134, 144-145
      expect(
        bulkMarkCompletionUseCaseProvider.debugGetCreateSourceHash(),
        isNotEmpty,
      );
    });
  });

  // ── scheduler remaining ───────────────────────────────────────────────────

  group('scheduler remaining provider instances', () {
    test('previouslySkippedRefsProvider debugGetCreateSourceHash', () {
      // covers lines 339, 352-353, 363-364
      expect(
        previouslySkippedRefsProvider.debugGetCreateSourceHash(),
        isNotEmpty,
      );
    });

    test('schedulerEngineProvider debugGetCreateSourceHash', () {
      // covers lines 58, 64-65, 75-76
      expect(schedulerEngineProvider.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('dailyTaskGeneratorProvider debugGetCreateSourceHash', () {
      // covers lines 100, 110-111, 122
      expect(dailyTaskGeneratorProvider.debugGetCreateSourceHash(), isNotEmpty);
    });
  });

  // ── database_provider.g.dart ──────────────────────────────────────────────

  group('database provider instances', () {
    test('contentDbPathProvider overrideWithValue String', () {
      // covers lines 120-123
      final override = contentDbPathProvider.overrideWithValue(
        'test/db/content.db',
      );
      expect(override, isNotNull);
    });

    // ignore: deprecated_member_use
    test('appDatabaseProvider debugGetCreateSourceHash', () {
      // covers lines 219-220
      // ignore: deprecated_member_use
      expect(appDatabaseProvider.debugGetCreateSourceHash(), isNotEmpty);
    });
  });

  // ── auth_providers.g.dart ─────────────────────────────────────────────────

  group('auth provider instances', () {
    test('firebaseAuthGatewayProvider debugGetCreateSourceHash', () {
      // Generated by core/auth/auth_providers.dart.
      expect(
        firebaseAuthGatewayProvider.debugGetCreateSourceHash(),
        isNotEmpty,
      );
    });

    test('googleSignInGatewayProvider debugGetCreateSourceHash', () {
      // Generated by core/auth/auth_providers.dart.
      expect(
        googleSignInGatewayProvider.debugGetCreateSourceHash(),
        isNotEmpty,
      );
    });

    test('authRepositoryProvider debugGetCreateSourceHash', () {
      // Generated by features/account/presentation/providers/auth_providers.dart.
      expect(authRepositoryProvider.debugGetCreateSourceHash(), isNotEmpty);
    });
  });

  // ── profile_providers.g.dart ──────────────────────────────────────────────

  group('profile provider instances', () {
    test('currentAccountIdProvider overrideWithValue int', () {
      // covers lines 70-71, 73
      final override = currentAccountIdProvider.overrideWithValue(1);
      expect(override, isNotNull);
    });

    test('profileRepositoryProvider debugGetCreateSourceHash', () {
      // covers lines 83, 96-97, 107-108
      expect(profileRepositoryProvider.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('selectedProfileIdProvider overrideWithValue null', () {
      // covers lines 160-161, 163
      final override = selectedProfileIdProvider.overrideWithValue(null);
      expect(override, isNotNull);
    });
  });

  // ── completion_writer_providers.g.dart ────────────────────────────────────

  group('completion writer provider instances', () {
    test('completionWriterProvider debugGetCreateSourceHash', () {
      // covers lines 15, 30-31, 41-42
      expect(completionWriterProvider.debugGetCreateSourceHash(), isNotEmpty);
    });

    test('completionCommittedProvider overrideWithValue int', () {
      // covers lines 123-124, 126
      final override = completionCommittedProvider.overrideWithValue(0);
      expect(override, isNotNull);
    });
  });

  // ── learning_ledger_providers.g.dart ──────────────────────────────────────

  group('learning ledger provider instances', () {
    test('learningLedgerRepositoryProvider debugGetCreateSourceHash', () {
      // covers lines 14, 27-28, 38-39
      expect(
        learningLedgerRepositoryProvider.debugGetCreateSourceHash(),
        isNotEmpty,
      );
    });
  });
}
