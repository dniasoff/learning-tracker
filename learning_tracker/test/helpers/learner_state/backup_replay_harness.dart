/// A [DefaultLearningCommands] wired for the DNI-482 AD-49 backup replay
/// over the in-memory ports, with one shared write log so tests can
/// assert the replay order. Shared by the replay command tests and the
/// backup round-trip integration test.
library;

import 'dart:async';

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/ports/backup_record_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/change_log_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/backup_import_replay.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';

import '../learner_state_fixtures.dart';
import 'c0_fixtures.dart';
import 'engine_fixtures.dart';
import 'fake_learning_commands.dart';
import 'in_memory_ports.dart';

/// An in-memory [BackupRecordWritePort]: stores every committed record by
/// scope; [failCommits] makes the listed commit attempts (0-based) throw
/// [failWith].
final class InMemoryBackupRecordWritePort implements BackupRecordWritePort {
  /// Creates the port, appending `records` to [log] on each commit.
  InMemoryBackupRecordWritePort([List<String>? log]) : log = log ?? [];

  /// The shared write log.
  final List<String> log;

  /// Every committed batch, in order.
  final List<List<BackupRecordWrite>> commits = [];

  /// Commit attempts (0-based) that throw [failWith].
  final Set<int> failCommits = {};

  /// The rejection [failCommits] throw.
  Exception failWith = const PermanentWriteRejection('permission-denied');

  int _attempts = 0;
  final Map<LearnerScope, Map<String, Map<String, Object?>>> _docs = {};

  /// The stored `{collection}/{docId}` docs of [scope].
  Map<String, Map<String, Object?>> docsOf(LearnerScope scope) =>
      Map.unmodifiable(_docs[scope] ?? const {});

  @override
  Future<void> commit(
    LearnerScope scope,
    List<BackupRecordWrite> writes,
  ) async {
    if (writes.length > BackupRecordWritePort.maxWrites) {
      throw ArgumentError('over budget');
    }
    final attempt = _attempts++;
    if (failCommits.contains(attempt)) throw failWith;
    log.add('records');
    commits.add(writes);
    final docs = _docs.putIfAbsent(scope, () => {});
    for (final w in writes) {
      docs['${w.collection.name}/${w.docId}'] = w.fields;
    }
  }
}

/// A [ChangeLogRepository] that logs each governed batch to [log] and can
/// fail chosen entries.
final class LoggingChangeLog implements ChangeLogRepository {
  /// Wraps [inner].
  LoggingChangeLog(this.inner, this.log);

  /// Where accepted batches land.
  final InMemoryChangeLogRepository inner;

  /// The shared write log.
  final List<String> log;

  /// Entry ids whose commit throws [failWith].
  final Set<String> fail = {};

  /// The failure.
  Exception failWith = const PermanentWriteRejection('permission-denied');

  /// Entry ids whose next commit waits for its completer (the SDK queued
  /// it offline): completing it acknowledges the batch, completing it with
  /// an error rejects it.
  final Map<String, Completer<void>> hold = {};

  @override
  Future<void> commitGoverned(LearnerScope scope, GovernedBatch batch) async {
    final held = hold.remove(batch.entry.id);
    if (held != null) await held.future;
    if (fail.contains(batch.entry.id)) throw failWith;
    log.add('governed:${batch.entry.entity.storage}');
    await inner.commitGoverned(scope, batch);
  }

  @override
  Future<List<ChangeLogEntry>> entriesOfAction(
    LearnerScope scope,
    String actionId,
  ) => inner.entriesOfAction(scope, actionId);

  @override
  Stream<CompleteRead<ChangeLogEntry>> watchIntentHistory(LearnerScope scope) =>
      inner.watchIntentHistory(scope);

  @override
  Stream<bool> watchIsReverted(LearnerScope scope, String actionId) =>
      inner.watchIsReverted(scope, actionId);
}

/// A [SubTrackRepository] that logs each change to [log].
final class LoggingSubTracks implements SubTrackRepository {
  /// Wraps [inner].
  LoggingSubTracks(this.inner, this.log);

  /// Where changes land.
  final InMemorySubTrackRepository inner;

