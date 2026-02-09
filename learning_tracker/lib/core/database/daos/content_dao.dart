import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/content_items.dart';

part 'content_dao.g.dart';

@DriftAccessor(tables: [ContentItems])
class ContentDao extends DatabaseAccessor<AppDatabase> with _$ContentDaoMixin {
  ContentDao(super.db);

  Future<List<ContentItem>> getAllContentItems() => select(contentItems).get();

  Future<ContentItem?> getContentItemById(int id) =>
      (select(contentItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<ContentItem>> getContentItemsByCurriculum(String curriculumId) =>
      (select(
        contentItems,
      )..where((t) => t.curriculumId.equals(curriculumId))).get();

  Future<List<ContentItem>> getLeafItems(String curriculumId) =>
      (select(contentItems)..where(
            (t) => t.curriculumId.equals(curriculumId) & t.isLeaf.equals(true),
          ))
          .get();

  Future<int> insertContentItem(ContentItemsCompanion entry) =>
      into(contentItems).insert(entry);

  Future<bool> updateContentItem(ContentItemsCompanion entry) =>
      update(contentItems).replace(entry);

  Future<int> deleteContentItem(int id) =>
      (delete(contentItems)..where((t) => t.id.equals(id))).go();

  Future<int> deleteAllForCurriculum(String curriculumId) => (delete(
    contentItems,
  )..where((t) => t.curriculumId.equals(curriculumId))).go();

  Future<int> getContentItemCountByCurriculum(String curriculumId) async {
    final query = selectOnly(contentItems)
      ..addColumns([contentItems.id.count()])
      ..where(contentItems.curriculumId.equals(curriculumId));

    final result = await query.getSingleOrNull();
    return result?.read(contentItems.id.count()) ?? 0;
  }
}
