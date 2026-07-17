import 'package:freezed_annotation/freezed_annotation.dart';

part 'content_item.freezed.dart';

/// A single item in a curriculum's content hierarchy.
///
/// Represents both container nodes (seder, masechta, perek) and leaf nodes
/// (individual mishna, daf, pasuk, etc.). Maps directly to the
/// `content_items` table schema.
///
/// `@freezed` generates field-wise `==`/`hashCode`/`copyWith`/`toString` so
/// two items are only equal when every field matches — a hand-rolled
/// `==` here previously compared only [curriculumId]/[sefariaRef], silently
/// treating items that differ in display text or sort order as equal
/// (AUD-core-network-01).
@freezed
abstract class ContentItem with _$ContentItem {
  const factory ContentItem({
    /// Which curriculum this item belongs to (uses CurriculumId.storageKey).
    required String curriculumId,

    /// Top-level grouping (e.g., seder name, masechta name, sefer name).
    required String level1,

    /// Second-level grouping (e.g., masechta, daf, parsha).
    String? level2,

    /// Third-level grouping (e.g., perek, amud, perek).
    String? level3,

    /// Fourth-level grouping (e.g., mishna number, pasuk).
    String? level4,

    /// Hebrew display name for this item.
    required String displayNameHe,

    /// English display name for this item.
    required String displayNameEn,

    /// Sefaria reference string for fetching text content.
    required String sefariaRef,

    /// Sort order within the full curriculum (global ordering).
    required int sortOrder,

    /// Whether this is a leaf node (actual content) vs. a container.
    required bool isLeaf,
  }) = _ContentItem;
}
