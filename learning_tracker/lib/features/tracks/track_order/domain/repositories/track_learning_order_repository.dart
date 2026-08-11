import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

abstract class TrackLearningOrderRepository {
  /// Returns ordered sedarim (level1 containers) for the curriculum.
  /// Falls back to canonical sort_order when no custom order is saved.
  ///
  /// [allItems] is the full flat content tree for the curriculum (as
  /// returned by `ContentRepository.getContentForCurriculum`). Callers
  /// resolve it before calling in — AUD-tracks-15/SM-8: this repository
  /// never talks to `ContentRepository` directly.
  Future<List<LearningOrderItem>> getSedarimOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  );

  /// Returns ordered masechtos (level2 containers) for the curriculum.
  /// Falls back to canonical sort_order when no custom order is saved.
  ///
  /// [allItems] — see [getSedarimOrder].
  Future<List<LearningOrderItem>> getMasechtosOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  );

  Future<void> saveSedarimOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items,
  );
  Future<void> saveMasechtosOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items,
  );

  /// Deletes all custom order rows for the curriculum (resets to canonical).
  Future<void> resetToDefault(CurriculumId curriculumId);
}
