import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_goal_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';

/// Thrown by [FirestoreGoalRepositoryAdapter]'s write methods when
/// `firestoreGoalRepositoryProvider` resolves to `null` — see
/// `BookmarkRepositoryNotReadyException`'s doc comment
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`)
/// for the read-vs-write split this mirrors: reads reuse a natural "nothing
/// yet" value (`[]`), writes have no such value and throw instead.
class GoalRepositoryNotReadyException implements Exception {
  const GoalRepositoryNotReadyException();

  @override
  String toString() =>
      'GoalRepositoryNotReadyException: firestoreGoalRepositoryProvider '
      'resolved to null (no active account, or no active learner profile, '
      'yet) — cannot complete a goal write until one is active.';
}

/// Firestore-backed adapter over [FirestoreGoalRepository]. Follows the
/// pattern `FirestoreBookmarkRepositoryAdapter`
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`)
/// establishes — read that class's doc comment first; this one only calls
/// out what is DIFFERENT here.
///
/// ## Now `implements` [GoalRepository] — the id mismatch that used to block
/// this is gone
///
/// [GoalRepository.updateGoal]/[GoalRepository.deleteGoal] used to take
/// `int goalId`, addressing a goal by [GoalDao]'s Drift-local autoincrement
/// primary key — a key [FirestoreGoalRepository] never had (a Firestore goal
/// is identified by [GoalEntity.firestoreId], `curriculumId` + `createdAt`;
/// see that repository's class doc comment, "Doc-id"). Owner decision 4
/// (`docs/firestore-rewrite-map.md`) widened the interface to pass the
/// [GoalEntity] itself instead of a row number — both call sites
/// (`TrackEditService.editTrack`,
/// `TrackCreationService._deleteExistingGoals`) already held the goal they
/// were editing, so the `int` was pure indirection. With that gone,
/// [updateGoal]/[deleteGoal] below already matched
/// [FirestoreGoalRepository]'s own entity-keyed shapes — nothing to change
/// there but the `@override` annotation.
///
/// ## Not-ready semantics
///
/// All operations throw [GoalRepositoryNotReadyException] when the backend is
/// not ready; empty reads must not be confused with a real empty result.
class FirestoreGoalRepositoryAdapter implements GoalRepository {
  FirestoreGoalRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Re-reads `firestoreGoalRepositoryProvider`, resolving to `null` exactly
  /// when it does (no active account, or no active learner profile). See
  /// `FirestoreBookmarkRepositoryAdapter._resolveOrNull`'s doc comment for
  /// why this re-reads on every call rather than caching.
  Future<FirestoreGoalRepository?> _resolveOrNull() {
    return _ref.read(firestoreGoalRepositoryProvider.future);
  }

  /// Like [_resolveOrNull], but throws [GoalRepositoryNotReadyException]
  /// instead of returning `null` — for the three write methods; see the
  /// class doc comment.
  Future<FirestoreGoalRepository> _resolve() async {
    final repo = await _resolveOrNull();
    if (repo == null) {
      throw const GoalRepositoryNotReadyException();
    }
    return repo;
  }

  /// Returns all goals for [curriculumId], sorted by `targetDate`
  /// (null-first, ascending). Throws when not ready.
  @override
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId) async {
    final repo = await _resolve();
    return repo.getGoals(curriculumId);
  }

  /// Live updates for [curriculumId]'s goal list. See
  /// [FirestoreCurriculumTrackRepositoryAdapter]'s class doc comment
  /// ("Not-ready semantics") for the one-shot-resolve limitation shared by
  /// every `watch*` method built in this wave: this does not re-subscribe
  /// if the active account/profile changes after the stream opens while
  /// not-ready. Throws when not ready.
  Stream<List<GoalEntity>> watchGoals(CurriculumId curriculumId) async* {
    final repo = await _resolve();
    yield* repo.watchGoals(curriculumId);
  }

  /// Creates a new goal for [curriculumId]. Throws
  /// [GoalRepositoryNotReadyException] when not ready.
  ///
  /// [paceGranularity] is the interface's raw storage-key string (unlike
  /// [updateGoal]'s typed [PaceGranularity] param — an existing asymmetry in
  /// [GoalRepository] itself, not introduced here). Resolved to the typed
  /// enum when it matches a known value, else preserved verbatim via
  /// [FirestoreGoalRepository.createGoal]'s `rawLearningUnit` — the same
  /// fallback [GoalEntity.paceGranularityKey] documents.
  @override
  Future<GoalEntity> createGoal({
    required CurriculumId curriculumId,
    required double targetPercent,
    PaceTarget? paceTarget,
    String description = '',
    String dateType = 'gregorian',
    String? paceGranularity,
  }) async {
    final repo = await _resolve();
    final granularity = PaceGranularity.fromStorageKey(paceGranularity);
    return repo.createGoal(
      curriculumId: curriculumId,
      targetPercent: targetPercent,
      paceTarget: paceTarget,
      description: description,
      dateType: dateType,
      paceGranularity: granularity,
      rawLearningUnit: granularity == null ? paceGranularity : null,
    );
  }

  /// Updates [goal] and writes the result back to the same Firestore
  /// document (see [FirestoreGoalRepository.updateGoal]'s doc comment).
  /// Throws [GoalRepositoryNotReadyException] when not ready.
  @override
  Future<GoalEntity> updateGoal({
    required GoalEntity goal,
    double? targetPercent,
    PaceTarget? paceTarget,
    bool clearPaceTarget = false,
    String? description,
    PaceGranularity? paceGranularity,
    String? rawLearningUnit,
    bool clearLearningUnit = false,
  }) async {
    final repo = await _resolve();
    return repo.updateGoal(
      goal: goal,
      targetPercent: targetPercent,
      paceTarget: paceTarget,
      clearPaceTarget: clearPaceTarget,
      description: description,
      paceGranularity: paceGranularity,
      rawLearningUnit: rawLearningUnit,
      clearLearningUnit: clearLearningUnit,
    );
  }

  /// Hard-deletes [goal]'s Firestore document. Throws
  /// [GoalRepositoryNotReadyException] when not ready.
  @override
  Future<void> deleteGoal(GoalEntity goal) async {
    final repo = await _resolve();
    await repo.deleteGoal(goal);
  }
}
