/// Story acceptance tests for Epic 24 -- Stop-the-Bleeding (Phase 0).
///
/// Story 24.7: Sync curriculum track activation to Firestore (DNI-310).
/// Story 24.8: Sync learning order to Firestore (DNI-311).
@Tags(['epic_24'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/network/connectivity_service.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/features/learning_order/data/repositories/learning_order_repository_impl.dart';
import 'package:learning_tracker/features/learning_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/sync/data/offline_queue.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';
import 'package:test/test.dart';

class MockFirestoreDataSource extends Mock implements FirestoreDataSource {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockSyncEngine extends Mock implements SyncEngine {}

class MockContentRepository extends Mock implements ContentRepository {}

/// Stubs every FirestoreDataSource method used by SyncEngine.pullOnLaunch.
void _stubPullOnLaunchEmpty(MockFirestoreDataSource mock) {
  const ps = FirestoreDataSource.defaultPageSize;
  when(() => mock.forProfile(any())).thenReturn(mock);
  when(() => mock.fetchCompletions(pageSize: ps)).thenAnswer((_) async => []);
  when(() => mock.fetchBookmarks(pageSize: ps)).thenAnswer((_) async => []);
  when(() => mock.fetchSettings(pageSize: ps)).thenAnswer((_) async => []);
  when(() => mock.fetchGoals(pageSize: ps)).thenAnswer((_) async => []);
  when(
    () => mock.fetchProfilePrograms(pageSize: ps),
  ).thenAnswer((_) async => []);
  when(() => mock.fetchStreak()).thenAnswer((_) async => null);
  when(() => mock.fetchProfile()).thenAnswer((_) async => null);
  when(() => mock.fetchLedgerEntries(pageSize: ps)).thenAnswer((_) async => []);
  when(
    () => mock.fetchCurriculumTracks(pageSize: ps),
  ).thenAnswer((_) async => []);
  when(() => mock.fetchLearnerProfiles()).thenAnswer((_) async => []);
  when(() => mock.fetchNotificationSettings()).thenAnswer((_) async => null);
  when(() => mock.fetchGamificationSettings()).thenAnswer((_) async => null);
  when(() => mock.fetchUiPreferences()).thenAnswer((_) async => null);
  when(() => mock.fetchLearningOrder(pageSize: ps)).thenAnswer((_) async => []);
}

UserDatabase _createDb() => UserDatabase(NativeDatabase.memory());

// ────────────────────────────────────────────────────────────────
// Story 24.7: Sync curriculum track activation to Firestore
// ────────────────────────────────────────────────────────────────

void main() {
  group(
    'Story 24.7 -- Sync curriculum track activation to Firestore',
    tags: ['story_24_7'],
    () {
      // ── Push-on-write tests (via TrackRepositoryImpl + mock SyncEngine) ──

      group('push-on-write', () {
        late UserDatabase db;
        late MockSyncEngine mockEngine;
        late TrackRepositoryImpl repo;

        setUp(() async {
          db = _createDb();
          mockEngine = MockSyncEngine();
          when(
            () => mockEngine.pushCurriculumTrack(any()),
          ).thenAnswer((_) async {});
          repo = TrackRepositoryImpl(
            database: db,
            syncEngine: mockEngine,
            activeProfileId: 0,
          );
        });

        tearDown(() => db.close());

        test('activateTrack pushes curriculum track to sync engine', () async {
          // Seed an existing track row so _resolveTrackRowForSync finds it.
          await db
              .into(db.curriculumTracks)
              .insert(
                CurriculumTracksCompanion.insert(
                  curriculumId: CurriculumId.mishnayos.storageKey,
                  trackType: TrackType.personal.storageKey,
                  activatedAt: DateTime.utc(2026, 1, 1),
                  isActive: const Value(false),
                ),
              );

          await repo.activateTrack(CurriculumId.mishnayos, TrackType.personal);

          verify(() => mockEngine.pushCurriculumTrack(any())).called(1);
        });

        test(
          'deactivateTrack is a no-op for personal track (guard preserved)',
          () async {
            // Personal track cannot be deactivated — expect exception.
            await repo.initializeDefaultTracks(CurriculumId.mishnayos);
            // reset call count from initializeDefaultTracks
            clearInteractions(mockEngine);

            await expectLater(
              () => repo.deactivateTrack(
                CurriculumId.mishnayos,
                TrackType.personal,
              ),
              throwsA(isA<InvalidTrackOperationException>()),
            );
            // push must NOT have been called because the deactivation was rejected
            verifyNever(() => mockEngine.pushCurriculumTrack(any()));
          },
        );

        test(
          'initializeDefaultTracks pushes personal track to sync engine',
          () async {
            await repo.initializeDefaultTracks(CurriculumId.mishnayos);

            verify(() => mockEngine.pushCurriculumTrack(any())).called(1);
          },
        );

        test('push payload contains required fields', () async {
          Map<String, dynamic>? capturedPayload;
          when(() => mockEngine.pushCurriculumTrack(any())).thenAnswer((inv) {
            capturedPayload =
                inv.positionalArguments[0] as Map<String, dynamic>;
            return Future<void>.value();
          });

          await repo.initializeDefaultTracks(CurriculumId.mishnayos);

          expect(capturedPayload, isNotNull);
          expect(capturedPayload!['curriculum_id'], isNotNull);
          expect(capturedPayload!['track_type'], isNotNull);
          expect(capturedPayload!['is_active'], isNotNull);
          expect(capturedPayload!['activated_at'], isNotNull);
        });

        test('no push when syncEngine is null (local-born user)', () async {
          final localRepo = TrackRepositoryImpl(database: db);
          // Should not throw and should not push anything.
          await localRepo.initializeDefaultTracks(CurriculumId.bavli);
          verifyNever(() => mockEngine.pushCurriculumTrack(any()));
        });
      });

      // ── Pull-on-launch tests (via SyncEngine + real OfflineQueue) ──

      group('pull-on-launch', () {
        late UserDatabase db;
        late MockFirestoreDataSource mockFirestore;
        late MockConnectivityService mockConnectivity;
        late OfflineQueue offlineQueue;
        late SyncEngine syncEngine;

        setUp(() async {
          db = _createDb();
          mockFirestore = MockFirestoreDataSource();
          mockConnectivity = MockConnectivityService();
          when(() => mockConnectivity.isOnline).thenAnswer((_) async => true);
          when(() => mockFirestore.isAuthenticated).thenReturn(true);
          when(() => mockFirestore.profileId).thenReturn(1);
          offlineQueue = OfflineQueue(
            database: db,
            firestoreDataSource: mockFirestore,
            logger: AppLogger(Talker()),
          );
          syncEngine = SyncEngine(
            database: db,
            firestoreDataSource: mockFirestore,
            offlineQueue: offlineQueue,
            logger: AppLogger(Talker()),
            connectivityService: mockConnectivity,
          );
        });

        tearDown(() async {
          await syncEngine.dispose();
          await db.close();
        });

        test('remote track absent locally is inserted on pull', () async {
          _stubPullOnLaunchEmpty(mockFirestore);
          when(
            () => mockFirestore.fetchCurriculumTracks(
              pageSize: FirestoreDataSource.defaultPageSize,
            ),
          ).thenAnswer(
            (_) async => [
              {
                'curriculum_id': CurriculumId.mishnayos.storageKey,
                'track_type': TrackType.personal.storageKey,
                'is_active': true,
                'activated_at': '2026-03-01T10:00:00.000Z',
              },
            ],
          );

          await syncEngine.pullOnLaunch();

          final tracks = await (db.select(
            db.curriculumTracks,
          )..where((t) => t.profileId.equals(1))).get();
          expect(tracks, hasLength(1));
          expect(tracks.first.curriculumId, CurriculumId.mishnayos.storageKey);
          expect(tracks.first.isActive, isTrue);
        });

        test('pull skips remote tracks with unknown curriculum_id', () async {
          _stubPullOnLaunchEmpty(mockFirestore);
          when(
            () => mockFirestore.fetchCurriculumTracks(
              pageSize: FirestoreDataSource.defaultPageSize,
            ),
          ).thenAnswer(
            (_) async => [
              {
                'curriculum_id': 'totally_unknown_curriculum',
                'track_type': TrackType.personal.storageKey,
                'is_active': true,
                'activated_at': '2026-03-01T10:00:00.000Z',
              },
            ],
          );

          await syncEngine.pullOnLaunch();

          final tracks = await db.select(db.curriculumTracks).get();
          expect(tracks, isEmpty);
        });
      });

      // ── Conflict resolution (LWW) tests ──

      group('LWW conflict resolution', () {
        late UserDatabase db;
        late MockFirestoreDataSource mockFirestore;
        late MockConnectivityService mockConnectivity;
        late OfflineQueue offlineQueue;
        late SyncEngine syncEngine;

        setUp(() {
          db = _createDb();
          mockFirestore = MockFirestoreDataSource();
          mockConnectivity = MockConnectivityService();
          when(() => mockConnectivity.isOnline).thenAnswer((_) async => true);
          when(() => mockFirestore.isAuthenticated).thenReturn(true);
          when(() => mockFirestore.profileId).thenReturn(1);
          offlineQueue = OfflineQueue(
            database: db,
            firestoreDataSource: mockFirestore,
            logger: AppLogger(Talker()),
          );
          syncEngine = SyncEngine(
            database: db,
            firestoreDataSource: mockFirestore,
            offlineQueue: offlineQueue,
            logger: AppLogger(Talker()),
            connectivityService: mockConnectivity,
          );
        });

        tearDown(() async {
          await syncEngine.dispose();
          await db.close();
        });

        Future<void> insertLocalTrack({
          required bool isActive,
          required DateTime activatedAt,
          DateTime? deactivatedAt,
        }) async {
          await db
              .into(db.curriculumTracks)
              .insert(
                CurriculumTracksCompanion.insert(
                  profileId: const Value(1),
                  curriculumId: CurriculumId.mishnayos.storageKey,
                  trackType: TrackType.personal.storageKey,
                  isActive: Value(isActive),
                  activatedAt: activatedAt,
                  deactivatedAt: Value(deactivatedAt),
                ),
              );
        }

        test(
          'remote wins when remote activatedAt is strictly newer than local',
          () async {
            // Local: deactivated at an older timestamp
            await insertLocalTrack(
              isActive: false,
              activatedAt: DateTime.utc(2026, 3, 1),
              deactivatedAt: DateTime.utc(2026, 3, 5),
            );

            _stubPullOnLaunchEmpty(mockFirestore);
            when(
              () => mockFirestore.fetchCurriculumTracks(
                pageSize: FirestoreDataSource.defaultPageSize,
              ),
            ).thenAnswer(
              (_) async => [
                {
                  'curriculum_id': CurriculumId.mishnayos.storageKey,
                  'track_type': TrackType.personal.storageKey,
                  'is_active': true,
                  // Remote was re-activated later — should win
                  'activated_at': '2026-03-10T00:00:00.000Z',
                },
              ],
            );

            await syncEngine.pullOnLaunch();

            final tracks = await (db.select(
              db.curriculumTracks,
            )..where((t) => t.profileId.equals(1))).get();
            expect(tracks, hasLength(1));
            expect(tracks.first.isActive, isTrue); // remote won
          },
        );

        test(
          'local wins when local deactivatedAt is strictly newer than remote activatedAt',
          () async {
            // Local was deactivated MORE RECENTLY than the remote was activated
            await insertLocalTrack(
              isActive: false,
              activatedAt: DateTime.utc(2026, 3, 1),
              deactivatedAt: DateTime.utc(2026, 3, 20), // very recent
            );

            _stubPullOnLaunchEmpty(mockFirestore);
            when(
              () => mockFirestore.fetchCurriculumTracks(
                pageSize: FirestoreDataSource.defaultPageSize,
              ),
            ).thenAnswer(
              (_) async => [
                {
                  'curriculum_id': CurriculumId.mishnayos.storageKey,
                  'track_type': TrackType.personal.storageKey,
                  'is_active': true,
                  // Remote is older — local should win
                  'activated_at': '2026-03-10T00:00:00.000Z',
                },
              ],
            );

            await syncEngine.pullOnLaunch();

            final tracks = await (db.select(
              db.curriculumTracks,
            )..where((t) => t.profileId.equals(1))).get();
            expect(tracks, hasLength(1));
            expect(tracks.first.isActive, isFalse); // local kept
          },
        );

        test(
          'local wins on tie (equal timestamps) — flapping prevention',
          () async {
            final ts = DateTime.utc(2026, 3, 10);
            // Local: deactivated at the same moment as remote activated
            await insertLocalTrack(
              isActive: false,
              activatedAt: DateTime.utc(2026, 3, 1),
              deactivatedAt: ts,
            );

            _stubPullOnLaunchEmpty(mockFirestore);
            when(
              () => mockFirestore.fetchCurriculumTracks(
                pageSize: FirestoreDataSource.defaultPageSize,
              ),
            ).thenAnswer(
              (_) async => [
                {
                  'curriculum_id': CurriculumId.mishnayos.storageKey,
                  'track_type': TrackType.personal.storageKey,
                  'is_active': true,
                  'activated_at': ts.toIso8601String(),
                },
              ],
            );

            await syncEngine.pullOnLaunch();

            final tracks = await (db.select(
              db.curriculumTracks,
            )..where((t) => t.profileId.equals(1))).get();
            expect(tracks, hasLength(1));
            expect(tracks.first.isActive, isFalse); // local kept (tie → local)
          },
        );

        test(
          'remote deactivation wins when remote deactivatedAt is newer',
          () async {
            // Local: currently active
            await insertLocalTrack(
              isActive: true,
              activatedAt: DateTime.utc(2026, 3, 1),
            );

            _stubPullOnLaunchEmpty(mockFirestore);
            when(
              () => mockFirestore.fetchCurriculumTracks(
                pageSize: FirestoreDataSource.defaultPageSize,
              ),
            ).thenAnswer(
              (_) async => [
                {
                  'curriculum_id': CurriculumId.mishnayos.storageKey,
                  'track_type': TrackType.personal.storageKey,
                  'is_active': false,
                  'activated_at': '2026-03-01T00:00:00.000Z',
                  // Remote deactivated after local activation — should win
                  'deactivated_at': '2026-03-15T00:00:00.000Z',
                },
              ],
            );

            await syncEngine.pullOnLaunch();

            final tracks = await (db.select(
              db.curriculumTracks,
            )..where((t) => t.profileId.equals(1))).get();
            expect(tracks, hasLength(1));
            expect(tracks.first.isActive, isFalse); // remote deactivation won
          },
        );
      });
    },
  );

  // ────────────────────────────────────────────────────────────────
  // Story 24.8 (DNI-311): Sync learning order to Firestore
  // ────────────────────────────────────────────────────────────────

  group(
    'Story 24.8 (DNI-311) -- Sync learning order to Firestore',
    tags: ['story_24_8'],
    () {
      // ── Push-on-write tests ───────────────────────────────────────────────

      group('push-on-write', () {
        late UserDatabase db;
        late MockSyncEngine mockEngine;
        late LearningOrderRepositoryImpl repo;

        setUp(() {
          db = _createDb();
          mockEngine = MockSyncEngine();
          when(
            () => mockEngine.pushLearningOrder(
              profileId: any(named: 'profileId'),
              curriculumId: any(named: 'curriculumId'),
              items: any(named: 'items'),
              updatedAt: any(named: 'updatedAt'),
            ),
          ).thenAnswer((_) async {});
          repo = LearningOrderRepositoryImpl(
            database: db,
            contentRepository: MockContentRepository(),
            syncEngine: mockEngine,
            profileId: 1,
          );
        });

        tearDown(() => db.close());

        test('saveOrder calls pushLearningOrder on syncEngine', () async {
          final items = [
            const LearningOrderItem(
              sefariaRef: 'Mishnah Berakhot 1',
              displayNameHe: 'ברכות א',
              displayNameEn: 'Berakhot 1',
              userSortOrder: 0,
              isCustomOrdered: true,
            ),
            const LearningOrderItem(
              sefariaRef: 'Mishnah Berakhot 2',
              displayNameHe: 'ברכות ב',
              displayNameEn: 'Berakhot 2',
              userSortOrder: 1,
              isCustomOrdered: true,
            ),
          ];

          await repo.saveOrder(CurriculumId.mishnayos, items);

          verify(
            () => mockEngine.pushLearningOrder(
              profileId: 1,
              curriculumId: CurriculumId.mishnayos.storageKey,
              items: any(named: 'items'),
              updatedAt: any(named: 'updatedAt'),
            ),
          ).called(1);
        });

        test('no push when syncEngine is null (local-born user)', () async {
          final localRepo = LearningOrderRepositoryImpl(
            database: db,
            contentRepository: MockContentRepository(),
          );
          // Should complete without error and not call engine.
          await localRepo.saveOrder(CurriculumId.mishnayos, []);
          verifyNever(
            () => mockEngine.pushLearningOrder(
              profileId: any(named: 'profileId'),
              curriculumId: any(named: 'curriculumId'),
              items: any(named: 'items'),
              updatedAt: any(named: 'updatedAt'),
            ),
          );
        });

        test(
          'resetToDefault calls pushLearningOrder with empty items',
          () async {
            await repo.resetToDefault(CurriculumId.mishnayos);

            final captured = verify(
              () => mockEngine.pushLearningOrder(
                profileId: 1,
                curriculumId: CurriculumId.mishnayos.storageKey,
                items: captureAny(named: 'items'),
                updatedAt: any(named: 'updatedAt'),
              ),
            ).captured;
            expect(captured.first as List, isEmpty);
          },
        );
      });

      // ── Pull-on-launch tests ──────────────────────────────────────────────

      group('pull-on-launch', () {
        late UserDatabase db;
        late MockFirestoreDataSource mockFirestore;
        late MockConnectivityService mockConnectivity;
        late OfflineQueue offlineQueue;
        late SyncEngine syncEngine;

        setUp(() {
          db = _createDb();
          mockFirestore = MockFirestoreDataSource();
          mockConnectivity = MockConnectivityService();
          when(() => mockConnectivity.isOnline).thenAnswer((_) async => true);
          when(() => mockFirestore.isAuthenticated).thenReturn(true);
          when(() => mockFirestore.profileId).thenReturn(0);
          offlineQueue = OfflineQueue(
            database: db,
            firestoreDataSource: mockFirestore,
            logger: AppLogger(Talker()),
          );
          syncEngine = SyncEngine(
            database: db,
            firestoreDataSource: mockFirestore,
            offlineQueue: offlineQueue,
            logger: AppLogger(Talker()),
            connectivityService: mockConnectivity,
          );
        });

        tearDown(() async {
          await syncEngine.dispose();
          await db.close();
        });

        test(
          'remote learning-order item absent locally is inserted on pull',
          () async {
            _stubPullOnLaunchEmpty(mockFirestore);
            const ps = FirestoreDataSource.defaultPageSize;
            when(
              () => mockFirestore.fetchLearningOrder(pageSize: ps),
            ).thenAnswer(
              (_) async => [
                {
                  'curriculum_id': CurriculumId.mishnayos.storageKey,
                  'sefaria_ref': 'Mishnah Berakhot 1',
                  'user_sort_order': 0,
                  'updated_at': '2026-05-01T10:00:00.000Z',
                },
              ],
            );

            await syncEngine.pullOnLaunch();

            final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
              CurriculumId.mishnayos.storageKey,
            );
            expect(rows, hasLength(1));
            expect(rows.first.sefariaRef, equals('Mishnah Berakhot 1'));
            expect(rows.first.userSortOrder, equals(0));
          },
        );
      });

      // ── LWW conflict resolution tests ────────────────────────────────────

      group('LWW conflict resolution', () {
        late UserDatabase db;
        late MockFirestoreDataSource mockFirestore;
        late MockConnectivityService mockConnectivity;
        late OfflineQueue offlineQueue;
        late SyncEngine syncEngine;

        setUp(() {
          db = _createDb();
          mockFirestore = MockFirestoreDataSource();
          mockConnectivity = MockConnectivityService();
          when(() => mockConnectivity.isOnline).thenAnswer((_) async => true);
          when(() => mockFirestore.isAuthenticated).thenReturn(true);
          when(() => mockFirestore.profileId).thenReturn(0);
          offlineQueue = OfflineQueue(
            database: db,
            firestoreDataSource: mockFirestore,
            logger: AppLogger(Talker()),
          );
          syncEngine = SyncEngine(
            database: db,
            firestoreDataSource: mockFirestore,
            offlineQueue: offlineQueue,
            logger: AppLogger(Talker()),
            connectivityService: mockConnectivity,
          );
        });

        tearDown(() async {
          await syncEngine.dispose();
          await db.close();
        });

        test('remote item newer than local wins (LWW)', () async {
          // Seed a local row with an older timestamp.
          final olderTime = DateTime.utc(2026, 4, 1);
          await db.learningOrderDao.upsertLearningOrder(
            LearningOrderCompanion(
              profileId: const Value(0),
              curriculumId: Value(CurriculumId.mishnayos.storageKey),
              sefariaRef: const Value('Mishnah Berakhot 1'),
              userSortOrder: const Value(5),
              updatedAt: Value(olderTime),
            ),
          );

          _stubPullOnLaunchEmpty(mockFirestore);
          const ps = FirestoreDataSource.defaultPageSize;
          when(() => mockFirestore.fetchLearningOrder(pageSize: ps)).thenAnswer(
            (_) async => [
              {
                'curriculum_id': CurriculumId.mishnayos.storageKey,
                'sefaria_ref': 'Mishnah Berakhot 1',
                'user_sort_order': 99,
                // Remote is newer — should win
                'updated_at': '2026-05-10T12:00:00.000Z',
              },
            ],
          );

          await syncEngine.pullOnLaunch();

          final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
            CurriculumId.mishnayos.storageKey,
          );
          expect(rows.first.userSortOrder, equals(99));
        });

        test('remote item older than local is skipped (LWW)', () async {
          // Seed a local row with a newer timestamp.
          final newerTime = DateTime.utc(2026, 5, 13);
          await db.learningOrderDao.upsertLearningOrder(
            LearningOrderCompanion(
              profileId: const Value(0),
              curriculumId: Value(CurriculumId.mishnayos.storageKey),
              sefariaRef: const Value('Mishnah Berakhot 1'),
              userSortOrder: const Value(42),
              updatedAt: Value(newerTime),
            ),
          );

          _stubPullOnLaunchEmpty(mockFirestore);
          const ps = FirestoreDataSource.defaultPageSize;
          when(() => mockFirestore.fetchLearningOrder(pageSize: ps)).thenAnswer(
            (_) async => [
              {
                'curriculum_id': CurriculumId.mishnayos.storageKey,
                'sefaria_ref': 'Mishnah Berakhot 1',
                'user_sort_order': 0,
                // Remote is older — local should win
                'updated_at': '2026-04-01T00:00:00.000Z',
              },
            ],
          );

          await syncEngine.pullOnLaunch();

          final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
            CurriculumId.mishnayos.storageKey,
          );
          expect(rows.first.userSortOrder, equals(42)); // local preserved
        });
      });
    },
  );
}
