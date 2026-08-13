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

/// Interface for reading the global debitable points balance.
abstract class PointsBalanceReader {
  Future<int> getBalance();
}

/// Reads points that were earned for milestone progression.
///
/// This is deliberately separate from [PointsBalanceReader]: points spent on
/// rewards reduce the debitable balance but never undo lifetime-earned
/// progress.
abstract class PointsLifetimeEarnedReader {
  Future<int> getLifetimeEarned();
}

/// Service for querying gamification points.
///
/// Points are awarded as a side effect of completion (via CompletionRepository).
/// This service provides read access to points totals and history.
///
/// **No point-config dependency.** A `PointConfigProvider` port (and this
/// service's own `getPointsForStage`/`ensureDefaultConfigs` methods) used to
/// live here, but had zero implementations and zero real callers — the
/// live point-award path already reads stage point values directly from
/// `FirestorePointConfigRepository` via `completion_points_awarder.dart`,
/// never through this service. Removed rather than adapted (Phase 3).
class PointsService {
  final CurriculumRewardEligibility _eligibility;
  final PointsBalanceReader _balanceReader;

  PointsService({
    required CurriculumRewardEligibility eligibility,
    required PointsBalanceReader balanceReader,
  }) : _eligibility = eligibility,
       _balanceReader = balanceReader;

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
}
