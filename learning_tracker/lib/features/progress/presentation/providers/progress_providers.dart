import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/progress/domain/repositories/progress_repository.dart';
import 'package:learning_tracker/features/progress/domain/services/curriculum_progress_service.dart';
import 'package:learning_tracker/features/progress/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'progress_providers.g.dart';

class ProgressOverviewStats {
  final int totalCompletions;
  final int totalUniqueItems;

  const ProgressOverviewStats({
    required this.totalCompletions,
    required this.totalUniqueItems,
  });
}

/// Provider for the progress repository instance.
@riverpod
ProgressRepository progressRepository(Ref ref) {
  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return ProgressRepositoryImpl(database: database, profileId: profileId);
}

/// Provider for track breakdown by curriculum, scoped to the active profile.
///
/// Returns a map of TrackType to completion counts for the given curriculum.
@riverpod
Future<Map<TrackType, int>> trackBreakdown(Ref ref, String curriculumId) async {
  final db = ref.watch(userDatabaseProvider);
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
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return db.completionDao.getAggregateCountByProfile(curriculumId, profileId);
}

/// Live progress snapshot derived directly from completion rows.
///
/// Unlike journey milestones, this updates on every completion and is used
/// for immediate progress feedback in the Progress screen.
@riverpod
Future<ProgressOverviewStats> progressOverviewStats(Ref ref) async {
  ref.watch<int>(completionCommittedProvider);
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  // SQL-filtered: excludes bulk-mark sentinel (trackId = 0) at the DB layer.
  final trackCompletions = await db.completionDao
      .getTrackOnlyCompletionsByProfile(profileId);
  final uniqueItems = <String>{};
  for (final c in trackCompletions) {
    uniqueItems.add('${c.curriculumId}:${c.sefariaRef}');
  }
  return ProgressOverviewStats(
    totalCompletions: trackCompletions.length,
    totalUniqueItems: uniqueItems.length,
  );
}

/// Provider that fetches completions for a single curriculum via
/// [ProgressRepository].
///
/// Using [ProgressRepository] (not [CompletionRepository]) keeps the history
/// screen decoupled from write-side concerns (sync engine, content repository)
/// and makes widget testing simpler — only [userDatabaseProvider] needs to be
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
  final db = ref.watch(userDatabaseProvider);

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
  final stageRepository = ref.watch(
    stageDefinitionRepositoryProvider(curriculumEnum),
  );
  final stageDefinitions = await stageRepository.getStagesForCurriculum(
    curriculumEnum,
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
///
/// F2 fix: uses [PaceCalculator.compute] from the progress domain so that
/// bulk-marked completions (sentinel date 2000-01-01) are excluded from live
/// velocity via the [trackStartDate] filter. Previously the scheduler's
/// [PaceCalculator.calculate] received ALL personal completions including
/// bulk entries, causing phantom "Ahead by 296 days on day 1" results.
@riverpod
Future<PaceCalculator?> curriculumPaceStatus(
  Ref ref,
  String curriculumId,
) async {
  ref.watch<int>(completionCommittedProvider);
  final db = ref.watch(userDatabaseProvider);
  final now = ref.watch(clockProvider);
  final profileId = ref.watch(activeProfileIdProvider);

  // Resolve CurriculumId enum for content.
  final curriculumEnum = CurriculumId.values
      .where((c) => c.storageKey == curriculumId)
      .firstOrNull;
  if (curriculumEnum == null) return null;

  // Get goals for this curriculum.
  final goals = await db.goalDao.getGoalsByCurriculumAndProfile(
    curriculumId,
    profileId,
  );
  if (goals.isEmpty) return null;

  // Pick the most recently created goal — defends against stale rows.
  final goal = goals.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
  if (goal.targetDate == null) return null;

  // Fetch the track to get activatedAt (= trackStartDate).
  final track = await db.trackDao.getTrackById(goal.trackId);
  if (track == null) return null;

  // trackStartDate = local-day midnight of the track's activatedAt.
  final trackStartDate = DateUtils.extractLocalDate(track.activatedAt);

  // Use scoped item count for pace calculation.
  final totalItems = await ref.watch(
    scopedItemCountProvider(curriculumEnum).future,
  );

  // Get personal-track completions.
  final allCompletions = await db.completionDao
      .getCompletionsByCurriculumAndProfile(curriculumId, profileId);
  final personalCompletions = allCompletions
      .where((c) => c.trackType == TrackType.personal.storageKey)
      .toList();

  // Split completions into bulk baseline (before trackStartDate) and live
  // (on or after trackStartDate). Bulk entries have sentinel date 2000-01-01
  // which is always before any real trackStartDate.
  final bulkBaseline = personalCompletions.where((c) {
    final local = DateUtils.extractLocalDate(c.completedAt);
    return local.isBefore(trackStartDate);
  }).length;
  final liveProgress = personalCompletions.where((c) {
    final local = DateUtils.extractLocalDate(c.completedAt);
    return !local.isBefore(trackStartDate);
  }).length;

  // F5 — telemetry: detect bulk leakage (live completions dated before
  // trackStartDate slipping through). This should always fire zero; if it
  // fires, the date filter regressed.
  if (liveProgress > 0) {
    final leaked = personalCompletions.where((c) {
      final local = DateUtils.extractLocalDate(c.completedAt);
      return !local.isBefore(trackStartDate) &&
          c.completedAt.isBefore(DateTime(2001));
    });
    if (leaked.isNotEmpty) {
      AppLogger.instance.warning(
        event: 'pace_bulk_leakage_detected',
        fields: {'leakedCount': leaked.length, 'curriculumId': curriculumId},
      );
    }
  }

  final targetDate = DateUtils.extractLocalDate(goal.targetDate!.toLocal());
  final today = DateUtils.extractLocalDate(now);

  return PaceCalculator.compute(
    totalItems: totalItems,
    bulkBaseline: bulkBaseline,
    liveProgress: liveProgress,
    trackStartDate: trackStartDate,
    targetDate: targetDate,
    today: today,
  );
}
