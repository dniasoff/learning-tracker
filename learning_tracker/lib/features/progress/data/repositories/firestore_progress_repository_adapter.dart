/// Firestore-backed [ProgressRepository] adapter — follows the reference
/// pattern `FirestoreBookmarkRepositoryAdapter`
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`).
/// Read that class's doc comment first (the numbered "pattern to copy"
/// list); this file only calls out what is DIFFERENT for progress.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/progress/domain/repositories/progress_repository.dart';

/// Firestore-backed [ProgressRepository] adapter.
///
/// ## Delegates to the completions repository — does not own one
///
/// `docs/firestore-rewrite-map.md`'s progress note: "progress uses GROUP
/// BY/COUNT(DISTINCT) via the completions DAO... those become client-side
/// computation over a bounded query. The completions adapter is another
/// agent's — do NOT build one." This class therefore never imports
/// `cloud_firestore` and never constructs a `FirestoreCompletionRepository`
/// itself — every read goes through `firestoreCompletionRepositoryProvider`
/// (`lib/data/firestore/repository_providers.dart`), which is already wired
/// to a real, ready instance. Like every provider in that file (see
/// [_resolveOrNull]), it resolves `null` only while no account or learner
/// profile is active yet — the same "not ready yet, show a loading/empty
/// state" contract every provider there documents, not a stub — and every
/// method below falls back to its "not ready" value in exactly that case.
///
/// This class is not itself wired into `progressRepositoryProvider` yet —
/// that provider (`progress_providers.dart`) still returns the Drift-era
/// `ProgressRepositoryImpl`. Rewiring the progress feature onto this
/// adapter is a separate task that has not happened yet.
///
/// [FirestoreCompletionRepository]'s own aggregate methods
/// (`getTrackTypeBreakdownForCurriculum`, `getAggregateCountForCurriculum`)
/// already compute client-side over a bounded, paginated query — see that
/// class's doc comment, "Aggregates are computed client-side" — so
/// [getTrackBreakdown] and [getAggregateCount] below are a direct,
/// behavior-preserving delegation: same curriculum+profile scoping as the
/// Drift-era `CompletionDao.getTrackBreakdownByProfile` /
/// `getAggregateCountByProfile` (no tier/source filter in either — verified
/// by reading both DAO methods), just re-homed onto the Firestore-side
/// equivalents.
///
/// ## `getCompletionsByCurriculum` / `getAllCompletions`: resolved — owner
/// decision 3
///
/// [ProgressRepository]'s interface used to return `List<Completion>` — the
/// Drift class from `lib/core/database/daos/completion_dao.dart`, which
/// carries an autoincrement `int id`, an `int profileId`, and an `int
/// trackId` — none of which [FirestoreCompletionRepository]'s
/// `CompletionEntity` has (see that class's own doc comment: "Firestore-
/// shaped — not a port of the Drift-era `Completion` class"). Owner decision
/// 3 (`docs/firestore-rewrite-map.md`) widened [ProgressRepository] to
/// return `CompletionEntity` directly instead, after confirming the two
/// consumers of these methods (`completionHistoryForCurriculumProvider`,
/// `allCompletionHistoryProvider`) never read `.id`/`.profileId`/`.trackId`
/// — they pass the list straight through. Both methods below now delegate
/// directly, the same shape as [getTrackBreakdown]/[getAggregateCount].
class FirestoreProgressRepositoryAdapter implements ProgressRepository {
  FirestoreProgressRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Re-reads `firestoreCompletionRepositoryProvider`, resolving to `null`
  /// exactly when it does (no active account, or no active learner
  /// profile). Re-resolved on every call rather than cached — see
  /// `FirestoreBookmarkRepositoryAdapter`'s class doc comment (point 3) for
  /// why.
  Future<FirestoreCompletionRepository?> _resolveOrNull() {
    return _ref.read(firestoreCompletionRepositoryProvider.future);
  }

  @override
  Future<Map<String, int>> getTrackBreakdown(String curriculumId) async {
    final repo = await _resolveOrNull();
    if (repo == null) return const {};
    final id = CurriculumId.fromStorageKey(curriculumId);
    if (id == null) return const {};
    return repo.getTrackTypeBreakdownForCurriculum(id);
  }

  @override
  Future<int> getAggregateCount(String curriculumId) async {
    final repo = await _resolveOrNull();
    if (repo == null) return 0;
    final id = CurriculumId.fromStorageKey(curriculumId);
    if (id == null) return 0;
    return repo.getAggregateCountForCurriculum(id);
  }

  @override
  Future<List<CompletionEntity>> getCompletionsByCurriculum(
    String curriculumId,
  ) async {
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    final id = CurriculumId.fromStorageKey(curriculumId);
    if (id == null) return const [];
    return repo.getCompletionsForCurriculum(id);
  }

  @override
  Future<List<CompletionEntity>> getAllCompletions() async {
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    // No curriculumId filter + CompletionTierFilter.lifetime == every
    // completion in the collection (see
    // FirestoreCompletionRepository.getCompletionsByTier's doc comment:
    // `trackAchievement`/`lifetime` return the same result set here, since
    // `completions` can only ever hold `live`/`bulkInTrack` documents) —
    // the same "no tier filter" scope the Drift-era
    // `CompletionDao.getCompletionsByProfile` this replaces had.
    return repo.getCompletionsByTier(tier: CompletionTierFilter.lifetime);
  }
}
