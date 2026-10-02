// Mirror test for
// `lib/features/learner_state/presentation/providers/learner_state_composition.dart`
// (DNI-474 AC-1: complete inputs only, errors forwarded, recompute).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_composition.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';

/// The four input streams, driven by the test.
final class _Inputs {
  // Every controller is closed by [close] at teardown.
  // ignore: close_sinks
  final events = StreamController<CompleteRead<LearningEvent>>();
  // ignore: close_sinks
  final subTracks = StreamController<CompleteRead<SubTrack>>();
  // ignore: close_sinks
  final history = StreamController<CompleteRead<ChangeLogEntry>>();
  // ignore: close_sinks
  final intent = StreamController<LearnerIntent>();
  // ignore: close_sinks
  final ticks = StreamController<void>();
  final calendarCalls = <LearnerIntent>[];
  var now = engineAt(10000);
  StateError? calendarError;

  Stream<LearnerState> compose() => composeLearnerState(
    events: events.stream,
    subTracks: subTracks.stream,
    intentHistory: history.stream,
    intent: intent.stream,
    corpora: {engineCurriculum: mishnayosCorpus()},
    loadCalendars: (intent, settings, nowUtc) async {
      calendarCalls.add(intent);
      if (calendarError case final error?) throw error;
      return const <String, List<CalendarAssignment>>{};
    },
    nowUtc: () => now,
    recompute: ticks.stream,
  );

  void allReady({List<LearningEvent> learns = const []}) {
    events.add(CompleteReadReady(learns));
    subTracks.add(CompleteReadReady(const []));
    history.add(CompleteReadReady(const []));
    intent.add(_intent());
  }

  /// Not awaited: a controller nobody listened to never completes `done`.
  void close() {
    for (final c in [events, subTracks, history, intent, ticks]) {
      unawaited(c.close());
    }
  }
}

LearnerIntent _intent() => LearnerIntent(
  settings: c0Settings,
  mainTracks: {engineCurriculum: engineIntent()},
  goals: const {},
);

/// Collects every state and error the composition emits.
final class _Sink {
  _Sink(Stream<LearnerState> stream) {
    sub = stream.listen(states.add, onError: (Object e) => errors.add(e));
  }

  // Cancelled by each test's teardown.
  // ignore: cancel_subscriptions
  late final StreamSubscription<LearnerState> sub;
  final states = <LearnerState>[];
  final errors = <Object>[];
}

