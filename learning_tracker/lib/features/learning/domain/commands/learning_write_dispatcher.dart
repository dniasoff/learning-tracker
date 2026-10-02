/// Commits a command's chunks and recovers from terminal rejections
/// (AD-54 Recovery, parent AD-8 / AD-30).
///
/// The Firestore SDK owns the offline queue: a commit future completes
/// only on server acknowledgement, so the dispatcher waits at most
/// [LearningWriteDispatcher.ackWait] and then reports the write as queued
/// (local success). It keeps listening: a chunk the server rejects for good
/// ([PermanentWriteRejection]), whenever that happens, becomes one
/// [PendingFailure] ("not saved — retry") holding the SAME immutable chunk,
/// and is reported to the [LearningFailureReporter] with enums only. Any
/// other failure is not app-queued (the SDK retries transient errors
/// itself). There is no outbox: pending failures live in memory for the
/// session.
library;

import 'dart:async';
import 'dart:collection';

import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';

/// How long a command waits for the server before treating its writes as
/// queued offline (mirrors `kFirestoreWriteAckTimeout`).
const Duration defaultLearningAckWait = Duration(seconds: 3);

/// The [PendingFailureReason] of a server error [code].
PendingFailureReason pendingFailureReasonOf(String code) => switch (code) {
  'permission-denied' => PendingFailureReason.permissionDenied,
  'invalid-argument' => PendingFailureReason.invalidArgument,
  'failed-precondition' => PendingFailureReason.failedPrecondition,
  _ => PendingFailureReason.other,
};

/// What happened to a command's chunks within the ack window.
final class DispatchOutcome {
  /// Creates the outcome.
  const DispatchOutcome({
    required this.eventIds,
    required this.learnEventIds,
    required this.queued,
    required this.rejectedChunks,
    required this.totalChunks,
  });

  /// Events of chunks not rejected within the window, in write order.
  final List<String> eventIds;

  /// The `learn` events among [eventIds] (what the achievement latch
  /// checks after the write, DNI-480), in write order.
  final List<String> learnEventIds;

  /// Whether some chunk was not yet acknowledged (queued offline).
  final bool queued;

  /// Chunks rejected within the window (each is now a pending failure).
  final int rejectedChunks;

  /// Chunks dispatched.
  final int totalChunks;

  /// Whether every chunk was rejected (nothing was saved).
  bool get allRejected => totalChunks > 0 && rejectedChunks == totalChunks;
}

enum _ChunkStatus { acked, rejected }

final class _Pending {
  _Pending(this.command, this.chunk, this.reason);

  final LearningCommandKind command;
  final LearningWriteChunk chunk;
  final PendingFailureReason reason;

  /// Whether a retry of [chunk] is awaiting the server. An in-flight entry
  /// stays tracked (it is the only retry handle for an unsaved chunk) but
  /// is not offered for retry again until the attempt fails.
  bool inFlight = false;

  PendingFailure get failure => PendingFailure(
    id: chunk.events.first.id,
    eventIds: [for (final e in chunk.events) e.id],
    changeIds: const [],
    reason: reason,
  );
}

/// Commits chunks for one [LearnerScope] and tracks pending failures.
final class LearningWriteDispatcher {
  /// Creates the dispatcher.
  LearningWriteDispatcher({
    required this.scope,
    required LearningWritePort port,
    required LearningFailureReporter reporter,
    this.ackWait = defaultLearningAckWait,
  }) : _port = port,
       _reporter = reporter;

  /// Where every chunk is written.
  final LearnerScope scope;

  /// The bounded wait for server acknowledgement.
  final Duration ackWait;

  final LearningWritePort _port;
  final LearningFailureReporter _reporter;
  final LinkedHashMap<String, _Pending> _pending = LinkedHashMap();
  final StreamController<List<PendingFailure>> _changes =
      StreamController<List<PendingFailure>>.broadcast();

  /// The current pending failures, oldest first; a failure whose retry
  /// is awaiting the server is withheld until that retry fails.
  List<PendingFailure> get pendingFailures => List.unmodifiable(
    _pending.values.where((p) => !p.inFlight).map((p) => p.failure),
  );

