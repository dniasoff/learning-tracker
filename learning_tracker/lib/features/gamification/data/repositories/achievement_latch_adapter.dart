/// The production [AchievementLatchPort] (DNI-480): the AD-50 filtered
/// totals from the points ledger and the learner's state, the configured
/// reward milestones as thresholds, and the `unlocked_achievement_ids`
/// list of `preferences/gamification_settings` as the latch record.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_reward_settings_repository.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/gamification/data/repositories/engine_points_reader.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/learning/domain/commands/achievement_latch.dart';

/// How long the latch waits for the learner's state to include a write.
const Duration achievementLatchStateWait = Duration(seconds: 30);

/// The learner's state as the commands see it: the latest one, and every
/// later one.
final class LearnerStateFeed {
  /// Creates a feed.
  const LearnerStateFeed({required this.latest, required this.changes});

  /// The latest complete state, or null before the first.
  final LearnerState? Function() latest;

  /// Every later complete state.
  final Stream<LearnerState> changes;

  /// The first state (the latest or a later one) that has seen every event
  /// of [learnEventIds], within [wait].
  Future<LearnerState> including(Set<String> learnEventIds, Duration wait) {
    bool seen(LearnerState s) => learnEventIds.every(
      (id) =>
          s.countedEventIds.contains(id) || s.lockIgnoredEventIds.contains(id),
    );
    final now = latest();
    if (now != null && seen(now)) return Future.value(now);
    return changes.firstWhere(seen).timeout(wait);
  }
}

/// [AchievementLatchPort] over the active learner's Firestore documents.
///
/// Bound to the commands' scope, which is the active learner's (commands
/// are null in a tutored session), so the active-profile repositories
/// resolve the same learner.
final class FirestoreAchievementLatchAdapter implements AchievementLatchPort {
  /// Creates the adapter.
  FirestoreAchievementLatchAdapter({
    required Ref ref,
    required LearnerStateFeed states,
    Duration stateWait = achievementLatchStateWait,
  }) : _ref = ref,
       _states = states,
       _stateWait = stateWait;

  final Ref _ref;
  final LearnerStateFeed _states;
  final Duration _stateWait;

  Future<FirestoreRewardSettingsRepository> _settings() async {
    final repo = await _ref.read(
      firestoreRewardSettingsRepositoryProvider.future,
    );
    if (repo == null) {
      throw PointsNotReadyException('no reward settings repository');
    }
    return repo;
  }

  @override
  Future<PointsTotals> totalsIncluding(
    LearnerScope scope,
    Set<String> learnEventIds,
  ) async {
    final state = await _states.including(learnEventIds, _stateWait);
    final ledger = await _ref.read(
      firestorePointsLedgerRepositoryProvider.future,
    );
    if (ledger == null) {
      throw PointsNotReadyException('no points ledger repository');
    }
    return ledger.getTotals(earningEventIds: state.earningEventIds);
  }

  @override
  Future<List<AchievementThreshold>> thresholds(LearnerScope scope) async {
    final service = _ref.read(rewardMilestoneServiceProvider);
    await service.mergeCloudPayload(
      await (await _settings()).readRewardSettings(),
    );
    return [
      for (final m in await service.getMilestones())
        if (m.isEnabled)
          AchievementThreshold(id: m.id, points: m.thresholdPoints),
    ];
  }

  @override
  Future<Set<String>> unlocked(LearnerScope scope) async =>
      (await _settings()).readUnlockedAchievementIds();

  @override
  Future<void> latch(LearnerScope scope, Set<String> achievementIds) async =>
      (await _settings()).latchUnlockedAchievementIds(achievementIds);
}
