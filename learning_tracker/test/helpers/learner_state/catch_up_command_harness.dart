/// Hermetic rig for the Story 3.3 (DNI-506) catch-up command tests: one
/// device's real `DefaultLearningCommands` over in-memory reads and a
/// write port that can hold (queue offline) or reject chosen chunks, at a
/// fixed learner clock over the DNI-505 catch-up history.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/catch_up_card_projection.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_event_plans.dart';

import '../learner_state_fixtures.dart';
import 'catch_up_card_harness.dart';
import 'engine_fixtures.dart';
import 'fake_learning_commands.dart';

/// The owner session.
const catchUpParent = Actor(
  uid: 'owner-uid',
  role: ActorRole.parent,
  displayName: '',
);

/// The child session of the same profile.
const catchUpChild = Actor(
  uid: 'owner-uid',
  role: ActorRole.child,
  displayName: '',
);

/// The Shabbos lock of [catchUpHistory] (2026-10-10).
LockWindow catchUpShabbosLock() =>
    catchUpCardWindowsAt(catchUpHistory, catchUpSunday).single.lock;

/// A main-track leaf of the Shabbos card.
CatchUpLeaf mainCatchUpLeaf(
  String ref, {
  int? stage = 1,
  String learnedOn = catchUpShabbos,
  String curriculumId = engineCurriculum,
}) => CatchUpLeaf(
  curriculumId: curriculumId,
  ref: ref,
  source: LearningEvent.sourceMain,
  learnedOn: learnedOn,
  stage: stage,
);

/// A sub-track leaf of the Shabbos card.
CatchUpLeaf subCatchUpLeaf(
  String ref, {
  String subTrackId = ulidB,
  String learnedOn = catchUpShabbos,
}) => CatchUpLeaf(
  curriculumId: engineCurriculum,
  ref: ref,
  source: subTrackId,
  learnedOn: learnedOn,
);

/// A *Yes, all of it* action of the Shabbos card over [leaves].
CatchUpAction catchUpAllAction(List<CatchUpLeaf> leaves) => CatchUpAction(
  lock: catchUpShabbosLock(),
  mode: CatchUpMode.all,
  lockedDaysOffered: 1,
  leaves: leaves,
);

/// A write port whose commit attempts can be held (the SDK queued them
/// offline) or rejected for good, by attempt index (0-based).
final class ScriptedWritePort implements LearningWritePort {
  /// Attempt indexes the server rejects for good.
  final Set<int> rejectAttempts = {};

  /// Attempt indexes held until [release] / [reject].
  final Set<int> holdAttempts = {};

  /// Every committed chunk, in order.
  final List<LearningWriteChunk> chunks = [];

  /// Every commit attempt, in order.
  final List<LearningWriteChunk> attempts = [];

  final Map<int, Completer<void>> _held = {};

  /// Acknowledges held attempt [index].
  void release(int index) => _held.remove(index)!.complete();

  /// Rejects held attempt [index] for good.
  void reject(int index, [String code = 'permission-denied']) =>
      _held.remove(index)!.completeError(PermanentWriteRejection(code));

  /// The events of every committed chunk.
  List<LearningEvent> get written => [for (final c in chunks) ...c.events];

  /// The awards of every committed chunk.
  List<PointsAward> get awards => [for (final c in chunks) ...c.awards];

  @override
  Future<void> commit(LearnerScope scope, LearningWriteChunk chunk) async {
    final index = attempts.length;
    attempts.add(chunk);
    if (rejectAttempts.contains(index)) {
      throw const PermanentWriteRejection('permission-denied');
    }
    if (holdAttempts.contains(index)) {
      final held = Completer<void>();
      _held[index] = held;
      await held.future;
    }
    chunks.add(chunk);
  }
}

/// One device's commands for the catch-up learner.
final class CatchUpCommandHarness {
  /// Creates the device at [now] (Sunday noon by default) as [actor].
  CatchUpCommandHarness({
    DateTime? now,
    this.actor = catchUpParent,
    LearnerSettingsHistory? history,
    int idSeed = 40000,
  }) : now = now ?? catchUpSunday,
       _seq = idSeed {
    reads = FakeLearningCommandReads(
      history: history ?? catchUpHistory,
      corpora: {engineCurriculum: mishnayosCorpus()},
    );
    commands = DefaultLearningCommands(
      scope: catchUpScope,
      actor: actor,
      reads: reads,
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

  /// The device clock.
  DateTime now;

  /// The session actor.
  final Actor actor;

  /// The command reads.
  late final FakeLearningCommandReads reads;

  /// The write port.
  final port = ScriptedWritePort();

  /// The analytics emitter.
  final analytics = RecordingLearningAnalytics();

  /// The failure reporter.
  final reporter = RecordingLearningFailureReporter();

  /// The commands.
  late final DefaultLearningCommands commands;

  int _seq;

  /// The committed events.
  List<LearningEvent> get written => port.written;

  /// The log as the commands judge it now.
  LearningLogView log() => LearningLogView.of(written, reads.history!, now);

  /// Makes everything committed so far visible to the command reads.
  void sync() {
    final ids = {for (final e in reads.eventLog) e.id};
    reads.eventLog.addAll(written.where((e) => ids.add(e.id)));
  }

  /// The current pending failures.
  Future<List<PendingFailure>> pending() =>
      commands.watchPendingFailures().first;
}
