/// The explicit lifecycle writes that are queued but not yet accepted by
/// the server (Story 2.8 / DNI-499; AD-54 Recovery).
///
/// A confirmed End, Delete or *Add next year* the server has not
/// acknowledged within the ack timeout comes back as
/// `CaptureSuccess(queued: true)`: applied to the local cache, not saved.
/// The surface that ran it hands it to [SubTrackLifecycleSyncNotifier.track],
/// which keeps it visibly pending ([SubTrackLifecycleSyncStatus.waiting])
/// until `LearningCommands.whenSubTrackChangeConfirmed` settles it:
///
/// * accepted → [SubTrackLifecycleSyncStatus.saved], and the sync panel
///   shows the success confirmation once, then acknowledges it;
/// * refused for good (the local write reverts) →
///   [SubTrackLifecycleSyncStatus.notSaved], with a retry through
///   `LearningCommands.retry` that re-sends the identical batch.
///
/// `subtrack_lifecycle` analytics follow the same acceptance: the commands
/// emit them only when the server accepts the write.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';

/// The explicit lifecycle write that was queued.
enum SubTrackLifecycleWrite {
  /// *End sub-track now*.
  end,

  /// *Delete track*.
  delete,

  /// *Add next year*.
  addNextYear,
}

/// Where a queued lifecycle write stands.
enum SubTrackLifecycleSyncStatus {
  /// Applied on this device; the server has not accepted it yet.
  waiting,

  /// The server refused it for good; it can be retried.
  notSaved,

  /// The server accepted it; its confirmation is still to be shown.
  saved,
}

/// One queued lifecycle write.
@immutable
final class SubTrackLifecycleSync {
  /// Creates the record.
  const SubTrackLifecycleSync({
    required this.changeId,
    required this.write,
    required this.name,
    this.yearLabel,
    this.status = SubTrackLifecycleSyncStatus.waiting,
  });

  /// The write's change-log entry id (its pending-failure id).
  final String changeId;

  /// What it does.
  final SubTrackLifecycleWrite write;

  /// The sub-track's name, for the copy.
  final String name;

  /// The academic-year label of an *Add next year*.
  final String? yearLabel;

  /// Where it stands.
  final SubTrackLifecycleSyncStatus status;

  /// This record at [status].
  SubTrackLifecycleSync withStatus(SubTrackLifecycleSyncStatus status) =>
      SubTrackLifecycleSync(
        changeId: changeId,
        write: write,
        name: name,
        yearLabel: yearLabel,
        status: status,
      );

  @override
  bool operator ==(Object other) =>
      other is SubTrackLifecycleSync &&
      other.changeId == changeId &&
      other.write == write &&
      other.name == name &&
      other.yearLabel == yearLabel &&
      other.status == status;

  @override
  int get hashCode => Object.hash(changeId, write, name, yearLabel, status);
}

/// The queued lifecycle writes of the current commands, by change id. A
/// new learner or session (new commands) starts empty.
final subTrackLifecycleSyncProvider =
    NotifierProvider<
      SubTrackLifecycleSyncNotifier,
      Map<String, SubTrackLifecycleSync>
    >(SubTrackLifecycleSyncNotifier.new);

/// See [subTrackLifecycleSyncProvider].
class SubTrackLifecycleSyncNotifier
    extends Notifier<Map<String, SubTrackLifecycleSync>> {
  @override
  Map<String, SubTrackLifecycleSync> build() {
    ref.watch(learningCommandsProvider);
    return const {};
  }

  /// Keeps [write], queued by [commands], pending until the server settles
  /// it.
  void track(SubTrackLifecycleSync write, LearningCommands commands) {
    state = {
      ...state,
      write.changeId: write.withStatus(SubTrackLifecycleSyncStatus.waiting),
    };
    unawaited(_settle(write.changeId, commands));
  }

  /// Re-sends the refused write [changeId] unchanged.
  Future<void> retry(String changeId) async {
    final write = state[changeId];
    final commands = ref.read(learningCommandsProvider).value;
    if (write == null ||
        write.status != SubTrackLifecycleSyncStatus.notSaved ||
        commands == null) {
      return;
    }
    _set(changeId, SubTrackLifecycleSyncStatus.waiting);
    CaptureResult result;
    try {
      result = await commands.retry(changeId);
    } on Object {
      result = const CaptureResult.rejected(CaptureRejection.notSaved);
    }
    if (!ref.mounted) return;
    if (result is CaptureSuccess) {
      if (result.queued) {
        await _settle(changeId, commands);
      } else {
        _set(changeId, SubTrackLifecycleSyncStatus.saved);
      }
    } else {
      _set(changeId, SubTrackLifecycleSyncStatus.notSaved);
    }
  }

  /// Forgets [changeId]: its confirmation was shown, or the parent
  /// dismissed a write that was not saved.
  void remove(String changeId) {
    if (!state.containsKey(changeId)) return;
    state = {...state}..remove(changeId);
  }

  Future<void> _settle(String changeId, LearningCommands commands) async {
    bool accepted;
    try {
      accepted = await commands.whenSubTrackChangeConfirmed(changeId);
    } on Object {
      accepted = false;
    }
    if (!ref.mounted) return;
    _set(
      changeId,
      accepted
          ? SubTrackLifecycleSyncStatus.saved
          : SubTrackLifecycleSyncStatus.notSaved,
    );
  }

  void _set(String changeId, SubTrackLifecycleSyncStatus status) {
    final write = state[changeId];
    if (write == null || write.status == status) return;
    state = {...state, changeId: write.withStatus(status)};
  }
}
