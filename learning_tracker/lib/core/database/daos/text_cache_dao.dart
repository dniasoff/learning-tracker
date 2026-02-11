import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/text_cache.dart';

part 'text_cache_dao.g.dart';

@DriftAccessor(tables: [TextCache])
class TextCacheDao extends DatabaseAccessor<AppDatabase>
    with _$TextCacheDaoMixin {
  TextCacheDao(super.db);

  /// Retrieves cached text for a given Sefaria reference.
  /// Returns null if not cached.
  Future<TextCacheData?> getText(String sefariaRef) => (select(
    textCache,
  )..where((t) => t.sefariaRef.equals(sefariaRef))).getSingleOrNull();

  /// Stores text in cache. Replaces existing entry if present.
  Future<void> storeText({
    required String sefariaRef,
    required String hebrewText,
    required String englishText,
  }) async {
    await into(textCache).insertOnConflictUpdate(
      TextCacheCompanion.insert(
        sefariaRef: sefariaRef,
        hebrewText: hebrewText,
        englishText: englishText,
        fetchedAt: DateTime.now(),
      ),
    );
  }

  /// Deletes cached text for a given Sefaria reference.
  Future<int> deleteText(String sefariaRef) =>
      (delete(textCache)..where((t) => t.sefariaRef.equals(sefariaRef))).go();

  /// Returns all cached Sefaria references.
  Future<List<String>> getAllCachedRefs() async {
    final results = await select(textCache).get();
    return results.map((row) => row.sefariaRef).toList();
  }

  /// Stores multiple texts in a single transaction (batch insert).
  Future<void> storeBatch(
    List<({String sefariaRef, String hebrewText, String englishText})> items,
  ) async {
    await batch((b) {
      for (final item in items) {
        b.insert(
          textCache,
          TextCacheCompanion.insert(
            sefariaRef: item.sefariaRef,
            hebrewText: item.hebrewText,
            englishText: item.englishText,
            fetchedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Clears all cached text.
  Future<int> clearCache() => delete(textCache).go();
}
