/// Regression test for TS-5:
/// In pace mode the Continue button's tap area must not overlap with the
/// inactive (dimmed) deadline card. Tapping Continue should emit a GoalEntity
/// via onComplete, NOT switch to deadline mode or open a date picker.
///
/// The fix wraps the inactive deadline card in [IgnorePointer] so its
/// InkWell cannot intercept taps that land on the Continue button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart'
    show TransliterationVariant;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart'
    show ActiveProfileId, activeProfileIdProvider;
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_goal.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/drift_memory.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockContentRepository extends Mock implements ContentRepository {}

class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _FalseUseHebrewDate extends UseHebrewDate {
  @override
  bool build() => false;
}

class _ProfileIdOverride extends ActiveProfileId {
  @override
  int build() => 1;
}

// ── Delegates ─────────────────────────────────────────────────────────────────

const _kDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

// ── Setup ─────────────────────────────────────────────────────────────────────

const _kScopeCount = 30;

List<Override> _overrides() {
  final db = inMemoryDb();
  final contentRepo = _MockContentRepository();

  when(
    () => contentRepo.getContentForCurriculum(any()),
  ).thenAnswer((_) async => []);

  return [
    userDatabaseProvider.overrideWithValue(db),
    contentRepositoryProvider.overrideWith((ref) => contentRepo),
    useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
    useHebrewDateProvider.overrideWith(() => _FalseUseHebrewDate()),
    syncWriteFacadeProvider.overrideWithValue(null),
    activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
    scopedCurriculumContentProvider(CurriculumId.mishnayos).overrideWith((
      ref,
    ) async {
      return List.generate(
        _kScopeCount,
        (i) => ContentItem(
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot $i',
          displayNameEn: 'Berakhot $i',
          displayNameHe: 'ברכות $i',
          level1: 'Seder Zeraim',
          sortOrder: i,
          isLeaf: true,
        ),
      );
    }),
    scopedItemCountProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => _kScopeCount),
    currentTransliterationVariantProvider.overrideWith(
      () => _AshkenaziVariant(),
    ),
  ];
}

class _AshkenaziVariant extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
}

Widget _buildStep({ValueChanged<GoalEntity?>? onComplete}) {
  SharedPreferences.setMockInitialValues({});
  GoogleFonts.config.allowRuntimeFetching = false;

  return ProviderScope(
    retry: (_, __) => null,
    overrides: _overrides(),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: _kDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SelfPacedGoalStep(
          curriculumId: CurriculumId.mishnayos,
          studyDays: const {
            1: 'study',
            2: 'study',
            3: 'study',
            4: 'study',
            5: 'study',
          },
          onComplete: onComplete ?? (_) {},
        ),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  group('TS-5 — Continue button does not overlap inactive deadline card', () {
    testWidgets(
      'tapping Continue in pace mode calls onComplete, not deadline mode',
      (tester) async {
        // Use a tall viewport so Continue is visible without scrolling.
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        GoalEntity? emitted;
        await tester.pumpWidget(_buildStep(onComplete: (g) => emitted = g));
        await _settle(tester);

        // The step starts in pace mode — the deadline card is dimmed/inactive.
        // Scroll to ensure Continue is visible.
        final continueButton = find.text('Continue');
        expect(
          continueButton,
          findsOneWidget,
          reason: 'Continue button must be visible',
        );
        await tester.ensureVisible(continueButton);
        await tester.pump();

        await tester.tap(continueButton);
        await _settle(tester);

        // onComplete must have been called with a pace-type goal.
        expect(
          emitted,
          isNotNull,
          reason:
              'TS-5: tapping Continue must emit a GoalEntity, not be intercepted '
              'by the inactive deadline card',
        );
        expect(
          emitted?.goalType,
          equals('pace'),
          reason: 'In default pace mode, the emitted goal type must be pace',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'inactive deadline card BlurInactiveGoalOption does not steal taps from Continue area',
      (tester) async {
        // This test verifies the fix: the inactive deadline card must NOT intercept
        // taps on the Continue button. After the TS-5 fix (ClipRect wrapping),
        // the deadline card's InkWell is bounded to the card's visual extent.
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        GoalEntity? emitted;
        await tester.pumpWidget(_buildStep(onComplete: (g) => emitted = g));
        await _settle(tester);

        // Verify the date picker is NOT open before tapping
        expect(find.byType(DatePickerDialog), findsNothing);

        // Scroll to the Continue button and tap it
        final continueButton = find.text('Continue');
        expect(continueButton, findsOneWidget);
        await tester.ensureVisible(continueButton);
        await tester.pump();

        await tester.tap(continueButton);
        await _settle(tester);

        // If TS-5 is NOT fixed: the date picker opens (deadline card intercepted)
        // and onComplete is not called.
        // After the fix: onComplete fires and no date picker opens.
        expect(
          find.byType(DatePickerDialog),
          findsNothing,
          reason: 'TS-5: tapping Continue must NOT open the date picker',
        );
        expect(
          emitted,
          isNotNull,
          reason: 'TS-5: tapping Continue must emit via onComplete',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
