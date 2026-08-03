import 'dart:async';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';

/// Drift-backed [CompletionPointsPort] — the storage-specific implementation
/// [CompletionOrchestrator] is wired against today.
///
/// Relocated verbatim (not rewritten) from what
/// `CompletionRepositoryImpl.markComplete` computed inline before the
/// completion-orchestrator lift (`docs/firestore-rewrite-map.md`, owner
/// decision 1): child-profile gating, `RewardMilestoneService
/// .trackCountsTowardRewardPoints`, `point_configs` lookup with the same
/// hardcoded fallback ladder (Learn=10, Chazara1=5, Chazara2=3, else 1), and
/// `PointsBalanceDao.creditCompletion`.
///
/// **No Firestore-backed sibling exists yet.** `PointsBalance`/`PointConfigs`
/// are Drift-only tables; `docs/firestore-rewrite-map.md` deletes the stored
/// balance outright in favor of summing an as-yet-unbuilt `points_ledger`
/// repository (owner decision 5) — that repository, not this file, is the
/// right place for a Firestore [CompletionPointsPort]. Until it lands,
/// [CompletionOrchestrator] simply receives `pointsPort: null` wherever it
/// sits above a Firestore-backed [CompletionRepository], which resolves
/// [CompletionOrchestrator.markComplete]'s points step to a no-op (0
/// points) rather than guessing at a Firestore shape here.
class DriftCompletionPointsAwarder implements CompletionPointsPort {
  DriftCompletionPointsAwarder({
    required UserDatabase database,
    required RewardMilestoneService Function(int profileId)
    rewardMilestoneServiceFactory,
    SyncWriteFacade? syncEngine,
  }) : _database = database,
       _rewardMilestoneServiceFactory = rewardMilestoneServiceFactory,
       _syncEngine = syncEngine;

  final UserDatabase _database;
  final RewardMilestoneService Function(int profileId)
  _rewardMilestoneServiceFactory;
  final SyncWriteFacade? _syncEngine;

  @override
  Future<int> calculatePoints({
    required String curriculumId,
    required int stageOrder,
    required int profileId,
  }) async {
    if (!await _isChildProfile(profileId)) return 0;

    final trackId = await _resolveTrackId(
      curriculumId: curriculumId,
      profileId: profileId,
    );
    if (trackId == null) return 0;

    final rewardService = _rewardMilestoneServiceFactory(profileId);
    final eligible = await rewardService.trackCountsTowardRewardPoints(trackId);
    if (!eligible) return 0;

    final config = await _database.pointConfigDao.getConfig(
      curriculumId,
      stageOrder,
      profileId: profileId,
      trackId: trackId,
    );
    if (config != null) return config.points;

    // Default values when no config is present — mirrors
    // CompletionRepositoryImpl._calculatePoints's prior fallback ladder.
    return switch (stageOrder) {
      1 => 10, // Learn
      2 => 5, // Chazara 1
      3 => 3, // Chazara 2
      _ => 1, // Any additional stages
    };
  }

  @override
  Future<void> creditCompletion({
    required int profileId,
    required int points,
    required String note,
  }) async {
    await _database.pointsBalanceDao.creditCompletion(
      profileId,
      points,
      note: note,
    );
    // R4o-C1/DEC-32: no unlock evaluation runs on completion any more — the
    // auto-unlock ladder was replaced by the spend economy. Only the
    // gamification settings snapshot push survives from the original
    // post-credit block; fire-and-forget, matching the prior call site.
    unawaited(_syncEngine?.pushGamificationSettingsSnapshot());
  }

  Future<bool> _isChildProfile(int profileId) async {
    final profile = await _database.profileDao.getProfileById(profileId);
    return profile != null &&
        ProfileMode.fromStorageKey(profile.mode) == ProfileMode.child;
  }

  /// Look up the curriculum_tracks.id for a given curriculum + profile.
  /// Returns null (rather than throwing) when no track exists yet — a
  /// points-eligibility question about a not-yet-created track is
  /// legitimately "not eligible," not an error.
  Future<int?> _resolveTrackId({
    required String curriculumId,
    required int profileId,
  }) async {
    final track =
        await (_database.select(_database.curriculumTracks)
              ..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(curriculumId),
              )
              ..limit(1))
            .getSingleOrNull();
    return track?.id;
  }
}
