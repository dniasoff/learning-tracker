import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/optimistic_completion_provider.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'completion_providers.g.dart';

/// Internal storage key written to the `track_type` column of the completion
/// event log. There is exactly one track per (profile, curriculum), so this is
/// a fixed constant — it is never surfaced as a user-facing "track type" label.
final trackStorageKeyForTrackIdProvider = FutureProvider.autoDispose
    .family<String, CurriculumId>((ref, curriculumId) async {
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

/// Provides the legacy completion repository — storage and reads only.
/// Story 1.11 (DNI-473) moved every owner learning write onto
/// `LearningCommands` (`learning_events`); the R1 story retires this
/// repository with its readers.
///
/// **Firestore-backed** via [FirestoreCompletionRepositoryAdapter] (wired
/// Phase 3, T-20). The Drift-backed [CompletionRepositoryImpl] is
/// deprecated and will be removed in Phase 4.
@riverpod
CompletionRepository completionRepository(Ref ref) {
  return FirestoreCompletionRepositoryAdapter(ref: ref);
}

/// Resolves a persisted curriculum-id storage key, throwing on an
/// unrecognised value — a bad key here is a caller bug, not a not-ready
/// backend, so it must never be swallowed into a silent empty result.
CurriculumId _requireCurriculumId(String storageKey) {
  final id = CurriculumId.fromStorageKey(storageKey);
  if (id == null) {
    throw ArgumentError.value(
      storageKey,
      'curriculumId',
      'Unknown CurriculumId storage key',
    );
  }
  return id;
}

/// Provides the number of completions for a specific content item,
/// scoped to the active profile.
@riverpod
Future<int> completionCount(
  Ref ref, {
  required String curriculumId,
  required String sefariaRef,
}) async {
  final repository = ref.watch(completionRepositoryProvider);
  final completions = await repository.getCompletionsForContentItem(sefariaRef);
  return completions
      .where((c) => c.curriculumId.storageKey == curriculumId)
      .length;
}

/// Batch review counts for all items in a curriculum (AC-3, AC-7).
@riverpod
Future<Map<String, int>> reviewCountsForCurriculum(
  Ref ref,
  String curriculumId,
) async {
  final repository = ref.watch(completionRepositoryProvider);
  return repository.getReviewCountsForCurriculum(
    _requireCurriculumId(curriculumId),
  );
}

/// Per-stage breakdown for a single item (AC-1, AC-5).
@riverpod
Future<Map<int, int>> itemStageBreakdown(
  Ref ref,
  ({String curriculumId, String sefariaRef}) params,
) async {
  final repository = ref.watch(completionRepositoryProvider);
  return repository.getStageBreakdownForItem(
    curriculumId: _requireCurriculumId(params.curriculumId),
    sefariaRef: params.sefariaRef,
  );
}
