/// What a Change history Undo did (DNI-514 / Story 4.6), read from the
/// [CaptureResult] of `LearningCommands.undoAction` / `undoEvents`.
///
/// The commands keep the C0 [CaptureResult] contract; this is the one
/// classification every undo surface shows, so "partly undone",
/// "nothing to undo — changed since", "online required" and "not saved —
/// retry" mean the same everywhere (AC-1, AC-3, AC-8, AC-9).
///
/// Imports only `lib/domain/learner_state/**`, this directory and `dart:`.
library;

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';

/// The outcome of one undo.
sealed class UndoResult {
  const UndoResult();

  /// Classifies the [result] of an undo command.
  factory UndoResult.of(CaptureResult result) => switch (result) {
    CaptureSuccess(:final eventIds, :final changeIds, :final changedSince)
        when eventIds.isEmpty && changeIds.isEmpty =>
      UndoNothingToUndo(changedSince),
    CaptureSuccess() => UndoApplied(
      actionId: result.actionId,
      changeIds: result.changeIds,
      eventIds: result.eventIds,
      queued: result.queued,
      changedSince: result.changedSince,
    ),
    CaptureOnlineRequired() => const UndoOnlineRequired(),
    CaptureLocked(:final window) => UndoLocked(window),
    CaptureRejected(reason: CaptureRejection.notSaved) => const UndoNotSaved(),
    CaptureRejected(:final reason) => UndoRefused(reason),
    CaptureChildLimit() => const UndoRefused(CaptureRejection.undoNotOffered),
  };
}

/// One new undo action was written (or queued offline, AC-9): every
/// eligible field was restored. [changedSince] lists the fields left alone
/// because someone changed them since (AC-3); empty for a full undo.
final class UndoApplied extends UndoResult {
  /// Creates the outcome.
  const UndoApplied({
    this.actionId,
    this.changeIds = const [],
    this.eventIds = const [],
    this.queued = false,
    this.changedSince = const [],
  });

  /// The undo's own `action_id` (governed undo; null for an event undo).
  final String? actionId;

  /// The change-log entries the undo wrote.
  final List<String> changeIds;

  /// The learning events the undo wrote (voids and copies, AC-6).
  final List<String> eventIds;

  /// Whether the undo is queued offline rather than confirmed (AC-9).
  final bool queued;

  /// The fields left alone, each with who changed it since.
  final List<ChangedSinceField> changedSince;

  /// Whether some fields were left alone (a partial undo).
  bool get isPartial => changedSince.isNotEmpty;

  /// Every id the undo wrote, change-log entries first.
  List<String> get writtenIds => [...changeIds, ...eventIds];
}

/// Nothing was eligible, so nothing was written and the original row stays
/// undoable-looking but not *Undone* (AC-3 "Nothing to undo — changed
/// since", AC-5).
final class UndoNothingToUndo extends UndoResult {
  /// Creates the outcome.
  const UndoNothingToUndo([this.changedSince = const []]);

  /// Why: every field someone changed since, with who.
  final List<ChangedSinceField> changedSince;
}

/// The undo spans more than one owner batch and needs a connection; nothing
/// was written (AC-8).
final class UndoOnlineRequired extends UndoResult {
  /// Creates the outcome.
  const UndoOnlineRequired();
}

/// The server refused the undo for good; each refused batch is a pending
/// failure with Retry (AC-9, AD-54 Recovery).
final class UndoNotSaved extends UndoResult {
  /// Creates the outcome.
  const UndoNotSaved();
}

/// The learner is inside a lock window; nothing was written (AD-36).
final class UndoLocked extends UndoResult {
  /// Creates the outcome.
  const UndoLocked(this.window);

  /// The lock in force.
  final LockWindow window;
}

/// The undo is not allowed: an undo is final, the target is a settings
/// seed or lock-ignored, already undone, or unknown (AC-2, AC-7).
final class UndoRefused extends UndoResult {
  /// Creates the outcome.
  const UndoRefused(this.reason);

  /// Why.
  final CaptureRejection reason;
}

/// [fields] grouped by who changed them since, in first-seen order, so a
/// surface can say "Deadline — changed since by Rav Cohen" once per actor.
List<(Actor, List<ChangedFieldKey>)> changedSinceByActor(
  List<ChangedSinceField> fields,
) {
  final grouped = <Actor, List<ChangedFieldKey>>{};
  for (final f in fields) {
    final keys = grouped.putIfAbsent(f.changedBy, () => []);
    if (!keys.contains(f.key)) keys.add(f.key);
  }
  return [for (final MapEntry(:key, :value) in grouped.entries) (key, value)];
}
