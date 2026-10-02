// Mirror test for
// `lib/features/learning/domain/commands/learning_commands.dart`
// (C0 DNI-524 EventReplacement; DNI-469 AC-1..AC-9 on
// DefaultLearningCommands with fake ports, a fixed clock, a stable id
// source, a fake failure reporter and fake analytics).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
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
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _b11 = 'Mishnah Berakhot 1:1';
const _b12 = 'Mishnah Berakhot 1:2';
const _b13 = 'Mishnah Berakhot 1:3';

// The UTC no-location learner (c0SettingsHistory): Shabbos lock
// Fri 2026-09-04 12:00Z → Sun 2026-09-06 01:00Z; catch-up to the end of
// Mon 2026-09-07.
final _lockStart = DateTime.utc(2026, 9, 4, 12);
final _lockEnd = DateTime.utc(2026, 9, 6, 1);
final _tuesday = engineAt(600); // 2026-09-01 10:00Z, unlocked

/// Every read, gate check and commit, in order.
typedef _Log = List<String>;

final class _LoggedReads implements LearningCommandReads {
  _LoggedReads(this.inner, this.log);

  final FakeLearningCommandReads inner;
  final _Log log;

  /// When set, every points read waits on it (a stalled offline read).
  Completer<int>? stalledPoints;

  @override
  Future<LearnerSettingsHistory> settingsHistory(LearnerScope scope) {
    log.add('settings');
    return inner.settingsHistory(scope);
  }

  @override
  Future<List<LearningEvent>> events(LearnerScope scope) {
    log.add('events');
    return inner.events(scope);
  }

  @override
  Future<Corpus?> corpus(String curriculumId) {
    log.add('corpus');
    return inner.corpus(curriculumId);
  }

  @override
  Future<int> pointsAmount(LearnerScope scope, String curriculumId, int? s) {
    log.add('points');
    final stalled = stalledPoints;
    if (stalled != null) return stalled.future;
    return inner.pointsAmount(scope, curriculumId, s);
  }
}

final class _LoggedGate implements CaptureGate {
  _LoggedGate(this.log);

  final _Log log;
  final checks = <(LearnerSettingsHistory, DateTime)>[];

  @override
  GateDecision check(LearnerSettingsHistory h, DateTime nowUtc) {
    log.add('gate');
    checks.add((h, nowUtc));
    return const LockWindowCaptureGate().check(h, nowUtc);
  }
}

final class _LoggedPort implements LearningWritePort {
  _LoggedPort(this.inner, this.log, this.harness);

  final InMemoryLearningWritePort inner;
  final _Log log;
  final _Harness harness;

  @override
  Future<void> commit(LearnerScope scope, LearningWriteChunk chunk) {
    log.add('commit');
    harness.idsMintedAtFirstCommit ??= harness.minted;
    return inner.commit(scope, chunk);
  }
}

/// A [GovernedLearningCommands] that records each delegated call.
final class _LoggedGoverned implements GovernedLearningCommands {
  _LoggedGoverned(this.log);

  final _Log log;

  @override
  Future<CaptureResult> applyGovernedChange(GovernedAction action) async {
    log.add('governed');
    return const CaptureResult.success();
  }

  @override
  Future<CaptureResult> undoAction(String actionId) async {
    log.add('governed');
    return const CaptureResult.success();
  }

  /// The governed pending failures it reports.
  List<PendingFailure> failures = const [];

  @override
  Stream<List<PendingFailure>> watchPendingFailures() => Stream.value(failures);

  @override
  Future<CaptureResult?> retry(String pendingFailureId) async {
    if (!failures.any((f) => f.id == pendingFailureId)) return null;
    log.add('governed retry');
    return CaptureResult.success(changeIds: [pendingFailureId]);
  }
}

final _governedAction = GovernedAction(const [
  GovernedEntityChange(
    entity: GovernedEntity.subTrack,
    entityId: 'sub-track',
    docs: [],
  ),
]);

