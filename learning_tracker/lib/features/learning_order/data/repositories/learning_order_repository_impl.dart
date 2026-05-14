import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/learning_order/domain/repositories/learning_order_repository.dart'
    show LearningOrderRepository, ParentControlException;

class LearningOrderRepositoryImpl implements LearningOrderRepository {
  LearningOrderRepositoryImpl({
    required UserDatabase database,
    required ContentRepository contentRepository,
    SyncWriteFacade? syncEngine,
    int profileId = 0,
  }) : _database = database,
       _contentRepository = contentRepository,
       _syncEngine = syncEngine,
       _profileId = profileId;

  final UserDatabase _database;
  final ContentRepository _contentRepository;
  final SyncWriteFacade? _syncEngine;
  final int _profileId;

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
    List<LearningOrderItem> items, {
    bool isChildRestricted = false,
  }) async {
    // Parent-control guard enforced at repository, not UI.
    if (isChildRestricted) {
      throw const ParentControlException();
    }

    final updatedAt = DateTimeFactory.nowUtc();

    // Wrap all upserts in a single transaction so a mid-loop crash cannot
    // leave a half-shuffled state (D7, T2.10).
    await _database.transaction(() async {
      for (var i = 0; i < items.length; i++) {
        await _database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: curriculumId.storageKey,
            sefariaRef: items[i].sefariaRef,
            userSortOrder: i,
            profileId: _profileId,
            updatedAt: Value(updatedAt),
          ),
        );
      }
    });

    // Push to Firestore (offline-queued, retry on reconnect).
    await _syncEngine?.pushLearningOrder(
      profileId: _profileId,
      curriculumId: curriculumId.storageKey,
      items: items.asMap().entries.map((e) {
        return {'sefaria_ref': e.value.sefariaRef, 'user_sort_order': e.key};
      }).toList(),
      updatedAt: updatedAt,
    );
  }

  @override
  Future<void> resetToDefault(CurriculumId curriculumId) async {
    await _database.learningOrderDao.deleteAllForCurriculum(
      curriculumId.storageKey,
    );

    // Push empty order to Firestore so other devices know custom ordering
    // has been cleared (each device falls back to natural content sort).
    await _syncEngine?.pushLearningOrder(
      profileId: _profileId,
      curriculumId: curriculumId.storageKey,
      items: const [],
      updatedAt: DateTimeFactory.nowUtc(),
    );
  }
}
