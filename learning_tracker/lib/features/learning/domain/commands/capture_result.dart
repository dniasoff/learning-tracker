/// The outcome of every `LearningCommands` call (C0, DNI-524).
///
/// Imports only `lib/domain/learner_state/**` and `dart:` (AC-1).
library;

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';

/// What a command did.
sealed class CaptureResult {
  const CaptureResult();

  /// The command was applied (or [queued] offline).
  const factory CaptureResult.success({
    List<String> eventIds,
    List<String> changeIds,
    String? actionId,
    bool queued,
    List<ChangedSinceField> changedSince,
    List<String> rejectedEventIds,
    List<LeafRef> alreadyRecordedRefs,
    List<String> keptNotCounted,
  }) = CaptureSuccess;

  /// Refused: the learner is inside lock [window] (AD-36).
  const factory CaptureResult.locked(LockWindow window) = CaptureLocked;

  /// Refused: a child session may not do this.
  const factory CaptureResult.childLimit() = CaptureChildLimit;

  /// Refused: the command needs a connection.
  const factory CaptureResult.onlineRequired() = CaptureOnlineRequired;

  /// Refused for [reason]; a sub-track command names its AD-45
  /// [violations].
  const factory CaptureResult.rejected(
    CaptureRejection reason, {
    List<SubTrackViolation> violations,
  }) = CaptureRejected;
}

/// The command was applied.
final class CaptureSuccess extends CaptureResult {
  /// Creates a success.
  const CaptureSuccess({
    this.eventIds = const [],
    this.changeIds = const [],
    this.actionId,
    this.queued = false,
    this.changedSince = const [],
    this.rejectedEventIds = const [],
    this.alreadyRecordedRefs = const [],
    this.keptNotCounted = const [],
  });

  /// The refs of a `skipRecorded` capture that the persisted log already
  /// recorded in this track, so no event was planned for them (DNI-501
  /// AC-2); in the caller's order. Empty for every other command.
  final List<LeafRef> alreadyRecordedRefs;

  /// The learning events written.
  final List<String> eventIds;

  /// The learning events of a partly rejected command that the server
  /// rejected for good (each chunk is now in
  /// `LearningCommands.watchPendingFailures` with a retry; AD-54
  /// Recovery); disjoint from [eventIds]. Empty unless some, but not
  /// every, chunk was rejected within the ack window — a command whose
  /// every chunk is rejected is [CaptureRejection.notSaved]. Added by
  /// DNI-501 so a caller can tell which of its leaves were not saved.
  final List<String> rejectedEventIds;

  /// The change-log entries written.
  final List<String> changeIds;

  /// The governed action id, if any.
  final String? actionId;

  /// Whether the write is queued offline rather than confirmed.
  final bool queued;

  /// Fields someone else changed since the caller last read them.
  final List<ChangedSinceField> changedSince;

  /// Events of [eventIds] that were stored but are not counted: a tutor
  /// callable stamped them inside the learner's lock window (AD-36,
  /// deviation #2; Story 1.24 / DNI-486 AC-7). They are kept, never rolled
  /// back, and no Undo is offered for them; surfaces show "Kept, not
  /// counted" and change no position or count for them.
  final List<String> keptNotCounted;

  /// [eventIds] minus [keptNotCounted]: the events that count.
  List<String> get countedEventIds => keptNotCounted.isEmpty
      ? eventIds
      : [
          for (final id in eventIds)
            if (!keptNotCounted.contains(id)) id,
        ];

  @override
  bool operator ==(Object other) =>
      other is CaptureSuccess &&
      _listEquals(other.eventIds, eventIds) &&
      _listEquals(other.changeIds, changeIds) &&
      other.actionId == actionId &&
      other.queued == queued &&
      _listEquals(other.changedSince, changedSince) &&
      _listEquals(other.rejectedEventIds, rejectedEventIds) &&
      _listEquals(other.alreadyRecordedRefs, alreadyRecordedRefs) &&
      _listEquals(other.keptNotCounted, keptNotCounted);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(eventIds),
    Object.hashAll(changeIds),
    actionId,
    queued,
    Object.hashAll(changedSince),
    Object.hashAll(rejectedEventIds),
    Object.hashAll(alreadyRecordedRefs),
    Object.hashAll(keptNotCounted),
  );

  @override
  String toString() =>
      'CaptureResult.success(${eventIds.length} events, '
      '${changeIds.length} changes, queued: $queued'
      '${keptNotCounted.isEmpty ? '' : ', ${keptNotCounted.length} kept, not counted'})';
}

/// Refused inside a lock window.
final class CaptureLocked extends CaptureResult {
  /// Creates the refusal.
  const CaptureLocked(this.window);

  /// The lock in force.
  final LockWindow window;

  @override
  bool operator ==(Object other) =>
      other is CaptureLocked && other.window == window;

