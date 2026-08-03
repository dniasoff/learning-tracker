import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/codec/goal_codec.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_goal_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/exceptions/goal_profile_mismatch_exception.dart';
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
class GoalRepositoryImpl implements GoalRepository {
  final UserDatabase _database;
  final SyncWriteFacade? _syncEngine;
  final int _profileId;

  GoalRepositoryImpl({
    required UserDatabase database,
    SyncWriteFacade? syncEngine,
    int profileId = 0,
  }) : _database = database,
       _syncEngine = syncEngine,
       _profileId = profileId;

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
    // AUD-scheduler-03: profileId is a redundant caller-supplied parameter —
    // the single source of truth for "which profile owns this repository
    // instance" is _profileId. Validate rather than silently trust it, so a
    // mismatched caller (bug or malicious input) cannot create a goal
    // attributed to a profile other than the one this repository instance
    // represents.
    if (profileId != _profileId) {
      throw GoalProfileMismatchException(
        'createGoal: profileId=$profileId does not match this repository '
        'instance\'s profile ($_profileId)',
      );
    }
    return await _database.transaction(() async {
      final now = DateTimeFactory.nowUtc();
      final (goalType, targetDate, paceValue, pacePeriod) =
          _decomposePaceTarget(paceTarget);

      final id = await _database.goalDao.insertGoal(
        GoalsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId.storageKey,
          trackId: trackId,
          targetPercent: drift.Value(targetPercent),
          targetDate: drift.Value(targetDate),
          description: drift.Value(description),
          dateType: drift.Value(dateType),
          goalType: drift.Value(goalType),
          paceValue: drift.Value(paceValue),
          pacePeriod: drift.Value(pacePeriod),
          paceGranularity: drift.Value(paceGranularity),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final goal = await _database.goalDao.getGoalById(id);
      if (goal == null) {
        throw StateError('Failed to retrieve created goal');
      }

      final entity = _toEntity(goal);

      // Push to Firestore
      await _syncGoal(entity);

      return entity;
    });
  }

