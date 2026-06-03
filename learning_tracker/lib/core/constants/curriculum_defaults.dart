import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Default curriculum configuration constants per D3.
///
/// Default learning cycle: Learn > Chazara 1 (+1 day) > Chazara 2 (+7 days).
/// Users can customize stage count, names, and timing per curriculum.
class CurriculumDefaults {
  CurriculumDefaults._();

  /// Default stage definitions applied to all curricula.
  static const List<DefaultStageDefinition> defaultStages = [
    DefaultStageDefinition(
      stageOrder: 0,
      stageName: 'לימוד',
      schedule: DelaySchedule(0),
    ),
    DefaultStageDefinition(
      stageOrder: 1,
      stageName: 'חזרה א׳',
      schedule: DelaySchedule(1),
    ),
    DefaultStageDefinition(
      stageOrder: 2,
      stageName: 'חזרה ב׳',
      schedule: DelaySchedule(7),
    ),
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

/// A default stage configuration used to seed new tracks.
///
/// Carries a [ScheduleSpec] instead of the old nullable quartet
/// (scheduleType, delayDays, daysOfWeek?, rollingWindowSize?) — W4.10.
class DefaultStageDefinition {
  const DefaultStageDefinition({
    required this.stageOrder,
    required this.stageName,
    required this.schedule,
  });

  final int stageOrder;
  final String stageName;
  final ScheduleSpec schedule;

  // ── Convenience accessors for repository write-back ─────────────────────

  /// `delay_days` column value — non-zero only for [DelaySchedule].
  int get delayDays => schedule.delayDays;

  /// `days_of_week` column value — non-null only for [WeeklySchedule].
  List<int>? get daysOfWeek => schedule.daysOfWeek;

  /// `rolling_window_size` column value — non-null only for [RollingSchedule].
  int? get rollingWindowSize => schedule.rollingWindowSize;

  /// `schedule_type` column value.
  String get scheduleTypeKey => schedule.storageKey;
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

  /// Curated Ashkenazi → Sephardi overrides for English-mode UNIT words.
  ///
  /// Most unit words are identical across nuschaos; only these differ. The
  /// `en`/`enPlural` fields hold the Ashkenazi form (Mishnayos, Masechtos,
  /// Dafim, Halachos…); when the renderer is in Sephardi mode the word is
  /// mapped through this table. Words absent here (Daf, Amud, Perek, Pasuk,
  /// Seder, Siman, Seif, Sefer, Mishnah, Shaar…) are identical in both
  /// nuschaos and pass through unchanged.
  static const Map<String, String> _sephardiUnitOverrides = {
    'Mishnayos': 'Mishnayot',
    'Masechta': 'Masekhet',
    'Masechtos': 'Masekhtot',
    'Dafim': 'Dapim',
    'Halacha': 'Halakha',
    'Halachos': 'Halakhot',
    'Seforim': 'Sefarim',
    'Seferim': 'Sefarim',
  };

  /// Maps an Ashkenazi English unit word to its Sephardi form, falling back
  /// to the Ashkenazi form when no override exists.
  static String _toSephardi(String ashkenazi) =>
      _sephardiUnitOverrides[ashkenazi] ?? ashkenazi;

  /// Returns the localized unit word for [useHebrew] / [variant].
  ///
  /// When [useHebrew] is true the [variant] is irrelevant (Hebrew script is
  /// nusach-independent here). In English mode [variant] selects the
  /// transliteration dialect: [TransliterationVariant.ashkenazi] (default)
  /// returns the bare `en`/`enPlural`; [TransliterationVariant.sephardi] maps
  /// it through [_sephardiUnitOverrides].
  String inLanguage({
    required bool useHebrew,
    bool plural = false,
    TransliterationVariant variant = TransliterationVariant.ashkenazi,
  }) {
    if (useHebrew) return plural ? hePlural : he;
    final ashkenazi = plural ? enPlural : en;
    return variant == TransliterationVariant.sephardi
        ? _toSephardi(ashkenazi)
        : ashkenazi;
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
      // Curriculum (CurriculumId.displayNameEn) names that differ by nusach.
      // Keyed by the exact Ashkenazi displayNameEn string. The remaining
      // curricula (Talmud Bavli, Talmud Yerushalmi, Mishna Berurah, Chumash,
      // Mishneh Torah, Mussar) are identical in both nuschaos and pass through.
      'Mishnayos': 'Mishnayos',
      'Tanach': 'Tanach',
      'Nach': 'Nach',
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
      // Masechtos (Bavli / Mishnayos / Yerushalmi). Keyed by every raw L2
      // form the bundled data ships: the bare name (Bavli — "Berakhot"), the
      // Mishnah-prefixed form ("Mishnah Berakhot"), and the Yerushalmi form
      // ("Jerusalem Talmud Berakhot"). The Masechta level word ("Maseches")
      // is prepended by the renderer, so the value here is the bare name.
      // Seder Zeraim
      'Berakhot': 'Berakhos',
      'Jerusalem Talmud Berakhot': 'Berakhos',
      'Mishnah Berakhot': 'Berakhos',
      'Jerusalem Talmud Bikkurim': 'Bikkurim',
      'Mishnah Bikkurim': 'Bikkurim',
      'Jerusalem Talmud Challah': 'Challah',
      'Mishnah Challah': 'Challah',
      'Jerusalem Talmud Demai': 'Demai',
      'Mishnah Demai': 'Demai',
      'Jerusalem Talmud Kilayim': 'Kilayim',
      'Mishnah Kilayim': 'Kilayim',
      'Jerusalem Talmud Maaser Sheni': 'Maaser Sheni',
      'Mishnah Maaser Sheni': 'Maaser Sheni',
      'Jerusalem Talmud Maasrot': 'Maasros',
      'Mishnah Maasrot': 'Maasros',
      'Jerusalem Talmud Orlah': 'Orlah',
      'Mishnah Orlah': 'Orlah',
      'Jerusalem Talmud Peah': 'Peah',
      'Mishnah Peah': 'Peah',
      'Jerusalem Talmud Sheviit': 'Sheviis',
      'Mishnah Sheviit': 'Sheviis',
      'Jerusalem Talmud Terumot': 'Terumos',
      'Mishnah Terumot': 'Terumos',
      // Seder Moed
      'Beitzah': 'Beitzah',
      'Jerusalem Talmud Beitzah': 'Beitzah',
      'Mishnah Beitzah': 'Beitzah',
      'Chagigah': 'Chagigah',
      'Jerusalem Talmud Chagigah': 'Chagigah',
      'Mishnah Chagigah': 'Chagigah',
      'Eruvin': 'Eruvin',
      'Jerusalem Talmud Eruvin': 'Eruvin',
      'Mishnah Eruvin': 'Eruvin',
      'Jerusalem Talmud Megillah': 'Megillah',
      'Megillah': 'Megillah',
      'Mishnah Megillah': 'Megillah',
      'Jerusalem Talmud Moed Katan': 'Moed Katan',
      'Mishnah Moed Katan': 'Moed Katan',
      'Moed Katan': 'Moed Katan',
      'Jerusalem Talmud Pesachim': 'Pesachim',
      'Mishnah Pesachim': 'Pesachim',
      'Pesachim': 'Pesachim',
      'Jerusalem Talmud Rosh Hashanah': 'Rosh Hashanah',
      'Mishnah Rosh Hashanah': 'Rosh Hashanah',
      'Rosh Hashanah': 'Rosh Hashanah',
      'Jerusalem Talmud Shabbat': 'Shabbos',
      'Mishnah Shabbat': 'Shabbos',
      'Shabbat': 'Shabbos',
      'Jerusalem Talmud Shekalim': 'Shekalim',
      'Mishnah Shekalim': 'Shekalim',
      'Jerusalem Talmud Sukkah': 'Succah',
      'Mishnah Sukkah': 'Succah',
      'Sukkah': 'Succah',
      "Mishnah Ta'anit": 'Taanis',
      'Jerusalem Talmud Taanit': 'Taanis',
      'Taanit': 'Taanis',
      'Jerusalem Talmud Yoma': 'Yoma',
      'Mishnah Yoma': 'Yoma',
      'Yoma': 'Yoma',
      // Seder Nashim
      'Gittin': 'Gittin',
      'Jerusalem Talmud Gittin': 'Gittin',
      'Mishnah Gittin': 'Gittin',
      'Jerusalem Talmud Ketubot': 'Kesubos',
      'Ketubot': 'Kesubos',
      'Mishnah Ketubot': 'Kesubos',
      'Jerusalem Talmud Kiddushin': 'Kiddushin',
      'Kiddushin': 'Kiddushin',
      'Mishnah Kiddushin': 'Kiddushin',
      'Jerusalem Talmud Nazir': 'Nazir',
      'Mishnah Nazir': 'Nazir',
      'Nazir': 'Nazir',
      'Jerusalem Talmud Nedarim': 'Nedarim',
      'Mishnah Nedarim': 'Nedarim',
      'Nedarim': 'Nedarim',
      'Jerusalem Talmud Sotah': 'Sotah',
      'Mishnah Sotah': 'Sotah',
      'Sotah': 'Sotah',
      'Jerusalem Talmud Yevamot': 'Yevamos',
      'Mishnah Yevamot': 'Yevamos',
      'Yevamot': 'Yevamos',
      // Seder Nezikin
      'Avodah Zarah': 'Avodah Zarah',
      'Jerusalem Talmud Avodah Zarah': 'Avodah Zarah',
      'Mishnah Avodah Zarah': 'Avodah Zarah',
      'Bava Batra': 'Bava Basra',
      'Jerusalem Talmud Bava Batra': 'Bava Basra',
      'Mishnah Bava Batra': 'Bava Basra',
      'Bava Kamma': 'Bava Kamma',
      'Jerusalem Talmud Bava Kamma': 'Bava Kamma',
      'Mishnah Bava Kamma': 'Bava Kamma',
      'Bava Metzia': 'Bava Metzia',
      'Jerusalem Talmud Bava Metzia': 'Bava Metzia',
      'Mishnah Bava Metzia': 'Bava Metzia',
      'Mishnah Eduyot': 'Eduyos',
      'Horayot': 'Horayos',
      'Jerusalem Talmud Horayot': 'Horayos',
      'Mishnah Horayot': 'Horayos',
      'Jerusalem Talmud Makkot': 'Makkos',
      'Makkot': 'Makkos',
      'Mishnah Makkot': 'Makkos',
      'Pirkei Avot': 'Pirkei Avos',
      'Jerusalem Talmud Sanhedrin': 'Sanhedrin',
      'Mishnah Sanhedrin': 'Sanhedrin',
      'Sanhedrin': 'Sanhedrin',
      'Jerusalem Talmud Shevuot': 'Shevuos',
      'Mishnah Shevuot': 'Shevuos',
      'Shevuot': 'Shevuos',
      // Seder Kodashim
      'Arakhin': 'Arachin',
      'Mishnah Arakhin': 'Arachin',
      'Bekhorot': 'Bechoros',
      'Mishnah Bekhorot': 'Bechoros',
      'Chullin': 'Chullin',
      'Mishnah Chullin': 'Chullin',
      'Keritot': 'Kerisos',
      'Mishnah Keritot': 'Kerisos',
      'Mishnah Kinnim': 'Kinnim',
      'Meilah': 'Meilah',
      'Mishnah Meilah': 'Meilah',
      'Menachot': 'Menachos',
      'Mishnah Menachot': 'Menachos',
      'Mishnah Middot': 'Middos',
      'Mishnah Tamid': 'Tamid',
      'Tamid': 'Tamid',
      'Mishnah Temurah': 'Temurah',
      'Temurah': 'Temurah',
      'Mishnah Zevachim': 'Zevachim',
      'Zevachim': 'Zevachim',
      // Seder Tahorot
      'Mishnah Kelim': 'Keilim',
      'Mishnah Makhshirin': 'Machshirin',
      'Mishnah Mikvaot': 'Mikvaos',
      'Mishnah Negaim': 'Negaim',
      'Jerusalem Talmud Niddah': 'Niddah',
      'Mishnah Niddah': 'Niddah',
      'Niddah': 'Niddah',
      'Mishnah Oholot': 'Ohalos',
      'Mishnah Oktzin': 'Uktzin',
      'Mishnah Parah': 'Parah',
      'Mishnah Tahorot': 'Taharos',
      'Mishnah Tevul Yom': 'Tevul Yom',
      'Mishnah Yadayim': 'Yadayim',
      'Mishnah Zavim': 'Zavim',
      // Seder (order) names — level 1. Only Tahoros differs by nusach; the
      // other sedarim are identical in both transliterations and pass through
      // unchanged. "Seder" is part of the displayed name (unlike the Mishnah/
      // Yerushalmi curriculum prefixes above, which are stripped), so it is
      // kept. Keyed bare and with the "Seder " prefix the data carries.
      'Tahorot': 'Taharos', 'Seder Tahorot': 'Seder Taharos',
    },
    TransliterationVariant.sephardi: {
      // Curriculum (CurriculumId.displayNameEn) names that differ by nusach.
      // Keyed by the exact Ashkenazi displayNameEn string.
      'Mishnayos': 'Mishnayot',
      'Tanach': 'Tanakh',
      'Nach': 'Nakh',
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
      // Masechtos (Bavli / Mishnayos / Yerushalmi). Same raw-key forms as the
      // ashkenazi map. The Sephardi/academic spelling generally equals the
      // raw data value; entries are listed explicitly for clarity.
      // Seder Zeraim
      'Berakhot': 'Berakhot',
      'Jerusalem Talmud Berakhot': 'Berakhot',
      'Mishnah Berakhot': 'Berakhot',
      'Jerusalem Talmud Bikkurim': 'Bikkurim',
      'Mishnah Bikkurim': 'Bikkurim',
      'Jerusalem Talmud Challah': 'Challah',
      'Mishnah Challah': 'Challah',
      'Jerusalem Talmud Demai': 'Demai',
      'Mishnah Demai': 'Demai',
      'Jerusalem Talmud Kilayim': 'Kilayim',
      'Mishnah Kilayim': 'Kilayim',
      'Jerusalem Talmud Maaser Sheni': 'Maaser Sheni',
      'Mishnah Maaser Sheni': 'Maaser Sheni',
      'Jerusalem Talmud Maasrot': 'Maasrot',
      'Mishnah Maasrot': 'Maasrot',
      'Jerusalem Talmud Orlah': 'Orlah',
      'Mishnah Orlah': 'Orlah',
      'Jerusalem Talmud Peah': 'Peah',
      'Mishnah Peah': 'Peah',
      'Jerusalem Talmud Sheviit': 'Sheviit',
      'Mishnah Sheviit': 'Sheviit',
      'Jerusalem Talmud Terumot': 'Terumot',
      'Mishnah Terumot': 'Terumot',
      // Seder Moed
      'Beitzah': 'Beitzah',
      'Jerusalem Talmud Beitzah': 'Beitzah',
      'Mishnah Beitzah': 'Beitzah',
      'Chagigah': 'Chagigah',
      'Jerusalem Talmud Chagigah': 'Chagigah',
      'Mishnah Chagigah': 'Chagigah',
      'Eruvin': 'Eruvin',
      'Jerusalem Talmud Eruvin': 'Eruvin',
      'Mishnah Eruvin': 'Eruvin',
      'Jerusalem Talmud Megillah': 'Megillah',
      'Megillah': 'Megillah',
      'Mishnah Megillah': 'Megillah',
      'Jerusalem Talmud Moed Katan': 'Moed Katan',
      'Mishnah Moed Katan': 'Moed Katan',
      'Moed Katan': 'Moed Katan',
      'Jerusalem Talmud Pesachim': 'Pesachim',
      'Mishnah Pesachim': 'Pesachim',
      'Pesachim': 'Pesachim',
      'Jerusalem Talmud Rosh Hashanah': 'Rosh Hashanah',
      'Mishnah Rosh Hashanah': 'Rosh Hashanah',
      'Rosh Hashanah': 'Rosh Hashanah',
      'Jerusalem Talmud Shabbat': 'Shabbat',
      'Mishnah Shabbat': 'Shabbat',
      'Shabbat': 'Shabbat',
      'Jerusalem Talmud Shekalim': 'Shekalim',
      'Mishnah Shekalim': 'Shekalim',
      'Jerusalem Talmud Sukkah': 'Sukkah',
      'Mishnah Sukkah': 'Sukkah',
      'Sukkah': 'Sukkah',
      "Mishnah Ta'anit": 'Taanit',
      'Jerusalem Talmud Taanit': 'Taanit',
      'Taanit': 'Taanit',
      'Jerusalem Talmud Yoma': 'Yoma',
      'Mishnah Yoma': 'Yoma',
      'Yoma': 'Yoma',
      // Seder Nashim
      'Gittin': 'Gittin',
      'Jerusalem Talmud Gittin': 'Gittin',
      'Mishnah Gittin': 'Gittin',
      'Jerusalem Talmud Ketubot': 'Ketubot',
      'Ketubot': 'Ketubot',
      'Mishnah Ketubot': 'Ketubot',
      'Jerusalem Talmud Kiddushin': 'Kiddushin',
      'Kiddushin': 'Kiddushin',
      'Mishnah Kiddushin': 'Kiddushin',
      'Jerusalem Talmud Nazir': 'Nazir',
      'Mishnah Nazir': 'Nazir',
      'Nazir': 'Nazir',
      'Jerusalem Talmud Nedarim': 'Nedarim',
      'Mishnah Nedarim': 'Nedarim',
      'Nedarim': 'Nedarim',
      'Jerusalem Talmud Sotah': 'Sotah',
      'Mishnah Sotah': 'Sotah',
      'Sotah': 'Sotah',
      'Jerusalem Talmud Yevamot': 'Yevamot',
      'Mishnah Yevamot': 'Yevamot',
      'Yevamot': 'Yevamot',
      // Seder Nezikin
      'Avodah Zarah': 'Avodah Zarah',
      'Jerusalem Talmud Avodah Zarah': 'Avodah Zarah',
      'Mishnah Avodah Zarah': 'Avodah Zarah',
      'Bava Batra': 'Bava Batra',
      'Jerusalem Talmud Bava Batra': 'Bava Batra',
      'Mishnah Bava Batra': 'Bava Batra',
      'Bava Kamma': 'Bava Kamma',
      'Jerusalem Talmud Bava Kamma': 'Bava Kamma',
      'Mishnah Bava Kamma': 'Bava Kamma',
      'Bava Metzia': 'Bava Metzia',
      'Jerusalem Talmud Bava Metzia': 'Bava Metzia',
      'Mishnah Bava Metzia': 'Bava Metzia',
      'Mishnah Eduyot': 'Eduyot',
      'Horayot': 'Horayot',
      'Jerusalem Talmud Horayot': 'Horayot',
      'Mishnah Horayot': 'Horayot',
      'Jerusalem Talmud Makkot': 'Makkot',
      'Makkot': 'Makkot',
      'Mishnah Makkot': 'Makkot',
      'Pirkei Avot': 'Pirkei Avot',
      'Jerusalem Talmud Sanhedrin': 'Sanhedrin',
      'Mishnah Sanhedrin': 'Sanhedrin',
      'Sanhedrin': 'Sanhedrin',
      'Jerusalem Talmud Shevuot': 'Shevuot',
      'Mishnah Shevuot': 'Shevuot',
      'Shevuot': 'Shevuot',
      // Seder Kodashim
      'Arakhin': 'Arakhin',
      'Mishnah Arakhin': 'Arakhin',
      'Bekhorot': 'Bekhorot',
      'Mishnah Bekhorot': 'Bekhorot',
      'Chullin': 'Chullin',
      'Mishnah Chullin': 'Chullin',
      'Keritot': 'Keritot',
      'Mishnah Keritot': 'Keritot',
      'Mishnah Kinnim': 'Kinnim',
      'Meilah': 'Meilah',
      'Mishnah Meilah': 'Meilah',
      'Menachot': 'Menachot',
      'Mishnah Menachot': 'Menachot',
      'Mishnah Middot': 'Middot',
      'Mishnah Tamid': 'Tamid',
      'Tamid': 'Tamid',
      'Mishnah Temurah': 'Temurah',
      'Temurah': 'Temurah',
      'Mishnah Zevachim': 'Zevachim',
      'Zevachim': 'Zevachim',
      // Seder Tahorot
      'Mishnah Kelim': 'Kelim',
      'Mishnah Makhshirin': 'Makhshirin',
      'Mishnah Mikvaot': 'Mikvaot',
      'Mishnah Negaim': 'Negaim',
      'Jerusalem Talmud Niddah': 'Niddah',
      'Mishnah Niddah': 'Niddah',
      'Niddah': 'Niddah',
      'Mishnah Oholot': 'Oholot',
      'Mishnah Oktzin': 'Oktzin',
      'Mishnah Parah': 'Parah',
      'Mishnah Tahorot': 'Tahorot',
      'Mishnah Tevul Yom': 'Tevul Yom',
      'Mishnah Yadayim': 'Yadayim',
      'Mishnah Zavim': 'Zavim',
      // Seder (order) names — Sephardi = the raw form ("Seder" kept).
      'Tahorot': 'Tahorot', 'Seder Tahorot': 'Seder Tahorot',
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

  /// Deepest level the **browse UI** drills into. Browse stops at the
  /// "perek-or-equivalent" row (which opens the reader on tap) — drilling
  /// down to individual pasuk / mishna / seif / halacha rows is too
  /// tedious for casual browsing. Goal-setup, lifetime-marking, and
  /// daily-task assignment screens still use the full `depth(id)` because
  /// they work at the leaf unit.
  ///
  /// Bavli / Yerushalmi are the exception: their leaf is Daf, which is
  /// already the natural browse target.
  static int maxBrowseDepth(CurriculumId id) {
    if (id == CurriculumId.bavli || id == CurriculumId.yerushalmi) {
      return depth(id);
    }
    return depth(id) - 1;
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

  /// Toggle-aware variant of [primaryUnitLabelPlural].
  static String primaryUnitLabel(
    CurriculumId id, {
    required bool useHebrew,
    TransliterationVariant variant = TransliterationVariant.ashkenazi,
  }) {
    return switch (id) {
      CurriculumId.bavli => level(
        id,
        3,
      ).inLanguage(useHebrew: useHebrew, plural: true, variant: variant),
      CurriculumId.yerushalmi => level(
        id,
        2,
      ).inLanguage(useHebrew: useHebrew, plural: true, variant: variant),
      CurriculumId.chumash => level(
        id,
        2,
      ).inLanguage(useHebrew: useHebrew, plural: true, variant: variant),
      _ => leaf(
        id,
      ).inLanguage(useHebrew: useHebrew, plural: true, variant: variant),
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

  /// Toggle-aware variant of [containerCountLabelPlural].
  static String containerCountLabel(
    CurriculumId id, {
    required bool useHebrew,
    TransliterationVariant variant = TransliterationVariant.ashkenazi,
  }) {
    return switch (id) {
      CurriculumId.yerushalmi ||
      CurriculumId.chumash ||
      CurriculumId.mishnehTorah => level(
        id,
        1,
      ).inLanguage(useHebrew: useHebrew, plural: true, variant: variant),
      CurriculumId.mishnayos || CurriculumId.bavli => level(
        id,
        2,
      ).inLanguage(useHebrew: useHebrew, plural: true, variant: variant),
      _ => useHebrew ? 'חלקים' : 'Sections',
    };
  }

  /// Variant-aware rendered level WORD for one 1-indexed [level].
  ///
  /// Returns the localized unit word (e.g. "Masechtos" / "Masekhtot" /
  /// "מסכתות") for the scope screen and other callers that need a single
  /// level word honouring both the Hebrew Terms toggle and the nusach.
  static String levelLabel(
    CurriculumId id,
    int level, {
    required bool useHebrew,
    TransliterationVariant variant = TransliterationVariant.ashkenazi,
    bool plural = false,
  }) {
    return CurriculumLabels.level(
      id,
      level,
    ).inLanguage(useHebrew: useHebrew, plural: plural, variant: variant);
  }

  /// Variant-aware per-level singular words (top → leaf). The nusach-aware
  /// companion to [labelsEn] / [labelsHe] for callers (e.g. the scope screen)
  /// that need the full ordered list rendered for the current toggle + nusach.
  static List<String> labelsForVariant(
    CurriculumId id, {
    required bool useHebrew,
    required TransliterationVariant variant,
  }) {
    return _levels[id]!
        .map((l) => l.inLanguage(useHebrew: useHebrew, variant: variant))
        .toList();
  }

  /// Plural label for the level-1 reorder section ("סדרים" in Hebrew
  /// mode, "Sedarim" in English mode). Never bilingual.
  ///
  /// [variant] selects the English transliteration dialect (Sephardi maps
  /// e.g. "Seforim" → "Sefarim"); it is irrelevant in Hebrew mode.
  static String topSectionHeader(
    CurriculumId id, {
    required bool useHebrew,
    TransliterationVariant variant = TransliterationVariant.ashkenazi,
  }) => level(
    id,
    1,
  ).inLanguage(useHebrew: useHebrew, plural: true, variant: variant);

  /// Plural label for the level-2 reorder section ("מסכתות" / "Masechtos" /
  /// "Masekhtot"). Null for single-level curricula.
  ///
  /// **Always returns level 2's plural** — not "level above leaf". For
  /// deep curricula like Mishnayos (Seder/Masechta/Perek/Mishna) the
  /// second reorder section is Masechtos (L2), not Perakim (L3).
  ///
  /// [variant] selects the English transliteration dialect so Sephardi nusach
  /// renders "Masekhtot" instead of "Masechtos"; irrelevant in Hebrew mode.
  static String? containerSectionHeader(
    CurriculumId id, {
    required bool useHebrew,
    TransliterationVariant variant = TransliterationVariant.ashkenazi,
  }) {
    final list = _levels[id]!;
    if (list.length < 2) return null;
    return list[1].inLanguage(
      useHebrew: useHebrew,
      plural: true,
      variant: variant,
    );
  }

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
