/// Invariant test net — 2026-05-17 quality crisis.
///
/// Six characterization/invariant tests (N1–N6) documenting the correct system
/// behaviour. Most are expected to FAIL when first written; each becomes the
/// regression anchor for the corresponding repair step:
///
///   N1 → R2  offline-queue drains to 0 after an online flush
///   N2 → R1  exactly one SyncOrchestrator instance per session
///   N3 → —   fresh profile reports 0 completions and 0 streak (baseline)
///   N4 → R3  delete+re-add track → completion %, count both 0
///   N5 → R4  restoreOrCreate preserves original activatedAt for overdue
///   N6 → R5  completion count and progress % share one "done" definition
///
/// Rule: a failing test is fixed by changing production code only — never by
/// weakening the assertion. Each repair ships as one commit: failing test +
/// fix + green test.
@Tags(['invariants'])
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/daily_plan_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/sync/data/offline_queue.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';

void main() {
  group('Invariant net — 2026-05-17 quality crisis', tags: ['invariants'], () {
    // ── N1 — offline-queue drains to 0 ─────────────────────────────────────

    group('N1: offline-queue drains to 0 after online flush', () {
      test(
        'OfflineQueue.flush() removes all successfully-pushed items',
        () async {
          final db = inMemoryDb();
          addTearDown(db.close);

          // Seed three heterogeneous operations.
          await db.syncQueueDao.enqueue(
            'completion',
            '{"profile_id":1,"sefariaRef":"Berakhot 1:1"}',
          );
          await db.syncQueueDao.enqueue(
            'completion',
            '{"profile_id":1,"sefariaRef":"Berakhot 1:2"}',
          );
          await db.syncQueueDao.enqueue('settings', '{"profile_id":1}');

          expect(await db.syncQueueDao.getPendingCount(), 3);

          final talker = AppLogger.init();
          final queue = OfflineQueue(
            database: db,
            firestoreGateway: _AlwaysOkGateway(),
            logger: AppLogger(talker),
          );

          final synced = await queue.flush();

          expect(
            synced,
            3,
            reason: 'N1: flush must report 3 successful pushes',
          );
          expect(
            await db.syncQueueDao.getPendingCount(),
            0,
            reason:
                'N1: after a successful online flush the queue must be empty',
          );
        },
      );
    });

    // ── N2 — single SyncOrchestrator per session ────────────────────────────

    group('N2: exactly one SyncOrchestrator instance per session', () {
      test(
        'syncOrchestratorProvider does not watch activeProfileIdProvider',
        () {
          // The provider currently rebuilds whenever activeProfileIdProvider
          // changes, which creates a second SyncOrchestratorImpl (and registers
          // a second LifecycleObserver) before the first is disposed.
          //
          // The fix (R1): either keep the provider alive via ref.keepAlive()
          // while removing the activeProfileIdProvider watch, or promote the
          // provider to keepAlive: true. Either way the source must not contain
          // a watch call on activeProfileIdProvider.
          final srcPath =
              'lib/core/sync/providers/sync_orchestrator_providers.dart';
          final file = File(srcPath);
          if (!file.existsSync()) {
            fail('N2: provider source not found at $srcPath');
          }
          final source = file.readAsStringSync();

          expect(
            source,
            isNot(contains('activeProfileIdProvider')),
            reason:
                'N2: syncOrchestratorProvider must not watch '
                'activeProfileIdProvider — a profile change must not tear down '
                'and recreate the SyncOrchestrator, which would register a '
                'duplicate LifecycleObserver with WidgetsBinding',
          );
        },
      );
    });

    // ── N3 — fresh profile = 0 everything ──────────────────────────────────

    group('N3: fresh profile reports 0 completions and 0 streak', () {
      test('getAggregateCountByProfile returns 0 for a profile with no data', () async {
        final db = inMemoryDb();
        addTearDown(db.close);

        final count = await db.completionDao.getAggregateCountByProfile(
          'mishnayos',
          1,
        );
        expect(
          count,
          0,
          reason: 'N3: a profile that has never marked a completion must '
              'report 0 completions',
        );
      });

      test('streaks table has no row for a fresh profile', () async {
        final db = inMemoryDb();
        addTearDown(db.close);

        final row = await (db.select(db.streaks)
              ..where((t) => t.profileId.equals(1)))
            .getSingleOrNull();

        expect(
          row,
          isNull,
          reason:
              'N3: no streak row should exist for a profile that has never '
              'completed anything — the achievement card must not manufacture '
              'a non-zero "Personal Best" from a missing row',
        );
      });
    });

    // ── N4 — delete+re-add track = 0 phantom progress ──────────────────────

    group('N4: delete+re-add track leaves 0 completions', () {
      test(
        'restoreOrCreate after deleteTrackAndData: no old completions visible',
        () async {
          final db = inMemoryDb();
          addTearDown(db.close);

          // Create a track for profile 1.
          final originalId = await db.trackDao.restoreOrCreate(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos,
            trackType: TrackType.personal,
          );

          // Directly insert 3 completions attached to that track.
          for (var i = 0; i < 3; i++) {
            await db.into(db.completions).insert(
              CompletionsCompanion.insert(
                profileId: 1,
                curriculumId: CurriculumId.mishnayos.storageKey,
                sefariaRef: 'Berakhot 1:${i + 1}',
                stageId: 1,
                trackType: TrackType.personal.storageKey,
                trackId: originalId,
                completedAt: DateTime.utc(2026, 5, 1),
              ),
            );
          }

          expect(
            await db.completionDao.getAggregateCountByProfile('mishnayos', 1),
            3,
          );

          // Delete the track (soft-delete; completions are intentionally kept).
          await db.trackDao.deleteTrackAndData(originalId);

          // Re-add the same curriculum — restoreOrCreate reuses the old row ID.
          final restoredId = await db.trackDao.restoreOrCreate(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos,
            trackType: TrackType.personal,
          );

          expect(
            restoredId,
            equals(originalId),
            reason:
                'N4 pre-condition: restoreOrCreate must reuse the same row '
                'id — this is the mechanism behind the phantom progress',
          );

          // After a fresh re-add, the user expects 0 prior completions.
          // FAILS today: old completions still join to the restored track.
          expect(
            await db.completionDao.getAggregateCountByProfile('mishnayos', 1),
            0,
            reason:
                'N4: after delete+re-add, no prior completions must be '
                'visible — the re-added track is a fresh start',
          );
        },
      );
    });

    // ── N5 — restoreOrCreate preserves activatedAt ──────────────────────────

    group('N5: restoreOrCreate preserves original activatedAt', () {
      test(
        'restored track retains pre-delete activatedAt so backfill can compute overdue',
        () async {
          final db = inMemoryDb();
          addTearDown(db.close);

          final originalActivatedAt = DateTimeFactory.nowUtc().subtract(
            const Duration(days: 5),
          );

          // Insert a track with an activatedAt 5 days in the past.
          final trackId = await db.into(db.curriculumTracks).insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: CurriculumId.mishnayos.storageKey,
              trackType: TrackType.personal.storageKey,
              isActive: const Value(true),
              activatedAt: originalActivatedAt,
            ),
          );

          // Soft-delete the track.
          await db.trackDao.deleteTrackAndData(trackId);

          // Re-add via restoreOrCreate.
          await db.trackDao.restoreOrCreate(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos,
            trackType: TrackType.personal,
          );

          final restored = await db.trackDao.getTrackById(trackId);

          // FAILS today: restoreOrCreate writes activatedAt = DateTimeFactory.nowUtc()
          // which discards the original value and causes backfillMissingSnapshots
          // to see 0 elapsed days → no prior-day rows → no overdue tasks.
          expect(
            restored!.activatedAt.isBefore(
              DateTimeFactory.nowUtc().subtract(const Duration(days: 4)),
            ),
            isTrue,
            reason:
                'N5: restoreOrCreate must preserve the original activatedAt '
                'so that backfillMissingSnapshots can generate prior-day '
                'snapshots and surface overdue tasks on app open',
          );
        },
      );
    });

    // ── N6 — completion count and progress % share one "done" definition ────

    group('N6: completion count and lifetime % agree on one definition of done', () {
      test(
        'getAggregateCountByProfile counts distinct completed refs, not total rows',
        () async {
          final db = inMemoryDb();
          addTearDown(db.close);

          // Seed a track so the FK constraint resolves.
          final trackId = await db.into(db.curriculumTracks).insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: CurriculumId.mishnayos.storageKey,
              trackType: TrackType.personal.storageKey,
              isActive: const Value(true),
              activatedAt: DateTimeFactory.nowUtc(),
            ),
          );

          // Insert the same sefariaRef at two different stages.
          // By the "distinct refs" definition, 1 ref is done — not 2.
          await db.into(db.completions).insert(
            CompletionsCompanion.insert(
              profileId: 1,
              curriculumId: CurriculumId.mishnayos.storageKey,
              sefariaRef: 'Berakhot 1:1',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              trackId: trackId,
              completedAt: DateTime.utc(2026, 5, 1),
            ),
          );
          await db.into(db.completions).insert(
            CompletionsCompanion.insert(
              profileId: 1,
              curriculumId: CurriculumId.mishnayos.storageKey,
              sefariaRef: 'Berakhot 1:1',
              stageId: 2,
              trackType: TrackType.personal.storageKey,
              trackId: trackId,
              completedAt: DateTime.utc(2026, 5, 2),
            ),
          );

          final rawCount = await db.completionDao.getAggregateCountByProfile(
            'mishnayos',
            1,
          );

          // FAILS today: rawCount = 2 (all rows), but the distinct-refs numerator
          // used by computeCompletionPercentage returns 1.
          // Both metrics must share the same "done" unit so the UI stays consistent.
          expect(
            rawCount,
            1,
            reason:
                'N6: getAggregateCountByProfile must count distinct completed '
                'sefariaRefs (1), not total completion rows (2); otherwise '
                'the completion count and lifetime-% disagree on what "done" '
                'means',
          );
        },
      );
    });
  });
}

