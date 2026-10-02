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
/// The records are kept per learner for the session
/// ([SubTrackLifecycleSyncStore]), so a rebuild of the commands or of this
/// provider never drops a pending write.
///
/// `subtrack_lifecycle` analytics follow the same acceptance: the commands
/// emit them only when the server accepts the write.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_lifecycle_sources.dart';

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

/// One learner's queued lifecycle writes for the session, by change id.
///
/// Held per learner scope ([subTrackLifecycleSyncStoreProvider]) rather
/// than in the notifier, which Riverpod recreates whenever it rebuilds: a
/// rebuild of `learningCommandsProvider` (a parent-PIN, profile or clock
/// change) or switching learners and back keeps every pending End, Delete
/// and *Add next year*, and a settle in flight still lands. The commands'
/// `SubTrackWriteLedger` keeps the matching acknowledgement wait and
/// retry across the same rebuilds. Session-scoped like every AD-54
/// pending failure (no outbox): after a restart the Firestore SDK still
/// sends the queued write, and the hub reflects its outcome from the
/// sub-track read.
class SubTrackLifecycleSyncStore extends ChangeNotifier {
  Map<String, SubTrackLifecycleSync> _writes = const {};
  bool _disposed = false;

  /// The queued writes, by change id.
  Map<String, SubTrackLifecycleSync> get writes => _writes;

  /// Keeps [write], queued by [commands], pending until the server settles
  /// it.
  void track(SubTrackLifecycleSync write, LearningCommands commands) {
    _put({
      ..._writes,
      write.changeId: write.withStatus(SubTrackLifecycleSyncStatus.waiting),
    });
    unawaited(_settle(write.changeId, commands));
  }

  /// Re-sends the refused write [changeId] unchanged through [commands].
  Future<void> retry(String changeId, LearningCommands commands) async {
    final write = _writes[changeId];
    if (write == null || write.status != SubTrackLifecycleSyncStatus.notSaved) {
      return;
    }
    _set(changeId, SubTrackLifecycleSyncStatus.waiting);
    CaptureResult result;
    try {
      result = await commands.retry(changeId);
    } on Object {
      result = const CaptureResult.rejected(CaptureRejection.notSaved);
    }
    if (_disposed) return;
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
    if (!_writes.containsKey(changeId)) return;
    _put({..._writes}..remove(changeId));
  }

  Future<void> _settle(String changeId, LearningCommands commands) async {
    bool accepted;
    try {
      accepted = await commands.whenSubTrackChangeConfirmed(changeId);
    } on Object {
      accepted = false;
    }
    if (_disposed) return;
    _set(
      changeId,
      accepted
          ? SubTrackLifecycleSyncStatus.saved
          : SubTrackLifecycleSyncStatus.notSaved,
    );
  }

  void _set(String changeId, SubTrackLifecycleSyncStatus status) {
    final write = _writes[changeId];
    if (write == null || write.status == status) return;
    _put({..._writes, changeId: write.withStatus(status)});
  }

  void _put(Map<String, SubTrackLifecycleSync> writes) {
    if (_disposed) return;
    _writes = Map.unmodifiable(writes);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The [SubTrackLifecycleSyncStore] of a learner, for the session.
final subTrackLifecycleSyncStoreProvider =
    Provider.family<SubTrackLifecycleSyncStore, LearnerScope>((ref, scope) {
      final store = SubTrackLifecycleSyncStore();
      ref.onDispose(store.dispose);
      return store;
    });

/// The active learner's queued lifecycle writes, by change id (empty while
/// no learner is resolved). Switching learners shows the other learner's
/// writes; switching back restores these.
final subTrackLifecycleSyncProvider =
    NotifierProvider<
      SubTrackLifecycleSyncNotifier,
      Map<String, SubTrackLifecycleSync>
    >(SubTrackLifecycleSyncNotifier.new);

/// See [subTrackLifecycleSyncProvider]. A view over the active learner's
/// [SubTrackLifecycleSyncStore]; it holds no state of its own.
class SubTrackLifecycleSyncNotifier
    extends Notifier<Map<String, SubTrackLifecycleSync>> {
  @override
  Map<String, SubTrackLifecycleSync> build() {
    final store = _activeStore(watch: true);
    if (store == null) return const {};
    void publish() {
      if (ref.mounted) state = store.writes;
    }

    store.addListener(publish);
    ref.onDispose(() => store.removeListener(publish));
    return store.writes;
  }

  /// Keeps [write], queued by [commands], pending until the server settles
  /// it.
  void track(SubTrackLifecycleSync write, LearningCommands commands) =>
      _activeStore()?.track(write, commands);

  /// Re-sends the refused write [changeId] unchanged through the current
  /// commands.
  Future<void> retry(String changeId) async {
    final store = _activeStore();
    final commands = ref.read(learningCommandsProvider).value;
    if (store == null || commands == null) return;
    await store.retry(changeId, commands);
  }

  /// Forgets [changeId]: its confirmation was shown, or the parent
  /// dismissed a write that was not saved.
  void remove(String changeId) => _activeStore()?.remove(changeId);

  SubTrackLifecycleSyncStore? _activeStore({bool watch = false}) {
    final scope = watch
        ? ref.watch(activeLearnerScopeProvider).value
        : ref.read(activeLearnerScopeProvider).value;
    if (scope == null) return null;
    return watch
        ? ref.watch(subTrackLifecycleSyncStoreProvider(scope))
        : ref.read(subTrackLifecycleSyncStoreProvider(scope));
  }
}
