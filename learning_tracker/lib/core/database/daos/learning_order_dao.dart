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
}
