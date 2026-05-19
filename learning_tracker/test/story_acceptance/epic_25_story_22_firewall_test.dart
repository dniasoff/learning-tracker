/// Story acceptance tests for Story 25.22 — Wipe-install cutover E2E
/// verification (FIREWALL gate).
///
/// DNI-343: Verifies that a fresh wipe-install onboarding completes
/// end-to-end without errors and that a second device can restore the
/// same data via the sync/restore path.
///
/// AC1: Schema migration — fresh DB initialises at schemaVersion 15;
///      all 22 Drift-registered tables exist; all UNIQUE indexes exist.
/// AC2: Onboarding flow — create account → create profile →
///      activate curriculum → writes land in local DB.
/// AC3: Second-device restore — given Firestore docs, the sync engine
///      writes the same profile and track_config to a second local DB.
/// AC4: `make ci` passes (enforced externally; AC1-AC3 green is the gate).
@Tags(['epic_25', 'story_25_22'])
library;

import 'package:drift/drift.dart' show Value, Variable;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/connectivity_service.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:learning_tracker/features/sync/data/offline_queue.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/features/sync/domain/services/device_restore_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';

// ── mocks ─────────────────────────────────────────────────────────────────────

class _MockFirestoreDataSource extends Mock implements FirestoreDataSource {}

class _MockFirestoreGateway extends Mock implements FirestoreGateway {}

class _MockConnectivityService extends Mock implements ConnectivityService {}

class _MockCurriculumImportService extends Mock
    implements CurriculumImportService {}

// ── stub orchestrator ─────────────────────────────────────────────────────────

/// Minimal [SyncOrchestrator] stub for tests that construct
/// [DeviceRestoreService] but do not exercise the pull path.
class _StubSyncOrchestrator implements SyncOrchestrator {
  @override
  Future<void> pullOnLaunch({bool triggeredFromResume = false}) async {}

  @override
  Future<void> pushAllLocalData() async {}

  @override
  SyncStatus get currentStatus =>
      SyncStatus.synced(lastSyncedAt: DateTimeFactory.nowUtc());

  @override
  Stream<SyncStatus> get statusStream => const Stream.empty();
}

// ── helpers ───────────────────────────────────────────────────────────────────

/// Stubs every FirestoreDataSource method used by SyncEngine.pullOnLaunch
/// to return empty collections (no remote data).
void _stubFirestoreEmpty(_MockFirestoreDataSource mock) {
  const ps = FirestoreDataSource.defaultPageSize;
  when(() => mock.isAuthenticated).thenReturn(true);
  when(() => mock.profileId).thenReturn(1);
  when(() => mock.forProfile(any())).thenReturn(mock);
  when(() => mock.fetchLearnerProfiles()).thenAnswer((_) async => []);
  when(() => mock.fetchProfile()).thenAnswer((_) async => null);
  when(() => mock.fetchCompletions(pageSize: ps)).thenAnswer((_) async => []);
  when(() => mock.fetchBookmarks(pageSize: ps)).thenAnswer((_) async => []);
  when(() => mock.fetchSettings(pageSize: ps)).thenAnswer((_) async => []);
  when(() => mock.fetchGoals(pageSize: ps)).thenAnswer((_) async => []);
  when(
    () => mock.fetchProfilePrograms(pageSize: ps),
  ).thenAnswer((_) async => []);
  when(() => mock.fetchStreak()).thenAnswer((_) async => null);
  when(() => mock.fetchLedgerEntries(pageSize: ps)).thenAnswer((_) async => []);
  when(
    () => mock.fetchCurriculumTracks(pageSize: ps),
  ).thenAnswer((_) async => []);
  when(() => mock.fetchCurriculumTracks()).thenAnswer((_) async => []);
  when(() => mock.fetchNotificationSettings()).thenAnswer((_) async => null);
  when(() => mock.fetchGamificationSettings()).thenAnswer((_) async => null);
  when(() => mock.fetchUiPreferences()).thenAnswer((_) async => null);
  when(() => mock.fetchLearningOrder(pageSize: ps)).thenAnswer((_) async => []);
}

