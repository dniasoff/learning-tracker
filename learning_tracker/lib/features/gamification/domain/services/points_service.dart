import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';

/// Record of a single points award event.
class PointsHistoryEntry {
  final DateTime timestamp;
  final String curriculumId;
  final int stageId;
  final int points;
  final String sefariaRef;

  const PointsHistoryEntry({
    required this.timestamp,
    required this.curriculumId,
    required this.stageId,
    required this.points,
    required this.sefariaRef,
  });
}

/// Service for querying and managing gamification points.
///
/// Points are awarded as a side effect of completion (via CompletionRepository).
/// This service provides read access to points totals, history, and configuration.
class PointsService {
  final UserDatabase _database;
  final int profileId;

  PointsService(this._database, {this.profileId = 0});

  /// Get the configured point value for a curriculum + stage.
  ///
  /// Falls back to default values if no config exists.
  Future<int> getPointsForStage({
    required String curriculumId,
    required int stageOrder,
    required int trackId,
  }) async {
    final config = await _database.pointConfigDao.getConfig(
      curriculumId,
      stageOrder,
      profileId: profileId,
      trackId: trackId,
    );
    if (config != null) return config.points;

    // Defaults: Learn=10, Chazara1=5, Chazara2=3
    return _defaultPoints(stageOrder);
  }

  /// Total points earned for a specific curriculum, scoped to active profile.
  ///
  /// Only includes completions on tracks that count toward gamification
  /// (programmed enrollment or self-paced with a learning goal) — not
  /// momentum-only browse tracks.
  Future<int> getCurriculumTotal(String curriculumId) async {
    final completions = await _database.completionDao
        .getCompletionsByCurriculumAndProfile(curriculumId, profileId);
    return _sumPointsForRewardEligibleTracks(completions);
  }

  /// Total points earned across all curricula, scoped to active profile.
  ///
  /// Only includes completions on tracks that count toward gamification
  /// (programmed enrollment or self-paced with a learning goal).
  Future<int> getGlobalTotal() async {
    final completions = await _database.completionDao.getCompletionsByProfile(
      profileId,
    );
    return _sumPointsForRewardEligibleTracks(completions);
  }

  /// Per-curriculum breakdown of points totals.
  Future<Map<CurriculumId, int>> getCurriculumBreakdown() async {
    final totals = <CurriculumId, int>{};
    for (final curriculum in CurriculumId.values) {
      final total = await getCurriculumTotal(curriculum.storageKey);
      if (total > 0) {
        totals[curriculum] = total;
      }
    }
    return totals;
  }

  /// Points history log — point awards from reward-eligible tracks only,
  /// ordered by timestamp, scoped to active profile.
  Future<List<PointsHistoryEntry>> getPointsHistory({
    String? curriculumId,
  }) async {
    final completions = curriculumId != null
        ? await _database.completionDao.getCompletionsByCurriculumAndProfile(
            curriculumId,
            profileId,
          )
        : await _database.completionDao.getCompletionsByProfile(profileId);

    final eligibility = await _rewardEligibilityByTrackId(completions);

    return completions
        .where((c) => c.points > 0 && (eligibility[c.trackId] ?? false))
        .map(
          (c) => PointsHistoryEntry(
            timestamp: c.completedAt,
            curriculumId: c.curriculumId,
            stageId: c.stageId,
            points: c.points,
            sefariaRef: c.sefariaRef,
          ),
        )
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<Map<int, bool>> _rewardEligibilityByTrackId(
    List<Completion> completions,
  ) async {
    final reward = RewardMilestoneService(_database, profileId: profileId);
    final ids = completions.map((c) => c.trackId).toSet();
    final map = <int, bool>{};
    for (final id in ids) {
      map[id] = await reward.trackCountsTowardRewardPoints(id);
    }
    return map;
  }

  Future<int> _sumPointsForRewardEligibleTracks(
    List<Completion> completions,
  ) async {
    if (completions.isEmpty) return 0;
    final eligibility = await _rewardEligibilityByTrackId(completions);
    return completions.fold<int>(0, (sum, c) {
      if (!(eligibility[c.trackId] ?? false)) return sum;
      return sum + c.points;
    });
  }

  /// Seed default point configs for a curriculum if none exist.
  Future<void> ensureDefaultConfigs(
    String curriculumId, {
    required int trackId,
  }) async {
    final existing = await _database.pointConfigDao.getConfigsByCurriculum(
      curriculumId,
      profileId: profileId,
      trackId: trackId,
    );
    if (existing.isEmpty) {
      await _database.pointConfigDao.seedDefaults(
        curriculumId,
        trackId,
        profileId: profileId,
      );
    }
  }

  /// Default point values when no config is present.
  static int _defaultPoints(int stageOrder) {
    return switch (stageOrder) {
      1 => 10, // Learn
      2 => 5, // Chazara 1
      3 => 3, // Chazara 2
      _ => 1, // Any additional stages
    };
  }
}
