import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

/// Thrown by [LearningOrderRepository.saveOrder] when the caller is in child
/// mode and a parent has locked the ordering.
class ParentControlException extends PermissionException {
  const ParentControlException()
    : super('Ordering is restricted by parent controls');
}

/// Repository for managing custom learning order per curriculum.
///
/// Implements D7: learning_order table is the override; `ContentItem.sortOrder`
/// (from the bundled JSON hierarchy assets — there is no `content_items`
/// database table) is the fallback when no custom order exists.
abstract class LearningOrderRepository {
  /// Get the ordered list of drag-level items for a curriculum.
  ///
  /// Returns custom order if rows exist in learning_order table;
  /// otherwise falls back to `ContentItem.sortOrder` (natural Sefaria order).
  ///
  /// [allItems] is the full flat content tree for [curriculumId] (as
  /// returned by `ContentRepository.getContentForCurriculum`). Callers
  /// resolve it before calling in — AUD-tracks-15/SM-8: this repository
  /// never talks to `ContentRepository` directly, only to its own DAO.
  Future<List<LearningOrderItem>> getOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  );

  /// Save a new custom order for a curriculum.
  ///
  /// Upserts one row per item with userSortOrder = index in [items], wrapped
  /// in a single DB transaction so a mid-loop crash cannot leave a
  /// half-shuffled state.
  ///
  /// Throws [ParentControlException] when [isChildRestricted] is true —
  /// enforcement happens here rather than at the UI layer (T1.9-ish, T2.10).
  Future<void> saveOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items, {
    bool isChildRestricted = false,
  });

  /// Reset to default order by deleting all learning_order rows for curriculum.
  Future<void> resetToDefault(CurriculumId curriculumId);
}
