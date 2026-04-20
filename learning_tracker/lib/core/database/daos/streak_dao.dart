import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/streaks.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'streak_dao.g.dart';

/// DAO for the streaks table.
///
/// Each profile on an account owns its own streak row, keyed by profileId.
@DriftAccessor(tables: [Streaks])
class StreakDao extends DatabaseAccessor<UserDatabase> with _$StreakDaoMixin {
  StreakDao(super.db);

  /// Get the streak record for a specific profile, or null if none exists.
  Future<Streak?> getStreakByProfile(int profileId) =>
      (select(streaks)
            ..where((t) => t.profileId.equals(profileId))
            ..limit(1))
          .getSingleOrNull();

  /// Watch the streak record for a specific profile.
  Stream<Streak?> watchStreakByProfile(int profileId) =>
      (select(streaks)
            ..where((t) => t.profileId.equals(profileId))
            ..limit(1))
          .watchSingleOrNull();

  /// Upsert the streak record for a specific profile.
  Future<void> upsertStreakByProfile(
    int profileId,
    StreaksCompanion entry,
  ) async {
    final existing = await getStreakByProfile(profileId);
    if (existing == null) {
      await into(streaks).insert(entry.copyWith(profileId: Value(profileId)));
    } else {
      await (update(
        streaks,
      )..where((t) => t.id.equals(existing.id))).write(entry);
    }
  }

  /// Legacy accessor — returns the streak for the default profile (id 0).
  /// Kept only for code paths that have not yet been threaded with a profileId
  /// (data export, legacy tests). Prefer [getStreakByProfile].
  Future<Streak?> getStreak() => getStreakByProfile(0);

  /// Legacy stream — watches the default profile (id 0). Prefer
  /// [watchStreakByProfile].
  Stream<Streak?> watchStreak() => watchStreakByProfile(0);

  /// Legacy upsert — writes to the default profile (id 0). Prefer
  /// [upsertStreakByProfile].
  Future<void> upsertStreak(StreaksCompanion entry) =>
      upsertStreakByProfile(0, entry);
}
