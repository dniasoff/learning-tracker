import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/tracks/track_order/domain/repositories/track_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/track_order/domain/services/masechta_ordering_policy.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

class TrackLearningOrderRepositoryImpl implements TrackLearningOrderRepository {
  TrackLearningOrderRepositoryImpl({
    required UserDatabase database,
    required ContentRepository contentRepository,
  }) : _database = database,
       _contentRepository = contentRepository;

  final UserDatabase _database;
  final ContentRepository _contentRepository;

  Future<Map<String, ({String he, String en, int sortOrder})>>
  _buildSedarimIndex(CurriculumId curriculumId) async {
    final allItems = await _contentRepository.getContentForCurriculum(
      curriculumId,
    );
    final index = <String, ({String he, String en, int sortOrder})>{};
    for (final item in allItems) {
      if (item.level2 == null && !item.isLeaf) {
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

  Future<Map<String, ({String he, String en, int sortOrder})>>
  _buildMasechtosIndex(int trackId, CurriculumId curriculumId) async {
    final allItems = await _contentRepository.getContentForCurriculum(
      curriculumId,
    );
    final sedarimIndex = await _buildSedarimIndex(curriculumId);

    // Convert DAO rows to the savedSederOrder list expected by the policy:
    // only include rows whose sefariaRef matches a known seder, in row order.
    final daoRows = await _database.trackLearningOrderDao.getByTrack(trackId);
    final savedSederOrder = daoRows
        .where((r) => sedarimIndex.containsKey(r.sefariaRef))
        .map((r) => r.sefariaRef)
        .toList();

    return const MasechtaOrderingPolicy().buildIndex(
      allItems: allItems,
      sedarimIndex: sedarimIndex,
      savedSederOrder: savedSederOrder,
    );
  }

  Future<List<LearningOrderItem>> _getOrderedItems(
    int trackId,
    Map<String, ({String he, String en, int sortOrder})> index,
  ) async {
    final rows = await _database.trackLearningOrderDao.getByTrack(trackId);
    final matchingRows = rows
        .where((r) => index.containsKey(r.sefariaRef))
        .toList();

    if (matchingRows.isNotEmpty) {
      return matchingRows.map((r) {
        final info = index[r.sefariaRef]!;
        return LearningOrderItem(
          sefariaRef: r.sefariaRef,
          displayNameHe: info.he,
          displayNameEn: info.en,
          userSortOrder: r.sortOrder,
          isCustomOrdered: true,
        );
      }).toList();
    }

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
  Future<List<LearningOrderItem>> getSedarimOrder(
    int trackId,
    CurriculumId curriculumId,
  ) async {
    final index = await _buildSedarimIndex(curriculumId);
    return _getOrderedItems(trackId, index);
  }

  @override
  Future<List<LearningOrderItem>> getMasechtosOrder(
    int trackId,
    CurriculumId curriculumId,
  ) async {
    final index = await _buildMasechtosIndex(trackId, curriculumId);
    return _getOrderedItems(trackId, index);
  }

  @override
  Future<void> saveSedarimOrder(
    int trackId,
    List<LearningOrderItem> items,
  ) async {
    final refs = items.map((i) => i.sefariaRef).toList();
    await _database.trackLearningOrderDao.upsertOrder(trackId, refs);
    // Reorder-amnesty: stamp lastReorderAt so the projection clears overdue
    // items that were scheduled before this reorder (architecture §10.1).
    await _database.trackDao.stampReorderAt(trackId);
  }

  @override
  Future<void> saveMasechtosOrder(
    int trackId,
    List<LearningOrderItem> items,
  ) async {
    final refs = items.map((i) => i.sefariaRef).toList();
    await _database.trackLearningOrderDao.upsertOrder(trackId, refs);
    // Reorder-amnesty: stamp lastReorderAt so the projection clears overdue
    // items scheduled before this reorder (architecture §10.1).
    await _database.trackDao.stampReorderAt(trackId);
  }

  @override
  Future<void> resetToDefault(int trackId) async {
    await _database.trackLearningOrderDao.deleteByTrack(trackId);
    // Reorder-amnesty: reset-to-default is a content-order change.
    await _database.trackDao.stampReorderAt(trackId);
  }
}
