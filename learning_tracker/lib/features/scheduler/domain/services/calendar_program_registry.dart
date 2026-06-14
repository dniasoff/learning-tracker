/// Definition of a known calendar-linked learning program.
class CalendarProgramDefinition {
  final String id;
  final String displayNameEn;
  final String displayNameHe;
  final String apiSource; // 'sefaria' | 'hebcal' | 'local'
  final String apiKey; // Key in the API response
  final String curriculumType; // Maps to CurriculumId.storageKey
  final String? hebcalCategory; // Hebcal category for matching

  const CalendarProgramDefinition({
    required this.id,
    required this.displayNameEn,
    required this.displayNameHe,
    required this.apiSource,
    required this.apiKey,
    required this.curriculumType,
    this.hebcalCategory,
  });
}

/// Static registry of all known calendar-linked learning programs.
///
/// Maps program identifiers to their API sources, display names,
/// and curriculum types. Hebcal is the source of truth for everything
/// except `halakhah_yomit` (Sefaria) and the Dirshu programs (local).
class CalendarProgramRegistry {
  static const List<CalendarProgramDefinition> programs = [
    // Hebcal-sourced programs
    CalendarProgramDefinition(
      id: 'daf_yomi',
      displayNameEn: 'Daf Yomi',
      displayNameHe: 'דף יומי',
      apiSource: 'hebcal',
      apiKey: 'dafyomi',
      curriculumType: 'bavli',
      hebcalCategory: 'dafyomi',
    ),
    CalendarProgramDefinition(
      id: 'daf_a_week',
      displayNameEn: 'Daf a Week',
      displayNameHe: 'דף השבוע',
      apiSource: 'hebcal',
      apiKey: 'dafWeekly',
      curriculumType: 'bavli',
      hebcalCategory: 'dafWeekly',
    ),
    CalendarProgramDefinition(
      id: 'mishna_yomit',
      displayNameEn: 'Mishna Yomit',
      displayNameHe: 'משנה יומית',
      apiSource: 'hebcal',
      apiKey: 'mishnayomi',
      curriculumType: 'mishnayos',
      hebcalCategory: 'mishnayomi',
    ),
    CalendarProgramDefinition(
      id: 'nach_yomi',
      displayNameEn: 'Nach Yomi',
      displayNameHe: 'נ״ך יומי',
      apiSource: 'hebcal',
      apiKey: 'nachyomi',
      curriculumType: 'nach',
      hebcalCategory: 'nachyomi',
    ),
    CalendarProgramDefinition(
      id: 'rambam_1_chapter',
      displayNameEn: 'Rambam - 1 Chapter',
      displayNameHe: 'רמב״ם - פרק אחד',
      apiSource: 'hebcal',
      apiKey: 'dailyRambam1',
      curriculumType: 'mishneh_torah',
      hebcalCategory: 'dailyRambam1',
    ),
    CalendarProgramDefinition(
      id: 'rambam_3_chapters',
      displayNameEn: 'Rambam - 3 Chapters',
      displayNameHe: 'רמב״ם - ג׳ פרקים',
      apiSource: 'hebcal',
      apiKey: 'dailyRambam3',
      curriculumType: 'mishneh_torah',
      hebcalCategory: 'dailyRambam3',
    ),
    CalendarProgramDefinition(
      id: 'yerushalmi_yomi',
      displayNameEn: 'Yerushalmi Yomi',
      displayNameHe: 'ירושלמי יומי',
      apiSource: 'hebcal',
      apiKey: 'yerushalmi',
      curriculumType: 'yerushalmi',
      hebcalCategory: 'yerushalmi',
    ),
    CalendarProgramDefinition(
      id: 'arukh_hashulchan_yomi',
      displayNameEn: 'Arukh HaShulchan Yomi',
      displayNameHe: 'ערוך השולחן יומי',
      apiSource: 'hebcal',
      apiKey: 'arukhHaShulchanYomi',
      curriculumType: 'mishna_berurah',
      hebcalCategory: 'arukhHaShulchanYomi',
    ),
    CalendarProgramDefinition(
      id: 'tanakh_yomi',
      displayNameEn: 'Tanakh Yomi',
      displayNameHe: 'תנ״ך יומי',
      apiSource: 'hebcal',
      apiKey: 'tanakhYomi',
      curriculumType: 'tanach',
      hebcalCategory: 'tanakhYomi',
    ),
    CalendarProgramDefinition(
      id: 'chofetz_chaim_daily',
      displayNameEn: 'Chofetz Chaim Daily',
      displayNameHe: 'חפץ חיים יומי',
      apiSource: 'hebcal',
      apiKey: 'chofetzChaim',
      curriculumType: 'mussar',
      hebcalCategory: 'chofetzChaim',
    ),
    CalendarProgramDefinition(
      id: 'kitzur_shulchan_aruch_yomi',
      displayNameEn: 'Kitzur Shulchan Aruch Yomi',
      displayNameHe: 'קיצור שולחן ערוך יומי',
      apiSource: 'hebcal',
      apiKey: 'kitzurShulchanAruch',
      curriculumType: 'mishna_berurah',
      hebcalCategory: 'kitzurShulchanAruch',
    ),
    CalendarProgramDefinition(
      id: 'tehillim_yomi',
      displayNameEn: 'Tehillim Yomi',
      displayNameHe: 'תהלים יומי',
      apiSource: 'hebcal',
      apiKey: 'dailyPsalms',
      curriculumType: 'tanach',
      hebcalCategory: 'dailyPsalms',
    ),
    CalendarProgramDefinition(
      id: 'perek_yomi',
      displayNameEn: 'Perek Yomi',
      displayNameHe: 'פרק יומי',
      apiSource: 'hebcal',
      apiKey: 'perekYomi',
      curriculumType: 'mishnayos',
      hebcalCategory: 'perekYomi',
    ),
    CalendarProgramDefinition(
      id: 'sefer_hamitzvot',
      displayNameEn: 'Sefer HaMitzvot',
      displayNameHe: 'ספר המצוות',
      apiSource: 'hebcal',
      apiKey: 'seferHaMitzvot',
      curriculumType: 'mishneh_torah',
      hebcalCategory: 'seferHaMitzvot',
    ),
    CalendarProgramDefinition(
      id: 'shemirat_halashon',
      displayNameEn: 'Shemirat HaLashon',
      displayNameHe: 'שמירת הלשון',
      apiSource: 'hebcal',
      apiKey: 'shemiratHaLashon',
      curriculumType: 'mussar',
      hebcalCategory: 'shemiratHaLashon',
    ),
    CalendarProgramDefinition(
      id: 'pirkei_avot_summer',
      displayNameEn: 'Pirkei Avot (Summer)',
      displayNameHe: 'פרקי אבות',
      apiSource: 'hebcal',
      apiKey: 'pirkeiAvotSummer',
      curriculumType: 'mishnayos',
      hebcalCategory: 'pirkeiAvotSummer',
    ),

    // Sefaria-sourced programs (hebcal doesn't supply these)
    CalendarProgramDefinition(
      id: 'halakhah_yomit',
      displayNameEn: 'Halakhah Yomit',
      displayNameHe: 'הלכה יומית',
      apiSource: 'sefaria',
      apiKey: 'Halakhah Yomit',
      curriculumType: 'mishna_berurah',
    ),

    // Dirshu programs (composite — share daf_yomi / yerushalmi cycles plus
    // their own review structure)
    CalendarProgramDefinition(
      id: 'dirshu_kinyan_torah',
      displayNameEn: 'Dirshu Kinyan Torah',
      displayNameHe: 'דרשו קנין תורה',
      apiSource: 'local',
      apiKey: 'Dirshu Kinyan Torah',
      curriculumType: 'bavli',
    ),
    CalendarProgramDefinition(
      id: 'dirshu_amud_hayomi',
      displayNameEn: 'Dirshu Amud HaYomi',
      displayNameHe: 'דרשו עמוד היומי',
      apiSource: 'hebcal',
      apiKey: 'dirshuAmudYomi',
      curriculumType: 'bavli',
      hebcalCategory: 'dirshuAmudYomi',
    ),
    CalendarProgramDefinition(
      id: 'dirshu_kinyan_yerushalmi',
      displayNameEn: 'Dirshu Kinyan Yerushalmi',
      displayNameHe: 'דרשו קנין ירושלמי',
      apiSource: 'local',
      apiKey: 'Dirshu Kinyan Yerushalmi',
      curriculumType: 'yerushalmi',
    ),
  ];

