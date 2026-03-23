import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('StreakDao', () {
    test('getStreak returns null initially', () async {
      final streak = await database.streakDao.getStreak();
      expect(streak, isNull);
    });

    test('upsertStreak inserts when no existing streak', () async {
      await database.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(5),
          maxStreak: const Value(10),
          lastCompletionDate: Value(DateTime(2024, 6, 15)),
        ),
      );

      final streak = await database.streakDao.getStreak();
      expect(streak, isNotNull);
      expect(streak!.currentStreak, 5);
      expect(streak.maxStreak, 10);
      expect(streak.lastCompletionDate, DateTime(2024, 6, 15));
    });

    test('upsertStreak updates existing streak', () async {
      await database.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(5),
          maxStreak: const Value(10),
        ),
      );

      await database.streakDao.upsertStreak(
        const StreaksCompanion(
          currentStreak: Value(7),
          maxStreak: Value(10),
          lastCompletionDate: Value(null),
        ),
      );

      final streak = await database.streakDao.getStreak();
      expect(streak!.currentStreak, 7);
    });

    test('watchStreak emits updates', () async {
      final stream = database.streakDao.watchStreak();

      expect(
        stream,
        emitsInOrder([
          isNull, // Initial empty state
          isNotNull, // After upsert
        ]),
      );

      await Future<void>.delayed(Duration.zero);
      await database.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(1),
          maxStreak: const Value(1),
        ),
      );
    });

    test('upsertStreak maintains single row', () async {
      await database.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(1),
          maxStreak: const Value(1),
        ),
      );

      await database.streakDao.upsertStreak(
        const StreaksCompanion(currentStreak: Value(2), maxStreak: Value(2)),
      );

      await database.streakDao.upsertStreak(
        const StreaksCompanion(currentStreak: Value(3), maxStreak: Value(3)),
      );

      // Should still be a single row
      final all = await database.streakDao.getStreak();
      expect(all, isNotNull);
      expect(all!.currentStreak, 3);
    });
  });
}
