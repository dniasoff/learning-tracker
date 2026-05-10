import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';

/// Default curriculum configuration constants per D3.
///
/// Default learning cycle: Learn > Chazara 1 (+1 day) > Chazara 2 (+7 days).
/// Users can customize stage count, names, and timing per curriculum.
class CurriculumDefaults {
  CurriculumDefaults._();

  /// Default stage definitions applied to all curricula.
  static const List<DefaultStageDefinition> defaultStages = [
    DefaultStageDefinition(stageOrder: 0, stageName: 'לימוד', delayDays: 0),
    DefaultStageDefinition(stageOrder: 1, stageName: 'חזרה א׳', delayDays: 1),
    DefaultStageDefinition(stageOrder: 2, stageName: 'חזרה ב׳', delayDays: 7),
  ];

  /// Points awarded per stage completion (keyed by stageOrder).
  static const Map<int, int> defaultPointsPerStage = {0: 10, 1: 5, 2: 3};

  /// Default daily learning targets per curriculum (items per day).
  static const Map<CurriculumId, int> defaultDailyTargets = {
    CurriculumId.mishnayos: 3,
    CurriculumId.bavli: 1,
    CurriculumId.yerushalmi: 1,
    CurriculumId.mishnaBerurah: 2,
    CurriculumId.chumash: 5,
    CurriculumId.mishnehTorah: 1,
    CurriculumId.tanach: 3,
    CurriculumId.nach: 3,
    CurriculumId.mussar: 1,
  };
}

class DefaultStageDefinition {
  const DefaultStageDefinition({
    required this.stageOrder,
    required this.stageName,
    required this.delayDays,
    this.scheduleType = ScheduleType.delay,
    this.daysOfWeek,
    this.rollingWindowSize,
  });

  final int stageOrder;
  final String stageName;
  final int delayDays;
  final ScheduleType scheduleType;
  final List<int>? daysOfWeek;
  final int? rollingWindowSize;
}

/// Bilingual, plural-aware label for one hierarchy level of a curriculum.
///
/// Singular and plural forms are both required because UI strings switch:
/// "Select the **Daf** you are up to" (singular) vs "63 **Masechtos**"
/// (plural). Hebrew + English forms are required for the bilingual section
/// headers and Hebrew-terms mode.
class LevelLabels {
  const LevelLabels({
    required this.en,
    required this.enPlural,
    required this.he,
    required this.hePlural,
  });

  final String en;
  final String enPlural;
  final String he;
  final String hePlural;

  /// "מסכתות • Masechtos" — for plural section headers.
  String get bilingualPlural => '$hePlural • $enPlural';

  /// "מסכת • Masechta" — for singular inline display.
  String get bilingualSingular => '$he • $en';

  /// Returns [en] or [he] based on [useHebrew].
  String inLanguage({required bool useHebrew, bool plural = false}) {
    if (useHebrew) return plural ? hePlural : he;
    return plural ? enPlural : en;
  }
}

/// Single source of truth for every curriculum-related label across the app.
///
/// Replaces the old `CurriculumHierarchyDefaults` + a half-dozen private
/// `_getXLabel()` helpers that lived in separate screens with subtly
/// inconsistent values ("Masechos" vs "Masechtos", "Pages" vs "Amud",
/// hard-coded Hebrew prefix lists). All curriculum-aware labels — drill-down
/// breadcrumbs, browse cards, reorder section headers, scope picker, full
/// hierarchy paths, structural prefix stripping — flow through here.
class CurriculumLabels {
  CurriculumLabels._();

