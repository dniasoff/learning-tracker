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

  /// Get top-level items for a curriculum (level2/3/4 are NULL).
  /// Returns the first level of the hierarchy (e.g., Sedarim for Mishnayos).
  Future<List<ContentItem>> getTopLevelItems(String curriculumId) =>
      (select(contentItems)
            ..where(
              (t) =>
                  t.curriculumId.equals(curriculumId) &
                  t.level2.isNull() &
                  t.level3.isNull() &
                  t.level4.isNull(),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

  /// Get children of a level 1 item (e.g., Masechtot for a specific Seder).
  Future<List<ContentItem>> getLevel2Items(
    String curriculumId,
    String level1Value,
  ) =>
      (select(contentItems)
            ..where(
              (t) =>
                  t.curriculumId.equals(curriculumId) &
                  t.level1.equals(level1Value) &
                  t.level2.isNotNull() &
                  t.level3.isNull() &
                  t.level4.isNull(),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

  /// Get children of a level 2 item (e.g., Perakim for a specific Masechta).
  Future<List<ContentItem>> getLevel3Items(
    String curriculumId,
    String level1Value,
    String level2Value,
  ) =>
      (select(contentItems)
            ..where(
              (t) =>
                  t.curriculumId.equals(curriculumId) &
                  t.level1.equals(level1Value) &
                  t.level2.equals(level2Value) &
                  t.level3.isNotNull() &
                  t.level4.isNull(),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

  /// Get children of a level 3 item (e.g., Mishnayos for a specific Perek).
  Future<List<ContentItem>> getLevel4Items(
    String curriculumId,
    String level1Value,
    String level2Value,
    String level3Value,
  ) =>
      (select(contentItems)
            ..where(
              (t) =>
                  t.curriculumId.equals(curriculumId) &
                  t.level1.equals(level1Value) &
                  t.level2.equals(level2Value) &
                  t.level3.equals(level3Value) &
                  t.level4.isNotNull(),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

  /// Get total item count for a curriculum (for curriculum list display).
  Future<int> getCurriculumItemCount(String curriculumId) async {
    final query = selectOnly(contentItems)
      ..addColumns([contentItems.id.count()])
      ..where(contentItems.curriculumId.equals(curriculumId));
    final result = await query.getSingle();
    return result.read(contentItems.id.count()) ?? 0;
  }

  /// Get a specific content item by its full hierarchy path.
  Future<ContentItem?> getItemByPath(
    String curriculumId,
    String level1Value,
    String? level2Value,
    String? level3Value,
    String? level4Value,
  ) {
    final query = select(contentItems)
      ..where(
        (t) =>
            t.curriculumId.equals(curriculumId) & t.level1.equals(level1Value),
      );

    if (level2Value != null) {
      query.where((t) => t.level2.equals(level2Value));
    } else {
      query.where((t) => t.level2.isNull());
    }

    if (level3Value != null) {
      query.where((t) => t.level3.equals(level3Value));
    } else {
      query.where((t) => t.level3.isNull());
    }

    if (level4Value != null) {
      query.where((t) => t.level4.equals(level4Value));
    } else {
      query.where((t) => t.level4.isNull());
    }

    return query.getSingleOrNull();
  }
}
