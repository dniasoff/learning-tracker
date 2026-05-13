import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/learning/completion_writer_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/bulk_mark_completion_use_case.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/mark_completion_use_case.dart';
import 'package:learning_tracker/features/learning/presentation/providers/bookmark_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/optimistic_completion_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'completion_providers.g.dart';

/// Storage key for [CurriculumTracks.trackType] (e.g. [TrackType.personal.storageKey]).
final trackStorageKeyForTrackIdProvider = FutureProvider.autoDispose
    .family<String, int>((ref, trackId) async {
      final db = ref.watch(userDatabaseProvider);
      final row = await db.trackDao.getTrackById(trackId);
      if (row == null) return TrackType.personal.storageKey;
      return row.trackType;
    });

/// Provider family to check whether a specific stage is already completed.
///
/// Checks optimistic state first (instant), then falls back to DB query.
/// Watches [completionCommittedProvider] so the DB check re-runs after every
/// successful completion commit (Story 26.13).
final isStageCompletedProvider = FutureProvider.autoDispose
    .family<bool, ({String sefariaRef, int stageId, String trackType})>((
      ref,
      params,
    ) async {
      ref.watch<int>(completionCommittedProvider);
      // Check optimistic state first — instant, no DB query needed
      final optimistic = ref.watch(optimisticCompletionStateProvider);
      final key = optimisticKey(
        sefariaRef: params.sefariaRef,
        stageId: params.stageId,
        trackType: params.trackType,
      );
      if (optimistic.contains(key)) return true;

      final repository = ref.watch(completionRepositoryProvider);
      return repository.isStageCompleted(
        sefariaRef: params.sefariaRef,
        stageId: params.stageId,
        trackType: params.trackType,
      );
    });

/// Provides the completion repository.
@riverpod
CompletionRepository completionRepository(Ref ref) {
  final database = ref.watch(userDatabaseProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  final contentRepository = ref.watch(contentRepositoryProvider);

  final bookmarkRepository = ref.watch(bookmarkRepositoryProvider);

  final profileId = ref.watch(activeProfileIdProvider);
  final ledgerRepository = ref.watch(learningLedgerRepositoryProvider);
  final rewardMilestoneService = RewardMilestoneService(
    database,
    profileId: profileId,
  );

  final detectionService = CompletionDetectionService(
    database: database,
    contentRepository: contentRepository,
    ledgerRepository: ledgerRepository,
  );

  return CompletionRepositoryImpl(
    database: database,
    syncEngine: syncEngine,
    contentRepository: contentRepository,
    bookmarkRepository: bookmarkRepository,
    completionDetectionService: detectionService,
    rewardMilestoneService: rewardMilestoneService,
    activeProfileId: profileId,
    completionWriter: ref.watch(completionWriterProvider),
  );
}

/// Provides the mark completion use case.
@riverpod
MarkCompletionUseCase markCompletionUseCase(Ref ref) {
  final repository = ref.watch(completionRepositoryProvider);
  return MarkCompletionUseCase(repository);
}

/// Provides the bulk mark completion use case.
@riverpod
BulkMarkCompletionUseCase bulkMarkCompletionUseCase(Ref ref) {
  final repository = ref.watch(completionRepositoryProvider);
  return BulkMarkCompletionUseCase(repository);
}

/// Provides the number of completions for a specific content item,
/// scoped to the active profile.
@riverpod
Future<int> completionCount(
  Ref ref, {
  required String curriculumId,
  required String sefariaRef,
}) async {
  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final completions = await database.completionDao
      .getCompletionsForContentAndProfile(sefariaRef, profileId);
  return completions.where((c) => c.curriculumId == curriculumId).length;
}

/// Batch review counts for all items in a curriculum (AC-3, AC-7).
/// Single GROUP BY query — avoids N+1 per-item watches.
@riverpod
Future<Map<String, int>> reviewCountsForCurriculum(
  Ref ref,
  String curriculumId,
) async {
  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return database.completionDao.getReviewCountsByItem(curriculumId, profileId);
}

/// Per-stage breakdown for a single item (AC-1, AC-5).
@riverpod
Future<Map<int, int>> itemStageBreakdown(
  Ref ref,
  ({String curriculumId, String sefariaRef}) params,
) async {
  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return database.completionDao.getStageBreakdownByItem(
    params.curriculumId,
    params.sefariaRef,
    profileId,
  );
}
