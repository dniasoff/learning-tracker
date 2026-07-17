import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

/// Source of a raw, calendar-style sefaria ref for a given program day.
///
/// Abstracted so the resolver can be tested without spinning up a real
/// calendar service. Not currently wired to any production implementation —
/// no ticket tracks production `ProgramRefSource` wiring yet (DNI-330 is
/// Story 25.9, the `core/labels/` rebuild; it is unrelated to calendar-ref
/// resolution). See [ProgramRefResolver]'s doc comment for the current
/// wiring status.
abstract class ProgramRefSource {
  /// Returns the raw calendar ref (e.g. `Hullin 7`, `Mishnah Berakhot 1:1`)
  /// for [programId] at [dayOffset] (0 = anchor day, 1 = next day, …).
  /// Returns null when the program has no entry for that day.
  String? rawRefFor({required String programId, required int dayOffset});
}

/// Single resolver mapping `(programId, dayOffset) → canonical sefariaRef`.
///
/// Built under DNI-329 (Story 25.8) to close FR16 ("dashboard, scheduler,
/// and reader all consume this same resolver so they agree on which
/// `ContentItem` a calendar entry points to"). FR16 is only partially
/// realized as of this writing:
///  - No production site calls [resolve] with a real `programId`/
///    `dayOffset` — [ProgramRefSource] has zero production implementations.
///  - Scheduler's own calendar-to-content matching
///    (`resolveProgramTodayRefs` in `sefaria_ref_matcher.dart`) is a
///    separate, independently-evolved fuzzy matcher (range expansion,
///    container fallback, etc.) that this class does not share.
///  - Scheduler's daf-grouping (`collapseDafTasks` in
///    `scheduler_providers.dart`) uses [lookupWithVariants] so that one
///    lookup at least shares this class's normalization rules instead of a
///    bare [ContentIndex.lookup].
///  - Dashboard and the reader (`text_display_screen.dart`) still call
///    [ContentIndex.lookup] directly.
/// Full FR16 consolidation is not yet tracked under a ticket.
///
/// The resolver never falls back to the raw display string — if no
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
    return lookupWithVariants(index, raw)?.sefariaRef;
  }

  /// Resolves [ref] against [index], trying whitespace/transliteration
  /// variants (see [_refVariants]) when an exact match fails.
  ///
  /// Static and index-only (no [ProgramRefSource] needed) so callers that
  /// already hold a ref string — rather than a `(programId, dayOffset)`
  /// pair — can share this class's normalization rules instead of a bare
  /// [ContentIndex.lookup]. Used by [resolve] and by
  /// `collapseDafTasks` in `scheduler_providers.dart`.
  static ContentItem? lookupWithVariants(ContentIndex index, String ref) {
    // Fast path: exact match against the canonical key.
    final direct = index.lookup(ref);
    if (direct != null) return direct;

    for (final candidate in _refVariants(ref)) {
      final hit = index.lookup(candidate);
      if (hit != null) return hit;
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
