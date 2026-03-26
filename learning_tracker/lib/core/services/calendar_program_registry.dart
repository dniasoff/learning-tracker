/// Definition of a known calendar-linked learning program.
class CalendarProgramDefinition {
  final String id;
  final String displayNameEn;
  final String displayNameHe;
  final String apiSource; // 'sefaria' | 'hebcal'
  final String apiKey; // Key in the API response
  final String curriculumType; // Maps to CurriculumId.storageKey

  const CalendarProgramDefinition({
    required this.id,
    required this.displayNameEn,
    required this.displayNameHe,
    required this.apiSource,
    required this.apiKey,
    required this.curriculumType,
  });
}

/// Static registry of all known calendar-linked learning programs.
///
/// Maps program identifiers to their API sources, display names,
/// and curriculum types.
class CalendarProgramRegistry {
  static const List<CalendarProgramDefinition> programs = [
    // Sefaria programs
    CalendarProgramDefinition(
      id: 'daf_yomi',
      displayNameEn: 'Daf Yomi',
      displayNameHe: 'דף יומי',
      apiSource: 'sefaria',
      apiKey: 'Daf Yomi',
      curriculumType: 'bavli',
    ),
    CalendarProgramDefinition(
      id: 'yerushalmi_yomi',
      displayNameEn: 'Yerushalmi Yomi',
      displayNameHe: 'ירושלמי יומי',
      apiSource: 'sefaria',
      apiKey: 'Yerushalmi Yomi',
      curriculumType: 'yerushalmi',
    ),
    CalendarProgramDefinition(
      id: 'mishna_yomit',
      displayNameEn: 'Mishna Yomit',
      displayNameHe: 'משנה יומית',
      apiSource: 'sefaria',
      apiKey: 'Mishnah Yomit',
      curriculumType: 'mishnayos',
    ),
    CalendarProgramDefinition(
      id: 'nach_yomi',
      displayNameEn: 'Nach Yomi',
      displayNameHe: 'נ״ך יומי',
      apiSource: 'sefaria',
      apiKey: 'Nach Yomi',
      curriculumType: 'nach',
    ),
    CalendarProgramDefinition(
      id: 'rambam_1_chapter',
      displayNameEn: 'Rambam - 1 Chapter',
      displayNameHe: 'רמב״ם - פרק אחד',
      apiSource: 'sefaria',
      apiKey: 'Daily Rambam 1 Chapter',
      curriculumType: 'torah',
    ),
    CalendarProgramDefinition(
      id: 'rambam_3_chapters',
      displayNameEn: 'Rambam - 3 Chapters',
      displayNameHe: 'רמב״ם - ג׳ פרקים',
      apiSource: 'sefaria',
      apiKey: 'Daily Rambam 3 Chapters',
      curriculumType: 'torah',
    ),
    CalendarProgramDefinition(
      id: 'daf_a_week',
      displayNameEn: 'Daf a Week',
      displayNameHe: 'דף השבוע',
      apiSource: 'sefaria',
      apiKey: 'Daf a Week',
      curriculumType: 'bavli',
    ),
    CalendarProgramDefinition(
      id: 'halakhah_yomit',
      displayNameEn: 'Halakhah Yomit',
      displayNameHe: 'הלכה יומית',
      apiSource: 'sefaria',
      apiKey: 'Halakhah Yomit',
      curriculumType: 'mishnaBerurah',
    ),
    CalendarProgramDefinition(
      id: 'arukh_hashulchan_yomi',
      displayNameEn: 'Arukh HaShulchan Yomi',
      displayNameHe: 'ערוך השולחן יומי',
      apiSource: 'sefaria',
      apiKey: 'Arukh HaShulchan Yomi',
      curriculumType: 'mishnaBerurah',
    ),
    CalendarProgramDefinition(
      id: 'tanakh_yomi',
      displayNameEn: 'Tanakh Yomi',
      displayNameHe: 'תנ״ך יומי',
      apiSource: 'sefaria',
      apiKey: 'Tanakh Yomi',
      curriculumType: 'tanach',
    ),
    // Hebcal programs
    CalendarProgramDefinition(
      id: 'chofetz_chaim_daily',
      displayNameEn: 'Chofetz Chaim Daily',
      displayNameHe: 'חפץ חיים יומי',
      apiSource: 'hebcal',
      apiKey: 'Chofetz Chaim',
      curriculumType: 'mussar',
    ),
    CalendarProgramDefinition(
      id: 'kitzur_shulchan_aruch_yomi',
      displayNameEn: 'Kitzur Shulchan Aruch Yomi',
      displayNameHe: 'קיצור שולחן ערוך יומי',
      apiSource: 'hebcal',
      apiKey: 'Kitzur Shulchan Aruch',
      curriculumType: 'mishnaBerurah',
    ),
  ];

  /// Look up a program definition by ID.
  static CalendarProgramDefinition? byId(String id) {
    final matches = programs.where((p) => p.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Look up a program definition by API key.
  static CalendarProgramDefinition? byApiKey(String apiKey) {
    final matches = programs.where((p) => p.apiKey == apiKey);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Get all programs from a specific API source.
  static List<CalendarProgramDefinition> bySource(String source) =>
      programs.where((p) => p.apiSource == source).toList();
}
