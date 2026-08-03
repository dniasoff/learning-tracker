import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/scheduler/data/repositories/goal_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/exceptions/goal_profile_mismatch_exception.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';
import 'not_ready_expectations.dart';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

/// Recording [SyncWriteFacade] that captures [pushGoal] payloads.
///
/// All other methods are no-ops — only the goal push path is under test.
class _RecordingGoalSyncFacade implements SyncWriteFacade {
  final List<Map<String, dynamic>> goalPayloads = [];
  final List<Map<String, dynamic>> deletePayloads = [];

  @override
  Future<void> pushGoal(Map<String, dynamic> goal) async {
    goalPayloads.add(Map<String, dynamic>.from(goal));
  }

  @override
  Future<void> deleteGoal(Map<String, dynamic> payload) async {
    deletePayloads.add(Map<String, dynamic>.from(payload));
  }

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
        goal: goal,
        targetPercent: 75.0,
        description: 'Updated goal',
      );

      expect(updated.targetPercent, 75.0);
      expect(updated.description, 'Updated goal');
    });

    // AUD-scheduler-04 — updateGoal must throw a typed ArgumentError (not
    // silently no-op, and not a raw DB/null-check crash) when the goal's id
    // doesn't exist — e.g. the goal was already deleted by a sync merge
    // from another device before this device's in-flight edit lands.
    test('updateGoal throws ArgumentError for a nonexistent goal id', () async {
      const missingGoalId = 999999;
      final missingGoal = GoalEntity(
        id: missingGoalId,
        curriculumId: CurriculumId.mishnayos,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => repo.updateGoal(goal: missingGoal, targetPercent: 50.0),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Goal not found: $missingGoalId'),
          ),
        ),
      );
    });

    test('deleteGoal removes the goal', () async {
      final goal = await repo.createGoal(
        profileId: 0,
        curriculumId: CurriculumId.mishnayos,
        trackId: trackId,
        targetPercent: 100.0,
      );

      await repo.deleteGoal(goal);

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
          goal: goal,
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
          goal: goal,
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
            goal: goal,
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

        await repoWithSync.updateGoal(goal: goal, targetPercent: 75.0);

        expect(syncFacade.goalPayloads, hasLength(1));
        final payload = syncFacade.goalPayloads.first;
        expect(
          payload['profile_id'],
          equals(1),
          reason: 'profile_id must be present on update pushes too',
        );
        expect(payload['id'], isNotNull);
      });

      // AUD-scheduler-04 — mirrors the create/update payload-completeness
      // tests above but for _syncDeleteGoal, which had zero coverage: a key
      // rename or dropped field in its {firestore_id, curriculum_id} payload
      // would previously have shipped silently.
      test('deleteGoal pushes firestore_id and curriculum_id in the outbox '
          'payload', () async {
        final goal = await repoWithSync.createGoal(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos,
          trackId: trackId,
          targetPercent: 100.0,
        );
        syncFacade.goalPayloads.clear();

        await repoWithSync.deleteGoal(goal);

        expect(syncFacade.deletePayloads, hasLength(1));
        final payload = syncFacade.deletePayloads.first;
        expect(
          payload['firestore_id'],
          equals(goal.firestoreId),
          reason: 'firestore_id must identify the deterministic doc to delete',
        );
        expect(
          payload['curriculum_id'],
          equals('mishnayos'),
          reason:
              'curriculum_id must be present for the delete queue '
              'entry',
        );
        expect(payload.keys, containsAll(['firestore_id', 'curriculum_id']));
      });

      // AUD-scheduler-16: firestoreId must not key off targetPercent (a
      // field updateGoal can change) — otherwise a routine "adjust my goal
      // target %" edit computes a different id, and _syncGoal pushes a
      // brand-new Firestore document instead of updating the original,
      // permanently orphaning the old one (deleteGoal only ever removes the
      // CURRENT firestoreId's doc).
      test('updateGoal changing only targetPercent pushes the SAME '
          'firestoreId as the create call (AUD-scheduler-16)', () async {
        final created = await repoWithSync.createGoal(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos,
          trackId: trackId,
          targetPercent: 50.0,
        );
        expect(syncFacade.goalPayloads, hasLength(1));
        final createdId = syncFacade.goalPayloads.first['id'];
        syncFacade.goalPayloads.clear();

        await repoWithSync.updateGoal(goal: created, targetPercent: 75.0);

        expect(syncFacade.goalPayloads, hasLength(1));
        final updatedId = syncFacade.goalPayloads.first['id'];
        expect(
          updatedId,
          equals(createdId),
          reason:
              'updateGoal must resolve to the SAME Firestore document as '
              'the original create — changing targetPercent must not '
              'orphan the create-time document.',
        );
      });
    });

    // AUD-scheduler-03 — repository-layer profile ownership backstop.
    //
    // GoalRepositoryImpl is constructed per-profile (see
    // `goalRepositoryProvider`), but prior to this fix updateGoal/deleteGoal
    // loaded the row by bare goalId with no check that it belongs to the
    // repository instance's own `_profileId`, and createGoal's explicit
    // `profileId` argument was never cross-checked against `_profileId`
    // either. These tests construct two repository instances — one per
    // profile — sharing a single DB and assert profile B's repository can
    // neither update nor delete a goal owned by profile A, and that
    // createGoal rejects a profileId argument that disagrees with the
    // repository's own profile.
    group('cross-profile ownership (AUD-scheduler-03)', () {
      test('updateGoal throws GoalProfileMismatchException for a goal owned '
          'by another profile, and leaves it unmodified', () async {
        final repoProfile1 = GoalRepositoryImpl(database: db, profileId: 1);
        final repoProfile0 = GoalRepositoryImpl(database: db, profileId: 0);

        final goal = await repoProfile1.createGoal(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos,
          trackId: trackId,
          targetPercent: 50.0,
        );

        expect(
          () => repoProfile0.updateGoal(goal: goal, targetPercent: 90.0),
          throwsA(isA<GoalProfileMismatchException>()),
        );

        final untouched = await repoProfile1.getGoals(CurriculumId.mishnayos);
        expect(untouched, hasLength(1));
        expect(untouched.single.targetPercent, 50.0);
      });

      test('deleteGoal throws GoalProfileMismatchException for a goal owned '
          'by another profile, and leaves it in place', () async {
        final repoProfile1 = GoalRepositoryImpl(database: db, profileId: 1);
        final repoProfile0 = GoalRepositoryImpl(database: db, profileId: 0);

        final goal = await repoProfile1.createGoal(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos,
          trackId: trackId,
          targetPercent: 50.0,
        );

        expect(
          () => repoProfile0.deleteGoal(goal),
          throwsA(isA<GoalProfileMismatchException>()),
        );

        final stillThere = await repoProfile1.getGoals(CurriculumId.mishnayos);
        expect(stillThere, hasLength(1));
      });

      test('createGoal throws GoalProfileMismatchException when the profileId '
          'argument disagrees with the repository profile', () async {
        final repoProfile1 = GoalRepositoryImpl(database: db, profileId: 1);

        expect(
          () => repoProfile1.createGoal(
            profileId: 0,
            curriculumId: CurriculumId.mishnayos,
            trackId: trackId,
            targetPercent: 50.0,
          ),
          throwsA(isA<GoalProfileMismatchException>()),
        );
      });
    });
  });

  group('FirestoreGoalRepositoryAdapter', () {
    const uid = 'uid-1';
    const profileDocId = 'profile-ulid-1';

    AccountFirebaseHandles handles(FakeFirebaseFirestore firestore) {
      return AccountFirebaseHandles(
        app: MockFirebaseApp(),
        firestore: firestore,
        auth: MockFirebaseAuthHandle(),
        uid: uid,
      );
    }

    // Constructing FirestoreGoalRepositoryAdapter requires a Ref
    // (Riverpod's Ref is sealed — it can only come from inside a provider
    // callback), so tests obtain one the same way production does: read a
    // throwaway Provider that builds the adapter from the container's ref.
    // Mirrors FirestoreBookmarkRepositoryAdapter's test helper
    // (bookmark_repository_impl_test.dart).
    FirestoreGoalRepositoryAdapter buildAdapter(ProviderContainer container) {
      final adapterProvider = Provider<FirestoreGoalRepositoryAdapter>(
        (ref) => FirestoreGoalRepositoryAdapter(ref: ref),
      );
      return container.read(adapterProvider);
    }

    group('not ready (no active account/profile)', () {
      // Hoisted: every test in this group needs the same bare container (no
      // account/profile overrides — that IS the not-ready condition), so
      // repeating it per test was pure setup noise.
      late FirestoreGoalRepositoryAdapter notReadyAdapter;

      setUp(() {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        notReadyAdapter = buildAdapter(container);
      });

      test('getGoals returns an empty list instead of throwing', () async {
        await expectEmptyListWhenNotReady(
          () => notReadyAdapter.getGoals(CurriculumId.mishnayos),
          describe: 'GoalRepository.getGoals',
        );
      });

      test('createGoal throws GoalRepositoryNotReadyException', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        expect(
          () => adapter.createGoal(
            // AUD-scheduler-16 follow-up: profileId/trackId are ignored by
            // this adapter (see its class doc comment) — arbitrary
            // sentinels, present only to satisfy GoalRepository's signature.
            profileId: 0,
            curriculumId: CurriculumId.mishnayos,
            trackId: 0,
            targetPercent: 100.0,
          ),
          throwsA(isA<GoalRepositoryNotReadyException>()),
        );
      });

      test('updateGoal throws GoalRepositoryNotReadyException', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);
        final goal = GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          createdAt: now,
          updatedAt: now,
        );

        expect(
          () => adapter.updateGoal(goal: goal, targetPercent: 50.0),
          throwsA(isA<GoalRepositoryNotReadyException>()),
        );
      });

      test('deleteGoal throws GoalRepositoryNotReadyException', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);
        final goal = GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          createdAt: now,
          updatedAt: now,
        );

        expect(
          () => adapter.deleteGoal(goal),
          throwsA(isA<GoalRepositoryNotReadyException>()),
        );
      });
    });

    group('ready (active account + profile)', () {
      late FakeFirebaseFirestore firestore;
      late ProviderContainer container;
      late FirestoreGoalRepositoryAdapter adapter;

      setUp(() {
        firestore = FakeFirebaseFirestore();
        container = ProviderContainer(
          overrides: [
            activeAccountFirebaseProvider.overrideWith(
              (ref) async => handles(firestore),
            ),
          ],
        );
        container.read(activeProfileDocIdProvider.notifier).set(profileDocId);
        adapter = buildAdapter(container);
      });

      tearDown(() => container.dispose());

      test('createGoal delegates to FirestoreGoalRepository and writes a doc '
          'reachable at the expected Firestore path', () async {
        final goal = await adapter.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.mishnayos,
          trackId: 0,
          targetPercent: 80.0,
          description: 'Finish Mishnayos',
        );

        expect(goal.targetPercent, 80.0);

        final doc = await firestore
            .collection('users')
            .doc(uid)
            .collection('learner_profiles')
            .doc(profileDocId)
            .collection('goals')
            .doc(goal.firestoreId)
            .get();
        expect(doc.exists, isTrue);
      });

      test('createGoal then getGoals round-trips through Firestore', () async {
        await adapter.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.mishnayos,
          trackId: 0,
          targetPercent: 60.0,
        );

        final goals = await adapter.getGoals(CurriculumId.mishnayos);

        expect(goals, hasLength(1));
        expect(goals.single.targetPercent, 60.0);
      });

      test('updateGoal writes the change back to the same document', () async {
        final created = await adapter.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.mishnayos,
          trackId: 0,
          targetPercent: 60.0,
        );

        final updated = await adapter.updateGoal(
          goal: created,
          targetPercent: 90.0,
        );

        expect(updated.targetPercent, 90.0);
        expect(updated.firestoreId, created.firestoreId);
        final goals = await adapter.getGoals(CurriculumId.mishnayos);
        expect(goals.single.targetPercent, 90.0);
      });

      test('deleteGoal removes the document', () async {
        final created = await adapter.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.mishnayos,
          trackId: 0,
          targetPercent: 60.0,
        );

        await adapter.deleteGoal(created);

        final goals = await adapter.getGoals(CurriculumId.mishnayos);
        expect(goals, isEmpty);
      });
    });
  });
}
