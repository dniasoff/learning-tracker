import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/base_dao.dart';
import 'package:learning_tracker/core/database/tables/learning_order.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'learning_order_dao.g.dart';

@DriftAccessor(tables: [LearningOrder])
class LearningOrderDao extends DatabaseAccessor<UserDatabase>
    with _$LearningOrderDaoMixin,
        BaseDao<$LearningOrderTable, LearningOrderData, UserDatabase> {
  LearningOrderDao(super.db);

  @override
  TableInfo<$LearningOrderTable, LearningOrderData> get table => learningOrder;

  @override
  Expression<int> idColumn($LearningOrderTable t) => t.id;

  @override
  Expression<int> profileIdColumn($LearningOrderTable t) => t.profileId;

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
          target: [
            learningOrder.profileId,
            learningOrder.curriculumId,
            learningOrder.sefariaRef,
          ],
        ),
      );

  /// Upsert only if [updatedAt] is strictly newer than the stored row.
  ///
  /// Returns `true` if the row was written, `false` if it was skipped
  /// because the local row is already at the same timestamp or newer
  /// (LWW conflict resolution for Firestore pulls — DNI-311).
  Future<bool> upsertLearningOrderIfNewer(
    LearningOrderCompanion entry, {
    required DateTime updatedAt,
  }) async {
    final existing =
        await (select(learningOrder)..where(
              (t) =>
                  t.profileId.equals(entry.profileId.value) &
                  t.curriculumId.equals(entry.curriculumId.value) &
                  t.sefariaRef.equals(entry.sefariaRef.value),
            ))
            .getSingleOrNull();

    if (existing != null && !updatedAt.isAfter(existing.updatedAt)) {
      return false;
    }

    await into(learningOrder).insert(
      entry.copyWith(updatedAt: Value(updatedAt)),
      onConflict: DoUpdate(
        (_) => entry.copyWith(updatedAt: Value(updatedAt)),
        target: [
          learningOrder.profileId,
          learningOrder.curriculumId,
          learningOrder.sefariaRef,
        ],
      ),
    );
    return true;
  }

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
