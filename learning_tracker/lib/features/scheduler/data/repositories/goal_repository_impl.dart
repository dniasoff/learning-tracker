import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_goal_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';

/// Converts a Drift [Goal] row into the storage-agnostic [GoalEntity] that
/// [GoalRepository]'s interface now speaks in terms of everywhere (owner
/// decision 4, `docs/firestore-rewrite-map.md`: goals are addressed by
/// value, not by row number). Exposed at top level — not just as
/// [GoalRepositoryImpl]'s private mapping helper — so the other two call
/// sites that already hold a Drift [Goal] row and need to hand a
/// [GoalEntity] to [GoalRepository.updateGoal]/[GoalRepository.deleteGoal]
/// (`TrackCreationService._deleteExistingGoals` and
/// `edit_track_screen.dart`'s save handler) share one mapping instead of
/// hand-rolling a second/third copy that could silently drift from this one
/// (`track_detail_screen.dart` already had its own private copy,
/// `_goalRowToEntity`, before this — the exact duplication this guards
/// against going forward).
GoalEntity goalEntityFromRow(Goal goal) {
  final rawUnit = goal.paceGranularity;
  final granularity = PaceGranularity.fromStorageKey(rawUnit);
  return GoalEntity(
    id: goal.id,
    curriculumId: CurriculumId.values.firstWhere(
      (c) => c.storageKey == goal.curriculumId,
    ),
    trackId: goal.trackId,
    targetPercent: goal.targetPercent,
    targetDate: goal.targetDate?.toUtc(),
    description: goal.description,
    dateType: goal.dateType,
    goalType: goal.goalType,
    paceValue: goal.paceValue,
    pacePeriod: goal.pacePeriod,
    paceGranularity: granularity,
    rawLearningUnit: granularity == null ? rawUnit : null,
    createdAt: goal.createdAt.toUtc(),
    updatedAt: goal.updatedAt.toUtc(),
  );
}

/// Implementation of [GoalRepository] using Drift database and sync engine.

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
/// [createGoal] still carries `profileId`/`trackId` `int` parameters (the
/// interface's shape, unchanged by owner decision 4) that are structurally
/// meaningless here: this instance's Firestore profile identity is already
/// fixed at construction (path-scoped, via the resolved
/// [FirestoreGoalRepository]), and there is no Drift `int` to bridge it
/// against; `trackId` is the Drift-era per-device value AD-25 retired. Both
/// are accepted (to satisfy the interface) and ignored — see [createGoal]'s
/// own doc comment.
///
/// ## Not-ready semantics
///
/// [getGoals]/[watchGoals] reuse the interface's own `[]` "nothing yet"
/// value. [createGoal]/[updateGoal]/[deleteGoal] have no such value and
/// throw [GoalRepositoryNotReadyException] instead.
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
  /// (null-first, ascending). `[]` when not ready.
  @override
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId) async {
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    return repo.getGoals(curriculumId);
  }

  /// Live updates for [curriculumId]'s goal list. See
  /// [FirestoreCurriculumTrackRepositoryAdapter]'s class doc comment
  /// ("Not-ready semantics") for the one-shot-resolve limitation shared by
  /// every `watch*` method built in this wave: this does not re-subscribe
  /// if the active account/profile changes after the stream opens while
  /// not-ready.
  Stream<List<GoalEntity>> watchGoals(CurriculumId curriculumId) async* {
    final repo = await _resolveOrNull();
    if (repo == null) {
      yield const [];
      return;
    }
    yield* repo.watchGoals(curriculumId);
  }

  /// Creates a new goal for [curriculumId]. Throws
  /// [GoalRepositoryNotReadyException] when not ready.
  ///
  /// [profileId] and [trackId] exist only to satisfy [GoalRepository]'s
  /// signature — see the class doc comment. This instance's Firestore
  /// profile identity is already fixed at construction, and there is no
  /// Drift `int` to bridge it against; `trackId` is the Drift-era
  /// per-device value AD-25 retired. Both are accepted and ignored, exactly
  /// like [FirestoreGoalRepository] itself already documents for its own
  /// (parameter-less) `createGoal`.
  ///
  /// [paceGranularity] is the interface's raw storage-key string (unlike
  /// [updateGoal]'s typed [PaceGranularity] param — an existing asymmetry in
  /// [GoalRepository] itself, not introduced here). Resolved to the typed
  /// enum when it matches a known value, else preserved verbatim via
  /// [FirestoreGoalRepository.createGoal]'s `rawLearningUnit` — the same
  /// fallback [GoalEntity.paceGranularityKey] documents.
  @override
  Future<GoalEntity> createGoal({
    required int profileId,
    required CurriculumId curriculumId,
    required int trackId,
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
