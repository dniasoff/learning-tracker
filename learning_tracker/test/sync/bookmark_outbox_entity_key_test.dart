/// Regression test for the bookmark outbox entity key.
///
/// One track per (profile, curriculum), so the bookmark outbox entity key is
/// the `curriculum_id` alone — mirroring the Firestore bookmark doc-id. Two
/// position updates for the same curriculum share one key (same logical
/// document); different curricula get distinct keys.
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

  group('bookmark outbox entity key (one track per curriculum)', () {
    test('different curricula produce distinct entity keys', () async {
      final facade = OutboxSyncWriteFacade(
        outboxDao: db.outboxDao,
        database: db,
        profileId: profileId,
        clock: FakeLocalDayClock(DateTime.utc(2026, 5, 31)),
      );

      await facade.pushBookmark({
        'curriculum_id': 'bereshit',
        'content_item_id': 'Genesis 1:1',
        'updated_at': '2026-05-31T10:00:00.000Z',
      });
      await facade.pushBookmark({
        'curriculum_id': 'mishnayos',
        'content_item_id': 'Berakhot 1:1',
        'updated_at': '2026-05-31T10:05:00.000Z',
      });

      final rows = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.bookmark,
        profileId,
      );

      expect(rows, hasLength(2));
      final keys = rows.map((r) => r.entityKey).toSet();
      expect(keys, hasLength(2));
      expect(keys, containsAll(['bereshit', 'mishnayos']));
    });

    test(
      'two position updates for the same curriculum share one entity key',
      () async {
        final facade = OutboxSyncWriteFacade(
          outboxDao: db.outboxDao,
          database: db,
          profileId: profileId,
          clock: FakeLocalDayClock(DateTime.utc(2026, 5, 31)),
        );

        await facade.pushBookmark({
          'curriculum_id': 'bereshit',
          'content_item_id': 'Genesis 1:1',
          'updated_at': '2026-05-31T10:00:00.000Z',
        });
        await facade.pushBookmark({
          'curriculum_id': 'bereshit',
          'content_item_id': 'Genesis 1:5',
          'updated_at': '2026-05-31T10:10:00.000Z',
        });

        final rows = await db.outboxDao.getPendingByKind(
          OutboxEntityKind.bookmark,
          profileId,
        );

        // Both rows are in the outbox (no UNIQUE constraint — de-dup happens
        // at drain time via set+merge), and they carry the same key because
        // they represent the same Firestore document.
        expect(rows, hasLength(2));
        expect(rows.map((r) => r.entityKey).toSet(), {'bereshit'});
      },
    );

    test('entity key mirrors the Firestore bookmark doc-id (curriculum_id)', () {
      // The Firestore gateway uses curriculum_id alone as the bookmark doc-id.
      final facade = OutboxSyncWriteFacade(
        outboxDao: db.outboxDao,
        database: db,
        profileId: profileId,
        clock: FakeLocalDayClock(DateTime.utc(2026, 5, 31)),
      );

      return facade
          .pushBookmark({
            'curriculum_id': 'mishnayos',
            'content_item_id': 'Berakhot 1:1',
            'updated_at': '2026-05-31T09:00:00.000Z',
          })
          .then((_) async {
            final rows = await db.outboxDao.getPendingByKind(
              OutboxEntityKind.bookmark,
              profileId,
            );
            expect(rows, hasLength(1));
            expect(rows.single.entityKey, 'mishnayos');
          });
    });
  });
}
