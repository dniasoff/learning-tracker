import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning_order/domain/models/learning_order_item.dart';

/// Repository for managing custom learning order per curriculum.
///
/// Implements D7: learning_order table is the override; content_items.sort_order
/// is the fallback when no custom order exists.
abstract class LearningOrderRepository {
  /// Get the ordered list of drag-level items for a curriculum.
  ///
  /// Returns custom order if rows exist in learning_order table;
  /// otherwise falls back to content_items.sort_order (natural Sefaria order).
  Future<List<LearningOrderItem>> getOrder(CurriculumId curriculumId);

  /// Save a new custom order for a curriculum.
  ///
  /// Upserts one row per item with userSortOrder = index in [items].
  Future<void> saveOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items,
  );

  /// Reset to default order by deleting all learning_order rows for curriculum.
  Future<void> resetToDefault(CurriculumId curriculumId);
}
