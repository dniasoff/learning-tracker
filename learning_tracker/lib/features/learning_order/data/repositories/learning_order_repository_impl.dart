import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/learning_order/domain/repositories/learning_order_repository.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';

class LearningOrderRepositoryImpl implements LearningOrderRepository {
  LearningOrderRepositoryImpl({
    required AppDatabase database,
    required ContentRepository contentRepository,
    SyncEngine? syncEngine,
  }) : _database = database,
       _contentRepository = contentRepository,
       _syncEngine = syncEngine;

  final AppDatabase _database;
  final ContentRepository _contentRepository;
  // ignore: unused_field, will be used once SyncEngine supports pushLearningOrder
  // ignore: unused_field
  final SyncEngine? _syncEngine;

  /// Returns a map from sefariaRef → (displayNameHe, displayNameEn, sortOrder)
  /// for all drag-level (level2, non-leaf) items of a curriculum.
  Future<Map<String, ({String he, String en, int sortOrder})>> _buildRefIndex(
    CurriculumId curriculumId,
  ) async {
    final allItems = await _contentRepository.getContentForCurriculum(
      curriculumId,
    );
    final index = <String, ({String he, String en, int sortOrder})>{};
    for (final item in allItems) {
      if (item.level2 != null && !item.isLeaf) {
        index.putIfAbsent(
          item.sefariaRef,
          () => (
            he: item.displayNameHe,
            en: item.displayNameEn,
            sortOrder: item.sortOrder,
          ),
        );
      }
    }
    return index;
  }

  @override
  Future<List<LearningOrderItem>> getOrder(CurriculumId curriculumId) async {
    final rows = await _database.learningOrderDao.getLearningOrderByCurriculum(
      curriculumId.storageKey,
    );
    final index = await _buildRefIndex(curriculumId);

    if (rows.isNotEmpty) {
      // Custom order exists — return sorted by userSortOrder, enriched with display names
      return rows.map((r) {
        final info = index[r.sefariaRef];
        return LearningOrderItem(
          sefariaRef: r.sefariaRef,
          displayNameHe: info?.he ?? r.sefariaRef,
          displayNameEn: info?.en ?? r.sefariaRef,
          userSortOrder: r.userSortOrder,
          isCustomOrdered: true,
        );
      }).toList();
    }

    // No custom order — fall back to content_items.sort_order at drag level
    final sorted = index.entries.toList()
      ..sort((a, b) => a.value.sortOrder.compareTo(b.value.sortOrder));

    return sorted
        .asMap()
        .entries
        .map(
          (e) => LearningOrderItem(
            sefariaRef: e.value.key,
            displayNameHe: e.value.value.he,
            displayNameEn: e.value.value.en,
            userSortOrder: e.key,
            isCustomOrdered: false,
          ),
        )
        .toList();
  }

  @override
  Future<void> saveOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items,
  ) async {
    for (var i = 0; i < items.length; i++) {
      await _database.learningOrderDao.upsertLearningOrder(
        LearningOrderCompanion.insert(
          curriculumId: curriculumId.storageKey,
          sefariaRef: items[i].sefariaRef,
          userSortOrder: i,
        ),
      );
    }

    // TODO: Push learning order to Firestore once SyncEngine supports it.
  }

  @override
  Future<void> resetToDefault(CurriculumId curriculumId) async {
    await _database.learningOrderDao.deleteAllForCurriculum(
      curriculumId.storageKey,
    );

    // TODO: Push empty learning order to Firestore once SyncEngine supports it.
  }
}
