/// DNI-475 T1 (AC-1, AC-2): the Mishna-history source joins the complete
/// `learning_events` and `sub_tracks` reads and never publishes a partial
/// log; tombstoned sub-tracks keep their stored name. TQ-6: fixed instants.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/data/repositories/profile_history_log_source.dart';
import 'package:learning_tracker/features/learning/domain/models/profile_history_log.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state/provider_settle.dart';
import '../../../../helpers/learner_state_fixtures.dart';

LearningEvent _learn(String id, {String source = LearningEvent.sourceMain}) =>
    LearningEvent.learn(
      id: id,
      curriculumId: 'mishnayos',
      ref: 'Mishnah Berakhot 1:1',
      source: source,
      dateState: DateState.dated,
      learnedOn: '2026-09-01',
      recordedAt: t0,
      actor: parentActor,
    );

SubTrack _ended(String id) {
  final live = c0SubTrack(id: id);
  return SubTrack(
    id: live.id,
    curriculumId: live.curriculumId,
    name: 'Cheder shiur',
    type: live.type,
    windowStart: live.windowStart,
    ratePerWeek: live.ratePerWeek,
    weeksPerYear: live.weeksPerYear,
    learnsOnShabbos: live.learnsOnShabbos,
    ground: live.ground,
    lastChangeId: live.lastChangeId,
    endedAt: t1,
    endReason: SubTrackEndReason.deleted,
  );
}

(
  StreamController<CompleteRead<LearningEvent>>,
  StreamController<CompleteRead<SubTrack>>,
)
_controllers() {
  final events = StreamController<CompleteRead<LearningEvent>>();
  final tracks = StreamController<CompleteRead<SubTrack>>();
  addTearDown(events.close);
  addTearDown(tracks.close);
  return (events, tracks);
}

