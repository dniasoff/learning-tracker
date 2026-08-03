/// Tests for [DriftCompletionPointsAwarder] — the Drift-backed
/// [CompletionPointsPort] implementation.
///
/// Relocated from `CompletionRepositoryImpl.markComplete`'s inline points
/// calculation as part of the completion-orchestrator lift
/// (`docs/firestore-rewrite-map.md`, owner decision 1): child-profile
/// gating, track reward-eligibility, and the `point_configs`
/// lookup-with-fallback-ladder all lived there before; they live only here
/// now — see [CompletionPointsPort]'s doc comment for why the repository no
/// longer knows about points at all.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/learning/data/completion_points_awarder.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/drift_memory.dart';

class _MockSyncEngine extends Mock implements SyncWriteFacade {}

void main() {
  late UserDatabase db;
  late DriftCompletionPointsAwarder awarder;
  late _MockSyncEngine syncEngine;

  RewardMilestoneService rewardServiceFor(int profileId) =>
      RewardMilestoneService(db, profileId: profileId);

  setUp(() async {
    db = inMemoryDb();
    addTearDown(db.close);
    syncEngine = _MockSyncEngine();
    when(
      () => syncEngine.pushGamificationSettingsSnapshot(),
    ).thenAnswer((_) async {});
    awarder = DriftCompletionPointsAwarder(
      database: db,
      rewardMilestoneServiceFactory: rewardServiceFor,
      syncEngine: syncEngine,
    );
  });

  /// Seeds an account + a profile (child or adult) + a reward-eligible
  /// curriculum track (a Goal row makes `trackCountsTowardRewardPoints`
  /// return true). Returns the profile id.
  Future<int> seedEligibleProfile({required String mode}) async {
    final now = DateTime.utc(2026, 6, 1);
    final accountId = await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            email: 'test@example.com',
            tier: 'localBorn',
            displayName: 'Test',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final profile = await db
        .into(db.learnerProfiles)
        .insertReturning(
          LearnerProfilesCompanion.insert(
            accountId: accountId,
            displayName: 'Test',
            mode: mode,
            createdAt: now,
            updatedAt: now,
          ),
        );
    final track = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: profile.id,
            curriculumId: 'mishnayos',
            stateChangedAt: now,
            activatedAt: now,
          ),
        );
    await db
        .into(db.goals)
        .insert(
          GoalsCompanion.insert(
            profileId: profile.id,
            curriculumId: 'mishnayos',
            trackId: track.id,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return profile.id;
  }

  group('calculatePoints', () {
    test('returns 0 for an adult profile — points are child-only', () async {
      final profileId = await seedEligibleProfile(mode: 'adult');

      final points = await awarder.calculatePoints(
        curriculumId: 'mishnayos',
        stageOrder: 1,
        profileId: profileId,
      );

      expect(points, 0);
    });

    test('returns 0 for a child profile on a non-reward-eligible track '
        '(no program, no goal)', () async {
      final now = DateTime.utc(2026, 6, 1);
      final accountId = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'test@example.com',
              tier: 'localBorn',
              displayName: 'Test',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final profile = await db
          .into(db.learnerProfiles)
          .insertReturning(
            LearnerProfilesCompanion.insert(
              accountId: accountId,
              displayName: 'Test',
              mode: 'child',
              createdAt: now,
              updatedAt: now,
            ),
          );
      // Track exists but has no Goal / ProfileProgram row — a
      // momentum-only/browse track.
      await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: profile.id,
              curriculumId: 'mishnayos',
              stateChangedAt: now,
              activatedAt: now,
            ),
          );

      final points = await awarder.calculatePoints(
        curriculumId: 'mishnayos',
        stageOrder: 1,
        profileId: profile.id,
      );

      expect(points, 0);
    });

    test('returns 0 (not a thrown StateError) when the curriculum track does '
        'not exist at all', () async {
      final now = DateTime.utc(2026, 6, 1);
      final accountId = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'test@example.com',
              tier: 'localBorn',
              displayName: 'Test',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final profile = await db
          .into(db.learnerProfiles)
          .insertReturning(
            LearnerProfilesCompanion.insert(
              accountId: accountId,
              displayName: 'Test',
              mode: 'child',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final points = await awarder.calculatePoints(
        curriculumId: 'mishnayos',
        stageOrder: 1,
        profileId: profile.id,
      );

      expect(
        points,
        0,
        reason:
            'a missing track is "not eligible," not an error — the '
            'write path (CompletionRepositoryImpl._resolveTrackId) is '
            'still the one that throws StateError for a genuinely '
            'missing track',
      );
    });

    test('returns the default fallback ladder (10/5/3/1) for an eligible '
        'child when no point_configs row exists', () async {
      final profileId = await seedEligibleProfile(mode: 'child');

      final stage1 = await awarder.calculatePoints(
        curriculumId: 'mishnayos',
        stageOrder: 1,
        profileId: profileId,
      );
      final stage2 = await awarder.calculatePoints(
        curriculumId: 'mishnayos',
        stageOrder: 2,
        profileId: profileId,
      );
      final stage3 = await awarder.calculatePoints(
        curriculumId: 'mishnayos',
        stageOrder: 3,
        profileId: profileId,
      );
      final stage4 = await awarder.calculatePoints(
        curriculumId: 'mishnayos',
        stageOrder: 4,
        profileId: profileId,
      );

      expect(stage1, 10, reason: 'Learn');
      expect(stage2, 5, reason: 'Chazara 1');
      expect(stage3, 3, reason: 'Chazara 2');
      expect(stage4, 1, reason: 'any additional stage');
    });

    test('returns the configured point_configs value, overriding the default '
        'ladder', () async {
      final profileId = await seedEligibleProfile(mode: 'child');
      final track = await (db.select(
        db.curriculumTracks,
      )..where((t) => t.profileId.equals(profileId))).getSingle();

      await db.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          profileId: profileId,
          curriculumId: 'mishnayos',
          trackId: track.id,
          stageOrder: 1,
          points: 99,
        ),
      );

      final points = await awarder.calculatePoints(
        curriculumId: 'mishnayos',
        stageOrder: 1,
        profileId: profileId,
      );

      expect(points, 99);
    });

    test('honors an injected rewardMilestoneServiceFactory over the real '
        'Drift-backed service (AUD-learning-10)', () async {
      final profileId = await seedEligibleProfile(mode: 'child');
      final fakeReward = _FakeIneligibleRewardService();
      final awarderWithFake = DriftCompletionPointsAwarder(
        database: db,
        rewardMilestoneServiceFactory: (profileId) => fakeReward,
        syncEngine: syncEngine,
      );

      final points = await awarderWithFake.calculatePoints(
        curriculumId: 'mishnayos',
        stageOrder: 1,
        profileId: profileId,
      );

      expect(
        points,
        0,
        reason:
            'the injected factory reports ineligible; the real Drift '
            'service (which would see the seeded Goal and report '
            'eligible=true) must not be consulted instead',
      );
    });
  });

  group('creditCompletion', () {
    test(
      'credits the points balance and pushes the gamification snapshot',
      () async {
        final profileId = await seedEligibleProfile(mode: 'child');

        await awarder.creditCompletion(
          profileId: profileId,
          points: 10,
          note: 'test-note',
        );

        final balance = await db.pointsBalanceDao.getBalance(profileId);
        expect(balance, 10);
        // pushGamificationSettingsSnapshot is fire-and-forget
        // (unawaited) inside creditCompletion — give the event loop a
        // turn before verifying.
        await Future<void>.delayed(Duration.zero);
        verify(() => syncEngine.pushGamificationSettingsSnapshot()).called(1);
      },
    );

    test('credits the balance even with no syncEngine wired (local-born '
        'account) — no crash', () async {
      final profileId = await seedEligibleProfile(mode: 'child');
      final localAwarder = DriftCompletionPointsAwarder(
        database: db,
        rewardMilestoneServiceFactory: rewardServiceFor,
      );

      await localAwarder.creditCompletion(
        profileId: profileId,
        points: 5,
        note: 'test-note',
      );

      final balance = await db.pointsBalanceDao.getBalance(profileId);
      expect(balance, 5);
    });
  });
}

class _FakeIneligibleRewardService implements RewardMilestoneService {
  @override
  Future<bool> trackCountsTowardRewardPoints(int trackId) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '_FakeIneligibleRewardService only implements trackCountsTowardRewardPoints',
  );
}
