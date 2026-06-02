import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/utils/gematriya.dart';

/// The single rendering function for every curriculum-aware display string
/// in the UI. Breadcrumbs, row labels, AppBar titles, reader headers — all
/// flow through here so the locale rules and prefix conventions cannot
/// drift between screens.
///
/// Rules (in plain English):
///   - **Named** levels (Sefer, Masechta, Seder, Parsha, Mussar Sefer):
///     show the localized name bare, no level-word prefix. Strip any
///     redundant Hebrew structural prefix carried over from the data.
///   - **Ordinal** levels (Perek, Daf, Amud, Pasuk, Mishna, Halacha, Shaar,
///     etc.): prefix the level word and localize the value. In Hebrew mode
///     Arabic integers convert to gematriya ("3" → "ג", "11" → "יא");
///     bare Hebrew letters pass through; daf "a"/"b" amud values become
///     "א"/"ב". In English mode the raw value passes through.
///
/// See `LevelLabels.valueKind` and `LevelLabels.prefixLabelInDisplay`.
class CurriculumLabelRenderer {
  CurriculumLabelRenderer._();

  /// Render one (level, value) pair.
  ///
  /// [hebrewName] is the optional pre-known Hebrew name for [rawValue] when
  /// the level is named — typically `ContentItem.displayNameHe`. For ordinal
  /// levels, [hebrewName] is ignored.
  ///
  /// [parentL1Value] is needed for curricula whose level structure varies by
  /// top-level book (Mussar — Shaarei Teshuvah's L2 is Shaar not Perek).
  ///
  /// [transliterationVariant] controls the dialect used for English-mode
  /// named values (Bereishis vs Bereshit). Defaults to Ashkenazi.
  static String renderValue({
    required CurriculumId curriculumId,
    required int level,
    required String rawValue,
    required bool useHebrew,
    String? hebrewName,
    String? parentL1Value,
    TransliterationVariant transliterationVariant =
        TransliterationVariant.ashkenazi,
  }) {
    final labels = CurriculumLabels.level(
      curriculumId,
      level,
      parentL1Value: parentL1Value,
    );

    switch (labels.valueKind) {
      case LevelValueKind.named:
        final name = useHebrew
            ? (hebrewName != null && hebrewName.isNotEmpty
                  ? CurriculumLabels.stripStructuralPrefix(
                      hebrewName,
                      curriculumId: curriculumId,
                    )
                  : rawValue)
            : CurriculumLabels.transliterateNamedValue(
                rawValue,
                variant: transliterationVariant,
              );
        return labels.prefixLabelInDisplay
            ? '${labels.inLanguage(useHebrew: useHebrew, variant: transliterationVariant)} $name'
            : name;

      case LevelValueKind.ordinal:
        final localizedValue = _localizeOrdinalValue(rawValue, useHebrew);
        return labels.prefixLabelInDisplay
            ? '${labels.inLanguage(useHebrew: useHebrew, variant: transliterationVariant)} $localizedValue'
            : localizedValue;
    }
  }

  /// Render every level of a path in order, returning one display string per
  /// segment. Drop into a breadcrumb widget directly.
  ///
  /// [rawSegmentValues] is the raw value at each level (1..N).
  /// [hebrewNamesPerSegment], when provided, supplies the Hebrew name for
  /// each named segment in parallel (use null at ordinal-level positions).
  static List<String> renderBreadcrumb({
    required CurriculumId curriculumId,
    required List<String> rawSegmentValues,
    required bool useHebrew,
    List<String?>? hebrewNamesPerSegment,
    TransliterationVariant transliterationVariant =
        TransliterationVariant.ashkenazi,
  }) {
    final out = <String>[];
    final parentL1 = rawSegmentValues.isNotEmpty
        ? rawSegmentValues.first
        : null;
    for (var i = 0; i < rawSegmentValues.length; i++) {
      out.add(
        renderValue(
          curriculumId: curriculumId,
          level: i + 1,
          rawValue: rawSegmentValues[i],
          useHebrew: useHebrew,
          hebrewName:
              hebrewNamesPerSegment != null && i < hebrewNamesPerSegment.length
              ? hebrewNamesPerSegment[i]
              : null,
          parentL1Value: parentL1,
          transliterationVariant: transliterationVariant,
        ),
      );
    }
    return out;
  }

