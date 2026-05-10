import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/tables/text_cache.dart';

part 'text_cache_dao.g.dart';

/// Read-only DAO for text content in the ContentDatabase.
@DriftAccessor(tables: [TextCache])
class ContentTextCacheDao extends DatabaseAccessor<ContentDatabase>
    with _$ContentTextCacheDaoMixin {
  ContentTextCacheDao(super.db);

  /// Retrieves cached text for a given Sefaria reference.
  Future<TextCacheData?> getText(String sefariaRef) => (select(
    textCache,
  )..where((t) => t.sefariaRef.equals(sefariaRef))).getSingleOrNull();

  /// Returns all cached Sefaria references.
  Future<List<String>> getAllCachedRefs() async {
    final results = await select(textCache).get();
    return results.map((row) => row.sefariaRef).toList();
  }

  /// Watch text for a given Sefaria reference.
  Stream<TextCacheData?> watchText(String sefariaRef) => (select(
    textCache,
  )..where((t) => t.sefariaRef.equals(sefariaRef))).watchSingleOrNull();

  /// Returns all child verse rows for a chapter-level ref.
  /// E.g., 'Genesis 1' returns all rows with sefariaRef LIKE 'Genesis 1:%'.
  Future<List<TextCacheData>> getChildTexts(String chapterRef) =>
      (select(textCache)
        ..where((t) => t.sefariaRef.like('$chapterRef:%'))).get();
}
