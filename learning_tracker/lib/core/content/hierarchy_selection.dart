import 'package:freezed_annotation/freezed_annotation.dart';

part 'hierarchy_selection.freezed.dart';

/// A selection within a content hierarchy (Seder → Masechta → Perek → Mishna).
///
/// Null levels act as wildcards — a [HierarchySelection] with only [level1]
/// set covers every item within that top-level container.
@freezed
abstract class HierarchySelection with _$HierarchySelection {
  const factory HierarchySelection({
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) = _HierarchySelection;
}
