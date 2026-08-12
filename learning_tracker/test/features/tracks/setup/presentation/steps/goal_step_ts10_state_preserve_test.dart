/// Regression test for TS-10:
/// SelfPacedGoalStep must accept an [initialGoal] parameter and restore
/// _mode='deadline' and _deadline when the user navigates Back and returns
/// to the goal step.
///
/// Before the fix: SelfPacedGoalStep always initializes _mode='pace' and
/// _deadline=today on every rebuild, discarding any deadline the user set.
///
/// After the fix: the step accepts [initialGoal] and restores the goal type
/// (pace/deadline) and target date from it.
///
/// AUD-t-tracks-05: the original version of this file only constructed the
/// widget and asserted the constructor stored the field verbatim — a check
/// that Dart's own field assignment guarantees trivially and would stay
/// green even if `initState` stopped reading [SelfPacedGoalStep.initialGoal]
/// entirely. This version pumps the widget and asserts the OBSERVABLE
/// deadline-mode state that `initState`/`build` derive from it: the deadline
/// card renders active (not blurred), and tapping Continue immediately
/// emits a deadline-type goal carrying the restored target date.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart'
    show TransliterationVariant;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart'
    show ActiveProfileId, activeProfileIdProvider;
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/goal_cards.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_goal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/fake_clock.dart';
import '../../../../../helpers/pump_app.dart';

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
  String? build() => '01J6Q2H4A8M7K3P9R5T6V8WXYC';
}

class _AshkenaziVariant extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
}

// ── Setup ─────────────────────────────────────────────────────────────────────

const _kScopeCount = 30;

// "Now" is pinned well before the deadline used below so the study-day
// window math has room to find study days regardless of wall-clock date.
final _fixedNow = DateTime.utc(2026, 6, 11);

List<Override> _overrides() {
  final contentRepo = _MockContentRepository();

  when(
    () => contentRepo.getContentForCurriculum(any()),
  ).thenAnswer((_) async => []);

  return [
    contentRepositoryProvider.overrideWith((ref) => contentRepo),
    useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
    useHebrewDateProvider.overrideWith(() => _FalseUseHebrewDate()),
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

Widget _buildStep({
  required GoalEntity? initialGoal,
  ValueChanged<GoalEntity?>? onComplete,
}) {
  SharedPreferences.setMockInitialValues({});
  GoogleFonts.config.allowRuntimeFetching = false;

  return pumpApp(
    retry: (_, __) => null,
    overrides: _overrides(),
    child: Scaffold(
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
        initialGoal: initialGoal,
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

  setUp(() {
    installFakeClock(_fixedNow);
  });

  group('TS-10 — SelfPacedGoalStep preserves goal state via initialGoal', () {
    testWidgets(
      'pumping with a deadline initialGoal renders the deadline card active '
      'and Continue emits the restored deadline (not the pace default)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final deadline = DateTime(2026, 12, 31);
        final initialGoal = GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          goalType: 'deadline',
          targetDate: deadline.toUtc(),
          paceValue: 7,
          pacePeriod: 'per_week',
          createdAt: _fixedNow,
          updatedAt: _fixedNow,
        );

        GoalEntity? emitted;
        await tester.pumpWidget(
          _buildStep(initialGoal: initialGoal, onComplete: (g) => emitted = g),
        );
        await _settle(tester);

        // Observable state, not constructor storage: the deadline card must
        // render as the ACTIVE card (border highlighted, not blurred) and
        // the pace card must be the inactive one — this only happens if
        // initState actually read widget.initialGoal and set _mode.
        final deadlineCardWidget = tester.widget<DeadlineGoalCard>(
          find.byType(DeadlineGoalCard),
        );
        expect(
          deadlineCardWidget.isActive,
          isTrue,
          reason:
              'TS-10: a deadline-type initialGoal must activate the deadline '
              'card — if initState stops reading widget.initialGoal this '
              'stays false (mode defaults to pace)',
        );
        expect(
          deadlineCardWidget.deadline,
          equals(deadline),
          reason:
              'TS-10: the restored deadline must be the target date carried '
              'by initialGoal, not the 30-days-from-now default',
        );

        final paceCardWidget = tester.widget<PaceGoalCard>(
          find.byType(PaceGoalCard),
        );
        expect(
          paceCardWidget.isActive,
          isFalse,
          reason:
              'TS-10: pace card must be inactive when a deadline goal is restored',
        );

        // The inactive PACE card is the one wrapped in the blur overlay —
        // the deadline card itself must NOT be blurred.
        expect(
          find.ancestor(
            of: find.byWidget(deadlineCardWidget),
            matching: find.byType(BlurInactiveGoalOption),
          ),
          findsNothing,
          reason: 'TS-10: the active deadline card must not be blurred',
        );

        // Drive it end-to-end: tapping Continue in the restored deadline
        // mode must emit a deadline goal carrying the restored target date,
        // not silently fall back to a pace-type goal.
        final continueButton = find.text('Continue');
        expect(continueButton, findsOneWidget);
        await tester.ensureVisible(continueButton);
        await tester.pump();
        await tester.tap(continueButton);
        await _settle(tester);

        expect(emitted, isNotNull, reason: 'TS-10: Continue must emit a goal');
        expect(
          emitted?.goalType,
          equals('deadline'),
          reason:
              'TS-10: the emitted goal must still be deadline-type — if the '
              'restore is broken, _mode silently reverts to pace',
        );
        expect(
          emitted?.targetDate,
          equals(deadline.toUtc()),
          reason:
              'TS-10: the emitted target date must match the restored deadline',
        );
      },
    );

    test('SelfPacedGoalStep defaults initialGoal to null', () {
      final step = SelfPacedGoalStep(
        curriculumId: CurriculumId.mishnayos,
        studyDays: const {},
        onComplete: (_) {},
      );

      expect(step.initialGoal, isNull);
    });
  });
}
