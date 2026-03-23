import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/network/connectivity_service.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:learning_tracker/features/sync/data/offline_queue.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';

class MockFirestoreDataSource extends Mock implements FirestoreDataSource {}

class MockOfflineQueue extends Mock implements OfflineQueue {}

class MockConnectivityService extends Mock implements ConnectivityService {}

AppDatabase _createInMemoryDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

void main() {
  late AppDatabase database;
  late MockFirestoreDataSource mockFirestore;
  late MockOfflineQueue mockOfflineQueue;
  late MockConnectivityService mockConnectivity;
  late Talker logger;
  late SyncEngine syncEngine;

  setUp(() {
    database = _createInMemoryDatabase();
    mockFirestore = MockFirestoreDataSource();
    mockOfflineQueue = MockOfflineQueue();
    mockConnectivity = MockConnectivityService();
    logger = Talker();

    when(() => mockConnectivity.isOnline).thenAnswer((_) async => true);

    // Default stubs for methods called by pullOnLaunch / attachListeners
    when(() => mockFirestore.fetchLedgerEntries()).thenAnswer((_) async => []);
    when(
      () => mockFirestore.listenToLedgerEntries(),
    ).thenAnswer((_) => const Stream.empty());

    syncEngine = SyncEngine(
      database: database,
      firestoreDataSource: mockFirestore,
      offlineQueue: mockOfflineQueue,
      logger: logger,
      connectivityService: mockConnectivity,
    );
  });

  tearDown(() async {
    await syncEngine.dispose();
    await database.close();
  });

  group('SyncEngine lifecycle', () {
    test('initialize calls pullOnLaunch', () async {
      when(() => mockFirestore.fetchCompletions()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchBookmarks()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchSettings()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchProfile()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchGoals()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchRewards()).thenAnswer((_) async => []);

      await syncEngine.initialize();

      verify(() => mockFirestore.fetchCompletions()).called(1);
    });

    test('currentStatus is synced by default', () {
      final status = syncEngine.currentStatus;
      expect(
        status,
        isA<SyncStatus>().having(
          (s) => s.maybeWhen(synced: (_) => true, orElse: () => false),
          'is synced',
          true,
        ),
      );
    });

    test('statusStream emits status changes', () async {
      when(() => mockFirestore.fetchCompletions()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchBookmarks()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchSettings()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchProfile()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchGoals()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchRewards()).thenAnswer((_) async => []);

      final statuses = <SyncStatus>[];
      final subscription = syncEngine.statusStream.listen(statuses.add);

      await syncEngine.pullOnLaunch();

      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      // Should emit syncing then synced
      expect(statuses.length, greaterThanOrEqualTo(2));
      expect(
        statuses.first.maybeWhen(syncing: (_) => true, orElse: () => false),
        isTrue,
      );
      expect(
        statuses.last.maybeWhen(synced: (_) => true, orElse: () => false),
        isTrue,
      );
    });
  });

  group('SyncEngine pullOnLaunch', () {
    test('sets offline status when not online', () async {
      when(() => mockOfflineQueue.getPendingCount()).thenAnswer((_) async => 3);
      syncEngine.setOnlineState(false);

      await syncEngine.pullOnLaunch();

      final status = syncEngine.currentStatus;
      expect(
        status.maybeWhen(offline: (pending) => pending, orElse: () => -1),
        3,
      );
      verifyNever(() => mockFirestore.fetchCompletions());
    });

    test('sets error status when fetch fails', () async {
      when(
        () => mockFirestore.fetchCompletions(),
      ).thenThrow(Exception('Network error'));

      await syncEngine.pullOnLaunch();

      final status = syncEngine.currentStatus;
      expect(
        status.maybeWhen(error: (msg, _) => msg, orElse: () => ''),
        contains('Network error'),
      );
    });
  });

  group('SyncEngine getPendingCount', () {
    test('returns 0 when no items queued', () async {
      final count = await database.syncQueueDao.getPendingCount();
      expect(count, 0);
    });

    test('returns accurate count after enqueuing multiple items', () async {
      await database.syncQueueDao.enqueue('completion', '{"id":"1"}');
      await database.syncQueueDao.enqueue('bookmark', '{"id":"2"}');
      await database.syncQueueDao.enqueue('settings', '{"id":"3"}');

      final count = await database.syncQueueDao.getPendingCount();
      expect(count, 3);
    });

    test('decrements after removing an item', () async {
      final id = await database.syncQueueDao.enqueue(
        'completion',
        '{"id":"1"}',
      );
      await database.syncQueueDao.enqueue('bookmark', '{"id":"2"}');

      await database.syncQueueDao.remove(id);

      final count = await database.syncQueueDao.getPendingCount();
      expect(count, 1);
    });
  });

  group('SyncEngine reconnect behavior', () {
    test('reattaches listeners after reconnect', () async {
      when(
        () => mockFirestore.listenToCompletions(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToBookmarks(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToSettings(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToStreak(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToGoals(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToRewards(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToActiveCurricula(),
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockOfflineQueue.flush()).thenAnswer((_) async => 0);
      when(() => mockOfflineQueue.getPendingCount()).thenAnswer((_) async => 0);

      // Attach listeners
      await syncEngine.attachListeners();

      // Go offline — this detaches listeners and clears _listenersAttached
      syncEngine.setOnlineState(false);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Go back online — _onReconnect should reattach listeners
      syncEngine.setOnlineState(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // listenTo* should have been called twice: once on initial attach and
      // once after reconnect.
      verify(() => mockFirestore.listenToCompletions()).called(2);
    });

    test('flushes offline queue on reconnect', () async {
      when(
        () => mockFirestore.listenToCompletions(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToBookmarks(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToSettings(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToStreak(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToGoals(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToRewards(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToActiveCurricula(),
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockOfflineQueue.flush()).thenAnswer((_) async => 2);
      when(() => mockOfflineQueue.getPendingCount()).thenAnswer((_) async => 0);

      syncEngine.setOnlineState(false);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      syncEngine.setOnlineState(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(() => mockOfflineQueue.flush()).called(1);
    });
  });

  group('SyncEngine _mergeCompletions', () {
    test('inserts new completions that do not exist locally', () async {
      when(() => mockFirestore.fetchCompletions()).thenAnswer(
        (_) async => [
          {
            'curriculum_id': 'mishnayos',
            'content_item_id': 'mishna-1',
            'stage_id': 1,
            'track_type': 'personal',
            'completed_at': '2026-02-09T12:00:00.000Z',
            'points': 10,
          },
        ],
      );
      when(() => mockFirestore.fetchBookmarks()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchSettings()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchProfile()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchGoals()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchRewards()).thenAnswer((_) async => []);

      await syncEngine.pullOnLaunch();

      final completions = await database.completionDao.getAllCompletions();
      expect(completions.length, 1);
      expect(completions.first.curriculumId, 'mishnayos');
      expect(completions.first.sefariaRef, 'mishna-1');
      expect(completions.first.points, 10);
    });

    test('skips completions that already exist locally', () async {
      // Insert locally first
      final completedAt = DateTime.utc(2026, 2, 9, 12, 0, 0);
      await database.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'mishnayos',
          sefariaRef: 'mishna-1',
          stageId: 1,
          trackType: 'personal',
          completedAt: completedAt,
          points: const Value(10),
        ),
      );

      when(() => mockFirestore.fetchCompletions()).thenAnswer(
        (_) async => [
          {
            'curriculum_id': 'mishnayos',
            'content_item_id': 'mishna-1',
            'stage_id': 1,
            'track_type': 'personal',
            'completed_at': '2026-02-09T12:00:00.000Z',
            'points': 10,
          },
        ],
      );
      when(() => mockFirestore.fetchBookmarks()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchSettings()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchProfile()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchGoals()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchRewards()).thenAnswer((_) async => []);

      await syncEngine.pullOnLaunch();

      final completions = await database.completionDao.getAllCompletions();
      expect(completions.length, 1); // No duplicate
    });

    test('skips completions with missing required fields', () async {
      when(() => mockFirestore.fetchCompletions()).thenAnswer(
        (_) async => [
          {
            'curriculum_id': 'mishnayos',
            // Missing content_item_id, stage_id, etc.
          },
        ],
      );
      when(() => mockFirestore.fetchBookmarks()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchSettings()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchProfile()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchGoals()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchRewards()).thenAnswer((_) async => []);

      await syncEngine.pullOnLaunch();

      final completions = await database.completionDao.getAllCompletions();
      expect(completions, isEmpty);
    });

    test('merges multiple completions from different curricula', () async {
      when(() => mockFirestore.fetchCompletions()).thenAnswer(
        (_) async => [
          {
            'curriculum_id': 'mishnayos',
            'content_item_id': 'mishna-1',
            'stage_id': 1,
            'track_type': 'personal',
            'completed_at': '2026-02-09T12:00:00.000Z',
            'points': 10,
          },
          {
            'curriculum_id': 'bavli',
            'content_item_id': 'bavli-5',
            'stage_id': 1,
            'track_type': 'school',
            'completed_at': '2026-02-09T14:00:00.000Z',
            'points': 15,
          },
        ],
      );
      when(() => mockFirestore.fetchBookmarks()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchSettings()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchProfile()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchGoals()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchRewards()).thenAnswer((_) async => []);

      await syncEngine.pullOnLaunch();

      final completions = await database.completionDao.getAllCompletions();
      expect(completions.length, 2);
    });
  });

  group('SyncEngine _mergeBookmarks (merge conflict resolution)', () {
    test('inserts new bookmarks from Firestore', () async {
      when(() => mockFirestore.fetchCompletions()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchBookmarks()).thenAnswer(
        (_) async => [
          {
            'curriculum_id': 'mishnayos',
            'track_type': 'personal',
            'content_item_id': 'mishna-42',
            'updated_at': '2026-02-09T12:00:00.000Z',
          },
        ],
      );
      when(() => mockFirestore.fetchSettings()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchProfile()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchGoals()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchRewards()).thenAnswer((_) async => []);

      await syncEngine.pullOnLaunch();

      final bookmark = await database.bookmarkDao
          .getBookmarkByCurriculumAndTrack('mishnayos', 'personal');
      expect(bookmark, isNotNull);
      expect(bookmark!.sefariaRef, 'mishna-42');
    });

    test('remote newer wins — updates bookmark when remote is newer', () async {
      // Insert older local bookmark
      await database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: 'mishnayos',
          trackType: 'personal',
          sefariaRef: 'mishna-10',
          updatedAt: DateTime.utc(2026, 2, 8),
        ),
      );

      when(() => mockFirestore.fetchCompletions()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchBookmarks()).thenAnswer(
        (_) async => [
          {
            'curriculum_id': 'mishnayos',
            'track_type': 'personal',
            'content_item_id': 'mishna-42',
            'updated_at': '2026-02-09T12:00:00.000Z', // newer
          },
        ],
      );
      when(() => mockFirestore.fetchSettings()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchProfile()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchGoals()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchRewards()).thenAnswer((_) async => []);

      await syncEngine.pullOnLaunch();

      final bookmark = await database.bookmarkDao
          .getBookmarkByCurriculumAndTrack('mishnayos', 'personal');
      expect(bookmark!.sefariaRef, 'mishna-42'); // Updated to remote
    });

    test(
      'local newer wins — keeps local bookmark when local is newer',
      () async {
        // Insert newer local bookmark
        await database.bookmarkDao.insertBookmark(
          BookmarksCompanion.insert(
            curriculumId: 'mishnayos',
            trackType: 'personal',
            sefariaRef: 'mishna-99',
            updatedAt: DateTime.utc(2026, 2, 10),
          ),
        );

        when(
          () => mockFirestore.fetchCompletions(),
        ).thenAnswer((_) async => []);
        when(() => mockFirestore.fetchBookmarks()).thenAnswer(
          (_) async => [
            {
              'curriculum_id': 'mishnayos',
              'track_type': 'personal',
              'content_item_id': 'mishna-42',
              'updated_at': '2026-02-09T12:00:00.000Z', // older
            },
          ],
        );
        when(() => mockFirestore.fetchSettings()).thenAnswer((_) async => []);
        when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
        when(() => mockFirestore.fetchProfile()).thenAnswer((_) async => null);
        when(() => mockFirestore.fetchGoals()).thenAnswer((_) async => []);
        when(() => mockFirestore.fetchRewards()).thenAnswer((_) async => []);

        await syncEngine.pullOnLaunch();

        final bookmark = await database.bookmarkDao
            .getBookmarkByCurriculumAndTrack('mishnayos', 'personal');
        expect(bookmark!.sefariaRef, 'mishna-99'); // Kept local
      },
    );
  });

  group('SyncEngine _mergeSettings', () {
    test('replaces stage definitions from remote settings', () async {
      // Insert local stages
      await database.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 1,
          stageName: 'Old Learn',
          delayDays: 0,
        ),
      );

      when(() => mockFirestore.fetchCompletions()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchBookmarks()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchSettings()).thenAnswer(
        (_) async => [
          {
            'curriculum_id': 'mishnayos',
            'stages': [
              {
                'stage_order': 1,
                'stage_name': 'Learn',
                'delay_days': 0,
                'is_default': true,
              },
              {
                'stage_order': 2,
                'stage_name': 'Chazara 1',
                'delay_days': 1,
                'is_default': true,
              },
            ],
          },
        ],
      );
      when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchProfile()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchGoals()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchRewards()).thenAnswer((_) async => []);

      await syncEngine.pullOnLaunch();

      final stages = await database.stageDao.getStageDefinitionsByCurriculum(
        'mishnayos',
      );
      expect(stages.length, 2);
      expect(stages[0].stageName, 'Learn');
      expect(stages[1].stageName, 'Chazara 1');
    });
  });

  group('SyncEngine _mergeProfile', () {
    test('inserts profile when none exists locally', () async {
      when(() => mockFirestore.fetchCompletions()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchBookmarks()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchSettings()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchProfile()).thenAnswer(
        (_) async => {
          'firebase_uid': 'uid-123',
          'display_name': 'Yisroel',
          'user_mode': 'child',
          'updated_at': '2026-02-09T12:00:00.000Z',
        },
      );
      when(() => mockFirestore.fetchGoals()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchRewards()).thenAnswer((_) async => []);

      await syncEngine.pullOnLaunch();

      final profile = await database.userProfileDao.getUserProfileByFirebaseUid(
        'uid-123',
      );
      expect(profile, isNotNull);
      expect(profile!.displayName, 'Yisroel');
      expect(profile.userMode, 'child');
    });

    test('updates profile when remote is newer', () async {
      // Insert older local profile
      await database.userProfileDao.insertUserProfile(
        UserProfilesCompanion.insert(
          firebaseUid: 'uid-123',
          displayName: 'Old Name',
          userMode: 'adult',
          createdAt: DateTime.utc(2026, 2, 7),
          updatedAt: DateTime.utc(2026, 2, 7),
        ),
      );

      when(() => mockFirestore.fetchCompletions()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchBookmarks()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchSettings()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchProfile()).thenAnswer(
        (_) async => {
          'firebase_uid': 'uid-123',
          'display_name': 'New Name',
          'user_mode': 'child',
          'updated_at': '2026-02-09T12:00:00.000Z',
        },
      );
      when(() => mockFirestore.fetchGoals()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchRewards()).thenAnswer((_) async => []);

      await syncEngine.pullOnLaunch();

      final profile = await database.userProfileDao.getUserProfileByFirebaseUid(
        'uid-123',
      );
      expect(profile!.displayName, 'New Name');
      expect(profile.userMode, 'child');
    });
  });

  group('SyncEngine _mergeGoals', () {
    void stubAllFetchesExceptGoals(List<Map<String, dynamic>> goals) {
      when(() => mockFirestore.fetchCompletions()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchBookmarks()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchSettings()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchProfile()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchGoals()).thenAnswer((_) async => goals);
      when(() => mockFirestore.fetchRewards()).thenAnswer((_) async => []);
    }

    test('inserts new goals from Firestore', () async {
      stubAllFetchesExceptGoals([
        {
          'curriculum_id': 'mishnayos',
          'description': 'Finish Berachos',
          'target_percent': 100.0,
          'target_date': '2026-06-01T00:00:00.000Z',
          'created_at': '2026-02-01T00:00:00.000Z',
          'updated_at': '2026-02-09T12:00:00.000Z',
        },
      ]);

      await syncEngine.pullOnLaunch();

      final goals = await database.goalDao.getGoalsByCurriculum('mishnayos');
      expect(goals.length, 1);
      expect(goals.first.description, 'Finish Berachos');
      expect(goals.first.targetPercent, 100.0);
    });

    test('remote newer wins — updates goal when remote is newer', () async {
      await database.goalDao.insertGoal(
        GoalsCompanion.insert(
          curriculumId: 'mishnayos',
          description: const Value('Finish Berachos'),
          targetPercent: const Value(50.0),
          createdAt: DateTime.utc(2026, 2, 1),
          updatedAt: DateTime.utc(2026, 2, 8),
        ),
      );

      stubAllFetchesExceptGoals([
        {
          'curriculum_id': 'mishnayos',
          'description': 'Finish Berachos',
          'target_percent': 100.0,
          'created_at': '2026-02-01T00:00:00.000Z',
          'updated_at': '2026-02-09T12:00:00.000Z', // newer
        },
      ]);

      await syncEngine.pullOnLaunch();

      final goals = await database.goalDao.getGoalsByCurriculum('mishnayos');
      expect(goals.length, 1);
      expect(goals.first.targetPercent, 100.0); // Updated
    });

    test('local newer wins — keeps local goal when local is newer', () async {
      await database.goalDao.insertGoal(
        GoalsCompanion.insert(
          curriculumId: 'mishnayos',
          description: const Value('Finish Berachos'),
          targetPercent: const Value(50.0),
          createdAt: DateTime.utc(2026, 2, 1),
          updatedAt: DateTime.utc(2026, 2, 10), // newer than remote
        ),
      );

      stubAllFetchesExceptGoals([
        {
          'curriculum_id': 'mishnayos',
          'description': 'Finish Berachos',
          'target_percent': 100.0,
          'created_at': '2026-02-01T00:00:00.000Z',
          'updated_at': '2026-02-09T12:00:00.000Z', // older
        },
      ]);

      await syncEngine.pullOnLaunch();

      final goals = await database.goalDao.getGoalsByCurriculum('mishnayos');
      expect(goals.length, 1);
      expect(goals.first.targetPercent, 50.0); // Kept local
    });

    test('skips goals with missing required fields', () async {
      stubAllFetchesExceptGoals([
        {
          'description': 'No curriculum_id',
          // Missing curriculum_id, created_at, updated_at
        },
      ]);

      await syncEngine.pullOnLaunch();

      final goals = await database.goalDao.getAllGoals();
      expect(goals, isEmpty);
    });
  });

  group('SyncEngine _mergeRewards', () {
    void stubAllFetchesExceptRewards(List<Map<String, dynamic>> rewards) {
      when(() => mockFirestore.fetchCompletions()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchBookmarks()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchSettings()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchProfile()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchGoals()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchRewards()).thenAnswer((_) async => rewards);
    }

    test('inserts new rewards from Firestore', () async {
      stubAllFetchesExceptRewards([
        {
          'title': 'First Completion',
          'description': 'Complete your first item',
          'points_threshold': 10,
          'is_revealed': true,
          'is_earned': false,
          'created_at': '2026-02-01T00:00:00.000Z',
        },
      ]);

      await syncEngine.pullOnLaunch();

      final rewards = await database.rewardDao.getAllRewards();
      expect(rewards.length, 1);
      expect(rewards.first.title, 'First Completion');
      expect(rewards.first.pointsThreshold, 10);
    });

    test('updates reward when remote is earned but local is not', () async {
      await database.rewardDao.insertReward(
        RewardsCompanion.insert(
          title: 'First Completion',
          description: 'Complete your first item',
          pointsThreshold: 10,
          isRevealed: const Value(true),
          isEarned: const Value(false),
        ),
      );

      stubAllFetchesExceptRewards([
        {
          'title': 'First Completion',
          'description': 'Complete your first item',
          'points_threshold': 10,
          'is_revealed': true,
          'is_earned': true,
          'earned_at': '2026-02-09T12:00:00.000Z',
          'created_at': '2026-02-01T00:00:00.000Z',
          'updated_at': '2099-01-01T00:00:00.000Z',
        },
      ]);

      await syncEngine.pullOnLaunch();

      final rewards = await database.rewardDao.getAllRewards();
      expect(rewards.length, 1);
      expect(rewards.first.isEarned, true);
      expect(rewards.first.earnedAt, isNotNull);
    });

    test('skips rewards with missing required fields', () async {
      stubAllFetchesExceptRewards([
        {
          'description': 'No title or threshold',
          // Missing title, points_threshold, created_at
        },
      ]);

      await syncEngine.pullOnLaunch();

      final rewards = await database.rewardDao.getAllRewards();
      expect(rewards, isEmpty);
    });
  });

  group('SyncEngine push operations', () {
    test('pushCompletion calls Firestore when online', () async {
      when(() => mockFirestore.pushCompletion(any())).thenAnswer((_) async {});

      final data = {'curriculum_id': 'mishnayos', 'content_item_id': 'm-1'};
      await syncEngine.pushCompletion(data);

      verify(() => mockFirestore.pushCompletion(data)).called(1);
    });

    test('pushCompletion queues when offline', () async {
      when(() => mockOfflineQueue.getPendingCount()).thenAnswer((_) async => 1);
      syncEngine.setOnlineState(false);
      when(
        () => mockOfflineQueue.enqueueCompletion(any()),
      ).thenAnswer((_) async {});

      final data = {'curriculum_id': 'mishnayos', 'content_item_id': 'm-1'};
      await syncEngine.pushCompletion(data);

      verify(() => mockOfflineQueue.enqueueCompletion(data)).called(1);
      verifyNever(() => mockFirestore.pushCompletion(any()));
    });

    test('pushCompletion queues on Firestore error', () async {
      when(
        () => mockFirestore.pushCompletion(any()),
      ).thenThrow(Exception('Firebase error'));
      when(
        () => mockOfflineQueue.enqueueCompletion(any()),
      ).thenAnswer((_) async {});
      when(() => mockOfflineQueue.getPendingCount()).thenAnswer((_) async => 1);

      final data = {'curriculum_id': 'mishnayos', 'content_item_id': 'm-1'};
      await syncEngine.pushCompletion(data);

      verify(() => mockOfflineQueue.enqueueCompletion(data)).called(1);
    });

    test('pushBookmark calls Firestore when online', () async {
      when(() => mockFirestore.pushBookmark(any())).thenAnswer((_) async {});

      final data = {'curriculum_id': 'mishnayos', 'track_type': 'personal'};
      await syncEngine.pushBookmark(data);

      verify(() => mockFirestore.pushBookmark(data)).called(1);
    });

    test('pushBookmark queues when offline', () async {
      when(() => mockOfflineQueue.getPendingCount()).thenAnswer((_) async => 1);
      syncEngine.setOnlineState(false);
      when(
        () => mockOfflineQueue.enqueueBookmark(any()),
      ).thenAnswer((_) async {});

      final data = {'curriculum_id': 'mishnayos', 'track_type': 'personal'};
      await syncEngine.pushBookmark(data);

      verify(() => mockOfflineQueue.enqueueBookmark(data)).called(1);
    });

    test('pushSettings queues when offline', () async {
      when(() => mockOfflineQueue.getPendingCount()).thenAnswer((_) async => 1);
      syncEngine.setOnlineState(false);
      when(
        () => mockOfflineQueue.enqueueSettings(any()),
      ).thenAnswer((_) async {});

      final data = {'curriculum_id': 'mishnayos'};
      await syncEngine.pushSettings(data);

      verify(() => mockOfflineQueue.enqueueSettings(data)).called(1);
    });

    test('pushStreak queues when offline', () async {
      when(() => mockOfflineQueue.getPendingCount()).thenAnswer((_) async => 1);
      syncEngine.setOnlineState(false);
      when(
        () => mockOfflineQueue.enqueueStreak(any()),
      ).thenAnswer((_) async {});

      final data = {'current_count': 5};
      await syncEngine.pushStreak(data);

      verify(() => mockOfflineQueue.enqueueStreak(data)).called(1);
    });

    test('pushProfile queues when offline', () async {
      when(() => mockOfflineQueue.getPendingCount()).thenAnswer((_) async => 1);
      syncEngine.setOnlineState(false);
      when(
        () => mockOfflineQueue.enqueueProfile(any()),
      ).thenAnswer((_) async {});

      final data = {'firebase_uid': 'uid-123'};
      await syncEngine.pushProfile(data);

      verify(() => mockOfflineQueue.enqueueProfile(data)).called(1);
    });
  });

  group('SyncEngine listener lifecycle', () {
    void stubAllListeners() {
      when(
        () => mockFirestore.listenToCompletions(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToBookmarks(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToSettings(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToStreak(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToGoals(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToRewards(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockFirestore.listenToActiveCurricula(),
      ).thenAnswer((_) => const Stream.empty());
    }

    test('attachListeners skips when already attached', () async {
      stubAllListeners();

      await syncEngine.attachListeners();
      await syncEngine.attachListeners(); // second call is a no-op

      verify(() => mockFirestore.listenToCompletions()).called(1);
    });

    test('attachListeners skips when offline', () async {
      when(() => mockOfflineQueue.getPendingCount()).thenAnswer((_) async => 0);
      syncEngine.setOnlineState(false);
      await syncEngine.attachListeners();

      verifyNever(() => mockFirestore.listenToCompletions());
    });

    test('detachListeners cancels subscriptions', () async {
      stubAllListeners();

      await syncEngine.attachListeners();
      await syncEngine.detachListeners();

      // Should be able to attach again without error
      await syncEngine.attachListeners();
      verify(() => mockFirestore.listenToCompletions()).called(2);
    });

    test('detachListeners is a no-op when not attached', () async {
      // Should not throw
      await syncEngine.detachListeners();
    });
  });

  group('SyncEngine network state', () {
    test('setOnlineState ignores same state', () {
      // Default is online, setting online again should be no-op
      syncEngine.setOnlineState(true);
      // Just verify no crash
    });

    test('going offline sets offline status', () async {
      when(() => mockOfflineQueue.getPendingCount()).thenAnswer((_) async => 0);

      syncEngine.setOnlineState(false);

      // Give async ops time to complete
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final status = syncEngine.currentStatus;
      expect(
        status.maybeWhen(offline: (_) => true, orElse: () => false),
        isTrue,
      );
    });
  });
}
