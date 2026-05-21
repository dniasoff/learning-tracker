/// Story acceptance tests for Epic 13 -- Cloud Sync.
///
/// NOTE (W2.35): The original tests in this file exercised the legacy
/// SyncEngine, OfflineQueue, and FirestoreDataSource classes — all deleted
/// in Wave 2 (W2.35-W2.37). Tests are skip-wrapped; underlying behaviour
/// is covered by:
/// - Push-on-write (13.1): test/sync/sync_rework_writepath_test.dart
/// - Pull-on-launch (13.2): test/sync/two_device_sync_test.dart
/// - Conflict resolution (13.3): EntityMerger unit tests
/// - Device restore (13.4): ported below using _StubSyncOrchestrator pattern
///   (V3-W4 port — unit-level contract tests; DB integration tests belong in
///    test/integration/firestore_wipe_install_test.dart)
@Tags(['epic_13'])
library;

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/features/sync/domain/services/device_restore_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Shared fakes (same pattern as epic_25_story_22_firewall_test.dart)
// ---------------------------------------------------------------------------

class _MockCurriculumImportService extends Mock
    implements CurriculumImportService {}

class _StubSyncOrchestrator implements SyncOrchestrator {
  _StubSyncOrchestrator({SyncStatus? status}) {
    if (status != null) _status = status;
  }

  SyncStatus _status = SyncStatus.synced(
    lastSyncedAt: DateTimeFactory.nowUtc(),
  );

  void setStatus(SyncStatus s) => _status = s;

  @override
  Future<void> pullOnLaunch({bool triggeredFromResume = false}) async {}

  @override
  Future<void> retryPull() async {}

  @override
  Future<void> pushAllLocalData() async {}

  @override
  SyncStatus get currentStatus => _status;

  @override
  Stream<SyncStatus> get statusStream => const Stream.empty();
}

// ---------------------------------------------------------------------------
// Helper to create a DeviceRestoreService with a real in-memory DB
// ---------------------------------------------------------------------------

