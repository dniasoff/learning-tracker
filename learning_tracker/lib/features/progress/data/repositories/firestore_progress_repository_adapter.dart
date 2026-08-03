/// Firestore-backed [ProgressRepository] adapter — follows the reference
/// pattern `FirestoreBookmarkRepositoryAdapter`
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`).
/// Read that class's doc comment first (the numbered "pattern to copy"
/// list); this file only calls out what is DIFFERENT for progress.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart'
    show Completion;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/features/progress/domain/repositories/progress_repository.dart';

/// Thrown by [FirestoreProgressRepositoryAdapter.getCompletionsByCurriculum]
/// and [FirestoreProgressRepositoryAdapter.getAllCompletions] — see the
/// class doc comment's "A real type-shape gap" section for why these two
/// methods cannot honestly be implemented against the current
/// [ProgressRepository] interface, regardless of whether the underlying
/// Firestore provider is ready.
class ProgressRepositoryUnsupportedException implements Exception {
  const ProgressRepositoryUnsupportedException(this.method);

  /// Name of the [ProgressRepository] method that cannot be served.
  final String method;

  @override
  String toString() =>
      'ProgressRepositoryUnsupportedException: $method cannot be served by '
      'FirestoreProgressRepositoryAdapter — ProgressRepository\'s interface '
      'returns List<Completion> (the Drift class from '
      'lib/core/database/daos/completion_dao.dart, carrying an autoincrement '
      'int id, an int profileId, and an int trackId), but '
      'FirestoreCompletionRepository hands back CompletionEntity instead, '
      'which deliberately has none of those three fields. See this class\'s '
      'doc comment for the full reasoning and what unblocks it.';
}

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
/// (`lib/data/firestore/repository_providers.dart`), which some other task
/// is responsible for wiring to a real, ready instance. Until that happens
/// this adapter behaves exactly like every other not-yet-activated provider
/// in this file (see [_resolveOrNull]): the provider resolves `null`
/// (`activeProfileDocIdProvider` is unset in production today — see that
/// provider's doc comment), and every method below falls back to its "not
/// ready" value.
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
/// ## `getCompletionsByCurriculum` / `getAllCompletions`: a real type-shape
/// gap, not an oversight
///
/// [ProgressRepository]'s interface returns `List<Completion>` — the Drift
/// class from `lib/core/database/daos/completion_dao.dart`, which carries an
/// autoincrement `int id`, an `int profileId`, and an `int trackId`.
/// [FirestoreCompletionRepository] hands back `CompletionEntity`
/// (`lib/features/learning/domain/entities/completion_entity.dart`)
/// instead, whose own class doc comment states plainly it is
/// "Firestore-shaped — not a port of the Drift-era `Completion` class" and
/// deliberately drops exactly those three fields: no autoincrement id
/// exists for a Firestore document, `profileId` is redundant with the
/// collection path, and AD-25 retired the per-device `trackId` entirely.
///
/// There is no honest value to put in those three fields for a
/// Firestore-sourced row — synthesizing one (`0`, a hash, whatever) would
/// silently fabricate data a caller might reasonably key off of (e.g. a
/// screen that groups completions by `trackId`). Rather than invent a
/// sentinel, these two methods throw
/// [ProgressRepositoryUnsupportedException] unconditionally — loud and
/// catchable by name, not a silently-wrong `Completion`, and not
/// conditioned on provider readiness (the gap exists whether or not an
/// active profile is resolved). Unblocking these two needs a decision
/// outside this adapter's scope: either widen [ProgressRepository] itself
/// to return `CompletionEntity` (rippling into `ProgressRepositoryImpl` and
/// every presentation call site that reads `.id`/`.trackId` off a
/// `Completion`), or give progress its own Firestore-shaped completion
/// projection. Flagged for the task owner rather than decided here.
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
  Future<List<Completion>> getCompletionsByCurriculum(
    String curriculumId,
  ) async {
    // See the class doc comment's "A real type-shape gap" section.
    throw const ProgressRepositoryUnsupportedException(
      'getCompletionsByCurriculum',
    );
  }

  @override
  Future<List<Completion>> getAllCompletions() async {
    // See the class doc comment's "A real type-shape gap" section.
    throw const ProgressRepositoryUnsupportedException('getAllCompletions');
  }
}