  /// The shared write log.
  final List<String> log;

  @override
  Future<void> applyGovernedChange(
    LearnerScope scope,
    SubTrackChange change,
  ) async {
    log.add(change.isCreate ? 'subTrack:create' : 'subTrack:update');
    await inner.applyGovernedChange(scope, change);
  }

  @override
  Stream<CompleteRead<SubTrack>> watchAll(LearnerScope scope) =>
      inner.watchAll(scope);
}

/// A [LearningWritePort] that logs each chunk and can reject chosen
/// commit attempts (0-based) for good.
final class LoggingWritePort implements LearningWritePort {
  /// Wraps [inner].
  LoggingWritePort(this.inner, this.log);

  /// Where accepted chunks land.
  final InMemoryLearningWritePort inner;

  /// The shared write log.
  final List<String> log;

  /// Commit attempts (0-based) that throw [PermanentWriteRejection].
  final Set<int> rejectAttempts = {};

  /// Every chunk attempted, in order.
  final List<LearningWriteChunk> attempts = [];

  @override
  Future<void> commit(LearnerScope scope, LearningWriteChunk chunk) async {
    final attempt = attempts.length;
    attempts.add(chunk);
    if (rejectAttempts.remove(attempt)) {
      throw const PermanentWriteRejection('permission-denied');
    }
    log.add('events');
    await inner.commit(scope, chunk);
  }
}

/// The replay commands under test with their in-memory ports.
final class BackupReplayHarness {
  /// Creates the harness at [now]; ids are `engineUlid(firstId)`, `+1`, ...
  BackupReplayHarness({
    LearnerScope? scope,
    DateTime? now,
    int firstId = 5000,
    LearnerSettingsHistory? settingsHistory,
    CaptureGate gate = const LockWindowCaptureGate(),
    this.ackWait = const Duration(milliseconds: 20),
  }) : scope = scope ?? c0Scope(),
       now = now ?? engineAt(600),
       _next = firstId {
    changeLog = LoggingChangeLog(store, log);
    subTrackPort = LoggingSubTracks(subTracks, log);
    writePort = LoggingWritePort(events, log);
    records = InMemoryBackupRecordWritePort(log);
    reads = FakeLearningCommandReads(
      history: settingsHistory ?? c0SettingsHistory(),
    );
    commands = DefaultLearningCommands(
      scope: this.scope,
      actor: parentActor,
      reads: reads,
      writePort: writePort,
      gate: gate,
      analytics: RecordingLearningAnalytics(),
      failureReporter: failureReporter,
      clock: () => this.now,
      newUlid: (_) => engineUlid(_next++),
      ackWait: ackWait,
      backupReplay: BackupImportReplay(
        scope: this.scope,
        changeLog: changeLog,
        subTracks: subTrackPort,
        reader: store,
        writePort: writePort,
        records: records,
        failureReporter: failureReporter,
        ackWait: ackWait,
      ),
    );
  }

  int _next;

  /// The destination scope.
  final LearnerScope scope;

  /// The command instant.
  final DateTime now;

  /// The ack wait of every write.
  final Duration ackWait;

  /// Every write in order: `governed:<entity>`, `subTrack:create|update`,
  /// `events`, `records`.
  final List<String> log = [];

  /// Governed docs and the change log.
  final InMemoryChangeLogRepository store = InMemoryChangeLogRepository();

  /// Sub-track rows.
  final InMemorySubTrackRepository subTracks = InMemorySubTrackRepository();

  /// Committed event chunks.
  final InMemoryLearningWritePort events = InMemoryLearningWritePort();

  /// The failure reporter.
  final RecordingLearningFailureReporter failureReporter =
      RecordingLearningFailureReporter();

  /// The logging ports.
  late final LoggingChangeLog changeLog;

  /// The logging sub-track port.
  late final LoggingSubTracks subTrackPort;

  /// The logging event port.
  late final LoggingWritePort writePort;

  /// The record port.
  late final InMemoryBackupRecordWritePort records;

  /// The reads (settings history for the gate, points amounts).
  late final FakeLearningCommandReads reads;

  /// The commands.
  late final DefaultLearningCommands commands;
}
