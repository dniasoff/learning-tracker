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
    required int goalId,
    double? targetPercent,
    PaceTarget? paceTarget,
    bool clearPaceTarget = false,
    String? description,
    PaceGranularity? paceGranularity,
    bool clearLearningUnit = false,
  }) async {
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
  Future<void> deleteGoal(int goalId) async {
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

  GoalEntity _toEntity(Goal goal) {
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
/// ## Deliberately does NOT `implements` [GoalRepository] — an unbridgeable
/// id mismatch, not an oversight
///
/// [GoalRepository.updateGoal] takes `required int goalId` and
/// [GoalRepository.deleteGoal] takes `int goalId` — both address a goal by
/// [GoalDao]'s Drift-local autoincrement primary key. [FirestoreGoalRepository]
/// has no such key at all: per its own class doc comment ("Doc-id"), a
/// Firestore goal is identified by [GoalEntity.firestoreId]
/// (`curriculumId` + `createdAt`), and [FirestoreGoalRepository.updateGoal]/
/// `.deleteGoal` both take the current [GoalEntity] itself, not an int.
/// There is no honest way to synthesize an `int` for a document that was
/// never assigned one — inventing one (a hash, a counter) would silently
/// diverge from what [GoalRepositoryImpl] actually stores and break the very
/// callers this adapter would be adapting for.
///
/// This is the same CLASS of problem
/// `FirestoreProfileRepositoryAdapter`(`lib/features/profiles/data/
/// repositories/profile_repository_impl.dart`) solved for
/// `ProfileRepository`'s `int`-keyed interface — but that fix was a
/// dual-write hybrid (every write still goes through the Drift repository
/// first, Firestore identity is bridged via a `ulid` column added to the
/// Drift row) built specifically because `ProfileModel.id` is threaded
/// through a great many profile-scoped screens/providers/queries. Goals'
/// `int goalId` has a much narrower blast radius — exactly two callers,
/// both outside this task's scope to touch:
/// `TrackEditService.editTrack` (`lib/features/tracks/setup/domain/
/// services/track_edit_service.dart`, calls `updateGoal(goalId: goalId,
/// ...)`) and `TrackCreationService._deleteExistingGoals`/`._recreateGoal`
/// (`lib/features/tracks/setup/domain/services/track_creation_service.dart`,
/// calls `deleteGoal(g.id)` / `createGoal(...)`). Building the equivalent
/// dual-write bridge for goals (a Drift-row `firestoreId` column, or
/// widening [GoalRepository] itself to accept an entity instead of an int)
/// would mean editing those two `domain/services/` files — outside this
/// adapter's `data/repositories/` scope. So this class instead exposes
/// [FirestoreGoalRepository]'s own entity-keyed method shapes directly,
/// standalone (not `implements` anything) — the same "no interface, nothing
/// to be substitutable with yet" status
/// [FirestoreStudyDayConfigRepositoryAdapter] documents for study-day
/// configs — ready for a future task that either widens [GoalRepository]'s
/// contract or builds the same kind of identity bridge Profiles used.
///
/// ## Not-ready semantics
///
/// [getGoals]/[watchGoals] reuse the interface's own `[]` "nothing yet"
/// value. [createGoal]/[updateGoal]/[deleteGoal] have no such value and
/// throw [GoalRepositoryNotReadyException] instead.
class FirestoreGoalRepositoryAdapter {
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
  Future<GoalEntity> createGoal({
    required CurriculumId curriculumId,
    required double targetPercent,
    PaceTarget? paceTarget,
    String description = '',
    String dateType = 'gregorian',
    PaceGranularity? paceGranularity,
    String? rawLearningUnit,
  }) async {
    final repo = await _resolve();
    return repo.createGoal(
      curriculumId: curriculumId,
      targetPercent: targetPercent,
      paceTarget: paceTarget,
      description: description,
      dateType: dateType,
      paceGranularity: paceGranularity,
      rawLearningUnit: rawLearningUnit,
    );
  }

  /// Updates [goal] and writes the result back to the same Firestore
  /// document (see [FirestoreGoalRepository.updateGoal]'s doc comment).
  /// Throws [GoalRepositoryNotReadyException] when not ready.
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
  Future<void> deleteGoal(GoalEntity goal) async {
    final repo = await _resolve();
    await repo.deleteGoal(goal);
  }
}
