import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/progress/domain/repositories/progress_repository.dart';
import 'package:learning_tracker/features/progress/domain/services/curriculum_progress_service.dart';
import 'package:learning_tracker/features/progress/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
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

/// Provider for completion counts by curriculum, scoped to the active profile.
///
/// Returns a map keyed by the internal track storage key. One track per
/// curriculum, so this is a single-entry map — not a user-facing concept.
@riverpod
Future<Map<String, int>> trackBreakdown(Ref ref, String curriculumId) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return db.completionDao.getTrackBreakdownByProfile(curriculumId, profileId);
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
    .family<List<CompletionEntity>, String>((ref, curriculumId) async {
      final repository = ref.watch(progressRepositoryProvider);
      return repository.getCompletionsByCurriculum(curriculumId);
    });

/// Provider that fetches completions across all curricula.
///
/// Used when no curriculumId filter is applied.
final allCompletionHistoryProvider =
    FutureProvider.autoDispose<List<CompletionEntity>>((ref) async {
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
  // CP-02: recompute whenever a completion is committed so the Breakdown by
  // Level cards update live without the user having to pull-to-refresh.
  ref.watch<int>(completionCommittedProvider);
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
/// F2 fix: uses [ProgressPaceCalculator.compute] from the progress domain so that
/// bulk-marked completions (sentinel date 2000-01-01) are excluded from live
/// velocity via the [trackStartDate] filter. Previously the scheduler's
/// [ProgressPaceCalculator.calculate] received ALL personal completions including
/// bulk entries, causing phantom "Ahead by 296 days on day 1" results.
@riverpod
Future<ProgressPaceCalculator?> curriculumPaceStatus(
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
  final trackStartDate = LocalDayUtils.extractLocalDate(track.activatedAt);

  // Use scoped item count for pace calculation.
  final totalItems = await ref.watch(
    scopedItemCountProvider(curriculumEnum).future,
  );

  // Rule-7 (no track types): all tracks are implicitly personal now, so the
  // `trackType == personal` filter was a no-op that could wrongly drop rows.
  // Use every completion for the pace calculation.
  final allCompletions = await db.completionDao
      .getCompletionsByCurriculumAndProfile(curriculumId, profileId);

  // Split completions into bulk baseline (before trackStartDate) and live
  // (on or after trackStartDate). Bulk entries have sentinel date 2000-01-01
  // which is always before any real trackStartDate.
  //
  // Count DISTINCT sefariaRefs, NOT raw completion_events rows: chazara-enabled
  // tracks store one row per stage (learn + chazara1 + chazara2), so a row count
  // over-counts live progress by the stage multiplier (up to 3x) while
  // [totalItems] (scopedItemCountProvider) counts distinct leaf items. Mixing a
  // row-based numerator with an item-based denominator drove a phantom "ahead"
  // signal on multi-stage tracks (the same F2 class this provider already
  // guards date-wise). Partition each ref by whether it has ANY live completion:
  // a ref counts as live if any of its stages was completed on/after
  // trackStartDate, otherwise it counts toward the bulk baseline.
  final liveRefs = <String>{};
  final bulkRefs = <String>{};
  for (final c in allCompletions) {
    final local = LocalDayUtils.extractLocalDate(c.completedAt);
    if (local.isBefore(trackStartDate)) {
      bulkRefs.add(c.sefariaRef);
    } else {
      liveRefs.add(c.sefariaRef);
    }
  }
  // A ref with any live completion is live, even if it also has a bulk-dated
  // stage; remove such refs from the bulk baseline to avoid double-counting.
  bulkRefs.removeAll(liveRefs);
  final bulkBaseline = bulkRefs.length;
  final liveProgress = liveRefs.length;

  // F5 — telemetry: detect bulk leakage (live completions dated before
  // trackStartDate slipping through). This should always fire zero; if it
  // fires, the date filter regressed.
  if (liveProgress > 0) {
    final leaked = allCompletions.where((c) {
      final local = LocalDayUtils.extractLocalDate(c.completedAt);
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

  final targetDate = LocalDayUtils.extractLocalDate(goal.targetDate!.toLocal());
  final today = LocalDayUtils.extractLocalDate(now);

  return ProgressPaceCalculator.compute(
    totalItems: totalItems,
    bulkBaseline: bulkBaseline,
    liveProgress: liveProgress,
    trackStartDate: trackStartDate,
    targetDate: targetDate,
    today: today,
  );
}
