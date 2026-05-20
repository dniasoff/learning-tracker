import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

/// Pure domain service that orders masechtos (level2 containers) by the
/// parent seder's user-defined position, falling back to the canonical
/// source sort_order when the user has not yet customised the seder order.
///
/// ### Why a dedicated policy class?
/// The ordering logic in `TrackLearningOrderRepositoryImpl._buildMasechtosIndex`
/// is non-trivial: it must:
///   1. Build a seder priority map from the user's saved seder order.
///   2. Filter `allItems` to level2-only containers (excluding perakim /
///      mishnayot that also have `level2 != null`).
///   3. Sort the masechtos by parent-seder priority, then by canonical
///      sort_order within the same seder.
///   4. Return a stable ref→(he, en, sortOrder) index.
///
/// Extracting this into a pure domain service:
///   * Makes the logic unit-testable without a real DB or content repository.
///   * Unblocks W4.22 (`_buildMasechtosIndex` removal from the repository impl).
///   * Is the canonical home for the seder→masechta dependency that the
///     repository impl currently encodes inline.
///
/// ### Input contract
/// * [allItems] — the **complete** flat content tree for the curriculum
///   (returned by `ContentRepository.getContentForCurriculum`). Must include
///   both container nodes and leaf nodes so the level-filter can be applied.
/// * [sedarimIndex] — the seder ref → sortOrder index (canonical or
///   user-customised). Callers build this from `_buildSedarimIndex`; the
///   policy accepts the result so it remains DB-free.
/// * [savedSederOrder] — the user's saved seder refs in priority order. May
///   be empty when no custom seder order has been saved.
///
/// ### Output contract
/// Returns a `Map<String, ({String he, String en, int sortOrder})>` where:
///   * The key is the masechta's `sefariaRef`.
///   * `sortOrder` is the masechta's final position (0-based, ascending).
class MasechtaOrderingPolicy {
  const MasechtaOrderingPolicy();

  /// Compute the masechtos sort-order index.
  ///
  /// The returned map maps each masechta's [ContentItem.sefariaRef] to its
  /// display names and its final `sortOrder` integer (the position in the
  /// sorted list, 0-based ascending).
  ///
  /// This is a pure function — the same inputs always produce the same output.
  Map<String, ({String he, String en, int sortOrder})> buildIndex({
    required List<ContentItem> allItems,
    required Map<String, ({String he, String en, int sortOrder})> sedarimIndex,
    required List<String> savedSederOrder,
  }) {
    // ── Build seder priority map ──────────────────────────────────────────────
    //
    // The user's saved seder order is a list of sefariaRefs in their preferred
    // order. We assign each one a priority 0, 1, 2, … and fall back to a large
    // canonical sort_order-derived number for sedarim not yet saved.
    final sederUserOrder = _buildSederPriorityMap(
      savedSederOrder: savedSederOrder,
      sedarimIndex: sedarimIndex,
    );

    // ── Filter to level2-only containers ─────────────────────────────────────
    //
    // A masechta is a content item where:
    //   • level2 is set (it belongs to a seder's children)
    //   • level3 and level4 are null (it's the second level, not deeper)
    //   • isLeaf is false (it's a container, not a daf/perek/mishna)
    //
    // The level3/level4 null check is essential to exclude perakim and
    // mishnayot, which also have level2 != null but are deeper containers.
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
            final pa = _sederPriority(a.level1, sederUserOrder, sedarimIndex);
            final pb = _sederPriority(b.level1, sederUserOrder, sedarimIndex);
            if (pa != pb) return pa.compareTo(pb);
            return a.sortOrder.compareTo(b.sortOrder);
          });

    // ── Build output index ────────────────────────────────────────────────────
    final result = <String, ({String he, String en, int sortOrder})>{};
    for (var i = 0; i < masechtos.length; i++) {
      final item = masechtos[i];
      result.putIfAbsent(
        item.sefariaRef,
        () => (he: item.displayNameHe, en: item.displayNameEn, sortOrder: i),
      );
    }
    return result;
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// Maps each seder sefariaRef to its user-priority integer.
  ///
  /// Sedarim in [savedSederOrder] get priority 0, 1, 2, … in order.
  /// Sedarim not in [savedSederOrder] get a large fallback derived from their
  /// canonical sort_order (bucketed 1000+) so they sort after user-ordered ones.
  Map<String, int> _buildSederPriorityMap({
    required List<String> savedSederOrder,
    required Map<String, ({String he, String en, int sortOrder})> sedarimIndex,
  }) {
    final userOrder = <String, int>{};
    for (var i = 0; i < savedSederOrder.length; i++) {
      final ref = savedSederOrder[i];
      if (sedarimIndex.containsKey(ref)) {
        userOrder[ref] = i;
      }
    }
    return userOrder;
  }

  /// Returns the effective seder sort priority for [level1].
  ///
  /// Uses [userOrder] when available, otherwise falls back to 1000 + the
  /// canonical sort_order from [sedarimIndex]. The 1000-offset ensures
  /// user-ordered sedarim always sort before un-ordered ones.
  int _sederPriority(
    String level1,
    Map<String, int> userOrder,
    Map<String, ({String he, String en, int sortOrder})> sedarimIndex,
  ) {
    final userIdx = userOrder[level1];
    if (userIdx != null) return userIdx;
    final src = sedarimIndex[level1]?.sortOrder ?? (1 << 30);
    return 1000 + src;
  }
}
