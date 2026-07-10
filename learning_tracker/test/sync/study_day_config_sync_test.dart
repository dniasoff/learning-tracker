/// Phase 1 — study-day config enrolment in the sync pipeline.
///
/// Study days used to be local-only; reinstall lost them and a second device
/// never saw them. Phase 1 adds:
///   - `study_day_config` outbox kind (push path via the gateway + pipeline);
///   - `study_day_configs` Firestore subcollection listener;
///   - `StudyDayConfigMerger` (LWW on `updated_at`).
///
/// The tests below exercise the push round-trip (write → drain → gateway
/// received) and the merge round-trip (remote row → merger → Drift row).
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/study_day_config_merger.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/push_pipeline_impl.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';

import '../helpers/drift_memory.dart';

class _RecordingGateway implements FirestoreGateway {
  final List<Map<String, dynamic>> studyDayPushes = [];

  @override
  Future<void> pushStudyDayConfig({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    studyDayPushes.add(data);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late UserDatabase db;
  late DriftMergeStore store;
  late int profileId;
  late int trackId;

  setUp(() async {
    db = inMemoryDb();
    store = DriftMergeStore(db);
    await seedProfile(db);
    final profile = (await db.select(db.learnerProfiles).get()).first;
    profileId = profile.id;
    trackId = await seedTrack(
      db,
      profileId: profileId,
      curriculumId: 'mishnayos',
    );
  });

  tearDown(() async => db.close());

  group('study-day config — push', () {
    test(
      'writing a config locally + draining lands a push at the gateway',
      () async {
        final gateway = _RecordingGateway();
        final pipeline = OutboxPushPipeline(gateway: gateway);
        final processor = OutboxProcessor(
          outboxDao: db.outboxDao,
          pipeline: pipeline,
          clock: FakeLocalDayClock(DateTime.utc(2026, 5, 21)),
        );
        final facade = OutboxSyncWriteFacade(
          outboxDao: db.outboxDao,
          database: db,
          profileId: profileId,
          clock: FakeLocalDayClock(DateTime.utc(2026, 5, 21)),
        );

        // Local upsert.
        await db.studyDayConfigDao.upsertDayConfig(
          profileId: profileId,
          curriculumId: 'mishnayos',
          trackId: trackId,
          dayOfWeek: 6, // Shabbos
          dayType: 'review',
        );
        // Enqueue cloud sync via the facade.
        await facade.pushStudyDayConfig({
          'profile_id': profileId,
          'curriculum_id': 'mishnayos',
          'track_id': trackId,
          'day_of_week': 6,
          'day_type': 'review',
          'updated_at': '2026-05-21T10:00:00.000Z',
        });

        // The outbox should hold the row before drain.
        var pending = await db.outboxDao.getPendingByKind(
          OutboxEntityKind.studyDayConfig,
          profileId,
        );
        expect(pending, hasLength(1));
        expect(gateway.studyDayPushes, isEmpty);

        // Drain pushes the row to the gateway.
        await processor.drain(profileId);

        expect(gateway.studyDayPushes, hasLength(1));
        expect(gateway.studyDayPushes.single['day_of_week'], 6);
        expect(gateway.studyDayPushes.single['day_type'], 'review');
        pending = await db.outboxDao.getPendingByKind(
          OutboxEntityKind.studyDayConfig,
          profileId,
        );
        expect(pending, isEmpty);
      },
    );
  });

  group('study-day config — merge (pull)', () {
    test('a newer remote row overwrites the local one (LWW)', () async {
      // Local row: updated_at = 10:00.
      await db.studyDayConfigDao.upsertDayConfig(
        profileId: profileId,
        curriculumId: 'mishnayos',
        trackId: trackId,
        dayOfWeek: 6,
        dayType: 'study',
      );
      // Force the local updated_at to a fixed value (the DAO uses now()).
      await (db.update(db.studyDayConfigs)..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.curriculumId.equals('mishnayos') &
                t.dayOfWeek.equals(6) &
                t.trackId.equals(trackId),
          ))
          .write(
            StudyDayConfigsCompanion(
              updatedAt: Value(DateTime.utc(2026, 5, 21, 10)),
            ),
          );
      // Phase 3 (AUD-core-sync-03): the merger arbitrates LWW against the
      // SyncKv shadow persisted by DriftMergeStore, not the raw Drift row —
      // seed it to match the forced local updated_at above so this test
      // exercises the real "remote beats a known local" branch rather than
      // the "no local shadow yet" (first-sync) branch.
      await store.persistUpdatedAt(
        kind: EntityKind.studyDayConfig,
        profileId: profileId,
        naturalKey: 'mishnayos|6|$trackId',
        updatedAt: DateTime.utc(2026, 5, 21, 10),
      );

      // Remote row: updated_at = 11:00 with a different day_type.
      final merger = StudyDayConfigMerger(db, store: store);
      await merger.merge(
        profileId: profileId,
        rows: [
          {
            'profile_id': profileId,
            'curriculum_id': 'mishnayos',
            'track_id': trackId,
            'day_of_week': 6,
            'day_type': 'review',
            'updated_at': '2026-05-21T11:00:00.000Z',
          },
        ],
      );

      final localRow =
          await (db.select(db.studyDayConfigs)..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals('mishnayos') &
                    t.dayOfWeek.equals(6) &
                    t.trackId.equals(trackId),
              ))
              .getSingle();
      expect(
        localRow.dayType,
        'review',
        reason: 'newer remote overrides local',
      );
    });

    test('an older remote row is ignored (LWW)', () async {
      // Local row: updated_at = 12:00.
      await db.studyDayConfigDao.upsertDayConfig(
        profileId: profileId,
        curriculumId: 'mishnayos',
        trackId: trackId,
        dayOfWeek: 6,
        dayType: 'study',
      );
      await (db.update(db.studyDayConfigs)..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.curriculumId.equals('mishnayos') &
                t.dayOfWeek.equals(6) &
                t.trackId.equals(trackId),
          ))
          .write(
            StudyDayConfigsCompanion(
              updatedAt: Value(DateTime.utc(2026, 5, 21, 12)),
            ),
          );
      // Phase 3 (AUD-core-sync-03): seed the SyncKv shadow the merger now
      // arbitrates against (see the sibling test above).
      await store.persistUpdatedAt(
        kind: EntityKind.studyDayConfig,
        profileId: profileId,
        naturalKey: 'mishnayos|6|$trackId',
        updatedAt: DateTime.utc(2026, 5, 21, 12),
      );

      // Remote row: older than local.
      final merger = StudyDayConfigMerger(db, store: store);
      await merger.merge(
        profileId: profileId,
        rows: [
          {
            'profile_id': profileId,
            'curriculum_id': 'mishnayos',
            'track_id': trackId,
            'day_of_week': 6,
            'day_type': 'review',
            'updated_at': '2026-05-21T10:00:00.000Z',
          },
        ],
      );

      final localRow =
          await (db.select(db.studyDayConfigs)..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals('mishnayos') &
                    t.dayOfWeek.equals(6) &
                    t.trackId.equals(trackId),
              ))
              .getSingle();
      expect(
        localRow.dayType,
        'study',
        reason: 'older remote must not overwrite newer local',
      );
    });

