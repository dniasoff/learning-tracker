import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'content_index.g.dart';
part 'content_index.freezed.dart';

/// Adjacent siblings of a [ContentItem] within its curriculum's leaf order.
@freezed
abstract class AdjacentItems with _$AdjacentItems {
  const factory AdjacentItems({ContentItem? prev, ContentItem? next}) =
      _AdjacentItems;
}

/// O(1) ref → item index across all 9 curricula.
///
/// Built once from each curriculum's full content list and held in a
/// keepAlive Riverpod provider so `lookup` and `adjacent` are constant-time
/// after the first warmup. Replaces the prior O(N×9) scan in
/// `CurriculumLabel.breadcrumb()` and similar lookups (NFR22).
class ContentIndex {
  ContentIndex._({
    required Map<String, ContentItem> byRef,
    required Map<String, List<ContentItem>> leavesByCurriculum,
    required Map<String, int> leafIndexByRef,
  }) : _byRef = byRef,
       _leavesByCurriculum = leavesByCurriculum,
       _leafIndexByRef = leafIndexByRef;

  final Map<String, ContentItem> _byRef;
  final Map<String, List<ContentItem>> _leavesByCurriculum;
  final Map<String, int> _leafIndexByRef;

  /// Total number of indexed items across all curricula.
  int get size => _byRef.length;

  /// Returns the [ContentItem] for [sefariaRef] in O(1), or null if no
  /// match exists in any curriculum.
  ContentItem? lookup(String sefariaRef) => _byRef[sefariaRef];

  /// Returns the sefariaRef of the first leaf in [curriculumId]'s leaf order
  /// (sorted by `sortOrder`), or null when the curriculum is unknown or has
  /// no leaf items.
  ///
  /// Used by [BookmarkRepositoryImpl._getFirstItemId] to avoid an O(N) scan.
  String? firstLeaf(CurriculumId curriculumId) {
    final leaves = _leavesByCurriculum[curriculumId.storageKey];
    return leaves != null && leaves.isNotEmpty ? leaves.first.sefariaRef : null;
  }

  /// Returns the previous and next leaf items sharing the same curriculum
  /// as [sefariaRef], ordered by `sortOrder`. Returns `(null, null)` when
  /// [sefariaRef] is unknown or is a non-leaf container.
  AdjacentItems adjacent(String sefariaRef) {
    final idx = _leafIndexByRef[sefariaRef];
    if (idx == null) return const AdjacentItems();
    final item = _byRef[sefariaRef];
    if (item == null) return const AdjacentItems();
    final leaves = _leavesByCurriculum[item.curriculumId];
    if (leaves == null) return const AdjacentItems();
    final prev = idx > 0 ? leaves[idx - 1] : null;
    final next = idx < leaves.length - 1 ? leaves[idx + 1] : null;
    return AdjacentItems(prev: prev, next: next);
  }

  /// Build a [ContentIndex] from a map of `CurriculumId → List<ContentItem>`.
  /// Used in tests and by the Riverpod provider.
  factory ContentIndex.fromCurricula(
    Map<CurriculumId, List<ContentItem>> byCurriculum,
  ) {
    final byRef = <String, ContentItem>{};
    final leavesByCurriculum = <String, List<ContentItem>>{};
    final leafIndexByRef = <String, int>{};

    for (final entry in byCurriculum.entries) {
      final curriculumKey = entry.key.storageKey;
      final items = entry.value;
      for (final item in items) {
        // First-write-wins: when the same sefariaRef exists in more than one
        // curriculum (e.g. a Chumash pasuk also indexed under Tanach), the
        // curriculum that comes FIRST in CurriculumId.values (the canonical
        // one, e.g. Chumash) wins. Without this, last-write-wins resolved a
        // חומש text's breadcrumb root to 'תורה' (Tanach) instead of 'חומש'.
        byRef.putIfAbsent(item.sefariaRef, () => item);
      }
      final leaves = items.where((i) => i.isLeaf).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      leavesByCurriculum[curriculumKey] = leaves;
      for (var i = 0; i < leaves.length; i++) {
        // First-write-wins to mirror _byRef above, so a colliding ref's leaf
        // position resolves to the same (canonical) curriculum.
        leafIndexByRef.putIfAbsent(leaves[i].sefariaRef, () => i);
      }
    }

    return ContentIndex._(
      byRef: byRef,
      leavesByCurriculum: leavesByCurriculum,
      leafIndexByRef: leafIndexByRef,
    );
  }
}

/// Provides a single [ContentIndex] populated from all 9 curricula.
///
/// `keepAlive: true` ensures the index is built once per app lifetime —
/// rebuilding it would discard the cached map and force a scan of 52K rows.
@Riverpod(keepAlive: true)
Future<ContentIndex> contentIndex(Ref ref) async {
  final byCurriculum = <CurriculumId, List<ContentItem>>{};
  for (final c in CurriculumId.all) {
    byCurriculum[c] = await ref.watch(curriculumContentProvider(c).future);
  }
  return ContentIndex.fromCurricula(byCurriculum);
}
