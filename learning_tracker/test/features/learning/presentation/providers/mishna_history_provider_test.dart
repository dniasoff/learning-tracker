/// DNI-475 (Story 1.13) AC-1 / AC-2 unit level: the Mishna-history read
/// model and its correction controller, against the C0 fakes and fixed
/// engine fixtures. TQ-6: fixed instants only.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/models/mishna_history_item.dart';
import 'package:learning_tracker/features/learning/domain/models/profile_history_log.dart';
import 'package:learning_tracker/features/learning/presentation/providers/mishna_history_provider.dart';

import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/mishna_history_fixtures.dart';
import '../../../../helpers/learner_state/provider_settle.dart';
import '../../../../helpers/learner_state_fixtures.dart';

ProviderContainer _container(
  HistoryPorts ports, {
  required Set<String> counted,
  Set<String> lockIgnored = const {},
  bool learnt = true,
  LearningCommands? commands,
}) {
  final container = ProviderContainer(
    overrides: historyOverrides(
      ports,
      state: historyState(
        learnt: learnt,
        counted: counted,
        lockIgnored: lockIgnored,
      ),
      commands: commands,
    ),
  );
  addTearDown(container.dispose);
  return container;
}

/// Settles the history and keeps the rendered view (history plus
/// correction overlays) alive, as the screen does.
Future<MishnaHistory> _history(ProviderContainer container) async {
  final view = container.listen(
    mishnaHistoryViewProvider(historyArgs),
    (_, _) {},
  );
  addTearDown(view.close);
  return (await settledAsync(
    container,
    mishnaHistoryProvider(historyArgs),
  )).requireValue;
}

MishnaHistory _project(
  List<LearningEvent> events, {
  required Set<String> counted,
  Set<String> lockIgnored = const {},
  bool learnt = true,
}) => MishnaHistory.project(
  curriculumId: historyCurriculum,
  leafRef: historyLeaf,
  log: ProfileHistoryLog(events: events, subTracks: const []),
  state: historyState(
    learnt: learnt,
    counted: counted,
    lockIgnored: lockIgnored,
  ),
  corpus: historyCorpus(),
);

