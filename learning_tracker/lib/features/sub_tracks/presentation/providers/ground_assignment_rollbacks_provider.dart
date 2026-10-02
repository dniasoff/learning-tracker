/// Late rollbacks of queued ground assignments (Story 2.7 / DNI-498 AC-4,
/// UX-DR-127).
///
/// Offline, `editSubTrack` returns `CaptureSuccess(queued: true)`: the
/// append is applied to the local cache at once and the picker closes, but
/// the server has not accepted it yet. If the server later refuses the
/// batch for good, the data layer reverts the local write (so the ground,
/// the main track and the target recompute back to the last accepted
/// state) and `LearningCommands.watchPendingFailures` reports the batch's
/// change id. This notifier remembers each queued assignment's change ids,
/// watches that feed and counts, per sub-track, the rollbacks nobody has
/// announced yet; the picker and *Add ground* take one and show the
/// rollback snackbar.
///
/// It is kept alive (not auto-disposed) because the picker that queued
/// the write has usually closed by the time the server answers.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';

/// Unannounced late rollbacks per sub-track id.
final class GroundAssignmentRollbacks extends Notifier<Map<String, int>> {
  /// Queued change id → the sub-track it assigns ground to.
  final Map<String, String> _queued = {};

  /// One pending-failure subscription per commands instance.
  final Map<LearningCommands, StreamSubscription<List<PendingFailure>>> _feeds =
      {};

  @override
  Map<String, int> build() {
    ref.onDispose(() {
      for (final feed in _feeds.values) {
        unawaited(feed.cancel());
      }
      _feeds.clear();
    });
    return const {};
  }

  /// Tracks a queued assignment of [subTrackId] ([result] from
  /// [commands]) until the server accepts or refuses it.
  void trackQueued(
    LearningCommands commands,
    String subTrackId,
    CaptureSuccess result,
  ) {
    if (!result.queued || result.changeIds.isEmpty) return;
    for (final id in result.changeIds) {
      _queued[id] = subTrackId;
    }
    _feeds[commands] ??= commands.watchPendingFailures().listen(
      _onPendingFailures,
      onError: (Object _) {},
    );
  }

  void _onPendingFailures(List<PendingFailure> failures) {
    final rolledBack = <String, int>{};
    for (final failure in failures) {
      final tracks = {
        for (final id in failure.changeIds)
          if (_queued.remove(id) case final subTrackId?) subTrackId,
      };
      for (final subTrackId in tracks) {
        rolledBack[subTrackId] = (rolledBack[subTrackId] ?? 0) + 1;
      }
    }
    if (rolledBack.isEmpty) return;
    state = {
      ...state,
      for (final MapEntry(:key, :value) in rolledBack.entries)
        key: (state[key] ?? 0) + value,
    };
  }

  /// Takes one unannounced rollback of [subTrackId]: true (and the count
  /// drops) when there was one, so exactly one listener announces it.
  bool take(String subTrackId) {
    final count = state[subTrackId] ?? 0;
    if (count == 0) return false;
    state = {
      for (final MapEntry(:key, :value) in state.entries)
        if (key != subTrackId) key: value else if (count > 1) key: count - 1,
    };
    return true;
  }
}

/// The app-wide [GroundAssignmentRollbacks].
final groundAssignmentRollbacksProvider =
    NotifierProvider<GroundAssignmentRollbacks, Map<String, int>>(
      GroundAssignmentRollbacks.new,
    );
