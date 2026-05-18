/// I-5 migration gate — schema v18 → v19.
///
/// Verifies:
///   1. sync_queue has the entityKey nullable column.
///   2. enqueueWithKey deduplicates on entityKey (INSERT OR REPLACE).
///   3. enqueue (no key) still works independently.
library;

import 'package:flutter_test/flutter_test.dart';

import '../helpers/drift_memory.dart';

void main() {
  group('v18→v19: entityKey dedup on sync_queue', () {
    // ── 1. Schema: entityKey column exists and defaults to null ─────────────

    test('enqueue without entityKey produces null entityKey row', () async {
      final db = inMemoryDb();
      addTearDown(db.close);

      await db.syncQueueDao.enqueue('completion', '{"ref":"Berakhot 1"}');

      final rows = await db.syncQueueDao.getAllPending();
      expect(rows, hasLength(1));
      expect(
        rows.first.entityKey,
        isNull,
        reason: 'I-5: legacy enqueue must not provide an entityKey',
      );
    });

    // ── 2. enqueueWithKey deduplicates ────────────────────────────────────

    test('enqueueWithKey replaces the existing row for the same entityKey', () async {
      final db = inMemoryDb();
      addTearDown(db.close);

      await db.syncQueueDao.enqueueWithKey(
        'track_config',
        '{"active":true}',
        'track_config:42',
      );
      await db.syncQueueDao.enqueueWithKey(
        'track_config',
        '{"active":false}',
        'track_config:42',
      );

      final rows = await db.syncQueueDao.getAllPending();
      expect(
        rows,
        hasLength(1),
        reason: 'I-5: second enqueueWithKey for same entityKey must replace first',
      );
      expect(rows.first.payload, contains('"active":false'));
    });

    // ── 3. Different entity keys don't interfere ──────────────────────────

    test('enqueueWithKey keeps both rows for different entityKeys', () async {
      final db = inMemoryDb();
      addTearDown(db.close);

      await db.syncQueueDao.enqueueWithKey(
        'track_config',
        '{"id":1}',
        'track_config:1',
      );
      await db.syncQueueDao.enqueueWithKey(
        'track_config',
        '{"id":2}',
        'track_config:2',
      );

      final rows = await db.syncQueueDao.getAllPending();
      expect(
        rows,
        hasLength(2),
        reason: 'I-5: distinct entityKeys must not collide',
      );
    });

    // ── 4. enqueue and enqueueWithKey coexist ─────────────────────────────

    test('null-key and keyed rows coexist without conflict', () async {
      final db = inMemoryDb();
      addTearDown(db.close);

      // Three legacy enqueues (null entityKey).
      for (var i = 0; i < 3; i++) {
        await db.syncQueueDao.enqueue('completion', '{"n":$i}');
      }
      // One keyed enqueue.
      await db.syncQueueDao.enqueueWithKey('profile', '{}', 'profile:1');

      final rows = await db.syncQueueDao.getAllPending();
      expect(
        rows,
        hasLength(4),
        reason: 'I-5: null entityKeys are not considered equal — no dedup',
      );
    });
  });
}