  /// Per-curriculum level labels (1-indexed in API, list-indexed top → leaf).
  static const Map<CurriculumId, List<LevelLabels>> _levels = {
    CurriculumId.mishnayos: [
      LevelLabels(
        en: 'Seder',
        enPlural: 'Sedarim',
        he: 'סדר',
        hePlural: 'סדרים',
      ),
      LevelLabels(
        en: 'Masechta',
        enPlural: 'Masechtos',
        he: 'מסכת',
        hePlural: 'מסכתות',
      ),
      LevelLabels(
        en: 'Perek',
        enPlural: 'Perakim',
        he: 'פרק',
        hePlural: 'פרקים',
      ),
      LevelLabels(
        en: 'Mishna',
        enPlural: 'Mishnayos',
        he: 'משנה',
        hePlural: 'משניות',
      ),
    ],
    CurriculumId.bavli: [
      LevelLabels(
        en: 'Seder',
        enPlural: 'Sedarim',
        he: 'סדר',
        hePlural: 'סדרים',
      ),
      LevelLabels(
        en: 'Masechta',
        enPlural: 'Masechtos',
        he: 'מסכת',
        hePlural: 'מסכתות',
      ),
      LevelLabels(en: 'Daf', enPlural: 'Dafim', he: 'דף', hePlural: 'דפים'),
      LevelLabels(
        en: 'Amud',
        enPlural: 'Amudim',
        he: 'עמוד',
        hePlural: 'עמודים',
      ),
    ],
    CurriculumId.yerushalmi: [
      LevelLabels(
        en: 'Masechta',
        enPlural: 'Masechtos',
        he: 'מסכת',
        hePlural: 'מסכתות',
      ),
      LevelLabels(en: 'Daf', enPlural: 'Dafim', he: 'דף', hePlural: 'דפים'),
      LevelLabels(
        en: 'Halacha',
        enPlural: 'Halachos',
        he: 'הלכה',
        hePlural: 'הלכות',
      ),
    ],
    CurriculumId.mishnaBerurah: [
      LevelLabels(
        en: 'Siman',
        enPlural: 'Simanim',
        he: 'סימן',
        hePlural: 'סימנים',
      ),
      LevelLabels(
        en: 'Seif',
        enPlural: 'Seifim',
        he: 'סעיף',
        hePlural: 'סעיפים',
      ),
      LevelLabels(
        en: 'Seif Katan',
        enPlural: 'Seifim Ketanim',
        he: 'סעיף קטן',
        hePlural: 'סעיפים קטנים',
      ),
    ],
    CurriculumId.chumash: [
      LevelLabels(
        en: 'Sefer',
        enPlural: 'Seferim',
        he: 'חומש',
        hePlural: 'חומשים',
      ),
      LevelLabels(
        en: 'Parsha',
        enPlural: 'Parshiyos',
        he: 'פרשה',
        hePlural: 'פרשיות',
      ),
      LevelLabels(
        en: 'Perek',
        enPlural: 'Perakim',
        he: 'פרק',
        hePlural: 'פרקים',
      ),
      LevelLabels(
        en: 'Pasuk',
        enPlural: 'Pesukim',
        he: 'פסוק',
        hePlural: 'פסוקים',
      ),
    ],
    CurriculumId.mishnehTorah: [
      LevelLabels(
        en: 'Sefer',
        enPlural: 'Seforim',
        he: 'ספר',
        hePlural: 'ספרים',
      ),
      LevelLabels(
        en: 'Hilchos',
        enPlural: 'Halachos',
        he: 'הלכות',
        hePlural: 'הלכות',
      ),
      LevelLabels(
        en: 'Perek',
        enPlural: 'Perakim',
        he: 'פרק',
        hePlural: 'פרקים',
      ),
      LevelLabels(
        en: 'Halacha',
        enPlural: 'Halachos',
        he: 'הלכה',
        hePlural: 'הלכות',
      ),
    ],
    CurriculumId.tanach: [
      LevelLabels(
        en: 'Section',
        enPlural: 'Sections',
        he: 'חלק',
        hePlural: 'חלקים',
      ),
      LevelLabels(
        en: 'Sefer',
        enPlural: 'Seforim',
        he: 'ספר',
        hePlural: 'ספרים',
      ),
      LevelLabels(
        en: 'Perek',
        enPlural: 'Perakim',
        he: 'פרק',
        hePlural: 'פרקים',
      ),
      LevelLabels(
        en: 'Pasuk',
        enPlural: 'Pesukim',
        he: 'פסוק',
        hePlural: 'פסוקים',
      ),
    ],
    CurriculumId.nach: [
      LevelLabels(
        en: 'Section',
        enPlural: 'Sections',
        he: 'חלק',
        hePlural: 'חלקים',
      ),
      LevelLabels(
        en: 'Sefer',
        enPlural: 'Seforim',
        he: 'ספר',
        hePlural: 'ספרים',
      ),
      LevelLabels(
        en: 'Perek',
        enPlural: 'Perakim',
        he: 'פרק',
        hePlural: 'פרקים',
      ),
      LevelLabels(
        en: 'Pasuk',
        enPlural: 'Pesukim',
        he: 'פסוק',
        hePlural: 'פסוקים',
      ),
    ],
    CurriculumId.mussar: [
      LevelLabels(
        en: 'Sefer',
        enPlural: 'Seforim',
        he: 'ספר',
        hePlural: 'ספרים',
      ),
      LevelLabels(
        en: 'Section',
        enPlural: 'Sections',
        he: 'חלק',
        hePlural: 'חלקים',
      ),
      LevelLabels(
        en: 'Chapter',
        enPlural: 'Chapters',
        he: 'פרק',
        hePlural: 'פרקים',
      ),
    ],
  };

  /// All level labels for [id], ordered top → leaf.
  static List<LevelLabels> levels(CurriculumId id) => _levels[id]!;

  /// Label for one 1-indexed [oneIndexedLevel]. Throws on out-of-range.
  static LevelLabels level(CurriculumId id, int oneIndexedLevel) {
    final list = _levels[id]!;
    if (oneIndexedLevel < 1 || oneIndexedLevel > list.length) {
      throw RangeError(
        'Level $oneIndexedLevel out of range (1..${list.length}) for $id',
      );
    }
    return list[oneIndexedLevel - 1];
  }

  /// Number of hierarchy levels for [id].
  static int depth(CurriculumId id) => _levels[id]!.length;

  /// English singular labels (top → leaf). Drop-in replacement for the
  /// old `[level1Label, if level2..., ...]` pattern.
  static List<String> labelsEn(CurriculumId id) =>
      _levels[id]!.map((l) => l.en).toList();

