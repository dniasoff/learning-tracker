import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

// ── OrderingLevel ─────────────────────────────────────────────────────────────

/// Discriminator for the two configurable ordering levels within a track.
///
/// The track learning-order screen lets the user drag-and-drop at two
/// distinct hierarchy levels:
///
/// * [sedarim] — Seder (level1 containers; e.g. "Seder Zeraim").
/// * [masechtos] — Masechta / Siman / Sefer (level2 containers within a
///   seder; the second-level grouping varies by curriculum but the
///   ordering mechanics are the same).
///
/// [OrderingLevel] replaces the two separate method pairs
/// (`getSedarimOrder` / `getMasechtosOrder` and their `save*` counterparts)
/// with a single typed discriminator so callers can branch on a value
/// instead of calling different methods. This pairs with the [TrackOrder]
/// aggregate and [MasechtaOrderingPolicy].
enum OrderingLevel {
  /// Seder-level reordering (level1 containers).
  sedarim,

  /// Masechta-level reordering (level2 containers, ordered within their
  /// parent seder's position). Seder order is respected when computing
  /// the masechta list — see [MasechtaOrderingPolicy].
  masechtos,
}

// ── TrackOrder ────────────────────────────────────────────────────────────────

/// Aggregate capturing the user's custom ordering for one level of a track's
/// curriculum hierarchy.
///
/// The aggregate pairs the [items] (ordered list) with the [level] that the
/// ordering applies to and the [curriculumId] + [trackId] that scope it,
/// giving consumers a self-describing value rather than an anonymous
/// `List<LearningOrderItem>`.
///
/// ### Usage
/// [TrackLearningOrderRepository] returns a [TrackOrder] from
/// `getSedarimOrder` / `getMasechtosOrder`. Presentation providers unwrap
/// [items] for the drag-and-drop widget and call `saveOrder` to persist.
///
/// ### Invariants
/// * [items] is never empty once loaded — the repository returns canonical
///   order as a fallback when no user order is saved ([isCustomOrdered]
///   is false on each item in that case).
/// * All items in [items] belong to [level]; no mixing.
class TrackOrder {
  const TrackOrder({
    required this.trackId,
    required this.curriculumId,
    required this.level,
    required this.items,
  });

  /// Database ID of the track this ordering belongs to.
  final int trackId;

  /// The curriculum whose hierarchy is being ordered.
  final CurriculumId curriculumId;

  /// Which hierarchy level [items] covers.
  final OrderingLevel level;

  /// The ordered list of items at [level].
  ///
  /// Items are sorted by [LearningOrderItem.userSortOrder] (ascending).
  /// When [LearningOrderItem.isCustomOrdered] is false the user has not yet
  /// saved a custom order and the canonical content sort_order is used.
  final List<LearningOrderItem> items;

  /// True when all [items] are using the user's custom ordering
  /// (i.e. none are falling back to canonical order).
  bool get isFullyCustomOrdered => items.every((i) => i.isCustomOrdered);

  /// True when any [items] are using the user's custom ordering.
  bool get hasAnyCustomOrder => items.any((i) => i.isCustomOrdered);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackOrder &&
          other.trackId == trackId &&
          other.curriculumId == curriculumId &&
          other.level == level &&
          _itemsEqual(other.items));

  bool _itemsEqual(List<LearningOrderItem> other) {
    if (other.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (items[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(trackId, curriculumId, level, items.length);

  @override
  String toString() =>
      'TrackOrder(track: $trackId, curriculum: $curriculumId, '
      'level: $level, items: ${items.length})';
}
