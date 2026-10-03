/// The AD-27 / AD-50 achievement latch `LearningCommands` runs after a
/// learning write (DNI-480, Story 1.18).
///
/// After a write that recorded learn events, the latch waits for the
/// learner's state to include them, takes the AD-50 filtered totals, and
/// array-unions every achievement id whose threshold is now crossed and not
/// yet latched into `preferences/gamification_settings
/// .unlocked_achievement_ids`. That list is the record every achievement
/// surface reads; an id in it stays unlocked even when a void later lowers
/// lifetime earned.
///
/// * **Idempotent and monotonic.** `newlyCrossedAchievements` never returns
///   a latched id, and the write is an array union, so a replayed write, a
///   repeated check, or two devices crossing the same threshold at once
///   leave exactly one id. Nothing is ever removed.
/// * **Only what the server accepted.** A latch can never be taken back, so
///   it must not latch on a write the server may still reject. The commands
///   run the check only once the write is acknowledged (a queued write when
///   it reaches the server, a rejected write never), and every check first
///   waits for the client's other pending writes to settle
///   ([AchievementLatchPort.pendingWritesSettled]) and leaves out the
///   events the server rejected this session, so the totals it judges
///   never include a write that is later rolled back.
/// * **Never fails a command.** The latch runs after the write has already
///   been acknowledged; a read or write failure never reaches the
///   command.
/// * **Recovers without another write.** A failed check is retried on its
///   own after each of [AchievementLatch.retryDelays], and the commands run
///   [AchievementLatch.reconcile] whenever they are created (app start,
///   learner switch), which latches every threshold the current totals have
///   crossed. A check compares the totals against the stored list, not
///   against the previous totals, so a retry, a reconcile and the next
///   write's check are all the same idempotent operation.
/// * **No analytics** (AD-47): the latch emits nothing.
///
/// Imports only `lib/domain/learner_state/**` and `dart:` (like the rest of
/// this directory).
library;

import 'dart:async';

import 'package:learning_tracker/domain/learner_state/points.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';

/// What the latch reads and writes. Implemented outside the domain
/// (`lib/features/gamification/data/repositories/achievement_latch_adapter.dart`).
abstract interface class AchievementLatchPort {
  /// Completes once every write the client has pending for [scope] (this
  /// session's or one persisted from an earlier session) has been
  /// acknowledged or rejected by the server. Throws when that does not
  /// happen in time (offline).
  Future<void> pendingWritesSettled(LearnerScope scope);

  /// The AD-50 filtered totals of [scope] once its learner state includes
  /// the written learn events [learnEventIds] (the current totals when
  /// [learnEventIds] is empty), never counting an event of [excluding]
  /// (written locally but rejected by the server). Throws when they cannot
  /// be read in time.
  Future<PointsTotals> totalsIncluding(
    LearnerScope scope,
    Set<String> learnEventIds, {
    Set<String> excluding = const {},
  });

  /// The enabled achievement thresholds of [scope] (the existing configured
  /// reward milestones; this story changes no threshold policy).
  Future<List<AchievementThreshold>> thresholds(LearnerScope scope);

  /// The latched ids, `unlocked_achievement_ids`.
  Future<Set<String>> unlocked(LearnerScope scope);

  /// Array-unions [achievementIds] into `unlocked_achievement_ids`.
  Future<void> latch(LearnerScope scope, Set<String> achievementIds);
}

/// The default waits before each retry of a failed latch check.
const List<Duration> defaultAchievementLatchRetryDelays = [
  Duration(seconds: 10),
  Duration(minutes: 1),
  Duration(minutes: 5),
];

/// Detects newly crossed achievement thresholds after a write and latches
/// them (AD-50 "Achievement latch").
final class AchievementLatch {
  /// Creates the latch over [_port].
  AchievementLatch(
    this._port, {
    this.retryDelays = defaultAchievementLatchRetryDelays,
  });

  final AchievementLatchPort _port;

  /// The waits before each retry of a failed check; after the last one the
  /// check is left to the next write or the next [reconcile].
  final List<Duration> retryDelays;

  final Set<Timer> _retries = {};
  bool _disposed = false;

  /// Latches every achievement of [scope] crossed once [learnEventIds] are
  /// counted, and returns the ids it latched (empty when none, when
  /// [learnEventIds] is empty, or on a failure, which is then retried in
  /// the background).
  ///
  /// [learnEventIds] must be events the server acknowledged. [unsaved]
  /// names, at each attempt, the events the server rejected and that are
  /// not yet saved; the totals leave them out.
  Future<Set<String>> afterWrite(
    LearnerScope scope,
    Set<String> learnEventIds, {
    Set<String> Function()? unsaved,
  }) async {
    if (learnEventIds.isEmpty) return const {};
    return _check(scope, learnEventIds, 0, unsaved);
  }

  /// Latches every achievement of [scope] the current totals have crossed
  /// and returns the ids it latched (empty when none, or on a failure,
  /// which is then retried in the background). Recovers a latch whose
  /// check failed before the app stopped.
  Future<Set<String>> reconcile(LearnerScope scope) =>
      _check(scope, const {}, 0, null);

  /// Cancels the pending retries; later checks still run once each.
  void dispose() {
    _disposed = true;
    for (final t in _retries) {
      t.cancel();
    }
    _retries.clear();
  }

  Future<Set<String>> _check(
    LearnerScope scope,
    Set<String> learnEventIds,
    int attempt,
    Set<String> Function()? unsaved,
  ) async {
    try {
      final thresholds = await _port.thresholds(scope);
      if (thresholds.isEmpty) return const {};
      await _port.pendingWritesSettled(scope);
      final totals = await _port.totalsIncluding(
        scope,
        learnEventIds,
        excluding: unsaved?.call() ?? const {},
      );
      final unlocked = await _port.unlocked(scope);
      final crossed = newlyCrossedAchievements(totals, thresholds, unlocked);
      if (crossed.isEmpty) return const {};
      await _port.latch(scope, crossed);
      return crossed;
    } on Object {
      // Never fails a command: retry on our own, then leave it to the next
      // write or reconcile.
      if (!_disposed && attempt < retryDelays.length) {
        late final Timer timer;
        timer = Timer(retryDelays[attempt], () {
          _retries.remove(timer);
          unawaited(_check(scope, learnEventIds, attempt + 1, unsaved));
        });
        _retries.add(timer);
      }
      return const {};
    }
  }
}
