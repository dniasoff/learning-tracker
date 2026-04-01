import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/database/tables/streaks.dart';

part 'streak_dao.g.dart';

/// DAO for the streaks table.
///
/// Manages the single-row global streak record.
@DriftAccessor(tables: [Streaks])
class StreakDao extends DatabaseAccessor<UserDatabase> with _$StreakDaoMixin {
  StreakDao(super.db);

  /// Get the current streak record, or null if none exists.
  Future<Streak?> getStreak() => (select(streaks)..limit(1)).getSingleOrNull();

  /// Watch the current streak record for reactive UI updates.
  Stream<Streak?> watchStreak() =>
      (select(streaks)..limit(1)).watchSingleOrNull();

  /// Upsert the streak record. Creates if not exists, updates if exists.
  Future<void> upsertStreak(StreaksCompanion entry) async {
    final existing = await getStreak();
    if (existing == null) {
      await into(streaks).insert(entry);
    } else {
      await (update(
        streaks,
      )..where((t) => t.id.equals(existing.id))).write(entry);
    }
  }
}
