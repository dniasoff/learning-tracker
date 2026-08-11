import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/learning/data/completion_points_awarder.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_streak_recorder.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/bulk_mark_completion_use_case.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/mark_completion_use_case.dart';
import 'package:learning_tracker/features/learning/presentation/providers/bookmark_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/optimistic_completion_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'completion_providers.g.dart';

/// Internal storage key written to the `track_type` column of the completion
/// event log. There is exactly one track per (profile, curriculum), so this is
/// a fixed constant — it is never surfaced as a user-facing "track type" label.
final trackStorageKeyForTrackIdProvider = FutureProvider.autoDispose
    .family<String, int>((ref, trackId) async {
      return 'personal';
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

/// Provides the completion repository — storage-only since the
/// completion-orchestrator lift (`docs/firestore-rewrite-map.md`, owner
/// decision 1). See [completionOrchestratorProvider] for where order
/// validation, points, siyum detection, bookmark advance and streak now
/// live.
///
/// **Firestore-backed** via [FirestoreCompletionRepositoryAdapter] (wired
/// Phase 3, T-20). The Drift-backed [CompletionRepositoryImpl] is
/// deprecated and will be removed in Phase 4.
@riverpod
CompletionRepository completionRepository(Ref ref) {
  return FirestoreCompletionRepositoryAdapter(ref: ref);
}

/// Drift-backed [CompletionPointsPort] — see that class's doc comment.
@riverpod
CompletionPointsPort completionPointsPort(Ref ref) {
  final database = ref.watch(userDatabaseProvider);
  final syncFacade = ref.watch(syncWriteFacadeProvider);
  return DriftCompletionPointsAwarder(
    database: database,
    rewardMilestoneServiceFactory: (profileId) =>
        RewardMilestoneService(database, profileId: profileId),
    syncEngine: syncFacade,
  );
}

/// Firestore-backed [CompletionStreakPort] — see that class's doc comment.
///
/// The recorder resolves its own repository from `ref`, so this presentation
/// provider never names a data-access-ring type (AD-23/AD-28).
@riverpod
CompletionStreakPort completionStreakPort(Ref ref) {
  return FirestoreCompletionStreakRecorder(ref: ref);
}

/// Provides the [CompletionOrchestrator] — the single place the five
/// completion side effects live (`docs/firestore-rewrite-map.md`, owner
/// decision 1). [MarkCompletionUseCase], [BulkMarkCompletionUseCase], and
/// (via `onboarding_providers.dart`) `BulkPriorCompletionService` all go
/// through this, not [completionRepositoryProvider] directly.
@riverpod
CompletionOrchestrator completionOrchestrator(Ref ref) {
  final contentRepository = ref.watch(contentRepositoryProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final stageRepository = ref.watch(globalStageRepositoryProvider);
  final ledgerRepository = ref.watch(learningLedgerRepositoryProvider);

  final bookmarkRepository = ref.watch(bookmarkRepositoryProvider);

  final completionRepository = ref.watch(completionRepositoryProvider);

  final detectionService = CompletionDetectionService(
    completionRepository: completionRepository,
    contentRepository: contentRepository,
    ledgerRepository: ledgerRepository,
    stageRepository: stageRepository,
  );

  return CompletionOrchestrator(
    repository: completionRepository,
    contentRepository: contentRepository,
    activeProfileId: profileId,
    bookmarkRepository: bookmarkRepository,
    completionDetectionService: detectionService,
    pointsPort: ref.watch(completionPointsPortProvider),
    streakPort: ref.watch(completionStreakPortProvider),
  );
}

/// Provides the mark completion use case.
@riverpod
MarkCompletionUseCase markCompletionUseCase(Ref ref) {
  final orchestrator = ref.watch(completionOrchestratorProvider);
  final analytics = ref.watch(analyticsServiceProvider);
  return MarkCompletionUseCase(orchestrator, analytics: analytics);
}

/// Provides the bulk mark completion use case.
@riverpod
BulkMarkCompletionUseCase bulkMarkCompletionUseCase(Ref ref) {
  final orchestrator = ref.watch(completionOrchestratorProvider);
  return BulkMarkCompletionUseCase(orchestrator);
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
