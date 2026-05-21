/// Acceptance test for Plan §F Phase 4 deliverable 1.
///
/// `DeviceRestoreService.restore` previously called
/// `pullOnLaunch` (which pulls `curriculum_tracks` among many other
/// collections) AND then issued a separate `fetchAll('curriculum_tracks')`
/// just to compute the active-curricula set. That was a wasted Firestore
/// read on every restore.
///
/// Post-fix: the active set is derived from the local `TrackDao` after the
/// merge, so the gateway sees ZERO direct `fetchAll('curriculum_tracks')`
/// calls coming from the restore path. (The gateway still services the
/// pull pipeline's per-collection fetches via the orchestrator — but those
/// happen INSIDE the stub `pullOnLaunch`, which is a no-op in this test.)
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/restore/device_restore_service.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

import '../../helpers/drift_memory.dart';

class _MockCurriculumImportService extends Mock
    implements CurriculumImportService {}

/// Sync orchestrator stub. Plan §F Phase 4 deliverable 1 ensures the
/// restore service derives active curricula from local Drift state, not by
/// re-fetching from Firestore — so this stub doesn't need a gateway at all.
class _StubSyncOrchestrator implements SyncOrchestrator {
  int pullCount = 0;

  @override
  Future<void> pullOnLaunch({bool triggeredFromResume = false}) async {
    pullCount++;
  }

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

  group('Plan §F Phase 4 deliverable 1 — DeviceRestoreService double-read', () {
    test(
      'restore() pulls once via pullOnLaunch and reads active curricula '
      'from the local Drift db, never re-issuing fetchAll(curriculum_tracks)',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);
        // Seed a track row locally — mirrors what pullOnLaunch would have
        // merged after pulling `curriculum_tracks` from Firestore.
        await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: CurriculumId.mishnayos.storageKey,
                stateChangedAt: DateTimeFactory.nowUtc(),
                activatedAt: DateTimeFactory.nowUtc(),
                state: const Value('active'),
              ),
            );

        final orchestrator = _StubSyncOrchestrator();
        final importSvc = _MockCurriculumImportService();
        when(
          () => importSvc.importAll(any()),
        ).thenAnswer((_) => const Stream.empty());

        final svc = DeviceRestoreService(
          database: db,
          syncOrchestrator: orchestrator,
          profileId: 1,
          isAuthenticated: true,
          curriculumImportService: importSvc,
          logger: AppLogger(Talker()),
        );
        addTearDown(svc.dispose);

        final result = await svc.restore();

        expect(result, isTrue);
        // Pull is invoked exactly once — there is no second pull or
        // companion fetchAll call for curriculum_tracks anywhere in
        // restore().
        expect(orchestrator.pullCount, 1);

        // The import path saw the locally-derived active curriculum.
        final captured = verify(
          () => importSvc.importAll(captureAny()),
        ).captured.single;
        expect(
          captured,
          isA<List<CurriculumId>>().having(
            (l) => l.map((c) => c.storageKey).toSet(),
            'storageKeys',
            equals({CurriculumId.mishnayos.storageKey}),
          ),
        );
      },
    );

    test('restore() with an empty local DB performs zero importAll calls — '
        'derivation is local, no fallback to Firestore re-read', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);
      // No track rows seeded — pullOnLaunch returned nothing, so the
      // restore path should NOT invent curricula by re-fetching from
      // Firestore. Local derivation just produces an empty active set.

      final orchestrator = _StubSyncOrchestrator();
      final importSvc = _MockCurriculumImportService();

      final svc = DeviceRestoreService(
        database: db,
        syncOrchestrator: orchestrator,
        profileId: 1,
        isAuthenticated: true,
        curriculumImportService: importSvc,
        logger: AppLogger(Talker()),
      );
      addTearDown(svc.dispose);

      final result = await svc.restore();

      expect(result, isTrue);
      expect(orchestrator.pullCount, 1);
      verifyNever(() => importSvc.importAll(any()));
    });
  });
}
