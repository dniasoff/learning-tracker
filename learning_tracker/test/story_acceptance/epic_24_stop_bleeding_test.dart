/// Story acceptance tests for Epic 24 -- Stop-the-Bleeding (Phase 0).
///
/// Story 24.7: Sync curriculum track activation to Firestore.
/// Linear ID: DNI-310
@Tags(['epic_24'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/network/connectivity_service.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:learning_tracker/features/sync/data/offline_queue.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';
import 'package:test/test.dart';

class MockFirestoreDataSource extends Mock implements FirestoreDataSource {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockSyncEngine extends Mock implements SyncEngine {}

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
            logger: Talker(),
          );
          syncEngine = SyncEngine(
            database: db,
            firestoreDataSource: mockFirestore,
            offlineQueue: offlineQueue,
            logger: Talker(),
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
            logger: Talker(),
          );
          syncEngine = SyncEngine(
            database: db,
            firestoreDataSource: mockFirestore,
            offlineQueue: offlineQueue,
            logger: Talker(),
            connectivityService: mockConnectivity,
          );
        });

        tearDown(() async {
          await syncEngine.dispose();
          await db.close();
        });

        Future<void> _insertLocalTrack({
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
            await _insertLocalTrack(
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
            await _insertLocalTrack(
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
            await _insertLocalTrack(
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
            await _insertLocalTrack(
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
}
