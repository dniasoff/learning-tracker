/// Compares two strings naturally: digit runs are compared numerically, all
/// other runs lexically. Use for sefariaRef tie-breaks so `Mishnah Berakhot
/// 1:2` sorts before `Mishnah Berakhot 1:10` (otherwise `1:10` would precede
/// `1:2` lexically).
int compareNaturalString(String a, String b) {
  final regex = RegExp(r'\d+|\D+');
  final aParts = regex.allMatches(a).map((m) => m.group(0)!).toList();
  final bParts = regex.allMatches(b).map((m) => m.group(0)!).toList();
  final limit = aParts.length < bParts.length ? aParts.length : bParts.length;
  for (var i = 0; i < limit; i++) {
    final aPart = aParts[i];
    final bPart = bParts[i];
    final aNum = int.tryParse(aPart);
    final bNum = int.tryParse(bPart);
    final cmp = (aNum != null && bNum != null)
        ? aNum.compareTo(bNum)
        : aPart.compareTo(bPart);
    if (cmp != 0) return cmp;
  }
  return aParts.length.compareTo(bParts.length);
}
