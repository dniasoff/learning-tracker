// Story 5.3 (DNI-518) AC-9, AC-10: the pace provider selects the report's
// curriculum state from the one shared learner state, follows the
// report's loading and error, and builds nothing outside a parent session.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/pace_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/providers/per_source_pace_report_provider.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/provider_settle.dart';
import '../../../../helpers/progress/lifetime_report_fixtures.dart';
import '../../../../helpers/progress/pace_report_fixtures.dart';

({ProviderContainer container, StreamController<LearnerState> stream})
_harness({bool parent = true}) {
  final stream = StreamController<LearnerState>.broadcast();
  final container = ProviderContainer(
    overrides: [
      parentSessionProvider.overrideWith((ref) async => parent),
      activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
      learnerStateProvider.overrideWith((ref, _) => stream.stream),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(stream.close);
  return (container: container, stream: stream);
}

void main() {
  test('loading until the learner state is complete', () async {
    final h = _harness();
    final value = await settledAsync(
      h.container,
      perSourcePaceReportProvider(null),
      maxTurns: 3,
    );
    expect(value, isA<AsyncLoading<PaceReportView?>>());
  });

  test('the selected curriculum\'s engine state, unchanged', () async {
    final h = _harness();
    final sub = h.container.listen(
      perSourcePaceReportProvider(reportCurriculum),
      (_, _) {},
    );
    addTearDown(sub.close);
    await pumpEventQueue();
    final report = paceReport();
    h.stream.add(
      paceState([
        paceCurriculumState(report, dailyTarget: 4),
        paceCurriculumState(
          paceReport(curriculumId: reportRetiredCurriculum),
          dailyTarget: 9,
        ),
      ]),
    );
    await pumpEventQueue();
    final view = sub.read().requireValue!;
    expect(view.curriculumId, reportCurriculum);
    expect(view.onTrack!.dailyTarget, 4);
    expect(view.rows, hasLength(3));
  });

  test('a retired curriculum gives no pace view (AC-9)', () async {
    final h = _harness();
    final sub = h.container.listen(
      perSourcePaceReportProvider(reportCurriculum),
      (_, _) {},
    );
    addTearDown(sub.close);
    await pumpEventQueue();
    h.stream.add(
      paceState([paceCurriculumState(paceReport(), evaluated: false)]),
    );
    await pumpEventQueue();
    expect(sub.read().hasValue, isTrue);
    expect(sub.read().value, isNull);
  });

  test('a load error is the report\'s error', () async {
    final h = _harness();
    final sub = h.container.listen(
      perSourcePaceReportProvider(null),
      (_, _) {},
    );
    addTearDown(sub.close);
    await pumpEventQueue();
    h.stream.addError(StateError('page 2 failed'));
    await pumpEventQueue();
    expect(sub.read().hasError, isTrue);
    expect(sub.read().hasValue, isFalse);
  });

  test('outside a parent session: access denied, no state read '
      '(AC-10)', () async {
    var reads = 0;
    final container = ProviderContainer(
      overrides: [
        parentSessionProvider.overrideWith((ref) async => false),
        activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
        learnerStateProvider.overrideWith((ref, _) {
          reads++;
          return Stream.value(paceState([paceCurriculumState(paceReport())]));
        }),
      ],
    );
    addTearDown(container.dispose);
    final value = await settledAsync(
      container,
      perSourcePaceReportProvider(reportCurriculum),
    );
    expect(value.error, isA<LifetimeReportAccessDenied>());
    expect(value.hasValue, isFalse);
    expect(reads, 0);
  });
}
