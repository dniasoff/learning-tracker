/// Regression test for R5-1 — bookmark outbox entity key must include
/// track_type so two bookmarks for the same curriculum but different track
/// types produce DIFFERENT entity keys that mirror the Firestore doc-id
/// shape `${curriculumId}_${trackType}`.
///
/// Prior to the fix, `_key()` only appended `track_id` (absent in bookmark
/// payloads) and stopped at `curriculum_id`, so both
/// `bereshit_personal` and `bereshit_teacher` collapsed to the same key
/// `bereshit`, causing the outbox processor to de-duplicate them and lose
/// one on sync.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';

import '../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late int profileId;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    final profile = (await db.select(db.learnerProfiles).get()).first;
    profileId = profile.id;
  });

  tearDown(() async => db.close());

  group('R5-1 — bookmark outbox entity key includes track_type', () {
    test('two bookmarks with same curriculum_id but different track_type '
        'produce distinct entity keys', () async {
      final facade = OutboxSyncWriteFacade(
        outboxDao: db.outboxDao,
        database: db,
        profileId: profileId,
        clock: FakeLocalDayClock(DateTime.utc(2026, 5, 31)),
      );

      // Push two bookmarks: same curriculum, different track_type.
      // This mirrors BookmarkEntity.toFirestore() output.
      await facade.pushBookmark({
        'curriculum_id': 'bereshit',
        'track_type': 'personal',
        'content_item_id': 'Genesis 1:1',
        'updated_at': '2026-05-31T10:00:00.000Z',
      });
      await facade.pushBookmark({
        'curriculum_id': 'bereshit',
        'track_type': 'teacher',
        'content_item_id': 'Genesis 2:1',
        'updated_at': '2026-05-31T10:05:00.000Z',
      });

      final rows = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.bookmark,
        profileId,
      );

      // Both rows must survive — the de-duplication must NOT collapse them.
      expect(
        rows,
        hasLength(2),
        reason:
            'two bookmarks with different track_type must occupy '
            'separate outbox rows',
      );

      final keys = rows.map((r) => r.entityKey).toList();

      // Keys must be distinct.
      expect(
        keys.toSet(),
        hasLength(2),
        reason: 'entity keys must differ when track_type differs',
      );

      // Each key must match the Firestore doc-id shape
      // `${curriculumId}_${trackType}`.
      expect(keys, containsAll(['bereshit_personal', 'bereshit_teacher']));
    });

    test(
      'two bookmarks with same curriculum_id AND same track_type '
      'both get enqueued with the same entity key (same logical document)',
      () async {
        final facade = OutboxSyncWriteFacade(
          outboxDao: db.outboxDao,
          database: db,
          profileId: profileId,
          clock: FakeLocalDayClock(DateTime.utc(2026, 5, 31)),
        );

        // Push the same logical bookmark twice (position update).
        await facade.pushBookmark({
          'curriculum_id': 'bereshit',
          'track_type': 'personal',
          'content_item_id': 'Genesis 1:1',
          'updated_at': '2026-05-31T10:00:00.000Z',
        });
        await facade.pushBookmark({
          'curriculum_id': 'bereshit',
          'track_type': 'personal',
          'content_item_id': 'Genesis 1:5',
          'updated_at': '2026-05-31T10:10:00.000Z',
        });

        final rows = await db.outboxDao.getPendingByKind(
          OutboxEntityKind.bookmark,
          profileId,
        );

        // Both rows are in the outbox (the outbox table has no UNIQUE
        // constraint — de-dup happens at drain time in OutboxProcessor,
        // which uses set+merge so the later write wins in Firestore).
        expect(rows, hasLength(2));

        // Both rows carry the same entity key (correct — they represent
        // the same Firestore document).
        expect(rows.map((r) => r.entityKey).toSet(), {'bereshit_personal'});

        // Keys match the Firestore doc-id shape.
        for (final row in rows) {
          expect(row.entityKey, 'bereshit_personal');
        }
      },
    );

    test('entity key shape matches Firestore gateway doc-id '
        '(curriculumId_trackType)', () async {
      final facade = OutboxSyncWriteFacade(
        outboxDao: db.outboxDao,
        database: db,
        profileId: profileId,
        clock: FakeLocalDayClock(DateTime.utc(2026, 5, 31)),
      );

      await facade.pushBookmark({
        'curriculum_id': 'mishnayos',
        'track_type': 'standard',
        'content_item_id': 'Berakhot 1:1',
        'updated_at': '2026-05-31T09:00:00.000Z',
      });

      final rows = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.bookmark,
        profileId,
      );

      expect(rows, hasLength(1));
      expect(
        rows.single.entityKey,
        'mishnayos_standard',
        reason:
            'entity key must mirror the Firestore doc-id '
            'curriculumId_trackType',
      );
    });
  });
}