void main() {
  late HistoryPorts ports;
  setUp(() => ports = HistoryPorts());
  tearDown(() => ports.dispose());

  group('AC-1 complete paged event load and deleted source', () {
    test('an ended sub-track source shows its stored name although no live '
        'track has that id; Home stays Home', () async {
      ports.events.seed(ports.scope, [
        historyLearn(1, source: ulidB),
        historyLearn(2, day: 3),
      ]);
      ports.tracks.seed(ports.scope, [endedSubTrack()]);
      final history = await _history(
        _container(ports, counted: {eid(1), eid(2)}),
      );

      final byId = {for (final i in history.items) i.eventId: i};
      expect(byId[eid(1)]!.sourceKind, MishnaHistorySourceKind.subTrack);
      expect(byId[eid(1)]!.sourceName, 'Cheder shiur');
      expect(byId[eid(1)]!.sourceEnded, isTrue);
      expect(byId[eid(2)]!.sourceKind, MishnaHistorySourceKind.home);
    });

    test('a source missing from the complete read is labelled generically, '
        'never with its ULID', () async {
      ports.events.seed(ports.scope, [historyLearn(1, source: ulidD)]);
      final history = await _history(_container(ports, counted: {eid(1)}));
      final item = history.items.single;
      expect(item.sourceKind, MishnaHistorySourceKind.unknownSubTrack);
      expect(item.sourceName, isNull);
    });

    test('stays loading until the engine state is available (no partial '
        'history)', () async {
      ports.events.seed(ports.scope, [historyLearn(1)]);
      final container = ProviderContainer(
        overrides: [
          ...historyOverrides(ports, state: null),
          learnerStateProvider.overrideWith((ref, _) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      final value = await settledAsync(
        container,
        mishnaHistoryProvider(historyArgs),
      );
      expect(value.isLoading, isTrue);
      expect(value.hasValue, isFalse);
    });

    test('an input failure surfaces as an error (retryable)', () async {
      final container = ProviderContainer(
        overrides: [
          ...historyOverrides(ports, state: null),
          learnerStateProvider.overrideWith(
            (ref, _) => Stream.error(StateError('engine input failed')),
          ),
        ],
      );
      addTearDown(container.dispose);
      final value = await settledAsync(
        container,
        mishnaHistoryProvider(historyArgs),
      );
      expect(value.error, isA<StateError>());
    });

    test('rows of other leaves and curricula never appear', () async {
      ports.events.seed(ports.scope, [
        historyLearn(1),
        historyLearn(2, ref: historySibling),
      ]);
      final history = await _history(
        _container(ports, counted: {eid(1), eid(2)}),
      );
      expect(history.items.map((i) => i.eventId), [eid(1)]);
    });
  });

  group('AC-1/AC-2 repeated and voided event counting', () {
    test('every non-voided repeat counts; a void removes its target; '
        'newest first with derived chazara on later repeats', () {
      final history = _project(
        [
          historyLearn(1, day: 1),
          historyLearn(2, day: 5),
          historyLearn(3, day: 9),
          historyVoid(4, eid(2)),
        ],
        counted: {eid(1), eid(3)},
      );

      expect(history.learnt, isTrue);
      expect(history.eventCount, 2);
      expect(history.items.map((i) => i.eventId), [eid(3), eid(2), eid(1)]);
      final byId = {for (final i in history.items) i.eventId: i};
      expect(byId[eid(2)]!.status, MishnaHistoryStatus.voided);
      expect(byId[eid(1)]!.ordinal, 1);
      expect(byId[eid(1)]!.isChazara, isFalse);
      expect(byId[eid(3)]!.ordinal, 2);
      expect(byId[eid(3)]!.isChazara, isTrue);
    });

    test('a void of a void has no effect on the count', () {
      final history = _project(
        [historyLearn(1), historyVoid(2, eid(3)), historyVoid(3, eid(4))],
        counted: {eid(1)},
      );
      expect(history.eventCount, 1);
      expect(history.items.single.status, MishnaHistoryStatus.counted);
    });

    test('Learnt follows the engine, never a screen-local recomputation', () {
      final history = _project(
        [historyLearn(1)],
        counted: {eid(1)},
        learnt: false,
      );
      expect(history.learnt, isFalse);
      expect(history.visibleTo(MishnaHistoryViewer.parent), isEmpty);
    });

    test('identical instants order by event id (stable tie-break)', () {
      final history = _project(
        [historyLearn(7, day: 2), historyLearn(5, day: 2)],
        counted: {eid(5), eid(7)},
      );
      expect(history.items.map((i) => i.eventId), [eid(7), eid(5)]);
      expect(history.items.last.ordinal, 1);
    });

    test('a Before-tracking node event covering the leaf is part of its '
        'history; place choices are the leaf\'s siblings', () {
      final history = _project(
        [
          historyLearn(
            1,
            ref: historyMasechta.ref,
            level: historyMasechta.level,
            dateState: DateState.beforeTracking,
          ),
        ],
        counted: {eid(1)},
      );
      final item = history.items.single;
      expect(item.isNodeEvent, isTrue);
      expect(item.isBeforeTracking, isTrue);
      expect(history.placeChoices, [historySibling]);
    });

    test('child mode hides voided rows; parent sees them', () {
      final history = _project(
        [historyLearn(1), historyLearn(2, day: 4), historyVoid(3, eid(1))],
        counted: {eid(2)},
      );
      expect(
        history.visibleTo(MishnaHistoryViewer.child).map((i) => i.eventId),
        [eid(2)],
      );
      expect(history.visibleTo(MishnaHistoryViewer.parent), hasLength(2));
    });
  });

  group('AC-1 lock-ignored events', () {
    test(
      'a learn neither voided nor counted is lock-ignored (engine '
      'countedEventIds; no second lock calculation) and offers no action',
      () {
        final history = _project(
          [historyLearn(1), historyLearn(2, day: 6)],
          counted: {eid(1)},
        );
        final ignored = history.items.firstWhere((i) => i.eventId == eid(2));
        expect(ignored.status, MishnaHistoryStatus.lockIgnored);
        expect(ignored.ordinal, isNull);
        expect(ignored.isChazara, isFalse);
        for (final viewer in MishnaHistoryViewer.values) {
          expect(allowedCorrections(ignored, viewer), isEmpty);
        }
      },
    );

    test('a counted event plus a lock-ignored event count 2 (FR-30: every '
        'non-voided event); only the counted one gets an ordinal', () {
      final history = _project(
        [historyLearn(1), historyLearn(2, day: 6), historyVoid(3, eid(4))],
        counted: {eid(1)},
        lockIgnored: {eid(2)},
      );
      expect(history.eventCount, 2);
      final byId = {for (final i in history.items) i.eventId: i};
      expect(byId[eid(1)]!.ordinal, 1);
      expect(byId[eid(2)]!.status, MishnaHistoryStatus.lockIgnored);
      expect(byId[eid(2)]!.ordinal, isNull);
    });

    test('a voided lock-ignored event leaves the count', () {
      final history = _project(
        [historyLearn(1), historyLearn(2, day: 6), historyVoid(3, eid(2))],
        counted: {eid(1)},
        lockIgnored: {eid(2)},
      );
      expect(history.eventCount, 1);
    });

    test('the engine lockIgnoredEventIds wins over a stale counted id', () {
      final history = _project(
        [historyLearn(1)],
        counted: {eid(1)},
        lockIgnored: {eid(1)},
      );
      expect(history.items.single.status, MishnaHistoryStatus.lockIgnored);
    });
  });

  group('AC-2 invalid and boundary correction targets', () {
    final dated = MishnaHistoryItem(
      event: historyLearn(1),
      status: MishnaHistoryStatus.counted,
      sourceKind: MishnaHistorySourceKind.home,
      ordinal: 1,
    );

    test('an old child event allows removal only', () {
      expect(allowedCorrections(dated, MishnaHistoryViewer.child), {
        MishnaCorrection.remove,
      });
    });

    test('a child may re-date a catch-up event (the command enforces its '
        'catch-up window)', () {
      final catchUp = MishnaHistoryItem(
        event: historyLearn(1, dateState: DateState.catchUp),
        status: MishnaHistoryStatus.counted,
        sourceKind: MishnaHistorySourceKind.home,
      );
      expect(allowedCorrections(catchUp, MishnaHistoryViewer.child), {
        MishnaCorrection.remove,
        MishnaCorrection.changeDate,
      });
    });

    test('a parent has no child re-date limit', () {
      expect(
        allowedCorrections(
          dated,
          MishnaHistoryViewer.parent,
          hasPlaceChoices: true,
        ),
        MishnaCorrection.values.toSet(),
      );
    });

    test('voided, node and in-flight rows, and tutors, get no action', () {
      expect(
        allowedCorrections(
          dated.copyWith(status: MishnaHistoryStatus.voided),
          MishnaHistoryViewer.parent,
        ),
        isEmpty,
      );
      expect(
        allowedCorrections(
          dated.copyWith(pending: true),
          MishnaHistoryViewer.parent,
        ),
        isEmpty,
      );
      expect(allowedCorrections(dated, MishnaHistoryViewer.tutor), isEmpty);
      final node = MishnaHistoryItem(
        event: historyLearn(
          2,
          ref: historyMasechta.ref,
          level: historyMasechta.level,
          dateState: DateState.beforeTracking,
        ),
        status: MishnaHistoryStatus.counted,
        sourceKind: MishnaHistorySourceKind.home,
      );
      expect(allowedCorrections(node, MishnaHistoryViewer.parent), isEmpty);
    });
  });

  group('AC-2 remove and correct through LearningCommands', () {
    test('removal calls voidEvent and keeps the optimistic row until new '
        'data lands', () async {
      ports.events.seed(ports.scope, [historyLearn(1)]);
      final fake = FakeLearningCommands();
      final container = _container(ports, counted: {eid(1)}, commands: fake);
      final history = await _history(container);

      final outcome = await container
          .read(mishnaHistoryCorrectionsProvider(historyArgs).notifier)
          .correct(history.items.single, const RemoveEventRequest());

      expect(outcome, MishnaCorrectionOutcome.applied);
      expect(fake.calls, [
        LearningCommandCall('voidEvent', {'targetId': eid(1)}),
      ]);
      final view = container
          .read(mishnaHistoryViewProvider(historyArgs))
          .requireValue;
      expect(view.items.single.status, MishnaHistoryStatus.voided);
      expect(view.items.single.pending, isTrue);
    });

    test('the confirmed overlay clears once the new log lands; the row then '
        'reads from the data', () async {
      ports.events.seed(ports.scope, [historyLearn(1)]);
      final container = _container(
        ports,
        counted: {eid(1)},
        commands: FakeLearningCommands(),
      );
      final history = await _history(container);
      await container
          .read(mishnaHistoryCorrectionsProvider(historyArgs).notifier)
          .correct(history.items.single, const RemoveEventRequest());

      ports.events.seed(ports.scope, [historyVoid(2, eid(1))]);
      await pumpEventQueue();

      expect(
        container.read(mishnaHistoryCorrectionsProvider(historyArgs)),
        isEmpty,
      );
      final view = container
          .read(mishnaHistoryViewProvider(historyArgs))
          .requireValue;
      expect(view.items.single.status, MishnaHistoryStatus.voided);
      expect(view.items.single.pending, isFalse);
      expect(view.eventCount, 0);
    });

    test('a date correction calls replace with the new learned_on', () async {
      ports.events.seed(ports.scope, [historyLearn(1)]);
      final fake = FakeLearningCommands();
      final container = _container(ports, counted: {eid(1)}, commands: fake);
      final history = await _history(container);
      const replacement = EventReplacement(learnedOn: '2026-08-30');

      await container
          .read(mishnaHistoryCorrectionsProvider(historyArgs).notifier)
          .correct(
            history.items.single,
            const ReplaceEventRequest(replacement),
          );

      expect(fake.calls, [
        LearningCommandCall('replace', {
          'targetId': eid(1),
          'replacement': replacement,
        }),
      ]);
    });

    for (final (label, result) in <(String, CaptureResult)>[
      (
        'voidTargetNotLearn',
        const CaptureResult.rejected(CaptureRejection.voidTargetNotLearn),
      ),
      (
        'lockIgnoredTarget',
        const CaptureResult.rejected(CaptureRejection.lockIgnoredTarget),
      ),
      (
        'targetNotFound',
        const CaptureResult.rejected(CaptureRejection.targetNotFound),
      ),
      ('onlineRequired', const CaptureResult.onlineRequired()),
    ]) {
      test('a rejected write ($label) restores the original row before the '
          'outcome is returned', () async {
        ports.events.seed(ports.scope, [historyLearn(1)]);
        final fake = FakeLearningCommands()..nextResult = result;
        final container = _container(ports, counted: {eid(1)}, commands: fake);
        final history = await _history(container);
        final original = history.items.single;

        final outcome = await container
            .read(mishnaHistoryCorrectionsProvider(historyArgs).notifier)
            .correct(original, const RemoveEventRequest());

        expect(outcome, MishnaCorrectionOutcome.rolledBack);
        final view = container
            .read(mishnaHistoryViewProvider(historyArgs))
            .requireValue;
        expect(view.items.single, same(original));
        expect(view.eventCount, 1);
      });
    }

    test('a child re-date outside the catch-up window comes back as '
        'childLimit and rolls back', () async {
      ports.events.seed(ports.scope, [
        historyLearn(1, dateState: DateState.catchUp),
      ]);
      final fake = FakeLearningCommands()
        ..nextResult = const CaptureResult.childLimit();
      final container = _container(ports, counted: {eid(1)}, commands: fake);
      final history = await _history(container);

      final outcome = await container
          .read(mishnaHistoryCorrectionsProvider(historyArgs).notifier)
          .correct(
            history.items.single,
            const ReplaceEventRequest(
              EventReplacement(learnedOn: '2026-08-29'),
            ),
          );

      expect(outcome, MishnaCorrectionOutcome.childLimit);
      expect(
        container.read(mishnaHistoryCorrectionsProvider(historyArgs)),
        isEmpty,
      );
    });

    test('a command that throws rolls back too', () async {
      ports.events.seed(ports.scope, [historyLearn(1)]);
      final container = ProviderContainer(
        overrides: historyOverrides(
          ports,
          state: historyState(counted: {eid(1)}),
        ),
      );
      addTearDown(container.dispose);
      final history = await _history(container);
      // learningCommandsProvider is left as its C0 stub: it throws.
      final outcome = await container
          .read(mishnaHistoryCorrectionsProvider(historyArgs).notifier)
          .correct(history.items.single, const RemoveEventRequest());
      expect(outcome, MishnaCorrectionOutcome.rolledBack);
    });

    test('in flight, a source change shows its new values', () async {
      ports.events.seed(ports.scope, [historyLearn(1, source: ulidB)]);
      ports.tracks.seed(ports.scope, [endedSubTrack()]);
      final gated = GatedLearningCommands(FakeLearningCommands());
      final container = _container(ports, counted: {eid(1)}, commands: gated);
      final history = await _history(container);

      final pending = container
          .read(mishnaHistoryCorrectionsProvider(historyArgs).notifier)
          .correct(
            history.items.single,
            const ReplaceEventRequest(
              EventReplacement(source: LearningEvent.sourceMain),
            ),
          );
      await pumpEventQueue();
      final view = container
          .read(mishnaHistoryViewProvider(historyArgs))
          .requireValue;
      expect(view.items.single.sourceKind, MishnaHistorySourceKind.home);
      expect(view.items.single.pending, isTrue);

      gated.release();
      expect(await pending, MishnaCorrectionOutcome.applied);
    });
  });
}
