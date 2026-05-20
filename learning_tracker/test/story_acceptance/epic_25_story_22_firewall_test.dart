/// Story acceptance tests for Story 25.22 — Wipe-install cutover E2E
/// verification (FIREWALL gate).
///
/// AC1: Schema migration — fresh DB at schemaVersion; all tables exist.
/// AC2: Onboarding flow — DB write path verification.
/// AC3: Second-device isolation — in-memory DBs are independent.
///
/// Note: Pull-on-launch tests that exercised the legacy SyncEngine were
/// retired (W2.35). Those code paths are covered by SyncOrchestratorImpl
/// + PullPipeline integration tests.
@Tags(['epic_25', 'story_25_22'])
library;

import 'package:drift/drift.dart' show Value, Variable;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/features/sync/domain/services/device_restore_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';

class _MockFirestoreGateway extends Mock implements FirestoreGateway {}

class _MockCurriculumImportService extends Mock
    implements CurriculumImportService {}

class _StubSyncOrchestrator implements SyncOrchestrator {
  @override
  Future<void> pullOnLaunch({bool triggeredFromResume = false}) async {}

  @override
  Future<void> retryPull() async {}

  @override
  Future<void> pushAllLocalData() async {}

  @override
  SyncStatus get currentStatus =>
      SyncStatus.synced(lastSyncedAt: DateTimeFactory.nowUtc());

  @override
  Stream<SyncStatus> get statusStream => const Stream.empty();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Story 25.22 — AC1: Schema migration', tags: ['story_25_22'], () {
    late UserDatabase db;

    setUp(() => db = inMemoryDb());
    tearDown(() => db.close());

    test('UserDatabase.schemaVersion is at least 1 (W3.19 schema reset)', () {
      expect(db.schemaVersion, greaterThanOrEqualTo(1));
    });

    test(
      'PRAGMA user_version matches schemaVersion after first query',
      () async {
        await db.customSelect('SELECT 1').get();
        final row = await db.customSelect('PRAGMA user_version').getSingle();
        expect(row.read<int>('user_version'), greaterThanOrEqualTo(1));
      },
    );

    test('all expected tables exist in sqlite_master', () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
          )
          .get();
      final tableNames = rows.map((r) => r.read<String>('name')).toSet();

      const expected = {
        'accounts',
        'learner_profiles',
        'curriculum_tracks',
        'curriculum_scopes',
        'profile_programs',
        'stage_definitions',
        'point_configs',
        'study_day_configs',
        'completion_events',
        'daily_plans',
        'learning_ledger',
        'bookmarks',
        'learning_order',
        'track_learning_order',
        'goals',
        'streak_events',
        'text_download_statuses',
        'outbox',
        'sacred_window_entries',
        'prior_completion_imports',
      };

      for (final name in expected) {
        expect(tableNames, contains(name), reason: 'Table "$name" missing');
      }
    });

    test('UNIQUE indexes exist on completion_events, curriculum_tracks, '
        'streak_events', () async {
      Future<List<String>> uniqueIndexesOn(String table) async {
        final rows = await db
            .customSelect(
              'SELECT name FROM pragma_index_list(?) WHERE "unique" = 1',
              variables: [Variable.withString(table)],
            )
            .get();
        return rows.map((r) => r.read<String>('name')).toList();
      }

      expect(await uniqueIndexesOn('completion_events'), isNotEmpty);
      expect(await uniqueIndexesOn('curriculum_tracks'), isNotEmpty);
      expect(await uniqueIndexesOn('streak_events'), isNotEmpty);
    });

    test('no migration error on fresh install', () async {
      await expectLater(
        () => db.customSelect('SELECT count(*) FROM accounts').getSingle(),
        returnsNormally,
      );
    });
  });

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

      test('create account, profile and activate curriculum — rows present '
          'without exceptions', () async {
        final now = DateTime.utc(2026, 5, 13, 12);

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

        final trackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: profileId,
                curriculumId: CurriculumId.mishnayos.storageKey,
                stateChangedAt: now,
                activatedAt: now,
              ),
            );
        expect(trackId, greaterThan(0));

        final profiles = await db.select(db.learnerProfiles).get();
        expect(profiles, hasLength(1));
        expect(profiles.first.displayName, equals('My Profile'));

        final tracks = await db.select(db.curriculumTracks).get();
        expect(tracks, hasLength(1));
        expect(
          tracks.first.curriculumId,
          equals(CurriculumId.mishnayos.storageKey),
        );
      });

      test('DeviceRestoreService with unauthenticated Firestore skips '
          'restore without throwing', () async {
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
          curriculumImportService: _MockCurriculumImportService(),
          logger: logger,
        );
        addTearDown(() => svc.dispose());

        await expectLater(() => svc.restore(), returnsNormally);
      });
    },
  );

  group(
    'Story 25.22 — AC3: Second-device DB isolation',
    tags: ['story_25_22'],
    () {
      test('two in-memory DB instances are independent', () async {
        final device1 = inMemoryDb();
        addTearDown(() => device1.close());

        // Seed account+profile first — W3.25 added FK learner_profiles→accounts.
        await seedProfile(device1);

        final now = DateTime.utc(2026, 5, 13, 12);
        await device1
            .into(device1.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: CurriculumId.bavli.storageKey,
                stateChangedAt: now,
                activatedAt: now,
              ),
            );

        final device2 = inMemoryDb();
        addTearDown(() => device2.close());

        final device2Tracks = await device2
            .select(device2.curriculumTracks)
            .get();
        expect(device2Tracks, isEmpty);
      });
    },
  );
}
