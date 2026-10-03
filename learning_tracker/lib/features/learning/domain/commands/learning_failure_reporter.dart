/// The observability seam for permanently rejected learning writes
/// (AD-54 Observability, AD-30).
///
/// `LearningCommands` reports every write the server rejects for good
/// here. The production binding sends a Crashlytics non-fatal whose error
/// carries ONLY these enums and counts: never a ref, profile id, learner
/// name or raw exception text (AD-47 privacy, PV-1).
library;

import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';

/// The command whose write was rejected.
enum LearningCommandKind {
  /// `capture`.
  capture('capture'),

  /// `voidEvent`.
  voidEvent('void'),

  /// `replace`.
  replace('replace'),

  /// `unlearn`.
  unlearn('unlearn'),

  /// `undoEvents`.
  undo('undo'),

  /// `applyGovernedChange` (DNI-470).
  governedChange('governed_change'),

  /// `undoAction` (DNI-470).
  undoAction('undo_action'),

  /// `retry` of a pending failure.
  retry('retry'),

  /// `importBackup` (DNI-482, AD-49 replay).
  backupImport('backup_import');

  const LearningCommandKind(this.storage);

  /// The value reported.
  final String storage;
}

/// Receives permanently rejected learning writes.
abstract interface class LearningFailureReporter {
  /// One atomic write of [command] holding [writeCount] documents was
  /// rejected for [reason].
  void writeRejected({
    required LearningCommandKind command,
    required PendingFailureReason reason,
    required int writeCount,
  });
}

/// The error a [LearningFailureReporter] binding records: enums and a
/// count only, so its `toString` is safe for Crashlytics.
final class LearningWriteRejectedError implements Exception {
  /// Creates the error.
  const LearningWriteRejectedError({
    required this.command,
    required this.reason,
    required this.writeCount,
  });

  /// The command whose write was rejected.
  final LearningCommandKind command;

  /// The server's terminal reason.
  final PendingFailureReason reason;

  /// Documents in the rejected write.
  final int writeCount;

  @override
  String toString() =>
      'LearningWriteRejected(command: ${command.storage}, '
      'reason: ${reason.name}, writes: $writeCount)';
}
