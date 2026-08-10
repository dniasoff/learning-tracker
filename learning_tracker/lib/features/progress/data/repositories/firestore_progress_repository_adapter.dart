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
/// Thrown by [FirestoreProgressRepositoryAdapter]'s reads when
/// `firestoreCompletionRepositoryProvider` resolves to `null`.
///
/// Owner ruling D-E, applied to ACHIEVEMENT-shaped reads. Every method here
/// answers "how much has this learner completed", where `0` / `[]` / `{}` is
/// indistinguishable from a truthful answer — so a not-ready backend previously
/// rendered as "you have achieved nothing", invisibly, to the learner and to
/// every gate.
///
/// This deliberately does NOT extend to configuration-shaped adapters
/// (curriculum tracks, learning order, study-day configs, goals): an empty
/// CONFIGURATION list is a legitimate state the UI already renders, whereas a
/// fabricated achievement total is not.
class ProgressRepositoryNotReadyException implements Exception {
  const ProgressRepositoryNotReadyException();

  @override
  String toString() =>
      'ProgressRepositoryNotReadyException: '
      'firestoreCompletionRepositoryProvider resolved to null (no active '
      'account, or no active learner profile, yet) — refusing to report a '
      'progress figure that would be indistinguishable from a real zero.';
}

class FirestoreProgressRepositoryAdapter implements ProgressRepository {
  FirestoreProgressRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Re-reads `firestoreCompletionRepositoryProvider`, resolving to `null`
  /// exactly when it does (no active account, or no active learner
  /// profile). Re-resolved on every call rather than cached — see
  /// `FirestoreBookmarkRepositoryAdapter`'s class doc comment (point 3) for
  /// why.
  /// Like [_resolveOrNull], but throws — see
  /// [ProgressRepositoryNotReadyException] for why every read here throws.
  Future<FirestoreCompletionRepository> _resolve() async {
    final repo = await _resolveOrNull();
    if (repo == null) {
      throw const ProgressRepositoryNotReadyException();
    }
    return repo;
  }

  /// Resolves a storage key to its [CurriculumId], THROWING on an unknown key.
  ///
  /// Previously an unrecognised key silently produced `0` / `[]` / `{}` — the
  /// same fabricated-achievement defect as a not-ready backend, but caused by a
  /// programming error rather than timing. Mis-attributing a learner's progress
  /// to "nothing" must never be the quiet path.
  static CurriculumId _curriculumFor(String storageKey) {
    final id = CurriculumId.fromStorageKey(storageKey);
    if (id == null) {
      throw ArgumentError('Unknown curriculumId: $storageKey');
    }
    return id;
  }

  Future<FirestoreCompletionRepository?> _resolveOrNull() {
    return _ref.read(firestoreCompletionRepositoryProvider.future);
  }

  @override
  Future<Map<String, int>> getTrackBreakdown(String curriculumId) async {
    final repo = await _resolve();
    final id = _curriculumFor(curriculumId);
    return repo.getTrackTypeBreakdownForCurriculum(id);
  }

  @override
  Future<int> getAggregateCount(String curriculumId) async {
    final repo = await _resolve();
    final id = _curriculumFor(curriculumId);
    return repo.getAggregateCountForCurriculum(id);
  }

  @override
  Future<List<CompletionEntity>> getCompletionsByCurriculum(
    String curriculumId,
  ) async {
    final repo = await _resolve();
    final id = _curriculumFor(curriculumId);
    return repo.getCompletionsForCurriculum(id);
  }

  @override
  Future<List<CompletionEntity>> getAllCompletions() async {
    final repo = await _resolve();
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
