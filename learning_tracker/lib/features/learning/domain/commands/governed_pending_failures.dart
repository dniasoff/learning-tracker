/// AD-54 Recovery for governed writes (AD-38 Batching; DNI-470 / Story 1.8).
///
/// A governed action is written as self-contained units: one batch per
/// entity (its docs plus its change-log entry), or the whole action through
/// the online-only oversized callable. A unit the server does not save,
/// whether it fails within the ack wait or after it was reported queued,
/// becomes one [PendingFailure] ("not saved — retry"). That failure holds
/// the SAME immutable unit, so the retry re-sends the identical entry ids,
/// `at`, actor and payload. A change-log entry that already landed makes
/// the replay a no-op, and the callable is idempotent on the `actionId`,
/// so a retry never duplicates a change.
///
/// Like the event dispatcher, there is no outbox: pending failures live in
/// memory for the session.
///
/// Imports only `lib/domain/learner_state/**`, this directory and `dart:`.
library;

import 'dart:async';
import 'dart:collection';

import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/oversized_governed_write_port.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_write_dispatcher.dart';

/// One governed write that can be re-sent unchanged.
final class GovernedWriteUnit {
  /// Creates a unit; [send] must write the same payload on every call.
  GovernedWriteUnit({
    required this.id,
    required this.actionId,
    required List<String> changeIds,
    required this.writeCount,
    required this.queueable,
    required Future<void> Function() send,
  }) : changeIds = List.unmodifiable(changeIds),
       _send = send;

  /// The pending-failure id: the entry id of an entity batch, or the action
  /// id of an oversized callable request.
  final String id;

  /// The governed action this unit belongs to.
  final String actionId;

  /// The change-log entries the unit writes.
  final List<String> changeIds;

  /// Documents in the unit (reported, enums and counts only).
  final int writeCount;

  /// Whether the SDK queues the unit offline (an owner batch), so an
  /// unacknowledged send counts as queued after the ack wait. The callable
  /// is online-only and is always awaited.
  final bool queueable;

  final Future<void> Function() _send;

  /// Sends the unit's identical payload.
  Future<void> send() => _send();
}

final class _Pending {
  _Pending(this.unit, this.reason);

  final GovernedWriteUnit unit;
  PendingFailureReason reason;

  /// Whether a retry is awaiting the server; the failure stays tracked but
  /// is withheld until that attempt fails.
  bool inFlight = false;

  PendingFailure get failure => PendingFailure(
    id: unit.id,
    eventIds: const [],
    changeIds: unit.changeIds,
    reason: reason,
  );
}

/// The governed pending failures of one learner scope.
final class GovernedPendingFailures {
  /// Creates the tracker.
  GovernedPendingFailures({
    LearningFailureReporter? reporter,
    this.ackWait = defaultLearningAckWait,
  }) : _reporter = reporter;

  /// The bounded wait for a queueable retry's acknowledgement.
  final Duration ackWait;

  final LearningFailureReporter? _reporter;
  final LinkedHashMap<String, _Pending> _pending = LinkedHashMap();
  final StreamController<List<PendingFailure>> _changes =
      StreamController<List<PendingFailure>>.broadcast();

  static const _notSaved = CaptureResult.rejected(CaptureRejection.notSaved);

  /// The current pending failures, oldest first, without those whose retry
  /// is in flight.
  List<PendingFailure> get pendingFailures => List.unmodifiable(
    _pending.values.where((p) => !p.inFlight).map((p) => p.failure),
  );

  /// [pendingFailures] now, then after every change.
  Stream<List<PendingFailure>> watchPendingFailures() async* {
    yield pendingFailures;
    yield* _changes.stream;
  }

  /// The [PendingFailureReason] of a governed write [error]: the server
  /// code of a [PermanentWriteRejection], else [PendingFailureReason.other].
  static PendingFailureReason reasonOf(Object error) => switch (error) {
    PermanentWriteRejection(:final code) => pendingFailureReasonOf(code),
    _ => PendingFailureReason.other,
  };

  /// Records [unit] of [command] as not saved because of [error], and
  /// reports it.
  void record(
    LearningCommandKind command,
    GovernedWriteUnit unit,
    Object error,
  ) {
    final reason = reasonOf(error);
    _pending[unit.id] = _Pending(unit, reason);
    _notify();
    _reporter?.writeRejected(
      command: command,
      reason: reason,
      writeCount: unit.writeCount,
    );
  }

  /// Re-sends the unit of pending failure [id] unchanged. Null when [id] is
  /// not a governed pending failure.
  ///
  /// The failure stays tracked until the server acknowledges the retry. A
  /// queueable retry not acknowledged within [ackWait] is reported queued
  /// and still watched. An offline callable retry is
  /// [CaptureResult.onlineRequired] and stays pending. A second retry while
  /// one is in flight sends nothing and reports it queued.
  Future<CaptureResult?> retry(String id) async {
    final pending = _pending[id];
    if (pending == null) return null;
    final unit = pending.unit;
    if (pending.inFlight) return _success(unit, queued: true);
    pending.inFlight = true;
    _notify();
    final sending = unit.send();
    try {
      if (!unit.queueable) {
        await sending;
        _acked(pending);
        return _success(unit, queued: false);
      }
      final acked = await sending
          .then((_) => true)
          .timeout(ackWait, onTimeout: () => false);
      if (!acked) {
        unawaited(
          sending.then<void>(
            (_) => _acked(pending),
            onError: (Object error) => _failed(pending, error),
          ),
        );
        return _success(unit, queued: true);
      }
      _acked(pending);
      return _success(unit, queued: false);
    } on OnlineRequiredException {
      _restore(pending);
      return const CaptureResult.onlineRequired();
    } on Object catch (error) {
      _failed(pending, error);
      return _notSaved;
    }
  }

  static CaptureResult _success(
    GovernedWriteUnit unit, {
    required bool queued,
  }) => CaptureResult.success(
    changeIds: unit.changeIds,
    actionId: unit.actionId,
    queued: queued,
  );

  void _acked(_Pending pending) {
    if (identical(_pending[pending.unit.id], pending)) {
      _pending.remove(pending.unit.id);
      _notify();
    }
  }

  void _restore(_Pending pending) {
    if (!identical(_pending[pending.unit.id], pending)) return;
    pending.inFlight = false;
    _notify();
  }

  void _failed(_Pending pending, Object error) {
    if (!identical(_pending[pending.unit.id], pending)) return;
    pending
      ..reason = reasonOf(error)
      ..inFlight = false;
    _notify();
    _reporter?.writeRejected(
      command: LearningCommandKind.retry,
      reason: pending.reason,
      writeCount: pending.unit.writeCount,
    );
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(pendingFailures);
  }

  /// Closes the pending-failure stream.
  Future<void> dispose() => _changes.close();
}
