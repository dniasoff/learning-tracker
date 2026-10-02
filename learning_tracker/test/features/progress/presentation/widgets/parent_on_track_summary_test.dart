// Story 5.3 (DNI-518) AC-11: the Dashboard on-track summary paints only a
// settled learner state of the current learner. Riverpod retains the
// previous value through a reload or an error, so a profile switch, a
// session re-check, a reload or a failed read must hide the summary rather
// than show the previous (or a stale) learner's status, finish and target.
@Tags(['progress', 'lifetime', 'story_5_3'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/parent_on_track_summary.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/pump_app.dart';

final _now = DateTime.utc(2026, 10, 8, 12);

/// Mishnayos with four dated leaves since 2026-09-15 and a deadline on
/// [targetDate]: on track for a far deadline, behind pace for a near one.
LearnerState _deadline(String targetDate) => const LearnerStateEngine().run(
  engineInputs(
    nowUtc: _now,
    intents: {
      engineCurriculum: MainTrackIntent(
        curriculumId: engineCurriculum,
        track: MainTrack(
          curriculumId: engineCurriculum,
          state: MainTrackState.active,
        ),
        program: MainTrackProgram(
          curriculumId: engineCurriculum,
          trackingStartDate: '2026-09-01',
        ),
      ),
    },
    goals: {
      engineCurriculum: CurriculumGoals(
        deadline: DeadlineGoal(
          curriculumId: engineCurriculum,
          targetDate: targetDate,
        ),
      ),
    },
    events: [
      engineLearn(1, 'Mishnah Berakhot 1:1', learnedOn: '2026-09-15'),
      engineLearn(2, 'Mishnah Berakhot 1:2', learnedOn: '2026-09-22'),
      engineLearn(3, 'Mishnah Berakhot 1:3', learnedOn: '2026-09-29'),
      engineLearn(4, 'Mishnah Berakhot 2:1', learnedOn: '2026-10-06'),
    ],
  ),
);

/// Bumped to re-run a resolution (a PIN, profile or tutor change, or a
/// retry of the learner-state read).
final _epoch = NotifierProvider<_Epoch, int>(_Epoch.new);

class _Epoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final _summary = find.byKey(const ValueKey('dashboardOnTrackSummary'));

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<Override> overrides,
) async {
  final container = ProviderContainer(
    overrides: [
      effectiveUseHebrewTermsProvider.overrideWithValue(false),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    pumpApp(
      container: container,
      child: const SingleChildScrollView(
        child: ParentOnTrackSummary(curricula: [CurriculumId.mishnayos]),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  final onTrack = _deadline('2027-09-01');
  final behind = _deadline('2026-10-20');

  testWidgets('a settled parent read paints the summary', (tester) async {
    await _pump(tester, [
      parentSessionProvider.overrideWith((ref) async => true),
      activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
      learnerStateProvider.overrideWith((ref, _) => Stream.value(onTrack)),
    ]);
    expect(_summary, findsOneWidget);
    expect(find.text('On track'), findsOneWidget);
  });

  testWidgets('a profile switch never paints the previous learner\'s '
      'status, finish or target', (tester) async {
    final learnerA = c0Scope(ownerUid: 'owner-a');
    final learnerB = c0Scope(ownerUid: 'owner-b');
    final gate = Completer<LearnerScope>();
    var scopeBuilds = 0;
    final container = await _pump(tester, [
      parentSessionProvider.overrideWith((ref) async => true),
      activeLearnerScopeProvider.overrideWith((ref) async {
        ref.watch(_epoch);
        if (++scopeBuilds == 1) return learnerA;
        return gate.future;
      }),
      learnerStateProvider.overrideWith(
        (ref, scope) => Stream.value(scope == learnerA ? onTrack : behind),
      ),
    ]);
    expect(find.text('On track'), findsOneWidget);

    container.read(_epoch.notifier).bump();
    await tester.pump();
    await tester.pump();
    // The scope re-resolves while still retaining learner A.
    expect(container.read(activeLearnerScopeProvider).value, learnerA);
    expect(container.read(activeLearnerScopeProvider).isLoading, isTrue);
    expect(_summary, findsNothing);
    expect(find.text('On track'), findsNothing);

    gate.complete(learnerB);
    await tester.pumpAndSettle();
    expect(_summary, findsOneWidget);
    expect(find.text('Behind pace'), findsOneWidget);
    expect(find.text('On track'), findsNothing);
  });

  testWidgets('a parent session re-resolving hides the summary until it '
      'settles', (tester) async {
    final gate = Completer<bool>();
    var sessionBuilds = 0;
    final container = await _pump(tester, [
      parentSessionProvider.overrideWith((ref) async {
        ref.watch(_epoch);
        if (++sessionBuilds == 1) return true;
        return gate.future;
      }),
      activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
      learnerStateProvider.overrideWith((ref, _) => Stream.value(onTrack)),
    ]);
    expect(_summary, findsOneWidget);

    container.read(_epoch.notifier).bump();
    await tester.pump();
    await tester.pump();
    expect(container.read(parentSessionProvider).value, isTrue);
    expect(_summary, findsNothing);

    gate.complete(false);
    await tester.pumpAndSettle();
    expect(_summary, findsNothing);
  });

  testWidgets('a failed learner-state read hides the retained summary', (
    tester,
  ) async {
    final reads = StreamController<LearnerState>.broadcast();
    addTearDown(reads.close);
    final container = await _pump(tester, [
      parentSessionProvider.overrideWith((ref) async => true),
      activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
      learnerStateProvider.overrideWith((ref, _) async* {
        yield onTrack;
        yield* reads.stream;
      }),
    ]);
    expect(find.text('On track'), findsOneWidget);

    reads.addError(StateError('read failed'));
    await tester.pumpAndSettle();
    final state = container.read(activeLearnerStateProvider);
    expect(state.hasError, isTrue);
    // Riverpod still retains the previous learner state.
    expect(state.value, isNotNull);
    expect(_summary, findsNothing);
    expect(find.text('On track'), findsNothing);
  });

  testWidgets('a retry hides the summary until the fresh read lands', (
    tester,
  ) async {
    final fresh = Completer<LearnerState>();
    var reads = 0;
    final container = await _pump(tester, [
      parentSessionProvider.overrideWith((ref) async => true),
      activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
      learnerStateProvider.overrideWith((ref, _) {
        ref.watch(_epoch);
        return ++reads == 1
            ? Stream.value(onTrack)
            : Stream.fromFuture(fresh.future);
      }),
    ]);
    expect(find.text('On track'), findsOneWidget);

    container.read(_epoch.notifier).bump();
    await tester.pump();
    await tester.pump();
    final state = container.read(activeLearnerStateProvider);
    expect(state.isLoading, isTrue);
    expect(state.value, isNotNull);
    expect(_summary, findsNothing);

    fresh.complete(behind);
    await tester.pumpAndSettle();
    expect(find.text('Behind pace'), findsOneWidget);
  });
}
