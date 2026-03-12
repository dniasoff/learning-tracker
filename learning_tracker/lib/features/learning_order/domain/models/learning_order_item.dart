import 'package:freezed_annotation/freezed_annotation.dart';

part 'learning_order_item.freezed.dart';

/// A single item displayed in the learning order drag-and-drop screen.
///
/// Represents items at the curriculum's configurable grouping level
/// (masechta for Mishnayos/Bavli/Yerushalmi, siman for MB, sefer for Chumash).
@freezed
abstract class LearningOrderItem with _$LearningOrderItem {
  const factory LearningOrderItem({
    required String sefariaRef,
    required String displayNameHe,
    required String displayNameEn,
    required int userSortOrder,

    /// False if this item is using fallback sort from content_items.sort_order.
    @Default(false) bool isCustomOrdered,
  }) = _LearningOrderItem;
}
