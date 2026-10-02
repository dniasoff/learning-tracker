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
/// * **Never fails a command.** The latch runs after the write has already
///   succeeded (or queued offline); any read or write failure is swallowed.
///   A missed latch is caught up by the next write's check, which compares
///   the totals against the stored list, not against the previous totals.
/// * **No analytics** (AD-47): the latch emits nothing.
///
/// Imports only `lib/domain/learner_state/**` and `dart:` (like the rest of
/// this directory).
library;

import 'package:learning_tracker/domain/learner_state/points.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';

/// What the latch reads and writes. Implemented outside the domain
/// (`lib/features/gamification/data/repositories/achievement_latch_adapter.dart`).
abstract interface class AchievementLatchPort {
  /// The AD-50 filtered totals of [scope] once its learner state includes
  /// the written learn events [learnEventIds]. Throws when they cannot be
  /// read in time.
  Future<PointsTotals> totalsIncluding(
    LearnerScope scope,
    Set<String> learnEventIds,
  );

  /// The enabled achievement thresholds of [scope] (the existing configured
  /// reward milestones; this story changes no threshold policy).
  Future<List<AchievementThreshold>> thresholds(LearnerScope scope);

  /// The latched ids, `unlocked_achievement_ids`.
  Future<Set<String>> unlocked(LearnerScope scope);

  /// Array-unions [achievementIds] into `unlocked_achievement_ids`.
  Future<void> latch(LearnerScope scope, Set<String> achievementIds);
}

/// Detects newly crossed achievement thresholds after a write and latches
/// them (AD-50 "Achievement latch").
final class AchievementLatch {
  /// Creates the latch over [port].
  const AchievementLatch(this._port);

  final AchievementLatchPort _port;

  /// Latches every achievement of [scope] crossed once [learnEventIds] are
  /// counted, and returns the ids it latched (empty when none, when
  /// [learnEventIds] is empty, or on any failure).
  Future<Set<String>> afterWrite(
    LearnerScope scope,
    Set<String> learnEventIds,
  ) async {
    if (learnEventIds.isEmpty) return const {};
    try {
      final thresholds = await _port.thresholds(scope);
      if (thresholds.isEmpty) return const {};
      final totals = await _port.totalsIncluding(scope, learnEventIds);
      final unlocked = await _port.unlocked(scope);
      final crossed = newlyCrossedAchievements(totals, thresholds, unlocked);
      if (crossed.isEmpty) return const {};
      await _port.latch(scope, crossed);
      return crossed;
    } on Object {
      return const {}; // never fails a command; the next write catches up
    }
  }
}
