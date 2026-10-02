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
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
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
    this.scope,
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

  /// The learner the write was issued for, stamped when it is tracked
  /// ([SubTrackLifecycleSyncNotifier.track]); its retry and removal are
  /// routed to that learner's store and commands.
  final LearnerScope? scope;

  /// This record at [status].
  SubTrackLifecycleSync withStatus(SubTrackLifecycleSyncStatus status) =>
      _copy(status: status);

  /// This record, issued for [scope].
  SubTrackLifecycleSync forScope(LearnerScope scope) => _copy(scope: scope);

  SubTrackLifecycleSync _copy({
    SubTrackLifecycleSyncStatus? status,
    LearnerScope? scope,
  }) => SubTrackLifecycleSync(
    changeId: changeId,
    write: write,
    name: name,
    yearLabel: yearLabel,
    status: status ?? this.status,
    scope: scope ?? this.scope,
  );

  @override
  bool operator ==(Object other) =>
      other is SubTrackLifecycleSync &&
      other.changeId == changeId &&
      other.write == write &&
      other.name == name &&
      other.yearLabel == yearLabel &&
      other.status == status &&
      other.scope == scope;

  @override
  int get hashCode =>
      Object.hash(changeId, write, name, yearLabel, status, scope);
}

/// One learner's queued lifecycle writes for the session, by change id.
///
/// Held per learner scope ([subTrackLifecycleSyncStoreProvider]) rather
/// than in the notifier, which Riverpod rebuilds with its inputs: a
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

/// Reads a provider (`WidgetRef.read` or `Ref.read`, torn off).
typedef SubTrackLifecycleReader = T Function<T>(ProviderListenable<T> provider);

/// The learner a lifecycle write is issued for, paired with the commands
/// bound to that learner.
///
/// Captured once, before the command runs
/// ([resolveSubTrackLifecycleOrigin]), and carried through the write: the
/// queued record lands in [scope]'s [SubTrackLifecycleSyncStore] and
/// settles through [commands], even when the active learner changes while
/// the command awaits its result.
@immutable
final class SubTrackLifecycleOrigin {
  /// Pairs [scope] with its [commands].
  const SubTrackLifecycleOrigin({required this.scope, required this.commands});

  /// The learner the write is for.
  final LearnerScope scope;

  /// The commands bound to [scope] that run the write.
  final LearningCommands commands;
}

/// The active learner and the commands bound to it, or null while either
/// is loading, failed, or absent (no learner, or a tutored session).
///
/// `learningCommandsProvider` watches the active scope, so when both are
/// settled in the same synchronous read the commands were built for that
/// scope; while a learner switch is in flight one of them is loading.
SubTrackLifecycleOrigin? settledSubTrackLifecycleOrigin(
  SubTrackLifecycleReader read,
) {
  final scope = read<AsyncValue<LearnerScope?>>(activeLearnerScopeProvider);
  if (scope.isLoading || scope.hasError) return null;
  final commands = read<AsyncValue<LearningCommands?>>(
    learningCommandsProvider,
  );
  if (commands.isLoading || commands.hasError) return null;
  final s = scope.value;
  final c = commands.value;
  if (s == null || c == null) return null;
  return SubTrackLifecycleOrigin(scope: s, commands: c);
}

/// Resolves the [SubTrackLifecycleOrigin] of a lifecycle write about to be
/// issued: waits for the active learner and its commands, then pairs them
/// only when they agree ([settledSubTrackLifecycleOrigin]). A learner
/// switch racing the wait is retried a few times; null when no consistent
/// pair settles (the caller reports the write as not run).
Future<SubTrackLifecycleOrigin?> resolveSubTrackLifecycleOrigin(
  SubTrackLifecycleReader read,
) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    final scope = await read(activeLearnerScopeProvider.future);
    if (scope == null) return null;
    final commands = await read(learningCommandsProvider.future);
    if (commands == null) return null;
    final origin = settledSubTrackLifecycleOrigin(read);
    if (origin != null) return origin;
  }
  return null;
}

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
///
/// Every write is routed by the learner it was issued for, never by
/// whichever learner is active when the call happens: [track] by the
/// write's [SubTrackLifecycleOrigin], [retry] and [remove] by the scope
/// stamped on the record ([SubTrackLifecycleSync.scope]).
class SubTrackLifecycleSyncNotifier
    extends Notifier<Map<String, SubTrackLifecycleSync>> {
  @override
  Map<String, SubTrackLifecycleSync> build() {
    final scope = ref.watch(activeLearnerScopeProvider).value;
    if (scope == null) return const {};
    final store = ref.watch(subTrackLifecycleSyncStoreProvider(scope));
    void publish() {
      if (ref.mounted) state = store.writes;
    }

    store.addListener(publish);
    ref.onDispose(() => store.removeListener(publish));
    return store.writes;
  }

  /// Keeps [write], queued through [origin]'s commands, pending in
  /// [origin]'s learner's store until the server settles it — whichever
  /// learner is active by the time the queued result arrives.
  void track(SubTrackLifecycleSync write, SubTrackLifecycleOrigin origin) => ref
      .read(subTrackLifecycleSyncStoreProvider(origin.scope))
      .track(write.forScope(origin.scope), origin.commands);

  /// Re-sends the refused [write], unchanged, through the current commands
  /// of the learner it was issued for. Does nothing while that learner is
  /// not the active one (its commands are not available): the write stays
  /// not saved, with its retry, in that learner's store.
  Future<void> retry(SubTrackLifecycleSync write) async {
    final scope = write.scope;
    if (scope == null || !ref.mounted) return;
    final store = ref.read(subTrackLifecycleSyncStoreProvider(scope));
    var origin = settledSubTrackLifecycleOrigin(ref.read);
    if (origin == null) {
      // A commands rebuild (parent PIN, profile, clock) or learner switch
      // in flight.
      try {
        await ref.read(learningCommandsProvider.future);
      } on Object {
        return;
      }
      if (!ref.mounted) return;
      origin = settledSubTrackLifecycleOrigin(ref.read);
    }
    if (origin == null || origin.scope != scope) return;
    await store.retry(write.changeId, origin.commands);
  }

  /// Forgets [write] in the store of the learner it was issued for: its
  /// confirmation was shown, or the parent dismissed a write that was not
  /// saved.
  void remove(SubTrackLifecycleSync write) {
    final scope = write.scope;
    if (scope == null || !ref.mounted) return;
    ref.read(subTrackLifecycleSyncStoreProvider(scope)).remove(write.changeId);
  }
}
