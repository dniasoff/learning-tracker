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

/// How a level's raw data value should be interpreted for display.
///
/// **named**: the value is a proper name that the renderer shows bare (no
/// level-word prefix) — e.g. Sefer "Genesis", Masechta "Berakhot", Seder
/// "Zeraim", Mussar book "Mesillat Yesharim".
///
/// **ordinal**: the value is a position (an Arabic integer, a Hebrew gematriya
/// letter, or a daf "a"/"b" amud). The renderer prefixes the level label and
/// converts numerals to gematriya in Hebrew mode — e.g. "פרק א", "Perek 1",
/// "דף ב", "עמוד א".
enum LevelValueKind { named, ordinal }

/// Which Hebrew transliteration dialect to use when rendering named values
/// in English mode. Ashkenazi: Bereishis, Shemos, Kesuvim. Sephardi:
/// Bereshit, Shemot, Ketuvim.
enum TransliterationVariant { ashkenazi, sephardi }

/// Bilingual, plural-aware label for one hierarchy level of a curriculum.
///
/// Singular and plural forms are both required because UI strings switch:
/// "Select the **Daf** you are up to" (singular) vs "63 **Masechtos**"
/// (plural). Hebrew + English forms are required for the bilingual section
/// headers and Hebrew-terms mode. [valueKind] and [prefixLabelInDisplay] are
/// consulted by `CurriculumLabelRenderer` to decide how to format a row,
/// breadcrumb segment, or AppBar title.
class LevelLabels {
  const LevelLabels({
    required this.en,
    required this.enPlural,
    required this.he,
    required this.hePlural,
    required this.valueKind,
    required this.prefixLabelInDisplay,
  });

