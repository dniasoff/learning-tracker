import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/progress/domain/repositories/progress_repository.dart';
import 'package:learning_tracker/features/progress/domain/services/curriculum_progress_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'progress_providers.g.dart';

/// Provider for the progress repository instance.
@riverpod
ProgressRepository progressRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return ProgressRepositoryImpl(database: database);
}

/// Provider for track breakdown by curriculum, scoped to the active profile.
///
/// Returns a map of TrackType to completion counts for the given curriculum.
@riverpod
Future<Map<TrackType, int>> trackBreakdown(Ref ref, String curriculumId) async {
  final db = ref.watch(appDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final rawBreakdown = await db.completionDao.getTrackBreakdownByProfile(
    curriculumId,
    profileId,
  );

  // Convert string keys to TrackType enum keys
  final result = <TrackType, int>{};
  for (final trackType in TrackType.values) {
    result[trackType] = 0;
  }
  for (final entry in rawBreakdown.entries) {
    try {
      final trackType = TrackType.fromStorageKey(entry.key);
      result[trackType] = entry.value;
    } on ArgumentError {
      continue;
    }
  }
  return result;
}

/// Provider for aggregate completion count by curriculum, scoped to the active profile.
///
/// Returns the total completion count across all tracks for the given curriculum.
@riverpod
Future<int> aggregateCount(Ref ref, String curriculumId) async {
  final db = ref.watch(appDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return db.completionDao.getAggregateCountByProfile(curriculumId, profileId);
}

/// Provider that fetches completions for a single curriculum via
/// [ProgressRepository].
///
/// Using [ProgressRepository] (not [CompletionRepository]) keeps the history
/// screen decoupled from write-side concerns (sync engine, content repository)
/// and makes widget testing simpler — only [appDatabaseProvider] needs to be
/// overridden. Watching this provider keeps the screen reactive; invalidating
/// it causes the UI to rebuild with fresh data.
final completionHistoryForCurriculumProvider = FutureProvider.autoDispose
    .family<List<Completion>, String>((ref, curriculumId) async {
      final repository = ref.watch(progressRepositoryProvider);
      return repository.getCompletionsByCurriculum(curriculumId);
    });

/// Provider that fetches completions across all curricula.
///
/// Used when no curriculumId filter is applied.
final allCompletionHistoryProvider =
    FutureProvider.autoDispose<List<Completion>>((ref) async {
      final repository = ref.watch(progressRepositoryProvider);
      return repository.getAllCompletions();
    });

/// Per-curriculum progress data provider (family keyed by curriculumId per P3).
///
/// Aggregates content hierarchy, completions, and stage definitions into
/// a [CurriculumProgressData] with hierarchy breakdowns, stage breakdowns,
/// track breakdowns, and overall stats.
@riverpod
Future<CurriculumProgressData> curriculumProgress(
  Ref ref,
  String curriculumId,
) async {
  final db = ref.watch(appDatabaseProvider);

  // Resolve CurriculumId enum for content repository
  final curriculumEnum = CurriculumId.values.firstWhere(
    (c) => c.storageKey == curriculumId,
  );

  // Fetch scoped content items, completions, stage definitions, hierarchy config
  final contentItems = await ref.watch(
    scopedCurriculumContentProvider(curriculumEnum).future,
  );
  final hierarchyConfig = await ref.watch(
    curriculumHierarchyConfigProvider(curriculumEnum).future,
  );
  final profileId = ref.watch(activeProfileIdProvider);
  final completions = await db.completionDao
      .getCompletionsByCurriculumAndProfile(curriculumId, profileId);
  final stageDefinitions = await db.stageDao.getStageDefinitionsByCurriculum(
    curriculumId,
  );

  return CurriculumProgressService.compute(
    curriculumId: curriculumId,
    contentItems: contentItems,
    completions: completions,
    stageDefinitions: stageDefinitions,
    levelLabels: hierarchyConfig.levelLabels,
  );
}

/// Pace status for a curriculum (null if no goal exists).
///
/// Family provider keyed by curriculumId per P3.
@riverpod
Future<PaceStatus?> curriculumPaceStatus(Ref ref, String curriculumId) async {
  final db = ref.watch(appDatabaseProvider);
  final now = ref.watch(clockProvider);

  final profileId = ref.watch(activeProfileIdProvider);

  // Get the most recent goal for this curriculum
  final goals = await db.goalDao.getGoalsByCurriculumAndProfile(
    curriculumId,
    profileId,
  );
  if (goals.isEmpty) return null;

  final goal = goals.first;
  if (goal.targetDate == null) return null;

  // Resolve CurriculumId enum for content
  final curriculumEnum = CurriculumId.values.firstWhere(
    (c) => c.storageKey == curriculumId,
  );

  // Use scoped item count for pace calculation
  final scopedTotal = await ref.watch(
    scopedItemCountProvider(curriculumEnum).future,
  );

  // Get personal-track completions
  final allCompletions = await db.completionDao
      .getCompletionsByCurriculumAndProfile(curriculumId, profileId);
  final personalCompletions = allCompletions
      .where((c) => c.trackType == TrackType.personal.storageKey)
      .toList();

  // Build daily counts
  final dailyCounts = <DateTime, int>{};
  for (final c in personalCompletions) {
    final date = DateTime.utc(
      c.completedAt.year,
      c.completedAt.month,
      c.completedAt.day,
    );
    dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
  }

  return PaceCalculator.calculate(
    goalStartDate: goal.createdAt,
    goalDeadline: goal.targetDate!,
    totalItems: scopedTotal,
    completedItems: personalCompletions.length,
    dailyCompletionCounts: dailyCounts,
    today: now,
  );
}