/// Creates a SyncEngine wired to the given database and Firestore mock.
SyncEngine _makeSyncEngine(
  UserDatabase db,
  _MockFirestoreDataSource fsMock,
  AppLogger logger,
) {
  final connectivity = _MockConnectivityService();
  when(() => connectivity.isOnline).thenAnswer((_) async => true);

  // OfflineQueue now requires a FirestoreGateway; use a minimal stub since
  // the queue path is not exercised by the tests in this file.
  final gatewayStub = _MockFirestoreGateway();

  final queue = OfflineQueue(
    database: db,
    firestoreGateway: gatewayStub,
    logger: logger,
  );
  return SyncEngine(
    database: db,
    firestoreDataSource: fsMock,
    offlineQueue: queue,
    logger: logger,
    connectivityService: connectivity,
  );
}

// ── tests ─────────────────────────────────────────────────────────────────────

void main() {
  // SharedPreferences must be mocked for the DeviceRestoreService and
  // SyncEngine code paths that touch it.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // --------------------------------------------------------------------------
  // AC1 — Schema migration: fresh DB at schemaVersion 22, all tables exist,
  //        all UNIQUE indexes exist, no migration error thrown.
  // --------------------------------------------------------------------------

  group('Story 25.22 — AC1: Schema migration', tags: ['story_25_22'], () {
    late UserDatabase db;

    setUp(() => db = inMemoryDb());
    tearDown(() => db.close());

    test('UserDatabase.schemaVersion is 22', () {
      // schemaVersion is a Dart constant — no I/O needed.
      expect(db.schemaVersion, equals(22));
    });

    test(
      'PRAGMA user_version matches schemaVersion 22 after first query',
      () async {
        // Trigger schema materialisation by issuing any query.
        await db.customSelect('SELECT 1').get();

        final row = await db.customSelect('PRAGMA user_version').getSingle();
        expect(row.read<int>('user_version'), equals(22));
      },
    );

    test('all 22 Drift-registered tables exist in sqlite_master', () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
          )
          .get();
      final tableNames = rows.map((r) => r.read<String>('name')).toSet();

      // The 22 tables registered in @DriftDatabase(tables: [...]).
      const expected = {
        'accounts',
        'learner_profiles',
        'curriculum_tracks',
        'curriculum_scopes',
        'profile_programs',
        'stage_definitions',
        'point_configs',
        'study_day_configs',
        'completions',
        'completion_events',
        'daily_plans',
        'learning_ledger',
        'bookmarks',
        'learning_order',
        'track_learning_order',
        'goals',
        'streaks',
        'streak_events',
        'sync_queue',
        'text_download_statuses',
        'outbox',
        'sacred_window_entries',
      };

      for (final name in expected) {
        expect(
          tableNames,
          contains(name),
          reason: 'Table "$name" missing from schema v14',
        );
      }
    });

    test('UNIQUE indexes exist on completion_events, curriculum_tracks, '
        'streak_events (DNI-323 append-only / dedup contracts)', () async {
      Future<List<String>> uniqueIndexesOn(String table) async {
        final rows = await db
            .customSelect(
              'SELECT name FROM pragma_index_list(?) WHERE "unique" = 1',
              variables: [Variable.withString(table)],
            )
            .get();
        return rows.map((r) => r.read<String>('name')).toList();
      }

      // completion_events must have its UNIQUE natural-key constraint.
      final ceIndexes = await uniqueIndexesOn('completion_events');
      expect(
        ceIndexes,
        isNotEmpty,
        reason:
            'completion_events must have at least one UNIQUE index '
            '(DNI-323 append-only event table)',
      );

      // curriculum_tracks: UNIQUE(profileId, curriculumId, trackType).
      final ctIndexes = await uniqueIndexesOn('curriculum_tracks');
      expect(
        ctIndexes,
        isNotEmpty,
        reason:
            'curriculum_tracks must have its UNIQUE composite index '
            '(profileId, curriculumId, trackType)',
      );

      // streak_events: UNIQUE natural-key (DNI-323).
      final seIndexes = await uniqueIndexesOn('streak_events');
      expect(
        seIndexes,
        isNotEmpty,
        reason:
            'streak_events must have at least one UNIQUE index '
            '(DNI-323 dedup contract)',
      );
    });

    test(
      'no migration error is thrown on fresh install (onCreate only)',
      () async {
        // The MigrationStrategy uses only onCreate with createAll().
        // Simply running a query confirms no error was raised.
        await expectLater(
          () => db.customSelect('SELECT count(*) FROM accounts').getSingle(),
          returnsNormally,
        );
      },
    );
  });

  // --------------------------------------------------------------------------
  // AC2 — Onboarding flow: create account → create profile → activate
  //        curriculum → writes land in local DB without exceptions.
  // --------------------------------------------------------------------------

  group(
    'Story 25.22 — AC2: Onboarding flow integration',
    tags: ['story_25_22'],
    () {
      late UserDatabase db;
      late AppLogger logger;

      setUp(() {
        db = inMemoryDb();
        logger = AppLogger(Talker());
      });

      tearDown(() => db.close());

      test('create account, profile and activate curriculum — all rows present '
          'in local DB without exceptions', () async {
        final now = DateTime.utc(2026, 5, 13, 12);

        // Step 1: Create account (cloud-born, simulating post-Firebase-auth).
        final accountId = await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                email: 'new-user@example.com',
                firebaseUid: const Value('uid_firewall_001'),
                tier: 'cloudBorn',
                displayName: 'New User',
                userMode: 'adult',
                createdAt: now,
                updatedAt: now,
              ),
            );
        expect(accountId, greaterThan(0));

        // Step 2: Create learner profile.
        final profileId = await db
            .into(db.learnerProfiles)
            .insert(
              LearnerProfilesCompanion.insert(
                accountId: accountId,
                displayName: 'My Profile',
                mode: 'adult',
                createdAt: now,
                updatedAt: now,
              ),
            );
        expect(profileId, greaterThan(0));

        // Step 3: Activate a curriculum (create track_config row).
        final trackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: profileId,
                curriculumId: CurriculumId.mishnayos.storageKey,
                trackType: 'personal',
                activatedAt: now,
              ),
            );
        expect(trackId, greaterThan(0));

        // Assert local DB state matches AC2 shape.
        final profiles = await db.select(db.learnerProfiles).get();
        expect(
          profiles,
          hasLength(1),
          reason: 'local DB must have exactly 1 learner_profiles row',
        );
        expect(profiles.first.displayName, equals('My Profile'));

        final tracks = await db.select(db.curriculumTracks).get();
        expect(
          tracks,
          hasLength(1),
          reason: 'local DB must have exactly 1 curriculum_tracks row',
        );
        expect(
          tracks.first.curriculumId,
          equals(CurriculumId.mishnayos.storageKey),
        );
        expect(tracks.first.profileId, equals(profileId));
      });

      test('SyncEngine.pullOnLaunch on empty Firestore does not throw '
          'and leaves DB in a clean state', () async {
        final fsMock = _MockFirestoreDataSource();
        _stubFirestoreEmpty(fsMock);

        final engine = _makeSyncEngine(db, fsMock, logger);
        addTearDown(() => engine.dispose());

        // pullOnLaunch must complete cleanly even with no remote data.
        await expectLater(() => engine.pullOnLaunch(), returnsNormally);

        // DB should have no rows written (all collections were empty).
        final profiles = await db.select(db.learnerProfiles).get();
        expect(
          profiles,
          isEmpty,
          reason: 'no profiles should be written when Firestore is empty',
        );
      });

      test('DeviceRestoreService with unauthenticated Firestore skips restore '
          'without throwing', () async {
        final importService = _MockCurriculumImportService();

        // Use a minimal gateway stub — DeviceRestoreService.restore() calls
        // fetchAll() for curriculum_tracks after pullOnLaunch, but with an
        // unauthenticated, empty-DB scenario the service skips to
        // isNewDevice() → true (empty profiles) and then calls pullOnLaunch
        // on the stub orchestrator (no-op) before fetching tracks.
        final gatewayStub = _MockFirestoreGateway();
        when(
          () => gatewayStub.fetchAll(
            profileId: any(named: 'profileId'),
            collection: any(named: 'collection'),
          ),
        ).thenAnswer((_) async => []);

        final svc = DeviceRestoreService(
          database: db,
          syncOrchestrator: _StubSyncOrchestrator(),
          firestoreGateway: gatewayStub,
          profileId: 1,
          isAuthenticated: false,
          curriculumImportService: importService,
          logger: logger,
        );
        addTearDown(() => svc.dispose());

        // isNewDevice: no completions + not authenticated => no session.
        // The service should either skip or complete without error.
        await expectLater(() => svc.restore(), returnsNormally);
      });
    },
  );

  // --------------------------------------------------------------------------
  // AC3 — Second-device restore: given Firestore docs, the sync engine
  //        writes the same profile and track row to a fresh local DB.
  // --------------------------------------------------------------------------

  group('Story 25.22 — AC3: Second-device restore', tags: ['story_25_22'], () {
    late UserDatabase db;
    late AppLogger logger;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
      logger = AppLogger(Talker());
    });

    tearDown(() => db.close());

    test('pullOnLaunch with Firestore learner_profile doc creates matching '
        'local learner_profiles row', () async {
      final fsMock = _MockFirestoreDataSource();
      _stubFirestoreEmpty(fsMock);

      // Override fetchLearnerProfiles to return one profile doc.
      const remoteProfileId = 42;
      final profileTs = DateTime.utc(2026, 5, 1);
      when(() => fsMock.fetchLearnerProfiles()).thenAnswer(
        (_) async => [
          {
            'id': remoteProfileId,
            'account_id': 1,
            'display_name': 'Restored Profile',
            'mode': 'adult',
            'avatar_index': 0,
            'created_at': profileTs,
            'updated_at': profileTs,
          },
        ],
      );

      final engine = _makeSyncEngine(db, fsMock, logger);
      addTearDown(() => engine.dispose());

      await engine.pullOnLaunch();

      // Verify the restored profile row exists with the correct id.
      final profiles = await db.select(db.learnerProfiles).get();
      expect(
        profiles.any((p) => p.id == remoteProfileId),
        isTrue,
        reason:
            'second device must have the same profileId ($remoteProfileId) '
            'after pullOnLaunch restores the Firestore doc',
      );
      final profile = profiles.firstWhere((p) => p.id == remoteProfileId);
      expect(profile.displayName, equals('Restored Profile'));
    });

    test('pullOnLaunch with Firestore curriculum_tracks doc creates matching '
        'local curriculum_tracks row on second device', () async {
      const remoteProfileId = 42;
      const remoteCurriculumId = 'mishnayos';
      const remoteTrackType = 'personal';
      final activatedAt = DateTime.utc(2026, 5, 1);

      final fsMock = _MockFirestoreDataSource();
      _stubFirestoreEmpty(fsMock);

      // Return the profile so the sync engine resolves a profileId.
      when(() => fsMock.fetchLearnerProfiles()).thenAnswer(
        (_) async => [
          {
            'id': remoteProfileId,
            'account_id': 1,
            'display_name': 'Restored Profile',
            'mode': 'adult',
            'avatar_index': 0,
            // Use DateTime directly — _parseTimestamp handles DateTime,
            // String, and Firestore Timestamp but NOT raw int millis.
            'created_at': activatedAt,
            'updated_at': activatedAt,
          },
        ],
      );

      // Return one curriculum track for the profile's sub-tree pull.
      const ps = FirestoreDataSource.defaultPageSize;
      when(() => fsMock.fetchCurriculumTracks(pageSize: ps)).thenAnswer(
        (_) async => [
          {
            'curriculum_id': remoteCurriculumId,
            'track_type': remoteTrackType,
            'is_active': true,
            // Use DateTime directly — _parseTimestamp handles DateTime but
            // NOT raw int millisecondsSinceEpoch.
            'activated_at': activatedAt,
          },
        ],
      );

      final engine = _makeSyncEngine(db, fsMock, logger);
      addTearDown(() => engine.dispose());

      await engine.pullOnLaunch();

      // Verify the curriculum_tracks row is present on "second device".
      final tracks = await db.select(db.curriculumTracks).get();
      expect(
        tracks.any(
          (t) =>
              t.profileId == remoteProfileId &&
              t.curriculumId == remoteCurriculumId &&
              t.trackType == remoteTrackType,
        ),
        isTrue,
        reason:
            'second device must have the restored curriculum_tracks row '
            '(profileId=$remoteProfileId, curriculumId=$remoteCurriculumId)',
      );
    });

    test(
      'two in-memory DB instances are independent — second device starts clean',
      () async {
        // Device 1 has data; device 2 (second inMemoryDb()) must be empty.
        final device1 = inMemoryDb();
        addTearDown(() => device1.close());

        final now = DateTime.utc(2026, 5, 13, 12);
        await device1
            .into(device1.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: CurriculumId.bavli.storageKey,
                trackType: 'personal',
                activatedAt: now,
              ),
            );

        final device2 = inMemoryDb();
        addTearDown(() => device2.close());

        final device2Tracks = await device2
            .select(device2.curriculumTracks)
            .get();
        expect(
          device2Tracks,
          isEmpty,
          reason:
              'second in-memory DB must be a completely fresh install '
              '(no data leakage from device 1)',
        );
      },
    );
  });
}
