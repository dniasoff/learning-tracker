import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

/// Describes how a composite curriculum (e.g. Tanach) is assembled from its
/// source curricula (e.g. Chumash + Nach), and what synthetic container items
/// should be prepended before each source's items are merged in.
///
/// This data-driven strategy replaces the hardcoded `_compositeSources` map
/// and `_tanachTorahContainer` constant that previously lived directly in
/// [ContentRepositoryImpl].
///
/// Usage inside the repository:
/// ```dart
/// final strategy = CompositeCurriculumStrategy.forKey(compositeKey);
/// if (strategy != null) {
///   // Use strategy.sources and strategy.preamble instead of hardcoded values.
/// }
/// ```
class CompositeCurriculumStrategy {
  const CompositeCurriculumStrategy({
    required this.compositeKey,
    required this.sources,
    this.preamble = const [],
    this.remapSource,
  });

  /// The storage key of the composite curriculum (e.g. `'tanach'`).
  final String compositeKey;

  /// Ordered list of source curriculum storage keys to merge in.
  final List<String> sources;

  /// Synthetic [ContentItem] rows to prepend to the assembled list before
  /// any source items are merged.  For Tanach this is the "Torah" section
  /// container that sits above the 5 books of Chumash.
  final List<ContentItem> preamble;

  /// Optional per-source item transformer.  When non-null, called for each
  /// source item before it is appended.  Receives the raw item, the composite
  /// key, the source key, and the current accumulated list length (used as a
  /// sort-order offset so Tanach's Nach items sort after Chumash items).
  ///
  /// When null, items are remapped via the default pass-through logic (all
  /// fields copied, `curriculumId` → [compositeKey], `sortOrder` + offset).
  final ContentItem Function(
    ContentItem item,
    String compositeKey,
    String source,
    int offset,
  )?
  remapSource;

  // ── Static registry ─────────────────────────────────────────────────────

  /// All known composite strategies, keyed by [compositeKey].
  static final Map<String, CompositeCurriculumStrategy> _registry = {
    'tanach': const CompositeCurriculumStrategy(
      compositeKey: 'tanach',
      sources: ['chumash', 'nach'],
      preamble: [
        ContentItem(
          curriculumId: 'tanach',
          level1: 'Torah',
          displayNameHe: 'תורה',
          displayNameEn: 'Torah',
          sefariaRef: 'Torah',
          sortOrder: -1, // sorted to the top
          isLeaf: false,
        ),
      ],
      remapSource: _remapTanach,
    ),
  };

  /// Returns the strategy for [compositeKey], or `null` if [compositeKey] is
  /// not a composite curriculum.
  static CompositeCurriculumStrategy? forKey(String compositeKey) =>
      _registry[compositeKey];

  /// Returns `true` if [storageKey] is a registered composite curriculum.
  static bool isComposite(String storageKey) =>
      _registry.containsKey(storageKey);

  /// Returns `true` if a `level1` mark with [level1Value] on the composite
  /// curriculum [compositeKey] targets a SYNTHETIC preamble container (e.g.
  /// Tanach's 'Torah' section) rather than a real source curriculum unit.
  ///
  /// Marking such a synthetic container as a single blanket `level1` ledger row
  /// over-credits every leaf beneath it (the whole Torah from a one-book mark);
  /// the canonical place to record that learning is the underlying source
  /// curriculum (Chumash), which propagates up to the composite by canonical
  /// leaf. Callers use this to refuse persisting the synthetic-container mark.
  static bool isSyntheticContainerLevel1(
    String compositeKey,
    String level1Value,
  ) {
    final strategy = _registry[compositeKey];
    if (strategy == null) return false;
    return strategy.preamble.any((p) => p.level1 == level1Value);
  }

  // ── Default remapper ─────────────────────────────────────────────────────

  /// Applies the composite curriculum's [remapSource] to [item], or falls
  /// back to a simple copy that updates [curriculumId] and adds [offset] to
  /// [sortOrder].
  ContentItem remap({
    required ContentItem item,
    required String source,
    required int offset,
  }) {
    if (remapSource != null) {
      return remapSource!(item, compositeKey, source, offset);
    }
    return ContentItem(
      curriculumId: compositeKey,
      level1: item.level1,
      level2: item.level2,
      level3: item.level3,
      level4: item.level4,
      displayNameHe: item.displayNameHe,
      displayNameEn: item.displayNameEn,
      sefariaRef: item.sefariaRef,
      sortOrder: item.sortOrder + offset,
      isLeaf: item.isLeaf,
    );
  }

  // ── Tanach-specific remapper ─────────────────────────────────────────────

  /// Remaps a source item for Tanach composition.
  ///
  /// Chumash data is natively 3-level (Sefer / Perek / Pasuk); we shift all
  /// levels up by one so each book sits under the synthetic "Torah" section,
  /// matching Nach's Section / Sefer / Perek / Pasuk hierarchy.
  ///
  /// Nach items pass through unchanged (already 4-level).
  static ContentItem _remapTanach(
    ContentItem item,
    String compositeKey,
    String source,
    int offset,
  ) {
    if (source == 'chumash') {
      return ContentItem(
        curriculumId: compositeKey,
        level1: 'Torah',
        level2: item.level1,
        level3: item.level2,
        level4: item.level3,
        displayNameHe: item.displayNameHe,
        displayNameEn: item.displayNameEn,
        sefariaRef: item.sefariaRef,
        sortOrder: item.sortOrder + offset,
        isLeaf: item.isLeaf,
      );
    }
    return ContentItem(
      curriculumId: compositeKey,
      level1: item.level1,
      level2: item.level2,
      level3: item.level3,
      level4: item.level4,
      displayNameHe: item.displayNameHe,
      displayNameEn: item.displayNameEn,
      sefariaRef: item.sefariaRef,
      sortOrder: item.sortOrder + offset,
      isLeaf: item.isLeaf,
    );
  }
}
