import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/active_curricula.dart';

part 'active_curriculum_dao.g.dart';

@DriftAccessor(tables: [ActiveCurricula])
class ActiveCurriculumDao extends DatabaseAccessor<AppDatabase>
    with _$ActiveCurriculumDaoMixin {
  ActiveCurriculumDao(super.db);

  /// Get all active curricula IDs
  Future<List<String>> getActiveCurriculaIds() async {
    final results = await select(activeCurricula).get();
    return results.map((row) => row.curriculumId).toList();
  }

  /// Check if a curriculum is active
  Future<bool> isActive(String curriculumId) async {
    final result = await (select(
      activeCurricula,
    )..where((t) => t.curriculumId.equals(curriculumId))).getSingleOrNull();
    return result != null;
  }

  /// Activate a curriculum
  Future<void> activate(String curriculumId) async {
    await into(activeCurricula).insert(
      ActiveCurriculaCompanion(
        curriculumId: Value(curriculumId),
        activatedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Deactivate a curriculum
  /// Throws if this would leave zero active curricula
  Future<void> deactivate(String curriculumId) async {
    final activeIds = await getActiveCurriculaIds();
    if (activeIds.length <= 1 && activeIds.contains(curriculumId)) {
      throw Exception('Cannot deactivate the last active curriculum');
    }

    await (delete(
      activeCurricula,
    )..where((t) => t.curriculumId.equals(curriculumId))).go();
  }

  /// Get count of active curricula
  Future<int> getActiveCount() async {
    final results = await select(activeCurricula).get();
    return results.length;
  }
}
