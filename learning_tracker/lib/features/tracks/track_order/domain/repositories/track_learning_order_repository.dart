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

  /// Saves [items] as the sedarim order: one logged `mainTrackOrder`
  /// change; over 10 changed docs it is online-only (throws while offline).
  Future<void> saveSedarimOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items,
  );

  /// Saves [items] as the masechtos order (see [saveSedarimOrder]).
  Future<void> saveMasechtosOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items,
  );

  /// Resets the curriculum to canonical order: one logged change setting
  /// `ended_at` on every live order doc (never a delete, DNI-476).
  Future<void> resetToDefault(CurriculumId curriculumId);
}
