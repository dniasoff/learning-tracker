import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/active_curricula.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

part 'active_curriculum_dao.g.dart';

@DriftAccessor(tables: [ActiveCurricula])
class ActiveCurriculumDao extends DatabaseAccessor<AppDatabase>
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

  /// Check if a curriculum is currently active
  Future<bool> isActive(CurriculumId curriculum) async {
    final query = select(activeCurricula)
      ..where((t) => t.curriculumId.equals(curriculum.storageKey));
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Activate a curriculum (idempotent)
  Future<void> activate(CurriculumId curriculum) async {
    await into(activeCurricula).insertOnConflictUpdate(
      ActiveCurriculaCompanion.insert(
        curriculumId: curriculum.storageKey,
        activatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Deactivate a curriculum (throws StateError if last active)
  Future<void> deactivate(CurriculumId curriculum) async {
    // Check if this is the last active curriculum
    final activeCurriculaList = await getActiveCurricula();
    if (activeCurriculaList.length <= 1) {
      throw StateError('Cannot deactivate the last active curriculum');
    }

    await (delete(
      activeCurricula,
    )..where((t) => t.curriculumId.equals(curriculum.storageKey))).go();
  }
}
