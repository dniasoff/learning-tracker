import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/learning_order.dart';

part 'learning_order_dao.g.dart';

@DriftAccessor(tables: [LearningOrder])
class LearningOrderDao extends DatabaseAccessor<AppDatabase>
    with _$LearningOrderDaoMixin {
  LearningOrderDao(super.db);

  Future<List<LearningOrderData>> getAllLearningOrders() =>
      select(learningOrder).get();

  Future<LearningOrderData?> getLearningOrderById(int id) =>
      (select(learningOrder)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<LearningOrderData>> getLearningOrderByCurriculum(
    String curriculumId,
  ) =>
      (select(learningOrder)
            ..where((t) => t.curriculumId.equals(curriculumId))
            ..orderBy([(t) => OrderingTerm.asc(t.userSortOrder)]))
          .get();

  Future<int> insertLearningOrder(LearningOrderCompanion entry) =>
      into(learningOrder).insert(entry);

  Future<bool> updateLearningOrder(LearningOrderCompanion entry) =>
      update(learningOrder).replace(entry);

  Future<int> deleteLearningOrder(int id) =>
      (delete(learningOrder)..where((t) => t.id.equals(id))).go();

  /// Upsert a learning order row — insert or update on (curriculumId, sefariaRef) conflict.
  Future<int> upsertLearningOrder(LearningOrderCompanion entry) =>
      into(learningOrder).insert(
        entry,
        onConflict: DoUpdate(
          (_) => entry,
          target: [learningOrder.profileId, learningOrder.curriculumId, learningOrder.sefariaRef],
        ),
      );

  /// Count the total number of content items for a curriculum.
  Future<int> countByCurriculum(String curriculumId) async {
    final count = learningOrder.id.count();
    final query = selectOnly(learningOrder)
      ..addColumns([count])
      ..where(learningOrder.curriculumId.equals(curriculumId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Delete all learning order rows for a curriculum (reset to default).
  Future<int> deleteAllForCurriculum(String curriculumId) => (delete(
    learningOrder,
  )..where((t) => t.curriculumId.equals(curriculumId))).go();
}