  @override
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId) async {
    final goals = await _database.goalDao.getGoalsByCurriculumAndProfile(
      curriculumId.storageKey,
      _profileId,
    );
    return goals.map(_toEntity).toList();
  }

  @override
  Future<GoalEntity> updateGoal({
    required GoalEntity goal,
    double? targetPercent,
    PaceTarget? paceTarget,
    bool clearPaceTarget = false,
    String? description,
    PaceGranularity? paceGranularity,
    bool clearLearningUnit = false,
  }) async {
    // [goal] is passed by value (owner decision 4) but this Drift-backed
    // implementation still addresses the row by its autoincrement primary
    // key — [GoalEntity.id] already carries it (populated by [_toEntity]
    // below), so no new lookup mechanism is needed.
    final goalId = goal.id;
    if (goalId == null) {
      throw ArgumentError(
        'updateGoal: goal.id is null — this GoalEntity was never persisted '
        'by this (Drift-backed) repository, so there is no row to update.',
      );
    }
    return await _database.transaction(() async {
      final existing = await _database.goalDao.getGoalById(goalId);
      if (existing == null) {
        throw ArgumentError('Goal not found: $goalId');
      }
      // AUD-scheduler-03: the DAO layer does not scope getGoalById/updateGoal
      // by profile, so this repository-layer check is the last line of
      // defense against mutating another profile's goal.
      if (existing.profileId != _profileId) {
        throw GoalProfileMismatchException(
          'updateGoal: goal $goalId belongs to profile '
          '${existing.profileId}, not this repository instance\'s profile '
          '($_profileId)',
        );
      }

      final now = DateTimeFactory.nowUtc();

      // Resolve the learning unit string from typed enum or fallback to existing.
      final resolvedLearningUnit = clearLearningUnit
          ? null
          : (paceGranularity != null
                ? paceGranularity.storageKey
                : existing.paceGranularity);

      // Decompose paceTarget if explicitly set; keep existing values otherwise.
      final String resolvedGoalType;
      final DateTime? resolvedTargetDate;
      final int? resolvedPaceValue;
      final String? resolvedPacePeriod;
      if (clearPaceTarget) {
        resolvedGoalType = 'none';
        resolvedTargetDate = null;
        resolvedPaceValue = null;
        resolvedPacePeriod = null;
      } else if (paceTarget != null) {
        final decomposed = _decomposePaceTarget(paceTarget);
        resolvedGoalType = decomposed.$1;
        resolvedTargetDate = decomposed.$2;
        resolvedPaceValue = decomposed.$3;
        resolvedPacePeriod = decomposed.$4;
      } else {
        // No change to goal-mode fields.
        resolvedGoalType = existing.goalType;
        resolvedTargetDate = existing.targetDate;
        resolvedPaceValue = existing.paceValue;
        resolvedPacePeriod = existing.pacePeriod;
      }

      await _database.goalDao.updateGoal(
        GoalsCompanion(
          id: drift.Value(goalId),
          profileId: drift.Value(existing.profileId),
          curriculumId: drift.Value(existing.curriculumId),
          trackId: drift.Value(existing.trackId),
          targetPercent: drift.Value(targetPercent ?? existing.targetPercent),
          targetDate: drift.Value(resolvedTargetDate?.toUtc()),
          description: drift.Value(description ?? existing.description),
          goalType: drift.Value(resolvedGoalType),
          paceValue: drift.Value(resolvedPaceValue),
          pacePeriod: drift.Value(resolvedPacePeriod),
          paceGranularity: drift.Value(resolvedLearningUnit),
          createdAt: drift.Value(existing.createdAt),
          updatedAt: drift.Value(now),
        ),
      );

      final updated = await _database.goalDao.getGoalById(goalId);
      if (updated == null) {
        throw StateError('Failed to retrieve updated goal');
      }

      final entity = _toEntity(updated);
      await _syncGoal(entity);

      return entity;
    });
  }

  @override
  Future<void> deleteGoal(GoalEntity goal) async {
    // [goal] is passed by value (owner decision 4) — see [updateGoal]'s
    // comment on why this Drift-backed implementation still resolves the
    // row via [GoalEntity.id]. A `null` id means the entity was never
    // persisted here, which is indistinguishable from "already absent" —
    // deleting an already-absent goal is a no-op.
    final goalId = goal.id;
    if (goalId == null) return;
    // Retrieve the entity before deleting so we can sync the deletion
    final existing = await _database.goalDao.getGoalById(goalId);
    // Deleting an already-absent goal is a no-op (idempotent delete).
    if (existing == null) return;
    // AUD-scheduler-03: the DAO layer does not scope
    // getGoalById/deleteGoal by profile, so this repository-layer check is
    // the last line of defense against deleting another profile's goal.
    if (existing.profileId != _profileId) {
      throw GoalProfileMismatchException(
        'deleteGoal: goal $goalId belongs to profile ${existing.profileId}, '
        'not this repository instance\'s profile ($_profileId)',
      );
    }

    await _database.goalDao.deleteGoal(goalId);

    // Sync deletion to Firestore
    final entity = _toEntity(existing);
    await _syncDeleteGoal(entity);
  }

  /// Decomposes a [PaceTarget] into the four raw DB columns
  /// (goalType, targetDate, paceValue, pacePeriod).
  (String goalType, DateTime? targetDate, int? paceValue, String? pacePeriod)
  _decomposePaceTarget(PaceTarget? paceTarget) {
    switch (paceTarget) {
      case DeadlineTarget(:final dueDate):
        return ('deadline', dueDate.toUtc(), null, null);
      case PacePeriodTarget(:final rate, :final period):
        return ('pace', null, rate, period);
      case null:
        return ('none', null, null, null);
    }
  }

  GoalEntity _toEntity(Goal goal) => goalEntityFromRow(goal);

  Future<void> _syncGoal(GoalEntity entity) async {
    if (_syncEngine == null) return;

    // Route to the `goals` subcollection through the canonical write serializer
    // (GoalCodec.encode). This is the Phase B unification: a single serializer
    // drives both the live repo push and the local_data_upload bulk path so the
    // two write shapes can never drift from each other or from the merger's
    // read-keys.
    //
    // `id` is injected post-encode (it is in _serverInjectedKeys in the contract
    // test and is the doc-id used by FirestoreGateway.pushGoal to pick the
    // deterministic Firestore document path).
    const codec = GoalCodec();
    final data = codec.encode(
      GoalRow(
        firestoreId: entity.firestoreId,
        profileId: _profileId,
        curriculumId: entity.curriculumId.storageKey,
        trackId: entity.trackId,
        targetPercent: entity.targetPercent,
        description: entity.description,
        dateType: entity.dateType,
        goalType: entity.goalType,
        paceValue: entity.paceValue,
        pacePeriod: entity.pacePeriod,
        paceGranularity: entity.paceGranularityKey,
        targetDate: entity.targetDate,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      ),
    );
    data['id'] = entity.firestoreId;
    await _syncEngine.pushGoal(data);
  }

  Future<void> _syncDeleteGoal(GoalEntity entity) async {
    if (_syncEngine == null) return;

    // Hard delete in Firestore via the dedicated goal_delete queue type —
    // mirrors the existing profile_program_delete / learner_profile_delete
    // pattern so the cloud row goes away when the local row does.
    await _syncEngine.deleteGoal({
      'firestore_id': entity.firestoreId,
      'curriculum_id': entity.curriculumId.storageKey,
    });
  }
}

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
