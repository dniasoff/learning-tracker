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

  OutboxCompanion makeRow({
    int profileId = 1,
    String entityKind = 'completion',
    String entityKey = 'bavli/berakhot.2a/1/personal',
    String payload = '{"x":1}',
    DateTime? createdAt,
  }) {
    return OutboxCompanion.insert(
      profileId: profileId,
      entityKind: entityKind,
      entityKey: entityKey,
      payload: payload,
      createdAt: createdAt ?? DateTime.utc(2026, 5, 13, 12, 0),
    );
  }

  group('OutboxDao', () {
    group('insertOutboxRow', () {
      test('inserts a row and returns its auto-increment id', () async {
        final id = await db.outboxDao.insertOutboxRow(makeRow());
        expect(id, greaterThan(0));

        final rows = await db.select(db.outbox).get();
        expect(rows, hasLength(1));
        expect(rows.first.entityKind, 'completion');
        expect(rows.first.profileId, 1);
        expect(rows.first.attempts, 0);
        expect(rows.first.lastError, isNull);
        expect(rows.first.lastAttemptAt, isNull);
      });
    });

    group('getPendingByKind', () {
      test('returns empty list when no rows match', () async {
        final rows = await db.outboxDao.getPendingByKind(
          'completion',
          /*profileId*/ 1,
        );
        expect(rows, isEmpty);
      });

      test('returns rows for the given kind+profile, oldest first', () async {
        final a = await db.outboxDao.insertOutboxRow(
          makeRow(createdAt: DateTime.utc(2026, 5, 1)),
        );
        final b = await db.outboxDao.insertOutboxRow(
          makeRow(
            createdAt: DateTime.utc(2026, 5, 5),
            entityKey: 'bavli/berakhot.2b/1/personal',
          ),
        );
        // Different kind / profile — should NOT come back.
        await db.outboxDao.insertOutboxRow(makeRow(entityKind: 'streak'));
        await db.outboxDao.insertOutboxRow(makeRow(profileId: 2));

        final rows = await db.outboxDao.getPendingByKind('completion', 1);
        expect(rows.map((r) => r.id), [a, b]);
      });

      test('respects the limit parameter', () async {
        for (var i = 0; i < 5; i++) {
          await db.outboxDao.insertOutboxRow(
            makeRow(
              createdAt: DateTime.utc(2026, 5, 1).add(Duration(minutes: i)),
              entityKey: 'k_$i',
            ),
          );
        }
        final rows = await db.outboxDao.getPendingByKind(
          'completion',
          1,
          limit: 2,
        );
        expect(rows, hasLength(2));
      });
    });

    group('markAttempted', () {
      test('increments attempts and records the error', () async {
        final id = await db.outboxDao.insertOutboxRow(makeRow());

        await db.outboxDao.markAttempted(id, error: 'network down');

        final row = await (db.select(
          db.outbox,
        )..where((t) => t.id.equals(id))).getSingle();
        expect(row.attempts, 1);
        expect(row.lastError, 'network down');
        expect(row.lastAttemptAt, isNotNull);
      });

      test('clears the error when called without one (null arg)', () async {
        final id = await db.outboxDao.insertOutboxRow(makeRow());
        await db.outboxDao.markAttempted(id, error: 'first try');
        await db.outboxDao.markAttempted(id); // no error this time

        final row = await (db.select(
          db.outbox,
        )..where((t) => t.id.equals(id))).getSingle();
        expect(row.attempts, 2);
        expect(row.lastError, isNull);
      });

      test('is a no-op for a missing id (does not throw)', () async {
        await db.outboxDao.markAttempted(9999, error: 'whatever');
        final rows = await db.select(db.outbox).get();
        expect(rows, isEmpty);
      });
    });

    group('deleteRow', () {
      test('deletes the row by id and returns the affected count', () async {
        final id = await db.outboxDao.insertOutboxRow(makeRow());
        final affected = await db.outboxDao.deleteRow(id);
        expect(affected, 1);

        final rows = await db.select(db.outbox).get();
        expect(rows, isEmpty);
      });

      test('returns 0 when the id does not exist', () async {
        final affected = await db.outboxDao.deleteRow(404);
        expect(affected, 0);
      });
    });
  });
}
