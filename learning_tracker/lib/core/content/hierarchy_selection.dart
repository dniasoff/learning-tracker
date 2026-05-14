/// A selection within a content hierarchy (Seder → Masechta → Perek → Mishna).
///
/// Null levels act as wildcards — a [HierarchySelection] with only [level1]
/// set covers every item within that top-level container.
class HierarchySelection {
  final String? level1;
  final String? level2;
  final String? level3;
  final String? level4;

  const HierarchySelection({
    this.level1,
    this.level2,
    this.level3,
    this.level4,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HierarchySelection &&
          level1 == other.level1 &&
          level2 == other.level2 &&
          level3 == other.level3 &&
          level4 == other.level4;

  @override
  int get hashCode => Object.hash(level1, level2, level3, level4);
}
