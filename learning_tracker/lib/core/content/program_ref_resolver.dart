import 'package:learning_tracker/core/content/content_index.dart';

/// Source of a raw, calendar-style sefaria ref for a given program day.
///
/// Abstracted so the resolver can be tested without spinning up a real
/// calendar service. Production wires this to the local calendar engine
/// (DNI-330).
abstract class ProgramRefSource {
  /// Returns the raw calendar ref (e.g. `Hullin 7`, `Mishnah Berakhot 1:1`)
  /// for [programId] at [dayOffset] (0 = anchor day, 1 = next day, …).
  /// Returns null when the program has no entry for that day.
  String? rawRefFor({required String programId, required int dayOffset});
}

/// Single resolver mapping `(programId, dayOffset) → canonical sefariaRef`.
///
/// Dashboard, scheduler, and reader all consume this same resolver so they
/// agree on which `ContentItem` a calendar entry points to (FR16). The
/// resolver never falls back to the raw display string — if no
/// [ContentIndex] entry matches, [resolve] returns null. T1.7 forbids
/// persisting human-readable strings as sefariaRefs because the reader
/// breaks on them.
class ProgramRefResolver {
  ProgramRefResolver({required this.index, required this.programRefSource});

  final ContentIndex index;
  final ProgramRefSource programRefSource;

  /// Resolves [programId] + [dayOffset] to a canonical sefariaRef that
  /// exists in [index], or null when:
  ///  - the program has no calendar entry for that day, or
  ///  - the calendar's raw ref does not match any indexed content item.
  String? resolve({required String programId, required int dayOffset}) {
    final raw = programRefSource.rawRefFor(
      programId: programId,
      dayOffset: dayOffset,
    );
    if (raw == null) return null;

    // Fast path: exact match against the canonical key.
    final direct = index.lookup(raw);
    if (direct != null) return direct.sefariaRef;

    for (final candidate in _refVariants(raw)) {
      final hit = index.lookup(candidate);
      if (hit != null) return hit.sefariaRef;
    }
    return null;
  }
}

/// Generates conservative normalisation variants for [raw].
///
/// Calendar feeds sometimes emit refs with extra whitespace or older
/// transliterations (`Mishna` → `Mishnah`). The resolver tries each variant
/// against [ContentIndex] in turn. Variants must NOT be lossy — we only
/// collapse whitespace and try a single well-known transliteration swap;
/// anything more aggressive risks resolving to the wrong content item,
/// which is exactly the bug FR16 closes.
Iterable<String> _refVariants(String raw) sync* {
  final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (collapsed.isEmpty) return;
  yield collapsed;
  final lower = collapsed.toLowerCase();
  if (lower.startsWith('mishna ')) {
    yield 'Mishnah ${collapsed.substring('mishna '.length)}';
  } else if (lower.startsWith('mishnah ')) {
    yield 'Mishna ${collapsed.substring('mishnah '.length)}';
  }
}