  static List<String> labelsEnPlural(CurriculumId id) =>
      _levels[id]!.map((l) => l.enPlural).toList();

  static List<String> labelsHe(CurriculumId id) =>
      _levels[id]!.map((l) => l.he).toList();

  static List<String> labelsHePlural(CurriculumId id) =>
      _levels[id]!.map((l) => l.hePlural).toList();

  /// Deepest level (Mishna for Mishnayos, Pasuk for Chumash, …).
  static LevelLabels leaf(CurriculumId id) => _levels[id]!.last;

  /// Level just above leaf — the typical "container" in drill-down UIs.
  /// Null only for single-level curricula (none currently exist).
  static LevelLabels? container(CurriculumId id) {
    final list = _levels[id]!;
    return list.length >= 2 ? list[list.length - 2] : null;
  }

  /// User-facing primary unit (plural English) for curriculum browse cards.
  /// Defaults to the leaf, but daf-based curricula prefer Dafim over
  /// Amudim/Halachos, and Chumash counts Parshiyos rather than Pesukim.
  static String primaryUnitLabelPlural(CurriculumId id) {
    return switch (id) {
      CurriculumId.bavli => level(id, 3).enPlural,
      CurriculumId.yerushalmi => level(id, 2).enPlural,
      CurriculumId.chumash => level(id, 2).enPlural,
      _ => leaf(id).enPlural,
    };
  }

  /// User-facing container count (plural English) for browse cards
  /// (e.g. "63 Masechtos"). Maps to whichever level the user thinks of as
  /// "the top grouping" for that curriculum.
  static String containerCountLabelPlural(CurriculumId id) {
    return switch (id) {
      CurriculumId.yerushalmi ||
      CurriculumId.chumash ||
      CurriculumId.mishnehTorah => level(id, 1).enPlural,
      CurriculumId.mishnayos || CurriculumId.bavli => level(id, 2).enPlural,
      _ => 'Sections',
    };
  }

  /// Bilingual plural header for the level-1 reorder section
  /// (e.g. "סדרים • Sedarim", "חומשים • Seferim").
  static String topSectionHeader(CurriculumId id) =>
      level(id, 1).bilingualPlural;

  /// Bilingual plural header for the level-2 reorder section
  /// (e.g. "מסכתות • Masechtos"). Null for single-level curricula.
  static String? containerSectionHeader(CurriculumId id) =>
      container(id)?.bilingualPlural;

  /// Whether the level-2 reorder section should render. Chumash and Tanach
  /// hide it: a 929-row chapter list is unworkable as a drag-reorder UI;
  /// reordering at the Sefer level is sufficient.
  static bool hasReorderableLevel2(CurriculumId id) =>
      id != CurriculumId.chumash && id != CurriculumId.tanach;

  /// All Hebrew singular + plural labels followed by a space — used to
  /// strip redundant structural prefixes from `displayNameHe`
  /// (e.g. 'מסכת ברכות' → 'ברכות' when shown as a child of its container).
  /// Derived from `_levels`, so adding a curriculum extends the set
  /// automatically.
  static List<String> structuralPrefixesHe() {
    final set = <String>{};
    for (final list in _levels.values) {
      for (final l in list) {
        if (l.he.isNotEmpty) set.add('${l.he} ');
        if (l.hePlural.isNotEmpty) set.add('${l.hePlural} ');
      }
    }
    return set.toList();
  }

  /// Strip the first matching structural Hebrew prefix from [he].
  static String stripStructuralPrefix(String he) {
    for (final p in structuralPrefixesHe()) {
      if (he.startsWith(p)) return he.substring(p.length);
    }
    return he;
  }

  /// Combine a level label and a content value: e.g.
  /// `(bavli, 3, '2a', useHebrew:false)` → "Daf 2a";
  /// `(bavli, 3, 'ב', useHebrew:true)` → "דף ב".
  static String valueWithLabel(
    CurriculumId id,
    int oneIndexedLevel,
    String value, {
    required bool useHebrew,
  }) {
    final l = level(id, oneIndexedLevel);
    return useHebrew ? '${l.he} $value' : '${l.en} $value';
  }

  /// Build a full breadcrumb-style hierarchy path from raw level values.
  ///
  /// `fullPath(bavli, [Zeraim, Berakhos, '2', 'a'], useHebrew:false)` →
  /// "Seder Zeraim → Masechta Berakhos → Daf 2 → Amud a".
  ///
  /// Skips null entries so partial paths render cleanly. Pass
  /// [includeLevelLabel]: false to join just the values.
  static String fullPath(
    CurriculumId id,
    List<String?> pathSegments, {
    required bool useHebrew,
    String separator = ' → ',
    bool includeLevelLabel = true,
  }) {
    final parts = <String>[];
    for (var i = 0; i < pathSegments.length; i++) {
      final v = pathSegments[i];
      if (v == null) continue;
      if (includeLevelLabel) {
        parts.add(valueWithLabel(id, i + 1, v, useHebrew: useHebrew));
      } else {
        parts.add(v);
      }
    }
    return parts.join(separator);
  }
}