DeviceRestoreService _makeService(
  UserDatabase db, {
  SyncOrchestrator? orchestrator,
  CurriculumImportService? importService,
  bool isAuthenticated = true,
  int profileId = 1,
}) {
  final mockImport = importService ?? _MockCurriculumImportService();
  if (mockImport is _MockCurriculumImportService) {
    when(
      () => mockImport.importAll(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockImport.importSingle(any())).thenAnswer(
      (_) async => const CurriculumImportResult(
        curriculumId: CurriculumId.mishnayos,
        success: true,
      ),
    );
  }

  return DeviceRestoreService(
    database: db,
    syncOrchestrator: orchestrator ?? _StubSyncOrchestrator(),
    profileId: profileId,
    isAuthenticated: isAuthenticated,
    curriculumImportService: mockImport,
    logger: AppLogger(Talker()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  group(
    'Story 13.1 -- Push-on-Write with Offline Queuing',
    tags: ['story_13_1'],
    skip: 'Retired W2.35 — covered by outbox processor tests',
    () {
      test('placeholder', () {});
    },
  );

  group(
    'Story 13.2 -- Pull-on-Launch Merge',
    tags: ['story_13_2'],
    skip:
        'Retired W2.35 — covered by SyncOrchestratorImpl + PullPipeline tests',
    () {
      test('placeholder', () {});
    },
  );

  group(
    'Story 13.3 -- Conflict resolution (LWW)',
    tags: ['story_13_3'],
    skip: 'Retired W2.35 — covered by EntityMerger unit tests',
    () {
      test('placeholder', () {});
    },
  );

  group('Story 13.4 -- New Device Data Restore', tags: ['story_13_4'], () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // ── AC1: RestoreStatus state machine is complete ────────────────────────

    test('13.4-AC1: RestoreStatus sealed class covers all expected states', () {
      // Verify all status types compile and match their sealed class variants.
      const idle = RestoreStatus.idle();
      const checking = RestoreStatus.checking();
      const restoring = RestoreStatus.restoring(
        phase: 'Loading...',
        completedSteps: 1,
        totalSteps: 3,
      );
      const complete = RestoreStatus.complete(collectionsRestored: 3);
      const error = RestoreStatus.error(message: 'network error');

      expect(idle, isA<RestoreStatusIdle>());
      expect(checking, isA<RestoreStatusChecking>());
      expect(restoring, isA<RestoreStatusRestoring>());
      expect(complete, isA<RestoreStatusComplete>());
      expect(error, isA<RestoreStatusError>());
    });

    // ── AC2: isNewDevice returns true for authenticated + empty DB ──────────

    test(
      '13.4-AC2: isNewDevice returns true for authenticated user with no completions',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);

        final svc = _makeService(db, isAuthenticated: true);
        addTearDown(svc.dispose);

        // Empty DB + authenticated = new device.
        expect(await svc.isNewDevice(), isTrue);
      },
    );

    // ── AC3: isNewDevice returns false for unauthenticated user ────────────

    test(
      '13.4-AC3: isNewDevice returns false for unauthenticated user with empty DB',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);

        final svc = _makeService(db, isAuthenticated: false);
        addTearDown(svc.dispose);

        // Unauthenticated even with empty DB → not a cloud restore scenario.
        expect(await svc.isNewDevice(), isFalse);
      },
    );

    // ── AC4: isNewDevice returns true when in_progress marker is set ────────

    test(
      '13.4-AC4: isNewDevice returns true when restore marker is in_progress',
      () async {
        SharedPreferences.setMockInitialValues({
          DeviceRestoreService.restoreStatePrefKey: 'in_progress',
        });

        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        final svc = _makeService(db, isAuthenticated: false);
        addTearDown(svc.dispose);

        // in_progress marker overrides everything — partial restore must retry.
        expect(await svc.isNewDevice(), isTrue);
      },
    );

    // ── AC5: restore(bypassNewDeviceCheck: false) skips when not new device ──

    test(
      '13.4-AC5: restore returns false and emits idle when not a new device',
      () async {
        SharedPreferences.setMockInitialValues({
          DeviceRestoreService.restoreStatePrefKey: 'complete',
        });

        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        final svc = _makeService(db, isAuthenticated: true);
        addTearDown(svc.dispose);

        // complete marker → already restored; should skip.
        final result = await svc.restore();

        expect(result, isFalse);
        expect(svc.currentStatus, isA<RestoreStatusIdle>());
      },
    );

    // ── AC6: successful restore emits complete status ──────────────────────

    test(
      '13.4-AC6: restore returns true and emits complete after successful pull',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        // Empty DB + authenticated = new device → restore will run.
        // Seed an active curriculum row locally so the post-restore derivation
        // (step 2 in DeviceRestoreService) picks it up the same way
        // pullOnLaunch would have populated it.
        await seedProfile(db);
        await seedTrack(db, profileId: 1, curriculumId: 'mishnayos');

        final statusLog = <RestoreStatus>[];

        final importSvc = _MockCurriculumImportService();
        when(() => importSvc.importAll(any())).thenAnswer((_) async* {
          yield const CurriculumImportProgress(
            current: 1,
            total: 1,
            currentCurriculum: CurriculumId.mishnayos,
            results: [
              CurriculumImportResult(
                curriculumId: CurriculumId.mishnayos,
                success: true,
              ),
            ],
          );
        });
        when(() => importSvc.importSingle(any())).thenAnswer(
          (_) async => const CurriculumImportResult(
            curriculumId: CurriculumId.mishnayos,
            success: true,
          ),
        );

        final svc = DeviceRestoreService(
          database: db,
          syncOrchestrator: _StubSyncOrchestrator(),
          profileId: 1,
          isAuthenticated: true,
          curriculumImportService: importSvc,
          logger: AppLogger(Talker()),
        );
        addTearDown(svc.dispose);
        svc.statusStream.listen(statusLog.add);

        final result = await svc.restore();

        expect(result, isTrue);
        expect(svc.currentStatus, isA<RestoreStatusComplete>());
      },
    );

    // ── AC7: failed pull leaves error status and logs ──────────────────────

    test(
      '13.4-AC7: restore returns false and emits error when pullOnLaunch fails',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);

        final orchestrator = _StubSyncOrchestrator(
          status: SyncStatus.error(
            message: 'Firestore unreachable',
            failedAt: DateTime.utc(2026, 5, 20),
          ),
        );

        final svc = _makeService(db, orchestrator: orchestrator);
        addTearDown(svc.dispose);

        final result = await svc.restore();

        // pullOnLaunch succeeded (stub does nothing) but currentStatus is Error,
        // so restore detects the failure and returns false.
        expect(result, isFalse);
        expect(svc.currentStatus, isA<RestoreStatusError>());
      },
    );

    // ── AC8: retry() delegates to restore(bypassNewDeviceCheck: true) ──────

    test(
      '13.4-AC8: retry() runs restore even when DB already has data',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db); // DB has data → isNewDevice would return false

        final importSvc = _MockCurriculumImportService();
        when(
          () => importSvc.importAll(any()),
        ).thenAnswer((_) => const Stream.empty());
        when(() => importSvc.importSingle(any())).thenAnswer(
          (_) async => const CurriculumImportResult(
            curriculumId: CurriculumId.mishnayos,
            success: true,
          ),
        );

        final svc = DeviceRestoreService(
          database: db,
          syncOrchestrator: _StubSyncOrchestrator(),
          profileId: 1,
          isAuthenticated: true,
          curriculumImportService: importSvc,
          logger: AppLogger(Talker()),
        );
        addTearDown(svc.dispose);

        // retry() bypasses the new-device check → should still attempt restore.
        final result = await svc.retry();

        expect(result, isTrue, reason: 'retry() must bypass isNewDevice check');
        expect(svc.currentStatus, isA<RestoreStatusComplete>());
      },
    );
  });
}
