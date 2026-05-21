/// Tests for [SyncKvDao] — persisted LWW timestamps per `(kind, entityKey)`
/// (Phase 3 of the sync architecture plan).
///
/// Covers:
///   - `get` returns null for unknown keys.
///   - `upsert` then `get` round-trips the persisted `updated_at`.
///   - `upsert` of the same key updates in place (no row explosion).
///   - `getSyncedAt` returns null when the row had no synced_at recorded.
///   - `getSyncedAt` returns the persisted server timestamp when recorded.
///   - Keys are namespaced by [kind] — same entityKey under different kinds
///     stays independent.
@Tags(['sync_kv_dao'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncKvDao', () {
    test('get returns null for unknown (kind, entityKey)', () async {
      final result = await db.syncKvDao.get('bookmark', '0|bavli|personal');
      expect(result, isNull);
    });

    test('upsert + get round-trips the updated_at timestamp', () async {
      final ts = DateTime.utc(2026, 5, 21, 12, 0, 0);
      await db.syncKvDao.upsert('bookmark', '0|bavli|personal', ts);
      final after = await db.syncKvDao.get('bookmark', '0|bavli|personal');
      expect(after, ts);
    });

    test(
      'upsert of the same key updates in place (no duplicate rows)',
      () async {
        final ts1 = DateTime.utc(2026, 5, 21, 12, 0, 0);
        final ts2 = DateTime.utc(2026, 5, 21, 13, 0, 0);
        await db.syncKvDao.upsert('bookmark', '0|bavli|personal', ts1);
        await db.syncKvDao.upsert('bookmark', '0|bavli|personal', ts2);
        final after = await db.syncKvDao.get('bookmark', '0|bavli|personal');
        expect(after, ts2);

        // No duplicate rows: a single primary-key conflict in upsert mode
        // means the table still holds one row for this (kind, entityKey).
        final all = await db.select(db.syncKv).get();
        expect(all, hasLength(1));
      },
    );

    test('getSyncedAt returns null when no synced_at was recorded', () async {
      final ts = DateTime.utc(2026, 5, 21, 12, 0, 0);
      await db.syncKvDao.upsert('bookmark', '0|bavli|personal', ts);
      final synced = await db.syncKvDao.getSyncedAt(
        'bookmark',
        '0|bavli|personal',
      );
      expect(synced, isNull);
    });

    test('upsert with synced_at + getSyncedAt round-trips', () async {
      final ts = DateTime.utc(2026, 5, 21, 12, 0, 0);
      final syncedAt = DateTime.utc(2026, 5, 21, 12, 0, 30);
      await db.syncKvDao.upsert(
        'bookmark',
        '0|bavli|personal',
        ts,
        syncedAt: syncedAt,
      );
      final after = await db.syncKvDao.getSyncedAt(
        'bookmark',
        '0|bavli|personal',
      );
      expect(after, syncedAt);
    });

    test(
      'kind namespacing — same entityKey under different kinds is independent',
      () async {
        final tsBookmark = DateTime.utc(2026, 5, 21, 12, 0, 0);
        final tsSettings = DateTime.utc(2026, 5, 21, 14, 0, 0);
        await db.syncKvDao.upsert('bookmark', 'shared|key', tsBookmark);
        await db.syncKvDao.upsert('settings', 'shared|key', tsSettings);
        expect(await db.syncKvDao.get('bookmark', 'shared|key'), tsBookmark);
        expect(await db.syncKvDao.get('settings', 'shared|key'), tsSettings);
      },
    );

    test(
      'upsert without syncedAt clears any prior persisted syncedAt',
      () async {
        final ts = DateTime.utc(2026, 5, 21, 12, 0, 0);
        final syncedAt = DateTime.utc(2026, 5, 21, 12, 0, 30);

        // First write with syncedAt set.
        await db.syncKvDao.upsert('bookmark', 'k', ts, syncedAt: syncedAt);
        expect(await db.syncKvDao.getSyncedAt('bookmark', 'k'), syncedAt);

        // Second write without syncedAt — the field must reset to null
        // (matches "explicit absence wins over stale value" semantics).
        await db.syncKvDao.upsert(
          'bookmark',
          'k',
          ts.add(const Duration(seconds: 1)),
        );
        expect(await db.syncKvDao.getSyncedAt('bookmark', 'k'), isNull);
      },
    );
  });
}