  /// [pendingFailures] now, then after every change.
  Stream<List<PendingFailure>> watchPendingFailures() async* {
    yield pendingFailures;
    yield* _changes.stream;
  }

  /// Commits [chunks] in order (all are handed to the SDK at once, which
  /// keeps their order) and waits up to [ackWait] for the server.
  ///
  /// A non-permanent error reported within the window is rethrown (the
  /// write was not accepted locally); after the window it is left to the
  /// SDK, which retries transient errors itself (no app-level queue).
  Future<DispatchOutcome> dispatch(
    LearningCommandKind command,
    List<LearningWriteChunk> chunks,
  ) => _dispatch(command, chunks);

  Future<DispatchOutcome> _dispatch(
    LearningCommandKind command,
    List<LearningWriteChunk> chunks, {
    bool retrying = false,
  }) async {
    final statuses = [
      for (final c in chunks) _commit(command, c, retrying: retrying),
    ];
    final settled = <int, _ChunkStatus>{};
    final all = Future.wait([
      for (var i = 0; i < statuses.length; i++)
        statuses[i].then((s) => settled[i] = s),
    ]);
    var timedOut = false;
    await all.timeout(
      ackWait,
      onTimeout: () {
        timedOut = true;
        return const [];
      },
    );
    if (timedOut) {
      // Keep the later outcomes observed (pending failures are recorded by
      // [_commit]); a late non-permanent error must not escape the zone.
      unawaited(all.then<void>((_) {}, onError: (Object _) {}));
    }
    final ids = <String>[];
    final learns = <String>[];
    var rejected = 0;
    for (var i = 0; i < chunks.length; i++) {
      if (settled[i] == _ChunkStatus.rejected) {
        rejected++;
      } else {
        for (final e in chunks[i].events) {
          ids.add(e.id);
          if (e.isLearn) learns.add(e.id);
        }
      }
    }
    return DispatchOutcome(
      eventIds: ids,
      learnEventIds: learns,
      queued: timedOut || settled.length < chunks.length,
      rejectedChunks: rejected,
      totalChunks: chunks.length,
    );
  }

  /// Re-commits the chunk of pending failure [id] unchanged (same ids,
  /// same timestamps). Null when there is no such pending failure.
  ///
  /// The failure stays tracked until the server acknowledges the retry:
  /// it is withheld from [pendingFailures] while the retry is in flight
  /// and restored on every outcome that is not an acknowledgement (a new
  /// rejection, any other error, in or after the ack window). A second
  /// retry while one is in flight writes nothing and reports it queued.
  Future<DispatchOutcome?> retry(String id) async {
    final pending = _pending[id];
    if (pending == null) return null;
    if (pending.inFlight) {
      return DispatchOutcome(
        eventIds: [for (final e in pending.chunk.events) e.id],
        learnEventIds: [
          for (final e in pending.chunk.events)
            if (e.isLearn) e.id,
        ],
        queued: true,
        rejectedChunks: 0,
        totalChunks: 1,
      );
    }
    pending.inFlight = true;
    _notify();
    return _dispatch(LearningCommandKind.retry, [
      pending.chunk,
    ], retrying: true);
  }

  Future<_ChunkStatus> _commit(
    LearningCommandKind command,
    LearningWriteChunk chunk, {
    bool retrying = false,
  }) async {
    final id = chunk.events.first.id;
    try {
      await _port.commit(scope, chunk);
      if (retrying && _pending.remove(id) != null) _notify();
      return _ChunkStatus.acked;
    } on PermanentWriteRejection catch (rejection) {
      final reason = pendingFailureReasonOf(rejection.code);
      _pending[id] = _Pending(command, chunk, reason);
      _notify();
      _reporter.writeRejected(
        command: command,
        reason: reason,
        writeCount: chunk.events.length + chunk.awards.length,
      );
      return _ChunkStatus.rejected;
    } on Object {
      // Not acknowledged: a retried failure becomes retryable again.
      final pending = retrying ? _pending[id] : null;
      if (pending != null) {
        pending.inFlight = false;
        _notify();
      }
      rethrow;
    }
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(pendingFailures);
  }

  /// Closes the pending-failure stream.
  Future<void> dispose() => _changes.close();
}
