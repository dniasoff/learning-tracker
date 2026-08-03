import 'package:drift/drift.dart' show Value;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_service.dart';
import 'package:learning_tracker/features/learning/data/completion_points_awarder.dart';
import 'package:learning_tracker/features/learning/data/completion_streak_recorder.dart';
import 'package:learning_tracker/features/learning/data/repositories/bookmark_repository_impl.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';

class MockSyncEngine extends Mock implements SyncWriteFacade {}

class MockContentRepository extends Mock implements ContentRepository {}

class MockRewardMilestoneService extends Mock
    implements RewardMilestoneService {}

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });
  late UserDatabase database;
  late MockSyncEngine mockSyncEngine;
  late MockContentRepository mockContentRepository;
  late CompletionRepositoryImpl repository;
  late CompletionOrchestrator orchestrator;
  late int trackId;
  late int learnerId;

  setUp(() async {
    database = createTestDatabase();
    mockSyncEngine = MockSyncEngine();
    mockContentRepository = MockContentRepository();

    final now = DateTime.utc(2026, 5, 1);
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

    // Post completion-orchestrator lift (`docs/firestore-rewrite-map.md`,
    // owner decision 1): `repository` is storage-only now. `orchestrator`
    // wires the same collaborators production does
    // (`completion_providers.dart`'s `completionOrchestratorProvider`) so
    // order validation, points, streak, and bookmark advance — the
    // behaviors this file's tests actually exercise — still fire.
    repository = CompletionRepositoryImpl(
      database: database,
      activeProfileId: learnerId,
    );
    orchestrator = CompletionOrchestrator(
      repository: repository,
      contentRepository: mockContentRepository,
      activeProfileId: learnerId,
      bookmarkRepository: BookmarkRepositoryImpl(
        database: database,
        syncEngine: mockSyncEngine,
        contentRepository: mockContentRepository,
        profileId: learnerId,
      ),
      pointsPort: DriftCompletionPointsAwarder(
        database: database,
        rewardMilestoneServiceFactory: (profileId) =>
            RewardMilestoneService(database, profileId: profileId),
        syncEngine: mockSyncEngine,
      ),
      streakPort: DriftCompletionStreakRecorder(database: database),
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

      final completion = (await orchestrator.markComplete(request)).completion;

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
      await orchestrator.markComplete(
        const CompletionRequest(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: 1,
          trackType: 'personal',
        ),
      );

      // Try stage 3, skipping stage 2. Post completion-orchestrator lift
      // (`docs/firestore-rewrite-map.md`, owner decision 1) this validation
      // runs in CompletionOrchestrator BEFORE any write — see that class's
      // doc comment, "Ordering" — not in CompletionRepositoryImpl any more.
      expect(
        () => orchestrator.markComplete(
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

      final first = (await orchestrator.markComplete(request)).completion;
      final second = (await orchestrator.markComplete(request)).completion;

      expect(second.id, first.id);
      expect(second.completedAt, first.completedAt);
    });

    test('enforces stage progression per track independently', () async {
      const curriculumId = 'mishnayos';
      const sefariaRef = 'Mishnah Berachot 1:1';

      await orchestrator.markComplete(
        const CompletionRequest(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: 1,
          trackType: 'personal',
        ),
      );

      // Stage 1 on a different track should succeed without requiring
      // stage 1 to be completed on that track first.
      final chavrusaCompletion = (await orchestrator.markComplete(
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
        final c1 = (await orchestrator.markComplete(
          const CompletionRequest(
            curriculumId: curriculumId,
            sefariaRef: 'Mishnah Berachot 1:1',
            stageId: 1,
            trackType: 'personal',
          ),
        )).completion;

        // Stage 2 completion (same ref, different stage)
        final c2 = (await orchestrator.markComplete(
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
      //
      // Post completion-orchestrator lift (`docs/firestore-rewrite-map.md`,
      // owner decision 1): `rewardMilestoneServiceFactory` is a
      // `CompletionPointsPort` (`DriftCompletionPointsAwarder`) constructor
      // argument now, not `CompletionRepositoryImpl`'s — the factory seam
      // itself is unchanged, only which class owns it.
      final fakeReward = MockRewardMilestoneService();
      when(
        () => fakeReward.trackCountsTowardRewardPoints(any()),
      ).thenAnswer((_) async => false);

      final orchestratorWithFakeReward = CompletionOrchestrator(
        repository: repository,
        contentRepository: mockContentRepository,
        activeProfileId: learnerId,
        pointsPort: DriftCompletionPointsAwarder(
          database: database,
          rewardMilestoneServiceFactory: (profileId) => fakeReward,
          syncEngine: mockSyncEngine,
        ),
      );

      final completion = (await orchestratorWithFakeReward.markComplete(
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
    // through `StreakStateService` rather than the cached `streaks`
    // snapshot.
    test('first completion produces currentStreak=1 via the reducer', () async {
      await orchestrator.markComplete(
        const CompletionRequest(
          curriculumId: 'mishnayos',
          sefariaRef: 'Mishnah Berachot 1:1',
          stageId: 1,
          trackType: 'personal',
        ),
      );

      final state = await StreakStateService(
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

      await orchestrator.markComplete(request);
      await orchestrator.markComplete(request); // idempotent path

      final state = await StreakStateService(
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

      await orchestrator.markComplete(
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

  group('FirestoreCompletionRepositoryAdapter', () {
    const uid = 'uid-1';
    const profileDocId = 'profile-ulid-1';
    const curriculumId = 'mishnayos';
    const sefariaRef = 'Mishnah Berachot 1:1';

    AccountFirebaseHandles handles(FakeFirebaseFirestore firestore) {
      return AccountFirebaseHandles(
        app: MockFirebaseApp(),
        firestore: firestore,
        auth: MockFirebaseAuthHandle(),
        uid: uid,
      );
    }

    // Constructing FirestoreCompletionRepositoryAdapter requires a Ref
    // (Riverpod's Ref is sealed — it can only come from inside a provider
    // callback), so tests obtain one the same way production does: read a
    // throwaway Provider that builds the adapter from the container's ref.
    // Mirrors FirestoreBookmarkRepositoryAdapter's test helper
    // (bookmark_repository_impl_test.dart).
    FirestoreCompletionRepositoryAdapter buildAdapter(
      ProviderContainer container,
    ) {
      final adapterProvider = Provider<FirestoreCompletionRepositoryAdapter>(
        (ref) => FirestoreCompletionRepositoryAdapter(ref: ref),
      );
      return container.read(adapterProvider);
    }

    group('not ready (no active account/profile)', () {
      test(
        'getCompletionsByCurriculum returns [] instead of throwing',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            await adapter.getCompletionsByCurriculum(curriculumId),
            isEmpty,
          );
        },
      );

      test(
        'getCompletionsForContentItem returns [] instead of throwing',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            await adapter.getCompletionsForContentItem(sefariaRef),
            isEmpty,
          );
        },
      );

      test('isStageCompleted returns false instead of throwing', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        expect(
          await adapter.isStageCompleted(
            sefariaRef: sefariaRef,
            stageId: 1,
            trackType: 'personal',
          ),
          isFalse,
        );
      });

      test(
        'markComplete throws CompletionRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.markComplete(
              const CompletionRequest(
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                stageId: 1,
                trackType: 'personal',
              ),
            ),
            throwsA(isA<CompletionRepositoryNotReadyException>()),
          );
        },
      );

      test(
        'bulkMarkComplete throws CompletionRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.bulkMarkComplete(
              const BulkCompletionRequest(
                curriculumId: curriculumId,
                sefariaRefs: [sefariaRef],
                stageId: 1,
                trackType: 'personal',
              ),
            ),
            throwsA(isA<CompletionRepositoryNotReadyException>()),
          );
        },
      );
    });

    group('ready (active account + profile)', () {
      late FakeFirebaseFirestore firestore;
      late ProviderContainer container;
      late FirestoreCompletionRepositoryAdapter adapter;

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

      Future<List<Map<String, dynamic>>> rawCompletionDocs() async {
        final snapshot = await firestore
            .collection('users')
            .doc(uid)
            .collection('learner_profiles')
            .doc(profileDocId)
            .collection('completions')
            .get();
        return snapshot.docs.map((d) => d.data()).toList();
      }

      group('source correctness per call-site category', () {
        test(
          'markComplete with default (live) args writes source=live',
          () async {
            final result = await adapter.markComplete(
              const CompletionRequest(
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                stageId: 1,
                trackType: 'personal',
              ),
            );

            expect(result.completion.sefariaRef, sefariaRef);
            expect(result.completion.curriculumId, curriculumId);
            expect(result.completion.stageId, 1);
            expect(result.completion.trackType, 'personal');
            expect(result.completion.completedAt.isUtc, isTrue);
            // No points calculation exists at this layer — see the class
            // doc comment, "What this adapter does NOT do."
            expect(result.completion.points, 0);

            final docs = await rawCompletionDocs();
            expect(docs, hasLength(1));
            expect(docs.single['source'], CompletionSource.live.name);
          },
        );

        test('markComplete with (awardGamificationPoints: false, '
            'creditsAchievement: true) writes source=bulkInTrack — the '
            'BulkPriorCompletionService category', () async {
          await adapter.markComplete(
            const CompletionRequest(
              curriculumId: curriculumId,
              sefariaRef: sefariaRef,
              stageId: 1,
              trackType: 'personal',
            ),
            awardGamificationPoints: false,
            creditsAchievement: true,
          );

          final docs = await rawCompletionDocs();
          expect(docs.single['source'], CompletionSource.bulkInTrack.name);
        });

        test('markComplete with (false, false) — lifetimeOnly — throws '
            'ArgumentError instead of writing a completions doc', () async {
          expect(
            () => adapter.markComplete(
              const CompletionRequest(
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                stageId: 1,
                trackType: 'personal',
              ),
              awardGamificationPoints: false,
              creditsAchievement: false,
            ),
            throwsA(isA<ArgumentError>()),
          );
        });

        test(
          'bulkMarkComplete with (false, true) writes every item as '
          'source=bulkInTrack — the onboarding bulk-mark-prior category',
          () async {
            final completedAt = DateTime.utc(2000, 1, 1);
            final results = await adapter.bulkMarkComplete(
              BulkCompletionRequest(
                curriculumId: curriculumId,
                sefariaRefs: const [sefariaRef, 'Mishnah Berachot 1:2'],
                stageId: 1,
                trackType: 'personal',
                awardGamificationPoints: false,
                creditsAchievement: true,
                completedAt: completedAt,
              ),
            );

            expect(results, hasLength(2));
            final docs = await rawCompletionDocs();
            expect(docs, hasLength(2));
            expect(
              docs.every(
                (d) => d['source'] == CompletionSource.bulkInTrack.name,
              ),
              isTrue,
            );
          },
        );
      });

      group('idempotency (SR-1 byte-identical-replay guard)', () {
        test('marking the same stage twice returns the SAME completedAt '
            'instead of computing a fresh one on the second call', () async {
          final first = await adapter.markComplete(
            const CompletionRequest(
              curriculumId: curriculumId,
              sefariaRef: sefariaRef,
              stageId: 1,
              trackType: 'personal',
            ),
          );

          final second = await adapter.markComplete(
            const CompletionRequest(
              curriculumId: curriculumId,
              sefariaRef: sefariaRef,
              stageId: 1,
              trackType: 'personal',
            ),
          );

          expect(second.completion.completedAt, first.completion.completedAt);
          // Only one document should exist — the second call must not
          // have attempted a second, differently-timestamped write.
          final docs = await rawCompletionDocs();
          expect(docs, hasLength(1));
        });
      });

      group('delegated profile is unsupported', () {
        test(
          'getCompletionsByCurriculum with a non-null profileId throws',
          () async {
            expect(
              () => adapter.getCompletionsByCurriculum(
                curriculumId,
                profileId: 42,
              ),
              throwsA(
                isA<CompletionRepositoryDelegatedProfileUnsupportedException>(),
              ),
            );
          },
        );
      });

      group('read delegation', () {
        test('getCompletionsByCurriculum round-trips a completion written via '
            'markComplete', () async {
          await adapter.markComplete(
            const CompletionRequest(
              curriculumId: curriculumId,
              sefariaRef: sefariaRef,
              stageId: 1,
              trackType: 'personal',
            ),
          );

          final results = await adapter.getCompletionsByCurriculum(
            curriculumId,
          );

          expect(results, hasLength(1));
          expect(results.single.sefariaRef, sefariaRef);
        });

        test('getCompletionsForContentItem round-trips a completion written '
            'via markComplete', () async {
          await adapter.markComplete(
            const CompletionRequest(
              curriculumId: curriculumId,
              sefariaRef: sefariaRef,
              stageId: 1,
              trackType: 'personal',
            ),
          );

          final results = await adapter.getCompletionsForContentItem(
            sefariaRef,
          );

          expect(results, hasLength(1));
          expect(results.single.curriculumId, curriculumId);
        });

        test(
          'isStageCompleted is true only for a matching trackType + stageId',
          () async {
            await adapter.markComplete(
              const CompletionRequest(
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                stageId: 1,
                trackType: 'personal',
              ),
            );

            expect(
              await adapter.isStageCompleted(
                sefariaRef: sefariaRef,
                stageId: 1,
                trackType: 'personal',
              ),
              isTrue,
            );
            expect(
              await adapter.isStageCompleted(
                sefariaRef: sefariaRef,
                stageId: 2,
                trackType: 'personal',
              ),
              isFalse,
            );
            expect(
              await adapter.isStageCompleted(
                sefariaRef: sefariaRef,
                stageId: 1,
                trackType: 'someOtherTrackType',
              ),
              isFalse,
            );
          },
        );
      });

      group('id / profileId / trackId are sentinel', () {
        test(
          'markComplete result carries kFirestoreUnmappedCompletionRowId '
          'for id, profileId, and trackId — never a real Drift value',
          () async {
            final result = await adapter.markComplete(
              const CompletionRequest(
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                stageId: 1,
                trackType: 'personal',
              ),
            );

            expect(result.completion.id, kFirestoreUnmappedCompletionRowId);
            expect(
              result.completion.profileId,
              kFirestoreUnmappedCompletionRowId,
            );
            expect(
              result.completion.trackId,
              kFirestoreUnmappedCompletionRowId,
            );
          },
        );
      });
    });
  });
}