final class _Harness {
  _Harness({
    DateTime? now,
    ActorRole role = ActorRole.parent,
    List<LearningEvent>? events,
    LearnerSettingsHistory? history,
    bool governed = false,
  }) : now = now ?? _tuesday {
    fakeReads = FakeLearningCommandReads(
      history: history ?? c0SettingsHistory(),
      log: events,
      corpora: {engineCurriculum: mishnayosCorpus()},
    );
    gate = _LoggedGate(log);
    reads = _LoggedReads(fakeReads, log);
    commands = DefaultLearningCommands(
      scope: c0Scope(),
      actor: Actor(uid: 'owner-uid', role: role, displayName: 'Abba'),
      reads: reads,
      writePort: _LoggedPort(port, log, this),
      gate: gate,
      analytics: analytics,
      failureReporter: reporter,
      clock: () => this.now,
      newUlid: (at) {
        minted++;
        return engineUlid(_seq++);
      },
      ackWait: const Duration(milliseconds: 40),
      pointsWait: const Duration(milliseconds: 40),
      governed: governed ? governedFake = _LoggedGoverned(log) : null,
    );
    addTearDown(commands.dispose);
  }

  DateTime now;
  final _Log log = [];
  late final FakeLearningCommandReads fakeReads;
  late final _LoggedReads reads;
  late final _LoggedGate gate;
  final port = InMemoryLearningWritePort();
  final analytics = RecordingLearningAnalytics();
  final reporter = RecordingLearningFailureReporter();
  late final DefaultLearningCommands commands;
  _LoggedGoverned? governedFake;
  int _seq = 20000;
  int minted = 0;
  int? idsMintedAtFirstCommit;

  List<LearningEvent> get written => [for (final c in port.chunks) ...c.events];

  List<PointsAward> get awards => [for (final c in port.chunks) ...c.awards];

  /// Appends everything committed so far to the read log (as the SDK
  /// cache would show it).
  void sync() {
    final all = {...fakeReads.eventLog, ...written};
    fakeReads.eventLog
      ..clear()
      ..addAll(all);
  }
}

Future<CaptureResult> _captureDated(
  _Harness h, {
  List<String> refs = const [_b11, _b12],
  String source = LearningEvent.sourceMain,
  DateState dateState = DateState.dated,
  String? learnedOn,
  int? stage,
}) => h.commands.capture(
  curriculumId: engineCurriculum,
  refs: refs,
  source: source,
  dateState: dateState,
  learnedOn: learnedOn,
  stage: stage,
);

