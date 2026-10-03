// Story 1.11 (DNI-473) R15 port: the capture behaviour retired writer
// services, their points/streak co-writers, and the bulk/manual use cases
// used to own, now
// pinned on `DefaultLearningCommands` — ordering, one capture per batch,
// pts_ attach (AD-50), Before tracking without a date (R10), dated
// backfill without a streak day (deviation #8), lock and permanent
// rejection (AC-5), retry with the same ids and undo of exactly one batch
// (AC-4, AC-7).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_command_reads.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/streak.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';

const _b11 = 'Mishnah Berakhot 1:1';
const _b12 = 'Mishnah Berakhot 1:2';
const _b13 = 'Mishnah Berakhot 1:3';

/// Tuesday 2026-09-01 10:00Z: unlocked for the UTC fixture learner.
final _tuesday = engineAt(600);

/// Saturday 2026-09-05 10:00Z: inside the fixture Shabbos lock.
final _shabbos = DateTime.utc(2026, 9, 5, 10);

final class _Harness {
  _Harness({
    DateTime? now,
    List<LearningEvent>? events,
    LearningCommandReads Function(FakeLearningCommandReads)? wrapReads,
  }) : now = now ?? _tuesday {
    reads = FakeLearningCommandReads(
      history: c0SettingsHistory(),
      log: events,
      corpora: {engineCurriculum: mishnayosCorpus()},
    );
    commands = DefaultLearningCommands(
      scope: c0Scope(),
      actor: const Actor(
        uid: 'owner-uid',
        role: ActorRole.parent,
        displayName: '',
      ),
      reads: wrapReads?.call(reads) ?? reads,
      writePort: port,
      gate: const LockWindowCaptureGate(),
      analytics: analytics,
      failureReporter: reporter,
      clock: () => this.now,
      newUlid: (_) => engineUlid(_seq++),
      ackWait: const Duration(milliseconds: 40),
      pointsWait: const Duration(milliseconds: 40),
      recordedWait: const Duration(milliseconds: 40),
    );
    addTearDown(commands.dispose);
  }

  DateTime now;
  late final FakeLearningCommandReads reads;
  final port = InMemoryLearningWritePort();
  final analytics = RecordingLearningAnalytics();
  final reporter = RecordingLearningFailureReporter();
  late final DefaultLearningCommands commands;
  int _seq = 30000;

  List<LearningEvent> get written => [for (final c in port.chunks) ...c.events];

  List<PointsAward> get awards => [for (final c in port.chunks) ...c.awards];

  /// Makes everything committed so far visible to the command reads.
  void sync() {
    final ids = {for (final e in reads.eventLog) e.id};
    reads.eventLog.addAll(written.where((e) => ids.add(e.id)));
  }

  Future<CaptureResult> capture({
    List<String> refs = const [],
    List<NodeEntry> nodes = const [],
    String source = LearningEvent.sourceMain,
    DateState dateState = DateState.dated,
    String? learnedOn,
    int? stage,
    bool skipRecorded = false,
  }) => commands.capture(
    curriculumId: engineCurriculum,
    refs: refs,
    nodes: nodes,
    source: source,
    dateState: dateState,
    learnedOn: learnedOn,
    stage: stage,
    skipRecorded: skipRecorded,
  );
}

/// Reads whose event log never arrives (offline, uncached).
final class _StalledEventReads implements LearningCommandReads {
  _StalledEventReads(this.inner);

  final FakeLearningCommandReads inner;

  @override
  Future<LearnerSettingsHistory> settingsHistory(LearnerScope scope) =>
      inner.settingsHistory(scope);

  @override
  Future<List<LearningEvent>> events(LearnerScope scope) =>
      Completer<List<LearningEvent>>().future;

  @override
  Future<Corpus?> corpus(String curriculumId) => inner.corpus(curriculumId);

  @override
  Future<int> pointsAmount(
    LearnerScope scope,
    String curriculumId,
    int? stage,
  ) => inner.pointsAmount(scope, curriculumId, stage);
}

/// Reads backed by the device's local cache: every write this device has
/// issued (saved or still queued) is visible, as in the Firestore SDK; the
/// snapshot is taken when the read starts and answers only after [delay],
/// so two captures started together both pass the read before either
/// writes unless they are serialized.
final class _LocalCacheReads implements LearningCommandReads {
  _LocalCacheReads(this.inner, this.port);