// ── Test doubles ─────────────────────────────────────────────────────────────

/// Stub [FirestoreGateway] that silently accepts every push operation.
/// Used by N1 to let OfflineQueue.flush() succeed without a real Firestore.
class _AlwaysOkGateway implements FirestoreGateway {
  @override
  Future<void> pushCompletion({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushStreak({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushTrack({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushBookmark({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushNotificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushGamificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushLearnerProfile({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> deleteLearnerProfile(int profileId) async {}

  @override
  Future<void> pushLedgerEntry({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushLedgerEntriesBatch({
    required int profileId,
    required List<Map<String, dynamic>> entries,
  }) async {}

  @override
  Future<void> pushProfileProgram({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> removeProfileProgramAssignment({
    required int profileId,
    required String curriculumStorageKey,
  }) async {}

  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async => const FirestorePage(rows: []);

  @override
  Future<List<Map<String, dynamic>>> fetchAll({
    required int profileId,
    required String collection,
  }) async => const [];

  @override
  Future<void> pushGoal({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushUiPreferences({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushAccountProfile({required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushCurriculumImportMetadata({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> deleteUserData(String uid) async {}

  @override
  Future<void> pushDiagnosticLog({
    required String uid,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushAccountUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Stream<List<Map<String, dynamic>>> listenToCollection({
    required int profileId,
    required String collection,
  }) => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();

  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async => const [];

  @override
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) async => null;
}