    test('remote row without a local counterpart is inserted', () async {
      // No local row for dayOfWeek=4. Merger should insert it.
      final merger = StudyDayConfigMerger(db, store: store);
      await merger.merge(
        profileId: profileId,
        rows: [
          {
            'profile_id': profileId,
            'curriculum_id': 'mishnayos',
            'track_id': trackId,
            'day_of_week': 4,
            'day_type': 'review',
            'updated_at': '2026-05-21T10:00:00.000Z',
          },
        ],
      );

      final localRow =
          await (db.select(db.studyDayConfigs)..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals('mishnayos') &
                    t.dayOfWeek.equals(4) &
                    t.trackId.equals(trackId),
              ))
              .getSingleOrNull();
      expect(localRow, isNotNull);
      expect(localRow!.dayType, 'review');
    });

    test(
      'remote row whose track is absent locally is skipped (no FK throw)',
      () async {
        // trackId 999999 does not exist in curriculum_tracks. Inserting it
        // would throw a FK-constraint violation that fails the whole channel
        // merge; the merger must skip it instead.
        final merger = StudyDayConfigMerger(db, store: store);
        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'profile_id': profileId,
              'curriculum_id': 'mishnayos',
              'track_id': 999999,
              'day_of_week': 3,
              'day_type': 'review',
              'updated_at': '2026-05-21T10:00:00.000Z',
            },
          ],
        );

        final rows = await (db.select(
          db.studyDayConfigs,
        )..where((t) => t.trackId.equals(999999))).get();
        expect(rows, isEmpty, reason: 'row with missing track FK is skipped');
      },
    );

    test(
      'a valid row still merges when batched with a missing-track row',
      () async {
        final merger = StudyDayConfigMerger(db, store: store);
        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'profile_id': profileId,
              'curriculum_id': 'mishnayos',
              'track_id': 999999, // missing track — must be skipped
              'day_of_week': 3,
              'day_type': 'review',
              'updated_at': '2026-05-21T10:00:00.000Z',
            },
            {
              'profile_id': profileId,
              'curriculum_id': 'mishnayos',
              'track_id': trackId, // valid — must still merge
              'day_of_week': 5,
              'day_type': 'review',
              'updated_at': '2026-05-21T10:00:00.000Z',
            },
          ],
        );

        final valid = await (db.select(
          db.studyDayConfigs,
        )..where((t) => t.dayOfWeek.equals(5))).getSingleOrNull();
        expect(
          valid,
          isNotNull,
          reason: 'one bad row must not block the rest of the batch',
        );
      },
    );

    test(
      'Bug 3: remote row with a STALE remote track_id is remapped onto the '
      'local track (tutored mirror) so the schedule pattern is not lost',
      () async {
        // Mirror scenario: the parent device pushed the config with ITS track
        // id; the tutor mirror re-created the same logical track under a
        // different local autoincrement id. The merger must resolve the local
        // track by (profile, curriculum) and bind the config to it — otherwise
        // getConfigsByTrack(localTrackId) is empty and the scheduler projection
        // shows 0 due / "No projection" for the tutor.
        const staleRemoteTrackId = 555555;
        expect(staleRemoteTrackId, isNot(equals(trackId)));

        final merger = StudyDayConfigMerger(db, store: store);
        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'profile_id': profileId,
              'curriculum_id': 'mishnayos',
              'track_id': staleRemoteTrackId,
              'day_of_week': 2,
              'day_type': 'study',
              'updated_at': '2026-05-21T10:00:00.000Z',
            },
          ],
        );

        // Stored under the LOCAL track id, not the stale remote one.
        final byLocal = await db.studyDayConfigDao.getConfigsByTrack(trackId);
        expect(byLocal.any((c) => c.dayOfWeek == 2), isTrue);
        final byRemote = await (db.select(
          db.studyDayConfigs,
        )..where((t) => t.trackId.equals(staleRemoteTrackId))).get();
        expect(byRemote, isEmpty);
      },
    );

    test(
      'Bug 3 guard: with NO local track for the curriculum, the row is skipped '
      '(no FK throw)',
      () async {
        // A curriculum the mirror has no track for → cannot resolve a local
        // track → must skip rather than violate the FK.
        final merger = StudyDayConfigMerger(db, store: store);
        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'profile_id': profileId,
              'curriculum_id': 'tehillim', // no local track seeded
              'track_id': 42,
              'day_of_week': 1,
              'day_type': 'study',
              'updated_at': '2026-05-21T10:00:00.000Z',
            },
          ],
        );

        final rows = await (db.select(
          db.studyDayConfigs,
        )..where((t) => t.curriculumId.equals('tehillim'))).get();
        expect(rows, isEmpty);
      },
    );

    test('malformed remote row is silently skipped', () async {
      final merger = StudyDayConfigMerger(db, store: store);
      await merger.merge(
        profileId: profileId,
        rows: [
          {
            'profile_id': profileId,
            // missing curriculum_id
            'track_id': trackId,
            'day_of_week': 4,
            'day_type': 'review',
            'updated_at': '2026-05-21T10:00:00.000Z',
          },
        ],
      );

      final rows = await db.select(db.studyDayConfigs).get();
      expect(rows, isEmpty, reason: 'malformed row skipped, no insert');
    });
  });
}
