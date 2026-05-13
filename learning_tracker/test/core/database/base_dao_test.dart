/// Tests for [BaseDao] mixin — DNI-338.
///
/// Verifies the four common methods (`getById`, `getByProfile`, `count`,
/// `exists`) work for a real Drift DAO that mixes in [BaseDao].
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:test/test.dart';

StreaksCompanion _streak({required int profileId, int current = 5}) =>
    StreaksCompanion.insert(
      profileId: profileId,
      currentStreak: Value(current),
    );

void main() {
  group('BaseDao<Streak> on StreakDao', () {
    late UserDatabase db;

    setUp(() {
      db = UserDatabase(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('count returns 0 on empty table', () async {
      expect(await db.streakDao.count(profileId: 1), 0);
    });

    test('exists returns false on empty table', () async {
      expect(await db.streakDao.exists(profileId: 1), isFalse);
    });

    test('count and exists reflect rows for the given profile only', () async {
      await db.streakDao.upsertStreakByProfile(1, _streak(profileId: 1));
      await db.streakDao.upsertStreakByProfile(
        2,
        _streak(profileId: 2, current: 3),
      );

      expect(await db.streakDao.count(profileId: 1), 1);
      expect(await db.streakDao.count(profileId: 2), 1);
      expect(await db.streakDao.count(profileId: 99), 0);
      expect(await db.streakDao.exists(profileId: 1), isTrue);
      expect(await db.streakDao.exists(profileId: 99), isFalse);
    });

    test('getById returns the row when present, null when absent', () async {
      await db.streakDao.upsertStreakByProfile(1, _streak(profileId: 1));

      final row = await db.streakDao.getStreakByProfile(1);
      expect(row, isNotNull);

      final fetched = await db.streakDao.getById(row!.id);
      expect(fetched, isNotNull);
      expect(fetched!.profileId, 1);
      expect(fetched.currentStreak, 5);

      expect(await db.streakDao.getById(999999), isNull);
    });

    test('getByProfile returns all rows for that profile', () async {
      await db.streakDao.upsertStreakByProfile(
        7,
        _streak(profileId: 7, current: 1),
      );

      final rows = await db.streakDao.getByProfile(7);
      expect(rows, hasLength(1));
      expect(rows.first.profileId, 7);

      final none = await db.streakDao.getByProfile(99);
      expect(none, isEmpty);
    });
  });
}