void main() {
  group('joinCompleteHistoryReads', () {
    test('publishes nothing until BOTH reads are complete', () async {
      final (events, tracks) = _controllers();
      final out = <ProfileHistoryLog>[];
      final sub = joinCompleteHistoryReads(
        events.stream,
        tracks.stream,
      ).listen(out.add);
      addTearDown(sub.cancel);

      events
        ..add(const CompleteReadLoading())
        ..add(CompleteReadReady([_learn(ulidA)]));
      tracks.add(const CompleteReadLoading());
      await pumpEventQueue();
      expect(out, isEmpty, reason: 'sub-tracks still paging');

      tracks.add(CompleteReadReady([_ended(ulidB)]));
      await pumpEventQueue();
      expect(out, hasLength(1));
      expect(out.single.events.map((e) => e.id), [ulidA]);
      expect(out.single.subTrackName(ulidB), 'Cheder shiur');
    });

    test('a later loading emission never replaces the last complete log; '
        'the next complete list republishes', () async {
      final (events, tracks) = _controllers();
      final out = <ProfileHistoryLog>[];
      final sub = joinCompleteHistoryReads(
        events.stream,
        tracks.stream,
      ).listen(out.add);
      addTearDown(sub.cancel);

      events.add(CompleteReadReady([_learn(ulidA)]));
      tracks.add(CompleteReadReady(const []));
      await pumpEventQueue();
      events
        ..add(const CompleteReadLoading())
        ..add(CompleteReadReady([_learn(ulidA), _learn(ulidC)]));
      await pumpEventQueue();

      expect(out.map((l) => l.events.length), [1, 2]);
    });

    test('a listener failure is forwarded as an error (retryable), never '
        'an empty or relabelled log', () async {
      final (events, tracks) = _controllers();
      final errors = <Object>[];
      final sub = joinCompleteHistoryReads(
        events.stream,
        tracks.stream,
      ).listen((_) {}, onError: errors.add);
      addTearDown(sub.cancel);

      tracks.addError(StateError('permission-denied'));
      await pumpEventQueue();
      expect(errors, [isA<StateError>()]);
    });

    test('a malformed event row fails the read: no log is published, the '
        'error keeps the rejected id and decode error', () async {
      final (events, tracks) = _controllers();
      final out = <ProfileHistoryLog>[];
      final errors = <Object>[];
      final sub = joinCompleteHistoryReads(
        events.stream,
        tracks.stream,
      ).listen(out.add, onError: errors.add);
      addTearDown(sub.cancel);

      final decodeError = StateError('bad kind');
      events.add(
        CompleteReadReady(
          [_learn(ulidA)],
          rejected: [RejectedRow(ulidD, decodeError)],
        ),
      );
      tracks.add(CompleteReadReady([_ended(ulidB)]));
      await pumpEventQueue();

      expect(out, isEmpty, reason: 'no partial history');
      final error = errors.single as UnreadableHistoryException;
      expect(error.eventRows.single.docId, ulidD);
      expect(error.eventRows.single.error, same(decodeError));
      expect(error.subTrackRows, isEmpty);
    });

    test('a malformed sub-track row fails the read: no log is published, '
        'never an unknown-source relabel', () async {
      final (events, tracks) = _controllers();
      final out = <ProfileHistoryLog>[];
      final errors = <Object>[];
      final sub = joinCompleteHistoryReads(
        events.stream,
        tracks.stream,
      ).listen(out.add, onError: errors.add);
      addTearDown(sub.cancel);

      events.add(CompleteReadReady([_learn(ulidA, source: ulidB)]));
      tracks.add(
        CompleteReadReady(
          const [],
          rejected: const [RejectedRow(ulidB, 'bad name')],
        ),
      );
      await pumpEventQueue();

      expect(out, isEmpty, reason: 'no partial history');
      final error = errors.single as UnreadableHistoryException;
      expect(error.subTrackRows.single.docId, ulidB);
      expect(error.eventRows, isEmpty);
    });

    test('once the rows read cleanly again, the next complete pair '
        'publishes', () async {
      final (events, tracks) = _controllers();
      final out = <ProfileHistoryLog>[];
      final errors = <Object>[];
      final sub = joinCompleteHistoryReads(
        events.stream,
        tracks.stream,
      ).listen(out.add, onError: errors.add);
      addTearDown(sub.cancel);

      events.add(
        CompleteReadReady(
          const [],
          rejected: const [RejectedRow(ulidD, 'bad')],
        ),
      );
      tracks.add(CompleteReadReady(const []));
      await pumpEventQueue();
      events.add(CompleteReadReady([_learn(ulidA)]));
      await pumpEventQueue();

      expect(errors, hasLength(1));
      expect(out.single.events.map((e) => e.id), [ulidA]);
    });
  });

  group('profileHistoryLogProvider', () {
    test('resolves the complete log, with an ended sub-track still named by '
        'its stored name even though no live track has that id', () async {
      final scope = c0Scope();
      final events = InMemoryLearningEventRepository()
        ..seed(scope, [_learn(ulidA, source: ulidB), _learn(ulidC)]);
      final tracks = InMemorySubTrackRepository()..seed(scope, [_ended(ulidB)]);
      addTearDown(events.dispose);
      addTearDown(tracks.dispose);
      final container = ProviderContainer(
        overrides: [
          learningEventRepositoryProvider.overrideWith((ref) async => events),
          subTrackRepositoryProvider.overrideWith((ref) async => tracks),
        ],
      );
      addTearDown(container.dispose);

      final log = await settledAsync(
        container,
        profileHistoryLogProvider(scope),
      );

      expect(log.requireValue.events.map((e) => e.id), [ulidA, ulidC]);
      expect(log.requireValue.subTrackName(ulidB), 'Cheder shiur');
      expect(log.requireValue.subTracksById[ulidB]!.endedAt, t1);
      expect(log.requireValue.subTrackName(ulidE), isNull);
    });

    test('stays loading while a repository is not ready (ruling B1)', () async {
      final scope = c0Scope();
      final tracks = InMemorySubTrackRepository();
      addTearDown(tracks.dispose);
      final container = ProviderContainer(
        overrides: [
          learningEventRepositoryProvider.overrideWith((ref) async => null),
          subTrackRepositoryProvider.overrideWith((ref) async => tracks),
        ],
      );
      addTearDown(container.dispose);

      final log = await settledAsync(
        container,
        profileHistoryLogProvider(scope),
      );
      expect(log.isLoading, isTrue);
      expect(log.hasValue, isFalse);
    });
  });
}