void main() {
  late _Inputs inputs;
  setUp(() => inputs = _Inputs());
  tearDown(() => inputs.close());

  _Sink listen() {
    final sink = _Sink(inputs.compose());
    addTearDown(sink.sub.cancel);
    return sink;
  }

  test('no state escapes while any source is still paging', () async {
    final sink = listen();
    inputs.events.add(const CompleteReadLoading());
    inputs.subTracks.add(CompleteReadReady(const []));
    inputs.history.add(const CompleteReadLoading());
    inputs.intent.add(_intent());
    await pumpEventQueue();
    expect(sink.states, isEmpty);

    // Events finish paging; the intent history is still paging.
    inputs.events.add(
      CompleteReadReady([engineLearn(1, 'Mishnah Berakhot 1:1')]),
    );
    await pumpEventQueue();
    expect(sink.states, isEmpty);

    inputs.history.add(CompleteReadReady(const []));
    await pumpEventQueue();
    expect(sink.states, hasLength(1));
    expect(sink.states.single[engineCurriculum]!.distinctLearnt, 1);
    expect(sink.errors, isEmpty);
  });

  test('emits the engine result over the complete inputs, once per '
      'change', () async {
    final sink = listen();
    final learns = [
      engineLearn(1, 'Mishnah Berakhot 1:1'),
      engineLearn(2, 'Mishnah Berakhot 1:1', minutes: 3),
    ];
    inputs.allReady(learns: learns);
    await pumpEventQueue();
    final expected = const LearnerStateEngine().run(
      engineInputs(events: learns, nowUtc: inputs.now),
    );
    expect(sink.states, hasLength(1));
    expect(
      sink.states.single[engineCurriculum]!.learntLeaves,
      expected[engineCurriculum]!.learntLeaves,
    );
    expect(sink.states.single.countedEventIds, expected.countedEventIds);
    expect(sink.states.single.nowUtc, inputs.now);

    inputs.events.add(
      CompleteReadReady([...learns, engineLearn(3, 'Mishnah Peah 1:1')]),
    );
    await pumpEventQueue();
    expect(sink.states, hasLength(2));
    expect(sink.states.last[engineCurriculum]!.distinctLearnt, 2);
  });

  test('a source that re-pages holds emissions until it is complete '
      'again', () async {
    final sink = listen();
    inputs.allReady();
    await pumpEventQueue();
    expect(sink.states, hasLength(1));

    inputs.events.add(const CompleteReadLoading());
    inputs.intent.add(_intent());
    await pumpEventQueue();
    expect(sink.states, hasLength(1), reason: 'events are re-paging');

    inputs.events.add(CompleteReadReady([engineLearn(1, 'Mishnah Peah 1:1')]));
    await pumpEventQueue();
    expect(sink.states, hasLength(2));
    expect(sink.states.last[engineCurriculum]!.distinctLearnt, 1);
  });

  test('undecodable event and sub-track rows are carried on '
      'rejectedRows', () async {
    final sink = listen();
    const bad = RejectedRow('bad-event', 'kind');
    const badTrack = RejectedRow('bad-track', 'name');
    inputs.events.add(CompleteReadReady(const [], rejected: const [bad]));
    inputs.subTracks.add(
      CompleteReadReady(const [], rejected: const [badTrack]),
    );
    inputs.history.add(CompleteReadReady(const []));
    inputs.intent.add(_intent());
    await pumpEventQueue();
    expect(sink.states.single.rejectedRows, [bad, badTrack]);
  });

  test('an undecodable intent-history row fails closed; a clean history '
      'recovers', () async {
    final sink = listen();
    inputs.events.add(CompleteReadReady(const []));
    inputs.subTracks.add(CompleteReadReady(const []));
    inputs.intent.add(_intent());
    inputs.history.add(
      CompleteReadReady(const [], rejected: const [RejectedRow('x', 'y')]),
    );
    await pumpEventQueue();
    expect(sink.states, isEmpty);
    expect(sink.errors.single, isA<UnreadableIntentHistoryException>());
    expect(sink.errors.single.toString(), contains('x'));

    inputs.history.add(CompleteReadReady(const []));
    await pumpEventQueue();
    expect(sink.states, hasLength(1));
  });

  test('an input error is forwarded and the next complete input '
      'recovers', () async {
    final sink = listen();
    inputs.allReady();
    await pumpEventQueue();
    inputs.events.addError(StateError('listener lost'));
    await pumpEventQueue();
    expect(sink.errors.single, isA<StateError>());

    inputs.events.add(CompleteReadReady(const []));
    await pumpEventQueue();
    expect(sink.states, hasLength(2));
  });

  test('calendars load once per intent; a load failure is an error and a '
      'new intent retries', () async {
    final sink = listen();
    inputs.allReady();
    await pumpEventQueue();
    inputs.events.add(CompleteReadReady(const []));
    await pumpEventQueue();
    expect(inputs.calendarCalls, hasLength(1), reason: 'same intent');
    expect(sink.states, hasLength(2));

    inputs.calendarError = StateError('calendar db');
    inputs.intent.add(_intent());
    await pumpEventQueue();
    expect(sink.errors.single, isA<StateError>());
    expect(sink.states, hasLength(2));

    inputs.calendarError = null;
    inputs.intent.add(_intent());
    await pumpEventQueue();
    expect(sink.states, hasLength(3));
  });

  test('a day tick recomputes at the new instant and reloads the '
      'calendars', () async {
    final sink = listen();
    inputs.allReady();
    await pumpEventQueue();
    inputs.now = engineAt(20000);
    inputs.ticks.add(null);
    await pumpEventQueue();
    expect(sink.states.map((s) => s.nowUtc), [
      engineAt(10000),
      engineAt(20000),
    ]);
    expect(inputs.calendarCalls, hasLength(2));
  });

  test('only touched curricula are passed to the engine', () async {
    final sink = _Sink(
      composeLearnerState(
        events: Stream.value(
          CompleteReadReady([engineLearn(1, 'Mishnah Berakhot 1:1')]),
        ),
        subTracks: Stream.value(CompleteReadReady(const [])),
        intentHistory: Stream.value(CompleteReadReady(const [])),
        intent: Stream.value(
          LearnerIntent(
            settings: c0Settings,
            mainTracks: const {},
            goals: const {},
          ),
        ),
        corpora: {
          engineCurriculum: mishnayosCorpus(),
          'bavli': mishnayosCorpus(),
        },
        loadCalendars: (_, _, _) async => const {},
        nowUtc: () => engineAt(10000),
      ),
    );
    addTearDown(sink.sub.cancel);
    await pumpEventQueue();
    expect(sink.states.single.curricula.keys, [engineCurriculum]);
  });

  test('the settings history comes from the intent settings and the '
      'intent history', () async {
    LearnerSettingsHistory? seen;
    final sink = _Sink(
      composeLearnerState(
        events: Stream.value(CompleteReadReady(const [])),
        subTracks: Stream.value(CompleteReadReady(const [])),
        intentHistory: Stream.value(CompleteReadReady(const [])),
        intent: Stream.value(_intent()),
        corpora: const {},
        loadCalendars: (_, settings, _) async {
          seen = settings;
          return const {};
        },
        nowUtc: () => engineAt(10000),
      ),
    );
    addTearDown(sink.sub.cancel);
    await pumpEventQueue();
    expect(
      seen,
      LearnerSettingsHistory.reconstruct(
        current: c0Settings,
        entries: const [],
      ),
    );
  });
}