  /// Look up a program definition by ID.
  static CalendarProgramDefinition? byId(String id) {
    final matches = programs.where((p) => p.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Hebrew display name for a learning program, matched by its internal
  /// `name` first and its `apiProgramKey` second.
  ///
  /// Some seeds use a different `name` than the registry id, which equals the
  /// `api_program_key` (e.g. seed name `mishnah_yomis` vs registry id /
  /// api key `mishna_yomit`). Matching on the api key as a fallback keeps the
  /// Hebrew label from falling back to the Latin transliteration in a Hebrew
  /// UI. Returns null when no registered program matches either key.
  static String? hebrewNameFor({required String name, String? apiKey}) {
    final def = byId(name) ?? (apiKey != null ? byId(apiKey) : null);
    return def?.displayNameHe;
  }

  /// Look up a program definition by API key.
  static CalendarProgramDefinition? byApiKey(String apiKey) {
    final matches = programs.where((p) => p.apiKey == apiKey);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Look up a program definition by Hebcal category.
  static CalendarProgramDefinition? byHebcalCategory(String category) {
    final matches = programs.where((p) => p.hebcalCategory == category);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Get all programs from a specific API source.
  static List<CalendarProgramDefinition> bySource(String source) =>
      programs.where((p) => p.apiSource == source).toList();
}