void main() {
  test('EventReplacement keeps every field optional and compares by '
      'value', () {
    const keep = EventReplacement();
    expect(keep.ref, isNull);
    expect(keep.source, isNull);
    expect(keep.learnedOn, isNull);
    expect(keep.dateState, isNull);
    expect(keep.stage, isNull);
    expect(
      const EventReplacement(ref: _b12, dateState: DateState.catchUp),
      const EventReplacement(ref: _b12, dateState: DateState.catchUp),
    );
    expect(keep, isNot(const EventReplacement(stage: 1)));
  });

  test('EventReplacement.resolveLearnedOn: null keeps the target date, a '
      'new date replaces it, and a move to Before tracking clears it', () {
    expect(
      const EventReplacement().resolveLearnedOn('2026-08-30'),
      '2026-08-30',
    );
    expect(
      const EventReplacement(source: 'main').resolveLearnedOn('2026-08-30'),
      '2026-08-30',
    );
    expect(
      const EventReplacement(
        learnedOn: '2026-08-29',
      ).resolveLearnedOn('2026-08-30'),
      '2026-08-29',
    );
    expect(
      const EventReplacement(
        source: 'main',
        dateState: DateState.beforeTracking,
      ).resolveLearnedOn('2026-08-30'),
      isNull,
    );
    expect(
      const EventReplacement(
        dateState: DateState.dated,
        learnedOn: '2026-08-29',
      ).resolveLearnedOn(null),
      '2026-08-29',
    );
  });

  test('EventReplacement rejects a learned_on on a Before-tracking '
      'replacement', () {
    EventReplacement build(String learnedOn) => EventReplacement(
      dateState: DateState.beforeTracking,
      learnedOn: learnedOn,
    );
    expect(() => build('2026-08-30'), throwsA(isA<AssertionError>()));
  });

  group('AC-1: every command runs the target learner gate first', () {
    final commands = <String, Future<CaptureResult> Function(_Harness)>{
      'capture': _captureDated,
      'voidEvent': (h) => h.commands.voidEvent(engineUlid(1)),
      'replace': (h) =>
          h.commands.replace(engineUlid(1), const EventReplacement(ref: _b12)),
      'unlearn': (h) => h.commands.unlearn(engineCurriculum, {_b11}),
      'undoEvents': (h) => h.commands.undoEvents([engineUlid(1)]),
      'retry': (h) => h.commands.retry(engineUlid(1)),
      'applyGovernedChange': (h) =>
          h.commands.applyGovernedChange(_governedAction),
      'undoAction': (h) => h.commands.undoAction(engineUlid(1)),
    };

    for (final MapEntry(key: name, value: run) in commands.entries) {
      test('$name inside a lock writes nothing and returns locked', () async {
        final h = _Harness(
          now: DateTime.utc(2026, 9, 5, 10),
          events: [engineLearn(1, _b11)],
          governed: true,
        );
        final result = await run(h);
        expect(result, CaptureResult.locked(LockWindow(_lockStart, _lockEnd)));
        expect(h.log, ['settings', 'gate'], reason: 'no read-for-write');
        expect(h.port.attempts, isEmpty);
        expect(h.gate.checks.single.$1, c0SettingsHistory());
        expect(h.gate.checks.single.$2, DateTime.utc(2026, 9, 5, 10));
        expect(h.analytics.captures, isEmpty);
      });
    }

    test(
      'the gate precedes every read-for-write and every port write',
      () async {
        final h = _Harness(events: [engineLearn(1, _b11)]);
        await _captureDated(h);
        expect(h.log, ['settings', 'gate', 'points', 'commit']);
        h.log.clear();
        await h.commands.voidEvent(engineUlid(1));
        expect(h.log, ['settings', 'gate', 'events', 'commit']);
      },
    );

    test('lock bounds follow lockWindows (closed interval)', () async {
      for (final at in [_lockStart, _lockEnd]) {
        final h = _Harness(now: at);
        expect(await _captureDated(h), isA<CaptureLocked>());
        expect(h.port.attempts, isEmpty);
      }
      for (final at in [
        _lockStart.subtract(const Duration(microseconds: 1)),
        _lockEnd.add(const Duration(microseconds: 1)),
      ]) {
        final h = _Harness(now: at);
        expect(await _captureDated(h), isA<CaptureSuccess>());
      }
    });

    test(
      'an unreadable settings history fails closed: no gate, no write',
      () async {
        final h = _Harness()..fakeReads.history = null;
        final result = await _captureDated(h);
        expect(result, CaptureResult.locked(LockWindow(h.now, h.now)));
        expect(h.log, ['settings']);
        expect(h.port.attempts, isEmpty);
      },
    );
  });

  group('AC-2: capture', () {
    test('dated main: one learn per leaf, civil-today default, pts_ pair at '
        'created_at = recorded_at with the first-stage amount', () async {
      final h = _Harness();
      final result = await _captureDated(h);
      expect(result, isA<CaptureSuccess>());
      final events = h.written;
      expect(events.map((e) => e.ref), [_b11, _b12]);
      expect((result as CaptureSuccess).eventIds, events.map((e) => e.id));
      for (final e in events) {
        expect(e.kind, LearningEventKind.learn);
        expect(e.dateState, DateState.dated);
        expect(e.learnedOn, '2026-09-01');
        expect(e.level, isNull);
        expect(effectiveAt(e), _tuesday);
        expect(e.actor.role, ActorRole.parent);
      }
      expect(h.awards.map((a) => a.eventId), events.map((e) => e.id));
      expect(h.awards.map((a) => a.amount), [10, 10]);
      expect(h.awards.map((a) => a.createdAt), [_tuesday, _tuesday]);
      expect(h.port.chunks.single.awards, hasLength(2), reason: 'same batch');
    });

    test('learned_on is editable; catch_up main also earns', () async {
      final h = _Harness();
      await _captureDated(
        h,
        refs: const [_b11],
        dateState: DateState.catchUp,
        learnedOn: '2026-08-29',
      );
      expect(h.written.single.learnedOn, '2026-08-29');
      expect(h.written.single.dateState, DateState.catchUp);
      expect(h.awards, hasLength(1));
    });

    test(
      'stage ?? firstStageOrder: the configured amount for the stage',
      () async {
        final h = _Harness();
        final asked = <int?>[];
        h.fakeReads.pointsFor = (c, stage) {
          asked.add(stage);
          return stage == null ? 12 : 4;
        };
        await _captureDated(h, refs: const [_b11]);
        await _captureDated(h, refs: const [_b12], stage: 2);
        expect(asked, [null, 2]);
        expect(h.awards.map((a) => a.amount), [12, 4]);
        expect(h.written.last.stage, 2);
      },
    );

    test('before_tracking: a permitted node event carries level and null '
        'learned_on, and never earns', () async {
      final h = _Harness();
      await h.commands.capture(
        curriculumId: engineCurriculum,
        refs: const [_b13],
        nodes: const [berakhot2],
        source: LearningEvent.sourceMain,
        dateState: DateState.beforeTracking,
        learnedOn: '2026-08-01',
      );
      final events = h.written;
      expect(events.map((e) => e.ref), [_b13, berakhot2.ref]);
      expect(events.map((e) => e.learnedOn), [null, null]);
      expect(events.last.level, 'chapter');
      expect(h.awards, isEmpty);
      expect(h.log, isNot(contains('points')));
    });

    test('a sub-track capture never earns', () async {
      final h = _Harness();
      await _captureDated(h, source: ulidB);
      expect(h.written, hasLength(2));
      expect(h.awards, isEmpty);
    });

    test('invalid input is rejected and writes nothing', () async {
      final h = _Harness();
      expect(
        await h.commands.capture(
          curriculumId: engineCurriculum,
          nodes: const [berakhot],
          source: LearningEvent.sourceMain,
          dateState: DateState.dated,
        ),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
      expect(
        await _captureDated(h, source: 'not-a-ulid'),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
      expect(
        await _captureDated(h, source: ulidB, stage: 1),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
      expect(
        await _captureDated(h, learnedOn: '2026-13-01'),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
      expect(h.port.attempts, isEmpty);
    });

    test('an empty capture is a no-op', () async {
      final h = _Harness();
      expect(
        await _captureDated(h, refs: const []),
        const CaptureResult.success(),
      );
      expect(h.port.attempts, isEmpty);
      expect(h.analytics.captures, isEmpty);
    });

    test(
      'no reversal entry is ever written (a void carries no award)',
      () async {
        final h = _Harness();
        await _captureDated(h, refs: const [_b11]);
        h.sync();
        await h.commands.voidEvent(h.written.single.id);
        expect(h.port.chunks.last.awards, isEmpty);
        expect(h.awards.every((a) => a.amount > 0), isTrue);
      },
    );
  });

  group('AC-3: 1,000-leaf capture', () {
    final refs = [for (var i = 0; i < 1000; i++) 'Mishnah Leaf $i'];

    test('chunks of ≤ 450 writes, each event with its pts_ entry, every '
        'client timestamp ≤ now', () async {
      final h = _Harness();
      final result = await _captureDated(h, refs: refs);
      expect((result as CaptureSuccess).eventIds, hasLength(1000));
      expect(h.port.chunks, hasLength(5));
      for (final chunk in h.port.chunks) {
        expect(
          chunk.events.length + chunk.awards.length,
          lessThanOrEqualTo(450),
        );
        expect(
          chunk.awards.map((a) => a.eventId).toSet(),
          chunk.events.map((e) => e.id).toSet(),
        );
        for (final e in chunk.events) {
          expect(rawRecordedAtForSkewRule(e).isAfter(h.now), isFalse);
        }
        for (final a in chunk.awards) {
          expect(a.createdAt.isAfter(h.now), isFalse);
        }
      }
    });

    test('ids and timestamps are fixed before the first attempt and reused '
        'on retry', () async {
      final h = _Harness();
      h.port.failNextWith(const PermanentWriteRejection('permission-denied'));
      await _captureDated(h, refs: refs);
      expect(h.idsMintedAtFirstCommit, 1000);
      final rejected = h.port.attempts.first;
      final pending = await h.commands.watchPendingFailures().first;
      expect(pending.single.eventIds, rejected.events.map((e) => e.id));

      h.now = h.now.add(const Duration(hours: 2)); // a later retry
      final retried = await h.commands.retry(pending.single.id);
      expect(retried, isA<CaptureSuccess>());
      expect(identical(h.port.attempts.last, rejected), isTrue);
      expect(h.minted, 1000, reason: 'no id minted on retry');
    });
  });

  group('AC-4: void and replace', () {
    test('void of a void and of a lock-ignored event are rejected', () async {
      final h = _Harness(
        now: DateTime.utc(2026, 9, 7, 10),
        events: [
          engineLearn(1, _b11),
          engineVoid(2, 1),
          engineLearn(3, _b12, minutes: 6000), // inside the Shabbos lock
        ],
      );
      expect(
        await h.commands.voidEvent(engineUlid(2)),
        const CaptureResult.rejected(CaptureRejection.voidTargetNotLearn),
      );
      expect(
        await h.commands.voidEvent(engineUlid(3)),
        const CaptureResult.rejected(CaptureRejection.lockIgnoredTarget),
      );
      expect(
        await h.commands.replace(
          engineUlid(3),
          const EventReplacement(ref: _b13),
        ),
        const CaptureResult.rejected(CaptureRejection.lockIgnoredTarget),
      );
      expect(
        await h.commands.undoEvents([engineUlid(3)]),
        const CaptureResult.rejected(CaptureRejection.lockIgnoredTarget),
      );
      expect(h.port.attempts, isEmpty);
    });

    test('an absent target is voided without error (AD-31); an already '
        'voided one is not voided twice', () async {
      final h = _Harness(events: [engineLearn(1, _b11), engineVoid(2, 1)]);
      expect(
        await h.commands.voidEvent(engineUlid(1)),
        const CaptureResult.success(),
      );
      expect(h.port.attempts, isEmpty);
      final absent = await h.commands.voidEvent(engineUlid(99));
      expect(absent, isA<CaptureSuccess>());
      expect(h.written.single.targetId, engineUlid(99));
    });

    test('a ref-only replacement keeps learned_on/date_state and '
        'effectiveAt(original), so it adds no streak day', () async {
      final original = engineLearn(1, _b11, minutes: 30);
      final h = _Harness(
        now: engineAt(3000), // two days later
        events: [original],
      );
      final result = await h.commands.replace(
        engineUlid(1),
        const EventReplacement(ref: _b12),
      );
      expect(result, isA<CaptureSuccess>());
      final chunk = h.port.chunks.single;
      final next = chunk.events.firstWhere((e) => e.isLearn);
      final voided = chunk.events.firstWhere((e) => e.isVoid);
      expect(voided.targetId, original.id);
      expect(next.ref, _b12);
      expect(next.learnedOn, original.learnedOn);
      expect(next.dateState, original.dateState);
      expect(effectiveAt(next), effectiveAt(original));
      expect(chunk.awards.single.eventId, next.id);
      final locks = lockWindows(
        c0SettingsHistory(),
        engineAt(0),
        engineAt(3000),
      );
      expect(
        streakDay(next, settingsHistory: c0SettingsHistory(), locks: locks),
        streakDay(original, settingsHistory: c0SettingsHistory(), locks: locks),
      );
    });

    test(
      'a source-only change to a sub-track drops stage and the award',
      () async {
        final h = _Harness(events: [engineLearn(1, _b11, stage: 1)]);
        await h.commands.replace(
          engineUlid(1),
          const EventReplacement(source: ulidB),
        );
        final next = h.written.firstWhere((e) => e.isLearn);
        expect(next.source, ulidB);
        expect(next.stage, isNull);
        expect(h.awards, isEmpty);
      },
    );

    test('replace of a missing target is targetNotFound; of a void is '
        'voidTargetNotLearn', () async {
      final h = _Harness(events: [engineLearn(1, _b11), engineVoid(2, 1)]);
      expect(
        await h.commands.replace(engineUlid(9), const EventReplacement()),
        const CaptureResult.rejected(CaptureRejection.targetNotFound),
      );
      expect(
        await h.commands.replace(engineUlid(2), const EventReplacement()),
        const CaptureResult.rejected(CaptureRejection.voidTargetNotLearn),
      );
    });
  });

  group('AC-5: child re-date limit', () {
    // Recorded Sun 09:00Z dated Sunday; the child re-dates it to Shabbos.
    final sunday = DateTime.utc(2026, 9, 6, 9);
    LearningEvent target() => LearningEvent.learn(
      id: engineUlid(1),
      curriculumId: engineCurriculum,
      ref: _b11,
      source: LearningEvent.sourceMain,
      dateState: DateState.dated,
      learnedOn: '2026-09-06',
      recordedAt: sunday,
      actor: parentActor,
    );
    const toShabbos = EventReplacement(
      dateState: DateState.catchUp,
      learnedOn: '2026-09-05',
    );

    test('allowed inside the locked day\'s catch-up window', () async {
      final h = _Harness(
        now: DateTime.utc(2026, 9, 7, 20),
        role: ActorRole.child,
        events: [target()],
      );
      expect(
        await h.commands.replace(engineUlid(1), toShabbos),
        isA<CaptureSuccess>(),
      );
      final next = h.written.firstWhere((e) => e.isLearn);
      expect(next.dateState, DateState.catchUp);
      expect(next.learnedOn, '2026-09-05');
      expect(effectiveAt(next), DateTime.utc(2026, 9, 7, 20));
    });

    test('rejected at the end of the window: childLimit and nothing written; '
        'removal is still allowed', () async {
      final h = _Harness(
        now: DateTime.utc(2026, 9, 8),
        role: ActorRole.child,
        events: [target()],
      );
      expect(
        await h.commands.replace(engineUlid(1), toShabbos),
        const CaptureResult.childLimit(),
      );
      expect(h.port.attempts, isEmpty);
      expect(await h.commands.voidEvent(engineUlid(1)), isA<CaptureSuccess>());
      expect(h.written.single.targetId, engineUlid(1));
    });

    test('a child may not re-date to a non-locked day; a ref-only fix is '
        'not a re-date', () async {
      final h = _Harness(
        now: DateTime.utc(2026, 9, 7, 20),
        role: ActorRole.child,
        events: [target()],
      );
      expect(
        await h.commands.replace(
          engineUlid(1),
          const EventReplacement(learnedOn: '2026-09-04'),
        ),
        const CaptureResult.childLimit(),
      );
      h.now = DateTime.utc(2026, 9, 9);
      expect(
        await h.commands.replace(
          engineUlid(1),
          const EventReplacement(ref: _b12),
        ),
        isA<CaptureSuccess>(),
      );
    });

    test('a parent has no such limit', () async {
      final h = _Harness(now: DateTime.utc(2026, 9, 9), events: [target()]);
      expect(
        await h.commands.replace(engineUlid(1), toShabbos),
        isA<CaptureSuccess>(),
      );
    });
  });

  group('AC-6: unlearn and its undo', () {
    test(
      'voids the node event, re-issues the maximal complement with its '
      'effective instant, voids leaf events in S; undo reverses it',
      () async {
        final node = engineGround(1, zeraim, minutes: 5);
        final leaf = engineLearn(2, _b12, minutes: 40);
        final untouched = engineLearn(3, 'Mishnah Shabbat 1:1');
        final h = _Harness(events: [node, leaf, untouched]);

        final result = await h.commands.unlearn(engineCurriculum, {_b12});
        final ids = (result as CaptureSuccess).eventIds;
        final written = h.written;
        expect(ids, written.map((e) => e.id));
        final reissues = written.where((e) => e.isLearn).toList();
        expect(reissues.map((e) => e.ref), [
          _b11,
          _b13,
          berakhot2.ref,
          peah.ref,
        ]);
        for (final r in reissues) {
          expect(r.dateState, DateState.beforeTracking);
          expect(r.level, isNotNull);
          expect(effectiveAt(r), effectiveAt(node));
        }
        expect(written.where((e) => e.isVoid).map((e) => e.targetId).toSet(), {
          node.id,
          leaf.id,
        });
        expect(h.awards, isEmpty);

        // Undo: voids the re-issues and re-copies the voided events.
        h.sync();
        final undo = await h.commands.undoEvents(ids);
        expect(undo, isA<CaptureSuccess>());
        final undoWrites = h.port.chunks.last.events;
        final undoVoids = undoWrites.where((e) => e.isVoid).toList();
        expect(
          undoVoids.map((e) => e.targetId).toSet(),
          reissues.map((e) => e.id).toSet(),
        );
        expect(undoVoids.every((v) => v.revertsActionId == ids.first), isTrue);
        final copies = undoWrites.where((e) => e.isLearn).toList();
        expect(copies.map((e) => e.ref).toSet(), {node.ref, leaf.ref});
        final nodeCopy = copies.firstWhere((e) => e.ref == node.ref);
        expect(nodeCopy.level, node.level);
        expect(effectiveAt(nodeCopy), effectiveAt(node));
        final leafCopy = copies.firstWhere((e) => e.ref == leaf.ref);
        expect(effectiveAt(leafCopy), effectiveAt(leaf));
        expect(
          h.port.chunks.last.awards.single.eventId,
          leafCopy.id,
          reason: 'the main dated copy pairs with its pts_ entry',
        );

        // Undo is final.
        h.sync();
        expect(
          await h.commands.undoEvents([undoVoids.first.id]),
          const CaptureResult.rejected(CaptureRejection.undoIsFinal),
        );
      },
    );

    test(
      'already voided events are not voided twice; empty S is a no-op',
      () async {
        final h = _Harness(events: [engineLearn(1, _b12), engineVoid(2, 1)]);
        expect(
          await h.commands.unlearn(engineCurriculum, {_b12}),
          const CaptureResult.success(),
        );
        expect(
          await h.commands.unlearn(engineCurriculum, {}),
          const CaptureResult.success(),
        );
        expect(h.port.attempts, isEmpty);
      },
    );

    test('an unknown curriculum corpus is invalid', () async {
      final h = _Harness();
      expect(
        await h.commands.unlearn('unknown', {_b12}),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
    });
  });

  group('AC-7: permanently rejected writes are recoverable', () {
    test('one pending failure per rejected item with a retry reusing the '
        'same ids and timestamps; Crashlytics gets enums only', () async {
      final h = _Harness();
      h.port.failNextWith(const PermanentWriteRejection('permission-denied'));
      final result = await _captureDated(h);
      expect(result, const CaptureResult.rejected(CaptureRejection.notSaved));
      expect(h.analytics.captures, isEmpty);

      final pending = await h.commands.watchPendingFailures().first;
      final rejected = h.port.attempts.single;
      expect(pending, [
        PendingFailure(
          id: rejected.events.first.id,
          eventIds: [for (final e in rejected.events) e.id],
          changeIds: const [],
          reason: PendingFailureReason.permissionDenied,
        ),
      ]);
      expect(h.reporter.reports.single, (
        command: LearningCommandKind.capture,
        reason: PendingFailureReason.permissionDenied,
        writeCount: 4,
      ));
      final reported = LearningWriteRejectedError(
        command: h.reporter.reports.single.command,
        reason: h.reporter.reports.single.reason,
        writeCount: h.reporter.reports.single.writeCount,
      ).toString();
      for (final secret in [profileUlid, _b11, engineCurriculum, 'owner-uid']) {
        expect(reported, isNot(contains(secret)));
      }

      final retried = await h.commands.retry(pending.single.id);
      expect(retried, CaptureResult.success(eventIds: pending.single.eventIds));
      expect(identical(h.port.attempts.last, rejected), isTrue);
      expect(await h.commands.watchPendingFailures().first, isEmpty);
    });

    test('a partially rejected command reports only what was saved', () async {
      final h = _Harness();
      h.port.failNextWith(const PermanentWriteRejection('invalid-argument'));
      final refs = [for (var i = 0; i < 300; i++) 'Mishnah Leaf $i'];
      final result = await _captureDated(h, refs: refs);
      expect((result as CaptureSuccess).eventIds, hasLength(75));
      final pending = await h.commands.watchPendingFailures().first;
      expect(pending.single.eventIds, hasLength(225));
      expect(h.analytics.captures.single.count, 75);
    });

    test('a transient (SDK-queued) write is not duplicated into an '
        'app-level queue', () async {
      final h = _Harness();
      h.port.holdNext();
      await _captureDated(h);
      h.port.release();
      await pumpEventQueue();
      expect(await h.commands.watchPendingFailures().first, isEmpty);
      expect(h.reporter.reports, isEmpty);
      expect(h.port.attempts, hasLength(1));
    });

    test('retry of an unknown pending failure is targetNotFound', () async {
      final h = _Harness();
      expect(
        await h.commands.retry(engineUlid(5)),
        const CaptureResult.rejected(CaptureRejection.targetNotFound),
      );
    });
  });

  group('AC-8: capture analytics', () {
    test(
      'fires once per successful capture with enums and counts only',
      () async {
        final h = _Harness();
        await _captureDated(h);
        await _captureDated(h, source: ulidB, dateState: DateState.catchUp);
        expect(h.analytics.captures, [
          (
            curriculumId: engineCurriculum,
            sourceKind: CaptureSourceKind.main,
            dateState: DateState.dated,
            count: 2,
          ),
          (
            curriculumId: engineCurriculum,
            sourceKind: CaptureSourceKind.subTrack,
            dateState: DateState.catchUp,
            count: 2,
          ),
        ]);
      },
    );

    test('corrections emit no capture event', () async {
      final h = _Harness(events: [engineLearn(1, _b11)]);
      await h.commands.voidEvent(engineUlid(1));
      await h.commands.unlearn(engineCurriculum, {_b11});
      expect(h.analytics.captures, isEmpty);
    });
  });

  test('AC-9: offline, a capture is queued by the SDK and succeeds locally '
      'without a server acknowledgement', () async {
    final h = _Harness();
    h.port.holdNext();
    final result = await _captureDated(h);
    expect(result, isA<CaptureSuccess>());
    expect((result as CaptureSuccess).queued, isTrue);
    expect(result.eventIds, hasLength(2));
    expect(h.port.heldCount, 1, reason: 'server never acknowledged');
    expect(h.analytics.captures, hasLength(1));
  });

  group(
    'AC-9: an unreadable points amount never blocks an offline capture',
    () {
      test('an uncached (failing) points read queues the event and its pts_ '
          'entry at the default first-stage amount', () async {
        final h = _Harness();
        h.fakeReads.pointsFor = (c, s) => throw StateError('unavailable');
        h.port.holdNext();
        final result = await _captureDated(h, refs: const [_b11]);
        expect(result, isA<CaptureSuccess>());
        expect((result as CaptureSuccess).queued, isTrue);
        expect(h.port.heldCount, 1, reason: 'one queued batch');
        final batch = h.port.attempts.single;
        expect(batch.events.single.ref, _b11);
        expect(batch.awards.single.eventId, batch.events.single.id);
        expect(
          batch.awards.single.amount,
          10,
          reason: 'default ladder, stage 1',
        );
        expect(h.analytics.captures, hasLength(1));
      });

      test('a failing read at an explicit stage uses that stage on the default '
          'ladder', () async {
        final h = _Harness();
        h.fakeReads.pointsFor = (c, s) => throw StateError('unavailable');
        await _captureDated(h, refs: const [_b11], stage: 2);
        expect(h.awards.single.amount, 5);
      });

      test('a stalled points read falls back after the points wait', () async {
        final h = _Harness();
        h.reads.stalledPoints = Completer<int>();
        h.port.holdNext();
        final result = await _captureDated(h, refs: const [_b11]);
        expect((result as CaptureSuccess).queued, isTrue);
        expect(h.port.attempts.single.awards.single.amount, 10);
        expect(h.log, ['settings', 'gate', 'points', 'commit']);
      });

      test(
        'a replacement and an undo re-issue fall back the same way',
        () async {
          final h = _Harness(events: [engineLearn(1, _b11)]);
          h.fakeReads.pointsFor = (c, s) => throw StateError('unavailable');
          final replaced = await h.commands.replace(
            engineUlid(1),
            const EventReplacement(ref: _b12),
          );
          expect(replaced, isA<CaptureSuccess>());
          expect(h.awards.single.amount, 10);

          final undo = _Harness(
            events: [engineLearn(1, _b11, stage: 3), engineVoid(2, 1)],
          );
          undo.fakeReads.pointsFor = (c, s) => throw StateError('unavailable');
          expect(
            await undo.commands.undoEvents([engineUlid(2)]),
            isA<CaptureSuccess>(),
          );
          expect(undo.awards.single.amount, 3, reason: 'stage 3 on the ladder');
        },
      );
    },
  );

  test('governed commands are delegated (DNI-470 fills them)', () {
    final h = _Harness();
    expect(
      () => h.commands.undoAction(engineUlid(1)),
      throwsA(isA<UnimplementedError>()),
    );
  });

  test('governed commands are delegated only after the gate opens', () async {
    final h = _Harness(governed: true);
    expect(
      await h.commands.applyGovernedChange(_governedAction),
      const CaptureResult.success(),
    );
    expect(h.log, ['settings', 'gate', 'governed']);
    h.log.clear();
    await h.commands.undoAction(engineUlid(1));
    expect(h.log, ['settings', 'gate', 'governed']);
  });

  test('governed pending failures are listed after the event ones, and '
      'retried through the governed commands after the gate', () async {
    final h = _Harness(governed: true);
    final failure = PendingFailure(
      id: engineUlid(7),
      eventIds: const [],
      changeIds: [engineUlid(7)],
      reason: PendingFailureReason.permissionDenied,
    );
    h.governedFake!.failures = [failure];
    expect(await h.commands.watchPendingFailures().first, [failure]);
    expect(
      await h.commands.retry(engineUlid(7)),
      CaptureResult.success(changeIds: [engineUlid(7)]),
    );
    expect(h.log, ['settings', 'gate', 'governed retry']);
    expect(
      await h.commands.retry(engineUlid(8)),
      const CaptureResult.rejected(CaptureRejection.targetNotFound),
    );
  });

  test(
    'an unreadable settings history fails a governed command closed',
    () async {
      final h = _Harness(governed: true)..fakeReads.history = null;
      expect(
        await h.commands.applyGovernedChange(_governedAction),
        CaptureResult.locked(LockWindow(h.now, h.now)),
      );
      expect(await h.commands.undoAction(engineUlid(1)), isA<CaptureLocked>());
      expect(h.log, ['settings', 'settings'], reason: 'never delegated');
    },
  );

  test('node fixtures used above are the corpus nodes', () {
    expect(mishnayosCorpus().nodeForRef(berakhot2.ref), berakhot2);
    expect(const NodeEntry(level: 'seder', ref: 'Seder Zeraim'), zeraim);
  });
}
