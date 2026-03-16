import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

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
  final AppDatabase _database;

  PointsService(this._database);

  /// Get the configured point value for a curriculum + stage.
  ///
  /// Falls back to default values if no config exists.
  Future<int> getPointsForStage({
    required String curriculumId,
    required int stageOrder,
  }) async {
    final config = await _database.pointConfigDao.getConfig(
      curriculumId,
      stageOrder,
    );
    if (config != null) return config.points;

    // Defaults: Learn=10, Chazara1=5, Chazara2=3
    return _defaultPoints(stageOrder);
  }

  /// Total points earned for a specific curriculum.
  Future<int> getCurriculumTotal(String curriculumId) async {
    final completions = await _database.completionDao
        .getCompletionsByCurriculum(curriculumId);
    return completions.fold<int>(0, (sum, c) => sum + c.points);
  }

  /// Total points earned across all curricula.
  Future<int> getGlobalTotal() async {
    final completions = await _database.completionDao.getAllCompletions();
    return completions.fold<int>(0, (sum, c) => sum + c.points);
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

  /// Points history log — all point award events ordered by timestamp.
  Future<List<PointsHistoryEntry>> getPointsHistory({
    String? curriculumId,
  }) async {
    final completions = curriculumId != null
        ? await _database.completionDao.getCompletionsByCurriculum(curriculumId)
        : await _database.completionDao.getAllCompletions();

    // Only include completions that actually earned points
    return completions
        .where((c) => c.points > 0)
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

  /// Seed default point configs for a curriculum if none exist.
  Future<void> ensureDefaultConfigs(String curriculumId) async {
    final existing = await _database.pointConfigDao.getConfigsByCurriculum(
      curriculumId,
    );
    if (existing.isEmpty) {
      await _database.pointConfigDao.seedDefaults(curriculumId);
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
