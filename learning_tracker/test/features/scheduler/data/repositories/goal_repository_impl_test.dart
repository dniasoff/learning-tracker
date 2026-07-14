import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/goal_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';

import '../../../../helpers/test_database.dart';

/// Recording [SyncWriteFacade] that captures [pushGoal] payloads.
///
/// All other methods are no-ops — only the goal push path is under test.
class _RecordingGoalSyncFacade implements SyncWriteFacade {
  final List<Map<String, dynamic>> goalPayloads = [];

  @override
  Future<void> pushGoal(Map<String, dynamic> goal) async {
    goalPayloads.add(Map<String, dynamic>.from(goal));
  }

  @override
  Future<void> deleteGoal(Map<String, dynamic> payload) async {}
  @override
  Future<void> pushGamificationSettingsSnapshot() async {}
  @override
  Future<void> pushUiPreferencesSnapshot() async {}
  @override
  Future<void> pushBookmark(Map<String, dynamic> bookmark) async {}
  @override
  Future<void> pushSettings(Map<String, dynamic> settings) async {}
  @override
  Future<void> pushCurriculumTrack(Map<String, dynamic> trackData) async {}
  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String curriculumId,
    required List<Map<String, dynamic>> items,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> pushLearnerProfile(Map<String, dynamic> profile) async {}
  @override
  Future<void> deleteLearnerProfile(int profileId) async {}
  @override
  Future<void> pushStageDefinitions({
    required int trackId,
    required String curriculumId,
    required List<Map<String, dynamic>> stages,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> deleteCompletion(String completionId) async {}
  @override
  Future<void> pushProfileProgram(Map<String, dynamic> payload) async {}
  @override
  Future<void> pushStudyDayConfig(Map<String, dynamic> payload) async {}
}

void main() {
  late UserDatabase db;
  late GoalRepositoryImpl repo;
  late int trackId;
  late int bavliTrackId;
  final now = DateTime.utc(2026, 1, 1);

  setUp(() async {
    db = createTestDatabase();
    await seedProfile(db);
    await seedProfileZero(db);
    repo = GoalRepositoryImpl(database: db);

    final trackRow = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            stateChangedAt: now,
            activatedAt: now,
          ),
        );
    trackId = trackRow.id;

    final bavliTrackRow = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: 'bavli',
            stateChangedAt: now,
            activatedAt: now,
          ),
        );
    bavliTrackId = bavliTrackRow.id;
  });

  tearDown(() async {
    await db.close();
  });

  group('GoalRepositoryImpl', () {
    test('createGoal creates and returns a goal entity', () async {
      final targetDate = DateTime(2026, 12, 31);
      final goal = await repo.createGoal(
        profileId: 0,
        curriculumId: CurriculumId.mishnayos,
        trackId: trackId,
        targetPercent: 100.0,
        paceTarget: DeadlineTarget(targetDate),
        description: 'Finish mishnayos',
        dateType: 'gregorian',
      );

      expect(goal.id, isPositive);
      expect(goal.curriculumId, CurriculumId.mishnayos);
      expect(goal.targetPercent, 100.0);
      expect(goal.description, 'Finish mishnayos');
      expect(goal.goalType, 'deadline');
      expect(goal.targetDate, isNotNull);
    });

    test('getGoals returns goals for specific curriculum', () async {
      await repo.createGoal(
        profileId: 0,
        curriculumId: CurriculumId.mishnayos,
        trackId: trackId,
        targetPercent: 50.0,
      );
      await repo.createGoal(
        profileId: 0,
        curriculumId: CurriculumId.bavli,
        trackId: bavliTrackId,
        targetPercent: 25.0,
      );

      final mishnayosGoals = await repo.getGoals(CurriculumId.mishnayos);
      expect(mishnayosGoals, hasLength(1));
      expect(mishnayosGoals.first.targetPercent, 50.0);

      final bavliGoals = await repo.getGoals(CurriculumId.bavli);
      expect(bavliGoals, hasLength(1));
    });

    test('updateGoal modifies existing goal', () async {
      final goal = await repo.createGoal(
        profileId: 0,
        curriculumId: CurriculumId.mishnayos,
        trackId: trackId,
        targetPercent: 50.0,
      );

      final updated = await repo.updateGoal(
        goalId: goal.id!,
        targetPercent: 75.0,
        description: 'Updated goal',
      );

      expect(updated.targetPercent, 75.0);
      expect(updated.description, 'Updated goal');
    });

    test('deleteGoal removes the goal', () async {
      final goal = await repo.createGoal(
        profileId: 0,
        curriculumId: CurriculumId.mishnayos,
        trackId: trackId,
        targetPercent: 100.0,
      );

      await repo.deleteGoal(goal.id!);

      final goals = await repo.getGoals(CurriculumId.mishnayos);
      expect(goals, isEmpty);
    });

    test('getGoals returns empty list when no goals', () async {
      final goals = await repo.getGoals(CurriculumId.mishnayos);
      expect(goals, isEmpty);
    });

    group('pace goal fields — W3.44 PaceTarget sealed VO', () {
      test('createGoal with PacePeriodTarget persists correctly', () async {
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
          paceTarget: const PacePeriodTarget(rate: 1, period: 'per_day'),
        );

        expect(goal.goalType, 'pace');
        expect(goal.paceValue, 1);
        expect(goal.pacePeriod, 'per_day');
        expect(goal.targetDate, isNull);
        // paceTarget getter reflects sealed VO
        expect(goal.paceTarget, isA<PacePeriodTarget>());
        expect((goal.paceTarget as PacePeriodTarget).rate, 1);
        expect((goal.paceTarget as PacePeriodTarget).period, 'per_day');
      });

      test('createGoal with DeadlineTarget persists correctly', () async {
        final due = DateTime(2026, 12, 31).toUtc();
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
          paceTarget: DeadlineTarget(due),
        );

        expect(goal.goalType, 'deadline');
        expect(goal.targetDate, isNotNull);
        expect(goal.paceValue, isNull);
        expect(goal.pacePeriod, isNull);
        expect(goal.paceTarget, isA<DeadlineTarget>());
      });

      test(
        'createGoal with null paceTarget defaults to goalType=none',
        () async {
          final goal = await repo.createGoal(
            profileId: 0,
            curriculumId: CurriculumId.bavli,
            trackId: bavliTrackId,
            targetPercent: 100.0,
          );

          expect(goal.goalType, 'none');
          expect(goal.paceValue, isNull);
          expect(goal.pacePeriod, isNull);
          expect(goal.paceTarget, isNull);
        },
      );

      test('updateGoal with PacePeriodTarget changes pace fields', () async {
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
          paceTarget: const PacePeriodTarget(rate: 1, period: 'per_day'),
        );

        final updated = await repo.updateGoal(
          goalId: goal.id!,
          paceTarget: const PacePeriodTarget(rate: 5, period: 'per_week'),
        );

        expect(updated.paceValue, 5);
        expect(updated.pacePeriod, 'per_week');
        expect(updated.paceTarget, isA<PacePeriodTarget>());
      });

      test('updateGoal with clearPaceTarget nulls out goal mode', () async {
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
          paceTarget: const PacePeriodTarget(rate: 1, period: 'per_day'),
        );

        final updated = await repo.updateGoal(
          goalId: goal.id!,
          clearPaceTarget: true,
        );

        expect(updated.goalType, 'none');
        expect(updated.paceValue, isNull);
        expect(updated.pacePeriod, isNull);
        expect(updated.paceTarget, isNull);
      });

      test(
        'updateGoal preserves pace fields when paceTarget not provided',
        () async {
          final goal = await repo.createGoal(
            profileId: 0,
            curriculumId: CurriculumId.bavli,
            trackId: bavliTrackId,
            targetPercent: 100.0,
            paceTarget: const PacePeriodTarget(rate: 3, period: 'per_week'),
          );

          final updated = await repo.updateGoal(
            goalId: goal.id!,
            description: 'Updated description',
          );

          expect(updated.goalType, 'pace');
          expect(updated.paceValue, 3);
          expect(updated.pacePeriod, 'per_week');
          expect(updated.description, 'Updated description');
        },
      );

      test('paceTarget getter returns null for goalType=none', () async {
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
        );
        // goalType=none → paceTarget getter returns null
        expect(goal.paceTarget, isNull);
      });
    });

    // R4-6 regression — goal push payload must include profile_id and id.
    //
    // Pull-side scoping is purely path-based (GoalMerger.merge receives
    // profileId from PullPipeline and never reads this field), so the field is
    // defensive rather than load-bearing. Its absence was still a detectable
    // inconsistency with sibling per-profile entities (tracks, bookmarks, etc.)
    // and could trip future Firestore security-rule audits.
    group('sync payload completeness (R4-6)', () {
      late _RecordingGoalSyncFacade syncFacade;
      late GoalRepositoryImpl repoWithSync;

      setUp(() {
        syncFacade = _RecordingGoalSyncFacade();
        // profileId=1 matches the profile seeded by seedProfile() in the outer
        // setUp.
        repoWithSync = GoalRepositoryImpl(
          database: db,
          syncEngine: syncFacade,
          profileId: 1,
        );
      });

      test('createGoal pushes profile_id in the outbox payload', () async {
        await repoWithSync.createGoal(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos,
          trackId: trackId,
          targetPercent: 100.0,
          description: 'test payload completeness',
        );

        expect(syncFacade.goalPayloads, hasLength(1));
        final payload = syncFacade.goalPayloads.first;
        expect(
          payload['profile_id'],
          equals(1),
          reason: 'profile_id must be denormalised into the Firestore payload',
        );
        expect(
          payload['id'],
          isNotNull,
          reason:
              'id (firestoreId) must be present so gateway uses a '
              'deterministic doc-id rather than auto-generating one',
        );
        // Sanity-check that the core goal fields are also present.
        expect(payload['curriculum_id'], equals('mishnayos'));
        expect(payload['target_percent'], equals(100.0));
      });

      test('updateGoal pushes profile_id in the outbox payload', () async {
        final goal = await repoWithSync.createGoal(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos,
          trackId: trackId,
          targetPercent: 50.0,
        );
        syncFacade.goalPayloads.clear();

        await repoWithSync.updateGoal(goalId: goal.id!, targetPercent: 75.0);

        expect(syncFacade.goalPayloads, hasLength(1));
        final payload = syncFacade.goalPayloads.first;
        expect(
          payload['profile_id'],
          equals(1),
          reason: 'profile_id must be present on update pushes too',
        );
        expect(payload['id'], isNotNull);
      });
    });
  });
}
