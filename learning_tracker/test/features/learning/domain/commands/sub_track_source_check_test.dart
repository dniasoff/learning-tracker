// Story 2.10 (DNI-501): the owner write path accepts a sub-track `source`
// only when it is a live sub-track of the event's curriculum in the
// learner's own scope. The Firestore rule for learning_events stays free
// of access calls (AD-54), so this check is the enforcement point for
// owner capture and source correction.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_source_check.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';

const _b11 = 'Mishnah Berakhot 1:1';

final _school = engineUlid(10);
final _ended = engineUlid(11);
final _bavliTrack = engineUlid(12);
final _otherProfileTrack = engineUlid(13);

/// Another profile of the same owner account.
final _otherProfile = LearnerScope(
  ownerUid: 'owner-uid',
  profileId: engineUlid(77),
);

SubTrack _track(String id, {String curriculumId = engineCurriculum}) =>
    SubTrack(
      id: id,
      curriculumId: curriculumId,
      name: 'Track $id',
      type: SubTrackType.ongoing,
      windowStart: '2026-09-01',
      ratePerWeek: 5,
      weeksPerYear: 40,
      learnsOnShabbos: false,
      ground: const [],
      lastChangeId: engineUlid(90),
    );

SubTrack _endedTrack(String id) => SubTrack(
  id: id,
  curriculumId: engineCurriculum,
  name: 'Ended',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 5,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: const [],
  lastChangeId: engineUlid(90),
  endedAt: DateTime.utc(2026, 8, 30),
);

InMemorySubTrackRepository _repo() => InMemorySubTrackRepository()
  ..seed(c0Scope(), [
    _track(_school),
    _endedTrack(_ended),
    _track(_bavliTrack, curriculumId: 'bavli'),
  ])
  ..seed(_otherProfile, [_track(_otherProfileTrack)]);

/// A repository whose complete read never arrives.
final class _NeverReady extends Fake implements SubTrackRepository {
  @override
  Stream<CompleteRead<SubTrack>> watchAll(LearnerScope scope) =>
      Stream.multi((c) => c.add(const CompleteReadLoading<SubTrack>()));
}

final class _Harness {
  _Harness({SubTrackSourceCheck? check}) {
    reads = FakeLearningCommandReads(
      history: c0SettingsHistory(),
      log: [engineLearn(1, _b11)],
      corpora: {engineCurriculum: mishnayosCorpus()},
    );
    commands = DefaultLearningCommands(
      scope: c0Scope(),
      actor: const Actor(
        uid: 'owner-uid',
        role: ActorRole.parent,
        displayName: '',
      ),
      reads: reads,
      writePort: port,
      gate: const LockWindowCaptureGate(),
      analytics: RecordingLearningAnalytics(),
      failureReporter: RecordingLearningFailureReporter(),
      clock: () => engineAt(600),
      newUlid: (_) => engineUlid(_seq++),
      ackWait: const Duration(milliseconds: 40),
      pointsWait: const Duration(milliseconds: 40),
      sourceCheck: check ?? subTrackSourceCheckFrom(_repo(), c0Scope()),
    );
    addTearDown(commands.dispose);
  }

  late final FakeLearningCommandReads reads;
  final port = InMemoryLearningWritePort();
  late final DefaultLearningCommands commands;
  int _seq = 30000;

  List<LearningEvent> get written => [for (final c in port.chunks) ...c.events];

  Future<CaptureResult> capture(String source) => commands.capture(
    curriculumId: engineCurriculum,
    refs: const [_b11],
    source: source,
    dateState: DateState.dated,
  );
}

void main() {
  group('subTrackSourceCheckFrom', () {
    final check = subTrackSourceCheckFrom(_repo(), c0Scope());

    test('a live sub-track of the curriculum in this scope passes', () async {
      expect(await check(engineCurriculum, _school), isTrue);
    });

    test('an unknown id fails', () async {
      expect(await check(engineCurriculum, engineUlid(55)), isFalse);
    });

    test('a sub-track of another curriculum fails', () async {
      expect(await check(engineCurriculum, _bavliTrack), isFalse);
      expect(await check('bavli', _bavliTrack), isTrue);
    });

    test('a sub-track of another profile fails', () async {
      expect(await check(engineCurriculum, _otherProfileTrack), isFalse);
    });

    test('an ended sub-track fails', () async {
      expect(await check(engineCurriculum, _ended), isFalse);
    });

    test('a read that never completes times out', () async {
      final slow = subTrackSourceCheckFrom(
        _NeverReady(),
        c0Scope(),
        wait: const Duration(milliseconds: 10),
      );
      await expectLater(
        slow(engineCurriculum, _school),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group('DefaultLearningCommands with a source check', () {
    test(
      'capture from a live sub-track of the curriculum is written',
      () async {
        final h = _Harness();
        expect(await h.capture(_school), isA<CaptureSuccess>());
        expect([for (final e in h.written) e.source], [_school]);
      },
    );

    test('capture from main never consults the check', () async {
      final h = _Harness(check: (_, _) async => fail('not consulted'));
      expect(await h.capture(LearningEvent.sourceMain), isA<CaptureSuccess>());
    });

    for (final (name, source) in [
      ('an unknown', engineUlid(55)),
      ('a cross-curriculum', _bavliTrack),
      ('a cross-profile', _otherProfileTrack),
      ('an ended', _ended),
    ]) {
      test(
        'capture from $name sub-track is rejected and writes nothing',
        () async {
          final h = _Harness();
          expect(
            await h.capture(source),
            const CaptureResult.rejected(CaptureRejection.invalid),
          );
          expect(h.port.attempts, isEmpty);
        },
      );
    }

    test('a check that throws fails closed', () async {
      final h = _Harness(check: (_, _) async => throw StateError('offline'));
      expect(
        await h.capture(_school),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
      expect(h.port.attempts, isEmpty);
    });

    test('a source correction to a cross-curriculum sub-track is rejected; '
        'to a live one of the curriculum it is written', () async {
      final h = _Harness();
      expect(
        await h.commands.replace(
          engineUlid(1),
          EventReplacement(source: _bavliTrack),
        ),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
      expect(h.port.attempts, isEmpty);
      expect(
        await h.commands.replace(
          engineUlid(1),
          EventReplacement(source: _school),
        ),
        isA<CaptureSuccess>(),
      );
      expect(
        [
          for (final e in h.written)
            if (e.isLearn) e.source,
        ],
        [_school],
      );
    });

    test(
      'a correction that keeps the source does not consult the check',
      () async {
        final h = _Harness(check: (_, _) async => fail('not consulted'));
        expect(
          await h.commands.replace(
            engineUlid(1),
            const EventReplacement(learnedOn: '2026-08-31'),
          ),
          isA<CaptureSuccess>(),
        );
      },
    );
  });
}
