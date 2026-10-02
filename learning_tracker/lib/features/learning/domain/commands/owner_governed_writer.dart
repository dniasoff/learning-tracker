/// The owner governed-write port the owner repositories write through
/// (Story 1.14, DNI-476, AD-38): every goal, main-track, order, program,
/// study-day, stage and scope write is one [GovernedAction] handed to
/// `LearningCommands.applyGovernedChange`, never a direct Firestore write.
///
/// Imports only `lib/domain/learner_state/**` and this directory.
library;

import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';

/// The subset of [LearningCommands] an owner repository writes through.
abstract interface class OwnerGovernedWriter {
  /// See [LearningCommands.applyGovernedChange].
  Future<CaptureResult> applyGovernedChange(GovernedAction action);

  /// See [LearningCommands.removeTrack].
  Future<CaptureResult> removeTrack(String curriculumId);

  /// See [LearningCommands.reAddTrack].
  Future<CaptureResult> reAddTrack(String curriculumId);
}

/// No [LearningCommands] are available for the write: no active learner
/// yet, the account is not ready, or the session is a tutored one (tutor
/// writes go through callables, AD-53). Nothing was written.
final class GovernedWriterNotReadyException implements Exception {
  /// Creates the exception.
  const GovernedWriterNotReadyException();

  @override
  String toString() =>
      'GovernedWriterNotReadyException: no owner LearningCommands for this '
      'write (no active learner, or a tutored session)';
}

/// An owner governed write that the commands did not report as saved:
/// rejected, locked, online-only while offline, or not saved (the retry
/// then lives in `LearningCommands.watchPendingFailures`, AD-54).
final class GovernedWriteRejectedException implements Exception {
  /// Creates the exception for [result].
  const GovernedWriteRejectedException(this.result);

  /// The commands' result.
  final CaptureResult result;

  @override
  String toString() => 'GovernedWriteRejectedException($result)';
}

/// An [OwnerGovernedWriter] that resolves the active learner's
/// [LearningCommands] on every write, so it never holds a stale scope.
final class LearningCommandsOwnerWriter implements OwnerGovernedWriter {
  /// Creates the writer over [resolve] (null while not ready).
  const LearningCommandsOwnerWriter(this._resolve);

  final Future<LearningCommands?> Function() _resolve;

  @override
  Future<CaptureResult> applyGovernedChange(GovernedAction action) async =>
      (await _commands()).applyGovernedChange(action);

  @override
  Future<CaptureResult> removeTrack(String curriculumId) async =>
      (await _commands()).removeTrack(curriculumId);

  @override
  Future<CaptureResult> reAddTrack(String curriculumId) async =>
      (await _commands()).reAddTrack(curriculumId);

  Future<LearningCommands> _commands() async {
    final commands = await _resolve();
    if (commands == null) throw const GovernedWriterNotReadyException();
    return commands;
  }
}

/// Returns [result] when it is a success, else throws
/// [GovernedWriteRejectedException].
CaptureSuccess requireOwnerSuccess(CaptureResult result) {
  if (result is CaptureSuccess) return result;
  throw GovernedWriteRejectedException(result);
}

/// Applies [action] through [writer] and returns the success, or throws
/// [GovernedWriteRejectedException] for any other result. A queued success
/// (offline; the SDK owns the queue) is a success.
Future<CaptureSuccess> applyOwnerAction(
  OwnerGovernedWriter writer,
  GovernedAction action,
) async {
  return requireOwnerSuccess(await writer.applyGovernedChange(action));
}