  @override
  int get hashCode => window.hashCode;

  @override
  String toString() => 'CaptureResult.locked($window)';
}

/// Refused for a child session.
final class CaptureChildLimit extends CaptureResult {
  /// Creates the refusal.
  const CaptureChildLimit();

  @override
  bool operator ==(Object other) => other is CaptureChildLimit;

  @override
  int get hashCode => (CaptureChildLimit).hashCode;

  @override
  String toString() => 'CaptureResult.childLimit()';
}

/// Refused offline.
final class CaptureOnlineRequired extends CaptureResult {
  /// Creates the refusal.
  const CaptureOnlineRequired();

  @override
  bool operator ==(Object other) => other is CaptureOnlineRequired;

  @override
  int get hashCode => (CaptureOnlineRequired).hashCode;

  @override
  String toString() => 'CaptureResult.onlineRequired()';
}

/// Refused for [reason].
final class CaptureRejected extends CaptureResult {
  /// Creates the refusal. [violations] names each AD-45 rule a sub-track
  /// command broke (Story 2.1); it is empty for every other refusal.
  const CaptureRejected(this.reason, {this.violations = const []});

  /// Why.
  final CaptureRejection reason;

  /// The typed sub-track validation failures, each naming the violated
  /// limit (with [reason] [CaptureRejection.invalid]).
  final List<SubTrackViolation> violations;

  @override
  bool operator ==(Object other) =>
      other is CaptureRejected &&
      other.reason == reason &&
      _listEquals(other.violations, violations);

  @override
  int get hashCode => Object.hash(reason, Object.hashAll(violations));

  @override
  String toString() => violations.isEmpty
      ? 'CaptureResult.rejected(${reason.name})'
      : 'CaptureResult.rejected(${reason.name}, $violations)';
}

/// Why a command was rejected.
enum CaptureRejection {
  /// The target event or action does not exist.
  targetNotFound,

  /// A void must target a `learn` event.
  voidTargetNotLearn,

  /// The target was recorded in a lock window and is ignored.
  lockIgnoredTarget,

  /// The target is itself an undo, which is final.
  undoIsFinal,

  /// Undo is not offered for the target.
  undoNotOffered,

  /// The command's arguments are invalid.
  invalid,

  /// The server rejected every write of the command for good; each one is
  /// in `LearningCommands.watchPendingFailures` with a retry (AD-54
  /// Recovery, parent AD-30). Added by DNI-469.
  notSaved,

  /// A tutor's write was refused because the learner's parent turned off
  /// "Can edit learning" for the grant (AD-53 per-call check). Nothing was
  /// written and nothing is pending; the surface says "{learner}'s parent
  /// has turned off editing". Added by DNI-486 for DNI-487 AC-6.
  editingTurnedOff,
}

/// A field someone else changed since the caller read it.
final class ChangedSinceField {
  /// Creates the record.
  const ChangedSinceField(this.key, this.changedBy);

  /// The changed field.
  final ChangedFieldKey key;

  /// Who changed it.
  final Actor changedBy;

  @override
  bool operator ==(Object other) =>
      other is ChangedSinceField &&
      other.key == key &&
      other.changedBy == changedBy;

  @override
  int get hashCode => Object.hash(key, changedBy);

  @override
  String toString() => 'ChangedSinceField($key, $changedBy)';
}

/// Why a queued write failed for good.
enum PendingFailureReason {
  /// `permission-denied`.
  permissionDenied,

  /// `invalid-argument`.
  invalidArgument,

  /// `failed-precondition`.
  failedPrecondition,

  /// Anything else.
  other,
}

/// A queued write that the server rejected and the user must resolve.
final class PendingFailure {
  /// Creates the record.
  const PendingFailure({
    required this.id,
    required this.eventIds,
    required this.changeIds,
    required this.reason,
    this.isUndo = false,
  });

  /// The failure id (passed to `LearningCommands.retry`).
  final String id;

  /// The learning events in the failed write.
  final List<String> eventIds;

  /// The change-log entries in the failed write.
  final List<String> changeIds;

  /// Why it failed.
  final PendingFailureReason reason;

  /// Whether the failed write is an undo (`undoEvents` / `undoAction`), so
  /// the notice says the undo couldn't be saved (DNI-514 AC-9, UX-DR-139).
  final bool isUndo;

  @override
  bool operator ==(Object other) =>
      other is PendingFailure &&
      other.id == id &&
      _listEquals(other.eventIds, eventIds) &&
      _listEquals(other.changeIds, changeIds) &&
      other.reason == reason &&
      other.isUndo == isUndo;

  @override
  int get hashCode => Object.hash(
    id,
    Object.hashAll(eventIds),
    Object.hashAll(changeIds),
    reason,
    isUndo,
  );

  @override
  String toString() => 'PendingFailure($id, ${reason.name})';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
