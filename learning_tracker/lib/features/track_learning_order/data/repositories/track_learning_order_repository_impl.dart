import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/track_learning_order/domain/repositories/track_learning_order_repository.dart';

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

    // Look up the user's seder order so we can group masechtos by their
    // parent seder's position. Without this the masechtos list keeps its
    // source-data order even after the sedarim above are reordered.
    final sedarimIndex = await _buildSedarimIndex(curriculumId);
    final daoRows = await _database.trackLearningOrderDao.getByTrack(trackId);
    final sederUserOrder = <String, int>{};
    var seen = 0;
    for (final row in daoRows) {
      if (sedarimIndex.containsKey(row.sefariaRef)) {
        sederUserOrder[row.sefariaRef] = seen++;
      }
    }

    int parentSederPriority(String level1) {
      // Match the stored seder ref by its sefariaRef. In Mishnayos/Bavli
      // data the seder container's sefariaRef equals its level1 value.
      final userIdx = sederUserOrder[level1];
      if (userIdx != null) return userIdx;
      // Fall back to source order so unordered sedarim stay in default place.
      final src = sedarimIndex[level1]?.sortOrder ?? 1 << 30;
      return 1000 + src; // bucketed after user-ordered sedarim
    }

    // Filter to L2-only containers (level2 set, level3 null, level4 null,
    // not a leaf). This excludes Perakim/Mishnayot that were leaking into
    // the masechtos list because they also have level2 != null.
    final masechtos =
        allItems
            .where(
              (i) =>
                  i.level2 != null &&
                  i.level3 == null &&
                  i.level4 == null &&
                  !i.isLeaf,
            )
            .toList()
          ..sort((a, b) {
            final pa = parentSederPriority(a.level1);
            final pb = parentSederPriority(b.level1);
            if (pa != pb) return pa.compareTo(pb);
            return a.sortOrder.compareTo(b.sortOrder);
          });

    final index = <String, ({String he, String en, int sortOrder})>{};
    for (var i = 0; i < masechtos.length; i++) {
      final item = masechtos[i];
      index.putIfAbsent(
        item.sefariaRef,
        () => (he: item.displayNameHe, en: item.displayNameEn, sortOrder: i),
      );
    }
    return index;
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
  }

  @override
  Future<void> saveMasechtosOrder(
    int trackId,
    List<LearningOrderItem> items,
  ) async {
    final refs = items.map((i) => i.sefariaRef).toList();
    await _database.trackLearningOrderDao.upsertOrder(trackId, refs);
  }

  @override
  Future<void> resetToDefault(int trackId) async {
    await _database.trackLearningOrderDao.deleteByTrack(trackId);
  }
}
