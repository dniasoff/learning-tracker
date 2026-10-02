// Story 5.2 (DNI-517) AC-2, AC-9, AC-10, AC-11: the report provider reads
// the one shared, complete learner state; it is loading until the engine
// has every page, follows live updates, retries the whole input chain and
// builds nothing outside a parent session.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_view.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/provider_settle.dart';
import '../../../../helpers/progress/lifetime_report_fixtures.dart';

/// A container whose learner state comes from [states] (one stream per
/// build, so a retry gets a fresh one) and whose session is [parent].
({ProviderContainer container, List<StreamController<LearnerState>> streams})
_harness({bool parent = true, LearnerScope? scope}) {
  final streams = <StreamController<LearnerState>>[];
  final container = ProviderContainer(
    overrides: [
      parentSessionProvider.overrideWith((ref) async => parent),
      activeLearnerScopeProvider.overrideWith(
        (ref) async => scope ?? c0Scope(),
      ),
      learnerStateProvider.overrideWith((ref, _) {
        final controller = StreamController<LearnerState>();
        streams.add(controller);
        ref.onDispose(controller.close);
        return controller.stream;
      }),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, streams: streams);
}

void main() {
  test('loading until the engine emits a complete state, never a partial '
      'or zero report (AC-10)', () async {
    final h = _harness();
    final value = await settledAsync(
      h.container,
      lifetimeReportProvider(null),
      maxTurns: 3,
    );
    expect(value, isA<AsyncLoading<LifetimeReportView>>());
    expect(value.hasValue, isFalse);
  });

  test('renders the complete state once it arrives, then follows live '
      'updates after the goal is reached (AC-11)', () async {
    final h = _harness();
    final sub = h.container.listen(lifetimeReportProvider(null), (_, _) {});
    addTearDown(sub.close);
    await pumpEventQueue();
    h.streams.single.add(reportState([homeOnlyReport(events: 12)]));
    await pumpEventQueue();
    expect(sub.read().requireValue.report.totalEvents, 17);

    // A new counted event after the goal: the engine re-emits the state.
    h.streams.single.add(reportState([homeOnlyReport(events: 13)]));
    await pumpEventQueue();
    expect(sub.read().requireValue.report.totalEvents, 18);
  });

  test('a load error surfaces as an error; retry re-reads the whole input '
      'chain and recovers (AC-10)', () async {
    final h = _harness();
    final sub = h.container.listen(lifetimeReportProvider(null), (_, _) {});
    addTearDown(sub.close);
    await pumpEventQueue();
    h.streams.single.addError(StateError('page 3 failed'));
    await pumpEventQueue();
    expect(sub.read().hasError, isTrue);
    expect(sub.read().hasValue, isFalse);

    // retryLifetimeReport invalidates these same providers.
    h.container
      ..invalidate(parentSessionProvider)
      ..invalidate(activeLearnerScopeProvider)
      ..invalidate(learnerStateProvider)
      ..invalidate(corporaProvider);
    await pumpEventQueue();
    // The session and scope re-resolve first (the report fails closed
    // meanwhile), so the read may be re-opened; the live one is fresh.
    expect(
      h.streams.length,
      greaterThanOrEqualTo(2),
      reason: 'a fresh complete read',
    );
    expect(sub.read().isLoading, isTrue);
    h.streams.last.add(reportState([fullReport()]));
    await pumpEventQueue();
    expect(sub.read().requireValue.report.totalEvents, 2040);
  });

  test('builds nothing outside a parent session (AC-2)', () async {
    final h = _harness(parent: false);
    final value = await settledAsync(h.container, lifetimeReportProvider(null));
    expect(value.error, isA<LifetimeReportAccessDenied>());
    expect(h.streams, isEmpty, reason: 'the learner state is never read');
  });

  group('fails closed while the identity re-resolves (AC-2)', () {
    test('a parent session re-resolving with its earlier true retained '
        'shows nothing of the report', () async {
      final gate = Completer<bool>();
      var sessionBuilds = 0;
      final container = ProviderContainer(
        overrides: [
          parentSessionProvider.overrideWith((ref) async {
            if (++sessionBuilds == 1) return true;
            return gate.future;
          }),
          activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
          learnerStateProvider.overrideWith(
            (ref, _) => Stream.value(reportState([fullReport()])),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(lifetimeReportProvider(null), (_, _) {});
      addTearDown(sub.close);
      await pumpEventQueue();
      expect(sub.read().requireValue.report.totalEvents, 2040);

      // A PIN lock or profile switch re-runs the session check.
      container.invalidate(parentSessionProvider);
      await pumpEventQueue();
      expect(container.read(parentSessionProvider).value, isTrue);
      expect(sub.read().isLoading, isTrue);
      expect(sub.read().hasValue, isFalse);

      gate.complete(false);
      await pumpEventQueue();
      expect(sub.read().error, isA<LifetimeReportAccessDenied>());
    });

    test('a learner switch never shows the previous learner\'s report '
        'before the new scope settles', () async {
      final learnerA = c0Scope(ownerUid: 'owner-a');
      final learnerB = c0Scope(ownerUid: 'owner-b');
      final gate = Completer<LearnerScope>();
      var scopeBuilds = 0;
      final container = ProviderContainer(
        overrides: [
          parentSessionProvider.overrideWith((ref) async => true),
          activeLearnerScopeProvider.overrideWith((ref) async {
            if (++scopeBuilds == 1) return learnerA;
            return gate.future;
          }),
          learnerStateProvider.overrideWith(
            (ref, scope) => Stream.value(
              reportState([
                if (scope == learnerA)
                  fullReport()
                else
                  homeOnlyReport(events: 3, withBeforeTracking: false),
              ]),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(lifetimeReportProvider(null), (_, _) {});
      addTearDown(sub.close);
      await pumpEventQueue();
      expect(sub.read().requireValue.report.totalEvents, 2040);

      container.invalidate(activeLearnerScopeProvider);
      await pumpEventQueue();
      // The scope still retains learner A while it re-resolves.
      expect(container.read(activeLearnerScopeProvider).value, learnerA);
      expect(sub.read().isLoading, isTrue);
      expect(sub.read().hasValue, isFalse);

      gate.complete(learnerB);
      await pumpEventQueue();
      expect(sub.read().requireValue.report.totalEvents, 3);
    });
  });

  group('curriculum selection (AC-9)', () {
    Future<LifetimeReportView> viewFor(
      String? requested,
      LearnerState state,
    ) async {
      final h = _harness();
      final sub = h.container.listen(
        lifetimeReportProvider(requested),
        (_, _) {},
      );
      addTearDown(sub.close);
      await pumpEventQueue();
      h.streams.single.add(state);
      await pumpEventQueue();
      return sub.read().requireValue;
    }

    final twoCurricula = reportState([
      fullReport(),
      homeOnlyReport(
        curriculumId: reportRetiredCurriculum,
        events: 30,
        distinct: 25,
        withBeforeTracking: false,
      ),
    ]);

    test(
      'defaults to the first curriculum with events, in app order',
      () async {
        final view = await viewFor(null, twoCurricula);
        expect(view.curricula, [reportRetiredCurriculum, reportCurriculum]);
        expect(view.curriculumId, reportRetiredCurriculum);
      },
    );

    test('each curriculum shows only its own projection, the retired one '
        'included', () async {
      final mishnayos = await viewFor(reportCurriculum, twoCurricula);
      expect(mishnayos.report.totalEvents, 2040);
      final retired = await viewFor(reportRetiredCurriculum, twoCurricula);
      expect(retired.report.totalEvents, 30);
      expect(retired.report.curriculumId, reportRetiredCurriculum);
    });

    test(
      'a curriculum with no state reads as the empty projection (AC-8)',
      () async {
        final view = await viewFor('bavli', twoCurricula);
        expect(view.isEmpty, isTrue);
        expect(view.report.distinctLearnt, 0);
        expect(view.curricula, contains('bavli'));
      },
    );
  });
}