  final String en;
  final String enPlural;
  final String he;
  final String hePlural;
  final LevelValueKind valueKind;
  final bool prefixLabelInDisplay;

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
        valueKind: LevelValueKind.named,
        prefixLabelInDisplay: false,
      ),
      LevelLabels(
        en: 'Masechta',
        enPlural: 'Masechtos',
        he: 'מסכת',
        hePlural: 'מסכתות',
        valueKind: LevelValueKind.named,
        prefixLabelInDisplay: false,
      ),
      LevelLabels(
        en: 'Perek',
        enPlural: 'Perakim',
        he: 'פרק',
        hePlural: 'פרקים',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
      LevelLabels(
        en: 'Mishna',
        enPlural: 'Mishnayos',
        he: 'משנה',
        hePlural: 'משניות',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
    ],
    CurriculumId.bavli: [
      LevelLabels(
        en: 'Seder',
        enPlural: 'Sedarim',
        he: 'סדר',
        hePlural: 'סדרים',
        valueKind: LevelValueKind.named,
        prefixLabelInDisplay: false,
      ),
      LevelLabels(
        en: 'Masechta',
        enPlural: 'Masechtos',
        he: 'מסכת',
        hePlural: 'מסכתות',
        valueKind: LevelValueKind.named,
        prefixLabelInDisplay: false,
      ),
      LevelLabels(
        en: 'Daf',
        enPlural: 'Dafim',
        he: 'דף',
        hePlural: 'דפים',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
      LevelLabels(
        en: 'Amud',
        enPlural: 'Amudim',
        he: 'עמוד',
        hePlural: 'עמודים',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
    ],
    CurriculumId.yerushalmi: [
      // Bundled yerushalmi.json: level1=Seder, level2=Masechta, level3=Daf
      // (where Daf is the leaf; there is no Halacha sub-level in the data).
      LevelLabels(
        en: 'Seder',
        enPlural: 'Sedarim',
        he: 'סדר',
        hePlural: 'סדרים',
        valueKind: LevelValueKind.named,
        prefixLabelInDisplay: false,
      ),
      LevelLabels(
        en: 'Masechta',
        enPlural: 'Masechtos',
        he: 'מסכת',
        hePlural: 'מסכתות',
        valueKind: LevelValueKind.named,
        prefixLabelInDisplay: false,
      ),
      LevelLabels(
        en: 'Daf',
        enPlural: 'Dafim',
        he: 'דף',
        hePlural: 'דפים',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
    ],
    CurriculumId.mishnaBerurah: [
      // The bundled mishna_berurah.json has level1='Mishnah Berurah'
      // (the book name) and Siman/Seif as the numeric levels below it.
      LevelLabels(
        en: 'Sefer',
        enPlural: 'Seforim',
        he: 'ספר',
        hePlural: 'ספרים',
        valueKind: LevelValueKind.named,
        prefixLabelInDisplay: false,
      ),
      LevelLabels(
        en: 'Siman',
        enPlural: 'Simanim',
        he: 'סימן',
        hePlural: 'סימנים',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
      LevelLabels(
        en: 'Seif',
        enPlural: 'Seifim',
        he: 'סעיף',
        hePlural: 'סעיפים',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
    ],
    CurriculumId.chumash: [
      // Note: the bundled chumash.json has 3 hierarchy levels
      // (Sefer / Perek / Pasuk). There is no Parsha level in the data, so
      // the renderer never sees parsha values. Counting "Parshiyos" in
      // browse cards (existing primaryUnitLabelPlural behavior) is a
      // separate stat unrelated to the level hierarchy.
      LevelLabels(
        en: 'Sefer',
        enPlural: 'Seferim',
        he: 'חומש',
        hePlural: 'חומשים',
        valueKind: LevelValueKind.named,
        prefixLabelInDisplay: false,
      ),
      LevelLabels(
        en: 'Perek',
        enPlural: 'Perakim',
        he: 'פרק',
        hePlural: 'פרקים',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
      LevelLabels(
        en: 'Pasuk',
        enPlural: 'Pesukim',
        he: 'פסוק',
        hePlural: 'פסוקים',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
    ],
    CurriculumId.mishnehTorah: [
      LevelLabels(
        en: 'Sefer',
        enPlural: 'Seforim',
        he: 'ספר',
        hePlural: 'ספרים',
        valueKind: LevelValueKind.named,
        prefixLabelInDisplay: false,
      ),
      LevelLabels(
        en: 'Hilchos',
        enPlural: 'Halachos',
        he: 'הלכות',
        hePlural: 'הלכות',
        valueKind: LevelValueKind.named,
        prefixLabelInDisplay: false,
      ),
      LevelLabels(
        en: 'Perek',
        enPlural: 'Perakim',
        he: 'פרק',
        hePlural: 'פרקים',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
      LevelLabels(
        en: 'Halacha',
        enPlural: 'Halachos',
        he: 'הלכה',
        hePlural: 'הלכות',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
    ],
    CurriculumId.tanach: [
      LevelLabels(
        en: 'Section',
        enPlural: 'Sections',
        he: 'חלק',
        hePlural: 'חלקים',
        valueKind: LevelValueKind.named,
        prefixLabelInDisplay: false,
      ),
      LevelLabels(
        en: 'Sefer',
        enPlural: 'Seforim',
        he: 'ספר',
        hePlural: 'ספרים',
        valueKind: LevelValueKind.named,
        prefixLabelInDisplay: false,
      ),
      LevelLabels(
        en: 'Perek',
        enPlural: 'Perakim',
        he: 'פרק',
        hePlural: 'פרקים',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
      LevelLabels(
        en: 'Pasuk',
        enPlural: 'Pesukim',
        he: 'פסוק',
        hePlural: 'פסוקים',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
    ],
    CurriculumId.nach: [
      LevelLabels(
        en: 'Section',
        enPlural: 'Sections',
        he: 'חלק',
        hePlural: 'חלקים',
        valueKind: LevelValueKind.named,
        prefixLabelInDisplay: false,
      ),
      LevelLabels(
        en: 'Sefer',
        enPlural: 'Seforim',
        he: 'ספר',
        hePlural: 'ספרים',
        valueKind: LevelValueKind.named,
        prefixLabelInDisplay: false,
      ),
      LevelLabels(
        en: 'Perek',
        enPlural: 'Perakim',
        he: 'פרק',
        hePlural: 'פרקים',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
      LevelLabels(
        en: 'Pasuk',
        enPlural: 'Pesukim',
        he: 'פסוק',
        hePlural: 'פסוקים',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
    ],
    CurriculumId.mussar: [
      LevelLabels(
        en: 'Sefer',
        enPlural: 'Seforim',
        he: 'ספר',
        hePlural: 'ספרים',
        valueKind: LevelValueKind.named,
        prefixLabelInDisplay: false,
      ),
      // L2 default = Perek; per-book overrides in _levelOverrides
      // turn this into "Shaar" for Shaarei Teshuvah, "Part" for Tanya, etc.
      LevelLabels(
        en: 'Perek',
        enPlural: 'Perakim',
        he: 'פרק',
        hePlural: 'פרקים',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
      // L3 default = Pasuk for 3-level books (Mesillat Yesharim, Orchot
      // Tzadikim, Tomer Devorah, Shaarei Teshuvah).
      LevelLabels(
        en: 'Pasuk',
        enPlural: 'Pesukim',
        he: 'פסוק',
        hePlural: 'פסוקים',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
      // L4 = Pasuk for 4-level books (Tanya only — L3 becomes Perek via
      // per-book override).
      LevelLabels(
        en: 'Pasuk',
        enPlural: 'Pesukim',
        he: 'פסוק',
        hePlural: 'פסוקים',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      ),
    ],
  };

  /// English-mode display overrides for named-level values that ship in the
  /// bundled data as English **translations** (e.g. "Genesis", "Psalms",
  /// "Prophets"). When Hebrew Terms is off the renderer still wants the
  /// transliterated Hebrew name, not the translation, in the user's chosen
  /// dialect.
  ///
  /// Keys are the raw data values (case-sensitive). Lookups fall through to
  /// the raw value when no entry exists — masechtas like "Berakhot" pass
  /// through because they are already transliterated in the data.
  static const Map<TransliterationVariant, Map<String, String>>
  _englishNameTransliterations = {
    TransliterationVariant.ashkenazi: {
      // Tanach top sections
      'Torah': 'Torah',
      'Prophets': "Nevi'im",
      'Writings': 'Kesuvim',
      // Chumash books
      'Genesis': 'Bereishis',
      'Exodus': 'Shemos',
      'Leviticus': 'Vayikra',
      'Numbers': 'Bamidbar',
      'Deuteronomy': 'Devarim',
      // Nach — Nevi'im
      'Joshua': 'Yehoshua',
      'Judges': 'Shoftim',
      'I Samuel': 'Shmuel I',
      'II Samuel': 'Shmuel II',
      'I Kings': 'Melachim I',
      'II Kings': 'Melachim II',
      'Isaiah': 'Yeshayah',
      'Jeremiah': 'Yirmiyah',
      'Ezekiel': 'Yechezkel',
      'Hosea': 'Hoshea',
      'Joel': 'Yoel',
      'Amos': 'Amos',
      'Obadiah': 'Ovadyah',
      'Jonah': 'Yonah',
      'Micah': 'Michah',
      'Nahum': 'Nachum',
      'Habakkuk': 'Chavakuk',
      'Zephaniah': 'Tzefanyah',
      'Haggai': 'Chagai',
      'Zechariah': 'Zechariah',
      'Malachi': 'Malachi',
      // Nach — Kesuvim
      'Psalms': 'Tehillim',
      'Proverbs': 'Mishlei',
      'Job': 'Iyov',
      'Song of Songs': 'Shir HaShirim',
      'Ruth': 'Rus',
      'Lamentations': 'Eichah',
      'Ecclesiastes': 'Koheles',
      'Esther': 'Esther',
      'Daniel': 'Daniel',
      'Ezra': 'Ezra',
      'Nehemiah': 'Nechemya',
      'I Chronicles': 'Divrei HaYamim I',
      'II Chronicles': 'Divrei HaYamim II',
    },
    TransliterationVariant.sephardi: {
      // Tanach top sections
      'Torah': 'Torah',
      'Prophets': "Nevi'im",
      'Writings': 'Ketuvim',
      // Chumash books
      'Genesis': 'Bereshit',
      'Exodus': 'Shemot',
      'Leviticus': 'Vayikra',
      'Numbers': 'Bamidbar',
      'Deuteronomy': 'Devarim',
      // Nach — Nevi'im
      'Joshua': 'Yehoshua',
      'Judges': 'Shoftim',
      'I Samuel': 'Shmuel I',
      'II Samuel': 'Shmuel II',
      'I Kings': 'Melakhim I',
      'II Kings': 'Melakhim II',
      'Isaiah': "Yesha'yahu",
      'Jeremiah': 'Yirmiyahu',
      'Ezekiel': "Yehezk'el",
      'Hosea': "Hoshe'a",
      'Joel': "Yo'el",
      'Amos': 'Amos',
      'Obadiah': 'Ovadya',
      'Jonah': 'Yona',
      'Micah': 'Mikha',
      'Nahum': 'Nahum',
      'Habakkuk': 'Havakuk',
      'Zephaniah': 'Tzefanya',
      'Haggai': 'Hagai',
      'Zechariah': 'Zekharya',
      'Malachi': "Mal'akhi",
      // Nach — Ketuvim
      'Psalms': 'Tehilim',
      'Proverbs': 'Mishlei',
      'Job': 'Iyov',
      'Song of Songs': 'Shir HaShirim',
      'Ruth': 'Rut',
      'Lamentations': 'Eikha',
      'Ecclesiastes': 'Kohelet',
      'Esther': 'Ester',
      'Daniel': 'Daniel',
      'Ezra': 'Ezra',
      'Nehemiah': 'Nehemya',
      'I Chronicles': 'Divrei HaYamim I',
      'II Chronicles': 'Divrei HaYamim II',
    },
  };

  /// Returns the Hebrew-transliterated English display name for [rawValue]
  /// in the chosen [variant], or [rawValue] itself when no override exists.
  /// Used by the unified renderer in English mode.
  static String transliterateNamedValue(
    String rawValue, {
    TransliterationVariant variant = TransliterationVariant.ashkenazi,
  }) {
    return _englishNameTransliterations[variant]?[rawValue] ?? rawValue;
  }

  /// Per-book level overrides for curricula whose hierarchy varies by L1 book.
  /// Mussar is the only one today — Shaarei Teshuvah uses Shaarim (gates),
  /// Tanya uses Parts (named), the rest use Perakim like the default.
  static const Map<CurriculumId, Map<String, Map<int, LevelLabels>>>
  _levelOverrides = {
    CurriculumId.mussar: {
      'Shaarei Teshuvah': {
        2: LevelLabels(
          en: 'Shaar',
          enPlural: 'Shaarim',
          he: 'שער',
          hePlural: 'שערים',
          valueKind: LevelValueKind.ordinal,
          prefixLabelInDisplay: true,
        ),
      },
      'Tanya': {
        2: LevelLabels(
          en: 'Part',
          enPlural: 'Parts',
          he: 'חלק',
          hePlural: 'חלקים',
          valueKind: LevelValueKind.named,
          prefixLabelInDisplay: false,
        ),
        // Tanya is 4 levels deep — L3 below the Part is the Perek.
        3: LevelLabels(
          en: 'Perek',
          enPlural: 'Perakim',
          he: 'פרק',
          hePlural: 'פרקים',
          valueKind: LevelValueKind.ordinal,
          prefixLabelInDisplay: true,
        ),
      },
    },
  };

  /// All level labels for [id], ordered top → leaf.
  static List<LevelLabels> levels(CurriculumId id) => _levels[id]!;

  /// Label for one 1-indexed [oneIndexedLevel]. Throws on out-of-range.
  ///
  /// Pass [parentL1Value] when a curriculum's level structure varies by its
  /// top-level book (e.g. Mussar: Shaarei Teshuvah uses Shaarim at L2, Tanya
  /// uses Parts at L2, everything else uses Perakim). Defaults fall through
  /// when no override exists.
  static LevelLabels level(
    CurriculumId id,
    int oneIndexedLevel, {
    String? parentL1Value,
  }) {
    final list = _levels[id]!;
    if (oneIndexedLevel < 1 || oneIndexedLevel > list.length) {
      throw RangeError(
        'Level $oneIndexedLevel out of range (1..${list.length}) for $id',
      );
    }
    if (parentL1Value != null) {
      final override = _levelOverrides[id]?[parentL1Value]?[oneIndexedLevel];
      if (override != null) return override;
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

  /// Deepest level the **browse UI** drills into. For Tanakh curricula
  /// (Chumash / Nach / Tanach) the chapter row goes straight to the reader
  /// — browsing individual pasukim isn't useful, so we cap one above the
  /// leaf. Every other curriculum browses all the way to the leaf (Mishna,
  /// Amud, Pasuk-within-Mussar-book, etc.).
  static int maxBrowseDepth(CurriculumId id) {
    if (id == CurriculumId.chumash ||
        id == CurriculumId.nach ||
        id == CurriculumId.tanach) {
      return depth(id) - 1;
    }
    return depth(id);
  }

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

  /// Curriculum-specific Hebrew name prefixes that always appear in the
  /// bundled data and should be stripped before the value is shown to the
  /// user. Distinct from level-label prefixes (which we derive from
  /// `_levels`). Mishneh Torah's data ships every item with a
  /// "משנה תורה, " breadcrumb prefix; the renderer must remove it before
  /// any further level-label stripping.
  static const Map<CurriculumId, List<String>> _curriculumNamePrefixesHe = {
    CurriculumId.mishnehTorah: ['משנה תורה, '],
  };

  /// Hebrew singular + plural level labels (followed by a space) for the
  /// given curriculum. When [curriculumId] is null, returns the union
  /// across every curriculum (legacy callers).
  ///
  /// Scoping by curriculum prevents over-eager stripping — e.g. stripping
  /// "משנה " (the Mishnayos level label) from "משנה תורה, …" (the Mishneh
  /// Torah data prefix).
  static List<String> structuralPrefixesHe({CurriculumId? curriculumId}) {
    final set = <String>{};
    if (curriculumId != null) {
      for (final l in _levels[curriculumId]!) {
        if (l.he.isNotEmpty) set.add('${l.he} ');
        if (l.hePlural.isNotEmpty) set.add('${l.hePlural} ');
      }
      set.addAll(_curriculumNamePrefixesHe[curriculumId] ?? const []);
    } else {
      for (final list in _levels.values) {
        for (final l in list) {
          if (l.he.isNotEmpty) set.add('${l.he} ');
          if (l.hePlural.isNotEmpty) set.add('${l.hePlural} ');
        }
      }
    }
    return set.toList();
  }

  /// Strip every matching structural Hebrew prefix from [he] (looping
  /// until no prefix matches). When [curriculumId] is provided, only that
  /// curriculum's level labels plus its curriculum-specific name prefixes
  /// are considered. Without it, the legacy global pool is used.
  ///
  /// Example: 'משנה תורה, הלכות גירושין' with curriculumId=mishnehTorah →
  /// strips 'משנה תורה, ' → 'הלכות גירושין' → strips 'הלכות ' → 'גירושין'.
  static String stripStructuralPrefix(String he, {CurriculumId? curriculumId}) {
    final prefixes = structuralPrefixesHe(curriculumId: curriculumId);
    var out = he;
    var stripped = true;
    while (stripped) {
      stripped = false;
      for (final p in prefixes) {
        if (out.startsWith(p)) {
          out = out.substring(p.length);
          stripped = true;
          break;
        }
      }
    }
    return out;
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
