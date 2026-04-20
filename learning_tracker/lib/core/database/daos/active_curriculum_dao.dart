import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/active_curricula.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

part 'active_curriculum_dao.g.dart';

@DriftAccessor(tables: [ActiveCurricula])
class ActiveCurriculumDao extends DatabaseAccessor<UserDatabase>
    with _$ActiveCurriculumDaoMixin {
  ActiveCurriculumDao(super.db);

  /// Returns list of active curriculum IDs
  Future<List<String>> getActiveCurricula() async {
    final rows = await select(activeCurricula).get();
    return rows.map((row) => row.curriculumId).toList();
  }

  /// Watch stream of active curriculum IDs
  Stream<List<String>> watchActiveCurricula() {
    return select(
      activeCurricula,
    ).watch().map((rows) => rows.map((row) => row.curriculumId).toList());
  }

  // ========== Profile-Scoped Queries ==========

  /// Returns list of active curriculum IDs for a specific profile.
  Future<List<String>> getActiveCurriculaByProfile(int profileId) async {
    final rows = await (select(
      activeCurricula,
    )..where((t) => t.profileId.equals(profileId))).get();
    return rows.map((row) => row.curriculumId).toList();
  }

  /// Watch stream of active curriculum IDs for a specific profile.
  Stream<List<String>> watchActiveCurriculaByProfile(int profileId) {
    return (select(activeCurricula)
          ..where((t) => t.profileId.equals(profileId)))
        .watch()
        .map((rows) => rows.map((row) => row.curriculumId).toList());
  }

  /// Activate a curriculum for a specific profile (idempotent).
  Future<void> activateByProfile(CurriculumId curriculum, int profileId) async {
    await into(activeCurricula).insertOnConflictUpdate(
      ActiveCurriculaCompanion.insert(
        profileId: Value(profileId),
        curriculumId: curriculum.storageKey,
        activatedAt: DateTimeFactory.nowUtc(),
      ),
    );
  }

  /// Check if a curriculum is currently active (legacy — any profile).
  Future<bool> isActive(CurriculumId curriculum) async {
    final query = select(activeCurricula)
      ..where((t) => t.curriculumId.equals(curriculum.storageKey));
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Check if a curriculum is currently active for a specific profile.
  Future<bool> isActiveForProfile(CurriculumId curriculum, int profileId) async {
    final query = select(activeCurricula)
      ..where(
        (t) =>
            t.curriculumId.equals(curriculum.storageKey) &
            t.profileId.equals(profileId),
      );
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Deactivate a curriculum for a specific profile.
  Future<void> deactivateByProfile(
    CurriculumId curriculum,
    int profileId,
  ) async {
    await transaction(() async {
      final activeForProfile = await getActiveCurriculaByProfile(profileId);
      if (activeForProfile.length <= 1) {
        throw StateError(
          'Cannot deactivate the last active curriculum for this profile',
        );
      }

      await (delete(activeCurricula)..where(
            (t) =>
                t.curriculumId.equals(curriculum.storageKey) &
                t.profileId.equals(profileId),
          ))
          .go();
    });
  }

  /// Activate a curriculum (idempotent)
  Future<void> activate(CurriculumId curriculum) async {
    await into(activeCurricula).insertOnConflictUpdate(
      ActiveCurriculaCompanion.insert(
        curriculumId: curriculum.storageKey,
        activatedAt: DateTimeFactory.nowUtc(),
      ),
    );
  }

  /// Deactivate a curriculum (throws StateError if last active).
  ///
  /// The count check and delete are wrapped in a single [transaction] to
  /// prevent a TOCTOU race where two concurrent calls could both pass the
  /// "length > 1" guard and both delete, leaving zero active curricula.
  Future<void> deactivate(CurriculumId curriculum) async {
    await transaction(() async {
      final activeCurriculaList = await getActiveCurricula();
      if (activeCurriculaList.length <= 1) {
        throw StateError('Cannot deactivate the last active curriculum');
      }

      await (delete(
        activeCurricula,
      )..where((t) => t.curriculumId.equals(curriculum.storageKey))).go();
    });
  }
}
