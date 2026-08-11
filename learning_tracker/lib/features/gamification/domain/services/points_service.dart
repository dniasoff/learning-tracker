import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';

/// Record of a single points award event.
class PointsHistoryEntry {
  final DateTime timestamp;
  final CurriculumId curriculumId;
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

/// Interface for checking if a curriculum counts toward reward points.
///
/// Eligibility is CURRICULUM-keyed (AD-25): a curriculum is reward-eligible
/// when a profile_program exists for it OR any goal exists for it.
/// This replaces the old trackId-keyed eligibility in
/// [RewardMilestoneService.trackCountsTowardRewardPoints].
abstract class CurriculumRewardEligibility {
  Future<bool> isEligible(CurriculumId curriculumId);
}

/// Interface for fetching point configuration for a curriculum + stage.
abstract class PointConfigProvider {
  Future<int?> getPointsForStage({
    required CurriculumId curriculumId,
    required int stageOrder,
  });

  Future<void> ensureDefaultConfigs({
    required CurriculumId curriculumId,
  });
}

/// Interface for reading the global debitable points balance.
abstract class PointsBalanceReader {
  Future<int> getBalance();
}

/// Service for querying and managing gamification points.
///
/// Points are awarded as a side effect of completion (via CompletionRepository).
/// This service provides read access to points totals, history, and configuration.
class PointsService {
  final CurriculumRewardEligibility _eligibility;
  final PointConfigProvider _pointConfig;
  final PointsBalanceReader _balanceReader;

  PointsService({
    required CurriculumRewardEligibility eligibility,
    required PointConfigProvider pointConfig,
    required PointsBalanceReader balanceReader,
  }) : _eligibility = eligibility,
       _pointConfig = pointConfig,
       _balanceReader = balanceReader;

  /// Get the configured point value for a curriculum + stage.
  ///
  /// Falls back to default values if no config exists.
  Future<int> getPointsForStage({
    required CurriculumId curriculumId,
    required int stageOrder,
  }) async {
    final config = await _pointConfig.getPointsForStage(
      curriculumId: curriculumId,
      stageOrder: stageOrder,
    );
    if (config != null) return config;

    // Defaults: Learn=10, Chazara1=5, Chazara2=3
    return _defaultPoints(stageOrder);
  }

  /// Total points earned for a specific curriculum, scoped to active profile.
  ///
  /// Only includes completions on curricula that count toward gamification
  /// (programmed enrollment or self-paced with a learning goal) — not
  /// momentum-only browse curricula.
  Future<int> getCurriculumTotal(
    CurriculumId curriculumId,
    List<CompletionEntity> completions,
  ) async {
    final eligible = await _eligibility.isEligible(curriculumId);
    if (!eligible) return 0;

    return completions
        .where((c) => c.curriculumId == curriculumId && c.points > 0)
        .fold<int>(0, (sum, c) => sum + c.points);
  }

  /// Current debitable points balance for this profile (WS7.balance).
  ///
  /// Returns the stored balance from the points ledger — the spend-economy
  /// source of truth (DEC-32). Replaces the old derived-sum read.
  Future<int> getGlobalTotal() async {
    return _balanceReader.getBalance();
  }

  /// Derived sum of completion points for reward-eligible curricula.
  ///
  /// Kept for backward compatibility with tests and the streak/history
  /// subsystems that still need the raw completion sum. New UI should use
  /// [getGlobalTotal] which reads the stored debitable balance.
  Future<int> getDerivedTotal(List<CompletionEntity> completions) async {
    return _sumPointsForRewardEligibleCurricula(completions);
  }

  /// Per-curriculum breakdown of points totals.
  Future<Map<CurriculumId, int>> getCurriculumBreakdown(
    List<CompletionEntity> completions,
  ) async {
    final totals = <CurriculumId, int>{};
    for (final curriculum in CurriculumId.values) {
      final total = await getCurriculumTotal(
        curriculum,
        completions.where((c) => c.curriculumId == curriculum).toList(),
      );
      if (total > 0) {
        totals[curriculum] = total;
      }
    }
    return totals;
  }

  /// Points history log — point awards from reward-eligible curricula only,
  /// ordered by timestamp, scoped to active profile.
  ///
  /// Uses [CompletionTierFilter.liveOnly] (engagement tier) to exclude
  /// bulk-import and prior completions, per the three-tier credit policy.
  Future<List<PointsHistoryEntry>> getPointsHistory({
    required List<CompletionEntity> completions,
    CurriculumId? curriculumId,
  }) async {
    final filtered = completions.where((c) {
      if (c.points <= 0) return false;
      if (curriculumId != null && c.curriculumId != curriculumId) return false;
      return true;
    }).toList();

    final eligibility = await _rewardEligibilityByCurriculumId(filtered);

    return filtered
        .where((c) => eligibility[c.curriculumId] ?? false)
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

  Future<Map<CurriculumId, bool>> _rewardEligibilityByCurriculumId(
    List<CompletionEntity> completions,
  ) async {
    final curricula = completions.map((c) => c.curriculumId).toSet();
    final map = <CurriculumId, bool>{};
    for (final curriculum in curricula) {
      map[curriculum] = await _eligibility.isEligible(curriculum);
    }
    return map;
  }

  Future<int> _sumPointsForRewardEligibleCurricula(
    List<CompletionEntity> completions,
  ) async {
    if (completions.isEmpty) return 0;
    final eligibility = await _rewardEligibilityByCurriculumId(completions);
    return completions.fold<int>(0, (sum, c) {
      if (!(eligibility[c.curriculumId] ?? false)) return sum;
      return sum + c.points;
    });
  }

  /// Seed default point configs for a curriculum if none exist.
  Future<void> ensureDefaultConfigs(CurriculumId curriculumId) async {
    await _pointConfig.ensureDefaultConfigs(curriculumId: curriculumId);
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