  final FakeLearningCommandReads inner;
  final InMemoryLearningWritePort Function() port;
  static const delay = Duration(milliseconds: 5);
  int eventReads = 0;

  @override
  Future<LearnerSettingsHistory> settingsHistory(LearnerScope scope) =>
      inner.settingsHistory(scope);

  @override
  Future<List<LearningEvent>> events(LearnerScope scope) async {
    eventReads++;
    // The snapshot is taken when the read starts and answers later.
    final snapshot = [
      ...inner.eventLog,
      for (final c in port().attempts) ...c.events,
    ];
    await Future<void>.delayed(delay);
    return snapshot;
  }

  @override
  Future<Corpus?> corpus(String curriculumId) => inner.corpus(curriculumId);

  @override
  Future<int> pointsAmount(
    LearnerScope scope,
    String curriculumId,
    int? stage,
  ) => inner.pointsAmount(scope, curriculumId, stage);
}

String? _streakDayOf(LearningEvent e) => streakDay(
  e,
  settingsHistory: c0SettingsHistory(),
  locks: const <LockWindow>[],
);

void main() {
  group('AC-1 / AC-7: one main-track tap is one capture', () {
    test('a coarse unit (both amudim) is one batch: one learn event per '
        'ref in the given order, each with its pts_ entry in the same '
        'chunk (AD-50)', () async {
      final h = _Harness();
      final result = await h.capture(refs: [_b11, _b12], stage: 1);

      expect(result, isA<CaptureSuccess>());
      final ids = (result as CaptureSuccess).eventIds;
      expect(h.written.map((e) => e.ref), [_b11, _b12]);
      expect(ids, h.written.map((e) => e.id));
      expect(h.port.chunks, hasLength(1), reason: 'one batch, one chunk');
      for (final e in h.written) {
        expect(e.isLearn, isTrue);
        expect(e.source, LearningEvent.sourceMain);
        expect(e.dateState, DateState.dated);
        expect(e.learnedOn, '2026-09-01');
        expect(e.stage, 1);
        expect(effectiveAt(e), _tuesday);
      }
      expect(h.awards.map((a) => a.eventId), ids);
      expect(h.awards.every((a) => a.createdAt == _tuesday), isTrue);
    });

    test('a same-day main dated event counts for the streak on its '
        'day', () async {
      final h = _Harness();
      await h.capture(refs: [_b11]);
      expect(_streakDayOf(h.written.single), '2026-09-01');
    });

    test('duplicate refs in one batch record each ref once', () async {
      final h = _Harness();
      await h.capture(refs: [_b11, _b11, _b12]);
      expect(h.written.map((e) => e.ref), [_b11, _b12]);
    });

    test('an empty selection writes nothing', () async {
      final h = _Harness();
      expect(await h.capture(), const CaptureResult.success());
      expect(h.port.attempts, isEmpty);
      expect(h.analytics.captures, isEmpty);
    });
  });

  group('Edge: dates, Before tracking and sources', () {
    test('a Home tick dated to an earlier day stays dated with that '
        'learned_on, earns its pts_ entry and no streak day '
        '(deviation #8)', () async {
      final h = _Harness();
      await h.capture(refs: [_b11], learnedOn: '2026-08-28');
      final e = h.written.single;
      expect(e.dateState, DateState.dated);
      expect(e.learnedOn, '2026-08-28', reason: 'never moved to today');
      expect(_streakDayOf(e), isNull);
      expect(h.awards.single.eventId, e.id);
    });

    test('a Before-tracking batch writes no learned_on, no pts_ entry and '
        'no streak day for a before-tracking event', () async {
      final h = _Harness();
      await h.capture(refs: [_b11, _b12], dateState: DateState.beforeTracking);
      expect(h.written, hasLength(2));
      for (final e in h.written) {
        expect(e.dateState, DateState.beforeTracking);
        expect(e.learnedOn, isNull);
        expect(e.level, isNull, reason: 'a leaf ref carries no level');
        expect(_streakDayOf(e), isNull);
        expect(e.toStorage()['learned_on'], isNull);
      }
      expect(h.awards, isEmpty);
    });

    test('a whole node marked Before tracking is one node event carrying '
        'its level', () async {
      final h = _Harness();
      await h.capture(nodes: [berakhot], dateState: DateState.beforeTracking);
      final e = h.written.single;
      expect(e.ref, berakhot.ref);
      expect(e.level, berakhot.level);
      expect(e.learnedOn, isNull);
      expect(h.awards, isEmpty);
    });

    test('a node with a dated state is invalid and writes nothing', () async {
      final h = _Harness();
      expect(
        await h.capture(nodes: [berakhot]),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
      expect(h.port.attempts, isEmpty);
    });

    test('a sub-track source gets no main-track pts_ entry', () async {
      final h = _Harness();
      await h.capture(refs: [_b11], source: engineUlid(7));
      expect(h.written.single.source, engineUlid(7));
      expect(h.awards, isEmpty);
    });
  });

  group('AC-5: lock and permanent rejection', () {
    test('inside a lock every capture returns locked and writes '
        'nothing', () async {
      final h = _Harness(now: _shabbos);
      final result = await h.capture(refs: [_b11]);
      expect(result, isA<CaptureLocked>());
      expect(h.port.attempts, isEmpty);
      expect(h.analytics.captures, isEmpty);
    });

    test('a permanent rejection is one pending failure holding exactly the '
        'batch ids; retry re-sends the same ids and timestamps', () async {
      final h = _Harness();
      final failures = <List<PendingFailure>>[];
      final sub = h.commands.watchPendingFailures().listen(failures.add);
      addTearDown(sub.cancel);
      h.port.failNextWith(const PermanentWriteRejection('permission-denied'));

      final result = await h.capture(refs: [_b11, _b12]);
      expect(result, const CaptureResult.rejected(CaptureRejection.notSaved));
      await pumpEventQueue();
      final failure = failures.last.single;
      final attempted = h.port.attempts.single.events;
      expect(failure.eventIds, attempted.map((e) => e.id));
      expect(failure.reason, PendingFailureReason.permissionDenied);

      final retried = await h.commands.retry(failure.id);
      expect(retried, isA<CaptureSuccess>());
      expect(h.written.map((e) => e.id), failure.eventIds);
      expect(h.written.map(effectiveAt), attempted.map(effectiveAt));
      await pumpEventQueue();
      expect(failures.last, isEmpty);
    });
  });

  group('AC-4: undo voids exactly the batch just written', () {
    test('only the batch ids become void targets; an unrelated prior '
        'event stays counted', () async {
      final prior = engineLearn(1, _b13);
      final h = _Harness(events: [prior]);
      final batch = await h.capture(refs: [_b11, _b12]) as CaptureSuccess;
      h.sync();

      final undone = await h.commands.undoEvents(batch.eventIds);
      expect(undone, isA<CaptureSuccess>());
      final voids = h.written.where((e) => e.isVoid).toList();
      expect(voids.map((e) => e.targetId), unorderedEquals(batch.eventIds));
      expect(voids.map((e) => e.targetId), isNot(contains(prior.id)));
    });

    test('undo of an unknown id writes nothing', () async {
      final h = _Harness();
      final result = await h.commands.undoEvents([engineUlid(99)]);
      expect(
        result,
        const CaptureResult.rejected(CaptureRejection.targetNotFound),
      );
      expect(h.port.attempts, isEmpty);
    });
  });

  group('T6: the capture analytics event replaces the retired writers\' '
      'events (AD-47: enums and a count only)', () {
    test(
      'a Browse / bulk-mark batch emits ONE capture event per batch',
      () async {
        final h = _Harness();
        await h.capture(nodes: [berakhot], dateState: DateState.beforeTracking);
        await h.capture(refs: [_b11, _b12], source: engineUlid(7));
        expect(h.analytics.captures, [
          (
            curriculumId: engineCurriculum,
            sourceKind: CaptureSourceKind.main,
            dateState: DateState.beforeTracking,
            count: 1,
          ),
          (
            curriculumId: engineCurriculum,
            sourceKind: CaptureSourceKind.subTrack,
            dateState: DateState.dated,
            count: 2,
          ),
        ]);
      },
    );

    test('a locked or rejected batch emits nothing', () async {
      final locked = _Harness(now: _shabbos);
      await locked.capture(refs: [_b11]);
      expect(locked.analytics.captures, isEmpty);

      final rejected = _Harness();
      rejected.port.failNextWith(
        const PermanentWriteRejection('permission-denied'),
      );
      await rejected.capture(refs: [_b11]);
      expect(rejected.analytics.captures, isEmpty);
    });
  });

  group('DNI-501 AC-2: a stale Up to… picker never writes a leaf twice', () {
    final school = engineUlid(7);

    test('a leaf another device recorded in this sub-track while the '
        'picker was open is dropped; the rest are written', () async {
      // The picker froze [b11, b12, b13]; meanwhile another device
      // recorded b12 in School.
      final h = _Harness(events: [engineLearn(1, _b12, source: school)]);
      final result =
          await h.capture(
                refs: [_b11, _b12, _b13],
                source: school,
                skipRecorded: true,
              )
              as CaptureSuccess;

      expect(h.written.map((e) => e.ref), [_b11, _b13]);
      expect(result.eventIds, h.written.map((e) => e.id));
      expect(result.alreadyRecordedRefs, [_b12]);
    });

    test('a leaf learnt from another source still advances nothing in '
        'this sub-track, so it is written (AD-33 position)', () async {
      final h = _Harness(events: [engineLearn(1, _b12)]);
      final result =
          await h.capture(
                refs: [_b11, _b12],
                source: school,
                skipRecorded: true,
              )
              as CaptureSuccess;

      expect(h.written.map((e) => e.ref), [_b11, _b12]);
      expect(result.alreadyRecordedRefs, isEmpty);
    });

    test('main: a leaf learnt from any source is no longer schedulable '
        'and is dropped, with no pts_ entry for it', () async {
      final h = _Harness(events: [engineLearn(1, _b11, source: school)]);
      final result =
          await h.capture(refs: [_b11, _b12], stage: 1, skipRecorded: true)
              as CaptureSuccess;

      expect(h.written.map((e) => e.ref), [_b12]);
      expect(h.awards.map((a) => a.eventId), result.eventIds);
      expect(result.alreadyRecordedRefs, [_b11]);
    });

    test('a voided event does not count: its leaf is written', () async {
      final h = _Harness(
        events: [
          engineLearn(1, _b11, source: school),
          engineVoid(2, 1, minutes: 1),
        ],
      );
      await h.capture(refs: [_b11], source: school, skipRecorded: true);
      expect(h.written.map((e) => e.ref), [_b11]);
    });

    test('a second confirm of the same run writes nothing more', () async {
      final h = _Harness();
      await h.capture(refs: [_b11, _b12], source: school, skipRecorded: true);
      h.sync();
      final before = h.written.length;

      final again =
          await h.capture(
                refs: [_b11, _b12],
                source: school,
                skipRecorded: true,
              )
              as CaptureSuccess;

      expect(h.written, hasLength(before));
      expect(again.eventIds, isEmpty);
      expect(again.alreadyRecordedRefs, [_b11, _b12]);
      expect(h.analytics.captures, hasLength(1));
    });

    test('an unreadable log (offline) writes the refs as given', () async {
      final h = _Harness(
        events: [engineLearn(1, _b12, source: school)],
        wrapReads: _StalledEventReads.new,
      );
      final result =
          await h.capture(
                refs: [_b11, _b12],
                source: school,
                skipRecorded: true,
              )
              as CaptureSuccess;

      expect(h.written.map((e) => e.ref), [_b11, _b12]);
      expect(result.alreadyRecordedRefs, isEmpty);
    });

    test('two captures of the same leaf started together on this device '
        'write it once: the second re-reads after the first wrote, even '
        'while that write is still queued offline', () async {
      late _LocalCacheReads cache;
      late _Harness h;
      h = _Harness(
        wrapReads: (inner) => cache = _LocalCacheReads(inner, () => h.port),
      );
      h.port.holdNext(); // the first write stays queued (offline)

      final results = await Future.wait([
        h.capture(refs: [_b11, _b12], source: school, skipRecorded: true),
        h.capture(refs: [_b12, _b13], source: school, skipRecorded: true),
      ]);
      final first = results[0] as CaptureSuccess;
      final second = results[1] as CaptureSuccess;

      expect(
        [
          for (final c in h.port.attempts)
            for (final e in c.events) e.ref,
        ],
        [_b11, _b12, _b13],
      );
      expect(first.alreadyRecordedRefs, isEmpty);
      expect(second.alreadyRecordedRefs, [_b12]);
      expect(cache.eventReads, 2);
      h.port.release();
    });

    test('without skipRecorded the log is not read', () async {
      final h = _Harness(events: [engineLearn(1, _b12, source: school)]);
      await h.capture(refs: [_b12], source: school);
      expect(h.written.map((e) => e.ref), [_b12]);
      expect(h.reads.reads, isNot(contains('events')));
    });
  });
}
