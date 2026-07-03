import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/bookmark_repository_impl.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';

class MockSyncEngine extends Mock implements SyncWriteFacade {}

class MockContentRepository extends Mock implements ContentRepository {}

class MockRewardMilestoneService extends Mock
    implements RewardMilestoneService {}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });
  late UserDatabase database;
  late MockSyncEngine mockSyncEngine;
  late MockContentRepository mockContentRepository;
  late CompletionRepositoryImpl repository;
  late int trackId;
  late int learnerId;

  setUp(() async {
    database = createTestDatabase();
    mockSyncEngine = MockSyncEngine();
    mockContentRepository = MockContentRepository();

    final now = DateTime.now();
    // Seed account row first — learner_profiles.account_id is a FK.
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            email: 'test@example.com',
            tier: 'localBorn',
            displayName: 'Test Account',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final profileRow = await database
        .into(database.learnerProfiles)
        .insertReturning(
          ProfilesCompanion.insert(
            accountId: 1,
            displayName: 'Tester',
            mode: 'child',
            createdAt: now,
            updatedAt: now,
          ),
        );
    learnerId = profileRow.id;

    final trackRow = await database
        .into(database.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: learnerId,
            curriculumId: 'mishnayos',
            stateChangedAt: now,
            activatedAt: now,
          ),
        );
    trackId = trackRow.id;

    await database
        .into(database.goals)
        .insert(
          GoalsCompanion.insert(
            profileId: learnerId,
            curriculumId: 'mishnayos',
            trackId: trackId,
            createdAt: now,
            updatedAt: now,
          ),
        );

    repository = CompletionRepositoryImpl(
      database: database,
      syncEngine: mockSyncEngine,
      contentRepository: mockContentRepository,
      activeProfileId: learnerId,
    );

    // Default: no content items (bookmark advance is a no-op)
    when(
      () => mockContentRepository.getContentForCurriculum(any()),
    ).thenAnswer((_) async => []);

    // Sync engine stubs
    when(
      () => mockSyncEngine.pushBookmark(any()),
    ).thenAnswer((_) async => Future.value());
    when(
      () => mockSyncEngine.pushGamificationSettingsSnapshot(),
    ).thenAnswer((_) async => Future.value());
  });

  tearDown(() async {
    await database.close();
  });

  group('markComplete', () {
    test('creates completion record with correct data', () async {
      const curriculumId = 'mishnayos';
      const sefariaRef = 'Mishnah Berachot 1:1';
      const stageId = 1;

      const request = CompletionRequest(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: stageId,
        trackType: 'personal',
      );

      final completion = (await repository.markComplete(request)).completion;

      expect(completion.curriculumId, curriculumId);
      expect(completion.sefariaRef, sefariaRef);
      expect(completion.stageId, stageId);
      expect(completion.trackType, 'personal');
      expect(completion.points, greaterThan(0));
      expect(completion.id, greaterThan(0));
    });

    test('throws StageProgressionException when skipping stages', () async {
      const curriculumId = 'mishnayos';
      const sefariaRef = 'Mishnah Berachot 1:1';

      // Complete stage 1 first
      await repository.markComplete(
        const CompletionRequest(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: 1,
          trackType: 'personal',
        ),
      );

      // Try stage 3, skipping stage 2
      expect(
        () => repository.markComplete(
          const CompletionRequest(
            curriculumId: curriculumId,
            sefariaRef: sefariaRef,
            stageId: 3,
            trackType: 'personal',
          ),
        ),
        throwsA(isA<StageProgressionException>()),
      );
    });

    test('is idempotent — returns existing completion on duplicate', () async {
      const curriculumId = 'mishnayos';
      const sefariaRef = 'Mishnah Berachot 1:1';
      const request = CompletionRequest(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: 'personal',
      );

      final first = (await repository.markComplete(request)).completion;
      final second = (await repository.markComplete(request)).completion;

      expect(second.id, first.id);
      expect(second.completedAt, first.completedAt);
    });

    test('enforces stage progression per track independently', () async {
      const curriculumId = 'mishnayos';
      const sefariaRef = 'Mishnah Berachot 1:1';

      await repository.markComplete(
        const CompletionRequest(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: 1,
          trackType: 'personal',
        ),
      );

      // Stage 1 on a different track should succeed without requiring
      // stage 1 to be completed on that track first.
      final chavrusaCompletion = (await repository.markComplete(
        const CompletionRequest(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: 1,
          trackType: 'personal',
        ),
      )).completion;
      expect(chavrusaCompletion.trackType, 'personal');
    });

    test(
      'points scale with stage order when stage definitions are present',
      () async {
        const curriculumId = 'mishnayos';

        // Insert stage definitions so _calculatePoints can find them
        await database.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: curriculumId,
            trackId: trackId,
            stageOrder: 1,
            stageName: 'Learning',
            schedule: const Value('{"type":"delay","delay_days":0}'),
          ),
        );
        await database.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: curriculumId,
            trackId: trackId,
            stageOrder: 2,
            stageName: 'Chazara 1',
            schedule: const Value('{"type":"delay","delay_days":1}'),
          ),
        );

        // Stage 1 completion
        final c1 = (await repository.markComplete(
          const CompletionRequest(
            curriculumId: curriculumId,
            sefariaRef: 'Mishnah Berachot 1:1',
            stageId: 1,
            trackType: 'personal',
          ),
        )).completion;

        // Stage 2 completion (same ref, different stage)
        final c2 = (await repository.markComplete(
          const CompletionRequest(
            curriculumId: curriculumId,
            sefariaRef: 'Mishnah Berachot 1:1',
            stageId: 2,
            trackType: 'personal',
          ),
        )).completion;

        // Points differ by stage: Learn=10, Chazara1=5 (default config)
        expect(c1.points, isNot(equals(c2.points)));
      },
    );

    test('honors an injected rewardMilestoneServiceFactory over the real '
        'Drift-backed service (AUD-learning-10)', () async {
      // The shared setUp() seeds a Goal row for this track, so the real
      // (ad-hoc-constructed) RewardMilestoneService would report
      // eligible=true here — see "creates completion record with correct
      // data" above, which asserts points > 0 with this exact fixture.
      // Injecting a factory whose fake always reports ineligible and
      // observing points drop to 0 conclusively proves the factory seam
      // — not a same-behavior ad-hoc construction — is what's consulted.
      final fakeReward = MockRewardMilestoneService();
      when(
        () => fakeReward.trackCountsTowardRewardPoints(any()),
      ).thenAnswer((_) async => false);

      final repositoryWithFakeReward = CompletionRepositoryImpl(
        database: database,
        syncEngine: mockSyncEngine,
        contentRepository: mockContentRepository,
        activeProfileId: learnerId,
        rewardMilestoneServiceFactory: (profileId) => fakeReward,
      );

      final completion = (await repositoryWithFakeReward.markComplete(
        const CompletionRequest(
          curriculumId: 'mishnayos',
          sefariaRef: 'Mishnah Berachot 1:1',
          stageId: 1,
          trackType: 'personal',
        ),
      )).completion;

      expect(
        completion.points,
        0,
        reason:
            'The injected RewardMilestoneService factory reported the '
            'track ineligible; markComplete must honor it instead of an '
            'ad-hoc-constructed real service that would see the seeded '
            'Goal and report eligible=true.',
      );
      verify(() => fakeReward.trackCountsTowardRewardPoints(any())).called(1);
    });
  });

  group('bulkMarkComplete', () {
    test('marks multiple items in a single transaction', () async {
      const curriculumId = 'mishnayos';
      final refs = [
        'Mishnah Berachot 1:1',
        'Mishnah Berachot 1:2',
        'Mishnah Berachot 1:3',
      ];

      final completions = await repository.bulkMarkComplete(
        BulkCompletionRequest(
          curriculumId: curriculumId,
          sefariaRefs: refs,
          stageId: 1,
          trackType: 'personal',
        ),
      );

      expect(completions.length, 3);
      expect(completions.map((c) => c.sefariaRef).toList(), refs);
      // Completions now route through the outbox (not a direct syncEngine push).
      final outboxRows = await database.select(database.outbox).get();
      expect(outboxRows, hasLength(3));
    });

    test(
      'bulk prior flag yields zero points even when track is reward-eligible',
      () async {
        final completions = await repository.bulkMarkComplete(
          const BulkCompletionRequest(
            curriculumId: 'mishnayos',
            sefariaRefs: ['Mishnah Berachot 1:1'],
            stageId: 1,
            trackType: 'personal',
            awardGamificationPoints: false,
          ),
        );

        expect(completions.single.points, 0);
      },
    );

    test(
      'bulk prior fast path handles many stage-1 refs with batch inserts',
      () async {
        const curriculumId = 'mishnayos';
        final refs = List.generate(60, (i) => 'Mishnah Berachot 1:${i + 1}');

        final completions = await repository.bulkMarkComplete(
          BulkCompletionRequest(
            curriculumId: curriculumId,
            sefariaRefs: refs,
            stageId: 1,
            trackType: 'personal',
            awardGamificationPoints: false,
          ),
        );

        expect(completions.length, 60);
        expect(completions.every((c) => c.points == 0), isTrue);
        // All 60 completions land in the outbox for batched Firestore push.
        final outboxRows = await database.select(database.outbox).get();
        expect(outboxRows, hasLength(60));
        final rows = await database.completionDao
            .getCompletionsByCurriculumAndProfile(curriculumId, learnerId);
        expect(rows.length, 60);
      },
    );
  });

  group('streak integration', () {
    // Streak state is derived from `streak_events` (DNI-337). The
    // completion path tees an event into the log; assertions go
    // through `StreakStateProvider` rather than the cached `streaks`
    // snapshot.
    test('first completion produces currentStreak=1 via the reducer', () async {
      await repository.markComplete(
        const CompletionRequest(
          curriculumId: 'mishnayos',
          sefariaRef: 'Mishnah Berachot 1:1',
          stageId: 1,
          trackType: 'personal',
        ),
      );

      final state = await StreakStateProvider(
        db: database,
        clock: const SystemLocalDayClock(),
      ).read(profileId: learnerId);
      expect(state.currentStreak, 1);
      expect(state.maxStreak, 1);
    });

    test('duplicate completion does not double-increment streak', () async {
      const request = CompletionRequest(
        curriculumId: 'mishnayos',
        sefariaRef: 'Mishnah Berachot 1:1',
        stageId: 1,
        trackType: 'personal',
      );

      await repository.markComplete(request);
      await repository.markComplete(request); // idempotent path

      final state = await StreakStateProvider(
        db: database,
        clock: const SystemLocalDayClock(),
      ).read(profileId: learnerId);
      expect(state.currentStreak, 1);
    });
  });

  group('isStageCompleted', () {
    test('returns true for a completed stage', () async {
      const sefariaRef = 'Mishnah Berachot 1:1';
      await repository.markComplete(
        const CompletionRequest(
          curriculumId: 'mishnayos',
          sefariaRef: sefariaRef,
          stageId: 1,
          trackType: 'personal',
        ),
      );

      final result = await repository.isStageCompleted(
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: 'personal',
      );
      expect(result, isTrue);
    });

    test('returns false for a non-completed stage', () async {
      const sefariaRef = 'Mishnah Berachot 1:1';

      final result = await repository.isStageCompleted(
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: 'personal',
      );
      expect(result, isFalse);
    });
  });

  group('advances bookmark', () {
    test('advances bookmark when content repository returns items', () async {
      const curriculumId = 'mishnayos';
      const ref1 = 'Mishnah Berachot 1:1';
      const ref2 = 'Mishnah Berachot 1:2';

      // Stub content repository to return two leaf items in order
      when(
        () => mockContentRepository.getContentForCurriculum(any()),
      ).thenAnswer(
        (_) async => [
          const ContentItem(
            curriculumId: 'mishnayos',
            sefariaRef: ref1,
            displayNameEn: 'Berachot 1:1',
            displayNameHe: '',
            isLeaf: true,
            sortOrder: 1,
            level1: 'Seder Zeraim',
          ),
          const ContentItem(
            curriculumId: 'mishnayos',
            sefariaRef: ref2,
            displayNameEn: 'Berachot 1:2',
            displayNameHe: '',
            isLeaf: true,
            sortOrder: 2,
            level1: 'Seder Zeraim',
          ),
        ],
      );

      // Create a bookmark on ref1
      await database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          profileId: learnerId,
          curriculumId: curriculumId,
          trackId: trackId,
          sefariaRef: ref1,
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      await repository.markComplete(
        const CompletionRequest(
          curriculumId: curriculumId,
          sefariaRef: ref1,
          stageId: 1,
          trackType: 'personal',
        ),
      );

      final bookmark = await database.bookmarkDao
          .getBookmarkByCurriculumTrackAndProfile(
            curriculumId,
            trackId,
            learnerId,
          );
      expect(bookmark?.sefariaRef, ref2);
    });
  });

  group('bookmarkRepositoryFactory — delegated profile (AUD-learning-04)', () {
    test('delegated-profile advance uses the injected ContentIndex fast path, '
        'not the O(N) content-repo scan', () async {
      const curriculumId = 'mishnayos';
      const ref1 = 'Mishnah Berachot 1:1';
      const ref2 = 'Mishnah Berachot 1:2';
      final now = DateTime.now();

      // A second profile, delegated-to (e.g. parent bulk-marking prior
      // learning for a child while the session's active profile is the
      // parent) — deliberately NOT `learnerId`/`_activeProfileId`.
      final delegateRow = await database
          .into(database.learnerProfiles)
          .insertReturning(
            ProfilesCompanion.insert(
              accountId: 1,
              displayName: 'Delegate',
              mode: 'child',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final delegateProfileId = delegateRow.id;
      expect(delegateProfileId, isNot(learnerId));

      final delegateTrackRow = await database
          .into(database.curriculumTracks)
          .insertReturning(
            CurriculumTracksCompanion.insert(
              profileId: delegateProfileId,
              curriculumId: curriculumId,
              stateChangedAt: now,
              activatedAt: now,
            ),
          );

      const item1 = ContentItem(
        curriculumId: curriculumId,
        sefariaRef: ref1,
        displayNameEn: 'Berachot 1:1',
        displayNameHe: '',
        isLeaf: true,
        sortOrder: 1,
        level1: 'Seder Zeraim',
      );
      const item2 = ContentItem(
        curriculumId: curriculumId,
        sefariaRef: ref2,
        displayNameEn: 'Berachot 1:2',
        displayNameHe: '',
        isLeaf: true,
        sortOrder: 2,
        level1: 'Seder Zeraim',
      );
      final contentIndex = ContentIndex.fromCurricula({
        CurriculumId.mishnayos: [item1, item2],
      });

      // A repository wired with a bookmarkRepositoryFactory carrying a
      // ContentIndex — mirrors how completionRepositoryProvider wires
      // production. activeProfileId stays `learnerId`; the bulk request
      // below targets the delegate profile, so the injected same-profile
      // `bookmarkRepository` (unset here) could never apply — only the
      // factory can serve this profile.
      final delegatingRepository = CompletionRepositoryImpl(
        database: database,
        syncEngine: mockSyncEngine,
        contentRepository: mockContentRepository,
        activeProfileId: learnerId,
        bookmarkRepositoryFactory: (profileId) => BookmarkRepositoryImpl(
          database: database,
          syncEngine: mockSyncEngine,
          contentRepository: mockContentRepository,
          profileId: profileId,
          contentIndex: contentIndex,
        ),
      );

      await delegatingRepository.bulkMarkComplete(
        BulkCompletionRequest(
          curriculumId: curriculumId,
          sefariaRefs: const [ref1],
          stageId: 1,
          trackType: 'personal',
          profileId: delegateProfileId,
          // Routes through _bulkMarkCompletePriorOptimized — the leanest
          // path to _advanceBookmark, avoiding unrelated reward/streak
          // collaborators.
          awardGamificationPoints: false,
        ),
      );

      // AUD-learning-04: the delegated-profile advance must resolve via
      // the O(1) ContentIndex, never fall back to the O(N) content-repo
      // scan `BookmarkRepositoryImpl` uses when no index is supplied.
      verifyNever(() => mockContentRepository.getContentForCurriculum(any()));

      final bookmark = await database.bookmarkDao
          .getBookmarkByCurriculumTrackAndProfile(
            curriculumId,
            delegateTrackRow.id,
            delegateProfileId,
          );
      expect(
        bookmark?.sefariaRef,
        ref2,
        reason:
            'The ContentIndex fast path must resolve the same next-item '
            'as the O(N) scan it replaces.',
      );
    });
  });
}