  /// Render a [ContentItem]. Returns either the leaf segment alone or the
  /// full ancestor chain joined by [separator].
  ///
  /// The item carries level1..level4 (raw values) plus the pre-rendered
  /// displayNameHe/displayNameEn (used as the Hebrew/English name source for
  /// named levels). The renderer derives a per-segment Hebrew name from the
  /// item's displayNameHe by stripping the structural prefix.
  static String renderForItem(
    ContentItem item, {
    required bool useHebrew,
    bool fullPath = false,
    String separator = ' › ',
    TransliterationVariant transliterationVariant =
        TransliterationVariant.ashkenazi,
  }) {
    final id = _resolveCurriculumId(item.curriculumId);
    if (id == null) {
      return useHebrew ? item.displayNameHe : item.displayNameEn;
    }

    final rawSegments = _rawSegmentsFromItem(item);
    if (rawSegments.isEmpty) {
      return useHebrew ? item.displayNameHe : item.displayNameEn;
    }

    final hebrewNames = List<String?>.filled(rawSegments.length, null);
    final lastIdx = rawSegments.length - 1;
    hebrewNames[lastIdx] = item.displayNameHe;

    final segments = renderBreadcrumb(
      curriculumId: id,
      rawSegmentValues: rawSegments,
      useHebrew: useHebrew,
      hebrewNamesPerSegment: hebrewNames,
      transliterationVariant: transliterationVariant,
    );

    if (fullPath) return segments.join(separator);
    return segments.last;
  }

  /// Returns the parent segment of [item] — i.e. the display string for the
  /// level one above the item's deepest non-null level. Used by the reader
  /// page's two-line AppBar to show "פרק ג" big and "בראשית" small.
  ///
  /// Returns null when the item is already at level 1 (no parent).
  static String? renderParentForItem(
    ContentItem item, {
    required bool useHebrew,
    TransliterationVariant transliterationVariant =
        TransliterationVariant.ashkenazi,
  }) {
    final id = _resolveCurriculumId(item.curriculumId);
    if (id == null) return null;

    final rawSegments = _rawSegmentsFromItem(item);
    if (rawSegments.length < 2) return null;

    final parentSegments = rawSegments.sublist(0, rawSegments.length - 1);
    final segments = renderBreadcrumb(
      curriculumId: id,
      rawSegmentValues: parentSegments,
      useHebrew: useHebrew,
      transliterationVariant: transliterationVariant,
    );
    return segments.last;
  }

  // ---------- label accessors ----------

  /// Returns the Hebrew display name of [item], or null when [item] is null.
  ///
  /// All code outside `core/labels/` that needs `ContentItem.displayNameHe`
  /// must call this helper so the field access stays within this package.
  static String? hebrewNameOf(ContentItem? item) => item?.displayNameHe;

  // ---------- helpers ----------

  /// Convert a raw ordinal value (data form) to its localized display.
  ///
  /// "1" / "23"           → gematriya (Hebrew) or as-is (English)
  /// "א" / "יא"           → as-is in Hebrew; gematriya-parsed back to Arabic
  ///                        for English ("11")
  /// "a" / "b"            → "א" / "ב" in Hebrew; as-is in English
  /// "Mesillat Yesharim"  → as-is (caller passed a non-ordinal; render
  ///                        defensively so we don't drop the value)
  static String _localizeOrdinalValue(String rawValue, bool useHebrew) {
    if (rawValue.isEmpty) return rawValue;

    // Daf amud letters.
    if (rawValue == 'a') return useHebrew ? 'א' : 'a';
    if (rawValue == 'b') return useHebrew ? 'ב' : 'b';

    // Pure integer.
    final n = int.tryParse(rawValue);
    if (n != null) {
      if (useHebrew && n >= 1 && n <= 999) return Gematriya.forNumber(n);
      return rawValue;
    }

    // Already-Hebrew gematriya value.
    final parsed = Gematriya.parse(rawValue);
    if (parsed != null) {
      return useHebrew ? rawValue : '$parsed';
    }

    // Anything else (e.g. corrupt "h" data, named values misrouted): keep
    // as-is. Bad data renders loudly rather than silently transforming.
    return rawValue;
  }

  /// Build the non-null level segments from a ContentItem in order.
  static List<String> _rawSegmentsFromItem(ContentItem item) {
    final segs = <String>[item.level1];
    if (item.level2 != null) segs.add(item.level2!);
    if (item.level3 != null) segs.add(item.level3!);
    if (item.level4 != null) segs.add(item.level4!);
    return segs;
  }

  /// Map [ContentItem.curriculumId] (storage key string) to [CurriculumId].
  static CurriculumId? _resolveCurriculumId(String storageKey) {
    for (final id in CurriculumId.values) {
      if (id.storageKey == storageKey) return id;
    }
    return null;
  }
}
